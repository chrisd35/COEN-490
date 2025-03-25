import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../utils/models.dart';
import '../registration/firebase_service.dart';
import '../monitoring/ecg_monitoring_screen.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('ECGViewer');

class ECGViewer extends StatefulWidget {
  final ECGReading reading;
  final String patientName;

  // Use super parameter syntax for key
  const ECGViewer({
    super.key,
    required this.reading,
    required this.patientName,
  });

  @override
  State<ECGViewer> createState() => _ECGViewerState();
}

class _ECGViewerState extends State<ECGViewer> {
  List<Point<double>> _points = [];
  bool isLoading = true;
  double zoomLevel = 1.0;
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadECGData();
  }

 Future<void> _loadECGData() async {
  setState(() {
    isLoading = true;
  });
  
  try {
    _logger.info('Starting ECG data load for reading: ${widget.reading.filename}');
    
    if (widget.reading.downloadUrl != null && widget.reading.downloadUrl!.isNotEmpty) {
      _logger.info('Using provided download URL: ${widget.reading.downloadUrl}');
      await _tryLoadWithUrl(widget.reading.downloadUrl!);
    } else if (widget.reading.filename.isNotEmpty) {
      _logger.info('No download URL available, trying with filename: ${widget.reading.filename}');
      await _tryLoadWithFilename(widget.reading.filename);
    } else {
      throw Exception('Neither download URL nor filename available');
    }
    
    if (_points.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load ECG data - empty result'),
          backgroundColor: Colors.red,
        )
      );
      setState(() {
        isLoading = false;
      });
    }
  } catch (e) {
    _logger.severe('Error in _loadECGData: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading ECG data: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
      setState(() {
        isLoading = false;
      });
    }
  }
}

Future<void> _tryLoadWithUrl(String url) async {
  try {
    _logger.info('Attempting to load ECG data with URL: $url');
    final firebaseService = FirebaseService();
    final ecgData = await firebaseService.downloadECGData(url);
    
    if (!mounted) return;
    
    if (ecgData.isNotEmpty) {
      _logger.info('Successfully loaded ${ecgData.length} data points with URL');
      setState(() {
        _points = ecgData.asMap().entries
            .map((entry) => Point<double>(entry.key.toDouble(), entry.value.toDouble()))
            .toList();
        isLoading = false;
      });
    } else {
      _logger.warning('URL returned empty data, trying with filename instead');
      await _tryLoadWithFilename(widget.reading.filename);
    }
  } catch (e) {
    _logger.warning('Error loading with URL: $e');
    // If URL fails, try with filename
    await _tryLoadWithFilename(widget.reading.filename);
  }
}

Future<void> _tryLoadWithFilename(String filename) async {
  try {
    _logger.info('Attempting to load ECG data with filename: $filename');
    final storage = FirebaseStorage.instance;
    final ref = storage.ref(filename);
    
    // Get a fresh download URL and update it in the database
    final newUrl = await ref.getDownloadURL();
    _logger.info('Generated new download URL: $newUrl');
    
    // Update the URL in the database if we can
    _updateDownloadUrlInDatabase(filename, newUrl);
    
    // Download the data using the new URL
    final firebaseService = FirebaseService();
    final ecgData = await firebaseService.downloadECGData(newUrl);
    
    if (!mounted) return;
    
    if (ecgData.isNotEmpty) {
      _logger.info('Successfully loaded ${ecgData.length} data points with filename');
      setState(() {
        _points = ecgData.asMap().entries
            .map((entry) => Point<double>(entry.key.toDouble(), entry.value.toDouble()))
            .toList();
        isLoading = false;
      });
    } else {
      throw Exception('Failed to load ECG data from file');
    }
  } catch (e) {
    _logger.severe('Error loading with filename: $e');
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
    rethrow;
  }
}

Future<void> _updateDownloadUrlInDatabase(String filename, String newUrl) async {
  try {
    // Extract patient ID from filename
    // Assuming format like: users/[uid]/patients/[patientId]/ecg/...
    final parts = filename.split('/');
    if (parts.length < 5) return; // Not enough parts
    
    final uid = parts[1];
    String patientId = parts[3];
    
    // Find the record in the database
    final databaseRef = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://respirhythm-default-rtdb.firebaseio.com/',
    ).ref();
    
    final snapshot = await databaseRef
      .child('users')
      .child(uid)
      .child('patients')
      .child(patientId)
      .child('ecgData')
      .get();
    
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      
      // Find the record with this filename
      for (var entry in data.entries) {
        final record = entry.value as Map<dynamic, dynamic>;
        if (record['filename'] == filename) {
          // Update the download URL
          await databaseRef
            .child('users')
            .child(uid)
            .child('patients')
            .child(patientId)
            .child('ecgData')
            .child(entry.key)
            .update({'downloadUrl': newUrl});
          
          _logger.info('Updated downloadUrl in database for $filename');
          break;
        }
      }
    }
  } catch (e) {
    _logger.warning('Failed to update download URL in database: $e');
    // Continue even if we fail to update
  }
}


  void _adjustZoom(double delta) {
    setState(() {
      zoomLevel = (zoomLevel * (1 + delta)).clamp(0.5, 5.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ECG Data - ${widget.patientName}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationService.goBack(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () => _adjustZoom(0.1),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: () => _adjustZoom(-0.1),
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recording Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Duration: ${widget.reading.duration} seconds'),
                            Text('Sample Rate: ${widget.reading.sampleRate} Hz'),
                            Text('Date: ${DateFormat('MMM dd, yyyy - HH:mm:ss').format(widget.reading.timestamp)}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Constrain the height of the ECG graph
                        height: 300, // Set a fixed height for the graph
                        child: SingleChildScrollView(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox( // Changed from Container to SizedBox
                            width: _points.length * 2.0 * zoomLevel,
                            height: 300, // Match the height of the parent container
                            child: CustomPaint(
                              painter: ECGPainter(
                                points: _points,
                                minY: 0,
                                maxY: 4095,
                                zoomLevel: zoomLevel,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}