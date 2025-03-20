import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '/utils/models.dart';
import '../../registration/auth_service.dart';
import '../../registration/firebase_service.dart';
import '../../../utils/navigation_service.dart';
import '../../../utils/app_routes.dart';
import '../../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;
import 'package:firebase_auth/firebase_auth.dart' as auth;

final _logger = logging.Logger('MurmurChart');

class MurmurChart extends StatefulWidget {
  final String? preselectedPatientId;

  const MurmurChart({super.key, this.preselectedPatientId});

  @override
  State<MurmurChart> createState() => _MurmurChartState();
}

class _MurmurChartState extends State<MurmurChart> {
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Patient>? _patients;
  Patient? _selectedPatient;
  List<Recording>? _recordings;
  Recording? _selectedRecording;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  // Added for murmur analysis visualization
  bool _isAnalyzing = false;
  Map<String, dynamic>? _murmurAnalysis;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = auth.FirebaseAuth.instance.currentUser; // Use prefixed auth
      if (user != null) {
        try {
          final token = await user.getIdToken();
          print('DEBUG TOKEN FOR POSTMAN: $token');
        } catch (e) {
          print('Error getting token: $e');
        }
      }
    });
    
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
      
      if (!mounted) return;
      
      if (patient != null) {
        setState(() {
          _selectedPatient = patient;
          _patients = [patient];
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
      });
    } catch (e) {
      _logger.severe("Failed to load recordings: $e");
      
      if (!mounted) return;
      _showErrorSnackBar("Failed to load recordings: $e");
    }
  }

  Future<void> _analyzeMurmur(Recording recording) async {
    if (!mounted) return;
    
    setState(() {
      _isAnalyzing = true;
      _murmurAnalysis = null;
    });

    try {
      final analysis = await _firebaseService.analyzeRecording(recording.filename);
      
      if (!mounted) return;
      
      setState(() {
        _murmurAnalysis = {
          'hasMurmur': analysis['prediction'] == "Abnormal",
          'confidence': analysis['confidence'],
          'type': _parseMurmurType(analysis['features']),
          'location': _parseMurmurLocation(analysis['features']),
          'grade': _parseMurmurGrade(analysis['features']),
          'characteristics': analysis['suggestions'],
          'possibleCauses': analysis['suggestions'],
        };
      });
    } catch (e) {
      _logger.severe("Analysis failed: $e");
      if (!mounted) return;
      _showErrorSnackBar("Analysis failed: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  String _parseMurmurType(Map<String, dynamic> features) {
    // Systolic characteristics
    if (features['Systole_Mean'] > 0.75 && 
        features['Wavelet_1_Energy'] > 0.65) {
      return 'Systolic ejection murmur';
    }
    // Diastolic characteristics
    if (features['Wavelet_2_Shannon'] > 4.2 &&
        features['Energy_200_400Hz'] < 0.4) {
      return 'Diastolic murmur';
    }
    return 'Undetermined type';
  }

  String _parseMurmurLocation(Map<String, dynamic> features) {
    // Aortic area detection
    if (features['Energy_200_400Hz'] > 0.7 && 
        features['Wavelet_1_Shannon'] > 3.8) {
      return 'Aortic area (right sternal border)';
    }
    // Mitral area detection
    if (features['MFCC_mean_13'] < -0.4 && 
        features['Energy_100_200Hz'] > 0.6) {
      return 'Mitral area (cardiac apex)';
    }
    return 'General cardiac area';
  }

  String _parseMurmurGrade(Map<String, dynamic> features) {
    // Grade based on systole characteristics and heart rate
    final systoleScore = (features['Systole_Mean'] * 0.7) + 
                        (features['Systole_Std'] * 0.3);
    final hr = features['HeartRate'] ?? 72;

    if (systoleScore > 0.85 && hr > 100) return 'Grade 4/6';
    if (systoleScore > 0.7) return 'Grade 3/6';
    if (systoleScore > 0.55) return 'Grade 2/6';
    return 'Grade 1/6';
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
                    'returnRoute': 'murmur_chart',
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
                    'returnRoute': 'murmur_chart',
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title = _selectedPatient != null 
        ? "Murmur Analysis - ${_selectedPatient!.fullName}"
        : "Murmur Detection";
        
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
              if (_murmurAnalysis != null) _buildMurmurAnalysis(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelector() {
    if (_patients == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_patients!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No patients found"),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),
            DropdownButton<Patient>(
              isExpanded: true,
              value: _selectedPatient,
              hint: const Text("Choose a patient"),
              onChanged: (Patient? patient) {
                setState(() {
                  _selectedPatient = patient;
                  _recordings = null;
                  _selectedRecording = null;
                  _murmurAnalysis = null;
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_recordings!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No recordings found for this patient"),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _recordings!.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final recording = _recordings![index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.audio_file),
              title: Text("Recording ${index + 1}"),
              subtitle: Text(recording.timestamp.toString()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying && _selectedRecording == recording
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () => _playRecording(recording),
                  ),
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined),
                    onPressed: () {
                      setState(() {
                        _selectedRecording = recording;
                        _murmurAnalysis = null;
                      });
                      _analyzeMurmur(recording);
                    },
                  ),
                ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, -5),
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

  Widget _buildMurmurAnalysis() {
    if (_isAnalyzing) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Analyzing heart sounds..."),
            ],
          ),
        ),
      );
    }

    if (_murmurAnalysis == null) {
      return const SizedBox.shrink();
    }

    final analysis = _murmurAnalysis!;
    final confidencePercent = (analysis['confidence'] * 100).toStringAsFixed(1);
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                analysis['hasMurmur'] ? Icons.warning_amber_rounded : Icons.check_circle,
                color: analysis['hasMurmur'] ? Colors.orange : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                analysis['hasMurmur'] ? "Murmur Detected" : "No Murmur Detected",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "$confidencePercent% confidence",
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildAnalysisRow("Type", analysis['type']),
          _buildAnalysisRow("Location", analysis['location']),
          _buildAnalysisRow("Grade", analysis['grade']),
          
          const SizedBox(height: 12),
          const Text(
            "Characteristics",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (analysis['characteristics'] as List<dynamic>).map((characteristic) {
              return Chip(
                label: Text(characteristic),
                backgroundColor: Colors.grey[200],
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          const Text(
            "Possible Causes",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            (analysis['possibleCauses'] as List<dynamic>).length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8),
                  const SizedBox(width: 8),
                  Text(analysis['possibleCauses'][index]),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Text(
            "Note: This analysis is for informational purposes only. Please consult with a healthcare professional for proper diagnosis.",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
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
      _logger.severe("Failed to play recording: $e");
      if (!mounted) return;
      _showErrorSnackBar("Failed to play recording: $e");
    }
  }
}