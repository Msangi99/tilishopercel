import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:t_percel/services/printer_service.dart';
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
  bool _printing = false;

  static String _str(dynamic v) => v?.toString() ?? '—';

  static double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
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

  @override
  void initState() {
    super.initState();
    _initPrinter();
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

  Future<void> _printReceipt() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await _printerService.printReceipt(
        selection: _selection,
        parcel: widget.parcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Printed successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final tracking = _str(parcel['tracking_number']);
    final status = _str(parcel['status']);
    final createdAt = _formatDateTime(parcel['created_at']);
    final senderName = _str(parcel['sender_name']);
    final senderPhone = _str(parcel['sender_phone']);
    final receiverName = _str(parcel['receiver_name']);
    // Receiver contact might be sent as receiver_phone or receiver_contact
    final receiverPhone = _str(
      parcel['receiver_phone'] ?? parcel['receiver_contact'],
    );
    final origin = _str(parcel['origin']);
    final destination = _str(parcel['destination']);
    final amount = _amount(parcel['amount']);
    final description = parcel['description']?.toString();
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

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text(
          'Parcel receipt',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'TILISHO PARCEL',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Receipt',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      letterSpacing: 1,
                    ),
                  ),
                  _receiptDivider(),
                  const SizedBox(height: 16),

                  // QR + tracking
                  Center(
                    child: Column(
                      children: [
                        QrImageView(
                          data: tracking,
                          version: QrVersions.auto,
                          size: 160,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black87,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tracking,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${status.toUpperCase()}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (createdAt != '—')
                          Text(
                            'Created: $createdAt',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _receiptDivider(),
                  const SizedBox(height: 12),

                  // Sender
                  _receiptKeyValue('SENDER', senderName),
                  _receiptKeyValue('SENDER PHONE', senderPhone),
                  const SizedBox(height: 10),

                  // Receiver
                  _receiptKeyValue('RECEIVER', receiverName),
                  _receiptKeyValue('RECEIVER PHONE', receiverPhone),
                  _receiptDivider(),
                  const SizedBox(height: 8),

                  // Created by (before route)
                  if (createdByName != '—' || createdByPhone != '—') ...[
                    _receiptKeyValue('CREATED BY', createdByName),
                    _receiptKeyValue('CREATOR CONTACT', createdByPhone),
                    _receiptDivider(),
                    const SizedBox(height: 8),
                  ],

                  // Route
                  _receiptKeyValue('ROUTE', '$origin  →  $destination'),
                  const SizedBox(height: 10),

                  // Travel
                  _receiptKeyValue('TRAVEL DATE', travelDate),
                  _receiptDivider(),
                  const SizedBox(height: 8),

                  // Tracking info
                  if (parcel['transported_at'] != null ||
                      parcel['received_at'] != null) ...[
                    if (parcel['transported_at'] != null) ...[
                      _receiptKeyValue(
                        'GIVEN TO',
                        transportedRole.isEmpty
                            ? transportedName
                            : '$transportedName : $transportedRole',
                      ),
                      _receiptKeyValue(
                        'BUS',
                        '$busPlate -> ${parcel['transported_route'] ?? (busRoute ?? '—')}',
                      ),
                      _receiptKeyValue(
                        'IMPORTED AT',
                        _str(parcel['transported_at']),
                      ),
                    ],
                    if (parcel['transported_at'] != null &&
                        parcel['received_at'] != null) ...[
                      _textDivider(),
                    ],
                    if (parcel['received_at'] != null) ...[
                      _receiptKeyValue(
                        'RECEIVED BY',
                        parcel['received_by_name'] ?? '—',
                      ),
                      _receiptKeyValue(
                        'RECEIVED AT',
                        _str(parcel['received_at']),
                      ),
                    ],
                    _receiptDivider(),
                    const SizedBox(height: 8),
                  ],

                  // (Created by section moved above route)

                  // Amount (like total on receipt)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AMOUNT',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'TZS ${amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),

                  if (description != null && description.isNotEmpty) ...[
                    _receiptDivider(),
                    const SizedBox(height: 8),
                    _receiptKeyValue('NOTES', description),
                  ],

                  _receiptDivider(),
                  const SizedBox(height: 16),
                  Text(
                    'Thank you for using Tilisho',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.popUntil(
                          context,
                          ModalRoute.withName('/dashboard'),
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Home'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.print, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Printer',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadingPrinter
                                  ? null
                                  : _choosePrinter,
                              child: const Text('Choose'),
                            ),
                          ],
                        ),
                        Text(
                          _loadingPrinter
                              ? 'Detecting printer…'
                              : _selection.label,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: (_loadingPrinter || _printing)
                              ? null
                              : _printReceipt,
                          icon: _printing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print),
                          label: Text(
                            _printing ? 'Printing…' : 'Print receipt',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptDivider() {
    return _textDivider();
  }

  Widget _receiptKeyValue(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.4,
            color: Colors.black87,
          ),
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _textDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '-------------------------------------',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.grey.shade500,
          letterSpacing: 1.5,
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
