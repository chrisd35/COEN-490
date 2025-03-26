import 'package:coen_490/utils/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../utils/models.dart';
import '../registration/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Create a logger instance
final _logger = logging.Logger('ECGHistory');

// Design theme constants to match the app
class ECGHistoryTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors
  static const Color successColor = Color(0xFF2E7D32); // Darker green
  static const Color warningColor = Color(0xFFF57F17); // Amber shade
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red
  
  // Text colors
  static const Color textPrimary = Color(0xFF263238);   // Darker for contrast
  static const Color textSecondary = Color(0xFF546E7A); // Medium dark for subtext
  static const Color textLight = Color(0xFF78909C);     // Light text
  
  // Card shadow
  static final cardShadow = BoxShadow(
    color: Colors.black.withAlpha(18),  
    blurRadius: 12,
    spreadRadius: 0,
    offset: const Offset(0, 3),
  );
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
}

/// The ECG History screen for browsing saved ECG recordings
class ECGHistory extends StatefulWidget {
  final String? preselectedPatientId;

  const ECGHistory({super.key, this.preselectedPatientId});

  @override
  State<ECGHistory> createState() => _ECGHistoryState();
}

class _ECGHistoryState extends State<ECGHistory> {
  final FirebaseService _firebaseService = FirebaseService();
  List<ECGReading> readings = [];
  bool isLoading = true;
  ECGReading? selectedReading;
  String? patientName;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPatientId != null) {
      _loadReadingsForPatient(widget.preselectedPatientId!);
      
      // Debug info loading with delay
      Future.delayed(const Duration(seconds: 2), _debugECGInfo);
    }
  }
  /// Load ECG readings for a patient
  Future<void> _loadReadingsForPatient(String medicalCardNumber) async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load patient details
      final patient = await _firebaseService.getPatient(
        currentUser.uid,
        medicalCardNumber,
      );

      // Load ECG readings
      final loadedReadings = await _firebaseService.getECGReadings(
        currentUser.uid,
        medicalCardNumber,
      );

      // Check if widget is still mounted before using setState
      if (!mounted) return;

      setState(() {
        readings = loadedReadings.map((data) => ECGReading.fromMap(data)).toList();
        // Sort readings by timestamp, newest first
        readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        patientName = patient?.fullName ?? 'Unknown Patient';
        isLoading = false;
        if (readings.isNotEmpty) {
          selectedReading = readings.first;
        }
      });
    } catch (e) {
      _logger.severe('Error loading ECG readings: $e');
      
      // Check if widget is still mounted before using setState
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading ECG readings: ${e.toString()}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: ECGHistoryTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// Debug method to fix any issues with ECG download URLs
  void _debugECGInfo() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      if (widget.preselectedPatientId != null) {
        // Get raw data from Firebase directly to inspect it
        final databaseRef = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://respirhythm-default-rtdb.firebaseio.com/',
        ).ref();
        
        String sanitizedMedicalCard = widget.preselectedPatientId!.replaceAll('/', '_');
        
        final snapshot = await databaseRef
          .child('users')
          .child(currentUser.uid)
          .child('patients')
          .child(sanitizedMedicalCard)
          .child('ecgData')
          .get();
        
        _logger.info('DEBUG - Raw ECG data snapshot exists: ${snapshot.exists}');
        
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          _logger.info('DEBUG - Number of ECG readings: ${data.length}');
          
          // Examine each recording
          int index = 0;
          bool hasFixedAnyUrl = false;
          
          for (var entry in data.entries) {
            _logger.info('DEBUG - ECG Entry $index (ID: ${entry.key}):');
            final recording = entry.value as Map<dynamic, dynamic>;
            
            // Print all keys and values
            recording.forEach((key, value) {
              _logger.info('  $key: $value');
            });
            
            // Check if download URL exists and if it's valid
            bool urlIsValid = false;
            if (recording.containsKey('downloadUrl') && recording['downloadUrl'] != null) {
              final url = recording['downloadUrl'] as String;
              _logger.info('  Testing URL: $url');
              
              try {
                // Try to get metadata for the file
                final ref = FirebaseStorage.instance.refFromURL(url);
                final metadata = await ref.getMetadata();
                _logger.info('  URL is valid. Size: ${metadata.size}, Content Type: ${metadata.contentType}');
                urlIsValid = true;
              } catch (e) {
                _logger.warning('  URL is invalid: $e');
              }
            } else {
              _logger.warning('  No downloadUrl found in this entry');
            }
            
            // If URL is invalid or missing, try to fix it with the filename
            if (!urlIsValid && recording.containsKey('filename') && recording['filename'] != null) {
              final filename = recording['filename'] as String;
              _logger.info('  Testing direct access with filename: $filename');
              
              try {
                final ref = FirebaseStorage.instance.ref(filename);
                final metadata = await ref.getMetadata();
                _logger.info('  Direct access is valid. Size: ${metadata.size}, Content Type: ${metadata.contentType}');
                
                // Try to generate a new download URL
                final newUrl = await ref.getDownloadURL();
                _logger.info('  Generated new URL: $newUrl');
                
                // Update the database with the new URL
                await databaseRef
                  .child('users')
                  .child(currentUser.uid)
                  .child('patients')
                  .child(sanitizedMedicalCard)
                  .child('ecgData')
                  .child(entry.key)
                  .update({'downloadUrl': newUrl});
                
                _logger.info('  Updated database with new URL');
                hasFixedAnyUrl = true;
              } catch (e) {
                _logger.warning('  Direct access failed: $e');
              }
            }
            
            index++;
            if (index >= 5) break; // Limit to first 5 entries to avoid log overflow
          }
          
          // If we've fixed any URLs, reload the readings
          if (hasFixedAnyUrl && mounted) {
            _logger.info('One or more URLs were fixed, reloading readings...');
            _loadReadingsForPatient(widget.preselectedPatientId!);
          }
        } else {
          _logger.warning('DEBUG - ECG data not found in database');
        }
      }
    } catch (e) {
      _logger.severe('Error in debug method: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        backgroundColor: ECGHistoryTheme.secondaryColor,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  /// Build app bar with title
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        patientName ?? 'ECG History',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ECGHistoryTheme.textPrimary,
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: ECGHistoryTheme.primaryColor,
        ),
        onPressed: () => NavigationService.goBack(),
      ),
    );
  }

  /// Build main body content based on state
  Widget _buildBody() {
    if (isLoading) {
      return _buildLoadingState();
    } else if (readings.isEmpty) {
      return _buildEmptyState();
    } else {
      return _buildContentState();
    }
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ECGHistoryTheme.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading ECG recordings...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: ECGHistoryTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state when no readings are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: Colors.grey[400],
          ).animate().scale(
            duration: 400.ms,
            curve: Curves.easeOut,
          ),
          const SizedBox(height: 16),
          Text(
            'No ECG recordings found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: ECGHistoryTheme.textSecondary,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          const SizedBox(height: 8),
          Text(
            'Record an ECG to see it here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ECGHistoryTheme.textLight,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
        ],
      ),
    );
  }

  /// Build content state when readings are available
  Widget _buildContentState() {
    return Column(
      children: [
        _buildRecordingSelector(),
        if (selectedReading != null && selectedReading!.downloadUrl != null)
          _buildViewECGCard(),
      ],
    );
  }

  /// Build dropdown selector for recordings
  Widget _buildRecordingSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: ECGHistoryTheme.borderRadius,
          boxShadow: [ECGHistoryTheme.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: ECGHistoryTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Recording',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ECGHistoryTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ECGHistoryTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: DropdownButton<ECGReading>(
                    isExpanded: true,
                    value: selectedReading,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ECGHistoryTheme.primaryColor,
                    ),
                    items: readings.map((reading) {
                      return DropdownMenuItem(
                        value: reading,
                        child: Text(
                          DateFormat('MMM dd, yyyy - HH:mm:ss')
                              .format(reading.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: ECGHistoryTheme.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (reading) {
                      setState(() {
                        selectedReading = reading;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
  /// Build card with button to view selected ECG
  Widget _buildViewECGCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: ECGHistoryTheme.borderRadius,
      ),
      elevation: 0,
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: ECGHistoryTheme.borderRadius,
          boxShadow: [ECGHistoryTheme.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recording details 
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: ECGHistoryTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recording Details',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ECGHistoryTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Details grid
            Row(
              children: [
                _buildDetailItem(
                  icon: Icons.timer_outlined, 
                  label: 'Duration', 
                  value: '${selectedReading!.duration} sec'
                ),
                _buildDetailItem(
                  icon: Icons.speed_outlined, 
                  label: 'Sample Rate', 
                  value: '${selectedReading!.sampleRate} Hz'
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // View button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToECGViewer();
                },
                icon: const Icon(Icons.show_chart_rounded),
                label: Text(
                  'View ECG Data',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ECGHistoryTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: ECGHistoryTheme.buttonRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  /// Build a detail item with icon, label and value
  Widget _buildDetailItem({
    required IconData icon, 
    required String label, 
    required String value
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: ECGHistoryTheme.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: ECGHistoryTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ECGHistoryTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to ECG viewer screen
  void _navigateToECGViewer() {
    _logger.info('Navigation attempt with reading: ${selectedReading?.filename}');
    _logger.info('Download URL: ${selectedReading?.downloadUrl}');
    
    NavigationService.navigateTo(
      AppRoutes.ecgViewer,
      arguments: {
        'reading': selectedReading,
        'patientName': patientName ?? 'Unknown Patient',
      },
    );
  }
}
