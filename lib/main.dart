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
final _logger = logging.Logger('Navigation');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
}

class MyApp extends StatelessWidget {
  // Add key parameter using super
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
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
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.info('Pushed ${route.settings.name} (from ${previousRoute?.settings.name})');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.info('Popped ${route.settings.name} (back to ${previousRoute?.settings.name})');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logger.info('Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.info('Removed ${route.settings.name}');
    super.didRemove(route, previousRoute);
  }
}