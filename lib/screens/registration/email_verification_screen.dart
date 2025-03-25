import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../registration/auth_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('EmailVerificationScreen');

class EmailVerificationScreen extends StatefulWidget {
  final String email;

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
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1D557E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App theme colors for consistency
    const Color primaryColor = Color(0xFF1D557E);
    const Color secondaryColor = Color(0xFFE6EDF7);
    const Color textPrimary = Color(0xFF263238);
    const Color textSecondary = Color(0xFF546E7A);
    
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.block,
      child: Scaffold(
        backgroundColor: secondaryColor, // Match other screens background
        appBar: AppBar(
          title: Text(
            'Email Verification',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          automaticallyImplyLeading: false, // Disable back button
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Email Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _isVerified 
                        ? Colors.green.withAlpha(26) 
                        : primaryColor.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isVerified 
                        ? Icons.check_circle 
                        : Icons.mark_email_unread,
                    size: 50,
                    color: _isVerified ? Colors.green : primaryColor,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Text(
                  _isVerified
                      ? 'Email Verified!'
                      : 'Verify Your Email',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  _isVerified
                      ? 'Your email has been successfully verified. Redirecting you to the dashboard...'
                      : 'We\'ve sent a verification email to ${widget.email}. Please check your inbox and click the verification link.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.5,
                    color: textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                if (!_isVerified) ...[
                  Text(
                    'Didn\'t receive the email? Check your spam folder or click below to resend.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Resend button with enhanced styling
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(40),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _canResendEmail ? _resendVerificationEmail : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryColor.withAlpha(153), // 0.6 * 255 = 153
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _canResendEmail
                            ? 'Resend Verification Email'
                            : 'Resend in $_resendCooldown seconds',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  TextButton(
                    onPressed: () {
                      _authService.logout();
                      NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancel and Return to Login',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
                
                if (_isVerified)
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const LinearProgressIndicator(
                      backgroundColor: Color(0xFFD6E1EF),
                      color: Color(0xFF2E86C1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}