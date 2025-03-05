// No special imports needed for basic validation utilities
import 'package:coen_490/screens/registration/firebase_service.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('ValidationUtils');

class ValidationUtils {
  // Email validation with regex
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    // RFC 5322 compliant email regex (fixed syntax)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$'
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    
    return null;
  }
  
  // Password strength validation
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (!(hasUppercase && hasDigits)) {
      return 'Password must contain uppercase letters and numbers';
    }
    
    // Optional: require special characters
    if (!hasSpecialChars) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }
  
  // Phone number validation
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove any spaces, dashes, or parentheses
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Check if the phone number contains only digits
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanPhone)) {
      return 'Phone number should contain only digits';
    }
    
    // Check length (adjust based on your country's requirements)
    if (cleanPhone.length < 10 || cleanPhone.length > 15) {
      return 'Enter a valid phone number';
    }
    
    return null;
  }
  
  // Date validation
  static String? validateDateOfBirth(String? date) {
    if (date == null || date.isEmpty) {
      return 'Date of birth is required';
    }
    
    try {
      // Try to parse the date
      final parsedDate = DateTime.parse(date);
      
      // Check if date is in the future
      if (parsedDate.isAfter(DateTime.now())) {
        return 'Date of birth cannot be in the future';
      }
      
      // Check if person is too old (e.g., > 120 years)
      final oneHundredTwentyYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 120));
      if (parsedDate.isBefore(oneHundredTwentyYearsAgo)) {
        return 'Please enter a valid date of birth';
      }
      
      return null;
    } catch (e) {
      return 'Enter a valid date format (YYYY-MM-DD)';
    }
  }
  
  // Medicare number validation
  static String? validateMedicareNumber(String? medicareNumber) {
    if (medicareNumber == null || medicareNumber.isEmpty) {
      return 'Medical card number is required';
    }
    
    // Medicare format validation - adjust based on your specific format
    // Example: Assumes format like "1234-567-890"
    final cleanNumber = medicareNumber.replaceAll(RegExp(r'[^\w]'), '');
    
    if (cleanNumber.length < 6 || cleanNumber.length > 12) {
      return 'Enter a valid medical card number';
    }
    
    return null;
  }
  
  // Name validation
  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return 'Name is required';
    }
    
    if (name.length < 2) {
      return 'Name is too short';
    }
    
    if (!RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(name)) {
      return 'Name should contain only letters, spaces, hyphens, and periods';
    }
    
    return null;
  }
  
  // Format phone number for display/storage
  static String formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Format based on digit count and country format
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    
    return phone; // Return original if can't format
  }
  
  static Future<String?> validateEmailAvailability(String email) async {
    // First do basic validation
    String? basicValidation = validateEmail(email);
    if (basicValidation != null) {
      return basicValidation;
    }
    
    // Then check availability
    try {
      final FirebaseService firebaseService = FirebaseService();
      bool isInUse = await firebaseService.isEmailInUse(email);
      
      if (isInUse) {
        return 'This email is already registered. Please use a different email or try logging in.';
      }
      
      return null;
    } catch (e) {
      _logger.warning('Error validating email availability: $e');
      return null; // On error, allow the form to proceed
    }
  }
  
  static bool isEmailFormatValid(String email) {
    // More comprehensive RFC 5322 compliant email regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    
    return emailRegex.hasMatch(email);
  }
}