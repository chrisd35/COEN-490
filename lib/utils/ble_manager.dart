import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'dart:async';

class BLEManager extends ChangeNotifier {
  static final BLEManager _instance = BLEManager._internal();
  factory BLEManager() => _instance;
  BLEManager._internal();

  // Device states
  BluetoothDevice? _connectedDevice;
  bool _isRecording = false;
  List<int> _audioBuffer = [];
  
  // Audio metrics for heart sound monitoring
  double _currentAmplitude = 0;
  double _peakAmplitude = 0;
  List<double> _recentAmplitudes = [];
  
  // Constants for heart sound processing
  static const int SAMPLE_RATE = 4000;  // Optimized for heart sounds
  static const int BITS_PER_SAMPLE = 16;
  static const int CHANNELS = 1;
  
  // Service and Characteristic UUIDs
  static const String SERVICE_UUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
  static const String AUDIO_CHARACTERISTIC_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214";

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isRecording => _isRecording;
  List<int> get audioBuffer => _audioBuffer;
  double get currentAmplitude => _currentAmplitude;
  double get peakAmplitude => _peakAmplitude;
  List<double> get recentAmplitudes => _recentAmplitudes;

  // Get a copy of the audio buffer
  List<int> getAudioBuffer() {
    return List<int>.from(_audioBuffer);
  }

  // Clear the audio buffer
  void clearAudioBuffer() {
    _audioBuffer.clear();
    _recentAmplitudes.clear();
    _currentAmplitude = 0;
    _peakAmplitude = 0;
    notifyListeners();
  }

  // Scan for BLE devices
  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  // Connect to device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;
      notifyListeners();
      print("Connected to: ${device.name}");
      
      // Setup audio service after connection
      await _setupAudioService();
    } catch (e) {
      print("Error connecting to device: $e");
      rethrow;
    }
  }

  // Process incoming audio data
  void _processAudioData(List<int> data) {
    if (data.isEmpty) return;

    try {
      // Convert bytes to 16-bit samples
      Int16List samples = Int16List.fromList(
        List.generate(data.length ~/ 2, (i) {
          return (data[i * 2] | (data[i * 2 + 1] << 8));
        })
      );

      // Calculate amplitude
      double sumSquares = 0;
      double maxAmp = 0;
      for (int sample in samples) {
        double amplitude = sample.abs() / 32768.0;  // Normalize to 0-1
        sumSquares += amplitude * amplitude;
        maxAmp = maxAmp < amplitude ? amplitude : maxAmp;
      }

      _currentAmplitude = maxAmp;
      _peakAmplitude = _peakAmplitude < maxAmp ? maxAmp : _peakAmplitude;
      
      // Keep track of recent amplitudes for visualization
      _recentAmplitudes.add(maxAmp);
      if (_recentAmplitudes.length > 100) {  // Keep last 100 values
        _recentAmplitudes.removeAt(0);
      }

      // Add to main buffer
      _audioBuffer.addAll(data);
      notifyListeners();
    } catch (e) {
      print("Error processing audio data: $e");
    }
  }

  // Setup audio service and characteristics
  Future<void> _setupAudioService() async {
    if (_connectedDevice == null) return;

    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      print("Initial service discovery found ${services.length} services");
      
      for (var service in services) {
        print("Found service: ${service.uuid.toString().toUpperCase()}");
        if (service.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase()) {
          print("Found matching audio service");
          for (var characteristic in service.characteristics) {
            print("Found characteristic: ${characteristic.uuid.toString().toUpperCase()}");
            if (characteristic.uuid.toString().toUpperCase() == AUDIO_CHARACTERISTIC_UUID.toUpperCase()) {
              print("Setting up audio characteristic notifications");
              await characteristic.setNotifyValue(true);
              characteristic.value.listen(
                (value) {
                  if (_isRecording) {
                    _processAudioData(value);
                  }
                },
                onError: (error) {
                  print("Error in characteristic listener: $error");
                }
              );
            }
          }
        }
      }
    } catch (e) {
      print("Error in _setupAudioService: $e");
      rethrow;
    }
  }

  // Discover services for a device
  Future<List<BluetoothService>> discoverServices() async {
    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }
    List<BluetoothService> services = await _connectedDevice!.discoverServices();
    print("Discovered ${services.length} services");
    return services;
  }

  // Listen to a specific characteristic
  Stream<List<int>> listenToCharacteristic(BluetoothCharacteristic characteristic) async* {
    try {
      print("Setting up characteristic listener for: ${characteristic.uuid}");
      await characteristic.setNotifyValue(true);
      yield* characteristic.value;
    } catch (e) {
      print("Error setting up characteristic listener: $e");
      rethrow;
    }
  }

  // Start recording
  Future<void> startRecording() async {
    if (_connectedDevice == null) {
      print("No device connected");
      throw Exception("No device connected");
    }

    try {
      print("Starting recording process...");
      clearAudioBuffer();
      List<BluetoothService> services = await discoverServices();
      
      // Find audio service and characteristic
      print("\nLooking for audio service: $SERVICE_UUID");
      BluetoothService audioService = services.firstWhere(
        (service) => service.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase()
      );
      
      BluetoothCharacteristic audioCharacteristic = audioService.characteristics.firstWhere(
        (char) => char.uuid.toString().toUpperCase() == AUDIO_CHARACTERISTIC_UUID.toUpperCase()
      );
      
      // Check current notification state
      print("Current notification state: ${await audioCharacteristic.isNotifying}");
      
      // Enable notifications to start recording
      print("Enabling notifications to start recording");
      await audioCharacteristic.setNotifyValue(true);
      
      // Verify notification state
      bool isNotifying = await audioCharacteristic.isNotifying;
      print("Notification state after enable: $isNotifying");
      
      _isRecording = true;
      notifyListeners();
      print("Recording started successfully");
      
    } catch (e) {
      print("Error in startRecording: $e");
      rethrow;
    }
  }

  // Stop recording
  Future<List<int>> stopRecording() async {
    if (_connectedDevice == null) {
      print("No device connected");
      throw Exception("No device connected");
    }

    try {
      print("Stopping recording...");
      List<BluetoothService> services = await discoverServices();
      
      BluetoothService audioService = services.firstWhere(
        (service) => service.uuid.toString().toUpperCase() == SERVICE_UUID.toUpperCase()
      );
      
      BluetoothCharacteristic audioCharacteristic = audioService.characteristics.firstWhere(
        (char) => char.uuid.toString().toUpperCase() == AUDIO_CHARACTERISTIC_UUID.toUpperCase()
      );
      
      // Disable notifications to stop recording
      await audioCharacteristic.setNotifyValue(false);
      _isRecording = false;
      
      // Get current buffer contents
      List<int> recordedData = getAudioBuffer();
      
      // Clear the buffer after getting the data
      clearAudioBuffer();
      
      print("Recording stopped successfully");
      return recordedData;
      
    } catch (e) {
      print("Error stopping recording: $e");
      rethrow;
    }
  }

  // Disconnect from device
  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        print("Disconnecting from device...");
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _isRecording = false;
        clearAudioBuffer();
        print("Disconnected successfully");
      } catch (e) {
        print("Error disconnecting: $e");
        rethrow;
      }
    }
  }

  // Get device connection state
  Stream<BluetoothConnectionState> getDeviceState(BluetoothDevice device) {
    return device.connectionState;
  }
}