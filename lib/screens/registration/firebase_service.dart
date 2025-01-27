import 'package:firebase_database/firebase_database.dart';
import 'user_model.dart'; // Import the User model

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Save user data to Realtime Database
  Future<void> saveUser(User user) async {
    try {
      await _database.child('users').child(user.email.replaceAll('.', ',')).set(user.toMap());
      print('User saved successfully!');
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  // Fetch user data from Realtime Database
  Future<User?> getUser(String email) async {
    try {
      DataSnapshot snapshot = await _database.child('users').child(email.replaceAll('.', ',')).get();
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
}