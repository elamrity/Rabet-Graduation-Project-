import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleDevicesScreen extends StatefulWidget {
  const BleDevicesScreen({super.key});

  @override
  State<BleDevicesScreen> createState() => _BleDevicesScreenState();
}

class _BleDevicesScreenState extends State<BleDevicesScreen> {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, ScanResult> _devices = {};
  bool _isScanning = false;
  String _status = "جاهز للفحص";

  // نفس الـ UUID الموجود في كود الـ ESP32
  final Guid serviceUuid = Guid("12345678-1234-1234-1234-1234567890ab");

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    await _requestPermissions();
    if (await FlutterBluePlus.isSupported == false) {
      setState(() => _status = "الموبايل لا يدعم BLE");
      return;
    }
    // التأكد من تشغيل البلوتوث
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
    _startScan();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  Future<void> _startScan() async {
    setState(() {
      _status = "جاري البحث عن أجهزة esp...";
      _isScanning = true;
      _devices.clear();
    });

    try {
      // البحث فقط عن الأجهزة التي تملك هذا الـ UUID
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 10),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final id = result.device.remoteId.str;
          _devices[id] = result;
        }
        if (mounted) setState(() {});
      });

      // انتهاء المسح تلقائياً بعد الوقت المحدد
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _isScanning = false);
      });

    } catch (e) {
      debugPrint("Scan Error: $e");
      setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicesList = _devices.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1A),
      appBar: AppBar(
        title: const Text(" SCANNEING FOR ESP"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _isScanning
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_status, style: const TextStyle(color: Colors.greenAccent)),
          ),
          Expanded(
            child: devicesList.isEmpty
                ? const Center(child: Text("لم يتم العثور على أجهزة بعد", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                final device = devicesList[index];
                return Card(
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    title: Text(
                      device.device.platformName.isNotEmpty ? device.device.platformName : "Unknown ESP32",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(device.device.remoteId.str, style: const TextStyle(color: Colors.white70)),
                    trailing: Text("${device.rssi} dBm", style: const TextStyle(color: Colors.green)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}