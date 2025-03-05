import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that handles back button presses with various strategies.
class BackButtonHandler extends StatefulWidget {
  final Widget child;
  final BackButtonHandlingStrategy strategy;
  final String? snackBarMessage;
  final VoidCallback? onBackPressed;
  final Duration doubleTapTimeout;

  const BackButtonHandler({
    Key? key,
    required this.child,
    required this.strategy,
    this.snackBarMessage,
    this.onBackPressed,
    this.doubleTapTimeout = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  _BackButtonHandlerState createState() => _BackButtonHandlerState();
}

class _BackButtonHandlerState extends State<BackButtonHandler> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        switch (widget.strategy) {
          case BackButtonHandlingStrategy.block:
            // Simply block back navigation
            return false;
            
          case BackButtonHandlingStrategy.doubleTapToExit:
            final now = DateTime.now();
            if (_lastBackPressTime == null || 
                now.difference(_lastBackPressTime!) > widget.doubleTapTimeout) {
              _lastBackPressTime = now;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(widget.snackBarMessage ?? 'Press back again to exit'),
                  duration: widget.doubleTapTimeout,
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
              return false;
            }
            return true;
            
          case BackButtonHandlingStrategy.exitApp:
            SystemNavigator.pop(); // Exit the app
            return false;
            
          case BackButtonHandlingStrategy.custom:
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            }
            return false;
            
          case BackButtonHandlingStrategy.normal:
          default:
            // Default behavior, allow pop
            return true;
        }
      },
      child: widget.child,
    );
  }
}

/// Strategies for handling back button presses
enum BackButtonHandlingStrategy {
  /// Allow normal back navigation
  normal,
  
  /// Block back navigation completely
  block,
  
  /// Require double tap to exit, with snackbar feedback
  doubleTapToExit,
  
  /// Exit the application
  exitApp,
  
  /// Execute custom code
  custom,
}