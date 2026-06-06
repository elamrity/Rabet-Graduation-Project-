import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'RadarGridPainter.dart'; // تأكد من اسم الملف هنا

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // البيانات التي يتم رسمها
  final Map<String, Offset> users = {};
  final Map<String, int> rssiMap = {};

  // لتنعيم حركة النقطة (Smoothing)
  final Map<String, double> _smoothDistanceMap = {};

  StreamSubscription<List<ScanResult>>? _scanSub;

  // الـ UUID الخاص بـ OpticVerse
  final Guid targetServiceUuid = Guid("12345678-1234-1234-1234-1234567890ab");

  @override
  void initState() {
    super.initState();

    // أنيميشن خط الرادار (يلف كل 3 ثواني)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _initBle();
  }

  Future<void> _initBle() async {
    // 1. طلب كافة الصلاحيات اللازمة للأندرويد
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // 2. التأكد من تشغيل البلوتوث
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on) {
      _startScan();
    } else {
      await FlutterBluePlus.turnOn();
      _startScan();
    }
  }

  void _startScan() async {
    try {
      // 🔥 الحل الجذري: إيقاف أي فحص قديم وتنظيف الـ Stream
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();

      await Future.delayed(const Duration(milliseconds: 500));

      // 3. بدء الفحص بأقصى سرعة (Low Latency) لتحديث الـ dBm لحظياً
      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true, // تحديث مستمر للقوة الإشارية
      );

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;

        for (var result in results) {
          final String id = result.device.remoteId.str;
          final String name = result.device.platformName;

          // التحقق من الـ UUID الخاص بنا
          bool isTarget = result.advertisementData.serviceUuids.contains(targetServiceUuid);

          if (isTarget || name.contains("ESP32") || name.contains("OpticVerse")) {
            setState(() {
              int rssi = result.rssi;
              double rawDist = _rssiToDistance(rssi);

              // تكنولوجيا التنعيم: تجعل النقطة لا "تقفز" بل تتحرك بسلاسة
              _smoothDistanceMap[id] = _applySmoothing(_smoothDistanceMap[id] ?? rawDist, rawDist);

              // حساب الموقع (الزاوية تعتمد على الـ ID لثبات مكان الجهاز في الدائرة)
              double angle = (id.hashCode % 360) * pi / 180;
              double radarDist = _smoothDistanceMap[id]!.clamp(0.1, 3.5);

              users[id] = Offset(cos(angle) * radarDist, sin(angle) * radarDist);
              rssiMap[id] = rssi;
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Bluetooth Error: $e");
    }
  }

  // معامل التنعيم (0.1 يعني نعومة عالية جداً واستجابة هادئة)
  double _applySmoothing(double prev, double curr) {
    return prev + 0.12 * (curr - prev);
  }

  // تحويل الـ dBm لمسافة (Scale الرادار)
  double _rssiToDistance(int rssi) {
    if (rssi == 0) return 4.0;
    const int txPower = -59; // القوة المرجعية عند 1 متر
    return pow(10, (txPower - rssi) / 20).toDouble();
  }

  // دالة لتحديد لون الحالة (قريب/بعيد)
  Color _getStatusColor(int rssi) {
    if (rssi > -60) return Colors.greenAccent;
    if (rssi > -75) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _controller.dispose();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060612),
      appBar: AppBar(
        title: const Text("indoor positioning system", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // منطقة الرادار (الرسم)
          Expanded(
            flex: 3,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Center(
                  child: CustomPaint(
                    size: const Size(320, 320),
                    painter: RadarGridPainter(
                      users: users,
                      angle: _controller.value * 2 * pi,
                    ),
                  ),
                );
              },
            ),
          ),

          // منطقة البيانات (الاحترافية)
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: users.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                  : ListView(
                children: rssiMap.entries.map((e) {
                  return ListTile(
                    leading: Icon(Icons.location_searching, color: _getStatusColor(e.value)),
                    title: Text("Device ID: ${e.key.substring(e.key.length - 6)}", style: const TextStyle(color: Colors.white)),
                    subtitle: Text(e.value > -60 ? "بجانبك تماماً" : "بعيد قليلاً", style: TextStyle(color: _getStatusColor(e.value).withOpacity(0.7))),
                    trailing: Text("${e.value} dBm", style: TextStyle(color: _getStatusColor(e.value), fontWeight: FontWeight.bold, fontSize: 18)),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}