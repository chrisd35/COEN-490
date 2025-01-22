// dashboard_screen.dart
import 'package:flutter/material.dart';
import 'components/patient_card.dart';
import 'components/murmur_chart.dart';
import 'components/murmur_record.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Hello "Insert First Name"',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Patient Folders Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PatientCard(), // Leads to patient folders component
                    ),
                  );
                },
                child: Text('Patient Folders'),
              ),
              SizedBox(height: 20),

              // AI Murmur Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MurmurChart(), // Leads to AI murmur component
                    ),
                  );
                },
                child: Text('AI Murmur'),
              ),
              SizedBox(height: 20),

              // Murmur Recording Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MurmurRecord(), // Leads to murmur recording component
                    ),
                  );
                },
                child: Text('Murmur Record'),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
