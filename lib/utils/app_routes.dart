import 'package:flutter/material.dart';
import 'package:coen_490/screens/dashboard/dashboard_screen.dart';
import 'package:coen_490/screens/registration/auth_page.dart';
import 'package:coen_490/screens/registration/login_page.dart';
import 'package:coen_490/screens/registration/register_page.dart';
import 'package:coen_490/screens/registration/email_verification_screen.dart';
import 'package:coen_490/screens/dashboard/components/murmur_record.dart';
import 'package:coen_490/screens/dashboard/components/murmur_playback.dart';
import 'package:coen_490/screens/dashboard/components/patient_card.dart';
import 'package:coen_490/screens/dashboard/components/murmur_chart.dart';
import 'package:coen_490/screens/dashboard/ble_screen.dart';
import 'package:coen_490/screens/monitoring/ecg_monitoring_screen.dart';
import 'package:coen_490/screens/monitoring/oxygen_monitoring_screen.dart';
import 'package:coen_490/screens/monitoring/ecg_history.dart';
import 'package:coen_490/screens/monitoring/ecg_viewer.dart';
import 'package:coen_490/screens/monitoring/pusleox_history.dart';
import 'package:coen_490/screens/patient/add_patient_screen.dart';
import 'package:coen_490/screens/patient/patients_details_screen.dart';
import 'package:coen_490/utils/ble_manager.dart';

/// Class that defines all routes in the application
class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String auth = '/auth';
  static const String login = '/login';
  static const String register = '/register';
  static const String emailVerification = '/email-verification';
  static const String dashboard = '/dashboard';
  static const String murmurRecord = '/murmur-record';
  static const String recordingPlayback = '/recording-playback';
  static const String patientCard = '/patient-card';
  static const String murmurChart = '/murmur-chart';
  static const String bleScreen = '/ble-screen';
  static const String ecgMonitoring = '/ecg-monitoring';
  static const String oxygenMonitoring = '/oxygen-monitoring';
  static const String ecgHistory = '/ecg-history';
  static const String ecgViewer = '/ecg-viewer';
  static const String pulseOxHistory = '/pulse-ox-history';
  static const String addPatient = '/add-patient';
  static const String patientDetails = '/patient-details';
  
  // Route map
  static Map<String, WidgetBuilder> routes = {
    auth: (context) => AuthPage(),
    login: (context) => LoginPage(),
    register: (context) => RegisterPage(),
    dashboard: (context) => DashboardScreen(),
    patientCard: (context) => PatientCard(),
    murmurChart: (context) => MurmurChart(),
    bleScreen: (context) => BLEScreen(),
    addPatient: (context) => AddPatientScreen(),
  };
  
  // Route generator for routes with parameters
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case emailVerification:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            email: args?['email'] ?? '',
          ),
        );
        
      case murmurRecord:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => MurmurRecord(
            preselectedPatientId: args?['preselectedPatientId'],
          ),
        );
        
      case recordingPlayback:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => RecordingPlaybackScreen(
            preselectedPatientId: args?['preselectedPatientId'],
          ),
        );
        
      case addPatient:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => AddPatientScreen(
            fromMurmurRecord: args?['fromMurmurRecord'] ?? false,
          ),
        );
        
      case patientDetails:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args?['patient'] == null) return null;
        return MaterialPageRoute(
          builder: (context) => PatientDetails(
            patient: args!['patient'],
          ),
        );
        
      case ecgMonitoring:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => ECGMonitoring(
            bleManager: BLEManager(),
            preselectedPatientId: args?['preselectedPatientId'],
          ),
        );
        
      case oxygenMonitoring:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => OxygenMonitoring(
            preselectedPatientId: args?['preselectedPatientId'],
          ),
        );
        
      case ecgHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => ECGHistory(
            preselectedPatientId: args?['preselectedPatientId'],
          ),
        );
        
      case ecgViewer:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args?['reading'] == null) return null;
        return MaterialPageRoute(
          builder: (context) => ECGViewer(
            reading: args!['reading'],
            patientName: args['patientName'] ?? 'Unknown Patient',
          ),
        );
        
      case pulseOxHistory:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (context) => PulseOxHistory(
            preselectedPatientId: args?['preselectedPatientId'],
          ),
        );
        
      default:
        return null;
    }
  }
  
  // Unknown route fallback
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text('Not Found')),
        body: Center(
          child: Text('The requested page was not found.'),
        ),
      ),
    );
  }
}