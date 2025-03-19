import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '/utils/models.dart';
import 'package:logging/logging.dart' as logging;
import 'dart:math' as math;

final _logger = logging.Logger('FirebaseService');

class FirebaseService {
  final DatabaseReference _database;
  final FirebaseStorage _storage;

  FirebaseService()
      : _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://respirhythm-default-rtdb.firebaseio.com/',
        ).ref(),
        _storage = FirebaseStorage.instanceFor(
          app: Firebase.app(),
          bucket: 'respirhythm.firebasestorage.app',
        );

  Future<void> saveUser(User user) async {
    try {
      await _database
          .child('users')
          .child(user.uid)
          .set(user.toMap());
      _logger.info('User saved successfully!');
    } catch (e) {
      _logger.severe('Error saving user: $e');
      rethrow;
    }
  }

  Future<User?> getUser(String uid, String s) async {
    try {
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .get();
      
      if (snapshot.exists && snapshot.value != null) {
        return User.fromMap(snapshot.value as Map<dynamic, dynamic>);
      } else {
        _logger.warning('User not found');
        return null;
      }
    } catch (e) {
      _logger.severe('Error fetching user: $e');
      return null;
    }
  }

  Future<void> savePatient(String uid, Patient patient) async {
    try {
      // Validate required fields
      if (patient.fullName.isEmpty) {
        throw Exception('Patient name cannot be empty');
      }
      
      if (patient.medicalCardNumber.isEmpty) {
        throw Exception('Medical card number cannot be empty');
      }
      
      if (patient.dateOfBirth.isEmpty) {
        throw Exception('Date of birth cannot be empty');
      }
      
      if (patient.gender.isEmpty) {
        throw Exception('Gender cannot be empty');
      }
      
      // Check for duplicate Medicare number
      String sanitizedMedicalCard = patient.medicalCardNumber.replaceAll('/', '_');
      
      // First, check if a patient with this Medicare number already exists
      try {
        DataSnapshot snapshot = await _database
            .child('users')
            .child(uid)
            .child('patients')
            .child(sanitizedMedicalCard)
            .get();
        
        if (snapshot.exists && snapshot.value != null) {
          throw Exception('A patient with this medical card number already exists');
        }
      } catch (e) {
        // If the error is not our custom exception for duplication, rethrow it
        if (e is! Exception || e.toString() != 'Exception: A patient with this medical card number already exists') {
          _logger.warning('Error checking for duplicate: $e');
        } else {
          rethrow; // Rethrow our duplication error
        }
      }
      
      // If we get here, we can save the patient
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .set(patient.toMap());
      
      _logger.info('Patient saved successfully!');
    } catch (e) {
      _logger.severe('Error saving patient: $e');
      rethrow;
    }
  }

  Future<Patient?> getPatient(String uid, String medicalCardNumber) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .get();
      
      if (snapshot.exists && snapshot.value != null) {
        return Patient.fromMap(snapshot.value as Map<dynamic, dynamic>);
      } else {
        _logger.warning('Patient not found');
        return null;
      }
    } catch (e) {
      _logger.severe('Error fetching patient: $e');
      return null;
    }
  }

  Future<bool> isEmailInUse(String email) async {
    try {
      // Check only with the database approach to avoid using deprecated method
      // This approach won't have the same security guarantees as Firebase Auth's checks
      // but avoids using the deprecated fetchSignInMethodsForEmail method
      
      // Additional check in your database for extra safety
      final snapshot = await _database.child('users').get();
      
      if (snapshot.exists && snapshot.value != null) {
        final users = snapshot.value as Map<dynamic, dynamic>;
        
        // Search through all users to find matching email
        for (var entry in users.entries) {
          var userData = entry.value;
          if (userData is Map && 
              userData.containsKey('email') && 
              userData['email'] == email) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      _logger.severe('Error checking if email is in use: $e');
      return false; // Return false on error to avoid blocking legitimate registrations
    }
  }

  Future<void> updatePatient(String uid, Patient patient) async {
    try {
      // Validate required fields
      if (patient.fullName.isEmpty) {
        throw Exception('Patient name cannot be empty');
      }
      
      if (patient.medicalCardNumber.isEmpty) {
        throw Exception('Medical card number cannot be empty');
      }
      
      if (patient.dateOfBirth.isEmpty) {
        throw Exception('Date of birth cannot be empty');
      }
      
      if (patient.gender.isEmpty) {
        throw Exception('Gender cannot be empty');
      }
      
      String sanitizedMedicalCard = patient.medicalCardNumber.replaceAll('/', '_');
      
      // Check if patient exists before updating
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .get();
      
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Patient record not found');
      }
      
      // Update the patient record
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .update(patient.toMap());
      
      _logger.info('Patient updated successfully!');
    } catch (e) {
      _logger.severe('Error updating patient: $e');
      rethrow;
    }
  }

  Future<List<Patient>> getPatientsForUser(String uid) async {
    try {
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> patientsMap = snapshot.value as Map<dynamic, dynamic>;
      List<Patient> patients = [];
      
      try {
        for (var entry in patientsMap.entries) {
          try {
            Patient patient = Patient.fromMap(entry.value as Map<dynamic, dynamic>);
            patients.add(patient);
          } catch (e) {
            // Log error for this entry but continue processing other entries
            _logger.warning('Error parsing patient data: $e');
          }
        }
      } catch (e) {
        _logger.severe('Error iterating through patients: $e');
      }

      // Sort by full name (case insensitive)
      patients.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return patients;
    } catch (e) {
      _logger.severe('Error fetching patients: $e');
      rethrow;
    }
  }

  Future<bool> isMedicareNumberRegistered(String uid, String medicareNumber) async {
    try {
      String sanitizedMedicalCard = medicareNumber.replaceAll('/', '_');
      
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .get();
      
      return snapshot.exists && snapshot.value != null;
    } catch (e) {
      _logger.severe('Error checking Medicare number: $e');
      return false; // Assume not registered on error
    }
  }

  Future<void> deletePatient(String uid, String medicareNumber, String confirmationText) async {
    try {
      // Require exact confirmation text for deletion
      if (confirmationText != "DELETE") {
        throw Exception('Confirmation text does not match. Patient not deleted.');
      }
      
      String sanitizedMedicalCard = medicareNumber.replaceAll('/', '_');
      
      // First check if patient exists
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .get();
      
      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Patient record not found');
      }
      
      // Delete the patient record
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .remove();
      
      _logger.info('Patient deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting patient: $e');
      rethrow;
    }
  }

  // Enhanced Audio Processing Functions

  // Audio data debugging
  void debugAudioData(List<int> audioData, int sampleRate, int duration) {
    int expectedSamples = sampleRate * duration;
    int expectedBytes = expectedSamples * 2;
    
    _logger.info("Audio Debug Info:");
    _logger.info("Sample Rate: $sampleRate Hz");
    _logger.info("Duration: $duration seconds");
    _logger.info("Expected samples: $expectedSamples");
    _logger.info("Expected bytes: $expectedBytes");
    _logger.info("Actual bytes received: ${audioData.length}");
    _logger.info("Actual samples (bytes/2): ${audioData.length ~/ 2}");
    _logger.info("Calculated duration: ${audioData.length / (2 * sampleRate)} seconds");
  }

  List<int> _applyMedianFilterToSamples(List<int> samples, int kernelSize) {
  if (samples.isEmpty) return samples;
  
  List<int> filtered = List<int>.filled(samples.length, 0);
  
  for (int i = 0; i < samples.length; i++) {
    List<int> window = [];
    
    // Build window around current sample
    for (int j = math.max(0, i - kernelSize ~/ 2); 
         j <= math.min(samples.length - 1, i + kernelSize ~/ 2); 
         j++) {
      window.add(samples[j]);
    }
    
    // Sort window and take middle value
    window.sort();
    filtered[i] = window[window.length ~/ 2];
  }
  
  return filtered;
}

  List<int> processAudioForSaving(List<int> rawAudioData, int sampleRate, int bitsPerSample, int channels) {
  try {
    if (rawAudioData.isEmpty) {
      _logger.warning("Empty audio data");
      return rawAudioData;
    }

    // Convert raw bytes to samples for processing
    List<int> samples = [];
    for (int i = 0; i < rawAudioData.length; i += 2) {
      if (i + 1 < rawAudioData.length) {
        int sample = rawAudioData[i] | (rawAudioData[i + 1] << 8);
        // Convert from unsigned to signed if needed
        if (sample > 32767) {
          sample = sample - 65536;
        }
        samples.add(sample);
      }
    }

    // Find the peak amplitude for normalization
    int maxAmp = 0;
    for (int sample in samples) {
      int absValue = sample.abs();
      if (absValue > maxAmp) {
        maxAmp = absValue;
      }
    }

    _logger.info("Original peak amplitude: $maxAmp");

    // Check for DC offset and correct if needed
    double sum = 0;
    for (int sample in samples) {
      sum += sample;
    }
    double average = sum / samples.length;
    
    _logger.info("DC offset detected: $average");
    
    // Perform median filtering to remove random spikes
    List<int> medianFiltered = _applyMedianFilterToSamples(samples, 5);
    
    // Create a new buffer for the processed audio
    List<int> processedAudio = List<int>.filled(rawAudioData.length, 0);
    
    // Apply both DC offset correction, normalization, and adaptive gain
    double normFactor = 1.0;
    if (maxAmp > 0 && maxAmp < 8192) { // Less than 25% of max amplitude
      normFactor = 16384 / maxAmp; // Target ~50% of max amplitude
      _logger.info("Normalizing audio with factor: $normFactor");
    }
    
    int dcOffset = average.round();
    
    // Apply bandpass filter coefficients (30-600Hz) for heart sounds
    // Butterworth bandpass coefficients for 4kHz sample rate
    final List<double> a = [1.0000, -3.5797, 4.8849, -3.0092, 0.7056];
    final List<double> b = [0.0063, 0, -0.0126, 0, 0.0063];
    
    // Filter state variables
    List<double> x = List.filled(5, 0.0);
    List<double> y = List.filled(5, 0.0);
    
    for (int i = 0; i < medianFiltered.length; i++) {
      // Apply DC offset correction
      double sample = (medianFiltered[i] - dcOffset).toDouble();
      
      // Apply bandpass filter
      // Shift input values
      for (int j = x.length - 1; j > 0; j--) {
        x[j] = x[j-1];
      }
      x[0] = sample;
      
      // Apply filter
      double filtered = b[0] * x[0] + b[1] * x[1] + b[2] * x[2] + b[3] * x[3] + b[4] * x[4]
                      - a[1] * y[0] - a[2] * y[1] - a[3] * y[2] - a[4] * y[3];
      
      // Shift output values
      for (int j = y.length - 1; j > 0; j--) {
        y[j] = y[j-1];
      }
      y[0] = filtered;
      
      // Apply normalization if needed
      if (normFactor != 1.0) {
        filtered = filtered * normFactor;
      }
      
      // Clamp to valid range
      int processedSample = filtered.round().clamp(-32768, 32767);
      
      // Convert back to bytes
      int bytePos = i * 2;
      processedAudio[bytePos] = processedSample & 0xFF;
      processedAudio[bytePos + 1] = (processedSample >> 8) & 0xFF;
    }

    _logger.info("Audio processing complete with heart murmur optimization");
    return processedAudio;
  } catch (e) {
    _logger.severe("Error in audio processing: $e");
    return rawAudioData; // Return original on error
  }
}

  // Improved WAV file creation - optimized for heart murmur detection
  List<int> createWavFile(
    List<int> audioData, {
    int sampleRate = 4000,
    int bitsPerSample = 16,
    int channels = 1,
  }) {
    try {
      if (audioData.isEmpty) {
        _logger.warning("Empty audio data provided for WAV creation");
        // Return a small silent WAV file to prevent errors
        return createEmptyWavFile(sampleRate, bitsPerSample, channels, 1);
      }
      
      // Process audio for better heart murmur detection
      List<int> processedAudio = processAudioForSaving(audioData, sampleRate, bitsPerSample, channels);
      
      final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
      final int blockAlign = channels * (bitsPerSample ~/ 8);
      
      ByteData header = ByteData(44);
      
      // RIFF header
      header.setUint32(0, 0x52494646, Endian.big);  // "RIFF"
      header.setUint32(4, 36 + processedAudio.length, Endian.little);  // File size
      header.setUint32(8, 0x57415645, Endian.big);  // "WAVE"
      
      // Format chunk
      header.setUint32(12, 0x666D7420, Endian.big);  // "fmt "
      header.setUint32(16, 16, Endian.little);  // Format chunk size
      header.setUint16(20, 1, Endian.little);  // PCM format
      header.setUint16(22, channels, Endian.little);  // Channels
      header.setUint32(24, sampleRate, Endian.little);  // Sample rate
      header.setUint32(28, byteRate, Endian.little);  // Byte rate
      header.setUint16(32, blockAlign, Endian.little);  // Block align
      header.setUint16(34, bitsPerSample, Endian.little);  // Bits per sample
      
      // Data chunk
      header.setUint32(36, 0x64617461, Endian.big);  // "data"
      header.setUint32(40, processedAudio.length, Endian.little);  // Data size
      
      _logger.info("WAV file created successfully: ${processedAudio.length} bytes of audio data");
      return [...header.buffer.asUint8List(), ...processedAudio];
    } catch (e) {
      _logger.severe("Error creating WAV file: $e");
      // Return a silent WAV as fallback
      return createEmptyWavFile(sampleRate, bitsPerSample, channels, 1);
    }
  }
  
  // Create an empty WAV file with silence for fallback in error cases
  List<int> createEmptyWavFile(int sampleRate, int bitsPerSample, int channels, int durationSecs) {
    int numSamples = sampleRate * durationSecs;
    int dataSize = numSamples * channels * (bitsPerSample ~/ 8);
    List<int> silenceData = List.filled(dataSize, 0);
    
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    
    ByteData header = ByteData(44);
    
    // RIFF header
    header.setUint32(0, 0x52494646, Endian.big);  // "RIFF"
    header.setUint32(4, 36 + dataSize, Endian.little);  // File size
    header.setUint32(8, 0x57415645, Endian.big);  // "WAVE"
    
    // Format chunk
    header.setUint32(12, 0x666D7420, Endian.big);  // "fmt "
    header.setUint32(16, 16, Endian.little);  // Format chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, channels, Endian.little);  // Channels
    header.setUint32(24, sampleRate, Endian.little);  // Sample rate
    header.setUint32(28, byteRate, Endian.little);  // Byte rate
    header.setUint16(32, blockAlign, Endian.little);  // Block align
    header.setUint16(34, bitsPerSample, Endian.little);  // Bits per sample
    
    // Data chunk
    header.setUint32(36, 0x64617461, Endian.big);  // "data"
    header.setUint32(40, dataSize, Endian.little);  // Data size
    
    _logger.info("Created empty WAV file of $durationSecs seconds");
    return [...header.buffer.asUint8List(), ...silenceData];
  }

  // Enhanced recording saving with improved error handling and audio processing
  Future<void> saveRecording(
    String uid,
    String medicalCardNumber,
    DateTime timestamp,
    List<int> audioData,
    Map<String, dynamic> metadata,
  ) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      // Validate and adjust audio data if necessary
      int expectedSamples = (metadata['sampleRate'] ?? 4000) * (metadata['duration'] ?? 0);
      int expectedBytes = expectedSamples * 2;  // 2 bytes per sample (16-bit)
      
      // Validate audio data
      if (audioData.isEmpty) {
        throw Exception("Empty audio data received");
      }
      
      List<int> processedAudioData = audioData;
      
      // Adjust data length if necessary
      if ((audioData.length - expectedBytes).abs() > 1000) {
        _logger.warning("Audio data length significant mismatch");
        _logger.warning("Expected: $expectedBytes bytes");
        _logger.warning("Actual: ${audioData.length} bytes");
        
        if (audioData.length > expectedBytes * 1.5) {
          // If we have way too much data, trim it
          processedAudioData = audioData.sublist(0, expectedBytes);
          _logger.info("Trimmed excessively long audio data");
        } else if (audioData.length < expectedBytes * 0.5 && expectedBytes > 0) {
          // If we have way too little data, pad it
          int bytesToAdd = expectedBytes - audioData.length;
          List<int> padding = List.filled(bytesToAdd, 0);
          processedAudioData = [...audioData, ...padding];
          _logger.info("Padded excessively short audio data");
        }
      }

      // Debug processed data
      debugAudioData(
        processedAudioData,
        metadata['sampleRate'] ?? 4000,
        metadata['duration']
      );

      // Create WAV file with enhanced processing
      final wavData = createWavFile(
        processedAudioData,
        sampleRate: metadata['sampleRate'] ?? 4000,
        bitsPerSample: metadata['bitsPerSample'] ?? 16,
        channels: metadata['channels'] ?? 1,
      );

      // Generate filename with timestamp
      String filename = 'users/$uid/patients/$sanitizedMedicalCard/recordings/${timestamp.millisecondsSinceEpoch}.wav';

      // Upload to Firebase Storage with extended metadata
      await _storage.ref(filename).putData(
        Uint8List.fromList(wavData),
        SettableMetadata(
          contentType: 'audio/wav',
          customMetadata: {
            'sampleRate': (metadata['sampleRate'] ?? 4000).toString(),
            'duration': metadata['duration'].toString(),
            'bitsPerSample': (metadata['bitsPerSample'] ?? 16).toString(),
            'channels': (metadata['channels'] ?? 1).toString(),
            'recordingQuality': metadata['recordingQuality'] ?? 'unknown',
            'signalToNoiseRatio': (metadata['signalToNoiseRatio'] ?? 0).toString(),
            'peakAmplitude': (metadata['peakAmplitude'] ?? 0).toString(),
            'timestamp': timestamp.toIso8601String(),
          },
        ),
      );

      // Save metadata to Realtime Database
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .push()
          .set({
            'timestamp': timestamp.toIso8601String(),
            'filename': filename,
            'duration': metadata['duration'],
            'sampleRate': metadata['sampleRate'] ?? 4000,
            'bitsPerSample': metadata['bitsPerSample'] ?? 16,
            'channels': metadata['channels'] ?? 1,
            'peakAmplitude': metadata['peakAmplitude'] ?? 0,
            'signalToNoiseRatio': metadata['signalToNoiseRatio'] ?? 0,
            'recordingQuality': metadata['recordingQuality'] ?? 'unknown',
          });

      _logger.info("Recording saved successfully with enhanced processing for heart murmur detection");
    } catch (e) {
      _logger.severe('Error saving recording: $e');
      rethrow;
    }
  }

  Future<List<Recording>> getRecordingsForPatient(String uid, String medicalCardNumber) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> recordingsMap = snapshot.value as Map<dynamic, dynamic>;
      List<Recording> recordings = [];

      for (var entry in recordingsMap.entries) {
        Map<dynamic, dynamic> recordingData = entry.value as Map<dynamic, dynamic>;
        Recording recording = Recording.fromMap(recordingData);
        
        try {
          String downloadUrl = await _storage.ref(recording.filename).getDownloadURL();
          recording.downloadUrl = downloadUrl;
          recordings.add(recording);
        } catch (e) {
          _logger.warning('Error getting download URL for recording ${recording.filename}: $e');
          continue;
        }
      }

      recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return recordings;
    } catch (e) {
      _logger.severe('Error fetching recordings: $e');
      rethrow;
    }
  }

  Future<void> savePulseOxSession(
    String uid,
    String medicalCardNumber,
    List<Map<String, dynamic>> sessionReadings,
    Map<String, double> averages,
  ) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      // Ensure readings are in the correct format
      List<Map<String, dynamic>> formattedReadings = sessionReadings.map((reading) {
        return {
          'heartRate': reading['heartRate'],
          'spO2': reading['spO2'],
          'temperature': reading['temperature'],
          'timestamp': reading['timestamp'],
        };
      }).toList();
      
      // Save session data
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('pulseOxSessions')
          .push()
          .set({
            'timestamp': DateTime.now().toIso8601String(),
            'averages': {
              'heartRate': averages['heartRate'] ?? 0.0,
              'spO2': averages['spO2'] ?? 0.0,
              'temperature': averages['temperature'] ?? 0.0,
            },
            'readings': formattedReadings,
            'readingCount': formattedReadings.length,
          });

      _logger.info('PulseOx session saved successfully');
    } catch (e) {
      _logger.severe('Error saving PulseOx session: $e');
      rethrow;
    }
  }

  Future<List<PulseOxSession>> getPulseOxSessions(
    String uid,
    String medicalCardNumber,
  ) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('pulseOxSessions')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> sessionsMap = snapshot.value as Map<dynamic, dynamic>;
      List<PulseOxSession> sessions = [];

      for (var entry in sessionsMap.entries) {
        final value = entry.value;
        if (value is Map) {
          // Ensure readings is treated as a List
          if (value['readings'] is Map) {
            value['readings'] = (value['readings'] as Map).values.toList();
          }
          sessions.add(PulseOxSession.fromMap(value));
        }
      }

      // Sort by timestamp, newest first
      sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return sessions;
    } catch (e) {
      _logger.severe('Error fetching PulseOx sessions: $e');
      rethrow;
    }
  }

  Future<void> saveECGReading(
    String uid,
    String medicalCardNumber,
    List<int> ecgData,
    Map<String, dynamic> metadata,
  ) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      // Ensure ECG data is in the correct range (e.g., 0–4095)
      List<int> processedECGData = ecgData.map((value) {
        return value.clamp(0, 4095);
      }).toList();

      // Convert the processed ECG data to 16-bit little-endian bytes
      ByteData byteData = ByteData(processedECGData.length * 2);
      for (int i = 0; i < processedECGData.length; i++) {
        byteData.setInt16(i * 2, processedECGData[i], Endian.little);
      }
      Uint8List ecgBytes = byteData.buffer.asUint8List();

      // Generate filename and timestamp
      DateTime timestamp = DateTime.now();
      String filename = 'users/$uid/patients/$sanitizedMedicalCard/ecg/${timestamp.millisecondsSinceEpoch}.ecg';

      // Upload to Firebase Storage
      await _storage.ref(filename).putData(
        ecgBytes,
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {
            'sampleRate': (metadata['sampleRate'] ?? 4000).toString(),
            'duration': metadata['duration'].toString(),
            'timestamp': timestamp.toIso8601String(),
          },
        ),
      );

      // Get download URL
      String downloadUrl = await _storage.ref(filename).getDownloadURL();

      // Save metadata to Realtime Database
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .push()
          .set({
            'timestamp': timestamp.toIso8601String(),
            'filename': filename,
            'downloadUrl': downloadUrl,
            'duration': metadata['duration'],
            'sampleRate': metadata['sampleRate'] ?? 4000,
          });

      _logger.info('ECG reading saved successfully');
    } catch (e) {
      _logger.severe('Error saving ECG reading: $e');
      rethrow;
    }
  }

  Future<List<int>> downloadECGData(String downloadUrl) async {
    try {
      final response = await FirebaseStorage.instance
          .refFromURL(downloadUrl)
          .getData();
      
      if (response != null) {
        // Convert bytes to ECG values
        ByteData byteData = ByteData.sublistView(Uint8List.fromList(response));
        List<int> ecgData = [];
        
        for (int i = 0; i < response.length; i += 2) {
          // Read 16-bit integer (little-endian)
          int value = byteData.getInt16(i, Endian.little);
          // Ensure value is within the expected range (e.g., 0–4095)
          ecgData.add(value.clamp(0, 4095));
        }
        
        return ecgData;
      }
      return [];
    } catch (e) {
      _logger.severe('Error downloading ECG data: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPulseOxReadings(
    String uid,
    String medicalCardNumber,
  ) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('pulseOxData')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> readingsMap = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> readings = [];

      for (var entry in readingsMap.entries) {
        readings.add(Map<String, dynamic>.from(entry.value as Map));
      }

      readings.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']))
      );

      return readings;
    } catch (e) {
      _logger.severe('Error fetching PulseOx readings: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getECGReadings(
    String uid,
    String medicalCardNumber,
  ) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> readingsMap = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> readings = [];

      for (var entry in readingsMap.entries) {
        Map<dynamic, dynamic> readingData = entry.value as Map<dynamic, dynamic>;
        Map<String, dynamic> reading = Map<String, dynamic>.from(readingData);
        
        try {
          // Ensure the download URL is still valid
          if (!reading.containsKey('downloadUrl') || reading['downloadUrl'] == null) {
            String downloadUrl = await _storage.ref(reading['filename']).getDownloadURL();
            reading['downloadUrl'] = downloadUrl;
          }
          readings.add(reading);
        } catch (e) {
          _logger.warning('Error getting download URL for ECG ${reading['filename']}: $e');
          continue;
        }
      }

      readings.sort((a, b) => 
        DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp']))
      );

      return readings;
    } catch (e) {
      _logger.severe('Error fetching ECG readings: $e');
      rethrow;
    }
  }
}