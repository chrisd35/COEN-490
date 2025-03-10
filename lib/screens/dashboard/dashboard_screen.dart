import 'package:coen_490/screens/registration/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '../learning/learning_center_initializer_screen.dart';
import '/utils/ble_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '..//registration/firebase_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('DashboardScreen');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

// Changed from private to public state class
class DashboardScreenState extends State<DashboardScreen> {
  bool _wasConnected = false;
  final FirebaseService _firebaseService = FirebaseService();
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh state when the screen becomes visible
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      // Check if in guest mode
      final isGuest = await authService.isGuest();
      
      if (!mounted) return;
      
      if (isGuest) {
        setState(() {
          _userName = 'Guest';
        });
        return;
      }

      if (user != null) {
        final userData = await _firebaseService.getUser(user.uid, user.email ?? '');
        
        if (!mounted) return;
        
        if (userData != null) {
          setState(() {
            _userName = userData.fullName.split(' ')[0];
          });
        }
      }
    } catch (e) {
      _logger.warning('Error loading user name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleManager = Provider.of<BLEManager>(context, listen: true);
    final connectedDevice = bleManager.connectedDevice;

    // Use the BackButtonHandler widget with doubleTapToExit strategy
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.doubleTapToExit,
      snackBarMessage: 'Press back again to exit the app',
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13), // Using withAlpha instead of withOpacity
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Bluetooth Connection Button
                    IconButton(
                      icon: Icon(Icons.bluetooth, color: Theme.of(context).primaryColor),
                      onPressed: () => NavigationService.navigateTo(AppRoutes.bleScreen),
                    ),
                    // Logout Button
                    IconButton(
                      icon: Icon(Icons.logout_rounded, color: Colors.grey[700]),
                      onPressed: () => _showLogoutDialog(),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BLE Connection Status Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13), // Using withAlpha instead of withOpacity
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: connectedDevice != null
                            ? StreamBuilder<BluetoothConnectionState>(
                                stream: bleManager.getDeviceState(connectedDevice),
                                builder: (context, snapshot) {
                                  final isConnected = snapshot.data == BluetoothConnectionState.connected;

                                  if (!isConnected && _wasConnected) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _showDisconnectionDialog();
                                    });
                                    _wasConnected = false;
                                  } else if (isConnected) {
                                    _wasConnected = true;
                                  }

                                  return _buildConnectionStatus(
                                    isConnected: isConnected,
                                    deviceName: connectedDevice.platformName.isEmpty
                                        ? "Unknown Device"
                                        : connectedDevice.platformName,
                                  );
                                },
                              )
                            : _buildConnectionStatus(
                                isConnected: false,
                                deviceName: "No device connected",
                              ),
                      ),
                      const SizedBox(height: 32),

                      // Welcome Text
                      Text(
                        _userName.isEmpty ? 'Welcome' : 'Hello, $_userName',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'What would you like to do today?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Feature Grid based on user type
                      FutureBuilder<bool>(
                        future: Provider.of<AuthService>(context, listen: false).isGuest(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          final isGuest = snapshot.data ?? false;

                         return GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 2,
  mainAxisSpacing: 16,
  crossAxisSpacing: 16,
  childAspectRatio: 1.1,
  children: isGuest 
    ? _buildGuestFeatureCards()
    : _buildUserFeatureCards(),
);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUserFeatureCards() {
  return [
    FeatureCard(
      title: 'Patient Folders',
      icon: Icons.folder_rounded,
      color: Colors.blue,
      onTap: () => NavigationService.navigateTo(AppRoutes.patientCard),
    ),
    FeatureCard(
      title: 'AI Murmur',
      icon: Icons.analytics_rounded,
      color: Colors.purple,
      onTap: () => NavigationService.navigateTo(AppRoutes.murmurChart),
    ),
    FeatureCard(
      title: 'Murmur Record',
      icon: Icons.mic_rounded,
      color: Colors.orange,
      onTap: () => NavigationService.navigateTo(AppRoutes.murmurRecord),
    ),
    FeatureCard(
      title: 'View Recordings',
      icon: Icons.playlist_play,
      color: Colors.teal,
      onTap: () => _handleViewRecordings(),
    ),
    FeatureCard(
      title: 'ECG Monitoring',
      icon: Icons.monitor_heart_outlined,
      color: Colors.green,
      onTap: () => NavigationService.navigateTo(AppRoutes.ecgMonitoring),
    ),
    FeatureCard(
      title: 'Oxygen Monitoring',
      icon: Icons.air,
      color: Colors.blue[700] ?? Colors.blue,
      onTap: () => NavigationService.navigateTo(AppRoutes.oxygenMonitoring),
    ),
    // New Learning Center card
    FeatureCard(
      title: 'Learning Center',
      icon: Icons.school,
      color: Colors.amber,
      onTap: () => NavigationService.navigateTo(AppRoutes.learningCenter),
    ),
    // Placeholder card for future feature
    FeatureCard(
  title: 'Coming Soon',
  icon: Icons.new_releases,
  color: Colors.grey,
  onTap: () {
    // Show standard message to regular users
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Increment tap counter
    _adminTapCount++;
    
    // If secret tap pattern is met (5 taps), show admin dialog
    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _showAdminDialog();
    }
  },
),
  ];
}
int _adminTapCount = 0;

void _showAdminDialog() {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('Admin Access'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter admin password:'),
          const SizedBox(height: 16),
          TextField(
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Password',
            ),
            onSubmitted: (value) {
              // Simple admin password - replace with more secure method in production
              if (value == 'admin123') {
                Navigator.of(dialogContext).pop();
                _initializeDatabase(context);
              } else {
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect password'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

void _initializeDatabase(BuildContext context) {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (loadingContext) => AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text("Initializing database...")
        ],
      ),
    ),
  );
  
  // Create initializer
  final initializer = LearningCenterInitializer(
    context: context,
    showMessage: (message) {
      // Close loading dialog first if it's showing
      Navigator.of(context, rootNavigator: true).pop();
      // Show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message))
      );
    },
    updateProgress: (message, progress) {
      print('$message: $progress'); // You could update a progress indicator here
    },
  );
  
  // Initialize data
  initializer.initializeAllData().then((_) {
    // Make sure dialog is closed when done
    Navigator.of(context, rootNavigator: true).pop();
  }).catchError((error) {
    // Handle errors
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error initializing database: $error"),
        backgroundColor: Colors.red,
      )
    );
  });
}




List<Widget> _buildGuestFeatureCards() {
  return [
    FeatureCard(
      title: 'Murmur Record',
      icon: Icons.mic_rounded,
      color: Colors.orange,
      onTap: () => NavigationService.navigateTo(AppRoutes.murmurRecord),
    ),
    FeatureCard(
      title: 'ECG Monitoring',
      icon: Icons.monitor_heart_outlined,
      color: Colors.green,
      onTap: () => NavigationService.navigateTo(AppRoutes.ecgMonitoring),
    ),
    FeatureCard(
      title: 'Oxygen Monitoring',
      icon: Icons.air,
      color: Colors.blue,
      onTap: () => NavigationService.navigateTo(AppRoutes.oxygenMonitoring),
    ),
    FeatureCard(
      title: 'View Recordings',
      icon: Icons.playlist_play,
      color: Colors.purple,
      onTap: () => _showPlaybackLoginPrompt(),
    ),
    // Removed the Learning Center card - only available for logged-in users
    FeatureCard(
      title: 'Coming Soon',
      icon: Icons.new_releases,
      color: Colors.grey,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This feature is coming soon!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    ),
  ];
}

  // New method to handle view recordings flow with async operations
  Future<void> _handleViewRecordings() async {
    if (!mounted) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final uid = user.uid;
      final patients = await _firebaseService.getPatientsForUser(uid);
      
      if (!mounted) return;
      
      if (patients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Create a patient and save a recording to access playback history'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      NavigationService.navigateTo(AppRoutes.recordingPlayback);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check recordings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildConnectionStatus({required bool isConnected, required String deviceName}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isConnected ? 'Connected to: $deviceName' : deviceName,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showDisconnectionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.bluetooth_disabled_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Connection Lost',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Please reconnect your device to continue monitoring.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Later',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        NavigationService.navigateTo(AppRoutes.bleScreen);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(dialogContext).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final isGuest = await authService.isGuest();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(isGuest ? 'Exit Guest Mode' : 'Logout'),
        content: Text(isGuest 
          ? 'Are you sure you want to exit guest mode?' 
          : 'Are you sure you want to logout?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext); // Close dialog
                if (isGuest) {
                  // Simply navigate back to auth page for guests
                  NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                } else {
                  // Full logout for registered users
                  await authService.logout();
                  NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                }
              } catch (e) {
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Error logging out. Please try again.'),
                    backgroundColor: Colors.red[400],
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isGuest ? 'Exit' : 'Logout'),
          ),
        ],
      ),
    );
  }

  void _showPlaybackLoginPrompt() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Login Required'),
          content: const Text('You need to be logged in to view recorded murmurs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                NavigationService.navigateTo(
                  AppRoutes.login,
                  arguments: {
                    'returnRoute': 'recording_playback',
                    'pendingAction': 'view_recordings',
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }
}

// Changed from private to public class
class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FeatureCard({
    super.key, // Added key parameter
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26), // Using withAlpha instead of withOpacity (0.1)
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}