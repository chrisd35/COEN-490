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
  
  // Heart murmur detection metrics
  double _murmurProbability = 0.0;
  String _murmurType = 'None';
  double _dominantFrequency = 0.0;
  List<double> _frequencySpectrum = [];
  
  // Heart sound classification
  final List<String> _heartSoundEvents = [];
  int _s1Count = 0;
  int _s2Count = 0;
  double _s1s2Ratio = 0.0;
  
  // Additional murmur-related metrics
  double _diastolicRumble = 0.0;
  double _systolicIntensity = 0.0;
  bool _isSystolicMurmur = false;
  bool _isDiastolicMurmur = false;

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

  // Constants - updated to match Arduino code
  static const int sampleRate = 1000;  // Updated to match Arduino sample rate
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

  // New heart murmur detection getters
  double get murmurProbability => _murmurProbability;
  String get murmurType => _murmurType;
  double get dominantFrequency => _dominantFrequency;
  List<double> get frequencySpectrum => _frequencySpectrum;
  List<String> get heartSoundEvents => _heartSoundEvents;
  int get s1Count => _s1Count;
  int get s2Count => _s2Count;
  double get s1s2Ratio => _s1s2Ratio;
  double get diastolicRumble => _diastolicRumble;
  double get systolicIntensity => _systolicIntensity;
  bool get isSystolicMurmur => _isSystolicMurmur;
  bool get isDiastolicMurmur => _isDiastolicMurmur;

  // Audio quality getters
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
    
    // Reset heart murmur metrics
    _murmurProbability = 0.0;
    _murmurType = 'None';
    _dominantFrequency = 0.0;
    _frequencySpectrum = [];
    _heartSoundEvents.clear();
    _s1Count = 0;
    _s2Count = 0;
    _s1s2Ratio = 0.0;
    _diastolicRumble = 0.0;
    _systolicIntensity = 0.0;
    _isSystolicMurmur = false;
    _isDiastolicMurmur = false;
 
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

  // New implementation for processing heart sound data with murmur detection
 void _processAudioData(List<int> data) {
  if (data.isEmpty || !_isRecording) return;

  try {
    // For better performance, only log once in a while
    bool shouldLog = _audioBuffer.length % 5000 == 0;
    
    // Add raw data to buffer
    _audioBuffer.addAll(data);
    
    // Process visualization data in limited chunks to avoid UI freezes
    ByteData bytes = ByteData.sublistView(Uint8List.fromList(data));
    int sampleCount = data.length ~/ 2; // 16-bit samples
    
    // Process only a subset of samples for visualization to reduce CPU usage
    int visualSampleRate = 200; // Lower rate for visualization
    int skipFactor = math.max(1, sampleCount ~/ visualSampleRate);
    
    // Track zero crossings for frequency estimation
    int zeroCrossings = 0;
    double sumSquares = 0;
    double sum = 0;
    List<double> amplitudes = [];
    
    // Process samples for visualization in smaller chunks
    for (int i = 0; i < sampleCount; i += skipFactor) {
      if (i * 2 + 1 < data.length) {
        int sample = bytes.getInt16(i * 2, Endian.little);
        
        // Track zero crossings (useful for frequency estimation)
        if (i > 0) {
          int prevIndex = math.max(0, i - skipFactor);
          int prevSample = bytes.getInt16(prevIndex * 2, Endian.little);
          if ((prevSample < 0 && sample >= 0) || (prevSample >= 0 && sample < 0)) {
            zeroCrossings++;
          }
        }
        
        // Calculate amplitude and other statistics
        double amplitude = sample.abs() / 32768.0;
        amplitudes.add(amplitude);
        sum += amplitude;
        sumSquares += amplitude * amplitude;
        
        // Update current amplitude
        _currentAmplitude = amplitude;
        if (amplitude > _peakAmplitude) {
          _peakAmplitude = amplitude;
        }
        
        // Store recent amplitudes for visualization (limit to 100 points)
        _recentAmplitudes.add(amplitude);
        if (_recentAmplitudes.length > 100) {
          _recentAmplitudes.removeAt(0);
        }
      }
    }
    
    // Calculate audio statistics
    if (amplitudes.isNotEmpty) {
      // Update sample count
      _sampleCount += sampleCount;
      
      // Calculate mean amplitude
      double meanAmplitude = sum / amplitudes.length;
      
      // Calculate signal-to-noise ratio (basic estimation)
      double variance = 0;
      for (double amp in amplitudes) {
        variance += (amp - meanAmplitude) * (amp - meanAmplitude);
      }
      variance /= amplitudes.length;
      double stdDev = math.sqrt(variance);
      
      // Simple SNR calculation (ratio of mean to standard deviation)
      if (stdDev > 0) {
        _signalToNoiseRatio = meanAmplitude / stdDev;
      }
      
      // Normalized zero crossing rate (relates to dominant frequency)
      _normalizedCrossingRate = zeroCrossings / amplitudes.length;
      
      // Estimate dominant frequency from zero crossing rate
      _dominantFrequency = _normalizedCrossingRate * sampleRate / 2;
      
      // Basic heart murmur detection heuristics
      _detectHeartMurmur(amplitudes, zeroCrossings, meanAmplitude, stdDev, amplitudes.length);
    }
    
    if (shouldLog) {
      _logger.info("Heart sound data received: ${data.length} bytes, total buffer size: ${_audioBuffer.length} bytes (${_audioBuffer.length ~/ 2} samples)");
    }
    notifyListeners();
  } catch (e) {
    _logger.severe("Error processing heart sound data: $e");
  }
}

  // Heart murmur detection logic
  void _detectHeartMurmur(List<double> amplitudes, int zeroCrossings, double meanAmplitude, double stdDev, int sampleCount) {
    // Simple frequency analysis for murmur detection
    double estimatedFreq = zeroCrossings * sampleRate / (2 * sampleCount);
    
    // Heart murmurs typically have higher frequencies (100-600 Hz) than normal heart sounds (20-100 Hz)
    bool inMurmurFrequencyRange = estimatedFreq >= 100 && estimatedFreq <= 600;
    
    // Heart murmurs typically have specific amplitude and variance characteristics
    bool hasHighVariability = stdDev > 0.1 && meanAmplitude > 0.05;
    
    // Update murmur probability based on these factors
    if (inMurmurFrequencyRange && hasHighVariability) {
      // Higher probability if both frequency and amplitude characteristics match
      _murmurProbability = math.min(1.0, _murmurProbability + 0.1);
      
      // Classify murmur type based on frequency
      if (estimatedFreq >= 100 && estimatedFreq < 200) {
        _murmurType = 'Low Frequency Murmur';
        _isSystolicMurmur = true;
        _systolicIntensity = math.max(_systolicIntensity, meanAmplitude * 5);
      } else if (estimatedFreq >= 200 && estimatedFreq < 400) {
        _murmurType = 'Mid Frequency Murmur';
        _isSystolicMurmur = estimatedFreq < 300;
        _isDiastolicMurmur = estimatedFreq >= 300;
        _diastolicRumble = math.max(_diastolicRumble, meanAmplitude * 3);
      } else {
        _murmurType = 'High Frequency Murmur';
        _isDiastolicMurmur = true;
        _diastolicRumble = math.max(_diastolicRumble, meanAmplitude * 4);
      }
      
      // Heart sound event detection (S1, S2)
      if (_heartSoundEvents.isEmpty || _heartSoundEvents.last != "Murmur") {
        _heartSoundEvents.add("Murmur");
      }
    } else if (meanAmplitude > 0.2 && amplitudes.length > 10) {
      // Detect S1 (louder) and S2 (softer) heart sounds
      bool risingEdge = amplitudes[0] < amplitudes[amplitudes.length ~/ 2];
      bool isLoud = meanAmplitude > 0.3;
      
      if (isLoud && !_heartSoundEvents.contains("S1")) {
        _s1Count++;
        _heartSoundEvents.add("S1");
      } else if (!isLoud && !_heartSoundEvents.contains("S2")) {
        _s2Count++;
        _heartSoundEvents.add("S2");
      }
      
      // Calculate S1/S2 ratio
      if (_s1Count > 0 && _s2Count > 0) {
        _s1s2Ratio = _s1Count / _s2Count;
      }
      
      // Reduce murmur probability when normal heart sounds are detected
      _murmurProbability = math.max(0.0, _murmurProbability - 0.05);
    }
    
    // Limit heart sound events to most recent 10
    if (_heartSoundEvents.length > 10) {
      _heartSoundEvents.removeAt(0);
    }
  }

  Future<Map<String, dynamic>> stopRecording() async {
  if (_connectedDevice == null) {
    throw Exception("No device connected");
  }

  try {
    _logger.info("Stopping recording...");
    _isRecording = false;

    // Send stop command first - using standard write
    if (_controlCharacteristic != null) {
      await _controlCharacteristic!.write([0x00]);
      _logger.info("Sent stop command to Arduino");
    }

    // Wait for a moment to ensure remaining data is received
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Now cancel the subscription
    if (_audioSubscription != null) {
      await _audioSubscription?.cancel();
      _audioSubscription = null;
    }

    if (_audioCharacteristic != null) {
      await _audioCharacteristic!.setNotifyValue(false);
    }

    // Rest of the method for data processing...
    Duration totalDuration = DateTime.now().difference(_recordingStartTime!);
    int durationSeconds = ((totalDuration.inMilliseconds + 500) / 1000).floor();
    
    _logger.info("Recording complete. Total data received: ${_audioBuffer.length} bytes (${_audioBuffer.length ~/ 2} samples)");
    _logger.info("Expected samples for ${durationSeconds}s at $sampleRate Hz: ${durationSeconds * sampleRate}");
    double receivedPercentage = (_audioBuffer.length / 2) / (durationSeconds * sampleRate) * 100;
    _logger.info("Received approximately ${receivedPercentage.toStringAsFixed(1)}% of expected data");
    
    _finalizeMurmurAnalysis();
    
    // Make a copy of the buffer before possibly clearing it
    List<int> recordedData = List<int>.from(_audioBuffer);
    
    // Use upsample if needed
    int actualSamples = recordedData.length ~/ 2;
    int expectedSamples = durationSeconds * sampleRate;
    
    if (actualSamples < expectedSamples * 0.8) {
      recordedData = _upsampleIfNeeded(recordedData, actualSamples, expectedSamples);
    }
    
    Map<String, dynamic> metadata = {
      'duration': durationSeconds,
      'sampleRate': sampleRate,
      'bitsPerSample': bitsPerSample,
      'channels': channels,
      'peakAmplitude': _peakAmplitude,
      'murmurProbability': _murmurProbability,
      'murmurType': _murmurType,
      'dominantFrequency': _dominantFrequency,
      'isSystolicMurmur': _isSystolicMurmur,
      'isDiastolicMurmur': _isDiastolicMurmur,
      'signalToNoiseRatio': _signalToNoiseRatio,
      'originalSamples': actualSamples,
      'upsampled': actualSamples < expectedSamples * 0.8,
    };

    // Clear the buffer now that we're done with it
    clearAudioBuffer();
    
    return {
      'audioData': recordedData,
      'metadata': metadata
    };
  } catch (e) {
    _logger.severe("Error in stopRecording: $e");
    // Make sure to get the data before clearing
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

List<int> _upsampleIfNeeded(List<int> originalData, int actualSamples, int targetSamples) {
  // If we have enough data or close enough, return original
  if (actualSamples >= targetSamples * 0.8) {
    return originalData;
  }
  
  _logger.info("Upsampling audio data from $actualSamples to $targetSamples samples");
  
  // Calculate how many times each sample needs to be repeated
  double ratio = targetSamples / actualSamples;
  
  // Create upsampled buffer (with some interpolation)
  List<int> upsampled = [];
  ByteData bytes = ByteData.sublistView(Uint8List.fromList(originalData));
  
  for (int i = 0; i < actualSamples - 1; i++) {
    // Get current and next sample
    int sample1 = bytes.getInt16(i * 2, Endian.little);
    int sample2 = bytes.getInt16((i + 1) * 2, Endian.little);
    
    // Calculate number of points to insert between sample1 and sample2
    int points = (ratio * (i + 1)).floor() - (ratio * i).floor();
    
    for (int j = 0; j < points; j++) {
      // Linear interpolation
      double t = j / points;
      int interpolated = (sample1 * (1 - t) + sample2 * t).round();
      
      // Add to buffer (as bytes)
      ByteData newSample = ByteData(2);
      newSample.setInt16(0, interpolated, Endian.little);
      upsampled.addAll(newSample.buffer.asUint8List());
    }
  }
  
  // Make sure the length is even
  if (upsampled.length % 2 != 0) {
    upsampled.add(0);
  }
  
  _logger.info("Upsampled to ${upsampled.length} bytes (${upsampled.length ~/ 2} samples)");
  return upsampled;
}

  // Finalize murmur analysis at end of recording
  void _finalizeMurmurAnalysis() {
    // Calculate final S1/S2 ratio
    if (_s1Count > 0 && _s2Count > 0) {
      _s1s2Ratio = _s1Count / _s2Count;
    }
    
    // Adjust murmur probability based on overall recording
    if (_dominantFrequency > 150 && _dominantFrequency < 500) {
      _murmurProbability += 0.2;
    }
    
    // Check for systolic vs diastolic murmur patterns
    if (_systolicIntensity > _diastolicRumble * 1.5) {
      _isSystolicMurmur = true;
      _isDiastolicMurmur = false;
      _murmurType = 'Systolic Murmur';
    } else if (_diastolicRumble > _systolicIntensity * 1.2) {
      _isSystolicMurmur = false;
      _isDiastolicMurmur = true;
      _murmurType = 'Diastolic Murmur';
    } else if (_systolicIntensity > 0 && _diastolicRumble > 0) {
      _isSystolicMurmur = true;
      _isDiastolicMurmur = true;
      _murmurType = 'Continuous Murmur';
    }
    
    // Cap probability at 1.0
    _murmurProbability = math.min(1.0, _murmurProbability);
    
    // If probability is very low, reset murmur type
    if (_murmurProbability < 0.3) {
      _murmurType = 'None';
      _isSystolicMurmur = false;
      _isDiastolicMurmur = false;
    }
  }

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
    _logger.info("Starting heart sound recording...");
    
    // Make sure to fully clear buffer and reset all state
    _audioBuffer = [];
  
    _currentAmplitude = 0;
    _peakAmplitude = 0;
    _sampleCount = 0;
    _signalToNoiseRatio = 0;
    _normalizedCrossingRate = 0;
    _murmurProbability = 0.0;
    _murmurType = 'None';
    _dominantFrequency = 0.0;
  
    _s1Count = 0;
    _s2Count = 0;
    _s1s2Ratio = 0.0;
    _systolicIntensity = 0.0;
    _diastolicRumble = 0.0;
    _isSystolicMurmur = false;
    _isDiastolicMurmur = false;
    
    _recordingStartTime = DateTime.now();

    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }

    if (_controlCharacteristic == null || _audioCharacteristic == null) {
      throw Exception("Required characteristics not found");
    }

    // Request large MTU for better throughput
    try {
      await _connectedDevice!.requestMtu(512);
      _logger.info("Requested larger MTU for better audio streaming");
    } catch (e) {
      _logger.warning("Could not increase MTU: $e");
    }

    // Send control command to start recording
    await _controlCharacteristic!.write([0x01]);
    _logger.info("Sent start command to control characteristic");

    // Set up notification before setting recording=true to avoid race conditions
    await _audioCharacteristic!.setNotifyValue(true);
    _audioSubscription = _audioCharacteristic!.lastValueStream.listen(
      (value) {
        if (_isRecording && value.isNotEmpty) {
          _processAudioData(value);
        }
      },
      onError: (error) {
        _logger.severe("Error in audio listener: $error");
      },
    );

    // Now set recording state to true
    _isRecording = true;
    notifyListeners();
    _logger.info("Heart sound recording started successfully");
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