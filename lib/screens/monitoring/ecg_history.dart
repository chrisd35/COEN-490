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
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('ECGHistory');

class ECGHistory extends StatefulWidget {
  final String? preselectedPatientId;

  // Use super parameter syntax for key
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
    
    // Add this line:
    Future.delayed(const Duration(seconds: 2), _debugECGInfo);
  }
}

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patientName ?? 'ECG History'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationService.goBack(),
          ),
        ),
        body: isLoading 
            ? const Center(child: CircularProgressIndicator())
            : readings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ECG recordings found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: DropdownButton<ECGReading>(
                              isExpanded: true,
                              value: selectedReading,
                              items: readings.map((reading) {
                                return DropdownMenuItem(
                                  value: reading,
                                  child: Text(
                                    DateFormat('MMM dd, yyyy - HH:mm:ss')
                                        .format(reading.timestamp),
                                    style: const TextStyle(fontSize: 16),
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
                      ),
                      if (selectedReading != null && selectedReading!.downloadUrl != null) ...[
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
  onPressed: () {
    _logger.info('Navigation attempt with reading: ${selectedReading?.filename}');
    _logger.info('Download URL: ${selectedReading?.downloadUrl}');
    
    NavigationService.navigateTo(
      AppRoutes.ecgViewer,  // Make sure you use the constant instead of a string
      arguments: {
        'reading': selectedReading,
        'patientName': patientName ?? 'Unknown Patient',
      },
    );
  },
  icon: const Icon(Icons.show_chart),
  label: const Text('View ECG Data'),
),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

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
  
  // Removed unused _buildDetailRow method
}