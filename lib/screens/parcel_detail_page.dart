import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:t_percel/services/printer_service.dart';
import 'package:t_percel/services/api_service.dart';
import 'package:t_percel/main.dart';

class ParcelDetailPage extends StatefulWidget {
  const ParcelDetailPage({super.key, required this.parcel});

  final Map<String, dynamic> parcel;

  @override
  State<ParcelDetailPage> createState() => _ParcelDetailPageState();
}

class _ParcelDetailPageState extends State<ParcelDetailPage> {
  final PrinterService _printerService = PrinterService();
  PrinterSelection _selection = const PrinterSelection(type: PrinterType.none);
  bool _loadingPrinter = true;
  bool _printBusy = false;
  bool _refetchingParcel = false;
  late Map<String, dynamic> _parcel;

  @override
  void initState() {
    super.initState();
    _parcel = Map<String, dynamic>.from(widget.parcel);
    _initPrinter();
  }

  Future<void> _refreshParcel() async {
    final tracking = _parcel['tracking_number']?.toString().trim();
    if (tracking == null || tracking.isEmpty) return;
    setState(() => _refetchingParcel = true);
    try {
      final data = await ApiService.viewParcel(tracking);
      final p = data['parcel'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (p != null) {
        setState(() => _parcel = Map<String, dynamic>.from(p));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.poppins(fontSize: 13, height: 1.35),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _refetchingParcel = false);
    }
  }

  static String _str(dynamic v) => v?.toString() ?? '—';

  static double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _weightBandLabel(dynamic v) {
    final s = v?.toString() ?? '';
    if (s == 'over_20kg') return '20 kg or more';
    if (s == 'under_20kg') return 'Less than 20 kg';
    return '—';
  }

  static String _formatDateTime(dynamic v) {
    if (v == null) return '—';
    final raw = v.toString();
    try {
      final dt = DateTime.parse(raw);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _initPrinter() async {
    try {
      final sel = await _printerService.ensureDefaultSelection();
      if (!mounted) return;
      setState(() {
        _selection = sel;
        _loadingPrinter = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPrinter = false);
    }
  }

  Future<void> _choosePrinter() async {
    final builtInSupported = await _printerService.isBuiltInPrinterSupported();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _PrinterPickerSheet(
          printerService: _printerService,
          current: _selection,
          showBuiltIn: builtInSupported,
          onSelected: (sel) async {
            await _printerService.saveSelection(sel);
            if (mounted) {
              setState(() => _selection = sel);
            }
            if (context.mounted) Navigator.pop(context);
          },
        );
      },
    );
  }

  String _formatPrintError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) {
      return 'Printing failed. Please try again.';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('no printer')) {
      return 'No printer selected. Open the three-dot menu and tap Choose printer.';
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Permission denied. Allow Bluetooth in Settings, then try again.';
    }
    if (lower.contains('not connected') ||
        lower.contains('disconnect') ||
        lower.contains('unable to connect')) {
      return 'Printer not connected. Check Bluetooth pairing and try again.';
    }
    if (lower.contains('timeout')) {
      return 'Printer did not respond in time. Move closer and try again.';
    }
    if (lower.contains('share sheet')) {
      return 'Could not open the PDF share sheet. Try again or restart the app.';
    }
    if (lower.contains('not available on this device')) {
      return raw.length > 160 ? '${raw.substring(0, 157)}…' : raw;
    }
    if (raw.length > 140) {
      return '${raw.substring(0, 137)}…';
    }
    return raw;
  }

  void _showPrintErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13, height: 1.35)),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Set up',
          textColor: Colors.white,
          onPressed: _choosePrinter,
        ),
      ),
    );
  }

  Future<void> _printReceipt() async {
    if (_printBusy || _loadingPrinter) return;
    if (_selection.type == PrinterType.none) {
      _showPrintErrorSnack(
        'No printer selected. Tap Set up below or use the three-dot menu → Choose printer.',
      );
      return;
    }
    setState(() => _printBusy = true);
    try {
      await _printerService.printReceipt(
        selection: _selection,
        parcel: _parcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sent to printer',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showPrintErrorSnack(_formatPrintError(e));
    } finally {
      if (mounted) setState(() => _printBusy = false);
    }
  }

  /// System print UI (user can save as PDF or pick a printer). No hardware selection required.
  Future<void> _printReceiptPdf() async {
    if (_printBusy || _loadingPrinter) return;
    setState(() => _printBusy = true);
    try {
      final usedShare = await _printerService.printReceiptAsPdf(_parcel);
      if (!mounted) return;
      if (usedShare) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pick an app below to save as PDF or send to a printer.',
              style: GoogleFonts.poppins(fontSize: 13, height: 1.35),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showPrintErrorSnack(_formatPrintError(e));
    } finally {
      if (mounted) setState(() => _printBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = _parcel;
    String nz(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? '—' : s;
    }

    final tracking = _str(parcel['tracking_number']);
    final status = _str(parcel['status']);
    final createdAt = _formatDateTime(parcel['created_at']);
    final senderName = _str(parcel['sender_name']);
    final senderPhone = _str(parcel['sender_phone']);
    final senderEmail = nz(parcel['sender_email']);
    final receiverName = _str(parcel['receiver_name']);
    // Receiver contact might be sent as receiver_phone or receiver_contact
    final receiverPhone = _str(
      parcel['receiver_phone'] ?? parcel['receiver_contact'],
    );
    final receiverEmail = nz(parcel['receiver_email']);
    final origin = _str(parcel['origin']);
    final destination = _str(parcel['destination']);
    final amount = _amount(parcel['amount']);
    final description = parcel['description']?.toString();

    final parcelName = nz(parcel['parcel_name']);
    final quantityRaw = parcel['quantity'];
    final quantityStr = quantityRaw == null ? '—' : quantityRaw.toString();
    final weightLabel = _weightBandLabel(parcel['weight_band']);
    final creatorOffice = nz(parcel['creator_office']);
    final travelDate = _str(parcel['travel_date']);
    final transportedBus = parcel['transported_bus'] is Map
        ? parcel['transported_bus'] as Map<String, dynamic>
        : null;
    final primaryBus =
        transportedBus ??
        (parcel['bus'] is Map ? parcel['bus'] as Map<String, dynamic> : null);
    final busPlate = primaryBus?['plate_number']?.toString() ?? '—';
    final busRoute = primaryBus?['route_name']?.toString();
    // Creator info can be flattened or nested under created_by
    final createdByName = _str(
      parcel['created_by_name'] ??
          (parcel['created_by'] is Map
              ? (parcel['created_by'] as Map)['name']
              : null),
    );
    final createdByPhone = _str(
      parcel['created_by_phone'] ??
          (parcel['created_by'] is Map
              ? (parcel['created_by'] as Map)['phone']
              : null),
    );
    final transportedName = _str(parcel['transported_by_name']);
    final transportedRole = parcel['transported_by_role']?.toString() ?? '';
    final transportedByPhone = nz(parcel['transported_by_phone']);
    final receivedByStaffPhone = nz(parcel['received_by_phone']);

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text(
          'Parcel receipt',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        actions: [
          if (_refetchingParcel)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, size: 22),
              tooltip: 'Refresh',
              onPressed: _refreshParcel,
            ),
          if (_loadingPrinter)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(
                Icons.print_outlined,
                size: 22,
                color: _printBusy ? Colors.white54 : Colors.white,
              ),
              tooltip: 'Print to device printer',
              onPressed: _printBusy ? null : _printReceipt,
            ),
            IconButton(
              icon: Icon(
                Icons.picture_as_pdf_outlined,
                size: 22,
                color: _printBusy ? Colors.white54 : Colors.white,
              ),
              tooltip: 'Print or save as PDF',
              onPressed: _printBusy ? null : _printReceiptPdf,
            ),
            PopupMenuButton<String>(
              tooltip: 'Printer',
              icon: const Icon(Icons.more_vert, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onSelected: (value) {
                if (value == 'choose') {
                  _choosePrinter();
                } else if (value == 'print') {
                  _printReceipt();
                } else if (value == 'pdf') {
                  _printReceiptPdf();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'print',
                  enabled: !_printBusy,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.print_outlined, size: 20, color: Colors.grey.shade800),
                    title: Text('Print to printer', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  enabled: !_printBusy,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.grey.shade800),
                    title: Text('Print / save as PDF', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                ),
                PopupMenuItem(
                  value: 'choose',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.bluetooth_searching, size: 20, color: Colors.grey.shade800),
                    title: Text('Choose printer', style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.redBar,
        onRefresh: _refreshParcel,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Center(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              elevation: 6,
              shadowColor: AppColors.darkBlue.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailReceiptHeaderBand(),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: Image.asset(
                                'asset/logo.webp',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.directions_bus_filled_rounded,
                                  size: 76,
                                  color: AppColors.darkBlue,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'TRACKING',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tracking,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _statusChip('Status', status.toUpperCase()),
                            if (createdAt != '—')
                              _statusChip('Created', createdAt),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _detailReceiptHairline(),
                        const SizedBox(height: 16),

                        if (parcelName != '—' ||
                            quantityStr != '—' ||
                            weightLabel != '—' ||
                            creatorOffice != '—') ...[
                          _detailSectionTitle('Shipment'),
                          if (parcelName != '—')
                            _detailKvRow('Parcel name', parcelName),
                          if (quantityStr != '—')
                            _detailKvRow('Quantity', quantityStr),
                          if (weightLabel != '—')
                            _detailKvRow('Weight', weightLabel),
                          if (creatorOffice != '—')
                            _detailKvRow('Creator office', creatorOffice),
                          const SizedBox(height: 14),
                        ],

                        _detailSectionTitle('Parties'),
                        _detailKvRow('Sender', senderName),
                        _detailKvRow('Sender phone', senderPhone),
                        if (senderEmail != '—')
                          _detailKvRow('Sender email', senderEmail),
                        const SizedBox(height: 6),
                        _detailKvRow('Receiver', receiverName),
                        _detailKvRow('Receiver phone', receiverPhone),
                        if (receiverEmail != '—')
                          _detailKvRow('Receiver email', receiverEmail),
                        const SizedBox(height: 14),

                        if (createdByName != '—' || createdByPhone != '—') ...[
                          _detailSectionTitle('Staff'),
                          if (createdByName != '—')
                            _detailKvRow('Created by', createdByName),
                          if (createdByPhone != '—')
                            _detailKvRow('Creator contact', createdByPhone),
                          const SizedBox(height: 14),
                        ],

                        _detailSectionTitle('Route'),
                        _detailKvRow('From → To', '$origin  →  $destination'),
                        _detailKvRow('Travel date', travelDate),
                        const SizedBox(height: 14),

                        if (parcel['transported_at'] != null ||
                            parcel['received_at'] != null) ...[
                          _detailSectionTitle('Handover'),
                          if (parcel['transported_at'] != null) ...[
                            _detailKvRow(
                              'Given to',
                              transportedRole.isEmpty
                                  ? transportedName
                                  : '$transportedName · $transportedRole',
                            ),
                            if (transportedByPhone != '—')
                              _detailKvRow('Transporter phone', transportedByPhone),
                            _detailKvRow(
                              'Bus / route',
                              '$busPlate · ${parcel['transported_route'] ?? (busRoute ?? '—')}',
                            ),
                            _detailKvRow(
                              'Handed over at',
                              _str(parcel['transported_at']),
                            ),
                          ],
                          if (parcel['received_at'] != null) ...[
                            _detailKvRow(
                              'Received by',
                              parcel['received_by_name'] ?? '—',
                            ),
                            if (receivedByStaffPhone != '—')
                              _detailKvRow('Receiver (staff) phone', receivedByStaffPhone),
                            _detailKvRow(
                              'Received at',
                              _str(parcel['received_at']),
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],

                        _detailReceiptHairline(),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.teal.shade50.withValues(alpha: 0.55),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AMOUNT',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    'TZS ${NumberFormat('#,###', 'en_US').format(amount.round())}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 32,
                                color: Colors.green.shade700.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),

                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _detailSectionTitle('Notes'),
                          Text(
                            description,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              height: 1.45,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),
                        _detailReceiptHairline(),
                        const SizedBox(height: 16),
                        Text(
                          'SCAN TO VERIFY',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: tracking,
                              version: QrVersions.auto,
                              size: 140,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.darkBlue,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: AppColors.darkBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          tracking,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.darkBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _detailReceiptHairline(),
                        const SizedBox(height: 12),
                        Text(
                          'Thank you for choosing Tilisho',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'www.tilishosafari.co.tz',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_loadingPrinter && _selection.type != PrinterType.none)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Printer: ${_selection.label}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                                height: 1.25,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.popUntil(
                                context,
                                ModalRoute.withName('/dashboard'),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.darkBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Back to Home'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _detailReceiptHeaderBand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkBlue,
            AppColors.primaryBlue,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'TILISHO',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 4.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Parcel receipt',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailReceiptHairline() {
    return Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.circle, size: 5, color: Colors.grey.shade300),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _detailSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.redBar,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailKvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade800),
          children: [
            TextSpan(
              text: '$k · ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _PrinterPickerSheet extends StatefulWidget {
  const _PrinterPickerSheet({
    required this.printerService,
    required this.current,
    required this.showBuiltIn,
    required this.onSelected,
  });

  final PrinterService printerService;
  final PrinterSelection current;
  final bool showBuiltIn;
  final Future<void> Function(PrinterSelection selection) onSelected;

  @override
  State<_PrinterPickerSheet> createState() => _PrinterPickerSheetState();
}

class _PrinterPickerSheetState extends State<_PrinterPickerSheet> {
  bool _loading = true;
  List<dynamic> _devices = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devs = await widget.printerService.getBondedBluetoothPrinters();
      if (!mounted) return;
      setState(() {
        _devices = devs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose printer',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.showBuiltIn)
              ListTile(
                leading: const Icon(Icons.print),
                title: const Text('Built-in printer'),
                subtitle: const Text('Default device printer'),
                trailing: widget.current.type == PrinterType.builtIn
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => widget.onSelected(
                  const PrinterSelection(
                    type: PrinterType.builtIn,
                    name: 'Built-in printer',
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('None'),
              trailing: widget.current.type == PrinterType.none
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => widget.onSelected(
                const PrinterSelection(type: PrinterType.none),
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bluetooth printers (paired)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              )
            else if (_devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No paired bluetooth printers found.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (context, i) {
                    final d = _devices[i];
                    final name = (d.name?.toString() ?? '').isEmpty
                        ? 'Bluetooth printer'
                        : d.name.toString();
                    final addr = d.address?.toString() ?? '';
                    final isSel =
                        widget.current.type == PrinterType.bluetooth &&
                        widget.current.address == addr;
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(name),
                      subtitle: Text(addr),
                      trailing: isSel ? const Icon(Icons.check) : null,
                      onTap: () => widget.onSelected(
                        PrinterSelection(
                          type: PrinterType.bluetooth,
                          name: name,
                          address: addr,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
