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

  // Audio metrics
  double _currentAmplitude = 0;
  double _peakAmplitude = 0;
  List<double> _recentAmplitudes = [];

  // Constants
  static const int SAMPLE_RATE = 4000;
  static const int BITS_PER_SAMPLE = 16;
  static const int CHANNELS = 1;

  // UUIDs
  static const String SERVICE_UUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
  static const String AUDIO_CHARACTERISTIC_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214";
  static const String CONTROL_CHARACTERISTIC_UUID = "19B10002-E8F2-537E-4F6C-D104768A1214";

  // Characteristics
  BluetoothCharacteristic? _audioCharacteristic;
  BluetoothCharacteristic? _controlCharacteristic;
  StreamSubscription? _audioSubscription;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isRecording => _isRecording;
  List<int> get audioBuffer => _audioBuffer;
  double get currentAmplitude => _currentAmplitude;
  double get peakAmplitude => _peakAmplitude;
  List<double> get recentAmplitudes => _recentAmplitudes;

  List<int> getAudioBuffer() {
    return List<int>.from(_audioBuffer);
  }

  void clearAudioBuffer() {
    _audioBuffer.clear();
    _recentAmplitudes.clear();
    _currentAmplitude = 0;
    _peakAmplitude = 0;
    notifyListeners();
  }

  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("Attempting to connect to device: ${device.name}");

      // Add retry mechanism
      int retryCount = 0;
      bool connected = false;

      while (!connected && retryCount < 3) {
        try {
          await device.connect(timeout: Duration(seconds: 10));
          connected = true;
        } catch (e) {
          print("Connection attempt ${retryCount + 1} failed: $e");
          retryCount++;
          if (retryCount < 3) {
            await Future.delayed(Duration(seconds: 2));
          } else {
            rethrow;
          }
        }
      }

      _connectedDevice = device;

      // Add delay after connection
      await Future.delayed(Duration(milliseconds: 2000));

      // Setup services and characteristics
      await _setupAudioService();

      notifyListeners();
      print("Successfully connected and setup device: ${device.name}");
    } catch (e) {
      print("Error connecting to device: $e");
      rethrow;
    }
  }

  // Helper function to normalize UUIDs
  String normalizeUuid(String uuid) {
    // Remove dashes and curly braces, and convert to uppercase
    return uuid.replaceAll(RegExp(r'[{}-\s]', caseSensitive: false), '').toUpperCase();
  }

Future<void> _setupAudioService() async {
  if (_connectedDevice == null) return;

  try {
    print("Starting service discovery...");
    await Future.delayed(Duration(milliseconds: 1000));

    bool characteristicsFound = false;
    int retryCount = 0;
    const int maxRetries = 3;

    while (!characteristicsFound && retryCount < maxRetries) {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      print("\nAttempt ${retryCount + 1}: Found ${services.length} services");

      for (var service in services) {
        String serviceUuid = normalizeUuid(service.uuid.toString());
        print("\nExamining Service: $serviceUuid");
        print("Number of characteristics: ${service.characteristics.length}");

        if (serviceUuid == normalizeUuid(SERVICE_UUID)) {
          print("\nFound target service!");

          // Look for control characteristic
          for (var char in service.characteristics) {
            String charUuid = normalizeUuid(char.uuid.toString());
            print("Looking for control characteristic with UUID: ${normalizeUuid(CONTROL_CHARACTERISTIC_UUID)}");
            print("Found characteristic UUID: $charUuid");

            if (charUuid == normalizeUuid(CONTROL_CHARACTERISTIC_UUID)) {
              _controlCharacteristic = char;
              print("Found control characteristic");
            } else if (charUuid == normalizeUuid(AUDIO_CHARACTERISTIC_UUID)) {
              _audioCharacteristic = char;
              print("Found audio characteristic");
            }
          }

          // Check if both characteristics are found
          characteristicsFound = _audioCharacteristic != null && _controlCharacteristic != null;
          if (characteristicsFound) {
            print("Both characteristics found successfully!");
          } else {
            print("\nMissing characteristics:");
            print("Audio characteristic: ${_audioCharacteristic != null}");
            print("Control characteristic: ${_controlCharacteristic != null}");
          }
        }
      }

      if (!characteristicsFound) {
        retryCount++;
        if (retryCount < maxRetries) {
          print("\nRetrying service discovery in 1 second...");
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }

    if (!characteristicsFound) {
      throw Exception("Failed to find all required characteristics after $maxRetries attempts");
    }
  } catch (e) {
    print("Error in _setupAudioService: $e");
    rethrow;
  }
}

  void _processAudioData(List<int> data) {
    if (data.isEmpty) return;

    try {
      Int16List samples = Int16List.fromList(
        List.generate(data.length ~/ 2, (i) {
          return (data[i * 2] | (data[i * 2 + 1] << 8));
        }),
      );

      double maxAmp = 0;
      for (int sample in samples) {
        double amplitude = sample.abs() / 32768.0;
        maxAmp = maxAmp < amplitude ? amplitude : maxAmp;
      }

      _currentAmplitude = maxAmp;
      _peakAmplitude = _peakAmplitude < maxAmp ? maxAmp : _peakAmplitude;

      _recentAmplitudes.add(maxAmp);
      if (_recentAmplitudes.length > 100) {
        _recentAmplitudes.removeAt(0);
      }

      _audioBuffer.addAll(data);
      notifyListeners();
    } catch (e) {
      print("Error processing audio data: $e");
    }
  }

  Future<List<BluetoothService>> discoverServices() async {
    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }
    return await _connectedDevice!.discoverServices();
  }

  Stream<List<int>> listenToCharacteristic(BluetoothCharacteristic characteristic) async* {
    try {
      print("Setting up listener for characteristic: ${characteristic.uuid}");
      await characteristic.setNotifyValue(true);
      yield* characteristic.value;
    } catch (e) {
      print("Error setting up characteristic listener: $e");
      rethrow;
    }
  }

  Future<void> startRecording() async {
    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }

    try {
      print("Starting recording...");
      clearAudioBuffer();

      if (_controlCharacteristic == null || _audioCharacteristic == null) {
        throw Exception("Required characteristics not found");
      }

      // Send start command
      await _controlCharacteristic!.write([0x01], withoutResponse: true);
      print("Sent start command to control characteristic");

      // Setup audio listener
      await _audioCharacteristic!.setNotifyValue(true);
      _audioSubscription = _audioCharacteristic!.value.listen(
        (value) {
          if (_isRecording) {
            _processAudioData(value);
          }
        },
        onError: (error) {
          print("Error in audio listener: $error");
        },
      );

      _isRecording = true;
      notifyListeners();
      print("Recording started successfully");
    } catch (e) {
      print("Error in startRecording: $e");
      rethrow;
    }
  }

  Future<List<int>> stopRecording() async {
    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }

    try {
      print("Stopping recording...");

      await _audioSubscription?.cancel();
      _audioSubscription = null;

      if (_controlCharacteristic != null) {
        await _controlCharacteristic!.write([0x00], withoutResponse: true);
      }

      if (_audioCharacteristic != null) {
        await _audioCharacteristic!.setNotifyValue(false);
      }

      _isRecording = false;
      List<int> recordedData = getAudioBuffer();
      clearAudioBuffer();

      print("Recording stopped successfully");
      return recordedData;
    } catch (e) {
      print("Error in stopRecording: $e");
      rethrow;
    }
  }

  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        print("Disconnecting device...");
        await _audioSubscription?.cancel();
        _audioSubscription = null;
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _isRecording = false;
        _audioCharacteristic = null;
        _controlCharacteristic = null;
        clearAudioBuffer();
        print("Disconnected successfully");
      } catch (e) {
        print("Error disconnecting: $e");
        rethrow;
      }
    }
  }

  Stream<BluetoothConnectionState> getDeviceState(BluetoothDevice device) {
    return device.connectionState;
  }
}