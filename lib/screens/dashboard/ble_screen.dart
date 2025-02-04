import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/audio_service.dart';
import '/utils/ble_manager.dart';
import 'dart:typed_data';

class BLEScreen extends StatefulWidget {
  @override
  _BLEScreenState createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> {
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  bool _isScanning = false;


  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startScan();
  }

  void _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    if (await Permission.location.isGranted &&
        await Permission.bluetooth.isGranted &&
        await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      print("All permissions granted");
    } else {
      print("Permissions not granted");
    }
  }

  void _startScan() {
    setState(() {
      _isScanning = true; // Start scanning
    });
    print("Starting BLE scan...");
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    bleManager.scanDevices(timeout: Duration(seconds: 10)).listen((results) {
      print("Found ${results.length} devices");
      setState(() {
        scanResults = results;
        _isScanning = false; // Stop scanning when results are received
      });
    }, onError: (error) {
      print("BLE scan error: $error");
       setState(() {
        _isScanning = false; // Stop scanning on error
      });
    });
  }

void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isScanning = true; // Show loading while connecting
    });
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    await bleManager.connectToDevice(device);

    // Discover services
    List<BluetoothService> services = await bleManager.discoverServices(device);
    for (BluetoothService service in services) {
      // Find the audio service
      if (service.uuid.toString() == "19B10000-E8F2-537E-4F6C-D104768A1214") {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          // Find the audio characteristic
          if (characteristic.uuid.toString() == "19B10001-E8F2-537E-4F6C-D104768A1214") {
            // Start listening to the audio characteristic
            bleManager.listenToCharacteristic(characteristic).listen((data) {
              // Forward audio data to a dedicated service or database
              AudioService().saveAudioData(data);
            });
            break;
          }
        }
        break;
      }
    }
    
    setState(() {
      connectedDevice = device;
      _isScanning = false; // Stop loading after connection
    });

    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text("Connected to ${device.name.isEmpty ? "Unknown Device" : device.name}"),
      duration: Duration(seconds: 2),
    ),
  );
    
    Future.delayed(Duration(seconds: 2), () {
    Navigator.pop(context);
  });
  }


  void _disconnectDevice() async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    await bleManager.disconnectDevice();
    setState(() {
      connectedDevice = null;
    });
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BLE Devices"),
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final device = scanResults[index].device;
                    return ListTile(
                      title: Text(device.name.isEmpty ? "Unknown Device" : device.name),
                      subtitle: Text(device.id.toString()),
                      onTap: () => _connectToDevice(device),
                    );
                  },
                ),
              ),
              if (connectedDevice != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text("Connected to: ${connectedDevice!.name}"),
                      ElevatedButton(
                        onPressed: _disconnectDevice,
                        child: Text("Disconnect"),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Loading indicator
          if (_isScanning)
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}