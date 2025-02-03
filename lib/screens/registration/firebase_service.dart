import 'package:coen_490/screens/registration/user_model.dart';
import 'package:coen_490/screens/patient/patient_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _database;

  FirebaseService()
      : _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL:
              'https://respirhythm-default-rtdb.firebaseio.com/', // Add this line
        ).ref();

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
  Future<User?> getUser(String uid) async {
    try {
      DataSnapshot snapshot = await _database.child('users').child(uid).get();
      if (snapshot.exists) {
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
}
