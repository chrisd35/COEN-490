import 'package:coen_490/utils/editpatientscreen.dart';
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
// Import learning center screens
import 'package:coen_490/screens/learning/learning_center_screen.dart';
import 'package:coen_490/screens/learning/learning_topic_screen.dart';
import 'package:coen_490/screens/learning/heart_murmur_library_screen.dart';
import 'package:coen_490/screens/learning/heart_murmur_detail_screen.dart';
import 'package:coen_490/screens/learning/quiz_list_screen.dart';
import 'package:coen_490/screens/learning/quiz_screen.dart';
import 'package:coen_490/screens/learning/quiz_result_screen.dart';
import 'package:coen_490/screens/learning/user_progress_screen.dart';

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
  
  // Learning center routes
  static const String learningCenter = '/learning-center';
  static const String learningTopic = '/learning-topic';
  static const String heartMurmurLibrary = '/heart-murmur-library';
  static const String heartMurmurDetail = '/heart-murmur-detail';
  static const String quizList = '/quiz-list';
  static const String quiz = '/quiz';
  static const String quizResult = '/quiz-result';
  static const String userProgress = '/user-progress';
   static const String editPatient = '/edit-patient';

  
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
    // Learning center routes
    learningCenter: (context) => LearningCenterScreen(),
    heartMurmurLibrary: (context) => HeartMurmurLibraryScreen(),
    quizList: (context) => QuizListScreen(),
    userProgress: (context) => UserProgressScreen(),
    
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
  if (args == null || args['reading'] == null) {
    // Instead of returning null, show an error screen
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Error: Invalid ECG reading data was provided.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
  
  // If we have valid args, proceed normally
  return MaterialPageRoute(
    builder: (context) => ECGViewer(
      reading: args['reading'],
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
        
      // Learning center routes with parameters
      case learningTopic:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args?['topic'] == null) return null;
        return MaterialPageRoute(
          builder: (context) => LearningTopicScreen(
            topic: args!['topic'],
          ),
        );

         case editPatient:
    final args = settings.arguments as Map<String, dynamic>?;
    if (args?['patient'] == null) return null;
    return MaterialPageRoute(
      builder: (context) => EditPatientScreen(
        patient: args!['patient'],
      ),
    );
        
      case heartMurmurDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args?['murmur'] == null) return null;
        return MaterialPageRoute(
          builder: (context) => HeartMurmurDetailScreen(
            murmur: args!['murmur'],
          ),
        );
        
      case quiz:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args?['quiz'] == null) return null;
        return MaterialPageRoute(
          builder: (context) => QuizScreen(
            quiz: args!['quiz'],
          ),
        );
        
case quizResult:
  final args = settings.arguments as Map<String, dynamic>?;
  if (args?['result'] == null || args?['quiz'] == null || 
      args?['questions'] == null || args?['userAnswers'] == null) {
    return null;
  }
  return MaterialPageRoute(
    builder: (context) => QuizResultScreen(
      quiz: args!['quiz'],
      result: args['result'],
      questions: args['questions'],
      userAnswers: args['userAnswers'],
      isTimeUp: args['isTimeUp'] ?? false,
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