// patients_details_screen.dart
import 'package:flutter/material.dart';
import '../patient/add_patient_screen.dart';
import '../monitoring/ecg_monitoring_screen.dart';
import '../monitoring/oxygen_monitoring_screen.dart';
import '../dashboard/components/murmur_record.dart';


class PatientDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Insert "Full Name"')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medical History Button
            //   ElevatedButton(
            //     onPressed: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) =>
            //               PatientCard(), // Leads to patient folders component
            //         ),
            //       );
            //     },
            //     child: Text('Medical History'),
            //   ),
            //   SizedBox(height: 20),

              // ECG Monitoring Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ECGMonitoring(), // Leads to AI murmur component
                    ),
                  );
                },
                child: Text('ECG Monitoring'),
              ),
              SizedBox(height: 20),

              // Oxygen Monitoring Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OxygenMonitoring(), // Leads to murmur recording component
                    ),
                  );
                },
                child: Text('Oxygen Monitoring'),
              ),
              SizedBox(height: 20),

                // Murmur Analysis Monitoring Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MurmurRecord(), // Leads to AI murmur component
                    ),
                  );
                },
                child: Text('Murmur Analysis'),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
