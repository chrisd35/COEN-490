import 'package:flutter/material.dart';
import '../monitoring/ecg_monitoring_screen.dart';
import '../monitoring/oxygen_monitoring_screen.dart';
import '../dashboard/components/murmur_record.dart';
import './patient_model.dart';

class PatientDetails extends StatelessWidget {
  final Patient patient;

  const PatientDetails({Key? key, required this.patient}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(patient.fullName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildInfoRow('Medical Card', patient.medicalCardNumber),
                      _buildInfoRow('Date of Birth', patient.dateOfBirth),
                      _buildInfoRow('Gender', patient.gender),
                      _buildInfoRow('Phone', patient.phoneNumber),
                      _buildInfoRow('Email', patient.email),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Monitoring Buttons
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ECGMonitoring()),
                ),
                child: Text('ECG Monitoring'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OxygenMonitoring()),
                ),
                child: Text('Oxygen Monitoring'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MurmurRecord()),
                ),
                child: Text('Murmur Analysis'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
