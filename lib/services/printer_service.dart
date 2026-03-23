import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blue_thermal_printer_plus/blue_thermal_printer_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

enum PrinterType { none, builtIn, bluetooth }

class PrinterSelection {
  final PrinterType type;
  final String? name;
  final String? address;

  const PrinterSelection({required this.type, this.name, this.address});

  String get label {
    switch (type) {
      case PrinterType.builtIn:
        return name?.isNotEmpty == true ? name! : 'Built-in printer';
      case PrinterType.bluetooth:
        final n = name?.isNotEmpty == true ? name! : 'Bluetooth printer';
        final a = address?.isNotEmpty == true ? address! : '';
        return a.isEmpty ? n : '$n ($a)';
      case PrinterType.none:
        return 'No printer selected';
    }
  }
}

class PrinterService {
  static const _kLogoAsset = 'asset/logo.webp';

  static const _kType = 'printer_type';
  static const _kBtAddress = 'printer_bt_address';
  static const _kBtName = 'printer_bt_name';

  final BlueThermalPrinterPlus _bt = BlueThermalPrinterPlus();

  Future<PrinterSelection> loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final rawType = prefs.getString(_kType) ?? 'none';

    if (rawType == 'built_in') {
      return const PrinterSelection(
        type: PrinterType.builtIn,
        name: 'Built-in printer',
      );
    }

    if (rawType == 'bluetooth') {
      final address = prefs.getString(_kBtAddress);
      final name = prefs.getString(_kBtName);
      if (address != null && address.isNotEmpty) {
        return PrinterSelection(
          type: PrinterType.bluetooth,
          name: name,
          address: address,
        );
      }
    }

    return const PrinterSelection(type: PrinterType.none);
  }

  Future<void> saveSelection(PrinterSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    switch (selection.type) {
      case PrinterType.builtIn:
        await prefs.setString(_kType, 'built_in');
        await prefs.remove(_kBtAddress);
        await prefs.remove(_kBtName);
        break;
      case PrinterType.bluetooth:
        await prefs.setString(_kType, 'bluetooth');
        await prefs.setString(_kBtAddress, selection.address ?? '');
        await prefs.setString(_kBtName, selection.name ?? '');
        break;
      case PrinterType.none:
        await prefs.setString(_kType, 'none');
        await prefs.remove(_kBtAddress);
        await prefs.remove(_kBtName);
        break;
    }
  }

  /// If device has built-in printer support (Sunmi), prefer it as default.
  Future<PrinterSelection> ensureDefaultSelection() async {
    final current = await loadSelection();
    if (current.type != PrinterType.none) return current;

    final builtIn = await isBuiltInPrinterSupported();
    if (builtIn) {
      const sel = PrinterSelection(
        type: PrinterType.builtIn,
        name: 'Built-in printer',
      );
      await saveSelection(sel);
      return sel;
    }

    return current;
  }

  Future<bool> isBuiltInPrinterSupported() async {
    try {
      await SunmiPrinter.bindingPrinter();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureBluetoothPermissions() async {
    // Android 12+ needs BLUETOOTH_CONNECT/SCAN; permission_handler maps these.
    final connect = await Permission.bluetoothConnect.request();
    final scan = await Permission.bluetoothScan.request();

    // Pre-Android 12 scanning often requires location.
    final loc = await Permission.locationWhenInUse.request();

    return connect.isGranted &&
        scan.isGranted &&
        (loc.isGranted || loc.isLimited);
  }

  Future<List<BluetoothDevice>> getBondedBluetoothPrinters() async {
    final ok = await _ensureBluetoothPermissions();
    if (!ok) return [];

    final devices = await _bt.getBondedDevices();
    // Many printer plugins can only print to paired devices.
    return devices;
  }

  Future<void> printReceipt({
    required PrinterSelection selection,
    required Map<String, dynamic> parcel,
  }) async {
    if (selection.type == PrinterType.builtIn) {
      await _printSunmi(parcel);
      return;
    }
    if (selection.type == PrinterType.bluetooth) {
      await _printBluetooth(selection, parcel);
      return;
    }

    throw Exception('No printer selected');
  }

  /// Opens the system print UI when possible; otherwise opens the share sheet so the
  /// user can save or print the PDF in another app (common on Android without a print service).
  ///
  /// Returns `true` if the share sheet was used (print UI was skipped or failed).
  Future<bool> printReceiptAsPdf(Map<String, dynamic> parcel) async {
    final safeName = _pdfFileName(parcel);
    final info = await Printing.info();

    if (info.canPrint) {
      try {
        await Printing.layoutPdf(
          name: safeName,
          format: PdfPageFormat.a4,
          dynamicLayout: false,
          onLayout: (PdfPageFormat format) async =>
              buildReceiptPdfBytes(parcel, format),
        );
        return false;
      } catch (_) {
        // e.g. no print spooler, or platform channel failure — try share below
      }
    }

    if (info.canShare) {
      final bytes = await buildReceiptPdfBytes(parcel, PdfPageFormat.a4);
      final ok = await Printing.sharePdf(
        bytes: bytes,
        filename: safeName,
        subject: 'Tilisho parcel receipt',
        body: 'Parcel receipt (PDF)',
      );
      if (!ok) {
        throw Exception('Could not open PDF share sheet.');
      }
      return true;
    }

    throw Exception(
      'PDF printing is not available on this device. Try updating the app or OS.',
    );
  }

  static String _pdfFileName(Map<String, dynamic> parcel) {
    final raw = parcel['tracking_number']?.toString().trim() ?? 'receipt';
    final slug = raw.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return 'tilisho_parcel_$slug.pdf';
  }

  /// Loads the receipt logo as PNG bytes (WebP decoded via Flutter). Used for PDF and thermal.
  static Future<Uint8List?> _loadReceiptLogoPngBytes({int targetWidthPx = 200}) async {
    try {
      final data = await rootBundle.load(_kLogoAsset);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidthPx);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Builds a single-page PDF aligned with [ParcelReceiptPage] on-screen layout.
  Future<Uint8List> buildReceiptPdfBytes(
    Map<String, dynamic> parcel, [
    PdfPageFormat format = PdfPageFormat.a4,
  ]) async {
    final logoPng = await _loadReceiptLogoPngBytes(targetWidthPx: 220);
    final tracking = _str(parcel['tracking_number']);
    final qrData = tracking == '—' ? 'tilisho-parcel' : tracking;
    final travelFormatted = _formatTravelDate(parcel['travel_date']);
    final fareFormatted =
        NumberFormat('#,###', 'en_US').format(_amount(parcel['amount']).round());

    final senderEmail = parcel['sender_email']?.toString().trim();
    final receiverEmail = parcel['receiver_email']?.toString().trim();
    final desc = parcel['description']?.toString();
    final transportedPhone = parcel['transported_by_phone']?.toString().trim();
    final receivedStaffPhone = parcel['received_by_phone']?.toString().trim();
    final hasTransportedAt = parcel['transported_at'] != null;
    final hasReceivedAt = parcel['received_at'] != null;
    final showHandover = hasTransportedAt || hasReceivedAt;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                      colors: [
                        PdfColor.fromInt(0xFF0D47A1),
                        PdfColor.fromInt(0xFF1565C0),
                      ],
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'TILISHO',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 4,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Official receipt',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      if (logoPng != null) ...[
                        pw.Center(
                          child: pw.Image(
                            pw.MemoryImage(logoPng),
                            width: 96,
                            height: 96,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(height: 14),
                      ],
                      pw.Text(
                        'Parcel registered',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Keep this receipt for your records',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Text(
                        'TRACKING NUMBER',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        tracking,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF0D47A1),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Present this code at the counter when collecting',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 12),
                      _pdfSectionTitle('Shipment'),
                      _pdfKvRow('Parcel', _str(parcel['parcel_name'])),
                      _pdfKvRow('Quantity', _str(parcel['quantity'])),
                      _pdfKvRow('Travel date', travelFormatted),
                      pw.SizedBox(height: 8),
                      _pdfSectionTitle('Route'),
                      _pdfKvRow('From', _str(parcel['origin'])),
                      _pdfKvRow('To', _str(parcel['destination'])),
                      pw.SizedBox(height: 8),
                      _pdfSectionTitle('Parties'),
                      _pdfKvRow('Sender', _str(parcel['sender_name'])),
                      _pdfKvRow('Sender phone', _str(parcel['sender_phone'])),
                      if (senderEmail != null && senderEmail.isNotEmpty)
                        _pdfKvRow('Sender email', senderEmail),
                      _pdfKvRow('Receiver', _str(parcel['receiver_name'])),
                      _pdfKvRow(
                        'Receiver phone',
                        _str(parcel['receiver_phone'] ?? parcel['receiver_contact']),
                      ),
                      if (receiverEmail != null && receiverEmail.isNotEmpty)
                        _pdfKvRow('Receiver email', receiverEmail),
                      if (showHandover) ...[
                        pw.SizedBox(height: 8),
                        _pdfSectionTitle('Handover'),
                        if (hasTransportedAt) ...[
                          _pdfKvRow('Given to', _str(parcel['transported_by_name'])),
                          if (transportedPhone != null && transportedPhone.isNotEmpty)
                            _pdfKvRow('Transporter phone', transportedPhone),
                          _pdfKvRow('Handed over at', _str(parcel['transported_at'])),
                        ],
                        if (hasReceivedAt) ...[
                          _pdfKvRow(
                            'Received by (staff)',
                            _str(parcel['received_by_name']),
                          ),
                          if (receivedStaffPhone != null && receivedStaffPhone.isNotEmpty)
                            _pdfKvRow('Staff receiver phone', receivedStaffPhone),
                          _pdfKvRow('Received at', _str(parcel['received_at'])),
                        ],
                      ],
                      if (desc != null && desc.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        _pdfSectionTitle('Notes'),
                        pw.Text(
                          desc.trim(),
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey800,
                            lineSpacing: 1.35,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 14),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: PdfColors.green100),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'TOTAL FARE',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'TZS $fareFormatted',
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromInt(0xFF1B5E20),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 14),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'SCAN TO VERIFY',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Center(
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 112,
                          height: 112,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        tracking,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF0D47A1),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Divider(color: PdfColors.grey300),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'TILISHO PARCEL',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey500,
                          letterSpacing: 1.8,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'www.tilishosafari.co.tz',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return await doc.save();
  }

  static pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 3,
            height: 12,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFB71C1C),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(1)),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfKvRow(String label, String value, {bool emphasize = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 11,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ),
          pw.Expanded(
            flex: 14,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: emphasize ? 11 : 10,
                fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: PdfColors.grey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTravelDate(dynamic v) {
    if (v == null) return '—';
    try {
      return DateFormat.yMMMEd().format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _printSunmi(Map<String, dynamic> parcel) async {
    final logoPng = await _loadReceiptLogoPngBytes(targetWidthPx: 200);
    final tracking = _str(parcel['tracking_number']);
    final qrPayload = tracking == '—' ? 'tilisho-parcel' : tracking;
    final travelFormatted = _formatTravelDate(parcel['travel_date']);
    final fareFormatted = _formatFareTzs(parcel['amount']);
    final senderEmail = parcel['sender_email']?.toString().trim();
    final receiverEmail = parcel['receiver_email']?.toString().trim();
    final desc = parcel['description']?.toString();
    final tp = parcel['transported_by_phone']?.toString().trim();
    final rp = parcel['received_by_phone']?.toString().trim();

    await SunmiPrinter.initPrinter();
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('TILISHO');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.printText('Official receipt');
    await SunmiPrinter.lineWrap(1);
    if (logoPng != null) {
      await SunmiPrinter.printImage(logoPng, align: SunmiPrintAlign.CENTER);
      await SunmiPrinter.lineWrap(1);
    }
    await SunmiPrinter.printText('Parcel registered');
    await SunmiPrinter.printText('Keep this receipt for your records');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('TRACKING NUMBER');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.bold();
    await SunmiPrinter.printText(tracking);
    await SunmiPrinter.resetBold();
    await SunmiPrinter.printText('Present this code at the counter when collecting');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('--------------------------------');
    await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('SHIPMENT');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.printText('Parcel: ${_str(parcel['parcel_name'])}');
    await SunmiPrinter.printText('Quantity: ${_str(parcel['quantity'])}');
    await SunmiPrinter.printText('Travel date: $travelFormatted');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('ROUTE');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.printText('From: ${_str(parcel['origin'])}');
    await SunmiPrinter.printText('To: ${_str(parcel['destination'])}');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('PARTIES');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.printText('Sender: ${_str(parcel['sender_name'])}');
    await SunmiPrinter.printText('Sender phone: ${_str(parcel['sender_phone'])}');
    if (senderEmail != null && senderEmail.isNotEmpty) {
      await SunmiPrinter.printText('Sender email: $senderEmail');
    }
    await SunmiPrinter.printText('Receiver: ${_str(parcel['receiver_name'])}');
    await SunmiPrinter.printText(
      'Receiver phone: ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
    );
    if (receiverEmail != null && receiverEmail.isNotEmpty) {
      await SunmiPrinter.printText('Receiver email: $receiverEmail');
    }
    if (parcel['transported_at'] != null || parcel['received_at'] != null) {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('HANDOVER');
      await SunmiPrinter.resetBold();
      if (parcel['transported_at'] != null) {
        await SunmiPrinter.printText('Given to: ${_str(parcel['transported_by_name'])}');
        if (tp != null && tp.isNotEmpty) {
          await SunmiPrinter.printText('Transporter phone: $tp');
        }
        await SunmiPrinter.printText('Handed over at: ${_str(parcel['transported_at'])}');
      }
      if (parcel['received_at'] != null) {
        await SunmiPrinter.printText(
          'Received by (staff): ${_str(parcel['received_by_name'])}',
        );
        if (rp != null && rp.isNotEmpty) {
          await SunmiPrinter.printText('Staff receiver phone: $rp');
        }
        await SunmiPrinter.printText('Received at: ${_str(parcel['received_at'])}');
      }
    }
    if (desc != null && desc.trim().isNotEmpty) {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.bold();
      await SunmiPrinter.printText('NOTES');
      await SunmiPrinter.resetBold();
      await SunmiPrinter.printText(desc.trim());
    }
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('--------------------------------');
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('TOTAL FARE');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('TZS $fareFormatted');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('SCAN TO VERIFY');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.printQRCode(qrPayload);
    await SunmiPrinter.printText(tracking);
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('--------------------------------');
    await SunmiPrinter.printText('TILISHO PARCEL');
    await SunmiPrinter.printText('www.tilishosafari.co.tz');
    await SunmiPrinter.lineWrap(3);
    await SunmiPrinter.cut();
  }

  Future<void> _printBluetooth(
    PrinterSelection selection,
    Map<String, dynamic> parcel,
  ) async {
    final ok = await _ensureBluetoothPermissions();
    if (!ok) throw Exception('Bluetooth permission denied');

    final bonded = await _bt.getBondedDevices();
    final device = bonded
        .where((d) => d.address == selection.address)
        .cast<BluetoothDevice?>()
        .firstWhere((d) => d != null, orElse: () => null);
    if (device == null) throw Exception('Selected printer not paired');

    final connected = await _bt.isConnected ?? false;
    if (!connected) {
      await _bt.connect(device);
      // Small delay to allow connection to settle.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final logoPng = await _loadReceiptLogoPngBytes(targetWidthPx: 200);
    final tracking = _str(parcel['tracking_number']);
    final qrPayload = tracking == '—' ? 'tilisho-parcel' : tracking;
    final travelFormatted = _formatTravelDate(parcel['travel_date']);
    final fareFormatted = _formatFareTzs(parcel['amount']);
    final senderEmail = parcel['sender_email']?.toString().trim();
    final receiverEmail = parcel['receiver_email']?.toString().trim();
    final desc = parcel['description']?.toString();
    final tp = parcel['transported_by_phone']?.toString().trim();
    final rp = parcel['received_by_phone']?.toString().trim();

    final items = <PrintItem>[
      PrintItem.text('TILISHO', size: 2, align: 1),
      PrintItem.text('Official receipt', align: 1),
      PrintItem.text('', align: 1),
      if (logoPng != null) PrintItem.image(logoPng, align: 1, width: 200),
      if (logoPng != null) PrintItem.text('', align: 1),
      PrintItem.text('Parcel registered', align: 1),
      PrintItem.text('Keep this receipt for your records', align: 1),
      PrintItem.text('', align: 1),
      PrintItem.text('TRACKING NUMBER', align: 1),
      PrintItem.text(tracking, size: 1, align: 1),
      PrintItem.text('Present this code at the counter when collecting', align: 1),
      PrintItem.text('--------------------------------', align: 1),
      PrintItem.text('SHIPMENT', size: 1),
      PrintItem.text('Parcel: ${_str(parcel['parcel_name'])}'),
      PrintItem.text('Quantity: ${_str(parcel['quantity'])}'),
      PrintItem.text('Travel date: $travelFormatted'),
      PrintItem.text('', align: 1),
      PrintItem.text('ROUTE', size: 1),
      PrintItem.text('From: ${_str(parcel['origin'])}'),
      PrintItem.text('To: ${_str(parcel['destination'])}'),
      PrintItem.text('', align: 1),
      PrintItem.text('PARTIES', size: 1),
      PrintItem.text('Sender: ${_str(parcel['sender_name'])}'),
      PrintItem.text('Sender phone: ${_str(parcel['sender_phone'])}'),
      if (senderEmail != null && senderEmail.isNotEmpty)
        PrintItem.text('Sender email: $senderEmail'),
      PrintItem.text('Receiver: ${_str(parcel['receiver_name'])}'),
      PrintItem.text(
        'Receiver phone: ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
      ),
      if (receiverEmail != null && receiverEmail.isNotEmpty)
        PrintItem.text('Receiver email: $receiverEmail'),
    ];

    if (parcel['transported_at'] != null || parcel['received_at'] != null) {
      items.add(PrintItem.text('', align: 1));
      items.add(PrintItem.text('HANDOVER', size: 1));
      if (parcel['transported_at'] != null) {
        items.add(PrintItem.text('Given to: ${_str(parcel['transported_by_name'])}'));
        if (tp != null && tp.isNotEmpty) {
          items.add(PrintItem.text('Transporter phone: $tp'));
        }
        items.add(PrintItem.text('Handed over at: ${_str(parcel['transported_at'])}'));
      }
      if (parcel['received_at'] != null) {
        items.add(
          PrintItem.text(
            'Received by (staff): ${_str(parcel['received_by_name'])}',
          ),
        );
        if (rp != null && rp.isNotEmpty) {
          items.add(PrintItem.text('Staff receiver phone: $rp'));
        }
        items.add(PrintItem.text('Received at: ${_str(parcel['received_at'])}'));
      }
    }

    if (desc != null && desc.trim().isNotEmpty) {
      items.add(PrintItem.text('', align: 1));
      items.add(PrintItem.text('NOTES', size: 1));
      items.add(PrintItem.text(desc.trim()));
    }

    items.addAll([
      PrintItem.text('--------------------------------', align: 1),
      PrintItem.text('TOTAL FARE', size: 1),
      PrintItem.text('TZS $fareFormatted', size: 1),
      PrintItem.text('', align: 1),
      PrintItem.text('SCAN TO VERIFY', align: 1),
      PrintItem(type: PrintItemType.qrCode, text: qrPayload, align: 1),
      PrintItem.text('', align: 1),
      PrintItem.text(tracking, size: 1, align: 1),
      PrintItem.text('--------------------------------', align: 1),
      PrintItem.text('TILISHO PARCEL', align: 1),
      PrintItem.text('www.tilishosafari.co.tz', align: 1),
      PrintItem.text('', align: 1),
    ]);

    await _bt.print(items: items, protocol: PrinterProtocol.escPos);
  }

  static String _str(dynamic v) => v?.toString() ?? '—';

  static String _formatFareTzs(dynamic amount) {
    return NumberFormat('#,###', 'en_US').format(_amount(amount).round());
  }

  static double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
