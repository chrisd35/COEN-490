import 'package:flutter/material.dart';
import '/utils/models.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import '../screens/registration/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class EditPatientScreen extends StatefulWidget {
  final Patient patient;

  const EditPatientScreen({super.key, required this.patient});

  @override
  State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  
  late TextEditingController _nameController;
  late TextEditingController _medicalCardController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late String _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient.fullName);
    _medicalCardController = TextEditingController(text: widget.patient.medicalCardNumber);
    _dateOfBirthController = TextEditingController(text: widget.patient.dateOfBirth);
    _phoneController = TextEditingController(text: widget.patient.phoneNumber);
    _emailController = TextEditingController(text: widget.patient.email);
    _selectedGender = widget.patient.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicalCardController.dispose();
    _dateOfBirthController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updatePatient() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          throw Exception('User not authenticated');
        }

        // Create updated patient object
        final updatedPatient = Patient(
          fullName: _nameController.text.trim(),
          medicalCardNumber: widget.patient.medicalCardNumber, // Keep original ID
          dateOfBirth: _dateOfBirthController.text.trim(),
          gender: _selectedGender,
          phoneNumber: _phoneController.text.trim(),
          email: _emailController.text.trim(),
        );

        // Update patient in Firebase
        await _firebaseService.updatePatient(uid, updatedPatient);

        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to previous screen with updated patient data
        NavigationService.goBackWithResult(updatedPatient);
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating patient: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Patient'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => NavigationService.goBack(),
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Patient details form fields
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter patient name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      
                      // Medical Card Number (read-only)
                      TextFormField(
                        controller: _medicalCardController,
                        decoration: InputDecoration(
                          labelText: 'Medical Card Number',
                          border: OutlineInputBorder(),
                          helperText: 'Medical card number cannot be changed',
                        ),
                        readOnly: true,
                        enabled: false,
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _dateOfBirthController,
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          border: OutlineInputBorder(),
                          hintText: 'YYYY-MM-DD',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter date of birth';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      
                      // Gender Selection
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Male', 'Female', 'Other']
                            .map((gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select gender';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 24),
                      
                      ElevatedButton(
                        onPressed: _updatePatient,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Update Patient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}