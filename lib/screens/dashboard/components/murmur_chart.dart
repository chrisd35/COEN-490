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
          uid, patient.medicalCardNumber);

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

  // Modify the _analyzeMurmur method to include better error handling
  Future<void> _analyzeMurmur(Recording recording) async {
    if (!mounted) return;

    setState(() {
      _isAnalyzing = true;
      _murmurAnalysis = null;
    });

    try {
      final analysis =
          await _firebaseService.analyzeRecording(recording.filename);

      if (!mounted) return;

      // Check if features exist in the analysis
      if (analysis['features'] == null) {
        throw Exception("Analysis features are missing");
      }

      // Ensure features is a Map
      final features = analysis['features'] as Map<String, dynamic>;

      // Determine murmur type, location, and grade
      final type = _parseMurmurType(features);
      final location = _parseMurmurLocation(features);
      final grade = _parseMurmurGrade(features);
      final hasMurmur = analysis['prediction'] == "Abnormal";
      final suggestions = _parseSuggestions(features);

      // Generate causes based on type, location, grade and murmur detection
      List<String> causes = _generateCauses(hasMurmur, type, location, grade);

      setState(() {
        _murmurAnalysis = {
          'hasMurmur': hasMurmur,
          'confidence': analysis['confidence'] ?? 0.75,
          'type': type,
          'location': location,
          'grade': grade,
          'suggestions': suggestions,
          'possibleCauses': causes,
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

  List<String> _generateCauses(
      bool hasMurmur, String type, String location, String grade) {
    if (!hasMurmur) {
      return ['Normal physiological heart sounds'];
    }

    List<String> causes = [];

    // Systolic murmur causes
    if (type.contains('Systolic')) {
      if (location.contains('Aortic')) {
        causes.add('Aortic stenosis');
        causes.add('Hypertrophic cardiomyopathy');
        if (grade.contains('3/6') || grade.contains('4/6')) {
          causes.add('Severe aortic valve calcification');
        }
      } else if (location.contains('Pulmonic')) {
        causes.add('Pulmonary stenosis');
        causes.add('Pulmonary hypertension');
      } else if (location.contains('Mitral')) {
        causes.add('Mitral valve prolapse');
        causes.add('Mitral regurgitation');
      } else if (location.contains('Tricuspid')) {
        causes.add('Tricuspid regurgitation');
      } else {
        causes.add('Ventricular septal defect');
        causes.add('Flow murmur');
      }
    }
    // Diastolic murmur causes
    else if (type.contains('Diastolic')) {
      if (location.contains('Aortic')) {
        causes.add('Aortic regurgitation');
      } else if (location.contains('Pulmonic')) {
        causes.add('Pulmonary regurgitation');
      } else if (location.contains('Mitral')) {
        causes.add('Mitral stenosis');
      } else if (location.contains('Tricuspid')) {
        causes.add('Tricuspid stenosis');
      } else {
        causes.add('Diastolic cardiac dysfunction');
      }
    }
    // Undetermined
    else {
      causes.add('Innocent or functional murmur');
      causes.add('Valve pathology requiring further investigation');
      causes.add('Possible structural heart disease');
    }

    return causes;
  }

  // Updated _parseMurmurType method with null checks
  String _parseMurmurType(Map<String, dynamic> features) {
    // Add null safety checks
    final systoleMean = features['Systole_Mean'] ?? 0.0;
    final wavelet1Energy = features['Wavelet_1_Energy'] ?? 0.0;
    final wavelet2Shannon = features['Wavelet_2_Shannon'] ?? 0.0;
    final energy200400 = features['Energy_200_400Hz'] ?? 0.0;

    // Systolic characteristics
    if (systoleMean > 0.75 && wavelet1Energy > 0.65) {
      return 'Systolic ejection murmur';
    }
    // Diastolic characteristics
    if (wavelet2Shannon > 4.2 && energy200400 < 0.4) {
      return 'Diastolic murmur';
    }
    return 'Undetermined type';
  }

  // Updated _parseMurmurLocation method with null checks
  String _parseMurmurLocation(Map<String, dynamic> features) {
    // Add null safety checks
    final energy200400 = features['Energy_200_400Hz'] ?? 0.0;
    final wavelet1Shannon = features['Wavelet_1_Shannon'] ?? 0.0;
    final energy150300 = features['Energy_150_300Hz'] ?? 0.0;
    final wavelet2Energy = features['Wavelet_2_Energy'] ?? 0.0;
    final energy50150 = features['Energy_50_150Hz'] ?? 0.0;
    final mfcc7 = features['MFCC_mean_7'] ?? 0.0;
    final mfcc13 = features['MFCC_mean_13'] ?? 0.0;
    final energy100200 = features['Energy_100_200Hz'] ?? 0.0;

    // Aortic area detection
    if (energy200400 > 0.7 && wavelet1Shannon > 3.8) {
      return 'Aortic area (right 2nd intercostal space)';
    }

    // Pulmonic area detection
    if (energy150300 > 0.65 && wavelet2Energy > 0.55) {
      return 'Pulmonic area (left 2nd intercostal space)';
    }

    // Tricuspid area detection
    if (energy50150 > 0.6 && mfcc7 > 0.3) {
      return 'Tricuspid area (left 4th intercostal space)';
    }

    // Mitral area detection
    if (mfcc13 < -0.4 && energy100200 > 0.6) {
      return 'Mitral area (cardiac apex)';
    }

    return 'General cardiac area';
  }

  // Updated _parseMurmurGrade method with null checks
  String _parseMurmurGrade(Map<String, dynamic> features) {
    // Add null safety checks
    final systoleMean = features['Systole_Mean'] ?? 0.0;
    final systoleStd = features['Systole_Std'] ?? 0.0;
    final hr = features['HeartRate'] ?? 72.0;

    // Grade based on systole characteristics and heart rate
    final systoleScore = (systoleMean * 0.7) + (systoleStd * 0.3);

    if (systoleScore > 0.85 && hr > 100) return 'Grade 4/6';
    if (systoleScore > 0.7) return 'Grade 3/6';
    if (systoleScore > 0.55) return 'Grade 2/6';
    return 'Grade 1/6';
  }

  String _parseSuggestions(Map<String, dynamic> features) {
    // Add null safety checks for all feature accesses
    final hr = features['HeartRate'] ?? 72;
    final systoleMean = features['Systole_Mean'] ?? 0.0;
    final waveletEnergy = features['Wavelet_1_Energy'] ?? 0.0;
    final highFreqEnergy = features['Energy_200_400Hz'] ?? 0.0;
    final mfcc13 = features['MFCC_mean_13'] ?? 0.0;
    final midFreqEnergy = features['Energy_100_200Hz'] ?? 0.0;

    // Suggestion based on various features
    if (systoleMean > 0.7 && waveletEnergy > 0.6) {
      return 'Recommend auscultation in multiple positions';
    } else if (highFreqEnergy > 0.6 && hr > 90) {
      return 'Consider ECG for further evaluation';
    } else if (mfcc13 < -0.3 && midFreqEnergy > 0.5) {
      return 'Consider echocardiogram';
    }

    return 'Standard follow-up recommended';
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
          content: const Text(
              'You need to be logged in to access recordings. Do you have an account?'),
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
          // Wrap the entire body in a SingleChildScrollView
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (widget.preselectedPatientId == null)
                  _buildPatientSelector(),
                if (_selectedPatient != null)
                  Container(
                    height: 250, // Fixed height for recordings list
                    child: _buildRecordingsList(),
                  ),
                if (_selectedRecording != null) _buildPlaybackControls(),
                if (_murmurAnalysis != null) _buildMurmurAnalysis(),
              ],
            ),
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
                fontSize: 16, // reduced from 18
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

    return ListView.builder(
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
                analysis['hasMurmur']
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                color: analysis['hasMurmur'] ? Colors.orange : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  analysis['hasMurmur']
                      ? "Murmur Detected"
                      : "No Murmur Detected",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
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
                    fontSize: 14,
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
          _buildAnalysisRow("Suggested Action", analysis['suggestions']),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Possible Causes",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  (analysis['possibleCauses'] as List<dynamic>).length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            analysis['possibleCauses'][index],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Note: This analysis is for informational purposes only. Please consult with a healthcare professional for proper diagnosis.",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
            softWrap: true,
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
      _logger.severe("Failed to play recording: $e");
      if (!mounted) return;
      _showErrorSnackBar("Failed to play recording: $e");
    }
  }
}
