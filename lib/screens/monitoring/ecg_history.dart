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
                                    NavigationService.navigateTo(
                                      'ecg_viewer',
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
  
  // Removed unused _buildDetailRow method
}