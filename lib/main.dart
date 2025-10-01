import 'package:flutter/material.dart';

void main() {
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
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size; // device size

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height, // forces full height
                minWidth: size.width,   // forces full width
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // center vertically
                  crossAxisAlignment: CrossAxisAlignment.center, // center horizontally
                  children: [
                    SizedBox(
                      width: size.width * 0.9, // keep cards within screen
                      child: Column(
                        children: [
                          _welcomeCard(),
                          const SizedBox(height: 16),
                          _deviceStatusCard(),
                          const SizedBox(height: 16),
                          _statCard("Pulse Rate", "68", "BPM", "Normal"),
                          const SizedBox(height: 12),
                          _statCard("Oxygen Level", "97", "%", "Normal"),
                          const SizedBox(height: 16),
                          _sevenDayAverages(),
                          const SizedBox(height: 16),
                          _recentReadings(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Your Widgets ---
  Widget _welcomeCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // center text
          children: [
            const Text(
              "Welcome back, Demo",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Sunday, September 28, 2025 at 12:28 PM",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceStatusCard() {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Device Status",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 6,
                  backgroundColor: Colors.teal,
                ),
                const SizedBox(width: 8),
                const Text("Connected to HealthTracker Max"),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
              child: const Text("Change Device"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              child: const Text("Disconnect"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, String unit, String status) {
    return Card(
      color: const Color(0xFF0D1B2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.tealAccent),
                ),
                const SizedBox(width: 4),
                Text(unit,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Text(status,
                style: const TextStyle(color: Colors.greenAccent)),
          ],
        ),
      ),
    );
  }

  Widget _sevenDayAverages() {
    return Card(
      color: const Color(0xFF11291F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("7-Day Averages",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _averageRow("Average Pulse Rate", "69", "BPM"),
            const SizedBox(height: 12),
            _averageRow("Average Oxygen Level", "97", "%"),
            const SizedBox(height: 8),
            const Text("Last reading: Just now",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _averageRow(String title, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _recentReadings() {
    return Card(
      color: const Color(0xFF2C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("Recent Readings",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _readingRow("78", "99"),
            _readingRow("68", "97"),
            _readingRow("76", "96"),
          ],
        ),
      ),
    );
  }

  Widget _readingRow(String bpm, String oxygen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("$bpm BPM",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent)),
          const SizedBox(width: 24),
          Text("$oxygen %",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent)),
          const SizedBox(width: 24),
          const Text("Just now",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}