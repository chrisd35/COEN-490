import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '/utils/models.dart';
import '../../registration/auth_service.dart';
import '../../registration/firebase_service.dart';
import '../../../utils/navigation_service.dart';
import '../../../utils/app_routes.dart';
import '../../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Create a logger instance
final _logger = logging.Logger('RecordingPlaybackScreen');

// Design constants class to maintain consistency with dashboard_screen.dart
class PlaybackTheme {
  // Main color palette - using the same blue scheme as dashboard
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors
  static const Color successColor = Color(0xFF2E7D32); // Darker green
  static const Color warningColor = Color(0xFFF57F17); // Amber shade
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red
  
  // Text colors
  static const Color textPrimary = Color(0xFF263238);   // Primary text color
  static const Color textSecondary = Color(0xFF546E7A); // Secondary text color
  static const Color textLight = Color(0xFF78909C);     // Light text color
  
  // Card colors
  static final List<Color> cardColors = [
    const Color(0xFF1D557E),  // Primary blue
    const Color(0xFF2E86C1),  // Medium blue
    const Color(0xFF3498DB),  // Light blue
    const Color(0xFF0D47A1),  // Deep blue
    const Color(0xFF039BE5),  // Sky blue
  ];
  
  // Shadows
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
  
  // Text styles
  static final TextStyle headingStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  static final TextStyle subheadingStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: -0.2,
    height: 1.4,
  );
  
  static final TextStyle cardTitleStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  static final TextStyle buttonTextStyle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );
  
  // Animation durations
  static const Duration defaultAnimDuration = Duration(milliseconds: 300);
  static const Duration quickAnimDuration = Duration(milliseconds: 150);
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
}
class RecordingPlaybackScreen extends StatefulWidget {
  final String? preselectedPatientId;

  const RecordingPlaybackScreen({super.key, this.preselectedPatientId});

  @override
  State<RecordingPlaybackScreen> createState() => _RecordingPlaybackScreenState();
}

class _RecordingPlaybackScreenState extends State<RecordingPlaybackScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Patient>? _patients;
  Patient? _selectedPatient;
  List<Recording>? _recordings;
  Recording? _selectedRecording;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    
    _animationController = AnimationController(
      vsync: this,
      duration: PlaybackTheme.defaultAnimDuration,
    );
    
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26), 
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: PlaybackTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Login Required',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PlaybackTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You need to be logged in to access recordings. Do you have an account?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: PlaybackTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => NavigationService.goBack(),
                        style: TextButton.styleFrom(
                          foregroundColor: PlaybackTheme.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PlaybackTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                    backgroundColor: Colors.white,
                    foregroundColor: PlaybackTheme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: PlaybackTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: PlaybackTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
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
        backgroundColor: PlaybackTheme.secondaryColor,
        appBar: AppBar(
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: PlaybackTheme.textPrimary,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: PlaybackTheme.textPrimary,
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
      return Expanded(
        child: Center(
          child: CircularProgressIndicator(
            color: PlaybackTheme.primaryColor,
          ).animate()
            .fadeIn(duration: const Duration(milliseconds: 300))
            .shimmer(delay: const Duration(milliseconds: 1000), duration: const Duration(milliseconds: 1000)),
        ),
      );
    }

    if (_patients!.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64, 
                color: Colors.grey[400],
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
              const SizedBox(height: 16),
              Text(
                "No patients found",
                style: GoogleFonts.inter(
                  fontSize: 16, 
                  color: PlaybackTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)).slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PlaybackTheme.borderRadius,
        boxShadow: [PlaybackTheme.subtleShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Patient",
              style: PlaybackTheme.cardTitleStyle,
            ).animate().fadeIn(duration: const Duration(milliseconds: 400)).slideY(begin: -0.2, end: 0),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: DropdownButtonFormField<Patient>(
                isExpanded: true,
                value: _selectedPatient,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  hintText: "Choose a patient",
                  hintStyle: GoogleFonts.inter(
                    color: PlaybackTheme.textLight,
                    fontSize: 14,
                  ),
                ),
                icon: Icon(Icons.keyboard_arrow_down, color: PlaybackTheme.primaryColor),
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
                    child: Text(
                      patient.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: PlaybackTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ).animate().fadeIn(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 100)).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingsList() {
    if (_recordings == null) {
      return Expanded(
        child: Center(
          child: CircularProgressIndicator(
            color: PlaybackTheme.primaryColor,
          ).animate()
            .fadeIn(duration: const Duration(milliseconds: 300))
            .shimmer(delay: const Duration(milliseconds: 1000), duration: const Duration(milliseconds: 1000)),
        ),
      );
    }

    if (_recordings!.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_outlined, 
                size: 64, 
                color: Colors.grey[400],
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
              const SizedBox(height: 16),
              Text(
                "No recordings found for this patient",
                style: GoogleFonts.inter(
                  fontSize: 16, 
                  color: PlaybackTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)).slideY(begin: 0.2, end: 0),
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PlaybackTheme.borderRadius,
        boxShadow: [PlaybackTheme.subtleShadow],
        border: isSelected 
            ? Border.all(color: PlaybackTheme.primaryColor, width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: PlaybackTheme.borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedRecording = recording;
                _position = Duration.zero;
              });
            },
            splashColor: PlaybackTheme.primaryColor.withAlpha(26),
            highlightColor: PlaybackTheme.primaryColor.withAlpha(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Recording icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: PlaybackTheme.primaryColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.audio_file,
                          color: PlaybackTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Recording details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Recording ${index + 1}",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: PlaybackTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(recording.timestamp),
                              style: GoogleFonts.inter(
                                color: PlaybackTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Play button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              PlaybackTheme.primaryColor,
                              const Color(0xFF23689B), // Slightly darker shade
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: PlaybackTheme.primaryColor.withAlpha(51),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _playRecording(recording),
                            borderRadius: BorderRadius.circular(12),
                            child: Icon(
                              _isPlaying && _selectedRecording == recording
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Recording details section (shown only when selected)
                if (isSelected)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: PlaybackTheme.secondaryColor,
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Recording Details",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PlaybackTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                Icons.calendar_today_outlined,
                                "Recorded",
                                "${recording.timestamp.day}/${recording.timestamp.month}/${recording.timestamp.year}",
                              ),
                            ),
                            Expanded(
                              child: _buildDetailItem(
                                Icons.access_time,
                                "Time",
                                "${recording.timestamp.hour}:${recording.timestamp.minute.toString().padLeft(2, '0')}",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                Icons.timer_outlined,
                                "Duration",
                                "${recording.duration} seconds",
                              ),
                            ),
                            Expanded(
                              child: _buildDetailItem(
                                Icons.graphic_eq,
                                "Sample Rate",
                                "${recording.sampleRate ~/ 1000} kHz",
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400), delay: Duration(milliseconds: 100 * index)).slideY(begin: 0.2, end: 0);
  }
  
  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: PlaybackTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: PlaybackTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PlaybackTheme.textPrimary,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          // Track progress
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 16,
              ),
              activeTrackColor: PlaybackTheme.primaryColor,
              inactiveTrackColor: Colors.grey[200],
              thumbColor: PlaybackTheme.primaryColor,
              overlayColor: PlaybackTheme.primaryColor.withAlpha(51),
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
          
          // Time indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatTime(_position),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PlaybackTheme.textSecondary,
                  ),
                ),
                Text(
                  formatTime(_duration),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PlaybackTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rewind button
              _buildControlButton(
                Icons.replay_5,
                Colors.grey[300]!,
                PlaybackTheme.textPrimary,
                onTap: () async {
                  if (_position.inSeconds > 5) {
                    await _audioPlayer.seek(
                      Duration(seconds: _position.inSeconds - 5),
                    );
                  } else {
                    await _audioPlayer.seek(Duration.zero);
                  }
                },
              ),
              
              const SizedBox(width: 24),
              
              // Play/Pause button (larger)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PlaybackTheme.primaryColor,
                      const Color(0xFF23689B), // Slightly darker shade
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: PlaybackTheme.primaryColor.withAlpha(77),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(32),
                  child: InkWell(
                    onTap: () {
                      if (_selectedRecording != null) {
                        _playRecording(_selectedRecording!);
                      }
                    },
                    borderRadius: BorderRadius.circular(32),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 24),
              
              // Forward button
              _buildControlButton(
                Icons.forward_5,
                Colors.grey[300]!,
                PlaybackTheme.textPrimary,
                onTap: () async {
                  if (_position.inSeconds < _duration.inSeconds - 5) {
                    await _audioPlayer.seek(
                      Duration(seconds: _position.inSeconds + 5),
                    );
                  } else {
                    await _audioPlayer.seek(_duration);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 400)).slideY(begin: 0.2, end: 0);
  }
  // Helper method to build control buttons
  Widget _buildControlButton(
    IconData icon,
    Color backgroundColor,
    Color iconColor, {
    required VoidCallback onTap,
    double size = 48,
    double iconSize = 24,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(size/2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size/2),
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
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
    });

    try {
      if (recording.downloadUrl == null) {
        throw Exception("Download URL not available");
      }
      
      // Show loading indicator while preparing to play
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Preparing audio...",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: PlaybackTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      
      await _audioPlayer.play(UrlSource(recording.downloadUrl!));
    } catch (e) {
      _logger.severe("Failed to play recording: $e");
      if (!mounted) return;
      _showErrorSnackBar("Failed to play recording: $e");
    }
  }
}



