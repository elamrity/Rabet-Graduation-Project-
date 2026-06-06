import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class IndoorPositioningScreen extends StatefulWidget {
  const IndoorPositioningScreen({super.key});

  @override
  State<IndoorPositioningScreen> createState() => _IndoorPositioningScreenState();
}

class _IndoorPositioningScreenState extends State<IndoorPositioningScreen> {
  // تخزين المسافات المنعمة لكل جهاز بعد الفلترة
  Map<String, double> filteredDistances = {};

  // تخزين قيم الـ RSSI المفلترة باستخدام الـ EMA لمنع الشوشرة والتذبذب
  Map<String, double> emaRSSI = {};

  // الأجهزة الأربعة المستهدفة
  final List<String> targetDevices = ["ESP32_1", "ESP32_2", "ESP32_3", "ESP32_4"];

  // الـ UUID الخاص بمشروع OpticVerse
  final Guid targetServiceUuid = Guid("12345678-1234-1234-1234-1234567890ab");

  // معايرة الأجهزة عند مسافة 1 متر
  final Map<String, double> measuredPowerMap = {
    "ESP32_1": -55.0,
    "ESP32_2": -55.0,
    "ESP32_3": -55.0,
    "ESP32_4": -55.0,
  };

  // معامل البيئة (Path Loss Exponent)
  final double environmentFactor = 2.4;

  // معامل النعومة لفلتر الـ EMA (Alpha)
  final double emaAlpha = 0.20;

  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _startIPS();
  }

  void _startIPS() async {
    try {
      await FlutterBluePlus.stopScan();
      await Future.delayed(const Duration(milliseconds: 300));

      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true,
      );

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;

        for (var r in results) {
          String name = r.device.platformName;
          if (name.isEmpty && r.advertisementData.advName.isNotEmpty) {
            name = r.advertisementData.advName;
          }

          final int rawRssi = r.rssi;

          bool isOurDevice = targetDevices.contains(name) ||
              r.advertisementData.serviceUuids.contains(targetServiceUuid);

          if (isOurDevice && name.isNotEmpty) {
            setState(() {
              double prevRssi = emaRSSI[name] ?? rawRssi.toDouble();
              double filteredRssi = (emaAlpha * rawRssi) + ((1 - emaAlpha) * prevRssi);
              emaRSSI[name] = filteredRssi;

              double measuredPower = measuredPowerMap[name] ?? -55.0;
              double exponent = (measuredPower - filteredRssi) / (10 * environmentFactor);
              double calculatedDistance = pow(10, exponent).toDouble();

              if (calculatedDistance < 12.0 && calculatedDistance > 0.1) {
                filteredDistances[name] = calculatedDistance;
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint("IPS Scan Error: $e");
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
    // حساب عدد الأجهزة غير المتصلة حالياً (المسافة صفر أو لم تلتقط بعد)
    int offlineCount = targetDevices.where((name) {
      double d = filteredDistances[name] ?? 0.0;
      return d == 0.0;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFF03030F),
      body: Stack(
        children: [
          // خلفية الشبكة
          Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // 🔔 ويدجت الإشعارات في أعلى اليمين مع إصلاح التوافقية والألوان
          Positioned(
            top: 50,
            right: 20,
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50),
              // تم تعديل الخلفية هنا لتكون متوافقة عبر الـ style والأشكال البرمجية الآمنة
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                elevation: WidgetStateProperty.all(0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Colors.white10),
              ),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications, color: Colors.white, size: 30),
                  if (offlineCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$offlineCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text(
                      "حالة أجهزة الـ ESP32",
                      style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const PopupMenuDivider(),
                  ...targetDevices.map((name) {
                    double d = filteredDistances[name] ?? 0.0;
                    bool isOnline = d > 0.0;
                    return PopupMenuItem<String>(
                      enabled: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.black, fontSize: 13)),
                          Row(
                            children: [
                              Text(
                                isOnline ? "متصل" : "منفصل",
                                style: TextStyle(
                                  color: isOnline ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: isOnline ? Colors.green : Colors.red,
                              )
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ];
              },
            ),
          ),

          // لوحة الرادار المربعة
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.width * 0.85,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(20),
                color: Colors.black26,
              ),
              child: CustomPaint(
                painter: IPSPainter(distances: filteredDistances),
              ),
            ),
          ),

          // اللوحة السفلية لحالة الأجهزة
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 140,
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.white10),
              ),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: targetDevices.map((name) {
                  double d = filteredDistances[name] ?? 0.0;
                  bool isOnline = d > 0.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isOnline ? Colors.white54 : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: isOnline ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        !isOnline ? "OFF" : "${d.toStringAsFixed(1)}m",
                        style: TextStyle(
                          color: !isOnline
                              ? Colors.redAccent
                              : (d > 0 && d < 1.5 ? Colors.greenAccent : Colors.cyanAccent),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: isOnline ? Colors.green : Colors.red,
                      ),
                    ],
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

// كود الرسم الهندسي للرادار والشبكة
class IPSPainter extends CustomPainter {
  final Map<String, double> distances;
  IPSPainter({required this.distances});

  @override
  void paint(Canvas canvas, Size size) {
    final paintCyan = Paint()..color = Colors.cyanAccent..style = PaintingStyle.fill;
    final paintRed = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
    final paintCircle = Paint()..color = Colors.cyanAccent.withOpacity(0.025)..style = PaintingStyle.stroke;

    final paintUser = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    Offset p1 = Offset(size.width * 0.15, size.height * 0.15);
    Offset p2 = Offset(size.width * 0.85, size.height * 0.15);
    Offset p3 = Offset(size.width * 0.85, size.height * 0.85);
    Offset p4 = Offset(size.width * 0.15, size.height * 0.85);

    double d1 = (distances["ESP32_1"] ?? 0) * 45;
    double d2 = (distances["ESP32_2"] ?? 0) * 45;
    double d3 = (distances["ESP32_3"] ?? 0) * 45;
    double d4 = (distances["ESP32_4"] ?? 0) * 45;

    canvas.drawCircle(p1, 6, d1 > 0 ? paintCyan : paintRed);
    canvas.drawCircle(p2, 6, d2 > 0 ? paintCyan : paintRed);
    canvas.drawCircle(p3, 6, d3 > 0 ? paintCyan : paintRed);
    canvas.drawCircle(p4, 6, d4 > 0 ? paintCyan : paintRed);

    if (d1 > 0) canvas.drawCircle(p1, d1, paintCircle);
    if (d2 > 0) canvas.drawCircle(p2, d2, paintCircle);
    if (d3 > 0) canvas.drawCircle(p3, d3, paintCircle);
    if (d4 > 0) canvas.drawCircle(p4, d4, paintCircle);

    double totalWeight = 0.0;
    double sumX = 0.0;
    double sumY = 0.0;

    List<MapEntry<Offset, double>> activeBeacons = [];
    if (d1 > 0) activeBeacons.add(MapEntry(p1, d1));
    if (d2 > 0) activeBeacons.add(MapEntry(p2, d2));
    if (d3 > 0) activeBeacons.add(MapEntry(p3, d3));
    if (d4 > 0) activeBeacons.add(MapEntry(p4, d4));

    if (activeBeacons.length >= 2) {
      for (var beacon in activeBeacons) {
        double weight = 1.0 / (pow(beacon.value, 2) + 0.1);
        totalWeight += weight;
        sumX += beacon.key.dx * weight;
        sumY += beacon.key.dy * weight;
      }

      if (totalWeight > 0) {
        double userX = sumX / totalWeight;
        double userY = sumY / totalWeight;

        userX = userX.clamp(size.width * 0.12, size.width * 0.88);
        userY = userY.clamp(size.height * 0.12, size.height * 0.88);

        Offset userPos = Offset(userX, userY);

        canvas.drawCircle(userPos, 15, paintUser);
        canvas.drawCircle(userPos, 6, Paint()..color = Colors.white);
      }
    }
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white10..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), p);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), p);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}