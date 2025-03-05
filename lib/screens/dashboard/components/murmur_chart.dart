// account_profile_page.dart
import 'package:flutter/material.dart';

class MurmurChart extends StatelessWidget {
  // Add key parameter using super
  const MurmurChart({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Murmur Detection')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Allows scrolling if keyboard is open
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Murmur Findings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}