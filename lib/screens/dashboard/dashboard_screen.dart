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
import 'package:logging/logging.dart' as logging;
import 'package:flutter_animate/flutter_animate.dart'; // Add this for animations

final _logger = logging.Logger('DashboardScreen');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _wasConnected = false;
  final FirebaseService _firebaseService = FirebaseService();
  String _userName = '';
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final screenSize = MediaQuery.of(context).size;

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
                      color: Colors.black.withAlpha(13),
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
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideX(begin: -0.2, end: 0),
                    const Spacer(),
                    // Logout Button
                    IconButton(
                      icon: Icon(Icons.logout_rounded, color: Colors.grey[700]),
                      onPressed: () => _showLogoutDialog(),
                    ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
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
                              color: Colors.black.withAlpha(13),
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
                      ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 32),

                      // Welcome Text
                      Text(
                        _userName.isEmpty ? 'Welcome' : 'Hello, $_userName',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 8),
                      Text(
                        'What would you like to do today?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideX(begin: -0.2, end: 0),
                      const SizedBox(height: 32),

                      // Feature Grid based on user type
                      FutureBuilder<bool>(
                        future: Provider.of<AuthService>(context, listen: false).isGuest(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator().animate()
                                .fadeIn(duration: 300.ms)
                                .shimmer(delay: 1000.ms, duration: 1000.ms),
                            );
                          }

                          final isGuest = snapshot.data ?? false;
                          
                          // Responsive layout based on screen width
                          final itemCount = isGuest ? 4 : 7;
                          final crossAxisCount = screenSize.width > 600 ? 3 : 2;
                          
                          // Calculate appropriate aspect ratio
                          final childAspectRatio = screenSize.width > 600 ? 1.3 : 1.1;

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              final cards = isGuest
                                  ? _buildGuestFeatureCards()
                                  : _buildUserFeatureCards();
                              
                              if (index < cards.length) {
                                // Add staggered animations to each card
                                return cards[index]
                                  .animate()
                                  .fadeIn(
                                    duration: 400.ms, 
                                    delay: Duration(milliseconds: 500 + (index * 100))
                                  )
                                  .slideY(begin: 0.2, end: 0);
                              }
                              return const SizedBox.shrink();
                            },
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
      // Learning Center card
      FeatureCard(
        title: 'Learning Center',
        icon: Icons.school,
        color: Colors.amber,
        onTap: () => NavigationService.navigateTo(AppRoutes.learningCenter),
      ),
    ];
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
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'CREATE',
              onPressed: () => NavigationService.navigateTo(AppRoutes.patientCard),
            ),
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildConnectionStatus({required bool isConnected, required String deviceName}) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isConnected ? Colors.green : Colors.red).withOpacity(0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
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
        if (!isConnected)
          TextButton.icon(
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Connect'),
            onPressed: () => NavigationService.navigateTo(AppRoutes.bleScreen),
          ).animate().fadeIn(duration: 300.ms),
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
                children: [
                  const Icon(
                    Icons.bluetooth_disabled_rounded,
                    color: Colors.red,
                    size: 48,
                  ).animate().shake(duration: 700.ms),
                  const SizedBox(height: 16),
                  const Text(
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

class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
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
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
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