import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import 'firebase_service.dart'; // Import FirebaseService
import 'user_model.dart'; // Import User model
import 'auth_service.dart'; 
class AccountProfilePage extends StatefulWidget {
  final String? selectedRole; // Add selectedRole as a parameter

  AccountProfilePage({this.selectedRole}); // Constructor to accept selectedRole

  @override
  _AccountProfilePageState createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  final _authService = AuthService();

  // Controllers for text fields
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  String? _selectedGender;
  String? _selectedRole; // Add selectedRole variable
  final _phoneNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill the role if passed from RegisterPage
    _selectedRole = widget.selectedRole;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Account Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),

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
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value!.isEmpty) return 'Required';
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
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

                // Gender
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

                // Role
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedRole, // Pre-fill with selectedRole
                  items: [
                    DropdownMenuItem(
                      child: Text('Medical Professional'),
                      value: 'Medical Professional',
                    ),
                    DropdownMenuItem(
                      child: Text('Student'),
                      value: 'Student',
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: InputDecoration(
                    labelText: 'Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 20),

                // Save Button
                Center(
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    child: Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Register the user with Firebase Authentication
      final user = await _authService.register(email, password);

      if (user != null) {
        // Create a User object
        User newUser = User(
          fullName: _fullNameController.text,
          email: email,
          password: password,
          dateOfBirth: _dateOfBirthController.text,
          gender: _selectedGender!,
          role: _selectedRole!,
          phoneNumber: _phoneNumberController.text,
        );

        // Save the user to Firebase Realtime Database
        await _firebaseService.saveUser(newUser);

        // Clear the form
        _formKey.currentState!.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User registered successfully!')),
        );

        // Navigate to the DashboardScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed. Please try again.')),
        );
      }
    }
  }
}