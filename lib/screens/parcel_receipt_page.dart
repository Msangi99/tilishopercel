import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/my_parcels_page.dart';
import 'package:t_percel/services/printer_service.dart';

/// Shown after a parcel is created successfully (customer-style receipt).
class ParcelReceiptPage extends StatelessWidget {
  const ParcelReceiptPage({super.key, required this.parcel});

  final Map<String, dynamic> parcel;

  String _str(dynamic v) => v?.toString() ?? '—';

  String _nz(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? '—' : s;
  }

  double _amount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static TextStyle _labelStyle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Colors.grey.shade600,
      );

  static TextStyle _valueStyle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: Colors.grey.shade900,
      );

  @override
  Widget build(BuildContext context) {
    final tracking = _str(parcel['tracking_number']);
    final amountFmt = NumberFormat('#,###', 'en_US').format(_amount(parcel['amount']).round());
    String travel = _str(parcel['travel_date']);
    try {
      if (parcel['travel_date'] != null) {
        travel = DateFormat.yMMMEd().format(DateTime.parse(parcel['travel_date'].toString()));
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: const Color(0xFFE4E9F2),
      appBar: AppBar(
        title: Text('Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Print or save as PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
            onPressed: () => _openParcelReceiptPdf(context, parcel),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                elevation: 6,
                shadowColor: AppColors.darkBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReceiptHeaderBand(),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
                                width: 132,
                                height: 132,
                                child: Image.asset(
                                  'asset/logo.webp',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.directions_bus_filled_rounded,
                                    size: 72,
                                    color: AppColors.darkBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green.shade700,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Parcel registered',
                                      style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Keep this receipt for your records',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'TRACKING NUMBER',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            tracking,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.robotoMono(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.darkBlue,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Present this code at the counter when collecting',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ReceiptHairline(),
                          const SizedBox(height: 18),
                          _ReceiptSectionTitle('Shipment'),
                          _ReceiptKvRow(
                            label: 'Parcel',
                            value: _str(parcel['parcel_name']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          _ReceiptKvRow(
                            label: 'Quantity',
                            value: _str(parcel['quantity']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          _ReceiptKvRow(
                            label: 'Travel date',
                            value: travel,
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          const SizedBox(height: 14),
                          _ReceiptSectionTitle('Route'),
                          _ReceiptKvRow(
                            label: 'From',
                            value: _str(parcel['origin']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          _ReceiptKvRow(
                            label: 'To',
                            value: _str(parcel['destination']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          const SizedBox(height: 14),
                          _ReceiptSectionTitle('Parties'),
                          _ReceiptKvRow(
                            label: 'Sender',
                            value: _str(parcel['sender_name']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          _ReceiptKvRow(
                            label: 'Sender phone',
                            value: _str(parcel['sender_phone']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          if (parcel['sender_email'] != null &&
                              parcel['sender_email'].toString().trim().isNotEmpty)
                            _ReceiptKvRow(
                              label: 'Sender email',
                              value: _str(parcel['sender_email']),
                              labelStyle: _labelStyle(context),
                              valueStyle: _valueStyle(context),
                            ),
                          _ReceiptKvRow(
                            label: 'Receiver',
                            value: _str(parcel['receiver_name']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          _ReceiptKvRow(
                            label: 'Receiver phone',
                            value: _str(parcel['receiver_phone']),
                            labelStyle: _labelStyle(context),
                            valueStyle: _valueStyle(context),
                          ),
                          if (parcel['receiver_email'] != null &&
                              parcel['receiver_email'].toString().trim().isNotEmpty)
                            _ReceiptKvRow(
                              label: 'Receiver email',
                              value: _str(parcel['receiver_email']),
                              labelStyle: _labelStyle(context),
                              valueStyle: _valueStyle(context),
                            ),
                          if (parcel['transported_at'] != null ||
                              parcel['received_at'] != null) ...[
                            const SizedBox(height: 14),
                            _ReceiptSectionTitle('Handover'),
                            if (parcel['transported_at'] != null) ...[
                              _ReceiptKvRow(
                                label: 'Given to',
                                value: _str(parcel['transported_by_name']),
                                labelStyle: _labelStyle(context),
                                valueStyle: _valueStyle(context),
                              ),
                              if (_nz(parcel['transported_by_phone']) != '—')
                                _ReceiptKvRow(
                                  label: 'Transporter phone',
                                  value: _nz(parcel['transported_by_phone']),
                                  labelStyle: _labelStyle(context),
                                  valueStyle: _valueStyle(context),
                                ),
                              _ReceiptKvRow(
                                label: 'Handed over at',
                                value: _str(parcel['transported_at']),
                                labelStyle: _labelStyle(context),
                                valueStyle: _valueStyle(context),
                              ),
                            ],
                            if (parcel['received_at'] != null) ...[
                              _ReceiptKvRow(
                                label: 'Received by (staff)',
                                value: _str(parcel['received_by_name']),
                                labelStyle: _labelStyle(context),
                                valueStyle: _valueStyle(context),
                              ),
                              if (_nz(parcel['received_by_phone']) != '—')
                                _ReceiptKvRow(
                                  label: 'Staff receiver phone',
                                  value: _nz(parcel['received_by_phone']),
                                  labelStyle: _labelStyle(context),
                                  valueStyle: _valueStyle(context),
                                ),
                              _ReceiptKvRow(
                                label: 'Received at',
                                value: _str(parcel['received_at']),
                                labelStyle: _labelStyle(context),
                                valueStyle: _valueStyle(context),
                              ),
                            ],
                          ],
                          if (parcel['description'] != null &&
                              parcel['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _ReceiptSectionTitle('Notes'),
                            Text(
                              _str(parcel['description']),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.45,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _ReceiptHairline(),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.teal.shade50.withValues(alpha: 0.6),
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
                                      'TOTAL FARE',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'TZS $amountFmt',
                                      style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.payments_rounded,
                                  size: 36,
                                  color: Colors.green.shade700.withValues(alpha: 0.45),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _ReceiptHairline(),
                          const SizedBox(height: 18),
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
                                size: 132,
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
                          const SizedBox(height: 20),
                          _ReceiptHairline(),
                          const SizedBox(height: 14),
                          Text(
                            'TILISHO PARCEL',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'www.tilishosafari.co.tz',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (context) => const MyParcelsPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('My parcels', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptHeaderBand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Official receipt',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptSectionTitle extends StatelessWidget {
  const _ReceiptSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
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
              letterSpacing: 1,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptKvRow extends StatelessWidget {
  const _ReceiptKvRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Text(label, style: labelStyle),
          ),
          Expanded(
            flex: 14,
            child: Text(
              value,
              style: valueStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptHairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}

Future<void> _openParcelReceiptPdf(
  BuildContext context,
  Map<String, dynamic> parcel,
) async {
  try {
    final usedShare = await PrinterService().printReceiptAsPdf(parcel);
    if (!context.mounted) return;
    if (usedShare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pick an app to save as PDF or print.',
            style: GoogleFonts.poppins(fontSize: 13, height: 1.35),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    var msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.isEmpty) msg = 'Could not open PDF. Please try again.';
    if (msg.length > 140) msg = '${msg.substring(0, 137)}…';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13, height: 1.35)),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      ),
    );
  }
}
