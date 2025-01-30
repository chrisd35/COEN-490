import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEManager extends ChangeNotifier {
  // Singleton instance
  static final BLEManager _instance = BLEManager._internal();
  factory BLEManager() => _instance;
  BLEManager._internal();

  // Device connection state
  BluetoothDevice? _connectedDevice;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Scan for BLE devices
  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    // Start scanning for devices
    FlutterBluePlus.startScan(timeout: timeout);

    // Return the scan results stream
    return FlutterBluePlus.scanResults;
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    _connectedDevice = device;
     notifyListeners();
    print("Connected to: ${device.name}");
  }

  // Disconnect from the device
  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      notifyListeners(); 
      print("Disconnected from device");
    }
  }

// Listen to the device's connection state
  Stream<BluetoothConnectionState> getDeviceState(BluetoothDevice device) {
    return device.connectionState;
  }
  
  // Discover services and characteristics
  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }

  // Read data from a characteristic
  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  // Write data to a characteristic
  Future<void> writeCharacteristic(BluetoothCharacteristic characteristic, List<int> data) async {
    await characteristic.write(data);
  }

  // Listen to notifications from a characteristic
  Stream<List<int>> listenToCharacteristic(BluetoothCharacteristic characteristic) {
    characteristic.setNotifyValue(true);
    return characteristic.value;
  }
}