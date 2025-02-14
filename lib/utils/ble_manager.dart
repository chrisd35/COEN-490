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

  // Recording timing control
  DateTime? _recordingStartTime;
  int _expectedSamples = 0;

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
    _recordingStartTime = null;
    _expectedSamples = 0;
    notifyListeners();
  }

  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("Attempting to connect to device: ${device.name}");

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
      await Future.delayed(Duration(milliseconds: 2000));
      await _setupAudioService();

      notifyListeners();
      print("Successfully connected and setup device: ${device.name}");
    } catch (e) {
      print("Error connecting to device: $e");
      rethrow;
    }
  }

  String normalizeUuid(String uuid) {
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

          if (serviceUuid == normalizeUuid(SERVICE_UUID)) {
            print("\nFound target service!");

            for (var char in service.characteristics) {
              String charUuid = normalizeUuid(char.uuid.toString());
              if (charUuid == normalizeUuid(CONTROL_CHARACTERISTIC_UUID)) {
                _controlCharacteristic = char;
                print("Found control characteristic");
              } else if (charUuid == normalizeUuid(AUDIO_CHARACTERISTIC_UUID)) {
                _audioCharacteristic = char;
                print("Found audio characteristic");
              }
            }

            characteristicsFound = _audioCharacteristic != null && _controlCharacteristic != null;
          }
        }

        if (!characteristicsFound) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }

      if (!characteristicsFound) {
        throw Exception("Failed to find all required characteristics");
      }
    } catch (e) {
      print("Error in _setupAudioService: $e");
      rethrow;
    }
  }

void _processAudioData(List<int> data) {
    if (data.isEmpty || !_isRecording) return;

    try {
        // Calculate precise expected buffer size
        Duration elapsed = DateTime.now().difference(_recordingStartTime!);
        int totalExpectedSamples = (SAMPLE_RATE * elapsed.inMilliseconds) ~/ 1000;
        int expectedBufferSize = totalExpectedSamples * 2; // 2 bytes per sample

        // Check if adding this data would exceed our expected size
        if (_audioBuffer.length >= expectedBufferSize) {
            print("Buffer full, skipping new data");
            return;
        }

        // Calculate how many bytes we can still add
        int remainingSpace = expectedBufferSize - _audioBuffer.length;
        int bytesToAdd = data.length;
        if (bytesToAdd > remainingSpace) {
            bytesToAdd = remainingSpace;
            print("Truncating incoming data to fit buffer");
        }

        // Process only the bytes we're going to keep
        Int16List samples = Int16List(bytesToAdd ~/ 2);
        ByteData bytes = ByteData.sublistView(Uint8List.fromList(data.sublist(0, bytesToAdd)));
        
        for (int i = 0; i < bytesToAdd ~/ 2; i++) {
            samples[i] = bytes.getInt16(i * 2, Endian.little);
            double amplitude = samples[i].abs() / 32768.0;
            
            _currentAmplitude = amplitude;
            if (amplitude > _peakAmplitude) {
                _peakAmplitude = amplitude;
            }
            
            _recentAmplitudes.add(amplitude);
            if (_recentAmplitudes.length > 100) {
                _recentAmplitudes.removeAt(0);
            }
        }
        
        // Add only the processed data
        _audioBuffer.addAll(data.sublist(0, bytesToAdd));

        // Debug info
        if (_audioBuffer.length % (SAMPLE_RATE * 2) == 0) { // Log every second
            print("Buffer status: ${_audioBuffer.length} bytes / $expectedBufferSize expected");
            print("Current time: ${elapsed.inSeconds} seconds");
        }

        notifyListeners();
    } catch (e) {
        print("Error processing audio data: $e");
    }
}

  Future<void> startRecording() async {
    try {
      print("Starting recording...");
      clearAudioBuffer();
      _recordingStartTime = DateTime.now();

      if (_connectedDevice == null) {
        throw Exception("No device connected");
      }

      if (_controlCharacteristic == null || _audioCharacteristic == null) {
        throw Exception("Required characteristics not found");
      }

      await _controlCharacteristic!.write([0x01], withoutResponse: true);
      print("Sent start command to control characteristic");

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
        
        // Calculate exact duration in whole seconds
        Duration totalDuration = DateTime.now().difference(_recordingStartTime!);
        int durationSeconds = ((totalDuration.inMilliseconds + 500) / 1000).floor();
        int expectedSamples = SAMPLE_RATE * durationSeconds;
        int expectedBytes = expectedSamples * 2;
        
        print("Recording summary:");
        print("Duration: $durationSeconds seconds");
        print("Expected samples: $expectedSamples");
        print("Expected bytes: $expectedBytes");
        print("Current buffer size: ${_audioBuffer.length}");

        // Stop BLE operations first
        await _audioSubscription?.cancel();
        _audioSubscription = null;

        if (_controlCharacteristic != null) {
            await _controlCharacteristic!.write([0x00], withoutResponse: true);
        }

        if (_audioCharacteristic != null) {
            await _audioCharacteristic!.setNotifyValue(false);
        }

        _isRecording = false;

        // Ensure exact buffer size
        if (_audioBuffer.length > expectedBytes) {
            print("Trimming buffer from ${_audioBuffer.length} to $expectedBytes bytes");
            _audioBuffer = _audioBuffer.sublist(0, expectedBytes);
        }

        List<int> recordedData = List<int>.from(_audioBuffer);
        
        print("Final recording stats:");
        print("Buffer size: ${recordedData.length} bytes");
        print("Sample count: ${recordedData.length ~/ 2}");
        print("Actual duration: ${recordedData.length / (2 * SAMPLE_RATE)} seconds");

        clearAudioBuffer();
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