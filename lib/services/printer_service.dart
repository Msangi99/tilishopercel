import 'dart:async';
import 'dart:typed_data';

import 'package:blue_thermal_printer_plus/blue_thermal_printer_plus.dart';
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

  /// Builds a single-page PDF matching the thermal receipt content.
  Future<Uint8List> buildReceiptPdfBytes(
    Map<String, dynamic> parcel, [
    PdfPageFormat format = PdfPageFormat.a4,
  ]) async {
    final tracking = _str(parcel['tracking_number']);
    final qrData = tracking == '—' ? 'tilisho-parcel' : tracking;

    final senderEmail = parcel['sender_email']?.toString().trim();
    final receiverEmail = parcel['receiver_email']?.toString().trim();
    final pn = parcel['parcel_name']?.toString();
    final q = parcel['quantity'];
    final off = parcel['creator_office']?.toString();
    final desc = parcel['description']?.toString();
    final transportedPhone = parcel['transported_by_phone']?.toString().trim();
    final receivedStaffPhone = parcel['received_by_phone']?.toString().trim();
    final hasTransportedAt = parcel['transported_at'] != null;
    final hasReceivedAt = parcel['received_at'] != null;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(48),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'TILISHO PARCEL',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 112,
                  height: 112,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  tracking,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              _pdfLine('From', _str(parcel['origin'])),
              _pdfLine('To', _str(parcel['destination'])),
              _pdfLine(
                'Sender',
                '${_str(parcel['sender_name'])} · ${_str(parcel['sender_phone'])}',
              ),
              if (senderEmail != null && senderEmail.isNotEmpty)
                _pdfLine('Sender email', senderEmail),
              _pdfLine(
                'Receiver',
                '${_str(parcel['receiver_name'])} · ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
              ),
              if (receiverEmail != null && receiverEmail.isNotEmpty)
                _pdfLine('Receiver email', receiverEmail),
              _pdfLine('Ship date', _str(parcel['travel_date'])),
              if (pn != null && pn.trim().isNotEmpty) _pdfLine('Parcel', pn),
              if (q != null)
                _pdfLine(
                  'Qty / weight',
                  '$q · ${_weightBand(parcel['weight_band'])}',
                ),
              if (off != null && off.trim().isNotEmpty) _pdfLine('Office', off),
              if (desc != null && desc.trim().isNotEmpty) _pdfLine('Cargo', desc),
              if (hasTransportedAt) ...[
                pw.SizedBox(height: 4),
                _pdfLine('Handover', 'Transport'),
                _pdfLine('Given to', _str(parcel['transported_by_name'])),
                if (transportedPhone != null && transportedPhone.isNotEmpty)
                  _pdfLine('Transporter phone', transportedPhone),
                _pdfLine('Handed over at', _str(parcel['transported_at'])),
              ],
              if (hasReceivedAt) ...[
                _pdfLine('Received by', _str(parcel['received_by_name'])),
                if (receivedStaffPhone != null && receivedStaffPhone.isNotEmpty)
                  _pdfLine('Staff receiver phone', receivedStaffPhone),
                _pdfLine('Received at', _str(parcel['received_at'])),
              ],
              _pdfLine(
                'Fare',
                'TZS ${_amount(parcel['amount']).toStringAsFixed(0)}',
                emphasize: true,
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Support: 0750015630',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'www.tilishosafari.co.tz',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );
    return await doc.save();
  }

  static pw.Widget _pdfLine(String label, String value, {bool emphasize = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: emphasize ? 12 : 11,
                fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printSunmi(Map<String, dynamic> parcel) async {
    await SunmiPrinter.initPrinter();
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('TILISHO PARCEL');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText(_str(parcel['tracking_number']));
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
    await SunmiPrinter.printText('From: ${_str(parcel['origin'])}');
    await SunmiPrinter.printText('To: ${_str(parcel['destination'])}');
    await SunmiPrinter.printText(
      'Sender: ${_str(parcel['sender_name'])} ${_str(parcel['sender_phone'])}',
    );
    final senderEmail = parcel['sender_email']?.toString().trim();
    if (senderEmail != null && senderEmail.isNotEmpty) {
      await SunmiPrinter.printText('Sender email: $senderEmail');
    }
    await SunmiPrinter.printText(
      'Receiver: ${_str(parcel['receiver_name'])} ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
    );
    final receiverEmail = parcel['receiver_email']?.toString().trim();
    if (receiverEmail != null && receiverEmail.isNotEmpty) {
      await SunmiPrinter.printText('Receiver email: $receiverEmail');
    }
    await SunmiPrinter.printText('Ship Date: ${_str(parcel['travel_date'])}');
    final pn = parcel['parcel_name']?.toString();
    if (pn != null && pn.trim().isNotEmpty) {
      await SunmiPrinter.printText('Parcel: $pn');
    }
    final q = parcel['quantity'];
    if (q != null) {
      await SunmiPrinter.printText('Qty: $q  Weight: ${_weightBand(parcel['weight_band'])}');
    }
    final off = parcel['creator_office']?.toString();
    if (off != null && off.trim().isNotEmpty) {
      await SunmiPrinter.printText('Office: $off');
    }
    final desc = parcel['description']?.toString();
    if (desc != null && desc.trim().isNotEmpty) {
      await SunmiPrinter.printText('Cargo: $desc');
    }
    if (parcel['transported_at'] != null) {
      await SunmiPrinter.printText('--- Handover ---');
      await SunmiPrinter.printText('Given to: ${_str(parcel['transported_by_name'])}');
      final tp = parcel['transported_by_phone']?.toString().trim();
      if (tp != null && tp.isNotEmpty) {
        await SunmiPrinter.printText('Transporter tel: $tp');
      }
      await SunmiPrinter.printText('At: ${_str(parcel['transported_at'])}');
    }
    if (parcel['received_at'] != null) {
      await SunmiPrinter.printText('Received by: ${_str(parcel['received_by_name'])}');
      final rp = parcel['received_by_phone']?.toString().trim();
      if (rp != null && rp.isNotEmpty) {
        await SunmiPrinter.printText('Staff receiver tel: $rp');
      }
      await SunmiPrinter.printText('Received at: ${_str(parcel['received_at'])}');
    }
    await SunmiPrinter.printText(
      'Fare: TZS ${_amount(parcel['amount']).toStringAsFixed(0)}',
    );

    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('Support: 0750015630');
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

    final items = <PrintItem>[
      PrintItem.text('TILISHO PARCEL', size: 2, align: 1),
      PrintItem.text('', align: 1),
      PrintItem.text(_str(parcel['tracking_number']), size: 1, align: 1),
      PrintItem.text('', align: 1),
      PrintItem.text('From: ${_str(parcel['origin'])}'),
      PrintItem.text('To: ${_str(parcel['destination'])}'),
      PrintItem.text('Sender: ${_str(parcel['sender_name'])}'),
      PrintItem.text('Phone: ${_str(parcel['sender_phone'])}'),
      if (parcel['sender_email'] != null &&
          parcel['sender_email'].toString().trim().isNotEmpty)
        PrintItem.text('Email: ${parcel['sender_email']}'),
      PrintItem.text('Receiver: ${_str(parcel['receiver_name'])}'),
      PrintItem.text(
        'Phone: ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
      ),
      if (parcel['receiver_email'] != null &&
          parcel['receiver_email'].toString().trim().isNotEmpty)
        PrintItem.text('Email: ${parcel['receiver_email']}'),
      PrintItem.text('Ship Date: ${_str(parcel['travel_date'])}'),
    ];
    final pn = parcel['parcel_name']?.toString();
    if (pn != null && pn.trim().isNotEmpty) {
      items.add(PrintItem.text('Parcel: $pn'));
    }
    final q = parcel['quantity'];
    if (q != null) {
      items.add(
        PrintItem.text('Qty: $q  Weight: ${_weightBand(parcel['weight_band'])}'),
      );
    }
    final off = parcel['creator_office']?.toString();
    if (off != null && off.trim().isNotEmpty) {
      items.add(PrintItem.text('Office: $off'));
    }
    final desc = parcel['description']?.toString();
    if (desc != null && desc.trim().isNotEmpty) {
      items.add(PrintItem.text('Cargo: $desc'));
    }

    if (parcel['transported_at'] != null) {
      items.add(PrintItem.text('--- Handover ---'));
      items.add(PrintItem.text('Given to: ${_str(parcel['transported_by_name'])}'));
      final tp = parcel['transported_by_phone']?.toString().trim();
      if (tp != null && tp.isNotEmpty) {
        items.add(PrintItem.text('Transporter tel: $tp'));
      }
      items.add(PrintItem.text('At: ${_str(parcel['transported_at'])}'));
    }
    if (parcel['received_at'] != null) {
      items.add(PrintItem.text('Rcvd by: ${_str(parcel['received_by_name'])}'));
      final rp = parcel['received_by_phone']?.toString().trim();
      if (rp != null && rp.isNotEmpty) {
        items.add(PrintItem.text('Staff rcvr tel: $rp'));
      }
      items.add(PrintItem.text('Rcvd at: ${_str(parcel['received_at'])}'));
    }

    items.addAll([
      PrintItem.text(
        'Fare: TZS ${_amount(parcel['amount']).toStringAsFixed(0)}',
        size: 1,
        align: 0,
      ),
      PrintItem.text('', align: 1),
      PrintItem.text('Support: 0750015630', align: 1),
      PrintItem.text('www.tilishosafari.co.tz', align: 1),
      PrintItem.text('', align: 1),
    ]);

    await _bt.print(items: items, protocol: PrinterProtocol.escPos);
  }

  static String _str(dynamic v) => v?.toString() ?? '—';

  static String _weightBand(dynamic v) {
    final s = v?.toString() ?? '';
    if (s == 'over_20kg') return '20kg+';
    if (s == 'under_20kg') return '<20kg';
    return '—';
  }
  static double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
