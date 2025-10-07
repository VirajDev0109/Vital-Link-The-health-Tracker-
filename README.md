# vital_link

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


**For perfectly working bluetooth service**
- Download the BLE_Server.exe & add to the project directory
- Then Add the BLE_Server.exe location path to codes server path where needed i.e for this project

(void main() async {
  // INTEGRATED: WinBle initialization is required before running the app
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print("Initializing WinBle...");
    // IMPORTANT: Make sure this path to BLEServer.exe is correct for your system
    await WinBle.initialize(
      serverPath:
          'C:/Users/aryan/OneDrive/Desktop/oximeter_app/flutter_application_1/BLEServer.exe',) <--------- RIGHT HERE UR CUSTOM PATH!!!
