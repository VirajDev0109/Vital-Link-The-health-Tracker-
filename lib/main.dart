import 'dart:async';
import 'package:flutter/material.dart';
import 'package:win_ble/win_ble.dart';
import 'package:fl_chart/fl_chart.dart';

const String DATA_SERVICE_UUID = "49535343-fe7d-4ae5-8fa9-9fafd205e455";
const String RECEIVE_CHARACTERISTIC_UUID =
    "49535343-1e4d-4bd9-ba61-23c647249616";

void main() async {
  // INTEGRATED: WinBle initialization is required before running the app
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print("Initializing WinBle...");
    // IMPORTANT: Make sure this path to BLEServer.exe is correct for your system
    await WinBle.initialize(
      serverPath:
          'C:/Users/aryan/OneDrive/Desktop/oximeter_app/flutter_application_1/BLEServer.exe',
    );
    print("WinBle initialized");
  } catch (e) {
    print("Error initializing WinBle: $e");
  }
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Health Tracker",
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F2027),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16213E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

// Data point class for storing readings with timestamps
class HealthReading {
  final DateTime timestamp;
  final int heartRate;
  final int spO2;

  HealthReading({
    required this.timestamp,
    required this.heartRate,
    required this.spO2,
  });
}

// INTEGRATED: Converted to a StatefulWidget to manage BLE state
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // INTEGRATED: All state variables from the oximeter code
  List<BleDevice> scanResults = [];
  String? connectedDeviceAddress;
  String? connectedDeviceName;
  StreamSubscription<BleDevice>? scanSubscription;
  StreamSubscription<bool>? connectionSubscription;
  StreamSubscription<dynamic>? dataSubscription;
  int heartRate = 0;
  int spO2 = 0;
  bool noFinger = true;
  bool isScanning = false;
  bool isConnected = false;
  bool isBluetoothAvailable = false;
  List<int> buffer = [];

  // NEW: Store saved readings (persistent across session)
  List<HealthReading> savedReadings = [];

  // Show save notification
  bool showSaveSuccess = false;

  @override
  void initState() {
    super.initState();
    checkBluetoothAvailability();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    dataSubscription?.cancel();
    connectionSubscription?.cancel();
    if (connectedDeviceAddress != null) {
      WinBle.disconnect(connectedDeviceAddress!);
    }
    WinBle.dispose();
    super.dispose();
  }

  // NEW: Save current reading manually
  void _saveReading() {
    if (heartRate > 0 && spO2 > 0 && !noFinger) {
      setState(() {
        savedReadings.add(
          HealthReading(
            timestamp: DateTime.now(),
            heartRate: heartRate,
            spO2: spO2,
          ),
        );
        showSaveSuccess = true;
      });

      // Hide success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            showSaveSuccess = false;
          });
        }
      });
    }
  }

  // NEW: Calculate average for saved readings
  Map<String, double> _calculateAverages() {
    if (savedReadings.isEmpty) {
      return {'heartRate': 0, 'spO2': 0};
    }

    double avgHR =
        savedReadings.map((r) => r.heartRate).reduce((a, b) => a + b) /
        savedReadings.length;
    double avgSpO2 =
        savedReadings.map((r) => r.spO2).reduce((a, b) => a + b) /
        savedReadings.length;

    return {'heartRate': avgHR, 'spO2': avgSpO2};
  }

  Future<void> checkBluetoothAvailability() async {
    try {
      final state = await WinBle.getBluetoothState();
      setState(() {
        isBluetoothAvailable = state == BleState.On;
      });
    } catch (e) {
      print("Error checking Bluetooth: $e");
    }
  }

  Future<void> startScan(StateSetter modalSetState) async {
    if (!isBluetoothAvailable) {
      await checkBluetoothAvailability();
      return;
    }

    modalSetState(() {
      scanResults.clear();
      isScanning = true;
    });

    try {
      scanSubscription = WinBle.scanStream.listen((device) {
        if (device.name.isNotEmpty &&
            !scanResults.any((d) => d.address == device.address)) {
          modalSetState(() {
            scanResults.add(device);
          });
        }
      });

      WinBle.startScanning();
      await Future.delayed(const Duration(seconds: 10));
      await stopScan(modalSetState);
    } catch (e) {
      print("Error scanning: $e");
      modalSetState(() {
        isScanning = false;
      });
    }
  }

  Future<void> stopScan(StateSetter modalSetState) async {
    try {
      WinBle.stopScanning();
      await scanSubscription?.cancel();
      modalSetState(() {
        isScanning = false;
      });
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  Future<void> connectToDevice(String address, String name) async {
    try {
      connectionSubscription = WinBle.connectionStreamOf(address).listen((
        connected,
      ) {
        if (!connected) {
          if (mounted) disconnectDevice();
        }
      });
      await WinBle.connect(address);
      setState(() {
        connectedDeviceAddress = address;
        connectedDeviceName = name;
        isConnected = true;
      });
      await Future.delayed(const Duration(seconds: 1));
      await discoverAndSubscribe(address);
    } catch (e) {
      print("Failed to connect: $e");
    }
  }

  Future<void> disconnectDevice() async {
    if (connectedDeviceAddress != null) {
      try {
        await dataSubscription?.cancel();
        await connectionSubscription?.cancel();
        await WinBle.disconnect(connectedDeviceAddress!);
      } catch (e) {
        print("Error disconnecting: $e");
      }
      setState(() {
        connectedDeviceAddress = null;
        connectedDeviceName = null;
        isConnected = false;
        heartRate = 0;
        spO2 = 0;
        noFinger = true;
        buffer.clear();
      });
    }
  }

  Future<void> discoverAndSubscribe(String address) async {
    try {
      final services = await WinBle.discoverServices(address);
      for (var serviceId in services) {
        if (serviceId.toLowerCase() == DATA_SERVICE_UUID.toLowerCase()) {
          final characteristics = await WinBle.discoverCharacteristics(
            address: address,
            serviceId: serviceId,
          );
          for (var char in characteristics) {
            if (char.uuid.toLowerCase() ==
                RECEIVE_CHARACTERISTIC_UUID.toLowerCase()) {
              await setupNotifications(address, serviceId, char.uuid);
              return;
            }
          }
        }
      }
    } catch (e) {
      print("Error discovering services: $e");
    }
  }

  Future<void> setupNotifications(
    String address,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    try {
      dataSubscription = WinBle.characteristicValueStream.listen((event) {
        if (event is Map &&
            event['characteristicId']?.toString().toLowerCase() ==
                characteristicUuid.toLowerCase()) {
          final data = event['value'] as List<dynamic>;
          final bytes = data.map((e) => e as int).toList();
          processRawData(bytes);
        }
      });
      await WinBle.subscribeToCharacteristic(
        address: address,
        serviceId: serviceUuid,
        characteristicId: characteristicUuid,
      );
    } catch (e) {
      print("Error setting up notifications: $e");
    }
  }

  void processRawData(List<int> data) {
    buffer.addAll(data);
    while (buffer.length >= 5) {
      int startIndex = -1;
      for (int i = 0; i < buffer.length; i++) {
        if ((buffer[i] & 0x80) != 0) {
          startIndex = i;
          break;
        }
      }
      if (startIndex == -1) {
        buffer.clear();
        break;
      }
      if (startIndex > 0) {
        buffer.removeRange(0, startIndex);
      }
      if (buffer.length < 5) break;
      List<int> packet = buffer.sublist(0, 5);
      buffer.removeRange(0, 5);
      parsePacket(packet);
    }
  }

  void parsePacket(List<int> packet) {
    try {
      int byte2 = packet[2];
      bool noFingerBit = (byte2 & 0x20) != 0;
      int prHighBit = (byte2 & 0x40) >> 6;
      int prLowBits = packet[3] & 0x7F;
      int spo2Value = packet[4] & 0x7F;
      int pulseRate = prLowBits | (prHighBit << 7);
      setState(() {
        if (spo2Value >= 70 && spo2Value <= 100) spO2 = spo2Value;
        if (pulseRate > 0 && pulseRate < 255) heartRate = pulseRate;
        noFinger = noFingerBit;
      });
    } catch (e) {
      print("Error parsing packet: $e");
    }
  }

  void _showDeviceScanner(BuildContext context) {
    scanResults.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Scan for Oximeter",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: isScanning
                        ? null
                        : () => startScan(modalSetState),
                    icon: isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(isScanning ? "Scanning..." : "Start Scan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C75),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (scanResults.isEmpty && !isScanning)
                    const Expanded(
                      child: Center(
                        child: Text(
                          "No devices found.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: scanResults.length,
                      itemBuilder: (context, index) {
                        final device = scanResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: const Color(0xFF1A1A2E),
                          child: ListTile(
                            leading: const Icon(
                              Icons.bluetooth,
                              color: Color(0xFF3282B8),
                            ),
                            title: Text(device.name),
                            subtitle: Text(
                              device.address,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F4C75),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text('Connect'),
                              onPressed: () {
                                stopScan(modalSetState);
                                connectToDevice(device.address, device.name);
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final averages = _calculateAverages();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _welcomeCard(),
                    const SizedBox(height: 16),
                    _deviceStatusCard(),
                    const SizedBox(height: 16),
                    if (isConnected && noFinger) ...[
                      _noFingerWarningCard(),
                      const SizedBox(height: 16),
                    ],
                    _liveReadingCard(),
                    const SizedBox(height: 16),
                    // NEW: Save Button
                    _saveButton(),
                    const SizedBox(height: 16),
                    _chartCard(
                      "Heart Rate Trend",
                      savedReadings,
                      true,
                      averages['heartRate']!,
                    ),
                    const SizedBox(height: 16),
                    _chartCard(
                      "Oxygen Level Trend",
                      savedReadings,
                      false,
                      averages['spO2']!,
                    ),
                    const SizedBox(height: 16),
                    _averagesCard(averages),
                    const SizedBox(height: 16),
                    _recentReadings(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // Success notification
              if (showSaveSuccess)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Reading Saved!",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    // Updated to current date and time: 04:45 PM IST, Tuesday, October 07, 2025
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.waving_hand, color: Color(0xFFFFD700), size: 24),
                SizedBox(width: 8),
                Text(
                  "Welcome back, Demo",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  "Tuesday, October 07, 2025 at 04:45 PM IST",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getWeekday(int day) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[day - 1];
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _deviceStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? const Color(0xFF3282B8) : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device Status",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      isConnected
                          ? connectedDeviceName ?? "Connected"
                          : "Not Connected",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeviceScanner(context),
                    icon: const Icon(Icons.search),
                    label: const Text("Change Device"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C75),
                      minimumSize: const Size(0, 45),
                    ),
                  ),
                ),
                if (isConnected) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: disconnectDevice,
                      icon: const Icon(Icons.close),
                      label: const Text("Disconnect"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        minimumSize: const Size(0, 45),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveReadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.monitor_heart, color: Color(0xFF3282B8)),
                SizedBox(width: 8),
                Text(
                  "Live Reading",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _liveStatItem(
                    Icons.favorite,
                    "Pulse Rate",
                    heartRate > 0 ? heartRate.toString() : "--",
                    "BPM",
                    Colors.red[400]!,
                  ),
                ),
                Container(width: 1, height: 80, color: Colors.grey[700]),
                Expanded(
                  child: _liveStatItem(
                    Icons.water_drop,
                    "Oxygen",
                    spO2 > 0 ? spO2.toString() : "--",
                    "%",
                    Colors.cyan[400]!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveStatItem(
    IconData icon,
    String label,
    String value,
    String unit,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          ],
        ),
      ],
    );
  }

  Widget _noFingerWarningCard() {
    return Card(
      color: Colors.orange[900]?.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[300],
              size: 28,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                "No finger detected. Please place your finger on the sensor.",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    final canSave = isConnected && !noFinger && heartRate > 0 && spO2 > 0;

    return ElevatedButton.icon(
      onPressed: canSave ? _saveReading : null,
      icon: const Icon(Icons.save, size: 24),
      label: const Text(
        "Save Current Reading",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: canSave ? const Color(0xFF0F4C75) : Colors.grey[800],
        foregroundColor: canSave ? Colors.white : Colors.grey[600],
        minimumSize: const Size(double.infinity, 56),
        elevation: canSave ? 4 : 0,
      ),
    );
  }

  Widget _chartCard(
    String title,
    List<HealthReading> data,
    bool isHeartRate,
    double average,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHeartRate ? Icons.show_chart : Icons.trending_up,
                  color: isHeartRate ? Colors.red[400] : Colors.cyan[400],
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insights, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    Text(
                      "No saved readings yet",
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Connect device and save readings to see trends",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 220,
                child: HealthChart(
                  readings: data,
                  isHeartRate: isHeartRate,
                  average: average,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _averagesCard(Map<String, double> averages) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Color(0xFF3282B8)),
                SizedBox(width: 8),
                Text(
                  "Session Averages",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _averageRow(
              Icons.favorite,
              "Average Pulse Rate",
              averages['heartRate']! > 0
                  ? averages['heartRate']!.toStringAsFixed(0)
                  : "--",
              "BPM",
              Colors.red[400]!,
            ),
            const SizedBox(height: 16),
            _averageRow(
              Icons.water_drop,
              "Average Oxygen Level",
              averages['spO2']! > 0
                  ? averages['spO2']!.toStringAsFixed(0)
                  : "--",
              "%",
              Colors.cyan[400]!,
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[800]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.data_usage, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  savedReadings.isNotEmpty
                      ? "Total Readings: ${savedReadings.length}"
                      : "No readings saved yet",
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _averageRow(
    IconData icon,
    String title,
    String value,
    String unit,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15))),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(unit, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
      ],
    );
  }

  Widget _recentReadings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Color(0xFF3282B8)),
                SizedBox(width: 8),
                Text(
                  "Recent Readings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (savedReadings.isEmpty)
              Center(
                child: Text(
                  "No recent readings",
                  style: TextStyle(color: Colors.grey[400]),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: savedReadings.length > 7 ? 7 : savedReadings.length,
                itemBuilder: (context, index) {
                  final reading =
                      savedReadings[savedReadings.length -
                          1 -
                          index]; // Reverse for most recent first
                  return ListTile(
                    title: Text(
                      "HR: ${reading.heartRate} BPM, SpO2: ${reading.spO2}%",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "${reading.timestamp.toLocal().toString().split('.')[0]}",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class HealthChart extends StatelessWidget {
  final List<HealthReading> readings;
  final bool isHeartRate;
  final double average;

  const HealthChart({
    super.key,
    required this.readings,
    required this.isHeartRate,
    required this.average,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = readings.asMap().entries.map((entry) {
      int index = entry.key;
      HealthReading reading = entry.value;
      double value = isHeartRate
          ? reading.heartRate.toDouble()
          : reading.spO2.toDouble();
      return FlSpot(index.toDouble(), value);
    }).toList();

    double minY = isHeartRate ? 40 : 80;
    double maxY = isHeartRate ? 120 : 100;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 10,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey[800]!, strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(color: Colors.grey[800]!, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[800]!),
        ),
        minX: 0,
        maxX: (readings.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: isHeartRate ? Colors.red[400]! : Colors.cyan[400]!,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: (isHeartRate ? Colors.red[400]! : Colors.cyan[400]!)
                  .withOpacity(0.1),
            ),
          ),
          // Average line
          LineChartBarData(
            spots: [
              FlSpot(0, average),
              FlSpot((readings.length - 1).toDouble(), average),
            ],
            isCurved: false,
            color: Colors.yellow[700]!,
            barWidth: 2,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
