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
    super.key,
    required this.child,
    required this.strategy,
    this.snackBarMessage,
    this.onBackPressed,
    this.doubleTapTimeout = const Duration(seconds: 2),
  });

  @override
  State<BackButtonHandler> createState() => _BackButtonHandlerState();
}

class _BackButtonHandlerState extends State<BackButtonHandler> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    switch (widget.strategy) {
      case BackButtonHandlingStrategy.normal:
        // Allow normal pop behavior.
        return PopScope(
          canPop: true,
          child: widget.child,
        );
      case BackButtonHandlingStrategy.block:
        // Block pop entirely.
        return PopScope(
          canPop: false,
          child: widget.child,
        );
      case BackButtonHandlingStrategy.doubleTapToExit:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            final now = DateTime.now();
            if (_lastBackPressTime == null ||
                now.difference(_lastBackPressTime!) > widget.doubleTapTimeout) {
              _lastBackPressTime = now;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(widget.snackBarMessage ?? 'Press back again to exit'),
                  duration: widget.doubleTapTimeout,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            } else {
              // On the second back tap within the timeout, manually pop the route.
              Navigator.of(context).pop();
            }
          },
          child: widget.child,
        );
      case BackButtonHandlingStrategy.exitApp:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            SystemNavigator.pop(); // Exit the app.
          },
          child: widget.child,
        );
      case BackButtonHandlingStrategy.custom:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            }
          },
          child: widget.child,
        );
    }
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
