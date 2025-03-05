import 'package:flutter/material.dart';

/// A service that manages navigation throughout the app.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static NavigatorState? get navigator => navigatorKey.currentState;
  
  /// Navigate to a named route
  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }
  
  /// Replace the current route with a new one
  static Future<dynamic> replaceTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
  }
  
  /// Navigate to a route and clear all previous routes
  static Future<dynamic> navigateToAndRemoveUntil(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName, 
      (_) => false, // Remove all previous routes
      arguments: arguments
    );
  }
  
  /// Go back to the previous route
  static void goBack() {
    return navigatorKey.currentState!.pop();
  }
  
  /// Go back with a result
  static void goBackWithResult(dynamic result) {
    return navigatorKey.currentState!.pop(result);
  }
  
  /// Check if we can go back
  static bool canGoBack() {
    return navigatorKey.currentState!.canPop();
  }
  
  /// Pop until a specific route
  static void popUntil(String routeName) {
    navigatorKey.currentState!.popUntil(RouteName(routeName) as RoutePredicate);
  }
}

/// Helper class to check route names
class RouteName extends Route<dynamic> {
  final String name;
  
  RouteName(this.name);
  
  @override
  bool operator ==(Object other) {
    if (other is Route) {
      return other.settings.name == name;
    }
    return false;
  }
  
  @override
  int get hashCode => name.hashCode;
  
  @override
  RouteSettings get settings => RouteSettings(name: name);
  
  @override
  bool get opaque => false;
  
  @override
  bool get maintainState => false;
  
  @override
  Duration get transitionDuration => Duration.zero;
  
  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    throw UnimplementedError();
  }
  
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    throw UnimplementedError();
  }
}