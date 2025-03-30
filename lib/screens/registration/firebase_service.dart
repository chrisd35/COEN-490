import 'dart:math';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '/utils/models.dart';
import 'package:logging/logging.dart' as logging;
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON handling

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
      await _database.child('users').child(user.uid).set(user.toMap());
      _logger.info('User saved successfully!');
    } catch (e) {
      _logger.severe('Error saving user: $e');
      rethrow;
    }
  }

  Future<User?> getUser(String uid, String s) async {
    try {
      DataSnapshot snapshot = await _database.child('users').child(uid).get();

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
      String sanitizedMedicalCard =
          patient.medicalCardNumber.replaceAll('/', '_');

      // First, check if a patient with this Medicare number already exists
      try {
        DataSnapshot snapshot = await _database
            .child('users')
            .child(uid)
            .child('patients')
            .child(sanitizedMedicalCard)
            .get();

        if (snapshot.exists && snapshot.value != null) {
          throw Exception(
              'A patient with this medical card number already exists');
        }
      } catch (e) {
        // If the error is not our custom exception for duplication, rethrow it
        if (e is! Exception ||
            e.toString() !=
                'Exception: A patient with this medical card number already exists') {
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

      String sanitizedMedicalCard =
          patient.medicalCardNumber.replaceAll('/', '_');

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
      DataSnapshot snapshot =
          await _database.child('users').child(uid).child('patients').get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      Map<dynamic, dynamic> patientsMap =
          snapshot.value as Map<dynamic, dynamic>;
      List<Patient> patients = [];

      try {
        for (var entry in patientsMap.entries) {
          try {
            Patient patient =
                Patient.fromMap(entry.value as Map<dynamic, dynamic>);
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
      patients.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return patients;
    } catch (e) {
      _logger.severe('Error fetching patients: $e');
      rethrow;
    }
  }

  Future<bool> isMedicareNumberRegistered(
      String uid, String medicareNumber) async {
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

  Future<void> deletePatient(
      String uid, String medicareNumber, String confirmationText) async {
    try {
      // Require exact confirmation text for deletion
      if (confirmationText != "DELETE") {
        throw Exception(
            'Confirmation text does not match. Patient not deleted.');
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

 List<int> enhanceHeartbeatWithAmplification(List<int> audioData, {
  int sampleRate = 1000,
  double threshold = 0.03,           // Lower to detect more potential heartbeats
  double beatGain = 3000.0,          // Much higher to amplify detected heartbeats
  double overallGain = 5.0,          // Lower to reduce overall volume (white noise)
  double noiseSuppression = 0.001,   // More aggressive noise suppression
  bool shiftFrequencies = false,     
  double frequencyShift = 1.5       
}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  // Convert bytes to samples
  List<double> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sampleInt = byteData.getInt16(i, Endian.little);
      double sample = sampleInt / 32768.0;
      samples.add(sample);
    }
  }
  
  // Apply frequency shifting if enabled
  List<double> processedSamples = List.from(samples);
  if (shiftFrequencies) {
    processedSamples = _shiftFrequencies(samples, frequencyShift, sampleRate);
  }
  
  // Calculate envelope to detect beats
  List<double> envelope = _calculateEnvelope(processedSamples, sampleRate);
  
  // Find the average and peak envelope
  double avgEnvelope = 0.0;
  double peakEnvelope = 0.0;
  for (double value in envelope) {
    avgEnvelope += value;
    if (value > peakEnvelope) peakEnvelope = value;
  }
  avgEnvelope /= envelope.length;
  
  // Set dynamic threshold
  double dynamicThreshold = math.max(avgEnvelope * threshold, 0.003); // Lower floor
  
  // First apply overall gain - REDUCED to lower white noise
  List<double> amplifiedSamples = [];
  for (double sample in processedSamples) {
    amplifiedSamples.add(sample * overallGain);
  }
  
  // Then apply beat-specific gain on top - INCREASED for heartbeats
  List<double> enhancedSamples = List.filled(amplifiedSamples.length, 0.0);
  for (int i = 0; i < amplifiedSamples.length; i++) {
    double beatFactor = 1.0;
    
    if (envelope[i] > dynamicThreshold) {
      // Calculate how much this exceeds the threshold
      double beatStrength = (envelope[i] - dynamicThreshold) / dynamicThreshold;
      beatStrength = math.min(beatStrength, 8.0); // Higher cap to allow stronger emphasis
      
      // Apply much stronger beat emphasis
      beatFactor = 1.0 + (beatStrength * beatGain);
    } else {
      // Apply even more aggressive noise suppression
      beatFactor = noiseSuppression;
    }
    
    enhancedSamples[i] = amplifiedSamples[i] * beatFactor;
  }
  
  // Add hard limiting to prevent digital clipping
  enhancedSamples = _applyHardLimiting(enhancedSamples);
  
  // Convert back to 16-bit PCM with maximum volume
  List<int> enhancedData = [];
  for (double sample in enhancedSamples) {
    // Clamp to -1.0 to 1.0
    sample = sample.clamp(-1.0, 1.0);
    
    // Convert to 16-bit PCM at maximum volume
    int sampleInt = (sample * 32767).round().clamp(-32768, 32767);
    
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    enhancedData.add(newSample.getUint8(0));
    enhancedData.add(newSample.getUint8(1));
  }
  
  return enhancedData;
}

// Helper method to shift frequencies higher
List<double> _shiftFrequencies(List<double> samples, double shiftFactor, int sampleRate) {
  // Simple implementation using linear interpolation
  List<double> shiftedSamples = List.filled(samples.length, 0.0);
  
  for (int i = 0; i < samples.length; i++) {
    double origPos = i / shiftFactor;
    int lowIndex = origPos.floor();
    int highIndex = origPos.ceil();
    
    if (lowIndex >= 0 && highIndex < samples.length) {
      double fraction = origPos - lowIndex;
      shiftedSamples[i] = samples[lowIndex] * (1-fraction) + samples[highIndex] * fraction;
    } else if (lowIndex >= 0 && lowIndex < samples.length) {
      shiftedSamples[i] = samples[lowIndex];
    }
  }
  
  return shiftedSamples;
}

// Helper method to calculate envelope
List<double> _calculateEnvelope(List<double> samples, int sampleRate) {
  double attackTime = 0.01; // Fast attack
  double releaseTime = 0.3; // Slower release
  
  List<double> envelope = List.filled(samples.length, 0.0);
  double attackCoef = math.exp(-1.0 / (sampleRate * attackTime));
  double releaseCoef = math.exp(-1.0 / (sampleRate * releaseTime));
  
  for (int i = 0; i < samples.length; i++) {
    double absValue = samples[i].abs();
    
    if (i > 0) {
      if (absValue > envelope[i-1]) {
        envelope[i] = attackCoef * envelope[i-1] + (1 - attackCoef) * absValue;
      } else {
        envelope[i] = releaseCoef * envelope[i-1] + (1 - releaseCoef) * absValue;
      }
    } else {
      envelope[i] = absValue;
    }
  }
  
  return envelope;
}

// Apply hard limiting to prevent digital clipping
List<double> _applyHardLimiting(List<double> samples) {
  List<double> limited = List.filled(samples.length, 0.0);
  
  // First find the maximum absolute value
  double maxAbs = 0.0;
  for (double sample in samples) {
    double absValue = sample.abs();
    if (absValue > maxAbs) maxAbs = absValue;
  }
  
  // Calculate a normalization factor that brings the peak to just below clipping
  double normalizationFactor = 1.0;
  if (maxAbs > 0.95) {
    normalizationFactor = 0.95 / maxAbs;
  }
  
  // Apply the normalization and soft clipping
  for (int i = 0; i < samples.length; i++) {
    double normalized = samples[i] * normalizationFactor;
    
    // Apply soft clipping for more natural sound
    if (normalized > 0.7) {
      // Gradually compress the upper range
      double excess = normalized - 0.7;
      normalized = 0.7 + (excess * 0.5);
    } else if (normalized < -0.7) {
      // Gradually compress the lower range
      double excess = -normalized - 0.7;
      normalized = -0.7 - (excess * 0.5);
    }
    
    limited[i] = normalized;
  }
  
  return limited;
}

  List<int> enhanceHeartbeatWithEnvelope(List<int> audioData, {
  int sampleRate = 1000,
  double attackTime = 0.01,  // 10ms attack
  double releaseTime = 0.2,  // 200ms release
  double threshold = 0.2,    // Relative threshold
  double noiseFloor = 0.05,  // Minimum level to consider
  double gain = 3.0          // Output gain for beats
}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  _logger.info("Enhancing heartbeat with envelope detection");
  
  // Convert bytes to samples
  List<double> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sampleInt = byteData.getInt16(i, Endian.little);
      // Normalize to -1.0 to 1.0
      double sample = sampleInt / 32768.0;
      samples.add(sample);
    }
  }
  
  // Calculate DC offset
  double sum = 0;
  for (double sample in samples) {
    sum += sample;
  }
  double dcOffset = sum / samples.length;
  
  // Remove DC offset
  List<double> centeredSamples = [];
  for (double sample in samples) {
    centeredSamples.add(sample - dcOffset);
  }
  
  // Calculate envelope with different attack/release times
  List<double> envelope = List.filled(centeredSamples.length, 0.0);
  double attackCoef = math.exp(-1.0 / (sampleRate * attackTime));
  double releaseCoef = math.exp(-1.0 / (sampleRate * releaseTime));
  
  for (int i = 0; i < centeredSamples.length; i++) {
    double absValue = centeredSamples[i].abs();
    
    if (i > 0) {
      if (absValue > envelope[i-1]) {
        // Attack phase - quick rise
        envelope[i] = attackCoef * envelope[i-1] + (1 - attackCoef) * absValue;
      } else {
        // Release phase - slow fall
        envelope[i] = releaseCoef * envelope[i-1] + (1 - releaseCoef) * absValue;
      }
    } else {
      envelope[i] = absValue;
    }
  }
  
  // Find the average envelope level
  double envelopeSum = 0;
  for (double value in envelope) {
    envelopeSum += value;
  }
  double avgEnvelope = envelopeSum / envelope.length;
  
  // Set dynamic threshold based on average level
  double dynamicThreshold = avgEnvelope * threshold;
  if (dynamicThreshold < noiseFloor) {
    dynamicThreshold = noiseFloor;
  }
  
  _logger.info("Average envelope: $avgEnvelope, Threshold: $dynamicThreshold");
  
  // Apply dynamic gain based on envelope
  List<double> enhancedSamples = List.filled(centeredSamples.length, 0.0);
  for (int i = 0; i < centeredSamples.length; i++) {
    // Calculate gain factor - higher when envelope exceeds threshold
    double gainFactor = 1.0;
    if (envelope[i] > dynamicThreshold) {
      // Progressive gain - more gain for stronger signals
      gainFactor = 1.0 + (envelope[i] - dynamicThreshold) / dynamicThreshold * gain;
    } else {
      // Attenuate below threshold
      gainFactor = envelope[i] / dynamicThreshold;
    }
    
    // Apply the gain
    enhancedSamples[i] = centeredSamples[i] * gainFactor;
  }
  
  // Convert back to 16-bit PCM
  List<int> enhancedData = [];
  for (double sample in enhancedSamples) {
    // Add back DC offset (optional, depends on your preference)
    // sample += dcOffset;
    
    // Clamp to -1.0 to 1.0 range
    sample = sample.clamp(-1.0, 1.0);
    
    // Convert to 16-bit PCM
    int sampleInt = (sample * 32767).round().clamp(-32768, 32767);
    
    // Convert to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    enhancedData.add(newSample.getUint8(0));
    enhancedData.add(newSample.getUint8(1));
  }
  
  _logger.info("Envelope-based enhancement complete: ${samples.length} samples processed");
  
  return enhancedData;
}

 List<int> createRawWavFile(
  List<int> audioData, {
  int sampleRate = 1000,
  int bitsPerSample = 16,
  int channels = 1,
}) {
  final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final int blockAlign = channels * (bitsPerSample ~/ 8);

  _logger.info("Creating RAW WAV with: Sample rate: $sampleRate Hz, Bits: $bitsPerSample, Channels: $channels");
  _logger.info("No processing applied - this is raw data for diagnostic purposes");

  // Create WAV header
  ByteData header = ByteData(44);

  // RIFF header
  header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
  header.setUint32(4, 36 + audioData.length, Endian.little); // File size
  header.setUint32(8, 0x57415645, Endian.big); // "WAVE"

  // Format chunk
  header.setUint32(12, 0x666D7420, Endian.big); // "fmt "
  header.setUint32(16, 16, Endian.little); // Format chunk size
  header.setUint16(20, 1, Endian.little); // PCM format
  header.setUint16(22, channels, Endian.little); // Channels
  header.setUint32(24, sampleRate, Endian.little); // Sample rate
  header.setUint32(28, byteRate, Endian.little); // Byte rate
  header.setUint16(32, blockAlign, Endian.little); // Block align
  header.setUint16(34, bitsPerSample, Endian.little); // Bits per sample

  // Data chunk
  header.setUint32(36, 0x64617461, Endian.big); // "data"
  header.setUint32(40, audioData.length, Endian.little); // Data size

  _logger.info("RAW WAV header created for ${audioData.length} bytes of audio data");

  return [...header.buffer.asUint8List(), ...audioData];
}

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
    _logger.info(
        "Calculated duration: ${audioData.length / (2 * sampleRate)} seconds");
  }

  Future<void> saveRecording(
  String uid,
  String medicalCardNumber,
  DateTime timestamp,
  List<int> audioData,
  Map<String, dynamic> metadata,
) async {
  try {
    String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

    _logger.info(
        "Starting saveRecording with ${audioData.length} bytes of audio");
    _logger.info("Metadata: $metadata");

    // Add debug point 1
    _logger.info("DEBUG 1: Preparing to create WAV file");

    // Create WAV file with proper header
    final wavData = createWavFile(
      audioData,
      sampleRate: metadata['sampleRate'] ?? 2000, // Default to 2kHz for heart sounds
      bitsPerSample: metadata['bitsPerSample'] ?? 16,
      channels: metadata['channels'] ?? 1,
    );

    // Add debug point 2
    _logger.info("DEBUG 2: WAV file created with ${wavData.length} bytes");

    // Generate filename
    String filename =
        'users/$uid/patients/$sanitizedMedicalCard/recordings/${timestamp.millisecondsSinceEpoch}.wav';
    _logger.info("DEBUG 3: Saving to path: $filename");

    // Add debug point 3
    try {
      // Extract murmur-related metadata
      Map<String, String> customMetadata = {
        'sampleRate': (metadata['sampleRate'] ?? 2000).toString(),
        'duration': metadata['duration'].toString(),
        'bitsPerSample': (metadata['bitsPerSample'] ?? 16).toString(),
        'channels': (metadata['channels'] ?? 1).toString(),
        'processingApplied': 'true',
        'processingDetails': 'bandpass,heartSoundOptimized',
      };
      
      // Add heart murmur metadata if available
      if (metadata.containsKey('murmurProbability')) {
        customMetadata['murmurProbability'] = metadata['murmurProbability'].toString();
      }
      if (metadata.containsKey('murmurType')) {
        customMetadata['murmurType'] = metadata['murmurType'];
      }
      if (metadata.containsKey('dominantFrequency')) {
        customMetadata['dominantFrequency'] = metadata['dominantFrequency'].toString();
      }
      if (metadata.containsKey('isSystolicMurmur')) {
        customMetadata['isSystolicMurmur'] = metadata['isSystolicMurmur'].toString();
      }
      if (metadata.containsKey('isDiastolicMurmur')) {
        customMetadata['isDiastolicMurmur'] = metadata['isDiastolicMurmur'].toString();
      }
      if (metadata.containsKey('murmurGrade')) {
        customMetadata['murmurGrade'] = metadata['murmurGrade'];
      }
      
      // Upload to Firebase Storage with murmur-related metadata
      await _storage.ref(filename).putData(
            Uint8List.fromList(wavData),
            SettableMetadata(
              contentType: 'audio/wav',
              customMetadata: customMetadata,
            ),
          );
      _logger.info("DEBUG 4: Successfully uploaded audio to storage");
    } catch (e) {
      _logger.severe("DEBUG ERROR STORAGE: Error in storage upload: $e");
      rethrow;
    }

    // Add debug point 4
    try {
      // Create base recording data
      Map<String, dynamic> recordingData = {
        'timestamp': timestamp.toIso8601String(),
        'filename': filename,
        'duration': metadata['duration'],
        'sampleRate': metadata['sampleRate'] ?? 2000,
        'bitsPerSample': metadata['bitsPerSample'] ?? 16,
        'channels': metadata['channels'] ?? 1,
        'peakAmplitude': metadata['peakAmplitude'],
        'processingApplied': true,
        'processingDetails': 'bandpass,heartSoundOptimized',
      };
      
      // Add heart murmur data if available
      if (metadata.containsKey('murmurProbability')) {
        recordingData['murmurProbability'] = metadata['murmurProbability'];
      }
      if (metadata.containsKey('murmurType')) {
        recordingData['murmurType'] = metadata['murmurType'];
      }
      if (metadata.containsKey('dominantFrequency')) {
        recordingData['dominantFrequency'] = metadata['dominantFrequency'];
      }
      if (metadata.containsKey('isSystolicMurmur')) {
        recordingData['isSystolicMurmur'] = metadata['isSystolicMurmur'];
      }
      if (metadata.containsKey('isDiastolicMurmur')) {
        recordingData['isDiastolicMurmur'] = metadata['isDiastolicMurmur'];
      }
      if (metadata.containsKey('murmurGrade')) {
        recordingData['murmurGrade'] = metadata['murmurGrade'];
      }
      if (metadata.containsKey('signalToNoiseRatio')) {
        recordingData['signalToNoiseRatio'] = metadata['signalToNoiseRatio'];
      }
      
      // Save metadata including murmur data to Realtime Database
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .push()
          .set(recordingData);
      _logger.info("DEBUG 5: Recording metadata saved to database");
    } catch (e) {
      _logger.severe("DEBUG ERROR DATABASE: Error in database save: $e");
      rethrow;
    }
  } catch (e) {
    _logger.severe('Error saving recording: $e');
    rethrow;
  }
}
// Add this to your FirebaseService class
List<int> shiftHeartSoundFrequencies(List<int> audioData, {
  int sampleRate = 1000,
  double frequencyMultiplier = 3.0, // Shift frequencies higher by this factor
}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  _logger.info("Shifting heart sound frequencies with multiplier: $frequencyMultiplier");
  
  // Convert bytes to samples
  List<double> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sampleInt = byteData.getInt16(i, Endian.little);
      double sample = sampleInt / 32768.0; // Normalize to -1.0 to 1.0
      samples.add(sample);
    }
  }
  
  // Frequency shifting using a simple time compression method
  // This effectively speeds up playback, shifting all frequencies higher
  int compressionFactor = frequencyMultiplier.round();
  List<double> shiftedSamples = [];
  
  for (int i = 0; i < samples.length; i += compressionFactor) {
    shiftedSamples.add(samples[i]);
  }
  
  // Interpolate to restore original sample count (for proper playback duration)
  List<double> resampledShifted = [];
  double stepSize = (shiftedSamples.length - 1) / (samples.length - 1);
  
  for (int i = 0; i < samples.length; i++) {
    double position = i * stepSize;
    int index = position.floor();
    double fraction = position - index;
    
    if (index < shiftedSamples.length - 1) {
      double sample1 = shiftedSamples[index];
      double sample2 = shiftedSamples[index + 1];
      double interpolated = sample1 + (sample2 - sample1) * fraction;
      resampledShifted.add(interpolated);
    } else if (index < shiftedSamples.length) {
      resampledShifted.add(shiftedSamples[index]);
    } else {
      // Safety for edge cases
      resampledShifted.add(0.0);
    }
  }
  
  // Convert back to 16-bit PCM
  List<int> shiftedData = [];
  for (double sample in resampledShifted) {
    // Clamp to -1.0 to 1.0 range
    sample = sample.clamp(-1.0, 1.0);
    
    // Convert to 16-bit PCM and clamp to valid range
    int sampleInt = (sample * 32767).round().clamp(-32768, 32767);
    
    // Convert to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    shiftedData.add(newSample.getUint8(0));
    shiftedData.add(newSample.getUint8(1));
  }
  
  _logger.info("Frequency shifting complete. Original samples: ${samples.length}, Shifted samples: ${resampledShifted.length}");
  
  return shiftedData;
}
// Replace your existing correctAudioWithDCOffset method with this:
List<int> correctAudioWithDCOffset(List<int> audioData, {
  double amplificationFactor = 30.0,  // Increased from 14.0 to 25.0
  bool centerSignal = true,
  double noiseGateThreshold = 200.0,  // New parameter for noise gate
}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  _logger.info("Correcting DC offset and amplifying with factor: $amplificationFactor");
  
  // Convert bytes to samples
  List<int> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sample = byteData.getInt16(i, Endian.little);
      samples.add(sample);
    }
  }
  
  // Calculate DC offset (average value)
  double sum = 0;
  for (int sample in samples) {
    sum += sample;
  }
  double dcOffset = sum / samples.length;
  
  _logger.info("Calculated DC offset: $dcOffset");
  
  // Find min and max after DC offset removal to determine appropriate amplification
  double minVal = 0;
  double maxVal = 0;
  
  for (int sample in samples) {
    double centered = sample - dcOffset;
    if (centered < minVal) minVal = centered;
    if (centered > maxVal) maxVal = centered;
  }
  
  // Use manual abs and max functions
  double absMin = minVal < 0 ? -minVal : minVal;
  double absMax = maxVal < 0 ? -maxVal : maxVal;
  double range = absMin > absMax ? absMin : absMax;
  
  if (range < 1.0) range = 1.0; // Avoid division by zero
  
  // Calculate a safe amplification factor that won't cause clipping
  double safeAmplificationFactor = 32767.0 / range;
  // Use manual min function
  double finalAmplificationFactor = amplificationFactor < (safeAmplificationFactor * 0.9) ? 
                                   amplificationFactor : (safeAmplificationFactor * 0.9);
  
  _logger.info("Signal range after DC offset removal: $minVal to $maxVal");
  _logger.info("Safe max amplification: $safeAmplificationFactor, Using: $finalAmplificationFactor");
  
  // Apply DC offset correction, noise gate, and amplification
  List<int> correctedData = [];
  
  // Create a circular buffer for temporal smoothing of the noise gate
  const int smoothingWindow = 3;
  List<double> recentValues = List.filled(smoothingWindow, 0.0);
  int bufferIndex = 0;
  
  for (int i = 0; i < samples.length; i++) {
    // Remove DC offset
    double centered = samples[i] - dcOffset;

    
    
    // Apply noise gate with hysteresis (smooth transition)
    // Store in buffer for smoothing using circular buffer pattern
    recentValues[bufferIndex] = centered.abs();
    bufferIndex = (bufferIndex + 1) % smoothingWindow;
    
    // Calculate average of recent values
    double avgEnergy = 0;
    for (double val in recentValues) {
      avgEnergy += val;
    }
    avgEnergy /= recentValues.length;
    
    // Noise gate - suppress very quiet sounds
    if (avgEnergy < noiseGateThreshold) {
      centered = 0; // Zero out low amplitude signals completely
    } else if (avgEnergy < noiseGateThreshold * 2) {
      // Gradual transition between noiseGateThreshold and 2*noiseGateThreshold
      double factor = (avgEnergy - noiseGateThreshold) / noiseGateThreshold;
      centered *= factor;
    }
    
    // Apply amplification
    double amplified = centered * finalAmplificationFactor;
    
    // Clamp to 16-bit range
    int correctedSample = amplified.round().clamp(-32768, 32767);
    
    // Convert back to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, correctedSample, Endian.little);
    correctedData.add(newSample.getUint8(0));
    correctedData.add(newSample.getUint8(1));
  }
  
  _logger.info("Audio correction complete: ${samples.length} samples processed with amplification $finalAmplificationFactor");
  
  return correctedData;
}

List<int> createWavFile(
  List<int> audioData, {
  int sampleRate = 1000,  // Make sure this matches your Arduino sample rate exactly
  int bitsPerSample = 16,
  int channels = 1,
  double amplificationFactor = 1.0,
}) {
  final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final int blockAlign = channels * (bitsPerSample ~/ 8);

  _logger.info("Creating WAV with: Sample rate: $sampleRate Hz, Bits: $bitsPerSample, Channels: $channels, Amplification: $amplificationFactor");

  // Create WAV header
  ByteData header = ByteData(44);

  // RIFF header
  header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
  header.setUint32(4, 36 + audioData.length, Endian.little); // File size
  header.setUint32(8, 0x57415645, Endian.big); // "WAVE"

  // Format chunk
  header.setUint32(12, 0x666D7420, Endian.big); // "fmt "
  header.setUint32(16, 16, Endian.little); // Format chunk size
  header.setUint16(20, 1, Endian.little); // PCM format
  header.setUint16(22, channels, Endian.little); // Channels
  header.setUint32(24, sampleRate, Endian.little); // Sample rate
  header.setUint32(28, byteRate, Endian.little); // Byte rate
  header.setUint16(32, blockAlign, Endian.little); // Block align
  header.setUint16(34, bitsPerSample, Endian.little); // Bits per sample

  // Data chunk
  header.setUint32(36, 0x64617461, Endian.big); // "data"
  header.setUint32(40, audioData.length, Endian.little); // Data size

  // Apply simple gentle amplification if needed
  List<int> processedData = audioData;
  if (amplificationFactor != 1.0) {
    ByteData byteData = ByteData(audioData.length);
    for (int i = 0; i < audioData.length; i++) {
      byteData.setUint8(i, audioData[i]);
    }
    
    List<int> amplifiedData = [];
    for (int i = 0; i < audioData.length; i += 2) {
      if (i + 1 < audioData.length) {
        int sample = byteData.getInt16(i, Endian.little);
        double amplified = sample * amplificationFactor;
        int clampedValue = amplified.round().clamp(-32768, 32767);
        
        ByteData newSample = ByteData(2);
        newSample.setInt16(0, clampedValue, Endian.little);
        amplifiedData.add(newSample.getUint8(0));
        amplifiedData.add(newSample.getUint8(1));
      } else {
        amplifiedData.add(audioData[i]);
      }
    }
    processedData = amplifiedData;
  }

  _logger.info("WAV header created for ${processedData.length} bytes of audio data");

  return [...header.buffer.asUint8List(), ...processedData];
}

// Add this to your FirebaseService class
List<int> normalizeAudio(List<int> audioData, {double targetLevel = 0.9}) {
  if (audioData.isEmpty || audioData.length < 2) {
    return audioData;
  }
  
  _logger.info("Normalizing audio data with target level: $targetLevel");
  
  // Convert bytes to samples
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  // Find the maximum amplitude
  int maxAmplitude = 0;
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      final sample = byteData.getInt16(i, Endian.little).abs();
      if (sample > maxAmplitude) {
        maxAmplitude = sample;
      }
    }
  }
  
  // Calculate the normalization factor
  double normalizationFactor = 1.0;
  if (maxAmplitude > 0) {
    // Target the desired level of 16-bit max amplitude (32767 * targetLevel)
    normalizationFactor = (32767 * targetLevel) / maxAmplitude;
  }
  
  _logger.info("Max amplitude: $maxAmplitude, Normalization factor: $normalizationFactor");
  
  // Apply normalization
  List<int> normalizedData = [];
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sample = byteData.getInt16(i, Endian.little);
      double normalized = sample * normalizationFactor;
      int normalizedSample = normalized.round().clamp(-32768, 32767);
      
      ByteData newSample = ByteData(2);
      newSample.setInt16(0, normalizedSample, Endian.little);
      normalizedData.add(newSample.getUint8(0));
      normalizedData.add(newSample.getUint8(1));
    } else {
      normalizedData.add(audioData[i]);
    }
  }
  
  return normalizedData;
}

List<int> createMobileOptimizedHeartbeatAudio(List<int> audioData, {int sampleRate = 1000}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  _logger.info("Creating mobile-optimized heartbeat audio");
  
  // Convert bytes to samples
  List<int> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sample = byteData.getInt16(i, Endian.little);
      samples.add(sample);
    }
  }
  
  // Calculate min, max, and mean
  int minSample = samples[0];
  int maxSample = samples[0];
  double sum = 0;
  
  for (int sample in samples) {
    if (sample < minSample) minSample = sample;
    if (sample > maxSample) maxSample = sample;
    sum += sample;
  }
  
  double mean = sum / samples.length;
  _logger.info("Sample statistics: min=$minSample, max=$maxSample, mean=$mean");
  
  // Analyze signal quality
  int signalRange = maxSample - minSample;
  
  // If the signal range is very small, it's likely just noise
  if (signalRange < 300) {  // Reduced threshold to allow more signals
    _logger.info("Signal range too small ($signalRange), likely just ambient noise");
    return _createDefaultHeartbeatAudio();
  }
  
  // Find the typical amplitude of variations
  double sumAbsDiff = 0;
  for (int sample in samples) {
    sumAbsDiff += (sample - mean).abs();
  }
  double avgDeviation = sumAbsDiff / samples.length;
  
  // First normalize and center the data
  List<double> normalizedSamples = [];
  for (int sample in samples) {
    // Center around zero
    double centered = sample - mean;
    // Normalize
    normalizedSamples.add(centered / avgDeviation);
  }

  // Apply a minimal bandpass filter to enhance the signal
  List<double> filteredSamples = List.from(normalizedSamples);
  for (int i = 2; i < normalizedSamples.length - 2; i++) {
    // Simple 5-point weighted average that preserves peaks
    filteredSamples[i] = normalizedSamples[i-2] * -0.05 +
                         normalizedSamples[i-1] * 0.1 +
                         normalizedSamples[i] * 0.8 +
                         normalizedSamples[i+1] * 0.1 +
                         normalizedSamples[i+2] * -0.05;
  }

  // Enhanced peak detection with balanced parameters
  List<int> allPeaks = [];
  int lastPeakIndex = -1;
  // More permissive peak threshold
  double minPeakAmplitude = 1.2;  // Made more sensitive
  // Minimum samples between peaks
  int minPeakDistance = sampleRate ~/ 5; // 200ms minimum

  for (int i = 2; i < filteredSamples.length - 2; i++) {
    // Check if this is a local maximum
    if (filteredSamples[i] > filteredSamples[i-1] && 
        filteredSamples[i] > filteredSamples[i-2] && 
        filteredSamples[i] > filteredSamples[i+1] && 
        filteredSamples[i] > filteredSamples[i+2] && 
        filteredSamples[i] > minPeakAmplitude &&
        (lastPeakIndex == -1 || i - lastPeakIndex >= minPeakDistance)) {
      
      allPeaks.add(i);
      lastPeakIndex = i;
    }
  }

  // Add detailed logging to see what's being detected
  _logger.info("Peak detection found ${allPeaks.length} potential peaks");
  if (allPeaks.isNotEmpty && allPeaks.length < 10) {
    _logger.info("Peak positions: $allPeaks");
  } else if (allPeaks.isNotEmpty) {
    _logger.info("First few peaks at positions: ${allPeaks.take(5).toList()}");
  }

  // Calculate peak intervals and check if they're consistent
  // Only require 2 peaks for rhythm analysis
  if (allPeaks.length >= 2) {
    List<int> intervals = [];
    for (int i = 1; i < allPeaks.length; i++) {
      intervals.add(allPeaks[i] - allPeaks[i-1]);
    }
    
    // Calculate interval statistics
    double intervalMean = intervals.fold(0, (a, b) => a + b) / intervals.length;
    double intervalVariance = intervals.fold(0.0, (a, b) => a + math.pow(b - intervalMean, 2)) / intervals.length;
    double intervalStdDev = math.sqrt(intervalVariance);
    double coefficientOfVariation = intervalStdDev / intervalMean;
    
    _logger.info("Peak intervals: mean=$intervalMean, stdDev=$intervalStdDev, CV=$coefficientOfVariation");
    
    // More permissive CV threshold
    if (coefficientOfVariation > 0.5) {  // Increased from 0.3 to 0.5
      _logger.info("Intervals too variable (CV=$coefficientOfVariation), not likely heartbeats");
    } else {
      _logger.info("Rhythm looks consistent, likely heartbeats");
    }
  }

  // Identify potential S1-S2 patterns (lub-dub)
  // Typical timing: S1 followed by S2 within ~100-150ms, then longer pause
  List<int> heartbeats = [];
  int minS1S2Distance = sampleRate ~/ 10; // ~100ms minimum between S1 and S2
  int maxS1S2Distance = sampleRate ~/ 4;  // ~250ms maximum between S1 and S2

  // If we have very few peaks, use them all
  if (allPeaks.length < 4) {
    heartbeats = allPeaks;
  } else {
    // Look for the S1-S2 pattern
    for (int i = 0; i < allPeaks.length - 1; i++) {
      int currentPeak = allPeaks[i];
      int nextPeak = allPeaks[i+1];
      int distance = nextPeak - currentPeak;
      
      // If there's a short distance to the next peak, it's likely an S2
      // We only count the S1 as the actual heartbeat
      if (distance >= minS1S2Distance && distance <= maxS1S2Distance) {
        heartbeats.add(currentPeak);
        // Skip the next peak (S2) by incrementing i
        i++;
      } else {
        // If timing isn't right for S1-S2, assume it's an isolated S1
        heartbeats.add(currentPeak);
      }
    }
  }

  // Calculate heart rate
  double heartRate = 70.0; // Default
  if (heartbeats.length >= 2) {
    // Calculate the average interval between heartbeats
    double totalInterval = 0;
    for (int i = 1; i < heartbeats.length; i++) {
      totalInterval += heartbeats[i] - heartbeats[i-1];
    }
    double avgInterval = totalInterval / (heartbeats.length - 1);
    
    // Convert to BPM (60 seconds * sample rate / samples per heartbeat)
    heartRate = 60.0 * sampleRate / avgInterval;
    
    // Apply sanity check - most heart rates fall between 40-200 BPM
    if (heartRate < 40) {
      _logger.warning("Heart rate calculation too low (${heartRate.toStringAsFixed(1)} BPM), defaulting to detected peaks method");
      // Fallback: simply count all peaks
      if (allPeaks.length >= 2) {
        double allPeaksInterval = (allPeaks.last - allPeaks.first) / (allPeaks.length - 1);
        heartRate = 60.0 * sampleRate / allPeaksInterval;
        // Further sanity check for half rate (might be detecting every other beat)
        if (heartRate < 40) {
          heartRate *= 2; // Double it if it's unreasonably low
        }
      }
    } else if (heartRate > 200) {
      _logger.warning("Heart rate calculation too high (${heartRate.toStringAsFixed(1)} BPM), adjusting algorithm");
      // If rate is too high, we're likely seeing both S1 and S2 as separate beats
      heartRate /= 2;
    }
    
    _logger.info("Detected heart rate: ${heartRate.toStringAsFixed(1)} BPM from ${heartbeats.length} heartbeats");
  } else {
    _logger.info("Not enough heartbeats detected (${heartbeats.length}), using default 70 BPM");
    
    // If we have some peaks but not enough for pattern analysis, try using them
    if (allPeaks.length >= 2) {
      double avgInterval = (allPeaks.last - allPeaks.first) / (allPeaks.length - 1);
      double peakHeartRate = 60.0 * sampleRate / avgInterval;
      
      // If it's a reasonable heart rate, use it
      if (peakHeartRate >= 40 && peakHeartRate <= 200) {
        heartRate = peakHeartRate;
        _logger.info("Using basic peak-based heart rate: ${heartRate.toStringAsFixed(1)} BPM");
      }
    } else {
      // Completely insufficient data, use default and return synthetic heartbeat
      return _createDefaultHeartbeatAudio();
    }
  }
  
  // Calculate samples per heartbeat
  int samplesPerBeat = (60.0 / heartRate * sampleRate).round();
  
  // Create a synthetic heartbeat cycle
  List<double> syntheticHeartbeat = [];
  for (int i = 0; i < samplesPerBeat; i++) {
    double t = i / samplesPerBeat.toDouble();
    
    // S1 (first heart sound - "lub")
    double s1 = 0;
    if (t < 0.15) {
      // Create a resonant sine burst for S1
      double envelope = math.sin(t / 0.15 * math.pi);
      s1 = envelope * math.sin(2 * math.pi * 80 * t) * 0.8; // 80 Hz frequency
    }
    
    // S2 (second heart sound - "dub")
    double s2 = 0;
    if (t > 0.3 && t < 0.45) {
      // Create a resonant sine burst for S2
      double envelope = math.sin((t - 0.3) / 0.15 * math.pi);
      s2 = envelope * math.sin(2 * math.pi * 120 * t) * 0.6; // 120 Hz frequency
    }
    
    // Combine S1 and S2
    double sample = s1 + s2;
    
    // Scale to match original signal amplitude
    sample *= avgDeviation * 2.0;
    
    syntheticHeartbeat.add(sample);
  }
  
  // Modulate the synthetic heartbeat with the original data
  List<double> modulated = [];
  for (int i = 0; i < samples.length; i++) {
    // Get the normalized variation from the mean in the original signal
    double originalVariation = (samples[i] - mean) / avgDeviation;
    
    // Limit the influence of the original signal
    double modulationFactor = originalVariation.abs().clamp(0.5, 2.0);
    if (originalVariation < 0) modulationFactor *= -1;
    
    // Add the synthetic heartbeat sound
    int beatPosition = i % syntheticHeartbeat.length;
    double synthetic = syntheticHeartbeat[beatPosition];
    
    // Combine original signal (subtly) with synthetic heartbeat
    double combined = synthetic * 0.7 + modulationFactor * 0.3 * synthetic;
    
    // Scale up significantly for mobile speakers
    combined *= 8000.0;
    
    modulated.add(combined);
  }
  
  // Convert back to 16-bit PCM
  List<int> optimizedData = [];
  for (double sample in modulated) {
    // Clamp to 16-bit range
    int sampleInt = sample.round().clamp(-32768, 32767);
    
    // Convert to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    optimizedData.add(newSample.getUint8(0));
    optimizedData.add(newSample.getUint8(1));
  }
  
  _logger.info("Mobile-optimized heartbeat audio created: ${modulated.length} samples");
  
  return optimizedData;
}
List<int> _createDefaultHeartbeatAudio() {
  _logger.info("Creating default heartbeat audio at 70 BPM");
  
  int sampleRate = 1000;
  double heartRate = 70.0; // Default 70 BPM
  int samplesPerBeat = (60.0 / heartRate * sampleRate).round();
  
  List<double> syntheticHeartbeat = [];
  for (int i = 0; i < samplesPerBeat; i++) {
    double t = i / samplesPerBeat.toDouble();
    
    // S1 (first heart sound - "lub")
    double s1 = 0;
    if (t < 0.15) {
      // Create a resonant sine burst for S1
      double envelope = math.sin(t / 0.15 * math.pi);
      s1 = envelope * math.sin(2 * math.pi * 80 * t) * 0.8; // 80 Hz frequency
    }
    
    // S2 (second heart sound - "dub")
    double s2 = 0;
    if (t > 0.3 && t < 0.45) {
      // Create a resonant sine burst for S2
      double envelope = math.sin((t - 0.3) / 0.15 * math.pi);
      s2 = envelope * math.sin(2 * math.pi * 120 * t) * 0.6; // 120 Hz frequency
    }
    
    // Combine S1 and S2
    double sample = s1 + s2;
    
    // Scale to a reasonable level
    sample *= 10000.0;
    
    syntheticHeartbeat.add(sample);
  }
  
  // Convert to 16-bit PCM
  List<int> optimizedData = [];
  for (double sample in syntheticHeartbeat) {
    // Clamp to 16-bit range
    int sampleInt = sample.round().clamp(-32768, 32767);
    
    // Convert to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    optimizedData.add(newSample.getUint8(0));
    optimizedData.add(newSample.getUint8(1));
  }
  
  // Create a one-second buffer with repeated heartbeats
  List<int> buffer = [];
  int totalSamples = sampleRate;
  
  for (int i = 0; i < totalSamples; i++) {
    buffer.add(optimizedData[i % optimizedData.length]);
  }
  
  _logger.info("Created default heartbeat audio: ${buffer.length} bytes");
  return buffer;
}

// Helper method to generate a default heartbeat


List<int> enhanceHeartbeatAudio(List<int> audioData, {
  double resonanceFrequency = 100.0, // Target frequency for heart sounds in Hz
  double resonanceQ = 5.0,          // Resonance quality factor (higher = narrower)
  double outputGain = 40.0,         // Final amplification
}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  _logger.info("Enhancing heartbeat audio with resonance at ${resonanceFrequency}Hz, Q=${resonanceQ}, gain=${outputGain}");
  
  // Convert bytes to samples
  List<double> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sample = byteData.getInt16(i, Endian.little);
      samples.add(sample.toDouble());
    }
  }
  
  // Calculate DC offset
  double sum = 0;
  for (double sample in samples) {
    sum += sample;
  }
  double dcOffset = sum / samples.length;
  
  // Remove DC offset
  for (int i = 0; i < samples.length; i++) {
    samples[i] -= dcOffset;
  }
  
  // Create specialized bandpass filter specifically for heart sounds
  // Using biquad filter coefficients for precise frequency control
  
  // Calculate filter coefficients
  double sampleRate = 1000.0; // 1kHz
  double w0 = 2.0 * 3.14159265359 * resonanceFrequency / sampleRate;
  double alpha = math.sin(w0) / (2.0 * resonanceQ);
  
  // Bandpass filter coefficients
  double b0 = alpha;
  double b1 = 0;
  double b2 = -alpha;
  double a0 = 1.0 + alpha;
  double a1 = -2.0 * math.cos(w0);
  double a2 = 1.0 - alpha;
  
  // Normalize coefficients
  b0 /= a0;
  b1 /= a0;
  b2 /= a0;
  a1 /= a0;
  a2 /= a0;
  
  // Apply the filter
  List<double> filteredSamples = List.filled(samples.length, 0.0);
  List<double> x = [0.0, 0.0, 0.0]; // Input buffer
  List<double> y = [0.0, 0.0, 0.0]; // Output buffer
  
  for (int i = 0; i < samples.length; i++) {
    // Shift input buffer
    x[2] = x[1];
    x[1] = x[0];
    x[0] = samples[i];
    
    // Shift output buffer
    y[2] = y[1];
    y[1] = y[0];
    
    // Apply filter
    y[0] = b0 * x[0] + b1 * x[1] + b2 * x[2] - a1 * y[1] - a2 * y[2];
    
    // Store filtered sample
    filteredSamples[i] = y[0];
  }
  
  // Create a peaking filter to enhance specific heart sound frequencies
  // Another biquad filter with resonance at target frequency
  double peakGain = 12.0; // dB
  double peakQ = 1.5;
  
  // Calculate peak filter coefficients
  w0 = 2.0 * 3.14159265359 * resonanceFrequency / sampleRate;
  alpha = math.sin(w0) / (2.0 * peakQ);
  num A = math.pow(10.0, peakGain / 40.0); // convert dB to linear
  
  // Peak filter coefficients
  b0 = 1.0 + alpha * A;
  b1 = -2.0 * math.cos(w0);
  b2 = 1.0 - alpha * A;
  a0 = 1.0 + alpha / A;
  a1 = -2.0 * math.cos(w0);
  a2 = 1.0 - alpha / A;
  
  // Normalize coefficients
  b0 /= a0;
  b1 /= a0;
  b2 /= a0;
  a1 /= a0;
  a2 /= a0;
  
  // Apply the peak filter
  List<double> enhancedSamples = List.filled(filteredSamples.length, 0.0);
  x = [0.0, 0.0, 0.0]; // Reset input buffer
  y = [0.0, 0.0, 0.0]; // Reset output buffer
  
  for (int i = 0; i < filteredSamples.length; i++) {
    // Shift input buffer
    x[2] = x[1];
    x[1] = x[0];
    x[0] = filteredSamples[i];
    
    // Shift output buffer
    y[2] = y[1];
    y[1] = y[0];
    
    // Apply filter
    y[0] = b0 * x[0] + b1 * x[1] + b2 * x[2] - a1 * y[1] - a2 * y[2];
    
    // Store enhanced sample
    enhancedSamples[i] = y[0];
  }
  
  // Apply noise gate
  for (int i = 0; i < enhancedSamples.length; i++) {
    double absValue = enhancedSamples[i] < 0 ? -enhancedSamples[i] : enhancedSamples[i];
    
    // Apply noise gate with soft threshold
    if (absValue < 200.0) {
      double gateRatio = absValue / 200.0;
      enhancedSamples[i] *= gateRatio * gateRatio; // Squared for smoother transition
    }
  }
  
  // Apply final output gain
  for (int i = 0; i < enhancedSamples.length; i++) {
    enhancedSamples[i] *= outputGain;
  }
  
  // Find the maximum amplitude for normalization
  double maxAmp = 0.0;
  for (double sample in enhancedSamples) {
    double absValue = sample < 0 ? -sample : sample;
    if (absValue > maxAmp) {
      maxAmp = absValue;
    }
  }
  
  // Normalize if needed to prevent clipping
  double normalizationFactor = 1.0;
  if (maxAmp > 32000.0) {
    normalizationFactor = 32000.0 / maxAmp;
    _logger.info("Normalizing output by factor ${normalizationFactor} to prevent clipping");
  }
  
  // Convert back to 16-bit PCM
  List<int> enhancedData = [];
  for (double sample in enhancedSamples) {
    // Apply normalization and clamp
    int sampleInt = (sample * normalizationFactor).round().clamp(-32768, 32767);
    
    // Convert to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    enhancedData.add(newSample.getUint8(0));
    enhancedData.add(newSample.getUint8(1));
  }
  
  _logger.info("Heartbeat audio enhancement complete: ${samples.length} samples processed");
  
  return enhancedData;
}

List<int> enhanceHeartSounds(List<int> audioData, {
  int sampleRate = 2000,
  double bassBoost = 2.5,     // Amplification for lower frequencies (S1 and S2)
  double midBoost = 3.0,      // Amplification for mid frequencies (most murmurs)
  bool applyCompression = true, // Apply dynamic range compression
}) {
  if (audioData.isEmpty || audioData.length < 4) {
    return audioData;
  }
  
  _logger.info("Enhancing heart sounds with bass boost: $bassBoost, mid boost: $midBoost");
  
  // Convert bytes to samples
  List<double> samples = [];
  ByteData byteData = ByteData(audioData.length);
  for (int i = 0; i < audioData.length; i++) {
    byteData.setUint8(i, audioData[i]);
  }
  
  for (int i = 0; i < audioData.length; i += 2) {
    if (i + 1 < audioData.length) {
      int sampleInt = byteData.getInt16(i, Endian.little);
      double sample = sampleInt / 32768.0; // Normalize to -1.0 to 1.0
      samples.add(sample);
    }
  }
  
  // Apply a simple moving average filter to reduce noise
  List<double> filteredSamples = List<double>.from(samples);
  const int smoothingWindow = 3; // Small window to preserve heart sounds
  
  for (int i = smoothingWindow; i < samples.length - smoothingWindow; i++) {
    double sum = 0;
    for (int j = i - smoothingWindow; j <= i + smoothingWindow; j++) {
      sum += samples[j];
    }
    filteredSamples[i] = sum / (smoothingWindow * 2 + 1);
  }
  
  // Apply frequency-selective amplification
  // This is a simplified approach that approximates a bandpass filter
  List<double> enhancedSamples = List<double>.from(filteredSamples);
  
  // First pass: Highlight low frequency content (S1 and S2 heart sounds)
  for (int i = 1; i < filteredSamples.length - 1; i++) {
    // Detect slow changes (low frequencies)
    double prev = filteredSamples[i-1];
    double current = filteredSamples[i];
    double next = filteredSamples[i+1];
    
    // If current sample is trending in same direction as neighbors, it's likely low frequency content
    if ((current > prev && current < next) || (current < prev && current > next)) {
      // Boost the low frequency content
      enhancedSamples[i] = current * bassBoost;
    }
  }
  
  // Second pass: Highlight mid frequency content (murmurs)
  for (int i = 2; i < enhancedSamples.length - 2; i++) {
    // Detect medium frequency oscillations
    double twoBack = filteredSamples[i-2];
    double oneBack = filteredSamples[i-1];
    double current = filteredSamples[i];
    double oneAhead = filteredSamples[i+1];
    double twoAhead = filteredSamples[i+2];
    
    // Detect sign changes which indicate zero crossings (frequency components)
    bool hasMidFrequency = false;
    if ((oneBack < 0 && current > 0) || (oneBack > 0 && current < 0)) {
      hasMidFrequency = true;
    }
    if ((current < 0 && oneAhead > 0) || (current > 0 && oneAhead < 0)) {
      hasMidFrequency = true;
    }
    
    if (hasMidFrequency) {
      // Apply mid-frequency boost
      enhancedSamples[i] = enhancedSamples[i] * midBoost;
    }
  }
  
  // Apply dynamic range compression if requested
  if (applyCompression) {
    // Find the maximum amplitude
    double maxAmp = 0;
    for (double sample in enhancedSamples) {
      double absValue = sample.abs();
      if (absValue > maxAmp) {
        maxAmp = absValue;
      }
    }
    
    // Simple compression: reduce dynamic range, then normalize
    double threshold = 0.3;
    double ratio = 0.5; // 2:1 compression ratio
    
    for (int i = 0; i < enhancedSamples.length; i++) {
      double sample = enhancedSamples[i];
      double absValue = sample.abs();
      
      // Apply compression to samples above threshold
      if (absValue > threshold) {
        double exceeded = absValue - threshold;
        double compressed = threshold + (exceeded * ratio);
        
        // Keep the original sign
        enhancedSamples[i] = compressed * (sample >= 0 ? 1 : -1);
      }
    }
    
    // Find the new maximum amplitude after compression
    double newMaxAmp = 0;
    for (double sample in enhancedSamples) {
      double absValue = sample.abs();
      if (absValue > newMaxAmp) {
        newMaxAmp = absValue;
      }
    }
    
    // Normalize to use the full dynamic range
    double normalizeGain = newMaxAmp > 0 ? 0.95 / newMaxAmp : 1.0;
    for (int i = 0; i < enhancedSamples.length; i++) {
      enhancedSamples[i] *= normalizeGain;
    }
  }
  
  // Convert back to 16-bit PCM
  List<int> enhancedData = [];
  for (double sample in enhancedSamples) {
    // Clamp to -1.0 to 1.0 range
    sample = sample.clamp(-1.0, 1.0);
    
    // Convert to 16-bit PCM and clamp to valid range
    int sampleInt = (sample * 32767).round().clamp(-32768, 32767);
    
    // Convert to bytes
    ByteData newSample = ByteData(2);
    newSample.setInt16(0, sampleInt, Endian.little);
    enhancedData.add(newSample.getUint8(0));
    enhancedData.add(newSample.getUint8(1));
  }
  
  _logger.info("Heart sound enhancement complete. Original samples: ${samples.length}, Enhanced samples: ${enhancedSamples.length}");
  
  return enhancedData;
}

  Future<List<Recording>> getRecordingsForPatient(
    String uid, String medicalCardNumber) async {
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

    Map<dynamic, dynamic> recordingsMap =
        snapshot.value as Map<dynamic, dynamic>;
    List<Recording> recordings = [];

    for (var entry in recordingsMap.entries) {
      Map<dynamic, dynamic> recordingData =
          entry.value as Map<dynamic, dynamic>;
      
      // Create recording with base data
      Recording recording = Recording.fromMap(recordingData);
      
      // Add heart murmur data if available
      if (recordingData.containsKey('murmurProbability')) {
        recording.murmurProbability = recordingData['murmurProbability'] as double;
      }
      if (recordingData.containsKey('murmurType')) {
        recording.murmurType = recordingData['murmurType'] as String;
      }
      if (recordingData.containsKey('murmurGrade')) {
        recording.murmurGrade = recordingData['murmurGrade'] as String;
      }
      if (recordingData.containsKey('isSystolicMurmur')) {
        recording.isSystolicMurmur = recordingData['isSystolicMurmur'] as bool;
      }
      if (recordingData.containsKey('isDiastolicMurmur')) {
        recording.isDiastolicMurmur = recordingData['isDiastolicMurmur'] as bool;
      }
      if (recordingData.containsKey('dominantFrequency')) {
        recording.dominantFrequency = recordingData['dominantFrequency'] as double;
      }

      try {
        String downloadUrl =
            await _storage.ref(recording.filename).getDownloadURL();
        recording.downloadUrl = downloadUrl;
        recordings.add(recording);
      } catch (e) {
        _logger.warning(
            'Error getting download URL for recording ${recording.filename}: $e');
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
      List<Map<String, dynamic>> formattedReadings =
          sessionReadings.map((reading) {
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

      Map<dynamic, dynamic> sessionsMap =
          snapshot.value as Map<dynamic, dynamic>;
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
      String filename =
          'users/$uid/patients/$sanitizedMedicalCard/ecg/${timestamp.millisecondsSinceEpoch}.ecg';

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
    _logger.info('Starting download of ECG data from URL: $downloadUrl');
    
    // Try using the stored URL first
    try {
      final response = await FirebaseStorage.instance.refFromURL(downloadUrl).getData();
      
      if (response != null && response.isNotEmpty) {
        _logger.info('Successfully downloaded ECG data with stored URL, size: ${response.length} bytes');
        return _decodeECGData(response);
      }
    } catch (e) {
      _logger.warning('Error with stored URL: $e');
      // If the stored URL fails, the URL might have expired
      // Continue to the next approach
    }
    
    // Extract the path from the URL if possible
    String? path;
    try {
      // This is a simplified approach - you might need to adjust based on your URL format
      if (downloadUrl.contains('firebasestorage.googleapis.com')) {
        // Extract path from a Firebase Storage URL
        final uri = Uri.parse(downloadUrl);
        final pathSegments = uri.pathSegments;
        
        // Find the "o" segment which is followed by the bucket name and then the object path
        int oIndex = pathSegments.indexOf('o');
        if (oIndex >= 0 && oIndex < pathSegments.length - 1) {
          path = pathSegments.sublist(oIndex + 1).join('/');
          path = Uri.decodeComponent(path); // Decode URL-encoded characters
        }
      } else if (downloadUrl.contains('/')) {
        // Might be a direct path
        path = downloadUrl;
      }
      
      _logger.info('Extracted path from URL: $path');
    } catch (e) {
      _logger.warning('Error extracting path from URL: $e');
    }
    
    // If we have a path, try to use it directly
    if (path != null && path.isNotEmpty) {
      try {
        _logger.info('Trying to download using path: $path');
        final response = await FirebaseStorage.instance.ref(path).getData();
        
        if (response != null && response.isNotEmpty) {
          _logger.info('Successfully downloaded ECG data with path, size: ${response.length} bytes');
          return _decodeECGData(response);
        }
      } catch (e) {
        _logger.warning('Error with path: $e');
      }
    }
    
    // If all else fails, throw an error
    throw Exception('Unable to download ECG data');
  } catch (e) {
    _logger.severe('Error downloading ECG data: $e');
    rethrow;
  }
}

List<int> _decodeECGData(List<int> response) {
  try {
    _logger.info('Decoding ECG data, byte length: ${response.length}');
    
    // Check if we have enough bytes
    if (response.length < 2) {
      _logger.warning('ECG data too short, returning empty list');
      return [];
    }

    // First, let's check if this is already raw ECG data (not encoded as 16-bit values)
    // If most values are within expected ECG range (0-4095), it might be raw data
    bool mightBeRawData = true;
    for (int i = 0; i < min(20, response.length); i++) {
      if (response[i] > 4095) {
        mightBeRawData = false;
        break;
      }
    }

    if (mightBeRawData && response.length >= 100) {
      _logger.info('Data appears to be already in raw format');
      return response.map((value) => value.clamp(0, 4095)).toList();
    }
    
    // Otherwise, try different decoding methods to see what works
    List<List<int>> candidateDecodings = [];
    
    // Try little-endian decoding
    try {
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(response));
      List<int> littleEndianData = [];
      
      for (int i = 0; i < response.length - 1; i += 2) {
        int value = byteData.getInt16(i, Endian.little);
        littleEndianData.add(value.clamp(0, 4095));
      }
      
      candidateDecodings.add(littleEndianData);
      _logger.info('Added little-endian decoding, ${littleEndianData.length} points');
    } catch (e) {
      _logger.warning('Little-endian decoding failed: $e');
    }
    
    // Try big-endian decoding
    try {
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(response));
      List<int> bigEndianData = [];
      
      for (int i = 0; i < response.length - 1; i += 2) {
        int value = byteData.getInt16(i, Endian.big);
        bigEndianData.add(value.clamp(0, 4095));
      }
      
      candidateDecodings.add(bigEndianData);
      _logger.info('Added big-endian decoding, ${bigEndianData.length} points');
    } catch (e) {
      _logger.warning('Big-endian decoding failed: $e');
    }
    
    // Try unsigned little-endian decoding
    try {
      ByteData byteData = ByteData.sublistView(Uint8List.fromList(response));
      List<int> unsignedLittleEndianData = [];
      
      for (int i = 0; i < response.length - 1; i += 2) {
        int value = byteData.getUint16(i, Endian.little);
        unsignedLittleEndianData.add(value.clamp(0, 4095));
      }
      
      candidateDecodings.add(unsignedLittleEndianData);
      _logger.info('Added unsigned little-endian decoding, ${unsignedLittleEndianData.length} points');
    } catch (e) {
      _logger.warning('Unsigned little-endian decoding failed: $e');
    }
    
    // Choose the best decoding based on data quality
    if (candidateDecodings.isEmpty) {
      _logger.warning('No successful decodings, returning empty list');
      return [];
    }
    
    // Simple heuristic: Choose the decoding with the most reasonable values
    // For ECG data, we expect values to be in a certain range
    List<int> bestDecoding = candidateDecodings.first;
    int bestScore = _scoreECGData(bestDecoding);
    
    for (var decoding in candidateDecodings.skip(1)) {
      int score = _scoreECGData(decoding);
      if (score > bestScore) {
        bestScore = score;
        bestDecoding = decoding;
      }
    }
    
    _logger.info('Selected best decoding with score $bestScore, ${bestDecoding.length} points');
    return bestDecoding;
  } catch (e) {
    _logger.severe('Error in ECG data decoding: $e');
    return [];
  }
}

// Add this helper method to score the quality of decoded ECG data
int _scoreECGData(List<int> data) {
  // Count how many values are in a reasonable ECG range
  // For this application, we expect values between ~500 and ~3500
  int inRange = 0;
  for (int value in data) {
    if (value >= 500 && value <= 3500) {
      inRange++;
    }
  }
  
  // Calculate score as percentage of values in range
  return (inRange * 100) ~/ data.length;
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

      Map<dynamic, dynamic> readingsMap =
          snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> readings = [];

      for (var entry in readingsMap.entries) {
        readings.add(Map<String, dynamic>.from(entry.value as Map));
      }

      readings.sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));

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

      Map<dynamic, dynamic> readingsMap =
          snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> readings = [];

      for (var entry in readingsMap.entries) {
        Map<dynamic, dynamic> readingData =
            entry.value as Map<dynamic, dynamic>;
        Map<String, dynamic> reading = Map<String, dynamic>.from(readingData);

        try {
          // Ensure the download URL is still valid
          if (!reading.containsKey('downloadUrl') ||
              reading['downloadUrl'] == null) {
            String downloadUrl =
                await _storage.ref(reading['filename']).getDownloadURL();
            reading['downloadUrl'] = downloadUrl;
          }
          readings.add(reading);
        } catch (e) {
          _logger.warning(
              'Error getting download URL for ECG ${reading['filename']}: $e');
          continue;
        }
      }

      readings.sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));

      return readings;
    } catch (e) {
      _logger.severe('Error fetching ECG readings: $e');
      rethrow;
    }
  }

  // Add these methods to your FirebaseService class in paste.txt

  // Delete specific recording
  Future<void> deleteRecording(
      String uid, String medicalCardNumber, String recordingId) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

      // Get recording metadata
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .child(recordingId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('Recording not found');
      }

      Map<dynamic, dynamic> recordingData =
          snapshot.value as Map<dynamic, dynamic>;
      String filename = recordingData['filename'] as String;

      // Delete file from storage
      await _storage.ref(filename).delete();

      // Delete metadata from database
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .child(recordingId)
          .remove();

      _logger.info('Recording deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting recording: $e');
      rethrow;
    }
  }

  // Delete all recordings for a patient
  Future<void> deleteAllRecordings(String uid, String medicalCardNumber) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

      // Get all recordings
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        _logger.info('No recordings found to delete');
        return;
      }

      Map<dynamic, dynamic> recordingsMap =
          snapshot.value as Map<dynamic, dynamic>;

      // Delete each file from storage
      for (var entry in recordingsMap.entries) {
        Map<dynamic, dynamic> recording = entry.value as Map<dynamic, dynamic>;
        String filename = recording['filename'] as String;

        try {
          await _storage.ref(filename).delete();
        } catch (e) {
          _logger.warning('Error deleting recording file: $e');
          // Continue with deleting other files
        }
      }

      // Remove all recordings metadata
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('recordings')
          .remove();

      _logger.info('All recordings deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting all recordings: $e');
      rethrow;
    }
  }

  // Delete specific ECG reading
  Future<void> deleteECGReading(
      String uid, String medicalCardNumber, String ecgId) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

      // Get ECG metadata
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .child(ecgId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        throw Exception('ECG reading not found');
      }

      Map<dynamic, dynamic> ecgData = snapshot.value as Map<dynamic, dynamic>;
      String filename = ecgData['filename'] as String;

      // Delete file from storage
      await _storage.ref(filename).delete();

      // Delete metadata from database
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .child(ecgId)
          .remove();

      _logger.info('ECG reading deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting ECG reading: $e');
      rethrow;
    }
  }

  // Delete all ECG readings for a patient
  Future<void> deleteAllECGReadings(
      String uid, String medicalCardNumber) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

      // Get all ECG readings
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        _logger.info('No ECG readings found to delete');
        return;
      }

      Map<dynamic, dynamic> ecgMap = snapshot.value as Map<dynamic, dynamic>;

      // Delete each file from storage
      for (var entry in ecgMap.entries) {
        Map<dynamic, dynamic> ecgReading = entry.value as Map<dynamic, dynamic>;
        String filename = ecgReading['filename'] as String;

        try {
          await _storage.ref(filename).delete();
        } catch (e) {
          _logger.warning('Error deleting ECG file: $e');
          // Continue with deleting other files
        }
      }

      // Remove all ECG metadata
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .remove();

      _logger.info('All ECG readings deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting all ECG readings: $e');
      rethrow;
    }
  }

  // Delete specific PulseOx session
  Future<void> deletePulseOxSession(
      String uid, String medicalCardNumber, String sessionId) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

      // Delete session from database
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('pulseOxSessions')
          .child(sessionId)
          .remove();

      _logger.info('PulseOx session deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting PulseOx session: $e');
      rethrow;
    }
  }

  // Delete all PulseOx sessions for a patient
  Future<void> deleteAllPulseOxSessions(
      String uid, String medicalCardNumber) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');

      // Remove all PulseOx sessions
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('pulseOxSessions')
          .remove();

      _logger.info('All PulseOx sessions deleted successfully!');
    } catch (e) {
      _logger.severe('Error deleting all PulseOx sessions: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeRecording(String filename) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(
            'https://2e86-2001-56b-9ff1-10a6-8c48-2ff-f87e-1b7c.ngrok-free.app/analyze'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'firebase_path': filename}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Analysis failed: ${response.statusCode}');
    } catch (e) {
      _logger.severe('Analysis error: $e');
      rethrow;
    }
  }
}
