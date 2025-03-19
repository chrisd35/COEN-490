import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/ble_manager.dart';  
import 'screens/registration/auth_service.dart';  
import 'utils/navigation_service.dart';
import 'utils/app_routes.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('Main');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure logging
  _configureLogging();
  
  _logger.info('Starting application');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  _logger.info('Firebase initialized');
  
  runApp(
    MultiProvider(
      providers: [
        // Provide the BLEManager instance
        ChangeNotifierProvider<BLEManager>(
          create: (_) => BLEManager(),
        ),
        // Update to ChangeNotifierProvider for AuthService
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
  
  _logger.info('Application started');
}

/// Configure the logging system
void _configureLogging() {
  // Set the logging level
  logging.Logger.root.level = logging.Level.ALL;
  
  // Listen to log messages and print them
  logging.Logger.root.onRecord.listen((record) {
    // Format: [LEVEL] LOGGER_NAME: MESSAGE
    print('[${record.level.name}] ${record.loggerName}: ${record.message}');
    
    // If there's an error object, print it too
    if (record.error != null) {
      print('Error: ${record.error}');
    }
    
    // If there's a stack trace, print it too
    if (record.stackTrace != null) {
      print('Stack trace:\n${record.stackTrace}');
    }
  });
  
  _logger.info('Logging configured');
}

class MyApp extends StatelessWidget {
  // Add key parameter using super
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    _logger.fine('Building MyApp widget');
    
    return MaterialApp(
      title: 'RespiRhythm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      // Add the navigator key from NavigationService
      navigatorKey: NavigationService.navigatorKey,
      
      // Set the initial route
      initialRoute: AppRoutes.auth,
      
      // Define the routes
      routes: AppRoutes.routes,
      
      // Route generator for routes with parameters
      onGenerateRoute: AppRoutes.onGenerateRoute,
      
      // Handle unknown routes
      onUnknownRoute: AppRoutes.onUnknownRoute,
      
      // Add navigation observer for debugging
      navigatorObservers: [
        _NavigationHistoryObserver(),
      ],
    );
  }
}

/// Navigation observer to track route changes
class _NavigationHistoryObserver extends NavigatorObserver {
  final _navLogger = logging.Logger('Navigation');
  
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _navLogger.info('Pushed ${route.settings.name} (from ${previousRoute?.settings.name})');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _navLogger.info('Popped ${route.settings.name} (back to ${previousRoute?.settings.name})');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _navLogger.info('Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _navLogger.info('Removed ${route.settings.name}');
    super.didRemove(route, previousRoute);
  }
}