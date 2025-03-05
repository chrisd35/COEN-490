import 'package:coen_490/screens/registration/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import '/utils/ble_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '..//registration/firebase_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      
      if (isGuest) {
        setState(() {
          _userName = 'Guest';
        });
        return;
      }

      if (user != null) {
        final userData = await _firebaseService.getUser(user.uid, user.email ?? '');
        if (userData != null) {
          setState(() {
            _userName = userData.fullName.split(' ')[0];
          });
        }
      }
    } catch (e) {
      print('Error loading user name: $e');
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
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
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BLE Connection Status Card
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
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
                                    deviceName: connectedDevice.name.isEmpty
                                        ? "Unknown Device"
                                        : connectedDevice.name,
                                  );
                                },
                              )
                            : _buildConnectionStatus(
                                isConnected: false,
                                deviceName: "No device connected",
                              ),
                      ),
                      SizedBox(height: 32),

                      // Welcome Text
                      Text(
                        _userName.isEmpty ? 'Welcome' : 'Hello, $_userName',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'What would you like to do today?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 32),

                      // Feature Grid based on user type
                      FutureBuilder<bool>(
                        future: Provider.of<AuthService>(context, listen: false).isGuest(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          }

                          final isGuest = snapshot.data ?? false;

                          return GridView.count(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
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

  // Build feature cards for guest users
  List<Widget> _buildGuestFeatureCards() {
    return [
      _FeatureCard(
        title: 'Murmur Record',
        icon: Icons.mic_rounded,
        color: Colors.orange,
        onTap: () => NavigationService.navigateTo(AppRoutes.murmurRecord),
      ),
      _FeatureCard(
        title: 'ECG Monitoring',
        icon: Icons.monitor_heart_outlined,
        color: Colors.green,
        onTap: () => NavigationService.navigateTo(AppRoutes.ecgMonitoring),
      ),
      _FeatureCard(
        title: 'Oxygen Monitoring',
        icon: Icons.air,
        color: Colors.blue,
        onTap: () => NavigationService.navigateTo(AppRoutes.oxygenMonitoring),
      ),
      _FeatureCard(
        title: 'View Recordings',
        icon: Icons.playlist_play,
        color: Colors.purple,
        onTap: () => _showPlaybackLoginPrompt(),
      ),
    ];
  }

  // Build feature cards for registered users
  List<Widget> _buildUserFeatureCards() {
    return [
      _FeatureCard(
        title: 'Patient Folders',
        icon: Icons.folder_rounded,
        color: Colors.blue,
        onTap: () => NavigationService.navigateTo(AppRoutes.patientCard),
      ),
      _FeatureCard(
        title: 'AI Murmur',
        icon: Icons.analytics_rounded,
        color: Colors.purple,
        onTap: () => NavigationService.navigateTo(AppRoutes.murmurChart),
      ),
      _FeatureCard(
        title: 'Murmur Record',
        icon: Icons.mic_rounded,
        color: Colors.orange,
        onTap: () => NavigationService.navigateTo(AppRoutes.murmurRecord),
      ),
      _FeatureCard(
        title: 'View Recordings',
        icon: Icons.playlist_play,
        color: Colors.teal,
        onTap: () async {
          try {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final patients = await _firebaseService.getPatientsForUser(uid);
            
            if (patients.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Create a patient and save a recording to access playback history'),
                  duration: Duration(seconds: 4),
                ),
              );
              return;
            }
            
            NavigationService.navigateTo(AppRoutes.recordingPlayback);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to check recordings: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
      _FeatureCard(
        title: 'ECG Monitoring',
        icon: Icons.monitor_heart_outlined,
        color: Colors.green,
        onTap: () => NavigationService.navigateTo(AppRoutes.ecgMonitoring),
      ),
      _FeatureCard(
        title: 'Oxygen Monitoring',
        icon: Icons.air,
        color: Colors.blue[700] ?? Colors.blue,
        onTap: () => NavigationService.navigateTo(AppRoutes.oxygenMonitoring),
      ),
    ];
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
        SizedBox(width: 12),
        Expanded(
          child: Text(
            isConnected ? 'Connected to: $deviceName' : deviceName,
            style: TextStyle(
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
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
            Padding(
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
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Later',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        NavigationService.navigateTo(AppRoutes.bleScreen);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
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

  void _showLogoutDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isGuest = await authService.isGuest();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context); // Close dialog
                if (isGuest) {
                  // Simply navigate back to auth page for guests
                  NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                } else {
                  // Full logout for registered users
                  await authService.logout();
                  NavigationService.navigateToAndRemoveUntil(AppRoutes.auth);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error logging out. Please try again.'),
                    backgroundColor: Colors.red[400],
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Login Required'),
          content: Text('You need to be logged in to view recorded murmurs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                NavigationService.navigateTo(
                  AppRoutes.login,
                  arguments: {
                    'returnRoute': 'recording_playback',
                    'pendingAction': 'view_recordings',
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Login'),
            ),
          ],
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
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