import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
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

  // Audio quality metrics
  int _sampleCount = 0;
  double _signalToNoiseRatio = 0;
  double _normalizedCrossingRate = 0;

  // Recording timing control
  DateTime? _recordingStartTime;

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

  // New getters for audio quality
  double get signalToNoiseRatio => _signalToNoiseRatio;
  double get normalizedCrossingRate => _normalizedCrossingRate;
  int get sampleCount => _sampleCount;

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



  // Get a copy of the audio buffer
  List<int> getAudioBuffer() {
    return List<int>.from(_audioBuffer);
  }

  // Reset audio data and metrics
  void clearAudioBuffer() {
    _audioBuffer.clear();
    _recentAmplitudes.clear();
    _currentAmplitude = 0;
    _peakAmplitude = 0;
    _recordingStartTime = null;
    _sampleCount = 0;
    _signalToNoiseRatio = 0;
    _normalizedCrossingRate = 0;
 
    notifyListeners();
  }

  // Reset ECG buffer
  void clearECGBuffer() {
    _ecgBuffer.clear();
    notifyListeners();
  }

  // Reset PulseOx readings
  void clearPulseOxReadings() {
    _currentSessionReadings.clear();
    _currentHeartRate = 0;
    _currentSpO2 = 0;
    _currentTemperature = 0;
    notifyListeners();
  }

  // Start BLE scanning
  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  // Connect to BLE device with retry logic
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
      await _setupServices();

      notifyListeners();
      _logger.info("Successfully connected and setup device: ${device.platformName}");
    } catch (e) {
      _logger.severe("Error connecting to device: $e");
      rethrow;
    }
  }

  // Normalize UUIDs for reliable comparison
  String normalizeUuid(String uuid) {
    return uuid.replaceAll(RegExp(r'[{}-\s]', caseSensitive: false), '').toUpperCase();
  }

  // Discover and setup BLE services
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

            // Need at least control and one other characteristic
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

 


 void _processAudioData(List<int> data) {
  if (data.isEmpty || !_isRecording) return;

  try {
    // For the new approach, we'll receive larger chunks of data at once
    // Simply add raw data to buffer
    _audioBuffer.addAll(data);
    
    // Process visualization data in chunks to avoid UI freezes
    ByteData bytes = ByteData.sublistView(Uint8List.fromList(data));
    int sampleCount = data.length ~/ 2;
    
    // Process in smaller chunks if the data is large
    int chunkSize = 50; // Process 50 samples at a time for visualization
    for (int chunk = 0; chunk < sampleCount; chunk += chunkSize) {
      int end = chunk + chunkSize;
      if (end > sampleCount) end = sampleCount;
      
      // Process this chunk
      for (int i = chunk; i < end; i++) {
        if (i * 2 + 1 < data.length) {
          int sample = bytes.getInt16(i * 2, Endian.little);
          double amplitude = sample.abs() / 32768.0;
          _currentAmplitude = amplitude;
          if (amplitude > _peakAmplitude) {
            _peakAmplitude = amplitude;
          }
          
          // Store recent amplitudes for visualization
          _recentAmplitudes.add(amplitude);
          if (_recentAmplitudes.length > 100) {
            _recentAmplitudes.removeAt(0);
          }
        }
      }
    }
    
    _logger.info("Processed audio data chunk: ${data.length} bytes, buffer size now: ${_audioBuffer.length}");
    notifyListeners();
  } catch (e) {
    _logger.severe("Error processing audio data: $e");
  }
}

Future<Map<String, dynamic>> stopRecording() async {
  if (_connectedDevice == null) {
    throw Exception("No device connected");
  }

  try {
    _logger.info("Stopping recording...");
    _isRecording = false;

    // Cancel the subscription first
    if (_audioSubscription != null) {
      _audioSubscription?.cancel();
      _audioSubscription = null;
    }

    // Send stop command
    if (_controlCharacteristic != null) {
      _controlCharacteristic!.write([0x00], withoutResponse: true);
    }

    if (_audioCharacteristic != null) {
      _audioCharacteristic!.setNotifyValue(false);
    }

    Duration totalDuration = DateTime.now().difference(_recordingStartTime!);
    int durationSeconds = ((totalDuration.inMilliseconds + 500) / 1000).floor();

    _logger.info("Waiting for complete audio buffer to be received...");
    
    // Add a delay to ensure all buffered audio is received
    // This is critical for the new approach where data is sent after recording stops
    await Future.delayed(const Duration(milliseconds: 1000));
    
    List<int> recordedData = List<int>.from(_audioBuffer);
    
    _logger.info("Recording complete. Total data received: ${recordedData.length} bytes");
    
    // Package audio data with metadata
    Map<String, dynamic> metadata = {
      'duration': durationSeconds,
      'sampleRate': sampleRate,
      'bitsPerSample': bitsPerSample,
      'channels': channels,
      'peakAmplitude': _peakAmplitude,
    };

    clearAudioBuffer();
    return {
      'audioData': recordedData,
      'metadata': metadata
    };
  } catch (e) {
    _logger.severe("Error in stopRecording: $e");
    List<int> recordedData = List<int>.from(_audioBuffer);
    clearAudioBuffer();
    return {
      'audioData': recordedData,
      'metadata': {
        'duration': 0,
        'sampleRate': sampleRate,
        'bitsPerSample': bitsPerSample,
        'channels': channels,
        'error': e.toString(),
      }
    };
  }
}




  // Continue BLEManager class

  // Setup PulseOx notifications
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

  // Start a new PulseOx session
  void startNewSession() {
    _currentSessionReadings.clear();
    _sessionStartTime = DateTime.now();
    notifyListeners();
  }

  // End a PulseOx session
  void endSession() {
    _sessionStartTime = null;
    notifyListeners();
  }

  // Setup ECG notifications
  Future<void> _setupECGNotifications() async {
    if (_ecgCharacteristic == null) return;

    await _ecgCharacteristic!.setNotifyValue(true);
    _ecgSubscription = _ecgCharacteristic!.lastValueStream.listen(
          (data) {
        if (data.length >= 6) { // int16 + uint32
          ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
          int ecgValue = byteData.getInt16(0, Endian.little);
          // timestamp available but not currently used
          // int timestamp = byteData.getUint32(2, Endian.little);

          _ecgBuffer.add(ecgValue);
          notifyListeners();
        } else {
          _logger.warning("Received incomplete ECG data packet: ${data.length} bytes");
        }
      },
      onError: (error) {
        _logger.severe("Error in ECG notifications: $error");
      },
    );
    _logger.info("ECG notifications setup complete");
  }

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

    // Reset basic metrics
    _peakAmplitude = 0;
    _currentAmplitude = 0;
    _recentAmplitudes.clear();

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


  // Disconnect from device and clean up
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

  // Get device connection state stream
  Stream<BluetoothConnectionState> getDeviceState(BluetoothDevice device) {
    return device.connectionState;
  }
}