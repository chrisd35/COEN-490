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

   // Save audio recording for a specific patient
  Future<void> saveAudioRecording(String uid, String medicalCardNumber, List<int> data) async {
    try {
      // Convert data to Uint8List
      Uint8List audioBytes = Uint8List.fromList(data);

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child("audio/${DateTime.now().millisecondsSinceEpoch}.wav");
      final uploadTask = storageRef.putData(audioBytes);

      // Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Realtime Database under the patient's node
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(medicalCardNumber.replaceAll('/', '_'))
          .child('audio_recordings')
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .set({
            'url': downloadUrl,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

      print('Audio recording saved successfully!');
    } catch (e) {
      print('Error saving audio recording: $e');
    }
  }

  // Fetch audio recordings for a specific patient
  Future<Map<String, dynamic>?> getAudioRecordings(String uid, String medicalCardNumber) async {
    try {
      final snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(medicalCardNumber.replaceAll('/', '_'))
          .child('audio_recordings')
          .get();
      if (snapshot.exists) {
        return snapshot.value as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching audio recordings: $e');
    }
    return null;
  }

  // Save PulseOx data for a specific patient
  Future<void> savePulseOxData(String uid, String medicalCardNumber, int value) async {
    try {
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(medicalCardNumber.replaceAll('/', '_'))
          .child('pulseox_data')
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .set({
            'value': value,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
      print('PulseOx data saved successfully!');
    } catch (e) {
      print('Error saving PulseOx data: $e');
    }
  }

  // Fetch PulseOx data for a specific patient
  Future<Map<String, dynamic>?> getPulseOxData(String uid, String medicalCardNumber) async {
    try {
      final snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(medicalCardNumber.replaceAll('/', '_'))
          .child('pulseox_data')
          .get();
      if (snapshot.exists) {
        return snapshot.value as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching PulseOx data: $e');
    }
    return null;
  }

  // Save ECG data for a specific patient
  Future<void> saveEcgData(String uid, String medicalCardNumber, List<int> data) async {
    try {
      // Convert data to Uint8List
      Uint8List ecgBytes = Uint8List.fromList(data);

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child("ecg/${DateTime.now().millisecondsSinceEpoch}.csv");
      final uploadTask = storageRef.putData(ecgBytes);

      // Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Realtime Database under the patient's node
      await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(medicalCardNumber.replaceAll('/', '_'))
          .child('ecg_data')
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .set({
            'url': downloadUrl,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

      print('ECG data saved successfully!');
    } catch (e) {
      print('Error saving ECG data: $e');
    }
  }

  // Fetch ECG data for a specific patient
  Future<Map<String, dynamic>?> getEcgData(String uid, String medicalCardNumber) async {
    try {
      final snapshot = await _database
          .child('users')
          .child(uid)
          .child('patients')
          .child(medicalCardNumber.replaceAll('/', '_'))
          .child('ecg_data')
          .get();
      if (snapshot.exists) {
        return snapshot.value as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching ECG data: $e');
    }
    return null;
  }

  // Fetch audio data from Firebase Storage
  Future<Uint8List?> getAudioData(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      final data = await ref.getData();
      return data;
    } catch (e) {
      print("Error fetching audio data: $e");
    }
    return null;
  }
}