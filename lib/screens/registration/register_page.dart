import 'package:flutter/material.dart';
import 'auth_service.dart'; // Import AuthService
import 'account_profile_page.dart'; // Import AccountProfilePage

class RegisterPage extends StatelessWidget {
  final _authService = AuthService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Choose Your Role',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Register as Medical Professional Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountProfilePage(selectedRole: 'Medical Professional'),
                    ),
                  );
                },
                child: Text('Register as Medical Professional'),
              ),
              SizedBox(height: 10),

              // Register as Student Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountProfilePage(selectedRole: 'Student'),
                    ),
                  );
                },
                child: Text('Register as Student'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}