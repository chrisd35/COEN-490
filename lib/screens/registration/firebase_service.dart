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
        sampleRate: metadata['sampleRate'] ?? 4000, // Default to 4kHz
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
        // Upload to Firebase Storage with additional metadata
        await _storage.ref(filename).putData(
              Uint8List.fromList(wavData),
              SettableMetadata(
                contentType: 'audio/wav',
                customMetadata: {
                  'sampleRate': (metadata['sampleRate'] ?? 4000).toString(),
                  'duration': metadata['duration'].toString(),
                  'bitsPerSample': (metadata['bitsPerSample'] ?? 16).toString(),
                  'channels': (metadata['channels'] ?? 1).toString(),
                  'processingApplied': 'true',
                  'processingDetails':
                      'bandpass,median,adaptiveGain,noiseReduction,normalization',
                },
              ),
            );
        _logger.info("DEBUG 4: Successfully uploaded audio to storage");
      } catch (e) {
        _logger.severe("DEBUG ERROR STORAGE: Error in storage upload: $e");
        rethrow;
      }

      // Add debug point 4
      try {
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
          'peakAmplitude': metadata['peakAmplitude'],
          'processingApplied': true,
          'processingDetails':
              'bandpass,median,adaptiveGain,noiseReduction,normalization',
        });
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

  List<int> createWavFile(
    List<int> audioData, {
    int sampleRate = 16000, // Updated default to 16kHz
    int bitsPerSample = 16,
    int channels = 1,
  }) {
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);

    _logger.info(
        "Creating WAV with: Sample rate: $sampleRate Hz, Bits: $bitsPerSample, Channels: $channels");

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

    _logger
        .info("WAV header created for ${audioData.length} bytes of audio data");

    return [...header.buffer.asUint8List(), ...audioData];
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
        Recording recording = Recording.fromMap(recordingData);

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
      final response =
          await FirebaseStorage.instance.refFromURL(downloadUrl).getData();

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
        Uri.parse('http://localhost:8000/analyze'),
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
