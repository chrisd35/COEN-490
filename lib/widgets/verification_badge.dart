import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final VoidCallback? onTapResend;

  const VerificationBadge({
    Key? key,
    required this.isVerified,
    this.onTapResend,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified 
            ? Colors.green.withOpacity(0.1) 
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_user : Icons.warning_amber_rounded,
            size: 16,
            color: isVerified ? Colors.green : Colors.orange,
          ),
          SizedBox(width: 6),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isVerified ? Colors.green : Colors.orange,
            ),
          ),
          if (!isVerified && onTapResend != null) ...[
            SizedBox(width: 8),
            GestureDetector(
              onTap: onTapResend,
              child: Text(
                'Resend',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}