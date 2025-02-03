import 'package:flutter/material.dart';
import '../dashboard/components/patient_card.dart';
import '../registration/firebase_service.dart'; // Import FirebaseService
import 'patient_model.dart'; // Import Patient model
import 'package:firebase_auth/firebase_auth.dart';

class AddPatientScreen extends StatefulWidget {
  @override
  _AddPatientScreenState createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService(); // Reuse or adapt for patients

  // Controllers for text fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _medicalCardController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedGender;

  @override
  void dispose() {
    // Clean up controllers
    _fullNameController.dispose();
    _emailController.dispose();
    _medicalCardController.dispose();
    _dateOfBirthController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create New Patient')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey, // Add form key
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty) return 'Required';
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Medical Card #
                TextFormField(
                  controller: _medicalCardController,
                  decoration: InputDecoration(
                    labelText: 'Medical Card #',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 16),

                // Date of Birth (with controller update)
                GestureDetector(
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
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
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Gender Dropdown (with validation)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedGender,
                  items: [
                    DropdownMenuItem(child: Text('Male'), value: 'Male'),
                    DropdownMenuItem(child: Text('Female'), value: 'Female'),
                    DropdownMenuItem(child: Text('Other'), value: 'Other'),
                  ],
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
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 16),

                // Save Button
                Center(
                    child: ElevatedButton(
                  onPressed: _submitForm,
                  child: Text('Save'),
                )),
              ],
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
          SnackBar(content: Text('Error: User not logged in!')),
        );
        return;
      }

      // Create a Patient object (define Patient model)
      Patient newPatient = Patient(
        fullName: _fullNameController.text,
        email: _emailController.text,
        medicalCardNumber: _medicalCardController.text,
        dateOfBirth: _dateOfBirthController.text,
        gender: _selectedGender!,
        phoneNumber: _phoneNumberController.text,
      );

      // Save to Firebase (adapt FirebaseService for patients)
      await _firebaseService.savePatient(user.uid, newPatient);

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Patient saved successfully!')),
      );

      // Navigate to PatientCard or Dashboard
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientCard(),
        ),
      );
    }
  }
}
