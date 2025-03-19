import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('AudioProcessor');

class AudioProcessor {
  static const int sampleRate = 16000; // Match the Arduino's sample rate
  
  // Bandpass filter parameters - match Python script
  static const double lowCut = 30.0;
  static const double highCut = 600.0;
  static const int filterOrder = 4;
  
  // Median filter kernel size
  static const int medianKernelSize = 5;
  
  // Adaptive gain parameters
  static const double targetPeak = 20000.0;
  static const double minAmplitudeThreshold = 5000.0;
  
  // Noise reduction parameters
  static const double noiseReductionThreshold = 600.0;
  static const double normalPropDecrease = 0.8;
  static const double heartbeatPropDecrease = 0.3;
  
  // Normalization target
  static const double normalizationTarget = 25000.0;

  /// Process raw audio data with all the filters from the Python script
  static List<int> processAudioData(List<int> rawAudioData) {
    try {
      _logger.info("Starting audio processing on ${rawAudioData.length} bytes");
      
      // Convert byte array to Int16 samples
      List<double> samples = _convertBytesToSamples(rawAudioData);
      _logger.info("Converted ${samples.length} samples from raw data");
      
      // Step 1: Apply bandpass filter (30Hz-600Hz) - Keeps heartbeat sounds
      List<double> filteredSamples = _applyBandpassFilter(samples);
      _logger.info("Applied bandpass filter");
      
      // Step 2: Apply median filter to remove random spikes
      List<double> medianFiltered = _applyMedianFilter(filteredSamples, medianKernelSize);
      _logger.info("Applied median filter");
      
      // Step 3: Apply adaptive gain boost for weak heartbeats
      List<double> gainBoosted = _applyAdaptiveGain(medianFiltered);
      _logger.info("Applied adaptive gain");
      
      // Step 4: Detect heartbeat presence for adaptive noise reduction
      bool heartbeatPresent = _isHeartbeatPresent(gainBoosted);
      _logger.info("Heartbeat detection: ${heartbeatPresent ? 'Present' : 'Not detected'}");
      
      // Step 5: Apply adaptive noise reduction
      List<double> denoised = _applyAdaptiveNoiseReduction(gainBoosted, heartbeatPresent);
      _logger.info("Applied adaptive noise reduction");
      
      // Step 6: Apply smooth normalization
      List<double> normalized = _applyNormalization(denoised);
      _logger.info("Applied normalization");
      
      // Convert back to Int16 bytes
      List<int> processedAudio = _convertSamplesToBytes(normalized);
      _logger.info("Converted processed samples back to ${processedAudio.length} bytes");
      
      return processedAudio;
    } catch (e) {
      _logger.severe("Error processing audio: $e");
      // Return original audio on error
      return rawAudioData;
    }
  }

  /// Convert raw audio bytes to samples (doubles)
  static List<double> _convertBytesToSamples(List<int> audioBytes) {
    List<double> samples = [];
    
    for (int i = 0; i < audioBytes.length; i += 2) {
      if (i + 1 < audioBytes.length) {
        // Convert 2 bytes to a 16-bit sample (little-endian)
        int sample = (audioBytes[i] & 0xFF) | ((audioBytes[i + 1] & 0xFF) << 8);
        
        // Convert to signed value (-32768 to 32767)
        if (sample > 32767) {
          sample -= 65536;
        }
        
        samples.add(sample.toDouble());
      }
    }
    
    return samples;
  }

  /// Convert processed samples back to bytes (Int16 format)
  static List<int> _convertSamplesToBytes(List<double> samples) {
    List<int> bytes = [];
    
    for (double sample in samples) {
      // Clip to Int16 range
      int intSample = sample.round().clamp(-32768, 32767);
      
      // Convert to bytes (little-endian)
      bytes.add(intSample & 0xFF);
      bytes.add((intSample >> 8) & 0xFF);
    }
    
    return bytes;
  }

  /// Butterworth bandpass filter implementation
  /// This is a simplified version of the Python butterworth filter
  static List<double> _applyBandpassFilter(List<double> samples) {
    if (samples.isEmpty) return [];
    
    // Simplified butterworth coefficients for 30Hz-600Hz at 16kHz
    // These are pre-calculated based on the Python butter() function
    final List<double> b = [0.0316, 0, -0.0632, 0, 0.0316];
    final List<double> a = [1.0, -3.5797, 4.8967, -3.0165, 0.7082];
    
    // Apply the filter using direct form II transposed structure
    List<double> filtered = List<double>.filled(samples.length, 0);
    List<double> z = List<double>.filled(4, 0); // Filter state
    
    for (int i = 0; i < samples.length; i++) {
      // Calculate output sample
      filtered[i] = b[0] * samples[i] + z[0];
      
      // Update filter state
      for (int j = 0; j < 3; j++) {
        z[j] = b[j+1] * samples[i] - a[j+1] * filtered[i] + z[j+1];
      }
      z[3] = b[4] * samples[i] - a[4] * filtered[i];
    }
    
    return filtered;
  }

  /// Apply median filter to remove spikes
  static List<double> _applyMedianFilter(List<double> samples, int kernelSize) {
    if (samples.length < kernelSize) return samples;
    
    List<double> filtered = List<double>.filled(samples.length, 0);
    int halfKernel = kernelSize ~/ 2;
    
    for (int i = 0; i < samples.length; i++) {
      List<double> window = [];
      
      // Fill window around current sample
      for (int j = i - halfKernel; j <= i + halfKernel; j++) {
        if (j >= 0 && j < samples.length) {
          window.add(samples[j]);
        }
      }
      
      // Sort window and get median
      window.sort();
      filtered[i] = window[window.length ~/ 2];
    }
    
    return filtered;
  }

  /// Apply adaptive gain to boost weak heartbeat signals
  static List<double> _applyAdaptiveGain(List<double> samples) {
    if (samples.isEmpty) return [];
    
    // Find peak amplitude
    double peak = 0;
    for (double sample in samples) {
      double abs = sample.abs();
      if (abs > peak) peak = abs;
    }
    
    // Calculate gain factor (similar to Python implementation)
    double gain = 1.0;
    if (peak < minAmplitudeThreshold) {
      gain = targetPeak / (peak + 1);
      _logger.info("Applied gain factor of $gain to weak signal");
    }
    
    // Apply gain and clip
    return samples.map((sample) => 
      (sample * gain).clamp(-32768.0, 32767.0)
    ).toList();
  }

  /// Check if heartbeat is present based on signal intensity
  static bool _isHeartbeatPresent(List<double> samples) {
    if (samples.isEmpty) return false;
    
    // Find maximum amplitude
    double maxAmplitude = 0;
    for (double sample in samples) {
      double abs = sample.abs();
      if (abs > maxAmplitude) maxAmplitude = abs;
    }
    
    return maxAmplitude > noiseReductionThreshold;
  }

  /// Apply adaptive noise reduction
  /// This is a simplified version of the Python noisereduce library
  static List<double> _applyAdaptiveNoiseReduction(List<double> samples, bool heartbeatDetected) {
    if (samples.isEmpty) return [];
    
    // Determine reduction strength based on heartbeat presence
    double propDecrease = heartbeatDetected ? heartbeatPropDecrease : normalPropDecrease;
    
    // Simple noise gate approach (simplification of noisereduce)
    double noiseFloor = _estimateNoiseFloor(samples);
    List<double> denoised = List<double>.from(samples);
    
    for (int i = 0; i < denoised.length; i++) {
      if (denoised[i].abs() < noiseFloor) {
        denoised[i] *= (1.0 - propDecrease);
      }
    }
    
    return denoised;
  }

  /// Estimate noise floor for noise reduction
  static double _estimateNoiseFloor(List<double> samples) {
    if (samples.isEmpty) return 0;
    
    // Sort samples by absolute magnitude
    List<double> sortedMagnitudes = samples.map((s) => s.abs()).toList()
      ..sort();
    
    // Use the bottom 10% as an estimate of the noise floor
    int noiseIdx = sortedMagnitudes.length ~/ 10;
    return sortedMagnitudes[noiseIdx];
  }

  /// Apply smooth normalization to the processed audio
  static List<double> _applyNormalization(List<double> samples) {
    if (samples.isEmpty) return [];
    
    // Find maximum amplitude
    double maxAmp = 0;
    for (double sample in samples) {
      double abs = sample.abs();
      if (abs > maxAmp) maxAmp = abs;
    }
    
    // Avoid division by zero
    if (maxAmp == 0) return samples;
    
    // Normalize to target amplitude
    double normFactor = normalizationTarget / maxAmp;
    return samples.map((sample) => sample * normFactor).toList();
  }
}