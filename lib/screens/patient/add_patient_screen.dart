import 'package:flutter/material.dart';
import '../registration/firebase_service.dart';
import '/utils/models.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '/utils/validation_utils.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';

class AddPatientScreen extends StatefulWidget {
  final bool fromMurmurRecord;

  AddPatientScreen({
    Key? key,
    this.fromMurmurRecord = false,
  }) : super(key: key);
  @override
  _AddPatientScreenState createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _medicalCardController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
  bool _isCheckingMedicareNumber = false;
  String? _medicareNumberError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _medicalCardController.dispose();
    _dateOfBirthController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, IconData? icon, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue[700]) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      errorText: errorText,
    );
  }

  // Method to check if Medicare number is already in use
  Future<bool> _isMedicareNumberUnique(String medicareNumber) async {
    setState(() => _isCheckingMedicareNumber = true);
    
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return true; // Can't check without a user ID
      
      final patients = await _firebaseService.getPatientsForUser(uid);
      
      // Check if any existing patient has this medical card number
      bool isUnique = !patients.any((patient) => 
        patient.medicalCardNumber.replaceAll('/', '_') == 
        medicareNumber.replaceAll('/', '_')
      );
      
      return isUnique;
    } catch (e) {
      print('Error checking Medicare number uniqueness: $e');
      return true; // Assume unique on error to allow submission
    } finally {
      if (mounted) {
        setState(() => _isCheckingMedicareNumber = false);
      }
    }
  }

  // Validate Medicare number with uniqueness check
  Future<String?> _validateMedicareNumber(String? value) async {
    // First check basic validation
    String? basicValidation = ValidationUtils.validateMedicareNumber(value);
    if (basicValidation != null) {
      return basicValidation;
    }
    
    // Then check uniqueness
    bool isUnique = await _isMedicareNumberUnique(value!);
    if (!isUnique) {
      return 'This medical card number is already registered';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Create New Patient',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: Container(
          color: Colors.white,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        'Patient Information',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 24),

                      // Full Name
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _buildInputDecoration('Full Name', Icons.person),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: ValidationUtils.validateName,
                      ),
                      SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: _buildInputDecoration('Email', Icons.email),
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: ValidationUtils.validateEmail,
                      ),
                      SizedBox(height: 16),

                      // Medical Card with uniqueness check
                      TextFormField(
                        controller: _medicalCardController,
                        decoration: _buildInputDecoration(
                          'Medical Card #', 
                          Icons.health_and_safety,
                          errorText: _medicareNumberError,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (value) {
                          // Clear error when user types
                          if (_medicareNumberError != null) {
                            setState(() => _medicareNumberError = null);
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // Date of Birth
                      GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(Duration(days: 365 * 30)), // Default to 30 years ago
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: Colors.blue[700]!,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _dateOfBirthController.text =
                                  "${pickedDate.toLocal()}".split(' ')[0];
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _dateOfBirthController,
                            decoration: _buildInputDecoration(
                              'Date of Birth',
                              Icons.calendar_today,
                            ),
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            validator: ValidationUtils.validateDateOfBirth,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        decoration: _buildInputDecoration('Gender', Icons.people),
                        value: _selectedGender,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        items: ['Male', 'Female', 'Other'].map((String gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator: (value) => value == null ? 'Gender is required' : null,
                      ),
                      SizedBox(height: 16),

                      // Phone Number
                      TextFormField(
                        controller: _phoneNumberController,
                        decoration: _buildInputDecoration('Phone Number', Icons.phone),
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: ValidationUtils.validatePhoneNumber,
                      ),
                      SizedBox(height: 32),

                      // Save Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save Patient Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    // Check for Medicare number uniqueness first
    String medicareNumber = _medicalCardController.text.trim();
    String? medicareError = await _validateMedicareNumber(medicareNumber);
    
    if (medicareError != null) {
      setState(() => _medicareNumberError = medicareError);
      _showErrorSnackBar(medicareError);
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user == null) {
          _showErrorSnackBar('Error: User not logged in!');
          setState(() => _isLoading = false);
          return;
        }

        // Format the phone number
        String formattedPhone = ValidationUtils.formatPhoneNumber(_phoneNumberController.text);

        Patient newPatient = Patient(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          medicalCardNumber: _medicalCardController.text.trim(),
          dateOfBirth: _dateOfBirthController.text,
          gender: _selectedGender!,
          phoneNumber: formattedPhone,
        );

        await _firebaseService.savePatient(user.uid, newPatient);

        _showSuccessSnackBar('Patient saved successfully!');

        if (widget.fromMurmurRecord) {
          // If we came from MurmurRecord, pop and return the new patient
          NavigationService.goBackWithResult(newPatient);
        } else {
          // Use replaceTo instead of push to prevent going back to the form
           NavigationService.replaceTo(
    AppRoutes.patientDetails,
    arguments: {'patient': newPatient}, );
        }
      } catch (e) {
        _showErrorSnackBar('Error saving patient: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      // Form validation failed
      _showErrorSnackBar('Please correct the errors in the form.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}