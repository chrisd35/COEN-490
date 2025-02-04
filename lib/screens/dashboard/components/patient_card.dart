import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../patient/add_patient_screen.dart';
import '../../patient/patients_details_screen.dart';
import '../../patient/patient_model.dart';

class PatientCard extends StatelessWidget {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Patient Records',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.person_add_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddPatientScreen()),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: StreamBuilder(
                stream: _database
                    .child('users')
                    .child(user?.uid ?? '')
                    .child('patients')
                    .onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                    return _buildEmptyState(context);
                  }

                  Map<dynamic, dynamic> patientsMap = 
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  List<Patient> patients = patientsMap.entries.map((entry) {
                    return Patient.fromMap(Map<String, dynamic>.from(entry.value));
                  }).toList();

                  return _buildPatientsList(context, patients);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading patients...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red[400],
            ),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Patients Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first patient to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPatientScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Add Patient',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsList(BuildContext context, List<Patient> patients) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final patient = patients[index];
        final initials = patient.fullName
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join('');

        return Card(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientDetails(patient: patient),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar with gradient background
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Medical Card: ${patient.medicalCardNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}