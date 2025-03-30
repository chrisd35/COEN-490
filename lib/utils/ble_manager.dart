import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('BLEManager');

  enum AudioQuality {
    unknown,
    poor,
    fair,
    good,
    excellent,
  }

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

  // Constants for noise floor detection
  static const int _noiseFloorSampleSize = 500; // Number of samples to analyze for noise floor
  static const double _signalThresholdFactor = 2.5; // Signal must be this many times above noise floor
  static const double _minValidSignalAmplitude = 0.05; // Minimum amplitude to consider as valid signal (0-1 scale)
  static const int _minHeartbeatDuration = 50; // Minimum consecutive samples above threshold to be a heartbeat

  // Additional state variables for noise floor detection
  List<double> _noiseFloorSamples = [];
  double _noiseFloorMean = 0.0;
  double _noiseFloorStdDev = 0.0;
  bool _hasValidSignal = false;
  int _consecutiveSamplesAboveThreshold = 0;
  
  // Constants for audio quality assessment
  static const double _minAcceptableSNR = 1.5;
  static const double _goodSNR = 4.0;
  static const int _minHeartbeatCount = 4;
  static const int _reportingInterval = 1000; // ms

  // Additional state variables for audio quality
  int _heartbeatCount = 0;
  DateTime? _lastQualityReport;
  AudioQuality _audioQuality = AudioQuality.unknown;
  String _audioQualityMessage = "Analyzing audio quality...";

  // Enum for audio quality levels


  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isRecording => _isRecording;
  List<int> get audioBuffer => _audioBuffer;
  double get currentAmplitude => _currentAmplitude;
  double get peakAmplitude => _peakAmplitude;
  List<double> get recentAmplitudes => _recentAmplitudes;

  // Heart murmur detection getters
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
  bool get hasValidSignal => _hasValidSignal;
  AudioQuality get audioQuality => _audioQuality;
  String get audioQualityMessage => _audioQualityMessage;
  int get heartbeatCount => _heartbeatCount;

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
// Continue BLEManager class implementation

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
  
  // Reset noise floor detection
  _noiseFloorSamples.clear();
  _noiseFloorMean = 0.0;
  _noiseFloorStdDev = 0.0;
  _hasValidSignal = false;
  _consecutiveSamplesAboveThreshold = 0;
  
  // Reset audio quality metrics
  _heartbeatCount = 0;
  _lastQualityReport = null;
  _audioQuality = AudioQuality.unknown;
  _audioQualityMessage = "Analyzing audio quality...";
 
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
// Enhanced audio processing with noise floor detection
void _processAudioData(List<int> data) {
  if (data.isEmpty || !_isRecording) return;

  try {
    // For better performance, only log occasionally
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
    List<int> rawSamples = [];
    
    // First pass: extract raw samples and basic statistics
    for (int i = 0; i < sampleCount; i += skipFactor) {
      if (i * 2 + 1 < data.length) {
        int sample = bytes.getInt16(i * 2, Endian.little);
        rawSamples.add(sample);
        
        // Track zero crossings (useful for frequency estimation)
        if (i > 0) {
          int prevIndex = math.max(0, i - skipFactor);
          int prevSample = bytes.getInt16(prevIndex * 2, Endian.little);
          if ((prevSample < 0 && sample >= 0) || (prevSample >= 0 && sample < 0)) {
            zeroCrossings++;
          }
        }
        
        // Calculate amplitude
        double amplitude = sample.abs() / 32768.0;
        amplitudes.add(amplitude);
        sum += amplitude;
        sumSquares += amplitude * amplitude;
      }
    }
    
    // Skip further processing if we don't have enough samples
    if (amplitudes.length < 10) return;
    
    // Calculate DC offset (average value)
    double dcOffset = 0.0;
    if (rawSamples.isNotEmpty) {
      int rawSum = 0;
      for (int sample in rawSamples) {
        rawSum += sample;
      }
      dcOffset = rawSum / rawSamples.length;
    }
    
    // If we have significant DC offset, log it
    if (dcOffset.abs() > 1000 && shouldLog) {
      _logger.info("Significant DC offset detected: $dcOffset");
    }
    
    // Noise floor detection
    for (double amplitude in amplitudes) {
      // Collect noise floor samples if we don't have enough yet
      if (_noiseFloorSamples.length < _noiseFloorSampleSize) {
        _noiseFloorSamples.add(amplitude);
        
        // Once we have enough samples, calculate initial noise floor statistics
        if (_noiseFloorSamples.length == _noiseFloorSampleSize) {
          _updateNoiseFloorStatistics();
          _logger.info("Initial noise floor: mean=${_noiseFloorMean.toStringAsFixed(6)}, stdDev=${_noiseFloorStdDev.toStringAsFixed(6)}");
        }
      } else {
        // We have established a noise floor, now check if current sample is significantly above it
        double threshold = _noiseFloorMean + (_noiseFloorStdDev * _signalThresholdFactor);
        
        if (amplitude > threshold && amplitude > _minValidSignalAmplitude) {
          _consecutiveSamplesAboveThreshold++;
          
          // If we have enough consecutive samples above threshold, consider it a valid heartbeat signal
          if (_consecutiveSamplesAboveThreshold >= _minHeartbeatDuration && !_hasValidSignal) {
            _hasValidSignal = true;
            _logger.info("Valid heartbeat signal detected: amplitude=$amplitude, threshold=$threshold");
          }
        } else {
          // Reset consecutive counter if sample falls below threshold
          _consecutiveSamplesAboveThreshold = 0;
          
          // If signal is gone for a significant time, reset valid signal flag and update noise floor
          if (_hasValidSignal && amplitude < threshold * 0.8) {
            // Avoid quick toggling by requiring multiple samples below threshold
            _hasValidSignal = false;
            _logger.info("Signal lost: amplitude=$amplitude, threshold=$threshold");
            
            // Update our noise floor with this quiet period data
            if (_noiseFloorSamples.length > _noiseFloorSampleSize * 0.8) {
              // Replace 20% of noise floor samples with new ones
              _noiseFloorSamples.removeRange(0, _noiseFloorSampleSize ~/ 5);
            }
            _noiseFloorSamples.add(amplitude);
            _updateNoiseFloorStatistics();
          }
        }
      }
    }
    
    // Calculate audio statistics
    double meanAmplitude = sum / amplitudes.length;
    
    // Calculate variance and standard deviation
    double variance = 0;
    for (double amp in amplitudes) {
      variance += (amp - meanAmplitude) * (amp - meanAmplitude);
    }
    variance /= amplitudes.length;
    double stdDev = math.sqrt(variance);
    
    // Signal-to-Noise ratio calculation
    if (stdDev > 0) {
      _signalToNoiseRatio = meanAmplitude / stdDev;
    }
    
    // Normalized zero crossing rate (relates to dominant frequency)
    _normalizedCrossingRate = zeroCrossings / amplitudes.length;
    
    // Estimate dominant frequency from zero crossing rate (better for heartbeats than FFT for small samples)
    _dominantFrequency = _normalizedCrossingRate * sampleRate / 2;
    
    // Heartbeat detection - looking for typical heart sound patterns
    // Heart sounds are typically:
    // 1. Not very high frequency (below 200Hz, ideally 20-150Hz)
    // 2. Have specific amplitude patterns (distinct beats with gaps)
    // 3. S1 and S2 sounds have characteristic timing
    
    bool frequencyInHeartSoundRange = _dominantFrequency >= 20 && _dominantFrequency <= 200;
    bool amplitudeInHeartSoundRange = meanAmplitude >= 0.03 && meanAmplitude <= 0.5;
    bool variabilityInHeartSoundRange = stdDev >= 0.01 && stdDev <= 0.3;
    
    // Combined detection
    bool looksLikeHeartSound = frequencyInHeartSoundRange && 
                           amplitudeInHeartSoundRange && 
                           variabilityInHeartSoundRange &&
                           _hasValidSignal;
    
    // Update visualization for all samples
    for (double amplitude in amplitudes) {
      // Update current amplitude for visualization
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
    
    // Update murmur detection logic only when we're confident we have heart sounds
    if (looksLikeHeartSound) {
      _detectHeartMurmur(amplitudes, zeroCrossings, meanAmplitude, stdDev, amplitudes.length);
    } else {
      // If it doesn't look like a heart sound, gradually reduce murmur probability
      _murmurProbability = math.max(0.0, _murmurProbability - 0.02);
    }
    
    // Update sample count
    _sampleCount += sampleCount;
    
    // Analyze audio quality
    _analyzeAudioQuality();
    
    // Log periodically
    if (shouldLog) {
      _logger.info(
        "Audio stats: mean=${meanAmplitude.toStringAsFixed(4)}, " +
        "stdDev=${stdDev.toStringAsFixed(4)}, " +
        "freq=${_dominantFrequency.toStringAsFixed(1)}Hz, " +
        "SNR=${_signalToNoiseRatio.toStringAsFixed(2)}, " +
        "isHeartSound=$looksLikeHeartSound, " +
        "dcOffset=${dcOffset.toStringAsFixed(1)}, " +
        "validSignal=${_hasValidSignal}"
      );
    }
    
    notifyListeners();
  } catch (e) {
    _logger.severe("Error processing audio data: $e");
  }
}

// Modified heart murmur detection that better handles sensor noise
void _detectHeartMurmur(List<double> amplitudes, int zeroCrossings, double meanAmplitude, double stdDev, int sampleCount) {
  // Only proceed if we have a valid signal
  if (!_hasValidSignal) {
    _murmurProbability = 0.0;
    _murmurType = 'None';
    return;
  }

  // Simple frequency analysis for murmur detection
  double estimatedFreq = zeroCrossings * sampleRate / (2 * sampleCount);
  
  // Heart murmurs typically have higher frequencies (100-600 Hz) than normal heart sounds (20-100 Hz)
  bool inMurmurFrequencyRange = estimatedFreq >= 100 && estimatedFreq <= 500;
  
  // Heart murmurs typically have specific amplitude and variance characteristics
  bool hasHighVariability = stdDev > 0.1 * meanAmplitude;
  
  // Calculate coefficient of variation (CV = stdDev / mean) - important for distinguishing murmurs
  double coefficientOfVariation = meanAmplitude > 0 ? stdDev / meanAmplitude : 0;
  bool hasMurmurCV = coefficientOfVariation >= 0.2 && coefficientOfVariation <= 0.6;
  
  // Update murmur probability based on these factors
  if (inMurmurFrequencyRange && hasHighVariability && hasMurmurCV) {
    // Higher probability if all factors match
    _murmurProbability = math.min(1.0, _murmurProbability + 0.05);
    
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
    
    // Heart sound event detection
    if (_heartSoundEvents.isEmpty || _heartSoundEvents.last != "Murmur") {
      _heartSoundEvents.add("Murmur");
    }
  } else if (meanAmplitude > 0.1) {
    // Detect S1 (louder) and S2 (softer) heart sounds
    // Look for patterns with distinct peaks and valleys
    
    bool potentialS1orS2 = false;
    
    // Simple peak detection
    if (amplitudes.length > 10) {
      double maxAmp = 0;
      double minAmp = 1.0;
      
      for (double amp in amplitudes) {
        if (amp > maxAmp) maxAmp = amp;
        if (amp < minAmp) minAmp = amp;
      }
      
      // If there's significant difference between min and max, it could be a heart sound
      if (maxAmp > minAmp * 2) {
        potentialS1orS2 = true;
      }
    }
    
    if (potentialS1orS2) {
      bool isLoud = meanAmplitude > 0.2;
      
      if (isLoud && (_heartSoundEvents.isEmpty || _heartSoundEvents.last != "S1")) {
        _s1Count++;
        _heartbeatCount++; // Increment heartbeat count on S1 detection
        _heartSoundEvents.add("S1");
      } else if (!isLoud && (_heartSoundEvents.isEmpty || _heartSoundEvents.last != "S2")) {
        _s2Count++;
        _heartSoundEvents.add("S2");
      }
      
      // Reduce murmur probability when normal heart sounds are detected
      _murmurProbability = math.max(0.0, _murmurProbability - 0.03);
    }
    
    // Calculate S1/S2 ratio
    if (_s1Count > 0 && _s2Count > 0) {
      _s1s2Ratio = _s1Count / _s2Count;
    }
  }
  
  // Limit heart sound events to most recent 10
  if (_heartSoundEvents.length > 10) {
    _heartSoundEvents.removeAt(0);
  }
}
// Continue BLEManager class implementation - Audio Processing

void _updateNoiseFloorStatistics() {
  if (_noiseFloorSamples.isEmpty) return;
  
  // Calculate mean
  double sum = 0.0;
  for (double sample in _noiseFloorSamples) {
    sum += sample;
  }
  _noiseFloorMean = sum / _noiseFloorSamples.length;
  
  // Calculate standard deviation
  double sumSquaredDiff = 0.0;
  for (double sample in _noiseFloorSamples) {
    double diff = sample - _noiseFloorMean;
    sumSquaredDiff += diff * diff;
  }
  _noiseFloorStdDev = math.sqrt(sumSquaredDiff / _noiseFloorSamples.length);
  
  // Log the update occasionally (not every time)
  if (math.Random().nextDouble() < 0.05) {  // 5% chance to log
    _logger.info("Updated noise floor: mean=${_noiseFloorMean.toStringAsFixed(6)}, stdDev=${_noiseFloorStdDev.toStringAsFixed(6)}");
  }
}

// Audio quality analysis
void _analyzeAudioQuality() {
  // Only report periodically to avoid flooding
  final now = DateTime.now();
  if (_lastQualityReport != null && 
      now.difference(_lastQualityReport!).inMilliseconds < _reportingInterval) {
    return;
  }
  _lastQualityReport = now;
  
  // Calculate quality based on signal-to-noise ratio, heartbeat detection, and other factors
  if (!_hasValidSignal) {
    _audioQuality = AudioQuality.poor;
    _audioQualityMessage = "No heart sounds detected. Check stethoscope position.";
    return;
  }
  
  // Check if we have enough data for a good assessment
  if (_sampleCount < sampleRate * 3) {
    _audioQuality = AudioQuality.unknown;
    _audioQualityMessage = "Analyzing audio quality...";
    return;
  }
  
  // Check if we've detected heartbeats (S1 and S2 sounds)
  if (_s1Count < _minHeartbeatCount || _s2Count < _minHeartbeatCount) {
    _audioQuality = AudioQuality.fair;
    _audioQualityMessage = "Heart sounds detected but need more data.";
    return;
  }
  
  // Quality assessment based on SNR
  if (_signalToNoiseRatio < _minAcceptableSNR) {
    _audioQuality = AudioQuality.poor;
    _audioQualityMessage = "Poor signal quality. Too much background noise.";
  } else if (_signalToNoiseRatio < _goodSNR) {
    _audioQuality = AudioQuality.fair;
    _audioQualityMessage = "Fair signal quality. Try minimizing movement.";
  } else if (_signalToNoiseRatio < _goodSNR * 1.5) {
    _audioQuality = AudioQuality.good;
    _audioQualityMessage = "Good signal quality. Heart sounds are clear.";
  } else {
    _audioQuality = AudioQuality.excellent;
    _audioQualityMessage = "Excellent signal quality. Perfect position!";
  }
  
  // Log quality assessment
  _logger.info("Audio quality: $_audioQuality (SNR: ${_signalToNoiseRatio.toStringAsFixed(2)}, Heartbeats: $_s1Count)");
}

// Finalize murmur analysis at end of recording
void _finalizeMurmurAnalysis() {
  // If we never detected a valid signal, reset murmur probability
  if (!_hasValidSignal) {
    _murmurProbability = 0.0;
    _murmurType = 'None';
    _isSystolicMurmur = false;
    _isDiastolicMurmur = false;
    return;
  }

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
// Continue BLEManager class implementation - Recording and Device Control

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
    
    // Reset noise floor detection
    _noiseFloorSamples.clear();
    _noiseFloorMean = 0.0;
    _noiseFloorStdDev = 0.0;
    _hasValidSignal = false;
    _consecutiveSamplesAboveThreshold = 0;
    
    // Reset audio quality
    _heartbeatCount = 0;
    _lastQualityReport = null;
    _audioQuality = AudioQuality.unknown;
    _audioQualityMessage = "Analyzing audio quality...";
    
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

    // Process the recorded data
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
      'hasValidSignal': _hasValidSignal,
      'noiseFloorMean': _noiseFloorMean,
      'noiseFloorThreshold': _noiseFloorMean + (_noiseFloorStdDev * _signalThresholdFactor),
      'audioQuality': _audioQuality.toString().split('.').last,
      'heartbeatCount': _heartbeatCount,
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
        'hasValidSignal': false,
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




