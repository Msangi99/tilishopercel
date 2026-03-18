import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/parcel_detail_page.dart';
import 'package:t_percel/services/api_service.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
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

    try {
      final data = await ApiService.viewParcel(value.trim());
      final parcel = data['parcel'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (parcel == null) {
        throw Exception('Hakuna parcel iliyo patikana kwa QR hii');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParcelDetailPage(parcel: parcel),
        ),
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _controller.start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Parcel QR', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                    'Point the camera at the parcel QR code.',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'After scanning, parcel details will be shown in a receipt view.',
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
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.flip_camera_android),
                        onPressed: () => _controller.switchCamera(),
                        tooltip: 'Switch camera',
                      ),
                      IconButton(
                        icon: const Icon(Icons.flash_on),
                        onPressed: () => _controller.toggleTorch(),
                        tooltip: 'Toggle flash',
                      ),
                    ],
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

