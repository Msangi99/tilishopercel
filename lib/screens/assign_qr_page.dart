import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/parcel_detail_page.dart';
import 'package:t_percel/services/api_service.dart';

class AssignQrPage extends StatefulWidget {
  const AssignQrPage({super.key});

  @override
  State<AssignQrPage> createState() => _AssignQrPageState();
}

class _AssignQrPageState extends State<AssignQrPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _controller.stop();
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue ?? barcode?.displayValue;
    if (value == null || value.isEmpty) return;

    final tracking = value.trim();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignOptionsPage(trackingNumber: tracking),
      ),
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Parcel QR', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Scan parcel QR and choose whether you are the transporter or receiver.',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Assigned information will appear on the parcel receipt for all viewers.',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/search-parcel');
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search by Tracking Number'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssignOptionsPage extends StatefulWidget {
  const AssignOptionsPage({super.key, required this.trackingNumber});

  final String trackingNumber;

  @override
  State<AssignOptionsPage> createState() => _AssignOptionsPageState();
}

class _AssignOptionsPageState extends State<AssignOptionsPage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.getSavedUser(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        final assignedBusId = user?['assigned_bus']?['id'];
        return _AssignTransporterReceiverView(
          trackingNumber: widget.trackingNumber,
          assignedBusId: assignedBusId,
          currentUserName: user?['name']?.toString(),
        );
      },
    );
  }
}

class WorkerOption {
  WorkerOption({
    required this.workerName,
    required this.role,
    required this.busPlate,
    required this.routeName,
    required this.busId,
  });

  final String workerName;
  final String role;
  final String busPlate;
  final String routeName;
  final int busId;
}

class _AssignTransporterReceiverView extends StatefulWidget {
  const _AssignTransporterReceiverView({
    required this.trackingNumber,
    required this.assignedBusId,
    required this.currentUserName,
  });

  final String trackingNumber;
  final int? assignedBusId;
  final String? currentUserName;

  @override
  State<_AssignTransporterReceiverView> createState() => _AssignTransporterReceiverViewState();
}

class _AssignTransporterReceiverViewState extends State<_AssignTransporterReceiverView> {
  bool _isSaving = false;
  List<WorkerOption> _options = [];
  List<WorkerOption> _filtered = [];
  WorkerOption? _selected;
  bool _loadingWorkers = true;
  String _search = '';
  Map<String, dynamic>? _parcel;
  bool _loadingParcel = true;
  int? _transportedBusId;
  int? _transportedBusCapacity;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingWorkers = true;
      _loadingParcel = true;
    });
    try {
      final data = await ApiService.viewParcel(widget.trackingNumber);
      _parcel = data['parcel'] as Map<String, dynamic>?;
      if (_parcel != null) {
        // If parcel is already received, just show its info instead of assignment UI
        final receivedName = _parcel!['received_by_name']?.toString();
        if (receivedName != null && receivedName.isNotEmpty) {
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ParcelDetailPage(parcel: _parcel!)),
            );
            if (mounted) {
              Navigator.pop(context);
            }
          }
          return;
        }

        final tbId = _parcel!['transported_bus_id'];
        if (tbId is num) {
          _transportedBusId = tbId.toInt();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _loadingParcel = false;
      if (mounted) {
        setState(() {});
      }
    }
    await _loadWorkers();
    // Try to resolve transported bus capacity from loaded buses/options
    if (_transportedBusId != null) {
      // options are built from buses; capacity is not in WorkerOption, but
      // we can approximate by looking at any worker with same busId.
      final match = _options.firstWhere(
        (o) => o.busId == _transportedBusId,
        orElse: () => _options.isNotEmpty ? _options.first : WorkerOption(workerName: '', role: '', busPlate: '', routeName: '', busId: -1),
      );
      if (match.busId == _transportedBusId) {
        // capacity is not exposed; leave as null for now
        _transportedBusCapacity = null;
      }
    }
  }

  Future<void> _loadWorkers() async {
    try {
      final buses = await ApiService.getBuses();
      final busId = widget.assignedBusId;
      final Iterable<dynamic> source = busId == null
          ? buses
          : buses.where((b) => b is Map && b['id'] == busId);

      final List<WorkerOption> options = [];
      for (final b in source) {
        if (b is! Map) continue;
        final plate = b['plate_number']?.toString() ?? '';
        final route = b['route_name']?.toString() ?? '';
        final id = (b['id'] as num).toInt();

        // After backend change, drivers / conductors / attendants may be
        // either:
        // - List<Map> with { name, phone, ... }  (old format)
        // - List<int|string> of user_ids         (new format)
        // We defensive‑code here to avoid type errors and only use entries
        // where we can safely derive a display name.

        for (final d in (b['drivers'] as List?) ?? []) {
          String name = '';
          if (d is Map) {
            // New API format: { id, name, role }
            name = (d['name'] ?? '').toString();
          } else if (d is String) {
            name = d;
          } else if (d is num) {
            // Fallback if backend ever sends raw IDs
            name = 'Driver #${d.toInt()}';
          }
          if (name.isNotEmpty) {
            options.add(WorkerOption(
              workerName: name,
              role: 'driver',
              busPlate: plate,
              routeName: route,
              busId: id,
            ));
          }
        }

        for (final c in (b['conductors'] as List?) ?? []) {
          String name = '';
          if (c is Map) {
            name = (c['name'] ?? '').toString();
          } else if (c is String) {
            name = c;
          } else if (c is num) {
            name = 'Conductor #${c.toInt()}';
          }
          if (name.isNotEmpty) {
            options.add(WorkerOption(
              workerName: name,
              role: 'conductor',
              busPlate: plate,
              routeName: route,
              busId: id,
            ));
          }
        }

        for (final a in (b['attendants'] as List?) ?? []) {
          String name = '';
          if (a is Map) {
            name = (a['name'] ?? '').toString();
          } else if (a is String) {
            name = a;
          } else if (a is num) {
            name = 'Attendant #${a.toInt()}';
          }
          if (name.isNotEmpty) {
            options.add(WorkerOption(
              workerName: name,
              role: 'attendant',
              busPlate: plate,
              routeName: route,
              busId: id,
            ));
          }
        }
      }
      setState(() {
        _options = options;
        _applyFilter();
        _loadingWorkers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingWorkers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = List.of(_options);
    } else {
      _filtered = _options
          .where((o) => o.workerName.toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }
  }

  Future<void> _assignTransporter() async {
    if (_isSaving) return;
    if (_selected == null) return;
    if (_parcel != null && _parcel!['transported_by_name'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parcel hii tayari ina transporter aliyerekodiwa. Huwezi kubadilisha hapa.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = await ApiService.assignTransporter(
        widget.trackingNumber,
        workerName: _selected!.workerName,
        workerRole: _selected!.role,
      );
      final parcel = data['parcel'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (parcel == null) {
        throw Exception('Hakuna parcel iliyo patikana kwa QR hii');
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ParcelDetailPage(parcel: parcel)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _assignReceiver() async {
    if (_isSaving) return;
    if (_parcel != null) {
      final transportedName = _parcel!['transported_by_name']?.toString();
      final receivedName = _parcel!['received_by_name']?.toString();
      if (transportedName != null && transportedName.isNotEmpty && receivedName != null && receivedName.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcel hii tayari ina transporter na imepokelewa. Huwezi kuipokea tena.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Prevent same person being both transporter and receiver
      final currentUserName = widget.currentUserName?.trim().toLowerCase();
      if (transportedName != null &&
          transportedName.trim().isNotEmpty &&
          currentUserName != null &&
          currentUserName.isNotEmpty &&
          transportedName.trim().toLowerCase() == currentUserName) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Huwezi kuwa transporter na receiver wa parcel hii.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    setState(() => _isSaving = true);
    try {
      final data = await ApiService.assignReceiver(widget.trackingNumber);
      final parcel = data['parcel'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (parcel == null) {
        throw Exception('Hakuna parcel iliyo patikana kwa QR hii');
      }

      // Go to a success screen with animation and Back Home
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParcelReceivedSuccessPage(parcel: parcel),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Parcel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Parcel: ${widget.trackingNumber}',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (_parcel != null && _parcel!['transported_by_name'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Transporter: ${_parcel!['transported_by_name']}',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.green.shade800),
              ),
              if (_parcel!['transported_route'] != null)
                Text(
                  'Route: ${_parcel!['transported_route']}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                ),
              if (_transportedBusCapacity != null)
                Text(
                  'Size: $_transportedBusCapacity seats',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Select transporter (bus worker) or mark this parcel as received.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            if (_loadingWorkers || _loadingParcel)
              const Center(child: CircularProgressIndicator())
            else if (_parcel != null && _parcel!['transported_by_name'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Transporter already assigned. You can only mark as receiver.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _assignReceiver,
                icon: const Icon(Icons.person),
                label: const Text('Mark as Receiver'),
              ),
            ] else ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search worker name',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _search = value;
                    _applyFilter();
                  });
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final opt = _filtered[index];
                    final roleLabel = opt.role.isEmpty
                        ? ''
                        : opt.role[0].toUpperCase() + opt.role.substring(1).toLowerCase();
                    final title = roleLabel.isEmpty
                        ? opt.workerName
                        : '${opt.workerName} - $roleLabel';
                    final subtitle =
                        '${opt.busPlate} · ${opt.routeName.isEmpty ? 'No Route' : opt.routeName}';
                    return ListTile(
                      title: Text(title, style: GoogleFonts.poppins(fontSize: 14)),
                      subtitle: Text(subtitle,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey.shade700)),
                      onTap: () {
                        setState(() => _selected = opt);
                      },
                      selected: _selected == opt,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_selected == null || _isSaving) ? null : _assignTransporter,
                icon: const Icon(Icons.local_shipping),
                label: const Text('Assign Transporter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _assignReceiver,
                icon: const Icon(Icons.person),
                label: const Text('Mark as Receiver'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ParcelReceivedSuccessPage extends StatefulWidget {
  const ParcelReceivedSuccessPage({super.key, required this.parcel});

  final Map<String, dynamic> parcel;

  @override
  State<ParcelReceivedSuccessPage> createState() => _ParcelReceivedSuccessPageState();
}

class _ParcelReceivedSuccessPageState extends State<ParcelReceivedSuccessPage>
    with SingleTickerProviderStateMixin {
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    // Trigger animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _animate = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _animate ? 1 : 0.7,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _animate ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Parcel received successfully',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tracking: ${widget.parcel['tracking_number'] ?? '—'}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, ModalRoute.withName('/dashboard'));
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

