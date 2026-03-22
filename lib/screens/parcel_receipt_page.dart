import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/my_parcels_page.dart';

/// Shown after a parcel is created successfully (customer-style receipt).
class ParcelReceiptPage extends StatelessWidget {
  const ParcelReceiptPage({super.key, required this.parcel});

  final Map<String, dynamic> parcel;

  String _str(dynamic v) => v?.toString() ?? '—';

  double _amount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Risiti', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parcel imeundwa',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              Text(
                                'Hifadhi namba ya ufuatiliaji',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'TRACKING',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            tracking,
                            style: GoogleFonts.robotoMono(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.darkBlue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _row('Jina la parcel', _str(parcel['parcel_name'])),
                    _row('Idadi', _str(parcel['quantity'])),
                    _row('Bei (TZS)', amountFmt),
                    _row('Kutoka', _str(parcel['origin'])),
                    _row('Kwenda', _str(parcel['destination'])),
                    _row('Tarehe ya safari', travel),
                    _row('Mtumaji', _str(parcel['sender_name'])),
                    _row('Simu mtumaji', _str(parcel['sender_phone'])),
                    _row('Mpokeaji', _str(parcel['receiver_name'])),
                    _row('Simu mpokeaji', _str(parcel['receiver_phone'])),
                    if (parcel['description'] != null && parcel['description'].toString().isNotEmpty)
                      _row('Maelezo', _str(parcel['description'])),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Text(
                      'TILISHO PARCEL',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Maliza', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
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
                  side: BorderSide(color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Parcels zangu', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
