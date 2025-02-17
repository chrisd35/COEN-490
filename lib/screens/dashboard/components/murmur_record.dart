import 'dart:async';
import 'dart:typed_data';
import 'package:coen_490/screens/registration/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../patient/add_patient_screen.dart';
import '../../registration/login_page.dart';
import '../../registration/register_page.dart';
import '../dashboard_screen.dart';
import '/utils/ble_manager.dart';
import '../../registration/firebase_service.dart';
import '/utils/models.dart';


class MurmurRecord extends StatefulWidget {
  final String? preselectedPatientId;

  const MurmurRecord({
    Key? key,
    this.preselectedPatientId,
  }) : super(key: key);

  @override
  _MurmurRecordState createState() => _MurmurRecordState();
}

class _MurmurRecordState extends State<MurmurRecord> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isRecording = false;
  bool _hasRecordingCompleted = false;
  bool _isPlaying = false;
  List<int>? _recordedAudioData;
  double _bufferSize = 0;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
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

 void _startRecording() async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    if (bleManager.connectedDevice != null) {
      try {
        await bleManager.startRecording();
        setState(() {
          _isRecording = true;
          _hasRecordingCompleted = false;
          _bufferSize = 0;
          _recordingDuration = Duration.zero;
        });

        _startBufferSizeMonitoring();
        
        // Use a more precise timer
        _recordingTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
          setState(() {
            // Round to nearest second for display
            int totalMs = timer.tick * 100;
            _recordingDuration = Duration(milliseconds: totalMs);
          });
        });
      } catch (e) {
        _showErrorSnackBar("Failed to start recording: $e");
      }
    } else {
      _showErrorSnackBar("No device connected");
    }
  }

  void _startBufferSizeMonitoring() {
    Stream.periodic(Duration(milliseconds: 100)).listen((_) {
      if (_isRecording) {
        final bleManager = Provider.of<BLEManager>(context, listen: false);
        setState(() {
          _bufferSize = bleManager.audioBuffer.length.toDouble();
        });
      }
    });
  }

    void _stopRecording() async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    try {
      _recordingTimer?.cancel();

      // Get the final duration in whole seconds
      int durationSeconds = ((_recordingDuration.inMilliseconds + 500) / 1000).floor();
      print("Final recording duration: $durationSeconds seconds");

      List<int> audioData = await bleManager.stopRecording();

      if (audioData.isEmpty) {
        _showErrorSnackBar("No audio data recorded");
        return;
      }

      setState(() {
        _isRecording = false;
        _hasRecordingCompleted = true;
        _recordedAudioData = audioData;
      });

    } catch (e) {
      _showErrorSnackBar("Failed to stop recording: $e");
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
      // Convert the raw audio data to WAV format
      final wavData = _firebaseService.createWavFile(
        _recordedAudioData!,
        sampleRate: BLEManager.SAMPLE_RATE,
        bitsPerSample: 16,
        channels: 1,
      );

      // Create a temporary file or use in-memory playback
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch patients list
      List<Patient> patients = await _firebaseService.getPatientsForUser(uid);
      Navigator.pop(context); // Remove loading dialog

      if (patients.isEmpty) {
        _showNoPatientDialog();
        return;
      }
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Save Recording'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Create New Patient'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToCreatePatient();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Select Existing Patient'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPatientSelectionDialog(uid, patients);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.pop(context); // Remove loading dialog
      _showErrorSnackBar("Failed to load patients: $e");
    }
  }

void _navigateToCreatePatient() {
  if (!mounted) return;
  
  Navigator.push<Patient>(
    context,
    MaterialPageRoute(
      builder: (context) => AddPatientScreen(fromMurmurRecord: true),
    ),
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Patient'),
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
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

 void _showNoPatientDialog() {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) { // Use dialogContext instead of context
      return AlertDialog(
        title: Text('No Patients Found'),
        content: Text('Would you like to create a new patient?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text('Create Patient'),
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
    if (_recordedAudioData == null) return;

    _showLoadingDialog("Saving recording...");

    try {
      final bleManager = Provider.of<BLEManager>(context, listen: false);
      
      // Round the duration to nearest second
      int durationSeconds = ((_recordingDuration.inMilliseconds + 500) / 1000).floor();
      
      await _firebaseService.saveRecording(
        uid,
        patientId,
        DateTime.now(),
        _recordedAudioData!,
        {
          'duration': durationSeconds,
          'sampleRate': BLEManager.SAMPLE_RATE,
          'bitsPerSample': BLEManager.BITS_PER_SAMPLE,
          'channels': BLEManager.CHANNELS,
          'peakAmplitude': bleManager.peakAmplitude,
        },
      );

      Navigator.pop(context); // Close loading dialog
      _showSuccessSnackBar("Recording saved successfully");
      
      setState(() {
        _hasRecordingCompleted = false;
        _recordedAudioData = null;
      });
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar("Failed to save recording: $e");
    }
}

 void _showLoginPrompt() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Login Required'),
        content: Text('You need to be logged in to save recordings. Do you have an account?'),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(),
                  settings: RouteSettings(
                    arguments: {
                      'returnRoute': 'murmur_record',
                      'pendingAction': 'save_recording',
                    },
                  ),
                ),
              ).then((value) {
                if (value == true) {
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RegisterPage(),
                  settings: RouteSettings(
                    arguments: {
                      'returnRoute': 'murmur_record',
                      'pendingAction': 'save_recording',
                    },
                  ),
                ),
              ).then((value) {
                if (value == true) {
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
            child: Text('Create New Account'),
          ),
        ],
      );
    },
  );
}


  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Widget _buildWaveform(BuildContext context, BLEManager bleManager) {
    return Container(
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
              color: Colors.blue[700],
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue[700]!.withOpacity(0.1),
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
        SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
  title: Text(
    widget.preselectedPatientId != null 
        ? "Record Patient Murmur"
        : "Murmur Analysis",
    style: TextStyle(
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    ),
  ),
  elevation: 0,
  backgroundColor: Colors.white,
  foregroundColor: Colors.black87,
  leading: IconButton(
    icon: Icon(Icons.arrow_back_ios, size: 20),
    onPressed: () async {
      // Check if user is logged in before navigating back
      final authService = Provider.of<AuthService>(context, listen: false);
      final isGuest = await authService.isGuest();
      
      if (!isGuest) {
        // If logged in, refresh dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        // If guest, just pop back
        Navigator.pop(context);
      }
    },
  ),
),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Consumer<BLEManager>(
                builder: (context, bleManager, child) {
                  return Column(
                    children: [
                      _buildWaveform(context, bleManager),
                      SizedBox(height: 16),
                      _buildRecordingStatus(),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _buildMainContent(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
            color: Colors.red.withOpacity(0.1),
          ),
          child: Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: Icon(
                Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        SizedBox(height: 24),
        Text(
          "Recording in progress...",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
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
            color: Colors.green.withOpacity(0.1),
          ),
          child: Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 60,
          ),
        ),
        SizedBox(height: 24),
        Text(
          "Recording completed!",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Would you like to save this recording?",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 16),
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
            color: Colors.blue[700]!.withOpacity(0.1),
          ),
          child: Icon(
            Icons.mic_none,
            color: Colors.blue[700],
            size: 48,
          ),
        ),
        SizedBox(height: 24),
        Text(
          "Tap the button below to start recording",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
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
        label: Text("Stop Recording"),
        icon: Icon(Icons.stop),
      );
    } else if (_hasRecordingCompleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () => setState(() {
              _hasRecordingCompleted = false;
              _recordedAudioData = null;
            }),
            backgroundColor: Colors.red,
            label: Text("Discard"),
            icon: Icon(Icons.delete),
            heroTag: null,
          ),
          SizedBox(width: 16),
          FloatingActionButton.extended(
            onPressed: _showSaveRecordingDialog,
            backgroundColor: Colors.green,
            label: Text("Save Recording"),
            icon: Icon(Icons.save),
            heroTag: null,
          ),
        ],
      );
    } else {
      return FloatingActionButton.extended(
        onPressed: _startRecording,
        backgroundColor: Colors.blue[700],
        label: Text("Start Recording"),
        icon: Icon(Icons.mic),
      );
    }
  }
}