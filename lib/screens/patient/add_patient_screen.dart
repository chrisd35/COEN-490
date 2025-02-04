import 'package:flutter/material.dart';
import '../dashboard/components/patient_card.dart';
import '../registration/firebase_service.dart';
import 'patient_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPatientScreen extends StatefulWidget {
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _medicalCardController.dispose();
    _dateOfBirthController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, IconData? icon) {
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
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: _buildInputDecoration('Email', Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) return 'Required';
                        if (!value.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Medical Card
                    TextFormField(
                      controller: _medicalCardController,
                      decoration: _buildInputDecoration('Medical Card #', Icons.health_and_safety),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 16),

                    // Date of Birth
                    GestureDetector(
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
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
                          validator: (value) => value!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      decoration: _buildInputDecoration('Gender', Icons.people),
                      value: _selectedGender,
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
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: _buildInputDecoration('Phone Number', Icons.phone),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
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
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: User not logged in!'),
            backgroundColor: Colors.red[400],
          ),
        );
        return;
      }

      Patient newPatient = Patient(
        fullName: _fullNameController.text,
        email: _emailController.text,
        medicalCardNumber: _medicalCardController.text,
        dateOfBirth: _dateOfBirthController.text,
        gender: _selectedGender!,
        phoneNumber: _phoneNumberController.text,
      );

      await _firebaseService.savePatient(user.uid, newPatient);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient saved successfully!'),
          backgroundColor: Colors.green[400],
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientCard(),
        ),
      );
    }
  }
}