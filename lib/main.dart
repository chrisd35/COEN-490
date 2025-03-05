import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/ble_manager.dart';  
import 'screens/registration/auth_service.dart';  
import 'utils/navigation_service.dart';
import 'utils/app_routes.dart';

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
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RespiRhythm',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Poppins',
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
            ),
            padding: EdgeInsets.symmetric(vertical: 16),
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
    print('NAVIGATION: Pushed ${route.settings.name} (from ${previousRoute?.settings.name})');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('NAVIGATION: Popped ${route.settings.name} (back to ${previousRoute?.settings.name})');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    print('NAVIGATION: Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('NAVIGATION: Removed ${route.settings.name}');
    super.didRemove(route, previousRoute);
  }
}