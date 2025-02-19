import 'package:coen_490/screens/monitoring/ecg_monitoring_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../utils/models.dart';
import '../registration/firebase_service.dart';

class ECGViewer extends StatefulWidget {
  final ECGReading reading;
  final String patientName;

  const ECGViewer({
    Key? key,
    required this.reading,
    required this.patientName,
  }) : super(key: key);

  @override
  _ECGViewerState createState() => _ECGViewerState();
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
    try {
      if (widget.reading.downloadUrl != null) {
        final firebaseService = FirebaseService();
        // Load ECG data from downloadUrl
        // Convert to points
        final response = await firebaseService.downloadECGData(widget.reading.downloadUrl!);
        
        setState(() {
          _points = response.asMap().entries
              .map((entry) => Point<double>(entry.key.toDouble(), entry.value.toDouble()))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading ECG data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _adjustZoom(double delta) {
    setState(() {
      zoomLevel = (zoomLevel * (1 + delta)).clamp(0.5, 5.0);
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('ECG Data - ${widget.patientName}'),
      actions: [
        IconButton(
          icon: Icon(Icons.zoom_in),
          onPressed: () => _adjustZoom(0.1),
        ),
        IconButton(
          icon: Icon(Icons.zoom_out),
          onPressed: () => _adjustZoom(-0.1),
        ),
      ],
    ),
    body: isLoading
        ? Center(child: CircularProgressIndicator())
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
                        Text(
                          'Recording Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
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
                      child: Container(
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
  );
}

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}