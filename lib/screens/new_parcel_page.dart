import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:t_percel/main.dart';
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
  
  // Selected values
  String? _selectedOrigin;
  String? _selectedDestination;
  DateTime? _travelDate;
  
  bool _isLoading = false;
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
  
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && mounted) {
      setState(() {
        _travelDate = picked;
      });
    }
  }
  
  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final travelDateFormatted = _travelDate != null
            ? DateFormat('yyyy-MM-dd').format(_travelDate!)
            : DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        await ApiService.createParcel(
          senderName: _senderNameController.text.trim(),
          senderPhone: _senderPhoneController.text.trim(),
          receiverName: _receiverNameController.text.trim(),
          receiverPhone: _receiverPhoneController.text.trim(),
          origin: _selectedOrigin!,
          destination: _selectedDestination!,
          amount: double.parse(_amountController.text),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          travelDate: travelDateFormatted,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parcel created successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Clear form and go to My Parcels
          _formKey.currentState!.reset();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/my-parcels',
            ModalRoute.withName('/dashboard'),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
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
      body: (_isDataLoading || _isLoading)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    
                    const SizedBox(height: 32),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'CREATE PARCEL',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
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
    super.dispose();
  }
}
