import 'package:flutter/material.dart';
import 'dart:ui' as ui show TextDirection;
import 'dart:math' show Point, max, min, pi, pow, sqrt;
import '../../utils/app_routes.dart';
import '../../utils/ble_manager.dart';
import '../registration/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/models.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('ECGMonitoring');

class ECGMonitoring extends StatefulWidget {
  final String? uid;
  final String? preselectedPatientId;
  final BLEManager bleManager;

  const ECGMonitoring({
    super.key,
    this.uid,
    this.preselectedPatientId,
    required this.bleManager,
  });

  @override
  State<ECGMonitoring> createState() => ECGMonitoringState();
}

class ECGMonitoringState extends State<ECGMonitoring> with SingleTickerProviderStateMixin {
  final List<Point<double>> _points = [];
  final double minY = 0;
  final double maxY = 4095;
  double zoomLevel = 1.0;
  final FirebaseService _firebaseService = FirebaseService();

  // These metrics are still calculated in the background but not displayed
  double currentHeartRate = 0.0;
  double rrInterval = 0.0;
  double signalQuality = 0.0;
  List<int> rPeakIndices = [];
  double rPeakThreshold = 3000; // Adjusted threshold
  List<int> lastRPeakTimes = []; // Store times of last R peaks
  DateTime? lastPeakTime;
  List<double> lastHeartRates = [];
  Patient? selectedPatient;

  ScrollController scrollController = ScrollController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPatientId != null) {
      _loadPatientDetails(widget.preselectedPatientId!);
    }
    widget.bleManager.clearECGBuffer();
    widget.bleManager.addListener(_onBLEUpdate);
    
    // Animation controller for UI elements
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  Future<void> _loadPatientDetails(String medicalCardNumber) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      final patient = await _firebaseService.getPatient(
        currentUser.uid,
        medicalCardNumber,
      );
      
      if (patient != null && mounted) {
        setState(() {
          selectedPatient = patient;
        });
      }
    } catch (e) {
      _logger.warning('Error loading patient details: $e');
    }
  }

  @override
  void dispose() {
    widget.bleManager.removeListener(_onBLEUpdate);
    scrollController.dispose();
    _animationController.dispose();
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
      _calculateECGMetrics(); // Still calculate metrics but don't display
      widget.bleManager.clearECGBuffer();

      // Auto-scroll to the latest data
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
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
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // If we have a preselected patient, use it directly
    if (selectedPatient != null) {
      _saveECGToPatient(currentUser.uid, selectedPatient!);
      return;
    }

    // Store context before async gap
    final currentContext = context;
    
    // Otherwise show dialog to select patient
    final patient = await showDialog<Patient>(
      context: currentContext,
      builder: (dialogContext) => const PatientSelectionDialog(),
    );

    if (patient != null && mounted) {
      _saveECGToPatient(currentUser.uid, patient);
    }
  }

  void _saveECGToPatient(String uid, Patient patient) async {
    if (!mounted) return;
    
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ECG data to save'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Convert points to ECG data format
      List<int> ecgData = _points.map((point) => point.y.toInt()).toList();
      
      await _firebaseService.saveECGReading(
        uid,
        patient.medicalCardNumber,
        ecgData,
        {
          'duration': (ecgData.length / 100).round(),
          'sampleRate': 100,
        },
      );

      // Close loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ECG Recording saved successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving ECG recording: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showHistory() async {
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // If we have a preselected patient, go directly to history
    if (selectedPatient != null) {
      NavigationService.navigateTo(
        AppRoutes.ecgHistory,
        arguments: {
          'preselectedPatientId': selectedPatient!.medicalCardNumber,
        },
      );
      return;
    }

    // Store context before async gap
    final currentContext = context;
    
    // Otherwise show dialog to select patient
    final patient = await showDialog<Patient>(
      context: currentContext,
      builder: (dialogContext) => const PatientSelectionDialog(),
    );

    if (patient != null && mounted) {
      NavigationService.navigateTo(
        AppRoutes.ecgHistory,
        arguments: {
          'preselectedPatientId': patient.medicalCardNumber,
        },
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

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.bleManager.connectedDevice != null;
    String title = selectedPatient != null 
        ? 'ECG - ${selectedPatient!.fullName}'
        : 'ECG Monitoring';

    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(title),
          elevation: 0,
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'View History',
              onPressed: _showHistory,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Recording',
              onPressed: _showSaveDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Display',
              onPressed: _resetDisplay,
            ),
          ],
        ),
        body: Column(
          children: [
            // Show ECG status at the top with zoom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.zoom_in),
                        onPressed: () => _adjustZoom(0.1),
                        tooltip: 'Zoom In',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.zoom_out),
                        onPressed: () => _adjustZoom(-0.1),
                        tooltip: 'Zoom Out',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isConnected ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Main ECG Graph (takes full space)
            Expanded(
              child: Card(
                margin: const EdgeInsets.all(16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: max(MediaQuery.of(context).size.width - 32, _points.length * 2.0 * zoomLevel),
                      height: MediaQuery.of(context).size.height - 160,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ECGPainter class - keeping the original implementation to avoid errors
class ECGPainter extends CustomPainter {
  final List<Point<double>> points;
  final double minY;
  final double maxY;
  final double zoomLevel;
  final double sampleRate;

  const ECGPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.zoomLevel,
    this.sampleRate = 100,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Define margins for axes
    const double leftMargin = 50;
    const double rightMargin = 10;
    const double topMargin = 10;
    const double bottomMargin = 40;

    // Determine the plotting area
    final double plotWidth = size.width - leftMargin - rightMargin;
    final double plotHeight = size.height - topMargin - bottomMargin;

    // Draw a white background
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
    const double gridSpacingX = 50.0;
    for (double x = left; x <= left + width; x += gridSpacingX) {
      canvas.drawLine(Offset(x, top), Offset(x, top + height), paint);
    }
    // Draw horizontal grid lines (every 50 pixels in plot coordinates)
    const double gridSpacingY = 50.0;
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
    textPainter.text = const TextSpan(
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
    const int numYLabels = 5;
    for (int i = 0; i <= numYLabels; i++) {
      double value = minY + (maxY - minY) * i / numYLabels;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      double y = top + height - ((value - minY) / (maxY - minY) * height);
      textPainter.paint(canvas, Offset(left - textPainter.width - 5, y - textPainter.height / 2));
    }

    // X-Axis Title
    textPainter.text = const TextSpan(
      text: 'Time (s)',
      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(left + width / 2 - textPainter.width / 2, top + height + 20));

    // X-Axis Labels (5 labels; time computed using sampleRate)
    const int numXLabels = 5;
    for (int i = 0; i <= numXLabels; i++) {
      double fraction = i / numXLabels;
      double x = left + fraction * width;
      // Calculate time in seconds:
      double timeInSeconds = (fraction * points.length) / sampleRate;
      textPainter.text = TextSpan(
        text: timeInSeconds.toStringAsFixed(1),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, top + height + 25));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PatientSelectionDialog extends StatefulWidget {
  const PatientSelectionDialog({super.key});

  @override
  State<PatientSelectionDialog> createState() => PatientSelectionDialogState();
}

class PatientSelectionDialogState extends State<PatientSelectionDialog> {
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
      
      if (!mounted) return;
      
      setState(() {
        patients = loadedPatients;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        error = 'Error loading patients: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Patient'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                : patients.isEmpty
                    ? const Center(child: Text('No patients found'))
                    : ListView.builder(
                        itemCount: patients.length,
                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                patient.fullName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
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
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}