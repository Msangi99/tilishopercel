import 'dart:async';

import 'package:blue_thermal_printer_plus/blue_thermal_printer_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

enum PrinterType { none, builtIn, bluetooth }

class PrinterSelection {
  final PrinterType type;
  final String? name;
  final String? address;

  const PrinterSelection({required this.type, this.name, this.address});

  String get label {
    switch (type) {
      case PrinterType.builtIn:
        return name?.isNotEmpty == true ? name! : 'Built-in printer';
      case PrinterType.bluetooth:
        final n = name?.isNotEmpty == true ? name! : 'Bluetooth printer';
        final a = address?.isNotEmpty == true ? address! : '';
        return a.isEmpty ? n : '$n ($a)';
      case PrinterType.none:
        return 'No printer selected';
    }
  }
}

class PrinterService {
  static const _kType = 'printer_type';
  static const _kBtAddress = 'printer_bt_address';
  static const _kBtName = 'printer_bt_name';

  final BlueThermalPrinterPlus _bt = BlueThermalPrinterPlus();

  Future<PrinterSelection> loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final rawType = prefs.getString(_kType) ?? 'none';

    if (rawType == 'built_in') {
      return const PrinterSelection(
        type: PrinterType.builtIn,
        name: 'Built-in printer',
      );
    }

    if (rawType == 'bluetooth') {
      final address = prefs.getString(_kBtAddress);
      final name = prefs.getString(_kBtName);
      if (address != null && address.isNotEmpty) {
        return PrinterSelection(
          type: PrinterType.bluetooth,
          name: name,
          address: address,
        );
      }
    }

    return const PrinterSelection(type: PrinterType.none);
  }

  Future<void> saveSelection(PrinterSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    switch (selection.type) {
      case PrinterType.builtIn:
        await prefs.setString(_kType, 'built_in');
        await prefs.remove(_kBtAddress);
        await prefs.remove(_kBtName);
        break;
      case PrinterType.bluetooth:
        await prefs.setString(_kType, 'bluetooth');
        await prefs.setString(_kBtAddress, selection.address ?? '');
        await prefs.setString(_kBtName, selection.name ?? '');
        break;
      case PrinterType.none:
        await prefs.setString(_kType, 'none');
        await prefs.remove(_kBtAddress);
        await prefs.remove(_kBtName);
        break;
    }
  }

  /// If device has built-in printer support (Sunmi), prefer it as default.
  Future<PrinterSelection> ensureDefaultSelection() async {
    final current = await loadSelection();
    if (current.type != PrinterType.none) return current;

    final builtIn = await isBuiltInPrinterSupported();
    if (builtIn) {
      const sel = PrinterSelection(
        type: PrinterType.builtIn,
        name: 'Built-in printer',
      );
      await saveSelection(sel);
      return sel;
    }

    return current;
  }

  Future<bool> isBuiltInPrinterSupported() async {
    try {
      await SunmiPrinter.bindingPrinter();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureBluetoothPermissions() async {
    // Android 12+ needs BLUETOOTH_CONNECT/SCAN; permission_handler maps these.
    final connect = await Permission.bluetoothConnect.request();
    final scan = await Permission.bluetoothScan.request();

    // Pre-Android 12 scanning often requires location.
    final loc = await Permission.locationWhenInUse.request();

    return connect.isGranted &&
        scan.isGranted &&
        (loc.isGranted || loc.isLimited);
  }

  Future<List<BluetoothDevice>> getBondedBluetoothPrinters() async {
    final ok = await _ensureBluetoothPermissions();
    if (!ok) return [];

    final devices = await _bt.getBondedDevices();
    // Many printer plugins can only print to paired devices.
    return devices;
  }

  Future<void> printReceipt({
    required PrinterSelection selection,
    required Map<String, dynamic> parcel,
  }) async {
    if (selection.type == PrinterType.builtIn) {
      await _printSunmi(parcel);
      return;
    }
    if (selection.type == PrinterType.bluetooth) {
      await _printBluetooth(selection, parcel);
      return;
    }

    throw Exception('No printer selected');
  }

  Future<void> _printSunmi(Map<String, dynamic> parcel) async {
    await SunmiPrinter.initPrinter();
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.bold();
    await SunmiPrinter.printText('TILISHO PARCEL');
    await SunmiPrinter.resetBold();
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText(_str(parcel['tracking_number']));
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
    await SunmiPrinter.printText('From: ${_str(parcel['origin'])}');
    await SunmiPrinter.printText('To: ${_str(parcel['destination'])}');
    await SunmiPrinter.printText(
      'Sender: ${_str(parcel['sender_name'])} ${_str(parcel['sender_phone'])}',
    );
    await SunmiPrinter.printText(
      'Receiver: ${_str(parcel['receiver_name'])} ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
    );
    await SunmiPrinter.printText('Ship Date: ${_str(parcel['travel_date'])}');
    final pn = parcel['parcel_name']?.toString();
    if (pn != null && pn.trim().isNotEmpty) {
      await SunmiPrinter.printText('Parcel: $pn');
    }
    final q = parcel['quantity'];
    if (q != null) {
      await SunmiPrinter.printText('Qty: $q  Weight: ${_weightBand(parcel['weight_band'])}');
    }
    final off = parcel['creator_office']?.toString();
    if (off != null && off.trim().isNotEmpty) {
      await SunmiPrinter.printText('Office: $off');
    }
    final desc = parcel['description']?.toString();
    if (desc != null && desc.trim().isNotEmpty) {
      await SunmiPrinter.printText('Cargo: $desc');
    }
    await SunmiPrinter.printText(
      'Fare: TZS ${_amount(parcel['amount']).toStringAsFixed(0)}',
    );

    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('Msaada: 0750015630');
    await SunmiPrinter.printText('www.tilishosafari.co.tz');
    await SunmiPrinter.lineWrap(3);
    await SunmiPrinter.cut();
  }

  Future<void> _printBluetooth(
    PrinterSelection selection,
    Map<String, dynamic> parcel,
  ) async {
    final ok = await _ensureBluetoothPermissions();
    if (!ok) throw Exception('Bluetooth permission denied');

    final bonded = await _bt.getBondedDevices();
    final device = bonded
        .where((d) => d.address == selection.address)
        .cast<BluetoothDevice?>()
        .firstWhere((d) => d != null, orElse: () => null);
    if (device == null) throw Exception('Selected printer not paired');

    final connected = await _bt.isConnected ?? false;
    if (!connected) {
      await _bt.connect(device);
      // Small delay to allow connection to settle.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    final items = <PrintItem>[
      PrintItem.text('TILISHO PARCEL', size: 2, align: 1),
      PrintItem.text('', align: 1),
      PrintItem.text(_str(parcel['tracking_number']), size: 1, align: 1),
      PrintItem.text('', align: 1),
      PrintItem.text('From: ${_str(parcel['origin'])}'),
      PrintItem.text('To: ${_str(parcel['destination'])}'),
      PrintItem.text('Sender: ${_str(parcel['sender_name'])}'),
      PrintItem.text('Phone: ${_str(parcel['sender_phone'])}'),
      PrintItem.text('Receiver: ${_str(parcel['receiver_name'])}'),
      PrintItem.text(
        'Phone: ${_str(parcel['receiver_phone'] ?? parcel['receiver_contact'])}',
      ),
      PrintItem.text('Ship Date: ${_str(parcel['travel_date'])}'),
    ];
    final pn = parcel['parcel_name']?.toString();
    if (pn != null && pn.trim().isNotEmpty) {
      items.add(PrintItem.text('Parcel: $pn'));
    }
    final q = parcel['quantity'];
    if (q != null) {
      items.add(
        PrintItem.text('Qty: $q  Weight: ${_weightBand(parcel['weight_band'])}'),
      );
    }
    final off = parcel['creator_office']?.toString();
    if (off != null && off.trim().isNotEmpty) {
      items.add(PrintItem.text('Office: $off'));
    }
    final desc = parcel['description']?.toString();
    if (desc != null && desc.trim().isNotEmpty) {
      items.add(PrintItem.text('Cargo: $desc'));
    }

    items.addAll([
      PrintItem.text(
        'Fare: TZS ${_amount(parcel['amount']).toStringAsFixed(0)}',
        size: 1,
        align: 0,
      ),
      PrintItem.text('', align: 1),
      PrintItem.text('Msaada: 0750015630', align: 1),
      PrintItem.text('www.tilishosafari.co.tz', align: 1),
      PrintItem.text('', align: 1),
    ]);

    await _bt.print(items: items, protocol: PrinterProtocol.escPos);
  }

  static String _str(dynamic v) => v?.toString() ?? '—';

  static String _weightBand(dynamic v) {
    final s = v?.toString() ?? '';
    if (s == 'over_20kg') return '20kg+';
    if (s == 'under_20kg') return '<20kg';
    return '—';
  }
  static double _amount(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}
