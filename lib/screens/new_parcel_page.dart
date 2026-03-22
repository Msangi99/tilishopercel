import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/parcel_receipt_page.dart';
import 'package:t_percel/services/api_service.dart';

class NewParcelPage extends StatefulWidget {
  const NewParcelPage({super.key});

  @override
  State<NewParcelPage> createState() => _NewParcelPageState();
}

class _NewParcelPageState extends State<NewParcelPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _parcelNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _creatorOfficeController = TextEditingController();
  
  // Selected values
  String? _selectedOrigin;
  String? _selectedDestination;
  String _weightBand = 'under_20kg';
  DateTime _travelDate = DateTime.now();
  
  bool _isDataLoading = true; // true until routes are loaded
  List<dynamic> _routes = [];
  
  // Unique origins and destinations from routes
  Set<String> _origins = {};
  Set<String> _destinations = {};
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    if (!_isDataLoading) setState(() => _isDataLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getRoutes(),
      ]);
      
      if (mounted) {
        setState(() {
          _routes = List<dynamic>.from(results[0]);
          
          // Extract unique origins and destinations from routes
          _origins = {};
          _destinations = {};
          for (var route in _routes) {
            final from = route is Map ? route['from'] : null;
            final to = route is Map ? route['to'] : null;
            if (from != null && from.toString().isNotEmpty) _origins.add(from.toString());
            if (to != null && to.toString().isNotEmpty) _destinations.add(to.toString());
          }
          
          // Set default origin and destination from first route
          if (_routes.isNotEmpty && _routes.first is Map) {
            final first = _routes.first as Map;
            _selectedOrigin = first['from']?.toString();
            _selectedDestination = first['to']?.toString();
          }
          _isDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDataLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading buses/routes: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  Future<void> _handleRefresh() async {
    await _loadData();
  }

  Future<void> _pickTravelDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _travelDate = picked);
    }
  }

  Future<void> _openReviewAndConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_routes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No routes available. Cannot create parcel.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_selectedOrigin == null || _selectedDestination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select origin and destination.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final travelDateFormatted = DateFormat('yyyy-MM-dd').format(_travelDate);
    final qty = int.parse(_quantityController.text.trim());
    final snapshot = _ParcelCreateSnapshot(
      parcelName: _parcelNameController.text.trim(),
      quantity: qty,
      weightBand: _weightBand,
      creatorOffice: _creatorOfficeController.text.trim(),
      senderName: _senderNameController.text.trim(),
      senderPhone: _senderPhoneController.text.trim(),
      receiverName: _receiverNameController.text.trim(),
      receiverPhone: _receiverPhoneController.text.trim(),
      origin: _selectedOrigin!,
      destination: _selectedDestination!,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      travelDate: travelDateFormatted,
    );

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _ParcelCreateFlowPage(
          snapshot: snapshot,
          onSuccess: (Map<String, dynamic> parcel) {
            if (!mounted) return;
            _formKey.currentState!.reset();
            _quantityController.text = '1';
            _senderNameController.clear();
            _senderPhoneController.clear();
            _receiverNameController.clear();
            _receiverPhoneController.clear();
            _amountController.clear();
            _descriptionController.clear();
            _parcelNameController.clear();
            _creatorOfficeController.clear();
            if (_routes.isNotEmpty && _routes.first is Map) {
              final first = _routes.first as Map;
              setState(() {
                _selectedOrigin = first['from']?.toString();
                _selectedDestination = first['to']?.toString();
              });
            }
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (context) => ParcelReceiptPage(parcel: parcel),
              ),
            );
          },
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Parcel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _buildSectionTitle('Parcel details'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _parcelNameController,
                        label: 'Parcel name',
                        icon: Icons.inventory_2_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter parcel name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _quantityController,
                              label: 'Quantity',
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final n = int.tryParse(value.trim());
                                if (n == null || n < 1) {
                                  return 'Min 1';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildWeightDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _creatorOfficeController,
                        label: 'Creator office',
                        icon: Icons.storefront_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter office name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Sender Information Section
                      _buildSectionTitle('Sender Information'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _senderNameController,
                      label: 'Sender Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter sender name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _senderPhoneController,
                      label: 'Sender Phone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                          return 'Please enter valid phone number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Receiver Information Section
                    _buildSectionTitle('Receiver Information'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _receiverNameController,
                      label: 'Receiver Name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter receiver name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _receiverPhoneController,
                      label: 'Receiver Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                          return 'Please enter valid phone number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Route Information Section
                    _buildSectionTitle('Route Information'),
                    const SizedBox(height: 8),
                    if (_routes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No routes available. Please add routes in admin or contact admin.',
                                style: TextStyle(color: Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'From',
                              hint: 'Select origin',
                              items: _origins.toList(),
                              value: _selectedOrigin,
                              onChanged: (value) {
                                setState(() => _selectedOrigin = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'To',
                              hint: 'Select destination',
                              items: _destinations.toList(),
                              value: _selectedDestination,
                              onChanged: (value) {
                                setState(() => _selectedDestination = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    if (_routes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildTravelDateField(),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Amount and Description
                    _buildSectionTitle('Payment & Notes'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _amountController,
                      label: 'Amount (TZS)',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      prefix: 'TZS ',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter valid amount';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Amount must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description (Optional)',
                      icon: Icons.description,
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    // Outside Form: avoids keyboard Enter / web treating action as form submit
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _openReviewAndConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CONTINUE TO SUMMARY',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTravelDateField() {
    final display = DateFormat.yMMMEd().format(_travelDate);
    return Semantics(
      label: 'Travel date',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickTravelDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Travel date',
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              suffixIcon: Icon(Icons.edit_calendar_outlined, color: Colors.grey.shade600),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                display,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? prefix,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        prefixText: prefix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
  
  Widget _buildWeightDropdown() {
    return DropdownButtonFormField<String>(
      value: _weightBand,
      decoration: InputDecoration(
        labelText: 'Weight',
        prefixIcon: const Icon(Icons.scale, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      isExpanded: true,
      items: const [
        DropdownMenuItem(
          value: 'under_20kg',
          child: Text('Less than 20 kg'),
        ),
        DropdownMenuItem(
          value: 'over_20kg',
          child: Text('20 kg or more'),
        ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _weightBand = v);
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    String? hint,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: hint != null ? Text(hint) : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.list, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      isExpanded: true,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
  
  @override
  void dispose() {
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _parcelNameController.dispose();
    _quantityController.dispose();
    _creatorOfficeController.dispose();
    super.dispose();
  }
}

class _ParcelCreateSnapshot {
  const _ParcelCreateSnapshot({
    required this.parcelName,
    required this.quantity,
    required this.weightBand,
    required this.creatorOffice,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.origin,
    required this.destination,
    required this.amount,
    this.description,
    required this.travelDate,
  });

  final String parcelName;
  final int quantity;
  final String weightBand;
  final String creatorOffice;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;
  final String origin;
  final String destination;
  final double amount;
  final String? description;
  final String travelDate;

  String get weightLabel => weightBand == 'over_20kg'
      ? '20 kg or more'
      : 'Less than 20 kg';
}

class _ParcelCreateFlowPage extends StatefulWidget {
  const _ParcelCreateFlowPage({
    required this.snapshot,
    required this.onSuccess,
  });

  final _ParcelCreateSnapshot snapshot;
  final void Function(Map<String, dynamic> parcel) onSuccess;

  @override
  State<_ParcelCreateFlowPage> createState() => _ParcelCreateFlowPageState();
}

class _ParcelCreateFlowPageState extends State<_ParcelCreateFlowPage> {
  int _step = 0;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  String _formatSummaryTravelDate(String iso) {
    try {
      return DateFormat.yMMMEd().format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAfterPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your password to confirm.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final s = widget.snapshot;
    try {
      await ApiService.verifyPassword(password);
      final created = await ApiService.createParcel(
        parcelName: s.parcelName,
        quantity: s.quantity,
        weightBand: s.weightBand,
        creatorOffice: s.creatorOffice,
        senderName: s.senderName,
        senderPhone: s.senderPhone,
        receiverName: s.receiverName,
        receiverPhone: s.receiverPhone,
        origin: s.origin,
        destination: s.destination,
        amount: s.amount,
        description: s.description,
        travelDate: s.travelDate,
      );
      if (!mounted) return;
      Map<String, dynamic> parcelOut;
      final inner = created['parcel'];
      if (inner is Map) {
        parcelOut = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(inner));
      } else {
        parcelOut = created;
      }
      Navigator.of(context).pop();
      widget.onSuccess(parcelOut);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _summaryTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      );

  Widget _summarySection({
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(titleIcon, size: 20, color: AppColors.redBar),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStep(_ParcelCreateSnapshot s) {
    final amountFmt = NumberFormat('#,###', 'en_US').format(s.amount.round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue.withValues(alpha: 0.12),
                AppColors.darkBlue.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 28,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Almost done',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Review your shipment details. Next, you'll confirm with your password.",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _summarySection(
          title: 'Parcel',
          titleIcon: Icons.inventory_2_outlined,
          children: [
            _summaryTile(Icons.label_outline_rounded, 'Name', s.parcelName),
            _divider(),
            _summaryTile(Icons.numbers_rounded, 'Quantity', '${s.quantity}'),
            _divider(),
            _summaryTile(Icons.scale_rounded, 'Weight', s.weightLabel),
            _divider(),
            _summaryTile(Icons.storefront_outlined, 'Creator office', s.creatorOffice),
          ],
        ),
        const SizedBox(height: 14),
        _summarySection(
          title: 'People',
          titleIcon: Icons.people_outline_rounded,
          children: [
            _summaryTile(Icons.person_outline_rounded, 'Sender',
                '${s.senderName}\n${s.senderPhone}'),
            _divider(),
            _summaryTile(Icons.person_pin_outlined, 'Receiver',
                '${s.receiverName}\n${s.receiverPhone}'),
          ],
        ),
        const SizedBox(height: 14),
        _summarySection(
          title: 'Route & schedule',
          titleIcon: Icons.alt_route_rounded,
          children: [
            _summaryTile(Icons.place_outlined, 'From → To',
                '${s.origin}  →  ${s.destination}'),
            _divider(),
            _summaryTile(
              Icons.calendar_today_outlined,
              'Travel date',
              _formatSummaryTravelDate(s.travelDate),
            ),
          ],
        ),
        if (s.description != null && s.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _summarySection(
            title: 'Notes',
            titleIcon: Icons.sticky_note_2_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  s.description!.trim(),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: Colors.green.shade800,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMOUNT DUE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TZS $amountFmt',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Edit form',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_person_outlined, color: AppColors.redBar, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Security check',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the password you use to sign in to this app.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_submitting,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.poppins(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon: Icon(Icons.key_rounded, color: Colors.grey.shade600),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 2,
                    ),
                  ),
                ),
                onFieldSubmitted: (_) {
                  if (!_submitting) {
                    _createAfterPassword();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _step = 0;
                          _passwordController.clear();
                        }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade800,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _submitting ? null : _createAfterPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.redBar,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create parcel',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          _step == 0 ? 'Parcel summary' : 'Confirm password',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() {
                          _step = 0;
                          _passwordController.clear();
                        });
                      },
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_step == 0)
                _buildSummaryStep(s)
              else
                _buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }
}
