import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:t_percel/main.dart';

class ParcelDetailPage extends StatelessWidget {
  const ParcelDetailPage({super.key, required this.parcel});

  final Map<String, dynamic> parcel;

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
  Widget build(BuildContext context) {
    final tracking = _str(parcel['tracking_number']);
    final status = _str(parcel['status']);
    final createdAt = _formatDateTime(parcel['created_at']);
    final senderName = _str(parcel['sender_name']);
    final senderPhone = _str(parcel['sender_phone']);
    final receiverName = _str(parcel['receiver_name']);
    // Receiver contact might be sent as receiver_phone or receiver_contact
    final receiverPhone = _str(parcel['receiver_phone'] ?? parcel['receiver_contact']);
    final origin = _str(parcel['origin']);
    final destination = _str(parcel['destination']);
    final amount = _amount(parcel['amount']);
    final description = parcel['description']?.toString();
    final travelDate = _str(parcel['travel_date']);
    final startTime = _str(parcel['start_travel_time']);
    final endTime = _str(parcel['end_travel_time']);
    final transportedBus = parcel['transported_bus'] is Map
        ? parcel['transported_bus'] as Map<String, dynamic>
        : null;
    final primaryBus = transportedBus ?? (parcel['bus'] is Map ? parcel['bus'] as Map<String, dynamic> : null);
    final busPlate = primaryBus?['plate_number']?.toString() ?? '—';
    final busRoute = primaryBus?['route_name']?.toString();
    final timeDisplay = startTime != '—' && endTime != '—'
        ? '$startTime – $endTime'
        : (startTime != '—' ? startTime : endTime);
    // Creator info can be flattened or nested under created_by
    final createdByName = _str(
      parcel['created_by_name'] ??
          (parcel['created_by'] is Map ? (parcel['created_by'] as Map)['name'] : null),
    );
    final createdByPhone = _str(
      parcel['created_by_phone'] ??
          (parcel['created_by'] is Map ? (parcel['created_by'] as Map)['phone'] : null),
    );
    final transportedName = _str(parcel['transported_by_name']);
    final transportedRole = parcel['transported_by_role']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text('Parcel receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                  if (parcel['transported_at'] != null || parcel['received_at'] != null) ...[
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
                      _receiptKeyValue('IMPORTED AT', _str(parcel['transported_at'])),
                    ],
                    if (parcel['transported_at'] != null && parcel['received_at'] != null) ...[
                      _textDivider(),
                    ],
                    if (parcel['received_at'] != null) ...[
                      _receiptKeyValue('RECEIVED BY', parcel['received_by_name'] ?? '—'),
                      _receiptKeyValue('RECEIVED AT', _str(parcel['received_at'])),
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
                        Navigator.popUntil(context, ModalRoute.withName('/dashboard'));
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Back to Home'),
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

  Widget _receiptLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _receiptLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.35,
          color: Colors.black87,
        ),
      ),
    );
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
