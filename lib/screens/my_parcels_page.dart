import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/parcel_detail_page.dart';
import 'package:t_percel/services/api_service.dart';

class MyParcelsPage extends StatefulWidget {
  const MyParcelsPage({super.key});

  @override
  State<MyParcelsPage> createState() => _MyParcelsPageState();
}

class _MyParcelsPageState extends State<MyParcelsPage> with SingleTickerProviderStateMixin {
  List<dynamic> _parcels = [];
  Map<String, dynamic>? _pagination;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  DateTime _filterDate = DateTime.now();
  String _searchText = '';
  String _statusFilter = 'all';
  int _tabIndex = 0;
  late final TabController _tabController;

  String get _type {
    switch (_tabIndex) {
      case 1:
        return 'transported';
      case 2:
        return 'received';
      default:
        return 'created';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: _tabIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        final next = _tabController.index;
        if (next != _tabIndex) {
          setState(() {
            _tabIndex = next;
            _parcels = [];
            _pagination = null;
            _error = null;
          });
          _loadPage(1);
        }
      }
    });
    _loadPage(1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _filterDateStr => DateFormat('yyyy-MM-dd').format(_filterDate);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _filterDate = picked;
        _parcels = [];
      });
      _loadPage(1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (page == 1) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await ApiService.getMyParcels(page: page, date: _filterDateStr, type: _type);
      final list = data['parcels'] is List ? data['parcels'] as List<dynamic> : [];
      final pagination = data['pagination'] is Map ? data['pagination'] as Map<String, dynamic> : null;

      if (mounted) {
        setState(() {
          if (page == 1) {
            _parcels = list;
          } else {
            _parcels = [..._parcels, ...list];
          }
          _pagination = pagination;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _error = msg;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _loadPage(1);
  }

  void _loadMore() {
    if (_isLoadingMore || _pagination == null) return;
    final current = (_pagination!['current_page'] as num?)?.toInt() ?? 1;
    final last = (_pagination!['last_page'] as num?)?.toInt() ?? 1;
    if (current >= last) return;
    _loadPage(current + 1);
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'scanned':
        return Colors.green;
      case 'in-transit':
      case 'packed':
        return Colors.orange;
      case 'arrived':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _filterDate.year == DateTime.now().year &&
        _filterDate.month == DateTime.now().month &&
        _filterDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Parcels', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(),
          _buildDateFilter(isToday),
          _buildFiltersRow(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: TabBar(
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorColor: AppColors.primaryBlue,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Created'),
          Tab(text: 'Transported'),
          Tab(text: 'Received'),
        ],
        controller: _tabController,
      ),
    );
  }

  Widget _buildDateFilter(bool isToday) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _pickDate,
                child: Text(
                  DateFormat('EEE, MMM d, yyyy').format(_filterDate),
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (!isToday)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _filterDate = DateTime.now();
                    _parcels = [];
                  });
                  _loadPage(1);
                },
                icon: const Icon(Icons.today, size: 18),
                label: Text('Today', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tracking / sender / receiver',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _statusFilter,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('All'),
              ),
              DropdownMenuItem(
                value: 'pending',
                child: Text('Pending'),
              ),
              DropdownMenuItem(
                value: 'packed',
                child: Text('Packed'),
              ),
              DropdownMenuItem(
                value: 'in-transit',
                child: Text('In-transit'),
              ),
              DropdownMenuItem(
                value: 'arrived',
                child: Text('Arrived'),
              ),
              DropdownMenuItem(
                value: 'received',
                child: Text('Received'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _statusFilter = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _parcels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _parcels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadPage(1),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Apply client-side filters
    final filteredParcels = _parcels.where((p) {
      final parcel = p as Map<String, dynamic>;
      final tracking = parcel['tracking_number']?.toString().toLowerCase() ?? '';
      final sender = parcel['sender_name']?.toString().toLowerCase() ?? '';
      final receiver = parcel['receiver_name']?.toString().toLowerCase() ?? '';
      final status = parcel['status']?.toString().toLowerCase() ?? '';

      final matchesSearch = _searchText.isEmpty
          ? true
          : (tracking.contains(_searchText.toLowerCase()) ||
              sender.contains(_searchText.toLowerCase()) ||
              receiver.contains(_searchText.toLowerCase()));

      final matchesStatus =
          _statusFilter == 'all' ? true : status == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();

    if (filteredParcels.isEmpty) {
      final emptyTitle = _tabIndex == 0
          ? 'No created parcels'
          : _tabIndex == 1
              ? 'No transported parcels'
              : 'No received parcels';
      final emptySub = _tabIndex == 0
          ? 'Parcels you create will appear here'
          : _tabIndex == 1
              ? 'Parcels you transported will appear here'
              : 'Parcels you received will appear here';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              emptySub,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final pagination = _pagination;
    final hasMore = pagination != null &&
        ((pagination['current_page'] as num?)?.toInt() ?? 1) <
            ((pagination['last_page'] as num?)?.toInt() ?? 1);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredParcels.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredParcels.length) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: _loadMore,
                child: const Text('Load more'),
              ),
            );
          }

          final parcel = filteredParcels[index] as Map<String, dynamic>;
          return _buildParcelCard(
            parcel,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ParcelDetailPage(parcel: parcel),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildParcelCard(Map<String, dynamic> parcel, {VoidCallback? onTap}) {
    final tracking = parcel['tracking_number']?.toString() ?? '—';
    final sender = parcel['sender_name']?.toString() ?? '—';
    final receiver = parcel['receiver_name']?.toString() ?? '—';
    final origin = parcel['origin']?.toString() ?? '—';
    final destination = parcel['destination']?.toString() ?? '—';
    final amount = parcel['amount'];
    final status = parcel['status']?.toString() ?? 'pending';
    final travelDate = parcel['travel_date']?.toString();
    final bus = parcel['bus'] is Map ? parcel['bus'] as Map<String, dynamic> : null;
    final busPlate = bus?['plate_number']?.toString() ?? '—';

    final amountNum = amount is num ? amount.toDouble() : (double.tryParse(amount?.toString() ?? '') ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.confirmation_number, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tracking,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('$sender → $receiver', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            const SizedBox(height: 4),
            Text('$origin → $destination', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            if (travelDate != null && travelDate.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Travel: $travelDate · Bus: $busPlate', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Text(
              'TZS ${amountNum.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade700, fontSize: 15),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
