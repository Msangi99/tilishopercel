import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue ?? barcode?.displayValue;
    if (value == null || value.isEmpty) return;

    setState(() => _isProcessing = true);
    _controller.stop();

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
      backgroundColor: const Color(0xFFE4E9F2),
      appBar: AppBar(
        title: Text(
          'Assign parcel QR',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        elevation: 0,
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
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 248,
                    height: 248,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black38,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Material(
                elevation: 6,
                shadowColor: AppColors.darkBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.assignment_ind_rounded,
                              color: AppColors.primaryBlue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Link crew or receiver',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Scan the parcel code, then assign transporter or mark received.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Assignments show on the parcel receipt for everyone who views it.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/search-parcel');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 22),
                        label: Text(
                          'Search by tracking number',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => _controller.switchCamera(),
                            icon: const Icon(Icons.flip_camera_android_rounded),
                            tooltip: 'Switch camera',
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: () => _controller.toggleTorch(),
                            icon: const Icon(Icons.flashlight_on_rounded),
                            tooltip: 'Toggle flash',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
          return Scaffold(
            backgroundColor: const Color(0xFFE4E9F2),
            appBar: AppBar(
              title: Text(
                'Assign parcel',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.redBar,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your profile…',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
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
  State<_AssignTransporterReceiverView> createState() =>
      _AssignTransporterReceiverViewState();
}

class _AssignTransporterReceiverViewState
    extends State<_AssignTransporterReceiverView> {
  bool _isSaving = false;
  List<WorkerOption> _options = [];
  List<WorkerOption> _filtered = [];
  WorkerOption? _selected;
  bool _loadingWorkers = true;
  String _search = '';
  Map<String, dynamic>? _parcel;
  bool _loadingParcel = true;

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
              MaterialPageRoute(
                builder: (_) => ParcelDetailPage(parcel: _parcel!),
              ),
            );
            if (mounted) {
              Navigator.pop(context);
            }
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade800,
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
            options.add(
              WorkerOption(
                workerName: name,
                role: 'driver',
                busPlate: plate,
                routeName: route,
                busId: id,
              ),
            );
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
            options.add(
              WorkerOption(
                workerName: name,
                role: 'conductor',
                busPlate: plate,
                routeName: route,
                busId: id,
              ),
            );
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
            options.add(
              WorkerOption(
                workerName: name,
                role: 'attendant',
                busPlate: plate,
                routeName: route,
                busId: id,
              ),
            );
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
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = List.of(_options);
    } else {
      _filtered = _options
          .where(
            (o) => o.workerName.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
    }
  }

  Future<void> _assignTransporter() async {
    if (_isSaving) return;
    if (_selected == null) return;
    if (_parcel != null && _parcel!['transported_by_name'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This parcel already has a recorded transporter. It cannot be changed here.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          backgroundColor: Colors.red.shade800,
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
        throw Exception('No parcel found for this QR code');
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
          backgroundColor: Colors.red.shade800,
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
      if (transportedName != null &&
          transportedName.isNotEmpty &&
          receivedName != null &&
          receivedName.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This parcel already has a transporter and has been received. You cannot receive it again.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.red.shade800,
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
          SnackBar(
            content: Text(
              'You cannot be both transporter and receiver for this parcel.',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: Colors.red.shade800,
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
        throw Exception('No parcel found for this QR code');
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
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transportedName = _parcel?['transported_by_name']?.toString();
    final receivedName = _parcel?['received_by_name']?.toString();
    final hasTransporter =
        transportedName != null && transportedName.trim().isNotEmpty;
    final hasReceiver = receivedName != null && receivedName.trim().isNotEmpty;
    final tracking = widget.trackingNumber;

    return Scaffold(
      backgroundColor: const Color(0xFFE4E9F2),
      appBar: AppBar(
        title: Text(
          'Assign parcel',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Material(
                    elevation: 6,
                    shadowColor: AppColors.darkBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _assignHeaderBand(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: tracking,
                                    version: QrVersions.auto,
                                    size: 120,
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
                              const SizedBox(height: 10),
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
                              SelectableText(
                                tracking,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.darkBlue,
                                  height: 1.2,
                                ),
                              ),
                              if (_parcel != null) ...[
                                const SizedBox(height: 18),
                                _assignHairline(),
                                const SizedBox(height: 14),
                                _assignSectionTitle('Status'),
                                const SizedBox(height: 8),
                                _buildStatusCard(
                                  hasTransporter: hasTransporter,
                                  hasReceiver: hasReceiver,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                'Choose a bus crew member as transporter, or mark the parcel as received.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
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
          if (_loadingWorkers || _loadingParcel)
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasTransporter && !hasReceiver)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.primaryBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Transporter is set. Confirm receipt as the next step.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _assignReceiver,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          'Set receiver (received)',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by worker name',
                            prefixIcon: Icon(Icons.search_rounded,
                                color: Colors.grey.shade600),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.primaryBlue,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          onChanged: (value) {
                            setState(() {
                              _search = value;
                              _applyFilter();
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    _options.isEmpty
                                        ? 'No bus crew is available for your assignment. Contact an administrator.'
                                        : 'No crew members match your search.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.35,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _filtered.length,
                                  separatorBuilder: (context, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final opt = _filtered[index];
                                    return _workerOptionTile(opt);
                                  },
                                ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: (_selected == null || _isSaving)
                              ? null
                              : _assignTransporter,
                          icon: const Icon(Icons.local_shipping_rounded),
                          label: Text(
                            'Assign transporter',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _assignReceiver,
                          icon: const Icon(Icons.how_to_reg_outlined),
                          label: Text(
                            'Mark as receiver',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.darkBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _assignHeaderBand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.darkBlue, AppColors.primaryBlue],
        ),
      ),
      child: Column(
        children: [
          Text(
            'TILISHO',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 4.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Parcel assignment',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assignHairline() {
    return Row(
      children: [
        Expanded(
            child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.circle, size: 5, color: Colors.grey.shade300),
        ),
        Expanded(
            child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _assignSectionTitle(String title) {
    return Row(
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
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'driver':
        return Icons.directions_bus_filled_rounded;
      case 'conductor':
        return Icons.airline_seat_recline_normal_rounded;
      case 'attendant':
        return Icons.support_agent_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Widget _workerOptionTile(WorkerOption opt) {
    final roleLabel = opt.role.isEmpty
        ? ''
        : opt.role[0].toUpperCase() + opt.role.substring(1).toLowerCase();
    final title = roleLabel.isEmpty ? opt.workerName : '${opt.workerName} · $roleLabel';
    final subtitle =
        '${opt.busPlate} · ${opt.routeName.isEmpty ? 'No route' : opt.routeName}';
    final selected = _selected == opt;

    return Material(
      color: selected
          ? AppColors.primaryBlue.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: selected ? 0 : 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () => setState(() => _selected = opt),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: selected
                    ? AppColors.primaryBlue.withValues(alpha: 0.2)
                    : Colors.grey.shade100,
                child: Icon(
                  _roleIcon(opt.role),
                  color: selected ? AppColors.darkBlue : Colors.grey.shade700,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: AppColors.primaryBlue, size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required bool hasTransporter,
    required bool hasReceiver,
  }) {
    final transporter = _parcel?['transported_by_name']?.toString();
    final transporterPhone = _parcel?['transported_by_phone']?.toString().trim();
    final route = _parcel?['transported_route']?.toString();
    final transportedAt = _parcel?['transported_at']?.toString();
    final receiver = _parcel?['received_by_name']?.toString();
    final receiverPhone = _parcel?['received_by_phone']?.toString().trim();
    final receivedAt = _parcel?['received_at']?.toString();

    Widget chip({
      required String label,
      required bool ok,
      required Color color,
      required IconData icon,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              ok ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 15,
              color: color,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip(
                label: 'Transport',
                ok: hasTransporter,
                color: Colors.green.shade700,
                icon: Icons.local_shipping_rounded,
              ),
              chip(
                label: 'Received',
                ok: hasReceiver,
                color: hasReceiver
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
                icon: Icons.inventory_2_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _assignKv('Transporter', hasTransporter ? (transporter ?? '—') : '—'),
          if (hasTransporter &&
              transporterPhone != null &&
              transporterPhone.isNotEmpty)
            _assignKv('Transporter phone', transporterPhone),
          if (route != null && route.trim().isNotEmpty) _assignKv('Route', route),
          if (transportedAt != null && transportedAt.trim().isNotEmpty)
            _assignKv('Transported at', transportedAt),
          if (hasReceiver) ...[
            const SizedBox(height: 4),
            _assignKv('Receiver', receiver ?? '—'),
            if (receiverPhone != null && receiverPhone.isNotEmpty)
              _assignKv('Receiver phone', receiverPhone),
            if (receivedAt != null && receivedAt.trim().isNotEmpty)
              _assignKv('Received at', receivedAt),
          ],
        ],
      ),
    );
  }

  Widget _assignKv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Text(
              k,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ParcelReceivedSuccessPage extends StatefulWidget {
  const ParcelReceivedSuccessPage({super.key, required this.parcel});

  final Map<String, dynamic> parcel;

  @override
  State<ParcelReceivedSuccessPage> createState() =>
      _ParcelReceivedSuccessPageState();
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
    final tracking = widget.parcel['tracking_number']?.toString() ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFFE4E9F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                elevation: 8,
                shadowColor: AppColors.darkBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.darkBlue, AppColors.primaryBlue],
                        ),
                      ),
                      child: Text(
                        'TILISHO',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        children: [
                          AnimatedScale(
                            scale: _animate ? 1 : 0.75,
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity: _animate ? 1 : 0,
                              duration: const Duration(milliseconds: 350),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 72,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Parcel received',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The handoff is recorded on the parcel receipt.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                          SelectableText(
                            tracking,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.robotoMono(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.darkBlue,
                            ),
                          ),
                          const SizedBox(height: 28),
                          FilledButton.icon(
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
                            icon: const Icon(Icons.home_rounded),
                            label: Text(
                              'Back to home',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
}
