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
      appBar: AppBar(
        title: Text('Patient Card'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPatientScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Folders',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: StreamBuilder(
                stream: _database
                    .child('users')
                    .child(user?.uid ?? '')
                    .child('patients')
                    .onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                    return Center(
                      child: Text('No patients found. Add your first patient!'),
                    );
                  }

                  Map<dynamic, dynamic> patientsMap = 
                      snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  List<Patient> patients = patientsMap.entries.map((entry) {
                    return Patient.fromMap(Map<String, dynamic>.from(entry.value));
                  }).toList();

                  return ListView.builder(
                    itemCount: patients.length,
                    itemBuilder: (context, index) {
                      final patient = patients[index];

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(patient.fullName[0].toUpperCase()),
                          ),
                          title: Text(patient.fullName),
                          subtitle: Text('Medical Card: ${patient.medicalCardNumber}'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PatientDetails(patient: patient),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}