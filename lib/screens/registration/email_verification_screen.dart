import 'dart:async';
import 'package:flutter/material.dart';
import '../registration/auth_service.dart';
import '../dashboard/dashboard_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();
  bool _isVerified = false;
  bool _canResendEmail = true;
  Timer? _timer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Start checking for verification status
    _checkEmailVerified();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    // Check immediately once
    await _checkVerificationStatus();

    // Then check every 3 seconds
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) async {
        await _checkVerificationStatus();
      },
    );
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final isVerified = await _authService.isEmailVerified();
      
      if (mounted) {
        setState(() {
          _isVerified = isVerified;
        });
      }

      if (isVerified) {
        _timer?.cancel();
        // Navigate to dashboard after verification
        Future.delayed(Duration(seconds: 2), () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen()),
            (route) => false,
          );
        });
      }
    } catch (e) {
      print('Error checking verification status: $e');
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    setState(() {
      _canResendEmail = false;
      _resendCooldown = 60; // 60 second cooldown
    });

    try {
      await _authService.sendEmailVerification();
      _showSnackBar('Verification email sent to ${widget.email}');
      
      // Start cooldown timer
      _cooldownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (_resendCooldown > 0) {
            setState(() {
              _resendCooldown--;
            });
          } else {
            setState(() {
              _canResendEmail = true;
            });
            timer.cancel();
          }
        },
      );
    } catch (e) {
      setState(() {
        _canResendEmail = true;
      });
      _showSnackBar('Failed to send verification email. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Verification'),
        automaticallyImplyLeading: false, // Disable back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _isVerified ? Icons.check_circle : Icons.mark_email_unread,
              size: 80,
              color: _isVerified ? Colors.green : Theme.of(context).primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              _isVerified
                  ? 'Email Verified!'
                  : 'Verify Your Email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              _isVerified
                  ? 'Your email has been successfully verified. Redirecting you to the dashboard...'
                  : 'We\'ve sent a verification email to ${widget.email}. Please check your inbox and click the verification link.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            if (!_isVerified) ...[
              Text(
                'Didn\'t receive the email? Check your spam folder or click below to resend.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _canResendEmail ? _resendVerificationEmail : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _canResendEmail
                      ? 'Resend Verification Email'
                      : 'Resend in $_resendCooldown seconds',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _authService.logout();
                  Navigator.of(context).pop();
                },
                child: Text('Cancel and Return to Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}