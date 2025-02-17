import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String GUEST_KEY = 'is_guest_mode';

  // Register with email and password
  Future<User?> register(String email, String password) async {
    try {
      await _setGuestMode(false);
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
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
      await _setGuestMode(false);
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      rethrow;
    } catch (e) {
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  // Sign in as guest
  Future<void> signInAsGuest() async {
    try {
      // First ensure any existing user is signed out
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      
      // Simply set guest mode without anonymous authentication
      await _setGuestMode(true);
    } catch (e) {
      print('Error entering guest mode: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
      await _setGuestMode(false);
    } catch (e) {
      print('Error during logout: $e');
      rethrow;
    }
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if a user is logged in and not a guest
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null && !(await isGuest());
  }

  // Check if current user is guest
  Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(GUEST_KEY) ?? false;
  }

  // Private helper to set guest mode
  Future<void> _setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GUEST_KEY, isGuest);
  }
}
  // Check if a user is logged in
