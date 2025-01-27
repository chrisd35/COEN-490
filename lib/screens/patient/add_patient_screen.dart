// add_patient_screen.dart
import 'package:flutter/material.dart';
import '../dashboard/components/patient_card.dart';

class AddPatientScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create New Patient')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Allows scrolling if keyboard is open
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient Info',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),

              // Full Name
              TextField(
                decoration: InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),

              // Email
              TextField(
                decoration: InputDecoration(
                  labelText: 'Medical Card #',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),

              // Phone Number
              TextField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
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
                    // Handle selected date (e.g., save to variable)
                  }
                },
                child: AbsorbPointer(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
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
                items: [
                  DropdownMenuItem(child: Text('Male'), value: 'Male'),
                  DropdownMenuItem(child: Text('Female'), value: 'Female'),
                  DropdownMenuItem(child: Text('Other'), value: 'Other'),
                ],
                onChanged: (value) {
                  // Handle gender selection
                },
              ),
              SizedBox(height: 16),

              // Email
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),

            // Insert documents
            // Insert input here

              // Save Button
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    // Handle save action (e.g., validation, submission)
                    Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PatientCard()),
                  );
                  },
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
