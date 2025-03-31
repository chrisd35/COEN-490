import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:coen_490/screens/registration/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '/utils/ble_manager.dart';
import '../../registration/firebase_service.dart';
import '/utils/models.dart';
import '../../../utils/navigation_service.dart';
import '../../../utils/app_routes.dart';
import '../../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('MurmurRecord');

// Design constants to maintain consistency throughout the app
class AppTheme {
  // Main color palette - refining the blue scheme
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors - refined for better contrast
  static const Color successColor = Color(0xFF2E7D32); // Darker green
  static const Color warningColor = Color(0xFFF57F17); // Amber shade
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red
  
  // Text colors - improved for readability
  static const Color textPrimary = Color(0xFF263238);   // Darker for better contrast
  static const Color textSecondary = Color(0xFF546E7A); // Medium dark for subtext
  static const Color textLight = Color(0xFF78909C);     // Light text for tertiary info
  
  // Shadows - refined for better depth perception
  static final cardShadow = BoxShadow(
    color: Colors.black.withAlpha(18),  
    blurRadius: 12,
    spreadRadius: 0,
    offset: const Offset(0, 3),
  );
  
  static final subtleShadow = BoxShadow(
    color: Colors.black.withAlpha(10), 
    blurRadius: 6,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  );
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
}

class MurmurRecord extends StatefulWidget {
  final String? preselectedPatientId;

  const MurmurRecord({
    super.key,
    this.preselectedPatientId,
  });

  @override
  State<MurmurRecord> createState() => MurmurRecordState();
}
class MurmurRecordState extends State<MurmurRecord> with SingleTickerProviderStateMixin {
  // Animation controller for recording indicator
  late AnimationController _animationController;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRecording = false;
  bool _hasRecordingCompleted = false;
  bool _isPlaying = false;
  bool _cameFromPatientDetails = false;
  List<int>? _recordedAudioData;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  double _playbackVolume = 1.0;
  
  // UI display settings
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cameFromPatientDetails = widget.preselectedPatientId != null;
    _setupAudioPlayer();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen(_onPlayerStateChanged);
    _audioPlayer.onPlayerComplete.listen(_onPlayerCompleteListener);
  }

  // Define these helper methods at class level
  void _onPlayerStateChanged(PlayerState state) {
    if (mounted) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    }
  }

  void _onPlayerCompleteListener(_) {
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  @override
  void dispose() {
    // Cancel timer first
    _recordingTimer?.cancel();
    
    // Stop audio playback when navigating away
    if (_isPlaying) {
      _audioPlayer.stop();
    }
    
    // Dispose of animation controller
    _animationController.dispose();
    
    // Dispose of the audio player
    _audioPlayer.dispose();
    super.dispose();
  }
  // Add a new method to handle the back button press
 Future<void> _handleBackButton() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
    
    // If we came from patient details, just go back
    if (_cameFromPatientDetails) {
      NavigationService.goBack();
      return;
    }
    
    // Otherwise, use the original login logic for guests
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final isGuest = await authService.isGuest();
    
    if (!mounted) return;
    
    if (!isGuest) {
      // If logged in, go to dashboard
      NavigationService.navigateToAndRemoveUntil(AppRoutes.dashboard);
    } else {
      // If guest, just go back
      NavigationService.goBack();
    }
  }
 
  Future<void> _showLoadingDialog(String message) async {
    if (!mounted) return;
    
    // Use a barrierDismissible: false to prevent accidental dismissal
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button from dismissing
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(width: 20),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).catchError((error) {
      _logger.warning("Error in _showLoadingDialog: $error");
      return null;
    });
  }

  // Add this helper method to show info snackbars
  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showLoginPrompt() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Login Required',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'You need to be logged in to save recordings. Do you have an account?',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                NavigationService.navigateTo(
                  AppRoutes.login,
                  arguments: {
                    'returnRoute': 'murmur_record',
                    'pendingAction': 'save_recording',
                  },
                ).then((value) {
                  if (value == true && mounted) {
                    // User has successfully logged in, show save dialog again
                    _showSaveRecordingDialog();
                  }
                });
              },
              child: Text(
                'Yes, I have an account',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                NavigationService.navigateTo(
                  AppRoutes.register,
                  arguments: {
                    'returnRoute': 'murmur_record',
                    'pendingAction': 'save_recording',
                  },
                ).then((value) {
                  if (value == true && mounted) {
                    // User has successfully registered, show save dialog again
                    _showSaveRecordingDialog();
                  }
                });
              },
              child: Text(
                'Create New Account',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
 void _startRecording() async {
    if (!mounted) return;
    
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    if (bleManager.connectedDevice != null) {
      try {
        await bleManager.startRecording();
        
        if (!mounted) return;
        
        setState(() {
          _isRecording = true;
          _hasRecordingCompleted = false;
          _recordingDuration = Duration.zero;
        });

        // Animate the recording button
        _animationController.repeat(reverse: true);
        
        // Use a more precise timer
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (mounted) {
            setState(() {
              // Round to nearest second for display
              int totalMs = timer.tick * 100;
              _recordingDuration = Duration(milliseconds: totalMs);
            });
          } else {
            // Cancel timer if widget is no longer mounted
            timer.cancel();
          }
        });
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar("Failed to start recording: $e");
        }
      }
    } else {
      if (mounted) {
        _showErrorSnackBar("No device connected");
      }
    }
  }

  void _stopRecording() async {
  try {
    _recordingTimer?.cancel();
    _animationController.stop();

    setState(() {
      _isProcessing = true;
    });

    final bleManager = Provider.of<BLEManager>(context, listen: false);
    final result = await bleManager.stopRecording();
    List<int> rawAudio = result['audioData'];

    if (mounted) {
      setState(() {
        _isRecording = false;
        _hasRecordingCompleted = true;
        _recordedAudioData = rawAudio;
        _isProcessing = false;
      });
      
      _showSuccessSnackBar("Recording completed successfully");
    }
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar("Error processing recording: $e");
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
    }
  }
}
  
  Future<void> _playPreviewRecording() async {
    if (_recordedAudioData == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        // Get a copy of the audio data
        List<int> audioDataCopy = List.from(_recordedAudioData!);
        
        // Apply enhanced amplification that targets heartbeats
        List<int> enhancedAudio = _firebaseService.enhanceHeartbeatWithAmplification(
          audioDataCopy,
          sampleRate: BLEManager.sampleRate,
          threshold: 0.03,
          beatGain: 3000.0,
          overallGain: 5.0,
          noiseSuppression: 0.001,
          shiftFrequencies: false,
          frequencyShift: 1.5
        );
        
        // Create WAV with enhanced audio
        final wavData = _firebaseService.createRawWavFile(
          enhancedAudio,
          sampleRate: BLEManager.sampleRate,
          bitsPerSample: 16,
          channels: 1
        );

        // Play the enhanced audio
        await _audioPlayer.play(
          BytesSource(Uint8List.fromList(wavData)),
        );
        
        // Set volume
        await _audioPlayer.setVolume(_playbackVolume);
        
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
          
          _showInfoSnackBar("Playing recording");
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Failed to play recording: $e");
      }
    }
  }
  // Simplified save recording dialog
  void _showSaveRecordingDialog() async {
    _logger.info("Starting save recording dialog flow");
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.getCurrentUser() == null) {
      _showLoginPrompt();
      return;
    }

    final String uid = authService.getCurrentUser()!.uid;
    
    // If we have a preselected patient, save directly to that patient
    if (widget.preselectedPatientId != null) {
      _saveRecordingToPatient(uid, widget.preselectedPatientId!);
      return;
    }

    // Use a flag to track if loading dialog is shown
    bool isLoadingDialogShown = false;
    BuildContext? dialogContext;
    
    try {
      // Show loading while fetching patients
      if (!mounted) return;
      
      _logger.info("Showing loading dialog before fetching patients");
      
      // Show a loading indicator directly in the current context
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          dialogContext = context; // Store the dialog context for later use
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Row(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    "Loading patients...",
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      isLoadingDialogShown = true;

      // Fetch patients list
      _logger.info("Fetching patients for user: $uid");
      List<Patient> patients = [];
      
      try {
        patients = await _firebaseService.getPatientsForUser(uid);
      } catch (e) {
        _logger.severe("Error fetching patients: $e");
        
        // Dismiss loading dialog if shown and we've stored the context
        if (isLoadingDialogShown && dialogContext != null && mounted) {
          Navigator.of(dialogContext!).pop();
          isLoadingDialogShown = false;
        }
        
        if (mounted) {
          _showErrorSnackBar("Failed to load patients: $e");
        }
        return;
      }
      
      // Check if widget is still mounted before proceeding
      if (!mounted) {
        _logger.warning("Widget unmounted after fetching patients");
        return;
      }
      
      // Dismiss loading dialog using the stored context
      if (isLoadingDialogShown && dialogContext != null && mounted) {
        _logger.info("Dismissing loading dialog after fetching patients");
        Navigator.of(dialogContext!).pop();
        isLoadingDialogShown = false;
      }
      
      // Early return if unmounted after dialog dismissal
      if (!mounted) {
        _logger.warning("Widget unmounted after dismissing loading dialog");
        return;
      }

      // Handle empty patients list
      if (patients.isEmpty) {
        _logger.info("No patients found, showing create patient dialog");
        _showNoPatientDialog();
        return;
      }
      
      if (!mounted) return;
      
      // Show the patient selection dialog
      _logger.info("Showing patient selection options dialog");
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Save Recording',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.person_add, color: AppTheme.primaryColor),
                  title: Text(
                    'Create New Patient',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreatePatient();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.people, color: AppTheme.primaryColor),
                  title: Text(
                    'Select Existing Patient',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showPatientSelectionDialog(uid, patients);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Log the error
      _logger.severe("Error in _showSaveRecordingDialog: $e");
      
      // Make sure to dismiss loading dialog if it's showing
      if (isLoadingDialogShown && dialogContext != null && mounted) {
        try {
          _logger.info("Dismissing loading dialog after error");
          Navigator.of(dialogContext!).pop();
        } catch (dialogError) {
          _logger.warning("Error dismissing loading dialog: $dialogError");
        }
      }
      
      // Check if still mounted before showing error
      if (!mounted) return;
      
      _showErrorSnackBar("Failed to load patients: $e");
    }
  }

  void _navigateToCreatePatient() {
    if (!mounted) return;
    
    NavigationService.navigateTo(
      AppRoutes.addPatient,
      arguments: {'fromMurmurRecord': true},
    ).then((newPatient) {
      if (!mounted) return;
      if (newPatient != null) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final uid = authService.getCurrentUser()!.uid;
        _saveRecordingToPatient(uid, newPatient.medicalCardNumber);
      }
    });
  }

  void _showPatientSelectionDialog(String uid, List<Patient> patients) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Select Patient',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300, // Fixed height for scrollable list
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      patient.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Medical Card: ${patient.medicalCardNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _saveRecordingToPatient(uid, patient.medicalCardNumber);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showNoPatientDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'No Patients Found',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Text(
            'Would you like to create a new patient?',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text(
                'Create Patient',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                if (mounted) { // Check if still mounted
                  _navigateToCreatePatient();
                }
              },
            ),
          ],
        );
      },
    );
  }
  // Simplified save recording to patient method
  Future<void> _saveRecordingToPatient(String uid, String patientId) async {
    if (_recordedAudioData == null || !mounted) {
      _logger.warning("Save aborted: recordedAudioData is null or widget not mounted");
      return;
    }
    
    _logger.info("--- START SAVE RECORDING PROCESS ---");
    _logger.info("UID: $uid, Patient ID: $patientId");
    _logger.info("Raw audio data size: ${_recordedAudioData!.length} bytes");
    
    // Get data before showing dialog
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    final roundedDuration = ((_recordingDuration.inMilliseconds + 500) / 1000).floor();
    _logger.info("Recording duration: $roundedDuration seconds");
    
    // Get a copy of the audio data
    _logger.info("Creating copy of audio data...");
    List<int> audioDataCopy = List.from(_recordedAudioData!);
    _logger.info("Audio data copied successfully, size: ${audioDataCopy.length} bytes");
    
    // Apply the same enhancement that's used for playback
    _logger.info("Starting audio enhancement...");
    List<int> enhancedAudio;
    try {
      enhancedAudio = _firebaseService.enhanceHeartbeatWithAmplification(
        audioDataCopy,
        sampleRate: BLEManager.sampleRate,
        threshold: 0.03,
        beatGain: 3000.0,
        overallGain: 5.0,
        noiseSuppression: 0.001,
        shiftFrequencies: false,
        frequencyShift: 1.5
      );
      _logger.info("Enhancement complete, enhanced size: ${enhancedAudio.length} bytes");
    } catch (e) {
      _logger.severe("Audio enhancement failed: $e");
      if (mounted) {
        _showErrorSnackBar("Failed to enhance audio: $e");
      }
      return;
    }
    
    if (enhancedAudio.isEmpty) {
      _logger.severe("Enhanced audio is empty!");
      if (mounted) {
        _showErrorSnackBar("Error: Enhanced audio processing failed");
      }
      return;
    }
    
    if (!mounted) {
      _logger.warning("Widget unmounted after enhancement");
      return;
    }
    
    // Flag to track loading dialog state
    bool isLoadingDialogShown = false;
    BuildContext? dialogContext;
    
    try {
      // Show loading dialog
      _logger.info("Showing loading dialog...");
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            dialogContext = context; // Store dialog context
            return WillPopScope(
              onWillPop: () async => false, // Prevent back button from dismissing
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      "Saving recording...",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        isLoadingDialogShown = true;
        _logger.info("Loading dialog shown successfully");
      }
    } catch (e) {
      _logger.severe("Failed to show loading dialog: $e");
      // Continue anyway
    }
    
    // Check if still mounted after dialog is shown
    if (!mounted) {
      _logger.warning("Widget unmounted after showing dialog");
      return;
    }

    try {
      _logger.info("Calling FirebaseService.saveRecording...");
      await _firebaseService.saveRecording(
        uid,
        patientId,
        DateTime.now(),
        enhancedAudio,
        {
          'duration': roundedDuration,
          'sampleRate': BLEManager.sampleRate, 
          'bitsPerSample': BLEManager.bitsPerSample,
          'channels': BLEManager.channels,
          'peakAmplitude': bleManager.peakAmplitude,
          'processingApplied': true,
          'processingDetails': 'heartbeat-amplification',
          'amplificationSettings': {
            'threshold': 0.03,
            'beatGain': 3000.0,
            'overallGain': 5.0,
            'noiseSuppression': 0.001,
            'frequencyShift': 1.5
          },
          'signalToNoiseRatio': bleManager.signalToNoiseRatio,
        },
      );
      _logger.info("saveRecording completed successfully");

      // Check if still mounted before proceeding
      if (!mounted) {
        _logger.warning("Widget unmounted after saving recording");
        return;
      }
      
      // Close loading dialog using the stored context
      if (isLoadingDialogShown && dialogContext != null && mounted) {
        _logger.info("Attempting to close loading dialog...");
        try {
          Navigator.of(dialogContext!).pop();
          _logger.info("Loading dialog closed successfully");
        } catch (e) {
          _logger.warning("Failed to close dialog: $e");
        }
        isLoadingDialogShown = false;
      }
      
      if (!mounted) return;
      
      _showSuccessSnackBar("Recording saved successfully");
      _logger.info("Success message shown, resetting state...");
      
      if (!mounted) return;
      
      setState(() {
        _hasRecordingCompleted = false;
        _recordedAudioData = null;
      });
      _logger.info("--- SAVE RECORDING COMPLETED SUCCESSFULLY ---");
    } catch (e) {
      // Log the error for debugging
      _logger.severe("❌ Save recording error: $e");
      _logger.severe(e.toString());
      if (e is Error) {
        _logger.severe("Stack trace: ${e.stackTrace}");
      }
      
      // Check if still mounted before using context
      if (!mounted) {
        _logger.warning("Widget unmounted during error handling");
        return;
      }
      
      // Always try to dismiss the dialog using the stored context
      if (isLoadingDialogShown && dialogContext != null && mounted) {
        _logger.info("Attempting to close loading dialog after error...");
        try {
          Navigator.of(dialogContext!).pop();
          _logger.info("Loading dialog closed after error");
        } catch (dialogError) {
          _logger.warning("Failed to close dialog after error: $dialogError");
        }
        isLoadingDialogShown = false;
      }
      
      if (!mounted) return;
      _showErrorSnackBar("Failed to save recording: $e");
      _logger.info("--- SAVE RECORDING FAILED ---");
    }
  }
  
  // Audio analysis helper functions
  String _getSampleRange() {
    if (_recordedAudioData == null || _recordedAudioData!.isEmpty) return "N/A";
    
    ByteData byteData = ByteData(_recordedAudioData!.length);
    for (int i = 0; i < _recordedAudioData!.length; i++) {
      byteData.setUint8(i, _recordedAudioData![i]);
    }
    
    int min = 32767;
    int max = -32768;
    
    for (int i = 0; i < _recordedAudioData!.length; i += 2) {
      if (i + 1 < _recordedAudioData!.length) {
        int sample = byteData.getInt16(i, Endian.little);
        if (sample < min) min = sample;
        if (sample > max) max = sample;
      }
    }
    
    return "$min to $max";
  }

  double _calculateMean() {
    if (_recordedAudioData == null || _recordedAudioData!.isEmpty) return 0.0;
    
    ByteData byteData = ByteData(_recordedAudioData!.length);
    for (int i = 0; i < _recordedAudioData!.length; i++) {
      byteData.setUint8(i, _recordedAudioData![i]);
    }
    
    double sum = 0.0;
    int count = 0;
    
    for (int i = 0; i < _recordedAudioData!.length; i += 2) {
      if (i + 1 < _recordedAudioData!.length) {
        int sample = byteData.getInt16(i, Endian.little);
        sum += sample;
        count++;
      }
    }
    
    return count > 0 ? sum / count : 0.0;
  }

  double _calculateDCOffset() {
    return _calculateMean(); // DC offset is the mean value
  }

  double _calculateSignalVariation() {
    if (_recordedAudioData == null || _recordedAudioData!.isEmpty) return 0.0;
    
    ByteData byteData = ByteData(_recordedAudioData!.length);
    for (int i = 0; i < _recordedAudioData!.length; i++) {
      byteData.setUint8(i, _recordedAudioData![i]);
    }
    
    double mean = _calculateMean();
    double sumSquaredDiffs = 0.0;
    int count = 0;
    
    for (int i = 0; i < _recordedAudioData!.length; i += 2) {
      if (i + 1 < _recordedAudioData!.length) {
        int sample = byteData.getInt16(i, Endian.little);
        double diff = sample - mean;
        sumSquaredDiffs += diff * diff;
        count++;
      }
    }
    
    return count > 0 ? math.sqrt(sumSquaredDiffs / count) : 0.0;
  }
 Widget _buildWaveform(BuildContext context, BLEManager bleManager) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.secondaryColor,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: bleManager.recentAmplitudes.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withAlpha(26),
              ),
            ),
          ],
          minY: 0,
          maxY: 1,
        ),
      ),
    );
  }

  Widget _buildRecordingStatus() {
    return Column(
      children: [
        Text(
          _recordingDuration.toString().split('.').first,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMurmurVisualization() {
    if (!_hasRecordingCompleted || _recordedAudioData == null || _recordedAudioData!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Extract raw audio samples for visualization
    List<int> rawSamples = [];
    ByteData byteData = ByteData(_recordedAudioData!.length);
    for (int i = 0; i < _recordedAudioData!.length; i++) {
      byteData.setUint8(i, _recordedAudioData![i]);
    }
    
    // Start at 100 samples in to avoid any header data
    int startOffset = 100;
    
    // Take samples for visualization (max 2000 points)
    int samplesCount = (_recordedAudioData!.length - startOffset) ~/ 2;
    int step = samplesCount > 2000 ? samplesCount ~/ 2000 : 1;
    
    // Debug the sample range to see actual values
    List<int> sampleMinMax = [32767, -32768]; // [min, max]
    
    for (int i = 0; i < samplesCount; i++) {
      int offset = startOffset + (i * 2);
      if (offset + 1 < _recordedAudioData!.length) {
        int sampleInt = byteData.getInt16(offset, Endian.little);
        rawSamples.add(sampleInt);
        
        // Track min/max for debug
        if (sampleInt < sampleMinMax[0]) sampleMinMax[0] = sampleInt;
        if (sampleInt > sampleMinMax[1]) sampleMinMax[1] = sampleInt;
      }
    }
    
    // Print debug info
    _logger.info("Waveform debug: Sample range [${sampleMinMax[0]}, ${sampleMinMax[1]}]");
    _logger.info("Waveform debug: First 10 raw samples: ${rawSamples.take(10).toList()}");
    
    // Calculate DC offset (average value)
    double sum = 0;
    for (int sample in rawSamples) {
      sum += sample;
    }
    double dcOffset = sum / rawSamples.length;
    
    // Build raw, DC corrected, and heart sound emphasized waveforms
    List<FlSpot> rawWaveformSpots = [];
    List<FlSpot> correctedWaveformSpots = [];
    List<FlSpot> emphasizedWaveformSpots = [];
    
    // Sampling for display
    int displayStep = rawSamples.length > 300 ? rawSamples.length ~/ 300 : 1;
    
    // Calculate min/max after DC removal for proper scaling
    double minCentered = 0;
    double maxCentered = 0;
    
    List<double> centeredSamples = [];
    for (int i = 0; i < rawSamples.length; i++) {
      double centered = rawSamples[i] - dcOffset;
      centeredSamples.add(centered);
      
      if (centered < minCentered) minCentered = centered;
      if (centered > maxCentered) maxCentered = centered;
    }
    
    // Apply a simple bandpass filter to emphasize heart sounds (can be improved with FFT)
    List<double> emphasizedSamples = List.from(centeredSamples);
    for (int i = 2; i < emphasizedSamples.length - 2; i++) {
      // Simple 5-point weighted average acts like a band-pass filter
      emphasizedSamples[i] = 
          (centeredSamples[i-2] * -0.05 +
           centeredSamples[i-1] * 0.1 + 
           centeredSamples[i] * 0.7 + 
           centeredSamples[i+1] * 0.1 + 
           centeredSamples[i+2] * -0.05) * 2.0; // Amplify by 2x
    }
    
    // Manual abs function
    double absMin = minCentered < 0 ? -minCentered : minCentered;
    double absMax = maxCentered < 0 ? -maxCentered : maxCentered;
    // Manual max function
    double maxAbsValue = absMin > absMax ? absMin : absMax;
    
    // Create display spots
    for (int i = 0; i < rawSamples.length; i += displayStep) {
      // Original raw samples
      double normalizedRaw = rawSamples[i] / 32768.0;
      rawWaveformSpots.add(FlSpot(i.toDouble(), normalizedRaw));
      
      // DC offset corrected samples
      double yVal = centeredSamples[i] / maxAbsValue;
      yVal = yVal.clamp(-1.0, 1.0);
      correctedWaveformSpots.add(FlSpot(i.toDouble(), yVal));
      
      // Emphasized heart sound samples
      double emphasizedY = emphasizedSamples[i] / maxAbsValue;
      emphasizedY = emphasizedY.clamp(-1.0, 1.0);
      emphasizedWaveformSpots.add(FlSpot(i.toDouble(), emphasizedY));
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Raw Waveform",
              style: GoogleFonts.inter(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            "Sample range: ${sampleMinMax[0]} to ${sampleMinMax[1]}, DC offset: ${dcOffset.toStringAsFixed(1)}",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: rawWaveformSpots,
                    isCurved: false,
                    color: Colors.grey[700],
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: -1,
                maxY: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "DC Offset Corrected Waveform",
              style: GoogleFonts.inter(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            "Shows heart sound patterns after removing DC offset",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: correctedWaveformSpots,
                    isCurved: false,
                    color: AppTheme.primaryColor,
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: -1,
                maxY: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Heart Sound Enhanced",
              style: GoogleFonts.inter(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            "Filtered for more prominent heart sounds",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: emphasizedWaveformSpots,
                    isCurved: false,
                    color: Colors.red[700],
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: -1,
                maxY: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "The sine wave pattern shows your heartbeat.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMainContent() {
    if (_isRecording) {
      return _buildRecordingContent();
    } else if (_hasRecordingCompleted) {
      return _buildRecordingCompleteContent();
    } else {
      return _buildInitialContent();
    }
  }

  Widget _buildRecordingContent() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.errorColor.withAlpha(26),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.errorColor.withAlpha(
                        (_animationController.value * 150 + 105).toInt()
                      ),
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 24),
          Text(
            "Recording heart sounds...",
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCompleteContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.successColor.withAlpha(26),
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: AppTheme.successColor,
              size: 60,
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 16),
          Text(
            "Recording completed!",
            style: GoogleFonts.inter(
              fontSize: 18,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Would you like to save this recording?",
            style: GoogleFonts.inter(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_down, color: AppTheme.primaryColor),
                    Expanded(
                      child: Slider(
                        value: _playbackVolume,
                        min: 0.1,
                        max: 1.0,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() {
                            _playbackVolume = value;
                          });
                          if (_isPlaying) {
                            _audioPlayer.setVolume(_playbackVolume);
                          }
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                    Icon(Icons.volume_up, color: AppTheme.primaryColor),
                  ],
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () => _playPreviewRecording(),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  
          const SizedBox(height: 24),
          // Add visualization
          _buildMurmurVisualization(),
        ],
      ),
    );
  }

  Widget _buildInitialContent() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity, // Take full width of parent
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // Center children horizontally
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withAlpha(26),
            ),
            child: Icon(
              Icons.mic_none,
              color: AppTheme.primaryColor,
              size: 48,
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Tap the button below to start recording heart sounds",
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Make sure the stethoscope is placed properly",
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.preselectedPatientId != null 
                ? "Record Heart Sounds"
                : "Heart Sound Recorder",
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () {
              _handleBackButton();
            },
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Waveform and Recording Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Consumer<BLEManager>(
                      builder: (context, bleManager, child) {
                        return Column(
                          children: [
                            _buildWaveform(context, bleManager).animate().fadeIn(duration: 500.ms),
                            const SizedBox(height: 16),
                            _buildRecordingStatus().animate().fadeIn(duration: 500.ms, delay: 200.ms),
                          ],
                        );
                      },
                    ),
                  ),
                  
                  // Main Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _buildMainContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black.withAlpha(40),
                  child: Center(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Processing...',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_isRecording) {
      return FloatingActionButton.extended(
        onPressed: _stopRecording,
        backgroundColor: AppTheme.errorColor,
        label: Text(
          "Stop Recording",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.stop, color: Colors.white),
        elevation: 2,
      ).animate().fadeIn(duration: 300.ms);
    } else if (_hasRecordingCompleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              // Stop audio if playing
              if (_isPlaying) {
                _audioPlayer.stop();
              }
              setState(() {
                _hasRecordingCompleted = false;
                _recordedAudioData = null;
                _isPlaying = false;
              });
            },
            backgroundColor: AppTheme.errorColor,
            label: Text(
              "Discard",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            icon: const Icon(Icons.delete, color: Colors.white),
            heroTag: null,
            elevation: 2,
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _showSaveRecordingDialog,
            backgroundColor: AppTheme.successColor,
            label: Text(
              "Save Recording",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            heroTag: null,
            elevation: 2,
          ),
        ],
      ).animate().fadeIn(duration: 300.ms);
    } else {
      return FloatingActionButton.extended(
        onPressed: _startRecording,
        backgroundColor: AppTheme.primaryColor,
        label: Text(
          "Start Recording",
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.mic, color: Colors.white),
        elevation: 2,
      ).animate().fadeIn(duration: 300.ms);
    }
  }
}