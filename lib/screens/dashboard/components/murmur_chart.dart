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

class AppTheme {
  // Updated Main color palette with navy theme
  static const Color primaryColor = Color(0xFF1D3461); // Navy blue
  static const Color secondaryColor =
      Color(0xFFE6EDF4); // Light navy background
  static const Color accentColor = Color(0xFF1E5187); // Medium navy blue

  // Feature card colors - navy-focused palette
  static final List<Color> featureCardColors = [
    const Color(0xFF1D3461), // Deep navy
    const Color(0xFF1E5187), // Medium navy
    const Color(0xFF246BAF), // Bright navy
    const Color(0xFF152B4E), // Dark navy
    const Color(0xFF0F4C81), // Ocean navy
    const Color(0xFF2C5F8E), // Steel navy
    const Color(0xFF1B4F72), // Muted navy
  ];

  // Status colors - refined for navy theme
  static const Color successColor = Color(0xFF1B5E20); // Dark green
  static const Color warningColor = Color(0xFF1D3461); // Navy warning
  static const Color errorColor = Color(0xFFB71C1C); // Dark red

  // Text colors - adjusted for navy theme
  static const Color textPrimary = Color(0xFF1D3461); // Navy text
  static const Color textSecondary = Color(0xFF3A5378); // Medium navy
  static const Color textLight = Color(0xFF6B84A5); // Light navy
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
      final user = auth.FirebaseAuth.instance.currentUser;
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

      if (analysis['features'] == null) {
        throw Exception("Analysis features are missing");
      }
      final features = analysis['features'] as Map<String, dynamic>;
      final type = _parseMurmurType(features);
      final location = _parseMurmurLocation(features);
      final grade = _parseMurmurGrade(features);
      final hasMurmur = analysis['prediction'] == "Abnormal";
      final suggestions = _parseSuggestions(features);
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
    } else if (type.contains('Diastolic')) {
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
    } else {
      causes.add('Innocent or functional murmur');
      causes.add('Valve pathology requiring further investigation');
      causes.add('Possible structural heart disease');
    }
    return causes;
  }

  String _parseMurmurType(Map<String, dynamic> features) {
    final systoleMean = features['Systole_Mean'] ?? 0.0;
    final wavelet1Energy = features['Wavelet_1_Energy'] ?? 0.0;
    final wavelet2Shannon = features['Wavelet_2_Shannon'] ?? 0.0;
    final energy200400 = features['Energy_200_400Hz'] ?? 0.0;

    if (systoleMean > 0.75 && wavelet1Energy > 0.65) {
      return 'Systolic ejection murmur';
    }
    if (wavelet2Shannon > 4.2 && energy200400 < 0.4) {
      return 'Diastolic murmur';
    }
    return 'Undetermined type';
  }

  String _parseMurmurLocation(Map<String, dynamic> features) {
    final energy200400 = features['Energy_200_400Hz'] ?? 0.0;
    final wavelet1Shannon = features['Wavelet_1_Shannon'] ?? 0.0;
    final energy150300 = features['Energy_150_300Hz'] ?? 0.0;
    final wavelet2Energy = features['Wavelet_2_Energy'] ?? 0.0;
    final energy50150 = features['Energy_50_150Hz'] ?? 0.0;
    final mfcc7 = features['MFCC_mean_7'] ?? 0.0;
    final mfcc13 = features['MFCC_mean_13'] ?? 0.0;
    final energy100200 = features['Energy_100_200Hz'] ?? 0.0;

    if (energy200400 > 0.7 && wavelet1Shannon > 3.8) {
      return 'Aortic area (right 2nd intercostal space)';
    }
    if (energy150300 > 0.65 && wavelet2Energy > 0.55) {
      return 'Pulmonic area (left 2nd intercostal space)';
    }
    if (energy50150 > 0.6 && mfcc7 > 0.3) {
      return 'Tricuspid area (left 4th intercostal space)';
    }
    if (mfcc13 < -0.4 && energy100200 > 0.6) {
      return 'Mitral area (cardiac apex)';
    }
    return 'General cardiac area';
  }

  String _parseMurmurGrade(Map<String, dynamic> features) {
    final systoleMean = features['Systole_Mean'] ?? 0.0;
    final systoleStd = features['Systole_Std'] ?? 0.0;
    final hr = features['HeartRate'] ?? 72.0;
    final systoleScore = (systoleMean * 0.7) + (systoleStd * 0.3);

    if (systoleScore > 0.85 && hr > 100) return 'Grade 4/6';
    if (systoleScore > 0.7) return 'Grade 3/6';
    if (systoleScore > 0.55) return 'Grade 2/6';
    return 'Grade 1/6';
  }

  String _parseSuggestions(Map<String, dynamic> features) {
    final hr = features['HeartRate'] ?? 72;
    final systoleMean = features['Systole_Mean'] ?? 0.0;
    final waveletEnergy = features['Wavelet_1_Energy'] ?? 0.0;
    final highFreqEnergy = features['Energy_200_400Hz'] ?? 0.0;
    final mfcc13 = features['MFCC_mean_13'] ?? 0.0;
    final midFreqEnergy = features['Energy_100_200Hz'] ?? 0.0;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.secondaryColor,
        foregroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => NavigationService.goBack(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (widget.preselectedPatientId == null)
                  _buildPatientSelector(),
                if (_selectedPatient != null)
                  Container(
                    height: 250,
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

  // --- Updated Patient Selector with DropdownButtonFormField ---
  Widget _buildPatientSelector() {
    if (_patients == null) {
      return Center(
          child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
      ));
    }
    if (_patients!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No patients found",
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.secondaryColor, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Patient",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: DropdownButtonFormField<Patient>(
                value: _selectedPatient,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: TextStyle(color: AppTheme.textLight),
                ),
                icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
                dropdownColor: Colors.white,
                menuMaxHeight: 300,
                hint: Text("Choose a patient"),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        patient.fullName,
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Updated Recordings List with refined ListTiles ---
  Widget _buildRecordingsList() {
    if (_recordings == null) {
      return Center(
          child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
      ));
    }
    if (_recordings!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "No recordings found for this patient",
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _recordings!.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final recording = _recordings![index];
        final isSelected = _selectedRecording == recording;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.audio_file,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            title: Text(
              "Recording ${index + 1}",
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              recording.timestamp.toString(),
              style: TextStyle(color: AppTheme.textLight),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying && _selectedRecording == recording
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () => _playRecording(recording),
                ),
                IconButton(
                  icon: Icon(
                    Icons.analytics_outlined,
                    color: AppTheme.accentColor,
                  ),
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

  // --- Updated Playback Controls with Lottie Animation ---
  Widget _buildPlaybackControls() {
    String formatTime(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$minutes:$seconds";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            max: _duration.inSeconds.toDouble() > 0
                ? _duration.inSeconds.toDouble()
                : 1,
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
