import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '/utils/models.dart';

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
      print('User saved successfully!');
    } catch (e) {
      print('Error saving user: $e');
      rethrow;
    }
  }

  Future<User?> getUser(String uid, String s) async {
    try {
      DataSnapshot snapshot = await _database.child('users').child(uid).get();

      if (snapshot.exists && snapshot.value != null) {
        return User.fromMap(snapshot.value as Map<dynamic, dynamic>);
      } else {
        print('User not found');
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Future<void> savePatient(String uid, Patient patient) async {
    try {
      String sanitizedMedicalCard =
          patient.medicalCardNumber.replaceAll('/', '_');
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .set(patient.toMap());
      print('Patient saved successfully!');
    } catch (e) {
      print('Error saving patient: $e');
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
        print('Patient not found');
        return null;
      }
    } catch (e) {
      print('Error fetching patient: $e');
      return null;
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
      List<Patient> patients = patientsMap.entries.map((entry) {
        return Patient.fromMap(entry.value as Map<dynamic, dynamic>);
      }).toList();

      patients.sort((a, b) => a.fullName.compareTo(b.fullName));
      return patients;
    } catch (e) {
      print('Error fetching patients: $e');
      rethrow;
    }
  }

  void debugAudioData(List<int> audioData, int sampleRate, int duration) {
    int expectedSamples = sampleRate * duration;
    int expectedBytes = expectedSamples * 2;

    print("Audio Debug Info:");
    print("Sample Rate: $sampleRate Hz");
    print("Duration: $duration seconds");
    print("Expected samples: $expectedSamples");
    print("Expected bytes: $expectedBytes");
    print("Actual bytes received: ${audioData.length}");
    print("Actual samples (bytes/2): ${audioData.length ~/ 2}");
    print(
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

      // Validate and adjust audio data if necessary
      int expectedBytes = (metadata['sampleRate'] ?? 4000) *
          (metadata['duration'] ?? 0) *
          2; // 2 bytes per sample

      List<int> processedAudioData = audioData;
      if (audioData.length != expectedBytes) {
        print("Warning: Audio data length mismatch");
        print("Expected: $expectedBytes bytes");
        print("Actual: ${audioData.length} bytes");

        if (audioData.length > expectedBytes) {
          processedAudioData = audioData.sublist(0, expectedBytes);
          print("Trimmed audio data to expected length");
        }
      }

      // Debug processed data
      debugAudioData(processedAudioData, metadata['sampleRate'] ?? 4000,
          metadata['duration']);

      // Create WAV file
      final wavData = createWavFile(
        processedAudioData,
        sampleRate: metadata['sampleRate'] ?? 4000,
        bitsPerSample: metadata['bitsPerSample'] ?? 16,
        channels: metadata['channels'] ?? 1,
      );

      // Generate filename
      String filename =
          'users/$uid/patients/$sanitizedMedicalCard/recordings/${timestamp.millisecondsSinceEpoch}.wav';

      // Upload to Firebase Storage
      await _storage.ref(filename).putData(
            Uint8List.fromList(wavData),
            SettableMetadata(
              contentType: 'audio/wav',
              customMetadata: {
                'sampleRate': (metadata['sampleRate'] ?? 4000).toString(),
                'duration': metadata['duration'].toString(),
                'bitsPerSample': (metadata['bitsPerSample'] ?? 16).toString(),
                'channels': (metadata['channels'] ?? 1).toString(),
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
        'peakAmplitude': metadata['peakAmplitude'],
      });

      print("Recording saved successfully with correct duration");
    } catch (e) {
      print('Error saving recording: $e');
      rethrow;
    }
  }

  List<int> createWavFile(
    List<int> audioData, {
    int sampleRate = 4000,
    int bitsPerSample = 16,
    int channels = 1,
  }) {
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);

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
          print(
              'Error getting download URL for recording ${recording.filename}: $e');
          continue;
        }
      }

      recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return recordings;
    } catch (e) {
      print('Error fetching recordings: $e');
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

      print('PulseOx session saved successfully');
    } catch (e) {
      print('Error saving PulseOx session: $e');
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

      sessionsMap.forEach((key, value) {
        if (value is Map) {
          // Ensure readings is treated as a List
          if (value['readings'] is Map) {
            value['readings'] = (value['readings'] as Map).values.toList();
          }
          sessions.add(PulseOxSession.fromMap(value as Map<dynamic, dynamic>));
        }
      });

      // Sort by timestamp, newest first
      sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return sessions;
    } catch (e) {
      print('Error fetching PulseOx sessions: $e');
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

      print('ECG reading saved successfully');
    } catch (e) {
      print('Error saving ECG reading: $e');
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
      print('Error downloading ECG data: $e');
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

      readingsMap.forEach((key, value) {
        readings.add(Map<String, dynamic>.from(value as Map));
      });

      readings.sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));

      return readings;
    } catch (e) {
      print('Error fetching PulseOx readings: $e');
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
          print(
              'Error getting download URL for ECG ${reading['filename']}: $e');
          continue;
        }
      }

      readings.sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));

      return readings;
    } catch (e) {
      print('Error fetching ECG readings: $e');
      rethrow;
    }
  }

  Stream<List<Patient>> getPatientsStream(String uid) {
    return _database
        .child('users')
        .child(uid)
        .child('patients')
        .onValue
        .map((event) {
      final patientsMap = event.snapshot.value as Map<dynamic, dynamic>;
      final patients = patientsMap.entries.map((entry) {
        return Patient.fromMap(Map<String, dynamic>.from(entry.value));
      }).toList();
      return patients;
    });
  }
}
