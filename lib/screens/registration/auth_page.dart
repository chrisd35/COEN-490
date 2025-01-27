// auth_page.dart
import 'package:flutter/material.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'package:coen_490/screens/dashboard/dashboard_screen.dart';

class AuthPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/homepage.jpg'),
                fit: BoxFit.cover, // This will cover the whole screen
                alignment: Alignment.topCenter,
                scale: 0.5,
              ),
            ),
          ),
          // Content Layer
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Spacer(),
                  Text(
                    'RespiRhythm',
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Adjust text color for visibility
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text('Login'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterPage()),
                      );
                    },
                    child: Text('Sign Up'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DashboardScreen()),
                      );
                    },
                    child: Text('Continue as a Guest'),
                  ),
                  SizedBox(height: 40), // Added more bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
