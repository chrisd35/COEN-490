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

class MurmurRecordState extends State<MurmurRecord> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRecording = false;
  bool _hasRecordingCompleted = false;
  bool _isPlaying = false;
  bool _cameFromPatientDetails = false;
  List<int>? _recordedAudioData;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  bool _isProcessing = false;
  Map<String, dynamic>? _recordingData;
  
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
        });
        
        await bleManager.startRecording();
        
        if (!mounted) return;

        // Use a precise timer for updating duration display
        _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          if (mounted) {
            final int totalMs = timer.tick * 100;
            
            setState(() {
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
    setState(() {
      _isProcessing = true;
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
        final audioData = List<int>.from(_recordingData!['audioData']);

        // First process with the Python-like algorithm
        final bleManager = Provider.of<BLEManager>(context, listen: false);
        final processedAudio = bleManager.processHeartbeatAudio(audioData);

        // Then add sonification for clearer indication of heartbeats
        final sonifiedAudio = bleManager.addHeartbeatSonification(processedAudio);

        // Create WAV file from the sonified audio
        final wavData = _firebaseService.createWavFile(
          sonifiedAudio,
          sampleRate: BLEManager.sampleRate,
          bitsPerSample: BLEManager.bitsPerSample,
          channels: BLEManager.channels,
        );

        await _audioPlayer.play(
          BytesSource(Uint8List.fromList(wavData)),
        );
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
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
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildSimpleWaveform(BuildContext context, BLEManager bleManager) {
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
              color: Colors.blue,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withAlpha(26),
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
            double amplitudePercentage = (bleManager.currentAmplitude * 100).clamp(0.0, 100.0);
            
            return Text(
              'Signal Strength: ${amplitudePercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
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
                ? "Record Patient Audio"
                : "Audio Recording",
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
                        _buildSimpleWaveform(context, bleManager),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withAlpha(26),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (_pulseController.value * 0.2),
                  child: _isProcessing
                      ? Icon(
                          Icons.hourglass_top,
                          color: Colors.amber,
                          size: 40,
                        )
                      : Icon(
                          Icons.mic,
                          color: Colors.blue,
                          size: 40,
                        ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isProcessing ? "Processing audio..." : "Recording in progress",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // Show signal strength percentage
        const SizedBox(height: 12),
        Consumer<BLEManager>(
          builder: (context, bleManager, child) {
            double amplitudePercentage = (bleManager.currentAmplitude * 100).clamp(0.0, 100.0);
            
            return Text(
              "Signal Strength: ${amplitudePercentage.toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecordingCompleteContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withAlpha(26),
          ),
          child: Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Recording complete!",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
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