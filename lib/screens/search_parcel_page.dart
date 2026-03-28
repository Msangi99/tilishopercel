import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/parcel_detail_page.dart';
import 'package:t_percel/services/api_service.dart';

class SearchParcelPage extends StatefulWidget {
  const SearchParcelPage({super.key});

  @override
  State<SearchParcelPage> createState() => _SearchParcelPageState();
}

class _SearchParcelPageState extends State<SearchParcelPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _refresh() async {
    final tracking = _controller.text.trim();
    if (tracking.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a tracking number to search'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _search();
  }

  Future<void> _search() async {
    final tracking = _controller.text.trim();
    if (tracking.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.viewParcel(tracking);
      final parcel = data['parcel'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (parcel == null) {
        throw Exception('No parcel found for this tracking number');
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ParcelDetailPage(parcel: parcel),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Parcel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            color: AppColors.redBar,
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
            Text(
              'Search by tracking number',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter parcel tracking number',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _search,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Search'),
            ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

