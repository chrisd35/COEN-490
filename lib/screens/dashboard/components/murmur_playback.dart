import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '/utils/models.dart';
import '../../registration/auth_service.dart';
import '../../registration/firebase_service.dart';
import '../../../utils/navigation_service.dart';
import '../../../utils/app_routes.dart';
import '../../../widgets/back_button.dart';

class RecordingPlaybackScreen extends StatefulWidget {
  final String? preselectedPatientId;

  const RecordingPlaybackScreen({Key? key, this.preselectedPatientId}) : super(key: key);

  @override
  _RecordingPlaybackScreenState createState() => _RecordingPlaybackScreenState();
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
      
      if (patient != null) {
        setState(() {
          _selectedPatient = patient;
          _patients = [patient]; // Set patients list with just this patient
        });
        
        await _loadRecordings(patient);
      }
    } catch (e) {
      _showErrorSnackBar("Failed to load patient: $e");
    }
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
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
      
      setState(() {
        _patients = patients;
      });
    } catch (e) {
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
      
      setState(() {
        _recordings = recordings;
      });
    } catch (e) {
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
          title: Text('Login Required'),
          content: Text('You need to be logged in to access recordings. Do you have an account?'),
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
              child: Text('Create New Account'),
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
        duration: Duration(seconds: 2),
      ),
    );
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
      return Center(child: CircularProgressIndicator());
    }

    if (_patients!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("No patients found"),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Patient",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            DropdownButton<Patient>(
              isExpanded: true,
              value: _selectedPatient,
              hint: Text("Choose a patient"),
              onChanged: (Patient? patient) {
                setState(() {
                  _selectedPatient = patient;
                  _recordings = null;
                  _selectedRecording = null;
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
      return Center(child: CircularProgressIndicator());
    }

    if (_recordings!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("No recordings found for this patient"),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _recordings!.length,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final recording = _recordings![index];
          return Card(
            child: ListTile(
              leading: Icon(Icons.audio_file),
              title: Text("Recording ${index + 1}"),
              subtitle: Text(recording.timestamp.toString()),
              trailing: IconButton(
                icon: Icon(
                  _isPlaying && _selectedRecording == recording
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: () => _playRecording(recording),
              ),
            ),
          );
        },
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Slider(
            value: _position.inSeconds.toDouble(),
            min: 0,
            max: _duration.inSeconds.toDouble(),
            onChanged: (value) async {
              final position = Duration(seconds: value.toInt());
              await _audioPlayer.seek(position);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatTime(_position)),
                Text(formatTime(_duration)),
              ],
            ),
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
    });

    try {
      if (recording.downloadUrl == null) {
        throw Exception("Download URL not available");
      }
      await _audioPlayer.play(UrlSource(recording.downloadUrl!));
    } catch (e) {
      _showErrorSnackBar("Failed to play recording: $e");
    }
  }
}