import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('BLEManager');

class BLEManager extends ChangeNotifier {
  static final BLEManager _instance = BLEManager._internal();
  factory BLEManager() => _instance;
  BLEManager._internal();

  // Device states
  BluetoothDevice? _connectedDevice;
  bool _isRecording = false;
  List<int> _audioBuffer = [];
  final List<Map<String, dynamic>> _currentSessionReadings = [];

  // Audio metrics
  double _currentAmplitude = 0;
  double _peakAmplitude = 0;
  final List<double> _recentAmplitudes = [];

  // Recording timing control
  DateTime? _recordingStartTime;
  // Removed _expectedSamples as it's not used

  // New ECG and PulseOx buffers and metrics
  final List<int> _ecgBuffer = [];
  final List<Map<String, dynamic>> _pulseOxReadings = [];
  double _currentHeartRate = 0;
  double _currentSpO2 = 0;
  double _currentTemperature = 0;
  
  // Session timing
  DateTime? _sessionStartTime;

  // Constants - renamed to lowerCamelCase
  static const int sampleRate = 4000;
  static const int bitsPerSample = 16;
  static const int channels = 1;

  // UUIDs - renamed to lowerCamelCase
  static const String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  static const String audioCharacteristicUuid = "19B10001-E8F2-537E-4F6C-D104768A1214";
  static const String controlCharacteristicUuid = "19B10002-E8F2-537E-4F6C-D104768A1214";
  static const String pulseOxCharacteristicUuid = "19B10003-E8F2-537E-4F6C-D104768A1214";
  static const String ecgCharacteristicUuid = "19B10004-E8F2-537E-4F6C-D104768A1214";

  // Characteristics
  BluetoothCharacteristic? _audioCharacteristic;
  BluetoothCharacteristic? _controlCharacteristic;
  BluetoothCharacteristic? _pulseOxCharacteristic;
  BluetoothCharacteristic? _ecgCharacteristic;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _pulseOxSubscription;
  StreamSubscription? _ecgSubscription;

  // Existing getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isRecording => _isRecording;
  List<int> get audioBuffer => _audioBuffer;
  double get currentAmplitude => _currentAmplitude;
  double get peakAmplitude => _peakAmplitude;
  List<double> get recentAmplitudes => _recentAmplitudes;

  // New getters for ECG and PulseOx
  List<int> get ecgBuffer => _ecgBuffer;
  List<Map<String, dynamic>> get pulseOxReadings => _pulseOxReadings;
  double get currentHeartRate => _currentHeartRate;
  double get currentSpO2 => _currentSpO2;
  double get currentTemperature => _currentTemperature;
  List<Map<String, dynamic>> get currentSessionReadings => _currentSessionReadings;
  DateTime? get sessionStartTime => _sessionStartTime;

  Map<String, double> get sessionAverages {
    if (_currentSessionReadings.isEmpty) {
      return {
        'heartRate': 0,
        'spO2': 0,
        'temperature': 0,
      };
    }

    double sumHR = 0;
    double sumSpO2 = 0;
    double sumTemp = 0;

    for (var reading in _currentSessionReadings) {
      sumHR += reading['heartRate'];
      sumSpO2 += reading['spO2'];
      sumTemp += reading['temperature'];
    }

    return {
      'heartRate': sumHR / _currentSessionReadings.length,
      'spO2': sumSpO2 / _currentSessionReadings.length,
      'temperature': sumTemp / _currentSessionReadings.length,
    };
  }

  List<int> getAudioBuffer() {
    return List<int>.from(_audioBuffer);
  }

  void clearAudioBuffer() {
    _audioBuffer.clear();
    _recentAmplitudes.clear();
    _currentAmplitude = 0;
    _peakAmplitude = 0;
    _recordingStartTime = null;
    notifyListeners();
  }

  void clearECGBuffer() {
    _ecgBuffer.clear();
    notifyListeners();
  }

  void clearPulseOxReadings() {
    _currentSessionReadings.clear();
    _currentHeartRate = 0;
    _currentSpO2 = 0;
    _currentTemperature = 0;
    notifyListeners();
  }

  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _logger.info("Attempting to connect to device: ${device.platformName}");

      int retryCount = 0;
      bool connected = false;

      while (!connected && retryCount < 3) {
        try {
          await device.connect(timeout: const Duration(seconds: 10));
          connected = true;
        } catch (e) {
          _logger.warning("Connection attempt ${retryCount + 1} failed: $e");
          retryCount++;
          if (retryCount < 3) {
            await Future.delayed(const Duration(seconds: 2));
          } else {
            rethrow;
          }
        }
      }

      _connectedDevice = device;
      await Future.delayed(const Duration(milliseconds: 2000));
      await _setupServices(); // Changed from _setupAudioService to handle all services

      notifyListeners();
      _logger.info("Successfully connected and setup device: ${device.platformName}");
    } catch (e) {
      _logger.severe("Error connecting to device: $e");
      rethrow;
    }
  }

  String normalizeUuid(String uuid) {
    return uuid.replaceAll(RegExp(r'[{}-\s]', caseSensitive: false), '').toUpperCase();
  }

  Future<void> _setupServices() async {
    if (_connectedDevice == null) return;

    try {
      _logger.info("Starting service discovery...");
      await Future.delayed(const Duration(milliseconds: 1000));

      bool characteristicsFound = false;
      int retryCount = 0;
      const int maxRetries = 3;

      while (!characteristicsFound && retryCount < maxRetries) {
        List<BluetoothService> services = await _connectedDevice!.discoverServices();
        _logger.info("\nAttempt ${retryCount + 1}: Found ${services.length} services");

        for (var service in services) {
          String serviceUuid = normalizeUuid(service.uuid.toString());
          _logger.info("\nExamining Service: $serviceUuid");

          if (serviceUuid == normalizeUuid(BLEManager.serviceUuid)) {
            _logger.info("\nFound target service!");

            for (var char in service.characteristics) {
              String charUuid = normalizeUuid(char.uuid.toString());
              if (charUuid == normalizeUuid(BLEManager.controlCharacteristicUuid)) {
                _controlCharacteristic = char;
                _logger.info("Found control characteristic");
              } else if (charUuid == normalizeUuid(BLEManager.audioCharacteristicUuid)) {
                _audioCharacteristic = char;
                _logger.info("Found audio characteristic");
              } else if (charUuid == normalizeUuid(BLEManager.pulseOxCharacteristicUuid)) {
                _pulseOxCharacteristic = char;
                _logger.info("Found PulseOx characteristic");
                _setupPulseOxNotifications();
              } else if (charUuid == normalizeUuid(BLEManager.ecgCharacteristicUuid)) {
                _ecgCharacteristic = char;
                _logger.info("Found ECG characteristic");
                _setupECGNotifications();
              }
            }

            // Updated to ensure at least control and one other characteristic is found
            characteristicsFound = _controlCharacteristic != null &&
                (_audioCharacteristic != null || 
                 _pulseOxCharacteristic != null || 
                 _ecgCharacteristic != null);
          }
        }

        if (!characteristicsFound) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      if (!characteristicsFound) {
        throw Exception("Failed to find required characteristics");
      }
    } catch (e) {
      _logger.severe("Error in _setupServices: $e");
      rethrow;
    }
  }

  // Keep existing _processAudioData method exactly as is
  void _processAudioData(List<int> data) {
    if (data.isEmpty || !_isRecording) return;

    try {
        Duration elapsed = DateTime.now().difference(_recordingStartTime!);
        int totalExpectedSamples = (sampleRate * elapsed.inMilliseconds) ~/ 1000;
        int expectedBufferSize = totalExpectedSamples * 2;

        if (_audioBuffer.length >= expectedBufferSize) {
            _logger.info("Buffer full, skipping new data");
            return;
        }

        int remainingSpace = expectedBufferSize - _audioBuffer.length;
        int bytesToAdd = data.length;
        if (bytesToAdd > remainingSpace) {
            bytesToAdd = remainingSpace;
            _logger.info("Truncating incoming data to fit buffer");
        }

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
        
        _audioBuffer.addAll(data.sublist(0, bytesToAdd));

        if (_audioBuffer.length % (sampleRate * 2) == 0) {
            _logger.info("Buffer status: ${_audioBuffer.length} bytes / $expectedBufferSize expected");
            _logger.info("Current time: ${elapsed.inSeconds} seconds");
        }

        notifyListeners();
    } catch (e) {
        _logger.severe("Error processing audio data: $e");
    }
  }

  // Add new methods for processing ECG and PulseOx data
  void _setupPulseOxNotifications() async {
    if (_pulseOxCharacteristic == null) return;

    await _pulseOxCharacteristic!.setNotifyValue(true);
    _pulseOxSubscription = _pulseOxCharacteristic!.lastValueStream.listen(
      (data) {
        if (data.length >= 12) { // 3 float32 values
          ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
          
          _currentHeartRate = byteData.getFloat32(0, Endian.little);
          _currentSpO2 = byteData.getFloat32(4, Endian.little);
          _currentTemperature = byteData.getFloat32(8, Endian.little);

          // Only add valid readings to the session
          if (_currentHeartRate > 0 && _currentSpO2 > 50) {
            _currentSessionReadings.add({
              'heartRate': _currentHeartRate,
              'spO2': _currentSpO2,
              'temperature': _currentTemperature,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }

          notifyListeners();
        }
      },
      onError: (error) {
        _logger.severe("Error in PulseOx notifications: $error");
      },
    );
  }

  void startNewSession() {
    _currentSessionReadings.clear();
    _sessionStartTime = DateTime.now();
    notifyListeners();
  }

  void endSession() {
    _sessionStartTime = null;
    notifyListeners();
  }

  Future<void> _setupECGNotifications() async {
    if (_ecgCharacteristic == null) return;

    await _ecgCharacteristic!.setNotifyValue(true);
    _ecgSubscription = _ecgCharacteristic!.lastValueStream.listen(
      (data) {
        _logger.info("Received ECG data, length: ${data.length} bytes");
        if (data.length >= 6) { // int16 + uint32
          ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
          int ecgValue = byteData.getInt16(0, Endian.little);
          int timestamp = byteData.getUint32(2, Endian.little);
          
          _logger.info("ECG Reading:");
          _logger.info("  Value: $ecgValue");
          _logger.info("  Timestamp: $timestamp");
          
          _ecgBuffer.add(ecgValue);
          notifyListeners();
        } else {
          _logger.warning("Received incomplete ECG data packet: ${data.length} bytes");
          // Print raw data for debugging
          _logger.warning("Raw data: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
        }
      },
      onError: (error) {
        _logger.severe("Error in ECG notifications: $error");
      },
    );
    _logger.info("ECG notifications setup complete");
  }

  // Keep existing startRecording and stopRecording methods exactly as they are
  Future<void> startRecording() async {
    try {
      _logger.info("Starting recording...");
      clearAudioBuffer();
      _recordingStartTime = DateTime.now();

      if (_connectedDevice == null) {
        throw Exception("No device connected");
      }

      if (_controlCharacteristic == null || _audioCharacteristic == null) {
        throw Exception("Required characteristics not found");
      }

      await _controlCharacteristic!.write([0x01], withoutResponse: true);
      _logger.info("Sent start command to control characteristic");

      await _audioCharacteristic!.setNotifyValue(true);
      _audioSubscription = _audioCharacteristic!.lastValueStream.listen(
        (value) {
          if (_isRecording) {
            _processAudioData(value);
          }
        },
        onError: (error) {
          _logger.severe("Error in audio listener: $error");
        },
      );

      _isRecording = true;
      notifyListeners();
      _logger.info("Recording started successfully");
    } catch (e) {
      _logger.severe("Error in startRecording: $e");
      rethrow;
    }
  }
  
  Future<List<int>> stopRecording() async {
    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }

    try {
        _logger.info("Stopping recording...");
        
        Duration totalDuration = DateTime.now().difference(_recordingStartTime!);
        int durationSeconds = ((totalDuration.inMilliseconds + 500) / 1000).floor();
        int expectedSamples = sampleRate * durationSeconds;
        int expectedBytes = expectedSamples * 2;
        
        _logger.info("Recording summary:");
        _logger.info("Duration: $durationSeconds seconds");
        _logger.info("Expected samples: $expectedSamples");
        _logger.info("Expected bytes: $expectedBytes");
        _logger.info("Current buffer size: ${_audioBuffer.length}");

        await _audioSubscription?.cancel();
        _audioSubscription = null;

        if (_controlCharacteristic != null) {
            await _controlCharacteristic!.write([0x00], withoutResponse: true);
        }

        if (_audioCharacteristic != null) {
            await _audioCharacteristic!.setNotifyValue(false);
        }

        _isRecording = false;

        if (_audioBuffer.length > expectedBytes) {
            _logger.info("Trimming buffer from ${_audioBuffer.length} to $expectedBytes bytes");
            _audioBuffer = _audioBuffer.sublist(0, expectedBytes);
        }

        List<int> recordedData = List<int>.from(_audioBuffer);
        
        _logger.info("Final recording stats:");
        _logger.info("Buffer size: ${recordedData.length} bytes");
        _logger.info("Sample count: ${recordedData.length ~/ 2}");
        _logger.info("Actual duration: ${recordedData.length / (2 * sampleRate)} seconds");

        clearAudioBuffer();
        return recordedData;
    } catch (e) {
        _logger.severe("Error in stopRecording: $e");
        rethrow;
    }
  }
  
  Future<void> disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        await _audioSubscription?.cancel();
        await _pulseOxSubscription?.cancel();
        await _ecgSubscription?.cancel();
        
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _isRecording = false;
        
        _audioCharacteristic = null;
        _controlCharacteristic = null;
        _pulseOxCharacteristic = null;
        _ecgCharacteristic = null;
        
        _currentSessionReadings.clear();
        _sessionStartTime = null;
        
        clearAudioBuffer();
        notifyListeners();
      } catch (e) {
        _logger.severe("Error disconnecting: $e");
        rethrow;
      }
    }
  }

  Stream<BluetoothConnectionState> getDeviceState(BluetoothDevice device) {
    return device.connectionState;
  }
}