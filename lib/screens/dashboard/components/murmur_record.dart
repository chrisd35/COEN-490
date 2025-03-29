import 'dart:async';
import 'dart:math' as math;
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

final _logger = logging.Logger('AccountProfilePage');

class MurmurRecord extends StatefulWidget {
  final String? preselectedPatientId;

  const MurmurRecord({
    super.key,
    this.preselectedPatientId,
  });

  @override
  State<MurmurRecord> createState() => MurmurRecordState();
}

class MurmurRecordState extends State<MurmurRecord> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRecording = false;
  bool _hasRecordingCompleted = false;
  bool _isPlaying = false;
  bool _cameFromPatientDetails = false;
  List<int>? _recordedAudioData;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  double _playbackVolume = 1.0; // Add this line
  
  // Heart murmur analysis state
  double _murmurProbability = 0.0;
  String _murmurType = 'None';
  double _dominantFrequency = 0.0;
  bool _isSystolic = false;
  bool _isDiastolic = false;
  String _murmurGrade = 'N/A';
  
  // UI display settings
  bool _showAdvancedAnalysis = false;

  bool _debugModeEnabled = false;
bool _playingRawAudio = false;

  @override
  void initState() {
    super.initState();
    _cameFromPatientDetails = widget.preselectedPatientId != null;
    _setupAudioPlayer();
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

 



// Add this helper method to show info snackbars
void _showInfoSnackBar(String message) {
  if (!mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.blue,
      behavior: SnackBarBehavior.fixed,
      duration: const Duration(seconds: 2),
    ),
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
          _murmurProbability = 0.0;
          _murmurType = 'None';
          _dominantFrequency = 0.0;
          _murmurGrade = 'N/A';
          _isSystolic = false;
          _isDiastolic = false;
        });

        _startBufferSizeMonitoring();
        
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

  void _startBufferSizeMonitoring() {
    Stream.periodic(const Duration(milliseconds: 100)).listen((_) {
      if (_isRecording && mounted) {
        final bleManager = Provider.of<BLEManager>(context, listen: false);
        // Update murmur probability in real-time if available
        if (bleManager.murmurProbability > 0) {
          setState(() {
            _murmurProbability = bleManager.murmurProbability;
            _murmurType = bleManager.murmurType;
            _dominantFrequency = bleManager.dominantFrequency;
            _isSystolic = bleManager.isSystolicMurmur;
            _isDiastolic = bleManager.isDiastolicMurmur;
            
            // Calculate murmur grade based on probability
            if (_murmurProbability < 0.3) {
              _murmurGrade = 'N/A';
            } else if (_murmurProbability < 0.5) {
              _murmurGrade = 'Grade I';
            } else if (_murmurProbability < 0.7) {
              _murmurGrade = 'Grade II';
            } else if (_murmurProbability < 0.85) {
              _murmurGrade = 'Grade III';
            } else {
              _murmurGrade = 'Grade IV+';
            }
          });
        }
      }
    });
  }

  void _stopRecording() async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    try {
      _recordingTimer?.cancel();

      // Show processing indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Processing heart sound data..."),
            duration: Duration(seconds: 10),
          ),
        );
      }

      // Get recording result
      var result = await bleManager.stopRecording();
      List<int> rawAudio = result['audioData']; // Extract audio data from map
      Map<String, dynamic> metadata = result['metadata'];

      if (rawAudio.isEmpty) {
        if (mounted) {
          _showErrorSnackBar("No audio data recorded");
        }
        return;
      }

      if (mounted) {
        // Dismiss the processing snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        setState(() {
          _isRecording = false;
          _hasRecordingCompleted = true;
          _recordedAudioData = rawAudio;
          
          // Update murmur analysis from metadata
          _murmurProbability = metadata['murmurProbability'] ?? 0.0;
          _murmurType = metadata['murmurType'] ?? 'None';
          _dominantFrequency = metadata['dominantFrequency'] ?? 0.0;
          _isSystolic = metadata['isSystolicMurmur'] ?? false;
          _isDiastolic = metadata['isDiastolicMurmur'] ?? false;
          
          // Calculate murmur grade based on probability
          if (_murmurProbability < 0.3) {
            _murmurGrade = 'N/A';
          } else if (_murmurProbability < 0.5) {
            _murmurGrade = 'Grade I';
          } else if (_murmurProbability < 0.7) {
            _murmurGrade = 'Grade II';
          } else if (_murmurProbability < 0.85) {
            _murmurGrade = 'Grade III';
          } else {
            _murmurGrade = 'Grade IV+';
          }
        });
        
        // Show success message with murmur information
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _murmurProbability > 0.3 
                ? "Heart sound recording complete. Potential ${_murmurType.toLowerCase()} detected."
                : "Heart sound recording complete. No significant murmur detected."
            ),
            backgroundColor: _murmurProbability > 0.3 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Error processing recording: $e");
        setState(() {
          _isRecording = false;
        });
      }
    }
  }
  
Future<void> _playPreviewRecording() async {
  if (_recordedAudioData == null) return;

  try {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Get a copy of the audio data
      List<int> audioDataCopy = List.from(_recordedAudioData!);
      
      // Apply enhanced amplification that targets heartbeats
      List<int> enhancedAudio = _firebaseService.enhanceHeartbeatWithAmplification(
        audioDataCopy,
        sampleRate: BLEManager.sampleRate,
        threshold: 0.06,         // Make this lower to catch fainter beats
        beatGain: 300.0,           // Strong emphasis on beats
        overallGain: 400.0,        // Overall amplification
        noiseSuppression: 0.1    // Suppress quieter parts more (lower = more suppression)
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
      
      // Set volume to maximum for best effect
      await _audioPlayer.setVolume(1.0);
      
      setState(() {
        _isPlaying = true;
        _playbackVolume = 1.0;  // Update the UI slider
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Playing amplified heart sounds"),
          duration: Duration(seconds: 3),
        ),
      );
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
            title: const Text('Save Heart Sound Recording'),
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
  if (_recordedAudioData == null || !mounted) return;
  
  // Get data before showing dialog
  final bleManager = Provider.of<BLEManager>(context, listen: false);
  final roundedDuration = ((_recordingDuration.inMilliseconds + 500) / 1000).floor();
  
  // Get a copy of the audio data - use raw data without processing
  List<int> audioDataCopy = List.from(_recordedAudioData!);
  
  if (!mounted) return;
  
  // Show loading dialog
  await _showLoadingDialog("Saving heart sound recording...");
  
  // Check if still mounted after dialog is shown
  if (!mounted) return;

  try {
    await _firebaseService.saveRecording(
      uid,
      patientId,
      DateTime.now(),
      audioDataCopy, // Use the raw audio data
      {
        'duration': roundedDuration,
        'sampleRate': BLEManager.sampleRate, 
        'bitsPerSample': BLEManager.bitsPerSample,
        'channels': BLEManager.channels,
        'peakAmplitude': bleManager.peakAmplitude,
        'processingApplied': false, // Set to false for raw audio
        'signalToNoiseRatio': bleManager.signalToNoiseRatio,
        'murmurProbability': _murmurProbability,
        'murmurType': _murmurType,
        'dominantFrequency': _dominantFrequency,
        'isSystolicMurmur': _isSystolic,
        'isDiastolicMurmur': _isDiastolic,
        'murmurGrade': _murmurGrade,
        'audioProcessing': {
          'isRawAudio': true,
          'noProcessingApplied': true,
        },
      },
    );

    // Check if still mounted before proceeding
    if (!mounted) return;
    
    // Close loading dialog
    try {
      Navigator.of(context).pop();
    } catch (_) {
      // Dialog may have been dismissed already, ignore errors
    }
    
    if (!mounted) return;
    
    _showSuccessSnackBar("Raw heart sound recording saved successfully");
    
    if (!mounted) return;
    
    setState(() {
      _hasRecordingCompleted = false;
      _recordedAudioData = null;
      _murmurProbability = 0.0;
      _murmurType = 'None';
    });
  } catch (e) {
    // Check if still mounted before using context
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

// Add this debugging function to your MurmurRecordState class
void _debugAudioData() {
  if (_recordedAudioData == null || _recordedAudioData!.isEmpty) {
    _logger.info("No audio data to debug");
    return;
  }
  
  _logger.info("Debugging audio data:");
  _logger.info("Total bytes: ${_recordedAudioData!.length}");
  
  // Check if data is all zeros or very small values
  bool allZeros = true;
  bool allSmall = true;
  int nonZeroCount = 0;
  
  for (int i = 0; i < math.min(1000, _recordedAudioData!.length); i++) {
    if (_recordedAudioData![i] != 0) {
      allZeros = false;
      nonZeroCount++;
      
      if (_recordedAudioData![i] > 10 || _recordedAudioData![i] < -10) {
        allSmall = false;
      }
    }
  }
  
  _logger.info("First 1000 bytes check - All zeros: $allZeros, All small values: $allSmall, Non-zero count: $nonZeroCount");
  
  // Check sample distribution if we have enough samples
  if (_recordedAudioData!.length >= 100) {
    ByteData byteData = ByteData(_recordedAudioData!.length);
    for (int i = 0; i < _recordedAudioData!.length; i++) {
      byteData.setUint8(i, _recordedAudioData![i]);
    }
    
    List<int> sampleValues = [];
    for (int i = 0; i < math.min(100, _recordedAudioData!.length ~/ 2); i++) {
      if (2*i + 1 < _recordedAudioData!.length) {
        int sample = byteData.getInt16(2*i, Endian.little);
        sampleValues.add(sample);
      }
    }
    
    _logger.info("First 50 samples (16-bit): $sampleValues");
    
    // Calculate distribution metrics
    if (sampleValues.isNotEmpty) {
      sampleValues.sort();
      int minValue = sampleValues.first;
      int maxValue = sampleValues.last;
      int medianValue = sampleValues[sampleValues.length ~/ 2];
      
      _logger.info("Sample distribution - Min: $minValue, Max: $maxValue, Median: $medianValue");
      
      // Check for flatlined audio
      if (maxValue - minValue < 100) {
        _logger.warning("POSSIBLE ISSUE: Audio has very little variation (nearly flat)");
      }
      
      // Check for DC offset
      double avgValue = sampleValues.reduce((a, b) => a + b) / sampleValues.length;
      _logger.info("Average sample value: $avgValue");
      
      if (avgValue.abs() > 5000) {
        _logger.warning("POSSIBLE ISSUE: Audio has significant DC offset");
      }
    }
  }
  
  // Check for obvious patterns that might indicate data corruption
  int patternRepeatCount = 0;
  if (_recordedAudioData!.length >= 20) {
    List<int> pattern = _recordedAudioData!.sublist(0, 10);
    for (int i = 10; i < _recordedAudioData!.length - 10; i += 10) {
      bool matches = true;
      for (int j = 0; j < 10; j++) {
        if (i + j < _recordedAudioData!.length && pattern[j] != _recordedAudioData![i + j]) {
          matches = false;
          break;
        }
      }
      if (matches) patternRepeatCount++;
    }
    
    if (patternRepeatCount > 5) {
      _logger.warning("POSSIBLE ISSUE: Audio data shows repeating patterns, might be corrupted");
      _logger.info("Repeating pattern count: $patternRepeatCount");
    }
  }
}

// Call this in _playPreviewRecording() before playing audio
void _addDebugButton() {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text("Having audio issues? Try debugging"),
      action: SnackBarAction(
        label: "Debug Audio",
        onPressed: () {
          _debugAudioData();
        },
      ),
      duration: const Duration(seconds: 5),
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
    super.dispose();
  }



  Widget _buildWaveform(BuildContext context, BLEManager bleManager) {
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
              color: _getMurmurColor(),
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: _getMurmurColor().withAlpha(26),
              ),
            ),
          ],
          minY: 0,
          maxY: 1,
        ),
      ),
    );
  }
  
  // Get appropriate color based on murmur probability
  Color _getMurmurColor() {
    if (_murmurProbability < 0.3) {
      return Colors.blue[700]!;
    } else if (_murmurProbability < 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
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
  int step = samplesCount > 2000 ? samplesCount ~/ 2000 : 1;  // Manual max function
  
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
  int displayStep = rawSamples.length > 300 ? rawSamples.length ~/ 300 : 1;  // Manual max function
  
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
  
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          "Raw Waveform",
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ),
      Text(
        "Sample range: ${sampleMinMax[0]} to ${sampleMinMax[1]}, DC offset: ${dcOffset.toStringAsFixed(1)}",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
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
                color: Colors.grey,
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          "DC Offset Corrected Waveform",
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ),
      Text(
        "Shows heart sound patterns after removing DC offset",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
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
                color: Colors.blue[700],
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text(
          "Heart Sound Enhanced",
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ),
      Text(
        "Filtered for more prominent heart sounds",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
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
        "The sine wave pattern you see is your heartbeat! Look for repeating patterns in the middle graph.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[700],
        ),
      ),
    ],
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
            // Calculate percentage but clamp it to 100%
            double amplitudePercentage = (bleManager.peakAmplitude * 100).clamp(0.0, 100.0);
            return Text(
              'Peak Amplitude: ${amplitudePercentage.toStringAsFixed(1)}%',
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
  
  // Build murmur analysis card (shown after recording)
  Widget _buildMurmurAnalysisCard() {
    if (!_hasRecordingCompleted || _murmurProbability < 0.01) {
      return const SizedBox.shrink();
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Heart Sound Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                IconButton(
                  icon: Icon(_showAdvancedAnalysis ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showAdvancedAnalysis = !_showAdvancedAnalysis;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Murmur detected: ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  _murmurProbability > 0.3 ? 'Yes' : 'No',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _murmurProbability > 0.3 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            if (_murmurProbability > 0.3) ... [
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Type: ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    _murmurType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Grade: ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    _murmurGrade,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _murmurGrade.contains('III') || _murmurGrade.contains('IV') 
                          ? Colors.red 
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
              if (_showAdvancedAnalysis) ... [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Systolic: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    Icon(
                      _isSystolic ? Icons.check_circle : Icons.cancel,
                      color: _isSystolic ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Diastolic: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    Icon(
                      _isDiastolic ? Icons.check_circle : Icons.cancel,
                      color: _isDiastolic ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Dominant Frequency: ',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${_dominantFrequency.toStringAsFixed(1)} Hz',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _murmurProbability,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(_getMurmurColor()),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(_murmurProbability * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ],
        ),
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
                : "Heart Murmur Analysis",
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
           // Add the debug toggle in the actions area of the AppBar
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
                        _buildWaveform(context, bleManager),
                        const SizedBox(height: 16),
                        _buildRecordingStatus(),
                      ],
                    );
                  },
                ),
              ),
              if (_hasRecordingCompleted) _buildMurmurAnalysisCard(),
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
    if (_isRecording) {
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
            color: Colors.red.withAlpha(26),
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Recording heart sounds...",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_murmurProbability > 0.3) ... [
          const SizedBox(height: 12),
          Text(
            "Potential murmur detected: ${_murmurType}",
            style: TextStyle(
              fontSize: 16,
              color: _getMurmurColor(),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

Widget _buildRecordingCompleteContent() {
  Color statusColor = _murmurProbability > 0.3 ? Colors.orange : Colors.green;
  IconData statusIcon = _murmurProbability > 0.3 ? Icons.warning_amber_rounded : Icons.check_circle_outline;
  
  return SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor.withAlpha(26),
          ),
          child: Icon(
            statusIcon,
            color: statusColor,
            size: 60,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _murmurProbability > 0.3 
              ? "Potential murmur detected"
              : "Recording completed!",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Would you like to save this recording?",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volume_down, color: Colors.blue[700]),
            Slider(
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
              activeColor: Colors.blue[700],
            ),
            Icon(Icons.volume_up, color: Colors.blue[700]),
          ],
        ),
        const SizedBox(height: 8),
        // Regular playback button for processed audio
        if (!_debugModeEnabled)
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle : Icons.play_circle,
              size: 48,
              color: Colors.blue[700],
            ),
            onPressed: () => _playPreviewRecording(),
          ),
        
        // Debug mode UI with both processed and raw audio options
        if (_debugModeEnabled)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 48,
                      color: Colors.blue[700],
                    ),
                    onPressed: () => _playPreviewRecording(),
                  ),
                  Text(
                    "Processed",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  IconButton(
  icon: Icon(
    _isPlaying ? Icons.pause_circle : Icons.play_circle,
    size: 48,
    color: Colors.blue[700],
  ),
  onPressed: () => _playPreviewRecording(),
),
                  Text(
                    "Raw Audio",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          
        // Debug Info Section
        if (_debugModeEnabled)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Debug Information",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text("Sample Range: ${_recordedAudioData != null ? _getSampleRange() : 'N/A'}"),
                Text("Mean Value: ${_recordedAudioData != null ? _calculateMean().toStringAsFixed(1) : 'N/A'}"),
                Text("DC Offset: ${_recordedAudioData != null ? _calculateDCOffset().toStringAsFixed(1) : 'N/A'}"),
                Text("Signal Variation: ${_recordedAudioData != null ? _calculateSignalVariation().toStringAsFixed(1) : 'N/A'}"),
                const SizedBox(height: 8),
                Text(
                  "Raw audio is the unprocessed signal directly from the MEMS microphone. "
                  "It may contain DC offset and background noise.",
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        // Add visualization
        _buildMurmurVisualization(),
      ],
    ),
  );
}

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

// Add this method to the MurmurRecordState to add a Debug Mode toggle



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
          "Tap the button below to start recording heart sounds",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Make sure the stethoscope is placed properly",
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
        onPressed: _stopRecording,
        backgroundColor: Colors.red,
        label: const Text("Stop Recording"),
        icon: const Icon(Icons.stop),
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
                _murmurProbability = 0.0;
                _murmurType = 'None';
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