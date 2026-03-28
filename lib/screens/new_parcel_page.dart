import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:t_percel/main.dart';
import 'package:t_percel/screens/parcel_receipt_page.dart';
import 'package:t_percel/widgets/password_verify_sheet.dart';
import 'package:t_percel/services/api_service.dart';

String? _optionalEmailValidator(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  final email = RegExp(r'^[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}$');
  if (!email.hasMatch(v)) return 'Enter a valid email';
  return null;
}

class NewParcelPage extends StatefulWidget {
  const NewParcelPage({super.key});

  @override
  State<NewParcelPage> createState() => _NewParcelPageState();
}

class _NewParcelPageState extends State<NewParcelPage> {
  final List<GlobalKey<FormState>> _wizardFormKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  late final PageController _wizardPageController;
  int _wizardStep = 0;

  // Form controllers
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _senderEmailController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _receiverEmailController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _parcelNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _creatorOfficeController = TextEditingController();

  // Selected values
  String? _selectedCreatorOffice;
  String? _selectedOrigin;
  String? _selectedDestination;
  String _weightBand = 'under_20kg';
  DateTime _travelDate = DateTime.now();
  
  bool _isDataLoading = true; // true until routes are loaded
  List<dynamic> _routes = [];

  /// From `/api/offices` — used for creator office picker.
  List<String> _officeNames = [];

  /// Route endpoints plus office names — used for From / To pickers.
  List<String> _routePlaceOptions = [];
  
  @override
  void initState() {
    super.initState();
    _wizardPageController = PageController();
    _loadData();
  }

  static List<String> _uniqueRouteEndpoints(List<dynamic> routes) {
    final set = <String>{};
    for (final route in routes) {
      if (route is! Map) continue;
      final m = route.map((k, v) => MapEntry(k.toString(), v));
      final from = m['from']?.toString().trim();
      final to = m['to']?.toString().trim();
      if (from != null && from.isNotEmpty) set.add(from);
      if (to != null && to.isNotEmpty) set.add(to);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> _parseOfficeNames(List<dynamic> offices) {
    final set = <String>{};
    for (final o in offices) {
      if (o is! Map) continue;
      final m = o.map((k, v) => MapEntry(k.toString(), v));
      final n = m['name']?.toString().trim();
      if (n != null && n.isNotEmpty) set.add(n);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> _mergeUniqueSorted(List<String> a, List<String> b) {
    final set = <String>{...a, ...b};
    final list = set.toList()
      ..sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase()));
    return list;
  }

  Future<String?> _openLocationPicker({
    required String title,
    required List<String> options,
    String? currentValue,
  }) async {
    if (options.isEmpty) return null;
    final searchController = TextEditingController();
    List<String> filtered = List<String>.from(options);

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void applyFilter(String q) {
              final lower = q.trim().toLowerCase();
              filtered = lower.isEmpty
                  ? List<String>.from(options)
                  : options
                      .where((e) => e.toLowerCase().contains(lower))
                      .toList();
              setModalState(() {});
            }

            final maxH = MediaQuery.sizeOf(context).height * 0.78;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SizedBox(
                height: maxH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: applyFilter,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No matches',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final item = filtered[i];
                                final selected = item == currentValue;
                                return ListTile(
                                  title: Text(
                                    item,
                                    style: GoogleFonts.poppins(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  trailing: selected
                                      ? Icon(Icons.check_circle_rounded,
                                          color: AppColors.primaryBlue)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(sheetContext).pop(item),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    return picked;
  }

  Widget _buildSearchableLocationField({
    required String label,
    required IconData icon,
    required List<String> options,
    required String? value,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
    required String pickerTitle,
  }) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return FormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      validator: validator,
      builder: (state) {
        final display = value?.isNotEmpty == true ? value! : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: label,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final picked = await _openLocationPicker(
                      title: pickerTitle,
                      options: options,
                      currentValue: value,
                    );
                    if (picked != null) {
                      state.didChange(picked);
                      onChanged(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: label,
                      prefixIcon: Icon(icon, size: 20),
                      suffixIcon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.grey.shade700,
                      ),
                      errorText: state.errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.blue.shade700, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        display ?? 'Tap to select',
                        style: TextStyle(
                          fontSize: 15,
                          color: display != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _wizardSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _wizardNext() async {
    FocusScope.of(context).unfocus();
    final ok = _wizardFormKeys[_wizardStep].currentState?.validate() ?? false;
    if (!ok) return;
    if (_wizardStep == 0) {
      setState(() => _wizardStep = 1);
      await _wizardPageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_wizardStep == 1) {
      setState(() => _wizardStep = 2);
      await _wizardPageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_routes.isEmpty) {
      _wizardSnack('No routes available. Cannot create parcel.');
      return;
    }
    if (_selectedOrigin == null || _selectedDestination == null) {
      _wizardSnack('Select origin and destination.');
      return;
    }
    await _openReviewAndConfirm();
  }

  void _wizardBack() {
    FocusScope.of(context).unfocus();
    if (_wizardStep <= 0) return;
    setState(() => _wizardStep -= 1);
    _wizardPageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }
  
  Future<void> _loadData() async {
    if (!_isDataLoading) setState(() => _isDataLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getRoutes(),
        ApiService.getOffices(),
      ]);

      if (mounted) {
        setState(() {
          _routes = List<dynamic>.from(results[0]);
          _officeNames = _parseOfficeNames(List<dynamic>.from(results[1]));
          _routePlaceOptions = _mergeUniqueSorted(
            _uniqueRouteEndpoints(_routes),
            _officeNames,
          );

          if (_routes.isNotEmpty && _routes.first is Map) {
            final first = _routes.first as Map;
            final from = first['from']?.toString();
            final to = first['to']?.toString();
            _selectedOrigin =
                from != null && _routePlaceOptions.contains(from) ? from : null;
            _selectedDestination =
                to != null && _routePlaceOptions.contains(to) ? to : null;
            if (_selectedOrigin == null && _routePlaceOptions.isNotEmpty) {
              _selectedOrigin = _routePlaceOptions.first;
            }
            if (_selectedDestination == null && _routePlaceOptions.length > 1) {
              _selectedDestination = _routePlaceOptions[1];
            } else if (_selectedDestination == null &&
                _routePlaceOptions.isNotEmpty) {
              _selectedDestination = _routePlaceOptions.first;
            }
          } else {
            _selectedOrigin = null;
            _selectedDestination = null;
          }
          _isDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDataLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error loading routes/offices: ${e.toString().replaceFirst('Exception: ', '')}'),
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
    // Do not re-validate earlier wizard steps here: PageView only keeps the
    // current page built, so FormState for other pages is often null and
    // validate() would falsely fail. Steps are already validated on each
    // "Continue" tap; step 3 is validated in _wizardNext before this runs.
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
      creatorOffice: _officeNames.isNotEmpty
          ? (_selectedCreatorOffice ?? '')
          : _creatorOfficeController.text.trim(),
      senderName: _senderNameController.text.trim(),
      senderPhone: _senderPhoneController.text.trim(),
      senderEmail: _senderEmailController.text.trim().isEmpty
          ? null
          : _senderEmailController.text.trim(),
      receiverName: _receiverNameController.text.trim(),
      receiverPhone: _receiverPhoneController.text.trim(),
      receiverEmail: _receiverEmailController.text.trim().isEmpty
          ? null
          : _receiverEmailController.text.trim(),
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
            for (final k in _wizardFormKeys) {
              k.currentState?.reset();
            }
            _quantityController.text = '1';
            _senderNameController.clear();
            _senderPhoneController.clear();
            _senderEmailController.clear();
            _receiverNameController.clear();
            _receiverPhoneController.clear();
            _receiverEmailController.clear();
            _amountController.clear();
            _descriptionController.clear();
            _parcelNameController.clear();
            _creatorOfficeController.clear();
            if (_routes.isNotEmpty && _routes.first is Map) {
              final first = _routes.first as Map;
              final from = first['from']?.toString();
              final to = first['to']?.toString();
              setState(() {
                _wizardStep = 0;
                _selectedCreatorOffice = null;
                _selectedOrigin =
                    from != null && _routePlaceOptions.contains(from)
                        ? from
                        : (_routePlaceOptions.isNotEmpty
                            ? _routePlaceOptions.first
                            : null);
                _selectedDestination =
                    to != null && _routePlaceOptions.contains(to)
                        ? to
                        : (_routePlaceOptions.length > 1
                            ? _routePlaceOptions[1]
                            : _routePlaceOptions.isNotEmpty
                                ? _routePlaceOptions.first
                                : null);
              });
              _wizardPageController.jumpToPage(0);
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
    const stepHints = [
      'Name, quantity, weight, and registration office',
      'Sender and receiver details',
      'Route, travel date, amount, and notes',
    ];
    const stepTitles = [
      'Parcel details',
      'Sender & receiver',
      'Route & payment',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F7),
      appBar: AppBar(
        title: Text(
          'Create parcel',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWizardBanner(
                  title: stepTitles[_wizardStep],
                  subtitle: stepHints[_wizardStep],
                ),
                Expanded(
                  child: PageView(
                    controller: _wizardPageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Form(
                            key: _wizardFormKeys[0],
                            child: _buildWizardCard(
                              icon: Icons.inventory_2_outlined,
                              children: [
                                _buildSectionTitle('Parcel details'),
                                const SizedBox(height: 12),
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
                                    Expanded(child: _buildWeightDropdown()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_officeNames.isNotEmpty)
                                  _buildSearchableLocationField(
                                    label: 'Creator office',
                                    icon: Icons.storefront_outlined,
                                    options: _officeNames,
                                    value: _selectedCreatorOffice,
                                    pickerTitle: 'Select creator office',
                                    onChanged: (v) =>
                                        setState(() => _selectedCreatorOffice = v),
                                    validator: (v) =>
                                        v == null || v.isEmpty
                                            ? 'Select creator office'
                                            : null,
                                  )
                                else
                                  _buildTextField(
                                    controller: _creatorOfficeController,
                                    label: 'Creator office',
                                    icon: Icons.storefront_outlined,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Enter office name';
                                      }
                                      return null;
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Form(
                            key: _wizardFormKeys[1],
                            child: _buildWizardCard(
                              icon: Icons.people_outline_rounded,
                              children: [
                                _buildSectionTitle('Sender'),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _senderNameController,
                                  label: 'Sender name',
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
                                  label: 'Sender phone',
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
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _senderEmailController,
                                  label: 'Sender email (optional)',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _optionalEmailValidator,
                                ),
                                const SizedBox(height: 22),
                                _buildSectionTitle('Receiver'),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _receiverNameController,
                                  label: 'Receiver name',
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
                                  label: 'Receiver phone',
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
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _receiverEmailController,
                                  label: 'Receiver email (optional)',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _optionalEmailValidator,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Form(
                            key: _wizardFormKeys[2],
                            child: _buildWizardCard(
                              icon: Icons.alt_route_rounded,
                              children: [
                                _buildSectionTitle('Route'),
                                const SizedBox(height: 12),
                                if (_routes.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.orange.shade800),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'No routes are configured. Please contact an administrator.',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.orange.shade900,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _buildSearchableLocationField(
                                              label: 'From',
                                              icon: Icons.place_outlined,
                                              options: _routePlaceOptions,
                                              value: _selectedOrigin,
                                              pickerTitle: 'Select origin',
                                              onChanged: (value) {
                                                setState(
                                                    () => _selectedOrigin = value);
                                              },
                                              validator: (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Select origin'
                                                      : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildSearchableLocationField(
                                              label: 'To',
                                              icon: Icons.flag_rounded,
                                              options: _routePlaceOptions,
                                              value: _selectedDestination,
                                              pickerTitle: 'Select destination',
                                              onChanged: (value) {
                                                setState(() =>
                                                    _selectedDestination = value);
                                              },
                                              validator: (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Select destination'
                                                      : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTravelDateField(),
                                    ],
                                  ),
                                const SizedBox(height: 22),
                                _buildSectionTitle('Payment & notes'),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _amountController,
                                  label: 'Amount (TZS)',
                                  icon: Icons.payments_outlined,
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
                                  label: 'Description (optional)',
                                  icon: Icons.description_outlined,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildWizardBottomBar(),
              ],
            ),
    );
  }

  Widget _buildWizardBanner({required String title, required String subtitle}) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_wizardStep + 1) / 3,
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                color: AppColors.redBar,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step ${_wizardStep + 1} of 3',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardCard({required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: AppColors.primaryBlue),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildWizardBottomBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              if (_wizardStep > 0) ...[
                OutlinedButton(
                  onPressed: _wizardBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkBlue,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('Back', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _wizardNext,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _wizardStep >= 2 ? AppColors.redBar : AppColors.darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _wizardStep >= 2 ? 'Review & create' : 'Continue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
        letterSpacing: 0.2,
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

  @override
  void dispose() {
    _wizardPageController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _senderEmailController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverEmailController.dispose();
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
    this.senderEmail,
    required this.receiverName,
    required this.receiverPhone,
    this.receiverEmail,
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
  final String? senderEmail;
  final String receiverName;
  final String receiverPhone;
  final String? receiverEmail;
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
  String _formatSummaryTravelDate(String iso) {
    try {
      return DateFormat.yMMMEd().format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Future<void> _showVerifyPasswordSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
          ),
          child: PasswordVerifySheet(
            title: 'Verify password',
            subtitle:
                'Enter the same password you use to sign in. It is checked on the Tilisho server (your staff account / database).',
            primaryButtonLabel: 'Create parcel',
            scaffoldMessenger: messenger,
            onVerified: () async {
              final s = widget.snapshot;
              final created = await ApiService.createParcel(
                parcelName: s.parcelName,
                quantity: s.quantity,
                weightBand: s.weightBand,
                creatorOffice: s.creatorOffice,
                senderName: s.senderName,
                senderPhone: s.senderPhone,
                senderEmail: s.senderEmail,
                receiverName: s.receiverName,
                receiverPhone: s.receiverPhone,
                receiverEmail: s.receiverEmail,
                origin: s.origin,
                destination: s.destination,
                amount: s.amount,
                description: s.description,
                travelDate: s.travelDate,
              );
              if (!modalContext.mounted) return;
              Map<String, dynamic> parcelOut;
              final inner = created['parcel'];
              if (inner is Map) {
                parcelOut =
                    Map<String, dynamic>.from(Map<dynamic, dynamic>.from(inner));
              } else {
                parcelOut = created;
              }
              Navigator.of(modalContext).pop();
              if (!mounted) return;
              Navigator.of(context).pop();
              widget.onSuccess(parcelOut);
            },
          ),
        );
      },
    );
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
                      'Almost there',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review the shipment details. Tap Continue, then enter your sign-in password in the sheet to create the parcel.',
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
            _summaryTile(
              Icons.person_outline_rounded,
              'Sender',
              [
                s.senderName,
                s.senderPhone,
                if (s.senderEmail != null && s.senderEmail!.trim().isNotEmpty)
                  s.senderEmail!.trim(),
              ].join('\n'),
            ),
            _divider(),
            _summaryTile(
              Icons.person_pin_outlined,
              'Receiver',
              [
                s.receiverName,
                s.receiverPhone,
                if (s.receiverEmail != null && s.receiverEmail!.trim().isNotEmpty)
                  s.receiverEmail!.trim(),
              ].join('\n'),
            ),
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
              child: FilledButton(
                onPressed: _showVerifyPasswordSheet,
                style: FilledButton.styleFrom(
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

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F7),
      appBar: AppBar(
        title: Text(
          'Review details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: AppColors.redBar,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: _buildSummaryStep(s),
        ),
      ),
    );
  }
}
