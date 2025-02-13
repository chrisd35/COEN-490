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
      await _database
          .child('users')
          .child(user.uid)
          .set(user.toMap());
      print('User saved successfully!');
    } catch (e) {
      print('Error saving user: $e');
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
      String sanitizedMedicalCard = patient.medicalCardNumber.replaceAll('/', '_');
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
  // Add this method to your FirebaseService class:

Future<List<Patient>> getPatientsForUser(String uid) async {
  try {
    // Get snapshot of all patients under the user
    DataSnapshot snapshot = await _database
        .child('users')
        .child(uid)
        .child('patients')
        .get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    // Convert the snapshot value to a Map
    Map<dynamic, dynamic> patientsMap = snapshot.value as Map<dynamic, dynamic>;
    
    // Convert each patient entry to a Patient object
    List<Patient> patients = patientsMap.entries.map((entry) {
      return Patient.fromMap(entry.value as Map<dynamic, dynamic>);
    }).toList();

    // Sort patients by name for better display
    patients.sort((a, b) => a.fullName.compareTo(b.fullName));
    
    return patients;
  } catch (e) {
    print('Error fetching patients: $e');
    rethrow;
  }
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
      
      // Create WAV file
      final wavData = createWavFile(
        audioData,
        sampleRate: metadata['sampleRate'] ?? 44100,
        bitsPerSample: metadata['bitsPerSample'] ?? 16,
        channels: metadata['channels'] ?? 1,
      );

      // Generate filename with proper path structure
      String filename = 'users/$uid/patients/$sanitizedMedicalCard/recordings/${timestamp.millisecondsSinceEpoch}.wav';

      // Upload to Firebase Storage
      await _storage.ref(filename).putData(
        Uint8List.fromList(wavData),
        SettableMetadata(contentType: 'audio/wav'),
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
            'sampleRate': metadata['sampleRate'],
            'peakAmplitude': metadata['peakAmplitude'],
          });
    } catch (e) {
      print('Error saving recording: $e');
      rethrow;
    }
  }

  List<int> createWavFile(
    List<int> audioData, {
    int sampleRate = 44100,
    int bitsPerSample = 16,
    int channels = 1,
  }) {
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    
    ByteData header = ByteData(44);
    
    header.setUint32(0, 0x52494646, Endian.big);
    header.setUint32(4, 36 + audioData.length, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big);
    
    header.setUint32(12, 0x666D7420, Endian.big);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    
    header.setUint32(36, 0x64617461, Endian.big);
    header.setUint32(40, audioData.length, Endian.little);
    
    return [...header.buffer.asUint8List(), ...audioData];
  }
Future<List<Recording>> getRecordingsForPatient(String uid, String medicalCardNumber) async {
    try {
      String sanitizedMedicalCard = medicalCardNumber.replaceAll('/', '_');
      
      // Get recordings metadata from Realtime Database
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

      // For each recording, create Recording object and get download URL
      for (var entry in recordingsMap.entries) {
        Map<dynamic, dynamic> recordingData = entry.value as Map<dynamic, dynamic>;
        Recording recording = Recording.fromMap(recordingData);
        
        try {
          // Get download URL from Storage
          String downloadUrl = await _storage.ref(recording.filename).getDownloadURL();
          recording.downloadUrl = downloadUrl;
        } catch (e) {
          print('Error getting download URL for recording ${recording.filename}: $e');
          // Continue with next recording if this one fails
          continue;
        }
        
        recordings.add(recording);
      }

      // Sort recordings by timestamp, newest first
      recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return recordings;
    } catch (e) {
      print('Error fetching recordings: $e');
      rethrow;
    }
  }
  
}