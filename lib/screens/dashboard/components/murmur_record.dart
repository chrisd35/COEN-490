import 'dart:async';
import 'dart:typed_data';
import 'package:coen_490/screens/registration/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '/utils/ble_manager.dart';
import '../../registration/firebase_service.dart';
import '/utils/models.dart';
import '../../../utils/navigation_service.dart';
import '../../../utils/app_routes.dart';
import '../../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;


final _logger = logging.Logger('MurmurRecord');

class MurmurRecord extends StatefulWidget {
  final String? preselectedPatientId;

  const MurmurRecord({
    super.key,
    this.preselectedPatientId,
  });

  @override
  State<MurmurRecord> createState() => MurmurRecordState();
}

// Changed from private to public state class
class MurmurRecordState extends State<MurmurRecord> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRecording = false;
  bool _hasRecordingCompleted = false;
  bool _isPlaying = false;
  bool _cameFromPatientDetails = false;
  List<int>? _recordedAudioData;
  // Removed _bufferSize as it wasn't being used
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

bool _isProcessing = false;
Map<String, dynamic>? _recordingData;
String _recordingQuality = 'unknown';
  
// UI enhancement variables
String _recordingMessage = '';
Color _recordingStatusColor = Colors.grey;
double _recordingProgress = 0.0;
late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _cameFromPatientDetails = widget.preselectedPatientId != null;
    _setupAudioPlayer();
    _setupAnimations(); 
  }

  void _setupAnimations() {
  _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);
}

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
      });
    });
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
  
 void _startRecording() async {
  if (!mounted) return;
  
  final bleManager = Provider.of<BLEManager>(context, listen: false);
  if (bleManager.connectedDevice != null) {
    try {
      setState(() {
        _isRecording = true;
        _hasRecordingCompleted = false;
        _recordingDuration = Duration.zero;
        _recordingMessage = 'Initializing...';
        _recordingStatusColor = Colors.blue;
        _recordingProgress = 0.0;
        _recordingQuality = 'unknown';
      });
      
      await bleManager.startRecording();
      
      if (!mounted) return;
      
      setState(() {
        _recordingMessage = 'Listening for heartbeats...';
      });

      // Use a precise timer for updating duration and quality display
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (mounted) {
          final int totalMs = timer.tick * 100;
          
          setState(() {
            _recordingDuration = Duration(milliseconds: totalMs);
            _recordingProgress = _recordingDuration.inMilliseconds / 3000.0; // 3 sec recording
            
            // Get recording quality from BLEManager
            final quality = bleManager.recordingQuality;
            if (quality != _recordingQuality) {
              _recordingQuality = quality;
              
              // Update UI based on quality
              switch (_recordingQuality) {
                case 'excellent':
                  _recordingStatusColor = Colors.green;
                  _recordingMessage = 'Heart Sounds Detected!';
                  break;
                case 'good':
                  _recordingStatusColor = Colors.green.shade300;
                  _recordingMessage = 'Heartbeat Signal Detected';
                  break;
                case 'fair':
                  _recordingStatusColor = Colors.orange;
                  _recordingMessage = 'Weak Heartbeat Signal';
                  break;
                case 'poor':
                  _recordingStatusColor = Colors.red;
                  _recordingMessage = 'No Clear Heartbeat - Adjust Position';
                  break;
                case 'initializing':
                  _recordingStatusColor = Colors.blue;
                  _recordingMessage = 'Analyzing Heartbeat Signal...';
                  break;
                default:
                  _recordingStatusColor = Colors.grey;
                  _recordingMessage = 'Listening for Heartbeats...';
              }
            }
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

  void _startBufferSizeMonitoring() {
    Stream.periodic(const Duration(milliseconds: 100)).listen((_) {
      if (_isRecording && mounted) {
        setState(() {
          // We're just monitoring buffer state, no need to store it in a field
        });
      }
    });
  }

  void _stopRecording() async {
  setState(() {
    _isProcessing = true;
    _recordingMessage = 'Processing audio...';
  });
  
  final bleManager = Provider.of<BLEManager>(context, listen: false);
  try {
    _recordingTimer?.cancel();

    // Get processed audio data and metadata from BLEManager
    Map<String, dynamic> recordingData = await bleManager.stopRecording();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _hasRecordingCompleted = true;
        _recordingData = recordingData;
        _recordingQuality = recordingData['metadata']['recordingQuality'] ?? 'unknown';
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isRecording = false;
      });
      _showErrorSnackBar("Failed to stop recording: $e");
    }
  }
}
  
 Future<void> _playPreviewRecording() async {
  if (_recordingData == null || _recordingData!['audioData'] == null) return;

  try {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Show a processing indicator
      setState(() {
        _isProcessing = true;
      });

      // Get the raw audio data
      final audioData = List<int>.from(_recordingData!['audioData']);
      
      // Process audio using the Python-like algorithm
      final bleManager = Provider.of<BLEManager>(context, listen: false);
      
      // Process with Python-style algorithm
      final processedAudio = bleManager.processHeartbeatAudio(audioData);
      
      // Add sonification to make heartbeats more obvious
      final sonifiedAudio = bleManager.sonifyHeartbeats(processedAudio);
      
      // Create WAV file from the enhanced audio
      final wavData = _firebaseService.createWavFile(
        sonifiedAudio,
        sampleRate: BLEManager.sampleRate,
        bitsPerSample: BLEManager.bitsPerSample,
        channels: BLEManager.channels,
      );

      // Done processing
      setState(() {
        _isProcessing = false;
      });

      // Play the processed audio
      await _audioPlayer.play(
        BytesSource(Uint8List.fromList(wavData)),
      );
      
      setState(() {
        _isPlaying = true;
      });
    }
  } catch (e) {
    setState(() {
      _isProcessing = false;
    });
    _showErrorSnackBar("Failed to play recording: $e");
  }
}

  void _showSaveRecordingDialog() async {
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

    // Show loading while fetching patients
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Early return if widget is unmounted after dialog
    if (!mounted) return;

    try {
      // Fetch patients list
      List<Patient> patients = await _firebaseService.getPatientsForUser(uid);
      
      // Check if widget is still mounted before proceeding
      if (!mounted) return;
      
      // Close the loading dialog
      Navigator.of(context).pop();
      
      // Check if widget is still mounted after closing dialog
      if (!mounted) return;

      if (patients.isEmpty) {
        _showNoPatientDialog();
        return;
      }
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (dialogContext) { // Use dialogContext to avoid context references
          return AlertDialog(
            title: const Text('Save Recording'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Create New Patient'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _navigateToCreatePatient();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Select Existing Patient'),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showPatientSelectionDialog(uid, patients);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Check if widget is still mounted before using context
      if (!mounted) return;
      
      // Try to dismiss the loading dialog if it's still showing
      try {
        Navigator.of(context).pop();
      } catch (_) {
        // Dialog may have been dismissed already, ignore errors
      }
      
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
          title: const Text('Select Patient'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300, // Fixed height for scrollable list
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                return ListTile(
                  title: Text(patient.fullName),
                  subtitle: Text('Medical Card: ${patient.medicalCardNumber}'),
                  onTap: () {
                    Navigator.pop(context);
                    _saveRecordingToPatient(uid, patient.medicalCardNumber);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
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
      builder: (BuildContext dialogContext) { // Use dialogContext instead of context
        return AlertDialog(
          title: const Text('No Patients Found'),
          content: const Text('Would you like to create a new patient?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: const Text('Create Patient'),
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

  Future<void> _saveRecordingToPatient(String uid, String patientId) async {
  if (_recordingData == null || !mounted) return;
  
  // Extract recording data and metadata
  final audioData = List<int>.from(_recordingData!['audioData']);
  final metadata = Map<String, dynamic>.from(_recordingData!['metadata']);
  
  if (!mounted) return;
  
  // Show loading dialog
  await _showLoadingDialog("Saving recording...");
  
  if (!mounted) return;

  try {
    await _firebaseService.saveRecording(
      uid,
      patientId,
      DateTime.now(),
      audioData,
      metadata,
    );

    if (!mounted) return;
    
    // Close loading dialog
    try {
      Navigator.of(context).pop();
    } catch (_) {
      // Dialog may have been dismissed already, ignore errors
    }
    
    if (!mounted) return;
    
    _showSuccessSnackBar("Recording saved successfully");
    
    if (!mounted) return;
    
    setState(() {
      _hasRecordingCompleted = false;
      _recordingData = null;
    });
  } catch (e) {
    if (!mounted) return;
    
    // Try to dismiss the dialog
    try {
      Navigator.of(context).pop();
    } catch (_) {
      // Dialog may have been dismissed already, ignore errors
    }
    
    if (!mounted) return;
    _showErrorSnackBar("Failed to save recording: $e");
  }
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
          title: const Text('Login Required'),
          content: const Text('You need to be logged in to save recordings. Do you have an account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
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
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Create New Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLoadingDialog(String message) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

@override
void dispose() {
  // Stop audio playback when navigating away
  if (_isPlaying) {
    _audioPlayer.stop();
  }
  _audioPlayer.dispose();
  _recordingTimer?.cancel();
  _pulseController.dispose(); // Add this line
  super.dispose();
}

  Widget _buildWaveform(BuildContext context, BLEManager bleManager) {
  Color waveColor = _recordingStatusColor;
  
  return SizedBox(
    height: 120,
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
            color: waveColor,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: waveColor.withAlpha(26),
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
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
      const SizedBox(height: 8),
      Consumer<BLEManager>(
        builder: (context, bleManager, child) {
          String qualityText = '';
          switch (_recordingQuality) {
            case 'excellent':
              qualityText = 'Excellent Quality';
              break;
            case 'good':
              qualityText = 'Good Quality';
              break;
            case 'fair':
              qualityText = 'Fair Quality';
              break;
            case 'poor':
              qualityText = 'Poor Quality';
              break;
            default:
              qualityText = 'Signal Quality: Unknown';
          }
          
          double amplitudePercentage = (bleManager.peakAmplitude * 100).clamp(0.0, 100.0);
          
          return Column(
            children: [
              Text(
                qualityText,
                style: TextStyle(
                  fontSize: 16, 
                  color: _recordingStatusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Peak Amplitude: ${amplitudePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        },
      ),
    ],
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
                ? "Record Patient Murmur"
                : "Murmur Analysis",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () {
              _handleBackButton();
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
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
                      color: Colors.black.withAlpha(13), // Using withAlpha instead of withOpacity
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Consumer<BLEManager>(
                  builder: (context, bleManager, child) {
                    return Column(
                      children: [
                        _buildWaveform(context, bleManager),
                        const SizedBox(height: 16),
                        _buildRecordingStatus(),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildMainContent(),
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

  Widget _buildMainContent() {
  if (_isRecording || _isProcessing) {
    return _buildRecordingContent();
  } else if (_hasRecordingCompleted) {
    return _buildRecordingCompleteContent();
  } else {
    return _buildInitialContent();
  }
}

Widget _buildRecordingContent() {
  final bleManager = Provider.of<BLEManager>(context, listen: false);
  
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _recordingStatusColor.withAlpha(26),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              // Use heart icon if quality is good
              Widget icon;
              
              if (_recordingQuality == 'excellent' || _recordingQuality == 'good') {
                // Heart icon that pulses with animation
                icon = Transform.scale(
                  scale: 0.8 + (_pulseController.value * 0.3),
                  child: Icon(
                    Icons.favorite,
                    color: _recordingStatusColor,
                    size: 60,
                  ),
                );
              } else if (_isProcessing) {
                // Processing icon
                icon = Transform.scale(
                  scale: 0.8 + (_pulseController.value * 0.2),
                  child: Icon(
                    Icons.hourglass_top,
                    color: Colors.amber,
                    size: 40,
                  ),
                );
              } else {
                // Default microphone icon
                icon = Transform.scale(
                  scale: 0.8 + (_pulseController.value * 0.2),
                  child: Icon(
                    Icons.mic,
                    color: _recordingStatusColor,
                    size: 40,
                  ),
                );
              }
              
              return icon;
            },
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        _isProcessing ? "Processing audio..." : _recordingMessage,
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // Show amplitudes
      const SizedBox(height: 12),
      Consumer<BLEManager>(
        builder: (context, bleManager, child) {
          double amplitudePercentage = (bleManager.currentAmplitude * 100).clamp(0.0, 100.0);
          
          return Column(
            children: [
              // Show heart rate like display for good quality
              if (_recordingQuality == 'excellent' || _recordingQuality == 'good')
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        // Create a beep-like line
                        return Container(
                          width: 30,
                          height: 20,
                          child: CustomPaint(
                            painter: HeartbeatPainter(
                              progress: _pulseController.value,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              
              const SizedBox(height: 8),
              Text(
                "Signal Strength: ${amplitudePercentage.toStringAsFixed(1)}%",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        },
      ),
      
      // Show progress bar
      const SizedBox(height: 16),
      Container(
        width: 200,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _recordingProgress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: _recordingStatusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildRecordingCompleteContent() {
  // Display different icons based on recording quality
  IconData qualityIcon = Icons.check_circle_outline;
  Color qualityColor = Colors.green;
  String qualityText = "Recording complete!";
  String detailText = "Heart sounds were recorded.";
  
  switch (_recordingQuality) {
    case 'excellent':
      qualityIcon = Icons.favorite;
      qualityColor = Colors.green;
      qualityText = "Excellent heart sound quality!";
      detailText = "Clear heartbeats were detected.";
      break;
    case 'good':
      qualityIcon = Icons.favorite_border;
      qualityColor = Colors.green;
      qualityText = "Good heart sound quality";
      detailText = "Heartbeats were detected.";
      break;
    case 'fair':
      qualityIcon = Icons.favorite_border;
      qualityColor = Colors.orange;
      qualityText = "Fair heart sound quality";
      detailText = "Some heartbeats detected. May need review.";
      break;
    case 'poor':
      qualityIcon = Icons.heart_broken_outlined;
      qualityColor = Colors.red;
      qualityText = "Poor heart sound quality";
      detailText = "Weak or no heartbeats. Consider recording again.";
      break;
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: qualityColor.withAlpha(26),
        ),
        child: Icon(
          qualityIcon,
          color: qualityColor,
          size: 60,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        qualityText,
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        detailText,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
        ),
      ),
      const SizedBox(height: 16),
      IconButton(
        icon: Icon(
          _isPlaying ? Icons.pause_circle : Icons.play_circle,
          size: 48,
          color: Colors.blue[700],
        ),
        onPressed: () => _playPreviewRecording(),
      ),
    ],
  );
}

  Widget _buildInitialContent() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue[700]!.withAlpha(26),
        ),
        child: Icon(
          Icons.mic_none,
          color: Colors.blue[700],
          size: 48,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        "Tap the button below to start recording",
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        "For best results, place the device against the chest\nin a quiet room",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[500],
        ),
      ),
    ],
  );
}

Widget _buildFloatingActionButton() {
  if (_isRecording) {
    return FloatingActionButton.extended(
      onPressed: _isProcessing ? null : _stopRecording,
      backgroundColor: _isProcessing ? Colors.grey : Colors.red,
      label: Text(_isProcessing ? "Processing..." : "Stop Recording"),
      icon: Icon(_isProcessing ? Icons.hourglass_top : Icons.stop),
    );
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
            backgroundColor: Colors.red,
            label: const Text("Discard"),
            icon: const Icon(Icons.delete),
            heroTag: null,
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _showSaveRecordingDialog,
            backgroundColor: Colors.green,
            label: const Text("Save Recording"),
            icon: const Icon(Icons.save),
            heroTag: null,
          ),
        ],
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: _startRecording,
        backgroundColor: Colors.blue[700],
        label: const Text("Start Recording"),
        icon: const Icon(Icons.mic),
      );
    }
  }
}
class HeartbeatPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  HeartbeatPainter({required this.progress, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(0, size.height / 2);
    
    // Draw flatline
    if (progress < 0.3) {
      path.lineTo(size.width * progress / 0.3, size.height / 2);
    } else if (progress < 0.4) {
      path.lineTo(size.width * 0.3, size.height / 2);
      // Draw spike up (S1 - lub)
      final spikeProgress = (progress - 0.3) / 0.1;
      path.lineTo(
        size.width * (0.3 + 0.1 * spikeProgress), 
        size.height / 2 - size.height * 0.4 * spikeProgress
      );
    } else if (progress < 0.5) {
      path.lineTo(size.width * 0.3, size.height / 2);
      path.lineTo(size.width * 0.4, size.height / 2 - size.height * 0.4);
      // Draw spike down
      final spikeProgress = (progress - 0.4) / 0.1;
      path.lineTo(
        size.width * (0.4 + 0.1 * spikeProgress), 
        size.height / 2 - size.height * 0.4 * (1 - spikeProgress)
      );
    } else if (progress < 0.6) {
      path.lineTo(size.width * 0.3, size.height / 2);
      path.lineTo(size.width * 0.4, size.height / 2 - size.height * 0.4);
      path.lineTo(size.width * 0.5, size.height / 2);
      // Small pause
      path.lineTo(size.width * (0.5 + 0.1 * (progress - 0.5) / 0.1), size.height / 2);
    } else if (progress < 0.7) {
      path.lineTo(size.width * 0.3, size.height / 2);
      path.lineTo(size.width * 0.4, size.height / 2 - size.height * 0.4);
      path.lineTo(size.width * 0.5, size.height / 2);
      path.lineTo(size.width * 0.6, size.height / 2);
      // Draw second spike up (S2 - dub)
      final spikeProgress = (progress - 0.6) / 0.1;
      path.lineTo(
        size.width * (0.6 + 0.1 * spikeProgress), 
        size.height / 2 - size.height * 0.3 * spikeProgress
      );
    } else if (progress < 0.8) {
      path.lineTo(size.width * 0.3, size.height / 2);
      path.lineTo(size.width * 0.4, size.height / 2 - size.height * 0.4);
      path.lineTo(size.width * 0.5, size.height / 2);
      path.lineTo(size.width * 0.6, size.height / 2);
      path.lineTo(size.width * 0.7, size.height / 2 - size.height * 0.3);
      // Draw back down
      final spikeProgress = (progress - 0.7) / 0.1;
      path.lineTo(
        size.width * (0.7 + 0.1 * spikeProgress), 
        size.height / 2 - size.height * 0.3 * (1 - spikeProgress)
      );
    } else {
      path.lineTo(size.width * 0.3, size.height / 2);
      path.lineTo(size.width * 0.4, size.height / 2 - size.height * 0.4);
      path.lineTo(size.width * 0.5, size.height / 2);
      path.lineTo(size.width * 0.6, size.height / 2);
      path.lineTo(size.width * 0.7, size.height / 2 - size.height * 0.3);
      path.lineTo(size.width * 0.8, size.height / 2);
      // Flatline to end
      path.lineTo(size.width, size.height / 2);
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(HeartbeatPainter oldDelegate) => 
    oldDelegate.progress != progress || oldDelegate.color != color;
}