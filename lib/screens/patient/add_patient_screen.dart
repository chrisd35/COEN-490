import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../registration/firebase_service.dart';
import '/utils/models.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '/utils/validation_utils.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('AddPatientScreen');

class AddPatientScreen extends StatefulWidget {
  final bool fromMurmurRecord;

  const AddPatientScreen({
    super.key,
    this.fromMurmurRecord = false,
  });
  
  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  // Design Constants
  static final Color primaryColor = const Color(0xFF1D557E);
  static final Color backgroundColor = const Color(0xFFF5F7FA);
  static final Color textPrimaryColor = const Color(0xFF263238);
  static final Color textSecondaryColor = const Color(0xFF546E7A);

  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _medicalCardController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;
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
      labelStyle: GoogleFonts.inter(
        color: textSecondaryColor,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
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
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      errorText: errorText,
      errorStyle: GoogleFonts.inter(color: Colors.red),
    );
  }

  Future<bool> _isMedicareNumberUnique(String medicareNumber) async {
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return true;
      
      final patients = await _firebaseService.getPatientsForUser(uid);
      
      bool isUnique = !patients.any((patient) => 
        patient.medicalCardNumber.replaceAll('/', '_') == 
        medicareNumber.replaceAll('/', '_')
      );
      
      return isUnique;
    } catch (e) {
      _logger.severe('Error checking Medicare number uniqueness: $e');
      return true;
    }
  }

  Future<String?> _validateMedicareNumber(String? value) async {
    String? basicValidation = ValidationUtils.validateMedicareNumber(value);
    if (basicValidation != null) {
      return basicValidation;
    }
    
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
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            'Create New Patient',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: textPrimaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => NavigationService.goBack(),
          ),
        ),
        body: SafeArea(
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
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 24),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      decoration: _buildInputDecoration('Full Name', Icons.person),
                      style: GoogleFonts.inter(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: ValidationUtils.validateName,
                    ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration('Email', Icons.email),
                      style: GoogleFonts.inter(),
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: ValidationUtils.validateEmail,
                    ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
                    const SizedBox(height: 16),

                    // Medical Card with uniqueness check
                    TextFormField(
                      controller: _medicalCardController,
                      decoration: _buildInputDecoration(
                        'Medical Card #', 
                        Icons.health_and_safety,
                        errorText: _medicareNumberError,
                      ),
                      style: GoogleFonts.inter(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (value) {
                        if (_medicareNumberError != null) {
                          setState(() => _medicareNumberError = null);
                        }
                      },
                    ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
                    const SizedBox(height: 16),

                    // Date of Birth
                    GestureDetector(
                      onTap: () async {
                        final initialDate = DateTime.now().subtract(const Duration(days: 365 * 30));
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: primaryColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null && mounted) {
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
                          style: GoogleFonts.inter(),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: ValidationUtils.validateDateOfBirth,
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 400.ms),
                    const SizedBox(height: 16),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration('Gender', Icons.people),
                      style: GoogleFonts.inter(color: textPrimaryColor),
                      value: _selectedGender,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      items: ['Male', 'Female', 'Other'].map((String gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(
                            gender,
                            style: GoogleFonts.inter(),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      validator: (value) => value == null ? 'Gender is required' : null,
                    ).animate().fadeIn(duration: 300.ms, delay: 500.ms),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: _buildInputDecoration('Phone Number', Icons.phone),
                      style: GoogleFonts.inter(),
                      keyboardType: TextInputType.phone,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: ValidationUtils.validatePhoneNumber,
                    ).animate().fadeIn(duration: 300.ms, delay: 600.ms),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ).animate().fadeIn(duration: 300.ms, delay: 700.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    String medicareNumber = _medicalCardController.text.trim();
    String? medicareError = await _validateMedicareNumber(medicareNumber);
    
    if (medicareError != null) {
      if (!mounted) return;
      
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

        if (!mounted) return;
        
        _showSuccessSnackBar('Patient saved successfully!');

        if (widget.fromMurmurRecord) {
          NavigationService.goBackWithResult(newPatient);
        } else {
          NavigationService.replaceTo(
            AppRoutes.patientDetails,
            arguments: {'patient': newPatient},
          );
        }
      } catch (e) {
        _logger.severe('Error saving patient: $e');
        
        if (!mounted) return;
        
        _showErrorSnackBar('Error saving patient: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      _showErrorSnackBar('Please correct the errors in the form.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}