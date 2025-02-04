import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Register with email and password
  Future<User?> register(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user; // Return the registered user
    } catch (e) {
      print('Error registering user: $e');
      return null;
    }
  }

  
  // Login with email and password
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      rethrow; // Propagate the FirebaseAuthException
    } catch (e) {
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Check if a user is logged in
  User? getCurrentUser() {
    return _auth.currentUser;
  }


}