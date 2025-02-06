import 'package:coen_490/screens/registration/user_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

import '../patient/patient_model.dart';

class FirebaseService {
  final DatabaseReference _database;
  final FirebaseStorage _storage;

  FirebaseService()
      : _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://respirhythm-default-rtdb.firebaseio.com/', // Realtime Database URL
        ).ref(),
        _storage = FirebaseStorage.instanceFor(
          app: Firebase.app(),
          bucket: 'respirhythm.firebasestorage.app', // Firebase Storage URL
        );
  // Save user data to Realtime Database
  Future<void> saveUser(User user) async {
    try {
      await _database
          .child('users')
          .child(user.uid)
          .child(user.email.replaceAll('.', ','))
          .set(user.toMap());
      print('User saved successfully!');
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  // Fetch user data from Realtime Database
  Future<User?> getUser(String uid, String email) async {
    try {
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child(email.replaceAll('.', ','))
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

  // Save user data to Realtime Database
  Future<void> savePatient(String uid, Patient patient) async {
    try {
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(patient.medicalCardNumber.replaceAll('/', '_'))
          .set(patient.toMap());
      print('Patient saved successfully!');
    } catch (e) {
      print('Error saving patient: $e');
    }
  }

  // Fetch user data from Realtime Database
  Future<Patient?> getPatient(String uid, String medicalCardNumber) async {
    try {
      DataSnapshot snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child('patients')
          .child(medicalCardNumber)
          .get();
      if (snapshot.exists) {
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
Future<void> saveRecording(
  String patientId, 
  DateTime timestamp, 
  List<int> audioData,
  Map<String, dynamic> metadata
) async {
  try {
    // Create WAV file with actual recording parameters
    final wavData = createWavFile(
      audioData, 
      sampleRate: metadata['sampleRate'] ?? 44100,
      bitsPerSample: metadata['bitsPerSample'] ?? 16,
      channels: metadata['channels'] ?? 1
    );
    
    // Generate filename
    String filename = 'recordings/$patientId/${timestamp.millisecondsSinceEpoch}.wav';
    
    // Upload to Firebase Storage
    await _storage.ref(filename).putData(
      Uint8List.fromList(wavData),
      SettableMetadata(contentType: 'audio/wav')
    );
    
    // Save metadata to Realtime Database
    await _database
      .child('patients')
      .child(patientId)
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
  // WAV file parameters
  final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final int blockAlign = channels * (bitsPerSample ~/ 8);
  
  // Create header with precise calculations
  ByteData header = ByteData(44);
  
  // RIFF chunk descriptor
  header.setUint32(0, 0x52494646, Endian.big); // 'RIFF'
  header.setUint32(4, 36 + audioData.length, Endian.little); // File size
  header.setUint32(8, 0x57415645, Endian.big); // 'WAVE'
  
  // fmt sub-chunk
  header.setUint32(12, 0x666D7420, Endian.big); // 'fmt '
  header.setUint32(16, 16, Endian.little); // Subchunk1Size
  header.setUint16(20, 1, Endian.little); // Audio format (PCM)
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  
  // data sub-chunk
  header.setUint32(36, 0x64617461, Endian.big); // 'data'
  header.setUint32(40, audioData.length, Endian.little); // Subchunk2Size
  
  // Combine header and audio data
  return [...header.buffer.asUint8List(), ...audioData];
}
}
