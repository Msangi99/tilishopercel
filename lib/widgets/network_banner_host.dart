import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Same as [AppColors.redBar] in main.dart (kept here to avoid import cycle).
const Color _kNetworkBannerColor = Color(0xFFB71C1C);

bool _isOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}

/// Wraps the app below [MaterialApp] and shows a top banner when there is no network.
class NetworkBannerHost extends StatefulWidget {
  const NetworkBannerHost({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkBannerHost> createState() => _NetworkBannerHostState();
}

class _NetworkBannerHostState extends State<NetworkBannerHost> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _connectivity.checkConnectivity().then(_apply);
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final next = _isOnline(results);
    if (mounted && next != _online) {
      setState(() => _online = next);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_online)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 4,
              color: _kNetworkBannerColor,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No network connection',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
    );
  }
}
