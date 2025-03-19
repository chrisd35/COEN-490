import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '/utils/models.dart';
import '/widgets/waveform_painter.dart';
import '../../registration/auth_service.dart';
import '../../registration/firebase_service.dart';
import '../../../utils/navigation_service.dart';
import '../../../utils/app_routes.dart';
import '../../../widgets/back_button.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('RecordingPlaybackScreen');

class RecordingPlaybackScreen extends StatefulWidget {
  final String? preselectedPatientId;

  // Use super parameter syntax for key
  const RecordingPlaybackScreen({super.key, this.preselectedPatientId});

  @override
  State<RecordingPlaybackScreen> createState() => _RecordingPlaybackScreenState();
}

class _RecordingPlaybackScreenState extends State<RecordingPlaybackScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Patient>? _patients;
  Patient? _selectedPatient;
  List<Recording>? _recordings;
  Recording? _selectedRecording;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Uint8List? _currentAudioData;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    
    if (widget.preselectedPatientId != null) {
      _loadSpecificPatient(widget.preselectedPatientId!);
    } else {
      _checkAuthAndLoadPatients();
    }
  }

  Future<void> _loadSpecificPatient(String medicalCardNumber) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.getCurrentUser();
      
      if (currentUser == null) {
        _showLoginPrompt();
        return;
      }
      
      final patient = await _firebaseService.getPatient(
        currentUser.uid,
        medicalCardNumber,
      );
      
      // Check if widget is still mounted before using setState
      if (!mounted) return;
      
      if (patient != null) {
        setState(() {
          _selectedPatient = patient;
          _patients = [patient]; // Set patients list with just this patient
        });
        
        await _loadRecordings(patient);
      }
    } catch (e) {
      _logger.severe("Failed to load patient: $e");
      
      if (!mounted) return;
      _showErrorSnackBar("Failed to load patient: $e");
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (!mounted) return;
      setState(() {
        _duration = newDuration;
      });
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (!mounted) return;
      setState(() {
        _position = newPosition;
      });
    });
    
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  Future<void> _checkAuthAndLoadPatients() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.getCurrentUser() == null) {
      _showLoginPrompt();
      return;
    }

    await _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.getCurrentUser()!.uid;
      final patients = await _firebaseService.getPatientsForUser(uid);
      
      if (!mounted) return;
      
      setState(() {
        _patients = patients;
      });
    } catch (e) {
      _logger.severe("Failed to load patients: $e");
      
      if (!mounted) return;
      _showErrorSnackBar("Failed to load patients: $e");
    }
  }

  Future<void> _loadRecordings(Patient patient) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.getCurrentUser()!.uid;
      final recordings = await _firebaseService.getRecordingsForPatient(
        uid, 
        patient.medicalCardNumber
      );
      
      if (!mounted) return;
      
      setState(() {
        _recordings = recordings;
        _selectedRecording = null;
        _currentAudioData = null;
      });
    } catch (e) {
      _logger.severe("Failed to load recordings: $e");
      
      if (!mounted) return;
      _showErrorSnackBar("Failed to load recordings: $e");
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
          title: const Text('Login Required'),
          content: const Text('You need to be logged in to access recordings. Do you have an account?'),
          actions: [
            TextButton(
              onPressed: () => NavigationService.goBack(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            TextButton(
              onPressed: () {
                NavigationService.goBack();
                NavigationService.navigateTo(
                  AppRoutes.login,
                  arguments: {
                    'returnRoute': 'recording_playback',
                  },
                ).then((value) {
                  if (value == true) {
                    _loadPatients();
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
                NavigationService.goBack();
                NavigationService.navigateTo(
                  AppRoutes.register,
                  arguments: {
                    'returnRoute': 'recording_playback',
                  },
                ).then((value) {
                  if (value == true) {
                    _loadPatients();
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper method to download audio file
  Future<Uint8List> _downloadAudioData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception("Failed to download audio: ${response.statusCode}");
      }
    } catch (e) {
      _logger.severe("Error downloading audio: $e");
      rethrow;
    }
  }

  // Method to build waveform visualization
  Widget _buildWaveformView(Recording recording) {
    if (_currentAudioData != null) {
      // Extract audio data from WAV file (skip 44-byte header)
      List<int> audioData = _currentAudioData!.skip(44).toList();
      
      // Return the waveform visualization
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Waveform Visualization",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: WaveformVisualizer(
                audioData: audioData,
                waveColor: Theme.of(context).primaryColor,
                backgroundColor: Colors.grey[100]!,
                showGrid: true,
                height: 150,
                sampleRate: recording.sampleRate,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Processed with heartbeat-optimized filters",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (recording.downloadUrl != null) {
      // Show loading indicator while downloading
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text("Loading waveform..."),
            ],
          ),
        ),
      );
    } else {
      // Show message if waveform is not available
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text("Waveform visualization not available"),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title = _selectedPatient != null 
        ? "Recordings - ${_selectedPatient!.fullName}"
        : "Recording Playback";
        
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
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
            onPressed: () => NavigationService.goBack(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (widget.preselectedPatientId == null) _buildPatientSelector(),
              if (_selectedPatient != null) _buildRecordingsList(),
              if (_selectedRecording != null) _buildPlaybackControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    if (_patients == null) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_patients!.isEmpty) {
      return const Expanded(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("No patients found"),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Patient",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Patient>(
              isExpanded: true,
              value: _selectedPatient,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: "Choose a patient",
              ),
              icon: const Icon(Icons.arrow_drop_down_circle_outlined),
              onChanged: (Patient? patient) {
                setState(() {
                  _selectedPatient = patient;
                  _recordings = null;
                  _selectedRecording = null;
                  _currentAudioData = null;
                });
                if (patient != null) {
                  _loadRecordings(patient);
                }
              },
              items: _patients!.map((Patient patient) {
                return DropdownMenuItem<Patient>(
                  value: patient,
                  child: Text(patient.fullName),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsList() {
    if (_recordings == null) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recordings!.isEmpty) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "No recordings found for this patient",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _recordings!.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final recording = _recordings![index];
          return _buildRecordingItem(recording, index);
        },
      ),
    );
  }

  Widget _buildRecordingItem(Recording recording, int index) {
    bool isSelected = _selectedRecording == recording;
    
    return Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(26), // 0.1 * 255 ≈ 26
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.audio_file,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            title: Text(
              "Recording ${index + 1}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(recording.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Duration: ${recording.duration}s",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying && _selectedRecording == recording
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
              onPressed: () => _playRecording(recording),
            ),
            onTap: () {
              setState(() {
                _selectedRecording = recording;
                _currentAudioData = null;
                _position = Duration.zero;
              });
              
              // Download audio data for visualization
              if (recording.downloadUrl != null) {
                _downloadAudioData(recording.downloadUrl!)
                    .then((data) {
                  if (mounted) {
                    setState(() {
                      _currentAudioData = data;
                    });
                  }
                })
                    .catchError((e) {
                  _logger.severe("Error downloading audio data: $e");
                });
              }
            },
          ),
          
          // Add waveform visualization if selected
          if (isSelected)
            _buildWaveformView(recording),
            
          // Add recording details
          if (isSelected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoChip(
                      Icons.timelapse, "${recording.duration}s"),
                  _buildInfoChip(
                      Icons.speed, "${recording.sampleRate ~/ 1000}kHz"),
                  _buildInfoChip(
                      Icons.equalizer, "16-bit"),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    String formatTime(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$minutes:$seconds";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26), // Using withAlpha(26) instead of withOpacity(0.1)
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 16,
              ),
              activeTrackColor: Theme.of(context).primaryColor,
              inactiveTrackColor: Colors.grey[300],
              thumbColor: Theme.of(context).primaryColor,
              overlayColor: Theme.of(context).primaryColor.withAlpha(51), // 0.2 * 255 ≈ 51
            ),
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0,
              max: _duration.inSeconds.toDouble(),
              onChanged: (value) async {
                final position = Duration(seconds: value.toInt());
                await _audioPlayer.seek(position);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatTime(_position),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatTime(_duration),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () async {
                  if (_position.inSeconds > 5) {
                    await _audioPlayer.seek(
                      Duration(seconds: _position.inSeconds - 5),
                    );
                  } else {
                    await _audioPlayer.seek(Duration.zero);
                  }
                },
                icon: Icon(
                  Icons.replay_5,
                  size: 32,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withAlpha(77), // 0.3 * 255 ≈ 77
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    if (_selectedRecording != null) {
                      _playRecording(_selectedRecording!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () async {
                  if (_position.inSeconds < _duration.inSeconds - 5) {
                    await _audioPlayer.seek(
                      Duration(seconds: _position.inSeconds + 5),
                    );
                  } else {
                    await _audioPlayer.seek(_duration);
                  }
                },
                icon: Icon(
                  Icons.forward_5,
                  size: 32,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _playRecording(Recording recording) async {
    if (_selectedRecording == recording && _isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    setState(() {
      _selectedRecording = recording;
      _position = Duration.zero;
      
      // Download the audio data for visualization if not already loaded
      if (_currentAudioData == null && recording.downloadUrl != null) {
        _downloadAudioData(recording.downloadUrl!)
            .then((data) {
          if (mounted) {
            setState(() {
              _currentAudioData = data;
            });
          }
        })
            .catchError((e) {
          _logger.severe("Error downloading audio data: $e");
        });
      }
    });

    try {
      if (recording.downloadUrl == null) {
        throw Exception("Download URL not available");
      }
      await _audioPlayer.play(UrlSource(recording.downloadUrl!));
    } catch (e) {
      _logger.severe("Failed to play recording: $e");
      if (!mounted) return;
      _showErrorSnackBar("Failed to play recording: $e");
    }
  }
}