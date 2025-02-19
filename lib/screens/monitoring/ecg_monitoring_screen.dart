import 'package:flutter/material.dart';
import 'dart:ui' as ui show TextDirection;
import 'dart:math' show Point, max, min, pi, pow, sqrt;
import '../../utils/ble_manager.dart';
import '../registration/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/models.dart';
import 'package:intl/intl.dart';
import '../monitoring/oxygen_monitoring_screen.dart'; 
import '../monitoring/ecg_history.dart';


class ECGMonitoring extends StatefulWidget {
  final String? uid;
  final String? medicalCardNumber;
  final BLEManager bleManager;

  const ECGMonitoring({
    Key? key,
    this.uid,
    this.medicalCardNumber,
    required this.bleManager,
  }) : super(key: key);

  @override
  _ECGMonitoringState createState() => _ECGMonitoringState();
}

class _ECGMonitoringState extends State<ECGMonitoring> {
  final List<Point<double>> _points = [];
  final double minY = 0;
  final double maxY = 4095;
  double zoomLevel = 1.0;

   double currentHeartRate = 0.0;
  double rrInterval = 0.0;
  double signalQuality = 0.0;
  List<int> rPeakIndices = [];
  double rPeakThreshold = 3000; // Adjusted threshold
  List<int> lastRPeakTimes = []; // Store times of last R peaks
  DateTime? lastPeakTime;
  List<double> lastHeartRates = [];

  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.bleManager.clearECGBuffer();
    widget.bleManager.addListener(_onBLEUpdate);
  }

  @override
  void dispose() {
    widget.bleManager.removeListener(_onBLEUpdate);
    scrollController.dispose();
    super.dispose();
  }

  void _onBLEUpdate() {
    if (!mounted) return;
    
    final ecgBuffer = widget.bleManager.ecgBuffer;
    
    if (ecgBuffer.isNotEmpty) {
      setState(() {
        for (var value in ecgBuffer) {
          _points.add(Point(_points.length.toDouble(), value.toDouble()));
          // Keep last 500 points (5 seconds at 100Hz)
          if (_points.length > 500) {
            _points.removeAt(0);
          }
        }
      });
         _calculateECGMetrics(); 
      widget.bleManager.clearECGBuffer();

      // Auto-scroll to the latest data
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }
    Widget _buildMetricsPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricCard(
            'Heart Rate',
            '${currentHeartRate.toStringAsFixed(1)}',
            'BPM',
            Icons.favorite,
            Colors.red,
          ),
          _buildMetricCard(
            'R-R Interval',
            '${rrInterval.toStringAsFixed(3)}',
            'sec',
            Icons.timeline,
            Colors.blue,
          ),
          _buildMetricCard(
            'Signal Quality',
            '${signalQuality.toStringAsFixed(1)}',
            '%',
            Icons.signal_cellular_alt,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String unit, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _adjustZoom(double delta) {
    setState(() {
      zoomLevel = (zoomLevel * (1 + delta)).clamp(0.5, 5.0);
    });
  }

    void _resetDisplay() {
    setState(() {
      _points.clear();
      currentHeartRate = 0.0;
      rrInterval = 0.0;
      signalQuality = 0.0;
      lastRPeakTimes.clear();
      lastHeartRates.clear();
      lastPeakTime = null;
    });
  }

 Future<void> _showSaveDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final firebaseService = FirebaseService();

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final selectedPatient = await showDialog<Patient>(
      context: context,
      builder: (context) => PatientSelectionDialog(),
    );

    if (selectedPatient != null && _points.isNotEmpty) {
      try {
        // Convert points to ECG data format, regardless of metrics
        List<int> ecgData = _points.map((point) => point.y.toInt()).toList();
        
        await firebaseService.saveECGReading(
          currentUser.uid,
          selectedPatient.medicalCardNumber,
          ecgData,
          {
            'duration': (ecgData.length / 100).round(), // assuming 100Hz
            'sampleRate': 100,
            // Remove any dependencies on calculated metrics
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ECG Recording saved successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving ECG recording: $e')),
        );
      }
    }
  }

  void _showHistory() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final selectedPatient = await showDialog<Patient>(
      context: context,
      builder: (context) => PatientSelectionDialog(),
    );

    if (selectedPatient != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ECGHistory(
            preselectedPatientId: selectedPatient.medicalCardNumber,
          ),
        ),
      );
    }
  }

 void _calculateECGMetrics() {
    if (_points.length < 100) return;

    // Get last 100 samples (1 second at 100Hz)
    int windowSize = min(100, _points.length);
    List<Point<double>> recentPoints = _points.sublist(_points.length - windowSize);

    // Calculate mean value in the window
    double mean = recentPoints.map((p) => p.y).reduce((a, b) => a + b) / windowSize;
    // Use the actual max from recent points instead of fixed 4095
    double maxRecent = recentPoints.map((p) => p.y).reduce(max);
    double threshold = mean + (maxRecent - mean) * 0.6;

    // Find potential R peak in this window
    int peakIdx = -1;
    double maxVal = threshold;
    
    for (int i = 2; i < recentPoints.length - 2; i++) {
      double value = recentPoints[i].y;
      // Check if it's a local maximum and above threshold
      if (value > threshold && 
          value > recentPoints[i-1].y && 
          value > recentPoints[i-2].y &&
          value > recentPoints[i+1].y && 
          value > recentPoints[i+2].y) {
        if (value > maxVal) {
          maxVal = value;
          peakIdx = i;
        }
      }
    }

    // If we found a peak, process it
    if (peakIdx != -1) {
      DateTime currentTime = DateTime.now();
      
      // Minimum 300ms between peaks (200 BPM max)
      if (lastPeakTime == null || 
          currentTime.difference(lastPeakTime!).inMilliseconds > 300) {
        
        lastPeakTime = currentTime;
        lastRPeakTimes.add(currentTime.millisecondsSinceEpoch);
        
        // Keep only last 6 peaks for calculation
        if (lastRPeakTimes.length > 6) {
          lastRPeakTimes.removeAt(0);
        }

        // Calculate heart rate from last peaks
        if (lastRPeakTimes.length >= 2) {
          List<int> rrIntervals = [];
          for (int i = 1; i < lastRPeakTimes.length; i++) {
            rrIntervals.add(lastRPeakTimes[i] - lastRPeakTimes[i-1]);
          }

          // Average RR interval in seconds
          double avgRRInterval = rrIntervals.reduce((a, b) => a + b) / (rrIntervals.length * 1000.0);

          // Calculate heart rate
          double hr = 60.0 / avgRRInterval;

          // Smooth heart rate
          lastHeartRates.add(hr);
          if (lastHeartRates.length > 3) {
            lastHeartRates.removeAt(0);
          }
          double smoothedHR = lastHeartRates.reduce((a, b) => a + b) / lastHeartRates.length;

          // Signal quality based on RR interval consistency
          double rrStdDev = 0;
          double meanRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
          for (int interval in rrIntervals) {
            rrStdDev += pow(interval - meanRR, 2);
          }
          rrStdDev = sqrt(rrStdDev / rrIntervals.length);
          double quality = meanRR > 0 ? max(0, min(100, 100 * (1 - rrStdDev / meanRR))) : 100;

          // Update metrics if heart rate is physiologically plausible
          if (smoothedHR >= 40 && smoothedHR <= 200) {
            setState(() {
              currentHeartRate = smoothedHR;
              rrInterval = avgRRInterval;
              signalQuality = quality;
            });
          }
        }
      }
    }
  }

  Widget build(BuildContext context) {
    final isConnected = widget.bleManager.connectedDevice != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('ECG Monitoring'),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: _showHistory,
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _showSaveDialog,
          ),
          IconButton(
            icon: Icon(Icons.zoom_in),
            onPressed: () => _adjustZoom(0.1),
          ),
          IconButton(
            icon: Icon(Icons.zoom_out),
            onPressed: () => _adjustZoom(-0.1),
          ),
          // Added Reset Button to clear the screen/graph and metrics
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetDisplay,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live ECG Monitor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          _buildMetricsPanel(), 
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: Container(
                width: _points.length * 2.0 * zoomLevel, // Adjust width based on zoom
                child: CustomPaint(
                  painter: ECGPainter(
                    points: _points,
                    minY: minY,
                    maxY: maxY,
                    zoomLevel: zoomLevel,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class ECGPainter extends CustomPainter {
  final List<Point<double>> points;
  final double minY;
  final double maxY;
  final double zoomLevel;
  // (Optional) sample rate for X-axis labeling. Update if needed.
  final double sampleRate;

  ECGPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.zoomLevel,
    this.sampleRate = 100,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define margins for axes
    final double leftMargin = 50;
    final double rightMargin = 10;
    final double topMargin = 10;
    final double bottomMargin = 40;

    // Determine the plotting area
    final double plotWidth = size.width - leftMargin - rightMargin;
    final double plotHeight = size.height - topMargin - bottomMargin;

    // Draw a white background (optional)
    final Paint backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;
    _drawGrid(canvas, leftMargin, topMargin, plotWidth, plotHeight, gridPaint);

    if (points.length < 2) return;

    // Scale factors for the data (using dynamic vertical range)
    final double xScale = (plotWidth * zoomLevel) / (points.length - 1);
    final double yScale = plotHeight / (maxY - minY);

    // Draw the ECG line
    final Paint linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    Path path = Path();
    path.moveTo(
      leftMargin,
      topMargin + plotHeight - (points[0].y - minY) * yScale,
    );
    for (int i = 1; i < points.length; i++) {
      double x = leftMargin + i * xScale;
      double y = topMargin + plotHeight - (points[i].y - minY) * yScale;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Draw the axis labels and titles
    _drawAxisLabels(
      canvas,
      size,
      leftMargin,
      topMargin,
      plotWidth,
      plotHeight,
    );
  }

  void _drawGrid(Canvas canvas, double left, double top, double width, double height, Paint paint) {
    // Draw vertical grid lines (every 50 pixels in plot coordinates)
    double gridSpacingX = 50.0;
    for (double x = left; x <= left + width; x += gridSpacingX) {
      canvas.drawLine(Offset(x, top), Offset(x, top + height), paint);
    }
    // Draw horizontal grid lines (every 50 pixels in plot coordinates)
    double gridSpacingY = 50.0;
    for (double y = top; y <= top + height; y += gridSpacingY) {
      canvas.drawLine(Offset(left, y), Offset(left + width, y), paint);
    }
  }

  void _drawAxisLabels(Canvas canvas, Size size, double left, double top, double width, double height) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Y-Axis Title
    textPainter.text = TextSpan(
      text: 'Voltage (ADC)',
      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(5, top + height / 2);
    canvas.rotate(-pi / 2);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
    canvas.restore();

    // Y-Axis Labels (let's show 5 labels)
    int numYLabels = 5;
    for (int i = 0; i <= numYLabels; i++) {
      double value = minY + (maxY - minY) * i / numYLabels;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      double y = top + height - ((value - minY) / (maxY - minY) * height);
      textPainter.paint(canvas, Offset(left - textPainter.width - 5, y - textPainter.height / 2));
    }

    // X-Axis Title
    textPainter.text = TextSpan(
      text: 'Time (s)',
      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(left + width / 2 - textPainter.width / 2, top + height + 20));

    // X-Axis Labels (5 labels; time computed using sampleRate)
    int numXLabels = 5;
    for (int i = 0; i <= numXLabels; i++) {
      double fraction = i / numXLabels;
      double x = left + fraction * width;
      // Calculate time in seconds:
      double timeInSeconds = (fraction * points.length) / sampleRate;
      textPainter.text = TextSpan(
        text: timeInSeconds.toStringAsFixed(1),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, top + height + 25));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class _PatientSelectionDialogState extends State<PatientSelectionDialog> {
  List<Patient> patients = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final firebaseService = FirebaseService();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        error = 'User not logged in';
        isLoading = false;
      });
      return;
    }

    try {
      final loadedPatients = await firebaseService.getPatientsForUser(currentUser.uid);
      setState(() {
        patients = loadedPatients;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error loading patients: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Patient'),
      content: Container(
        width: double.maxFinite,
        height: 300,
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
                : patients.isEmpty
                    ? Center(child: Text('No patients found'))
                    : ListView.builder(
                        itemCount: patients.length,
                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                patient.fullName[0].toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(patient.fullName),
                            subtitle: Text(patient.medicalCardNumber),
                            onTap: () => Navigator.of(context).pop(patient),
                          );
                        },
                      ),
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}