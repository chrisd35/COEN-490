import 'dart:async';
import 'package:flutter/material.dart';
import '../registration/auth_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('EmailVerificationScreen');

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  // Use super parameter syntax for key
  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
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
        // Check if widget is still mounted before using a delayed function
        if (!mounted) return;
        
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          NavigationService.navigateToAndRemoveUntil(AppRoutes.dashboard);
        });
      }
    } catch (e) {
      _logger.severe('Error checking verification status: $e');
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
      
      if (!mounted) return;
      
      _showSnackBar('Verification email sent to ${widget.email}');
      
      // Start cooldown timer
      _cooldownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          
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
      _logger.severe('Error sending verification email: $e');
      
      if (!mounted) return;
      
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
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.block,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Email Verification'),
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
              const SizedBox(height: 24),
              Text(
                _isVerified
                    ? 'Email Verified!'
                    : 'Verify Your Email',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 32),
              if (!_isVerified) ...[
                Text(
                  'Didn\'t receive the email? Check your spam folder or click below to resend.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _canResendEmail ? _resendVerificationEmail : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _canResendEmail
                        ? 'Resend Verification Email'
                        : 'Resend in $_resendCooldown seconds',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _authService.logout();
                    NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                  },
                  child: const Text('Cancel and Return to Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}