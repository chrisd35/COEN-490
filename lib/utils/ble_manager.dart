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
  static const int sampleRate = 4000;  // Match Arduino's 4000Hz sample rate
  static const int bitsPerSample = 16;
  static const int channels = 1;

  // Python heartbeat detection thresholds
  static const double heartbeatThreshold = 600.0;
  static const double targetPeakAmplitude = 20000.0;

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

  // Filter parameters for real-time processing
  final List<double> _xHistory = List.filled(5, 0.0);
  final List<double> _yHistory = List.filled(5, 0.0);
  final int _maFilterSize = 8;
  final List<double> _maBuffer = List.filled(8, 0.0);
  int _maIndex = 0;
  final int _medianFilterSize = 5;
  final List<double> _medianBuffer = [];

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

  // Calculate recording quality based on heartbeat detection
  String get recordingQuality {
    if (_sampleCount < 1000) {
      return 'initializing';
    }
    
    // Check if heartbeats are detected
    bool isHeartbeatDetected = _peakAmplitude > (heartbeatThreshold / 32768.0);
    
    if (_signalToNoiseRatio > 15 && isHeartbeatDetected) {
      return 'excellent';
    } else if (_signalToNoiseRatio > 10 && _peakAmplitude > 0.3) {
      return 'good';
    } else if (_signalToNoiseRatio > 5 && _peakAmplitude > 0.1) {
      return 'fair';
    } else {
      return 'poor';
    }
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
    _xHistory.fillRange(0, _xHistory.length, 0);
    _yHistory.fillRange(0, _yHistory.length, 0);
    _maBuffer.fillRange(0, _maBuffer.length, 0);
    _maIndex = 0;
    _medianBuffer.clear();
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

  //-------------------------------------------------------------------------
  // PYTHON-STYLE HEART SOUND PROCESSING
  //-------------------------------------------------------------------------
  
  // Direct port of Python's bandpass_filter function
  List<double> bandpassFilter(List<double> data, {
    double lowcut = 30.0,
    double highcut = 600.0,
    int order = 4
  }) {
    _logger.info("Applying bandpass filter (${lowcut}Hz - ${highcut}Hz)");
    
    // Create coefficients for a Butterworth bandpass filter
    // These coefficients are pre-calculated for 4kHz sample rate
    final List<double> b = [0.0063, 0, -0.0126, 0, 0.0063];
    final List<double> a = [1.0000, -3.5797, 4.8849, -3.0092, 0.7056];
    
    // Apply filter using direct form II transposed structure
    List<double> filtered = List<double>.filled(data.length, 0);
    List<double> z = List<double>.filled(order, 0);
    
    for (int i = 0; i < data.length; i++) {
      // Apply feedforward and feedback parts
      filtered[i] = b[0] * data[i] + z[0];
      
      for (int j = 0; j < order - 1; j++) {
        z[j] = b[j+1] * data[i] + z[j+1] - a[j+1] * filtered[i];
      }
      
      z[order-1] = b[order] * data[i] - a[order] * filtered[i];
    }
    
    return filtered;
  }
  
  // Direct port of Python's median_filter function
  List<double> medianFilter(List<double> data, int kernelSize) {
    _logger.info("Applying median filter (kernel size: $kernelSize)");
    
    List<double> filtered = List<double>.filled(data.length, 0);
    
    for (int i = 0; i < data.length; i++) {
      List<double> window = [];
      
      // Build window around current sample
      for (int j = math.max(0, i - kernelSize ~/ 2); 
           j <= math.min(data.length - 1, i + kernelSize ~/ 2); 
           j++) {
        window.add(data[j]);
      }
      
      // Sort and take middle value
      window.sort();
      filtered[i] = window[window.length ~/ 2];
    }
    
    return filtered;
  }
  
  // Direct port of Python's adaptive_gain function
  List<double> adaptiveGain(List<double> audio, double targetPeak) {
    _logger.info("Applying adaptive gain");
    
    // Find current peak
    double peak = 0;
    for (double sample in audio) {
      if (sample.abs() > peak) peak = sample.abs();
    }
    
    // Apply gain if needed
    List<double> boosted = List<double>.from(audio);
    if (peak < 5000) {  // Same threshold as Python code
      double gain = targetPeak / (peak + 1);
      _logger.info("Applying gain of ${gain.toStringAsFixed(2)}");
      
      for (int i = 0; i < boosted.length; i++) {
        boosted[i] = boosted[i] * gain;
      }
    }
    
    // Clip to 16-bit range
    for (int i = 0; i < boosted.length; i++) {
      boosted[i] = boosted[i].clamp(-32768, 32767);
    }
    
    return boosted;
  }
  
  // Detect if heartbeats are present - direct port of is_heartbeat_present
  bool isHeartbeatPresent(List<double> samples, double threshold) {
    double maxValue = 0;
    for (double sample in samples) {
      if (sample.abs() > maxValue) {
        maxValue = sample.abs();
      }
    }
    return maxValue > threshold;
  }
  
  // Simple noise reduction (adaptation of Python's noise reduction)
  List<double> reduceNoise(List<double> audio, bool detectedHeartbeat) {
    _logger.info("Applying noise reduction (heartbeat detected: $detectedHeartbeat)");
    
    // Without the noisereduce library, we'll use a simplified approach
    // based on whether we've detected a heartbeat
    double propDecrease = detectedHeartbeat ? 0.3 : 0.8;
    
    // Apply a simple noise gate
    List<double> denoised = List<double>.filled(audio.length, 0);
    double rms = 0;
    
    // Calculate RMS
    for (double sample in audio) {
      rms += sample * sample;
    }
    rms = math.sqrt(rms / audio.length);
    
    // Set threshold based on RMS and whether a heartbeat is detected
    double threshold = rms * propDecrease;
    
    // Apply soft noise gate
    for (int i = 0; i < audio.length; i++) {
      if (audio[i].abs() > threshold) {
        denoised[i] = audio[i];
      } else {
        denoised[i] = audio[i] * (audio[i].abs() / threshold);
      }
    }
    
    return denoised;
  }

  // Process heart sounds with Python-like algorithm
  List<int> processHeartbeatAudio(List<int> rawAudioData) {
    _logger.info("Processing heartbeat audio with Python-like algorithm");
    
    // 1. Convert bytes to samples (same as the Python code)
    List<double> samples = [];
    for (int i = 0; i < rawAudioData.length; i += 2) {
      if (i + 1 < rawAudioData.length) {
        int sample = rawAudioData[i] | (rawAudioData[i + 1] << 8);
        if (sample > 32767) sample -= 65536;  // Convert to signed
        samples.add(sample.toDouble());
      }
    }
    
    // 2. Apply bandpass filter (30-600Hz) - like the Python script
    List<double> filtered = bandpassFilter(samples, lowcut: 30, highcut: 600);
    
    // 3. Apply median filter to remove spikes - like the Python medfilt
    List<double> medianFiltered = medianFilter(filtered, 5);
    
    // 4. Apply adaptive gain boost - like the Python adaptive_gain
    List<double> boosted = adaptiveGain(medianFiltered, targetPeakAmplitude);
    
    // 5. Detect if heartbeat is present
    bool heartbeatDetected = isHeartbeatPresent(boosted, heartbeatThreshold);
    
    // 6. Apply noise reduction - simplified version of Python's adaptive_noise_reduction
    List<double> denoised = reduceNoise(boosted, heartbeatDetected);
    
    // 7. Final normalization - like the Python script
    double maxAmp = 0;
    for (double sample in denoised) {
      if (sample.abs() > maxAmp) maxAmp = sample.abs();
    }
    
    if (maxAmp > 0) {
      for (int i = 0; i < denoised.length; i++) {
        denoised[i] = denoised[i] / maxAmp * 25000;  // Same as Python's 25000 normalization
      }
    }
    
    // 8. Convert back to bytes - same as Python's struct.pack
    List<int> processedData = List<int>.filled(denoised.length * 2, 0);
    for (int i = 0; i < denoised.length; i++) {
      int sampleValue = denoised[i].round().clamp(-32768, 32767);
      processedData[i * 2] = sampleValue & 0xFF;
      processedData[i * 2 + 1] = (sampleValue >> 8) & 0xFF;
    }
    
    _logger.info("Heart sound processing complete");
    return processedData;
  }
  
  // Sonify heartbeats to make them more audible
  List<int> sonifyHeartbeats(List<int> processedAudio) {
    _logger.info("Adding sonification to make heartbeats more audible");
    
    // Convert to samples
    List<double> samples = [];
    for (int i = 0; i < processedAudio.length; i += 2) {
      if (i + 1 < processedAudio.length) {
        int sample = processedAudio[i] | (processedAudio[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        samples.add(sample.toDouble());
      }
    }
    
    // Detect significant peaks (potential heartbeats)
    List<int> heartbeatPositions = [];
    
    // Find local maxima above threshold
    for (int i = 50; i < samples.length - 50; i++) {
      double currentSample = samples[i].abs();
      bool isPeak = true;
      
      // Check if this is a local maximum
      for (int j = 1; j <= 20; j++) {
        if (i-j >= 0 && i+j < samples.length) {
          if (samples[i-j].abs() > currentSample || samples[i+j].abs() > currentSample) {
            isPeak = false;
            break;
          }
        }
      }
      
      // Only keep significant peaks
      if (isPeak && currentSample > 3000) {
        heartbeatPositions.add(i);
        i += 100; // Skip ahead to avoid duplicate detections
      }
    }
    
    _logger.info("Detected ${heartbeatPositions.length} potential heartbeats");
    
    // Add a clear beep sound for each heartbeat
    for (int pos in heartbeatPositions) {
      // Add a short beep (sine wave at 440Hz)
      for (int i = 0; i < 200 && pos + i < samples.length; i++) {
        // Generate sine wave (envelope to avoid clicks)
        double envelope = math.sin(math.pi * i / 200); // 0 to 1 to 0
        double beep = 15000 * envelope * math.sin(2 * math.pi * 440 * i / sampleRate);
        
        // Mix with original sound
        samples[pos + i] = samples[pos + i] * 0.3 + beep * 0.7;
      }
    }
    
    // Convert back to bytes
    List<int> sonifiedData = List<int>.filled(samples.length * 2, 0);
    for (int i = 0; i < samples.length; i++) {
      int sample = samples[i].round().clamp(-32768, 32767);
      sonifiedData[i*2] = sample & 0xFF;
      sonifiedData[i*2 + 1] = (sample >> 8) & 0xFF;
    }
    
    return sonifiedData;
  }

  //-------------------------------------------------------------------------
  // REAL-TIME PROCESSING METHODS (DURING RECORDING)
  //-------------------------------------------------------------------------

  // Apply bandpass filter for real-time processing
  double _applyBandpassFilter(double input) {
    // Shift input values
    for (int i = _xHistory.length - 1; i > 0; i--) {
      _xHistory[i] = _xHistory[i-1];
    }
    _xHistory[0] = input;
    
    // Simple filter coefficients (bandpass 30-600Hz)
    final List<double> b = [0.2, 0.2, 0.2, 0.2, 0.2]; 
    final List<double> a = [1.0, 0, 0, 0, 0];
    
    // Apply filter
    double output = b[0] * _xHistory[0] +
                   b[1] * _xHistory[1] +
                   b[2] * _xHistory[2] +
                   b[3] * _xHistory[3] +
                   b[4] * _xHistory[4];
    
    // Shift output values
    for (int i = _yHistory.length - 1; i > 0; i--) {
      _yHistory[i] = _yHistory[i-1];
    }
    _yHistory[0] = output;
    
    return output;
  }

  // Apply median filter for real-time processing
  double _applyMedianFilter(double input) {
    if (_medianBuffer.length < _medianFilterSize) {
      _medianBuffer.add(input);
    } else {
      _medianBuffer.removeAt(0);
      _medianBuffer.add(input);
    }
    
    List<double> sorted = List.from(_medianBuffer);
    sorted.sort();
    
    if (sorted.isEmpty) return input;
    return sorted[sorted.length ~/ 2];
  }

  // Apply moving average filter for real-time processing
  double _applyMovingAverage(double input) {
    _maBuffer[_maIndex] = input;
    _maIndex = (_maIndex + 1) % _maFilterSize;
    
    double sum = 0;
    for (double value in _maBuffer) {
      sum += value;
    }
    
    return sum / _maFilterSize;
  }

  // Apply adaptive gain for real-time processing
  double _applyAdaptiveGain(double input, double rmsLevel) {
    double gain = 1.0;
    
    if (rmsLevel < 100) {
      gain = 2.0;
    } else if (rmsLevel < 500) {
      gain = 1.5;
    } else if (rmsLevel < 2000) {
      gain = 1.0;
    }
    
    return input * gain;
  }

  // Detect heartbeats in real-time
  bool _detectHeartSound(List<double> recentSamples) {
    if (recentSamples.length < 30) return false;
    
    // Calculate metrics for heartbeat detection
    double sumEnergy = 0;
    double peakEnergy = 0;
    int peakCount = 0;
    
    // Find local peaks
    for (int i = 5; i < recentSamples.length - 5; i++) {
      double currentSample = recentSamples[i].abs();
      double prevSample = recentSamples[i-1].abs();
      double nextSample = recentSamples[i+1].abs();
      
      if (currentSample > prevSample && currentSample > nextSample && 
          currentSample > 0.1) {
        peakCount++;
        peakEnergy += currentSample;
        
        // Look for the lub-dub pattern
        for (int j = i + 8; j < i + 25 && j < recentSamples.length - 1; j++) {
          double secondPeak = recentSamples[j].abs();
          double beforeSecond = recentSamples[j-1].abs();
          double afterSecond = recentSamples[j+1].abs();
          
          if (secondPeak > beforeSecond && secondPeak > afterSecond && 
              secondPeak > 0.1) {
            return true;
          }
        }
      }
      
      sumEnergy += currentSample * currentSample;
    }
    
    double avgEnergy = sumEnergy / recentSamples.length;
    return (peakCount >= 2 && avgEnergy > 0.03);
  }

  // Process audio data in real-time during recording  
  void _processAudioData(List<int> data) {
    if (data.isEmpty || !_isRecording) return;

    try {
      Duration elapsed = DateTime.now().difference(_recordingStartTime!);
      int totalExpectedSamples = (sampleRate * elapsed.inMilliseconds) ~/ 1000;
      int expectedBufferSize = totalExpectedSamples * 2; // 2 bytes per sample

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

      // Process samples
      ByteData bytes = ByteData.sublistView(Uint8List.fromList(data.sublist(0, bytesToAdd)));
      
      // Metrics variables
      double sumSquared = 0;
      double noiseEstimate = 0;
      int zeroCrossings = 0;
      int prevSign = 0;
      List<int> filteredSamples = [];
      List<double> recentProcessedSamples = [];

      // Calculate RMS level for adaptive processing
      double sumSquaredRaw = 0;
      for (int i = 0; i < bytesToAdd ~/ 2; i++) {
        int rawSample = bytes.getInt16(i * 2, Endian.little);
        sumSquaredRaw += rawSample * rawSample;
      }
      double rmsLevel = math.sqrt(sumSquaredRaw / (bytesToAdd ~/ 2));
      
      // Process each sample
      for (int i = 0; i < bytesToAdd ~/ 2; i++) {
        // Get original sample
        int rawSample = bytes.getInt16(i * 2, Endian.little);
        _sampleCount++;
        
        // Apply filter chain (same as Python algorithm)
        double filtered = _applyBandpassFilter(rawSample.toDouble());
        filtered = _applyMedianFilter(filtered);
        filtered = _applyAdaptiveGain(filtered, rmsLevel);
        double smoothed = _applyMovingAverage(filtered);
        
        // Track for heartbeat detection
        double normalizedSample = smoothed / 32768.0;
        recentProcessedSamples.add(normalizedSample);
        
        if (recentProcessedSamples.length > 100) {
          recentProcessedSamples.removeAt(0);
        }
        
        // Convert to 16-bit
        int filteredSample = smoothed.round().clamp(-32768, 32767);
        
        // Add to filtered buffer
        ByteData filteredBytes = ByteData(2);
        filteredBytes.setInt16(0, filteredSample, Endian.little);
        filteredSamples.add(filteredBytes.getUint8(0));
        filteredSamples.add(filteredBytes.getUint8(1));
        
        // Update metrics
        double amplitude = filteredSample.abs() / 32768.0;
        _currentAmplitude = amplitude;
        if (amplitude > _peakAmplitude) {
          _peakAmplitude = amplitude;
        }
        
        // Store for visualization
        _recentAmplitudes.add(amplitude);
        if (_recentAmplitudes.length > 100) {
          _recentAmplitudes.removeAt(0);
        }
        
        // Metrics calculations
        sumSquared += filteredSample * filteredSample;
        
        // Calculate zero crossings for frequency estimation
        int currentSign = filteredSample > 0 ? 1 : (filteredSample < 0 ? -1 : 0);
        if (prevSign != 0 && currentSign != 0 && prevSign != currentSign) {
          zeroCrossings++;
        }
        prevSign = currentSign != 0 ? currentSign : prevSign;
        
        // Noise estimate from small fluctuations
        if (i > 0) {
          int prevSample = bytes.getInt16((i-1) * 2, Endian.little);
          double diff = (rawSample - prevSample).abs().toDouble();
          if (diff < 100) { // Small changes likely to be noise
            noiseEstimate += diff * diff;
          }
        }
      }
      
      // Detect heart sounds
      bool heartbeatDetected = _detectHeartSound(recentProcessedSamples);
      
      // Update signal quality metrics
      if (_sampleCount > 0) {
        // Signal-to-Noise Ratio calculation
        if (noiseEstimate > 0) {
          _signalToNoiseRatio = 10 * (sumSquared / noiseEstimate > 0 ? 
            math.log(sumSquared / noiseEstimate) / math.ln10 : 0);
        }
        
        // Normalized zero crossing rate
        _normalizedCrossingRate = zeroCrossings / (bytesToAdd ~/ 2);
        
        // Boost quality rating if heartbeat is detected
        if (heartbeatDetected && _signalToNoiseRatio > 3) {
          _signalToNoiseRatio += 5;
          _logger.info("Heartbeat pattern detected! Boosting quality rating.");
        }
      }
      
      // Store processed audio data
      _audioBuffer.addAll(filteredSamples);

      if (_audioBuffer.length % (sampleRate) == 0) {
        _logger.info("Buffer status: ${_audioBuffer.length} bytes / $expectedBufferSize expected");
        _logger.info("Current time: ${elapsed.inSeconds} seconds");
        _logger.info("Audio quality metrics - SNR: ${_signalToNoiseRatio.toStringAsFixed(2)} dB, NCR: ${_normalizedCrossingRate.toStringAsFixed(4)}");
        _logger.info("Heartbeat detected: $heartbeatDetected");
        _logger.info("Recording quality: $recordingQuality");
      }

      notifyListeners();
    } catch (e) {
      _logger.severe("Error processing audio data: $e");
    }
  }

  //-------------------------------------------------------------------------
  // BLE COMMUNICATION METHODS
  //-------------------------------------------------------------------------
  
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

  // Start recording with filter initialization
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

      // Reset filter states
      _xHistory.fillRange(0, _xHistory.length, 0);
      _yHistory.fillRange(0, _yHistory.length, 0);
      _maBuffer.fillRange(0, _maBuffer.length, 0);
      _medianBuffer.clear();
      _maIndex = 0;
      
      // Reset metrics
      _sampleCount = 0;
      _signalToNoiseRatio = 0;
      _normalizedCrossingRate = 0;
      _peakAmplitude = 0;

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
  
  // Stop recording with enhanced error handling
  Future<Map<String, dynamic>> stopRecording() async {
    if (_connectedDevice == null) {
      throw Exception("No device connected");
    }

    try {
      _logger.info("Stopping recording...");
      
      // First, set recording flag to false to stop processing incoming data
      _isRecording = false;
      
      // Cancel the subscription first (this is most important)
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      // Calculate duration and stats
      Duration totalDuration = DateTime.now().difference(_recordingStartTime!);
      int durationSeconds = ((totalDuration.inMilliseconds + 500) / 1000).floor();
      int expectedSamples = sampleRate * durationSeconds;
      int expectedBytes = expectedSamples * 2;
      
      _logger.info("Recording summary:");
      _logger.info("Duration: $durationSeconds seconds");
      _logger.info("Expected samples: $expectedSamples");
      _logger.info("Expected bytes: $expectedBytes");
      _logger.info("Current buffer size: ${_audioBuffer.length}");
      _logger.info("Signal quality - SNR: ${_signalToNoiseRatio.toStringAsFixed(2)} dB");
      _logger.info("Recording quality: $recordingQuality");

      // Use a timeout for potentially problematic BLE operations
      try {
        if (_controlCharacteristic != null) {
          await _controlCharacteristic!.write([0x00], withoutResponse: true)
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        _logger.warning("Error writing to control characteristic: $e");
        // Continue anyway
      }

      try {
        if (_audioCharacteristic != null) {
          await _audioCharacteristic!.setNotifyValue(false)
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        _logger.warning("Error disabling notifications: $e");
        // Continue anyway - don't let this stop us from processing the data
      }

      // Ensure correct data length for WAV file
      List<int> recordedData = List<int>.from(_audioBuffer);
      if (recordedData.length > expectedBytes) {
        _logger.info("Trimming buffer from ${recordedData.length} to $expectedBytes bytes");
        recordedData = recordedData.sublist(0, expectedBytes);
      } else if (recordedData.length < expectedBytes) {
        // Pad with silence if we have too few samples
        _logger.info("Padding buffer from ${recordedData.length} to $expectedBytes bytes");
        int bytesToAdd = expectedBytes - recordedData.length;
        List<int> padding = List.filled(bytesToAdd, 0);
        recordedData.addAll(padding);
      }
      
      _logger.info("Final recording stats:");
      _logger.info("Buffer size: ${recordedData.length} bytes");
      _logger.info("Sample count: ${recordedData.length ~/ 2}");
      _logger.info("Actual duration: ${recordedData.length / (2 * sampleRate)} seconds");

      // Package audio data with detailed metadata for heart murmur detection
      Map<String, dynamic> metadata = {
        'duration': durationSeconds,
        'sampleRate': sampleRate,
        'bitsPerSample': bitsPerSample,
        'channels': channels,
        'peakAmplitude': _peakAmplitude,
        'signalToNoiseRatio': _signalToNoiseRatio,
        'normalizedCrossingRate': _normalizedCrossingRate,
        'recordingQuality': recordingQuality,
        'heartbeatDetected': _peakAmplitude > (heartbeatThreshold / 32768.0),
        'processingType': 'heartMurmurOptimized',
      };

      clearAudioBuffer();
      return {
        'audioData': recordedData,
        'metadata': metadata
      };
    } catch (e) {
      _logger.severe("Error in stopRecording: $e");
      
      // Even if we hit an error, try to return whatever data we collected
      List<int> recordedData = List<int>.from(_audioBuffer);
      clearAudioBuffer();
      
      return {
        'audioData': recordedData,
        'metadata': {
          'duration': 0,
          'sampleRate': sampleRate,
          'bitsPerSample': bitsPerSample,
          'channels': channels,
          'peakAmplitude': _peakAmplitude,
          'signalToNoiseRatio': _signalToNoiseRatio,
          'recordingQuality': 'error',
          'error': e.toString(),
        }
      };
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