import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String GUEST_KEY = 'is_guest_mode';
  static const String LAST_LOGIN_KEY = 'last_login_time';
  static const int MAX_FAILED_ATTEMPTS = 5;
  static const String FAILED_ATTEMPTS_KEY = 'failed_login_attempts';
  static const String LOCKOUT_TIME_KEY = 'login_lockout_time';

  // Check if an email is already registered with Firebase Auth
  Future<bool> isEmailRegistered(String email) async {
    try {
      // This method returns a list of sign-in methods available for the email
      // If the list is empty, the email is not registered
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print('Error checking if email is registered: $e');
      return false; // Return false on error to not block registration
    }
  }

  // Register with email and password with enhanced error handling
  Future<User?> register(String email, String password) async {
    try {
      await _setGuestMode(false);
      
      // Validate email and password before attempting to create account
      if (email.isEmpty || !email.contains('@')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.'
        );
      }
      
      if (password.isEmpty || password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'The password is too weak.'
        );
      }
      
      // Check if email is already registered
      bool isRegistered = await isEmailRegistered(email);
      if (isRegistered) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use by another account.'
        );
      }
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Send email verification
      await userCredential.user?.sendEmailVerification();
      
      // Reset any previous failed attempts after successful registration
      _resetFailedAttempts();
      
      // Store login time
      await _updateLastLoginTime();
      
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('Error registering user: ${e.code} - ${e.message}');
      rethrow; // Rethrow to allow handling in UI
    } catch (e) {
      print('Unexpected error registering user: $e');
      throw FirebaseAuthException(
        code: 'unexpected-error',
        message: 'An unexpected error occurred. Please try again.'
      );
    }
  }

  // Login with email and password with brute force protection
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Check for too many failed attempts
      if (await _isLockedOut()) {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Access temporarily disabled due to many failed login attempts. Try again later.'
        );
      }
      
      // Validate input before login attempt
      if (email.isEmpty) {
        await _incrementFailedAttempts();
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Email cannot be empty.'
        );
      }
      
      if (password.isEmpty) {
        await _incrementFailedAttempts();
        throw FirebaseAuthException(
          code: 'invalid-password',
          message: 'Password cannot be empty.'
        );
      }
      
      await _setGuestMode(false);
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Check if email is verified
      if (credential.user != null && !credential.user!.emailVerified) {
        // You might want to handle this differently based on your app's needs
        // Here we just notify about it, but still allow login
        print('Warning: Email not verified');
      }
      
      // Reset failed attempts on successful login
      _resetFailedAttempts();
      
      // Store login time
      await _updateLastLoginTime();
      
      return credential;
    } on FirebaseAuthException catch (e) {
      // Increment failed attempts for authentication failures
      if (['user-not-found', 'wrong-password', 'invalid-credential'].contains(e.code)) {
        await _incrementFailedAttempts();
      }
      rethrow;
    } catch (e) {
      await _incrementFailedAttempts();
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
  
  // Get last login time
  Future<DateTime?> getLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(LAST_LOGIN_KEY);
    return timestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  // Method to send verification email
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print('Error sending verification email: $e');
      rethrow;
    }
  }

  // Method to check if email is verified
  Future<bool> isEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  // Private helper to set guest mode
  Future<void> _setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GUEST_KEY, isGuest);
  }
  
  // Private helper to update last login time
  Future<void> _updateLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LAST_LOGIN_KEY, DateTime.now().millisecondsSinceEpoch);
  }
  
  // Private helper to track failed attempts
  Future<void> _incrementFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    int attempts = prefs.getInt(FAILED_ATTEMPTS_KEY) ?? 0;
    attempts++;
    await prefs.setInt(FAILED_ATTEMPTS_KEY, attempts);
    
    // Set lockout time if max attempts reached
    if (attempts >= MAX_FAILED_ATTEMPTS) {
      // Lock for 30 minutes
      final lockoutTime = DateTime.now().add(Duration(minutes: 30)).millisecondsSinceEpoch;
      await prefs.setInt(LOCKOUT_TIME_KEY, lockoutTime);
    }
  }
  
  // Private helper to check if account is locked
  Future<bool> _isLockedOut() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get the number of failed attempts
    int attempts = prefs.getInt(FAILED_ATTEMPTS_KEY) ?? 0;
    if (attempts < MAX_FAILED_ATTEMPTS) {
      return false;
    }
    
    // Check if we're still in lockout period
    int? lockoutTimeMs = prefs.getInt(LOCKOUT_TIME_KEY);
    if (lockoutTimeMs == null) {
      return false;
    }
    
    // Check if lockout period has expired
    DateTime lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimeMs);
    bool stillLocked = lockoutTime.isAfter(DateTime.now());
    
    // If lockout has expired, reset failed attempts
    if (!stillLocked) {
      _resetFailedAttempts();
    }
    
    return stillLocked;
  }
  
  // Reset failed login attempts
  Future<void> _resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(FAILED_ATTEMPTS_KEY);
    await prefs.remove(LOCKOUT_TIME_KEY);
  }
  
  // Method to change password with current password verification
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user is currently signed in.'
      );
    }
    
    if (user.email == null) {
      throw FirebaseAuthException(
        code: 'invalid-user',
        message: 'User does not have an email address.'
      );
    }
    
    try {
      // Re-authenticate user to confirm current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      print('Error changing password: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected error changing password: $e');
      throw FirebaseAuthException(
        code: 'unexpected-error',
        message: 'An unexpected error occurred while changing password.'
      );
    }
  }
  
  // Request password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Error sending password reset email: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected error sending reset email: $e');
      throw FirebaseAuthException(
        code: 'unexpected-error',
        message: 'An unexpected error occurred. Please try again.'
      );
    }
  }
}