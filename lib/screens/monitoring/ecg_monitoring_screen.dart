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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

final _logger = logging.Logger('ECGMonitoring');

// Design theme constants matching the app
class ECGTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors
  static const Color successColor = Color(0xFF2E7D32); // Darker green
  static const Color warningColor = Color(0xFFF57F17); // Amber shade
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red
  
  // Graph colors
  static const Color gridLineColor = Color(0xFFE0E0E0);
  static const Color ecgLineColor = Color(0xFF2E7D32);
  static const Color axisLabelColor = Color(0xFF78909C);
  
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

/// Main ECG Monitoring Screen
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
  // ECG Data
  final List<Point<double>> _points = [];
  final double minY = 0;
  final double maxY = 4095;
  double zoomLevel = 1.0;
  final FirebaseService _firebaseService = FirebaseService();

  // Heart rate monitoring values
  double currentHeartRate = 0.0;
  double rrInterval = 0.0;
  double signalQuality = 0.0;
  List<int> rPeakIndices = [];
  double rPeakThreshold = 3000; 
  List<int> lastRPeakTimes = []; 
  DateTime? lastPeakTime;
  List<double> lastHeartRates = [];
  
  // Patient data
  Patient? selectedPatient;

  // UI controllers
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

  @override
  void dispose() {
    widget.bleManager.removeListener(_onBLEUpdate);
    scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  //==================================================
  // DATA HANDLING METHODS
  //==================================================

  /// Load patient details from Firebase
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

  /// Handle BLE data updates
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Calculate heart rate and other ECG metrics
  void _calculateECGMetrics() {
    if (_points.length < 100) return;

    // Get last 100 samples (1 second at 100Hz)
    int windowSize = min(100, _points.length);
    List<Point<double>> recentPoints = _points.sublist(_points.length - windowSize);

    // Calculate mean value in the window
    double mean = recentPoints.map((p) => p.y).reduce((a, b) => a + b) / windowSize;
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

  //==================================================
  // UI INTERACTION METHODS
  //==================================================

  /// Adjust the zoom level of the ECG display
  void _adjustZoom(double delta) {
    setState(() {
      zoomLevel = (zoomLevel * (1 + delta)).clamp(0.5, 5.0);
    });
  }

  /// Reset the ECG display
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
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Display reset successfully',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: ECGTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show dialog to save ECG recording
  Future<void> _showSaveDialog() async {
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User not logged in',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: ECGTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
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

  /// Save ECG data to patient record
  void _saveECGToPatient(String uid, Patient patient) async {
    if (!mounted) return;
    
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No ECG data to save',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: ECGTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: ECGTheme.primaryColor,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Saving ECG data...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ECGTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
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
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'ECG Recording saved successfully',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: ECGTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
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
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error saving ECG recording: $e',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: ECGTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// Navigate to ECG history screen
  void _showHistory() async {
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User not logged in',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: ECGTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
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

  //==================================================
  // UI BUILDING METHODS
  //==================================================

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.bleManager.connectedDevice != null;
    String title = selectedPatient != null 
        ? 'ECG - ${selectedPatient!.fullName}'
        : 'ECG Monitoring';

    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        backgroundColor: ECGTheme.secondaryColor,
        appBar: _buildAppBar(title),
        body: Column(
          children: [
            _buildControlBar(isConnected),
            _buildMainContent(isConnected),
            _buildHeartRateIndicator(),
          ],
        ),
      ),
    );
  }

  /// Build the app bar with actions
  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ECGTheme.textPrimary,
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      iconTheme: IconThemeData(color: ECGTheme.primaryColor),
      actions: [
        // History button
        IconButton(
          icon: Icon(Icons.history, color: ECGTheme.primaryColor),
          tooltip: 'View History',
          onPressed: _showHistory,
        ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
        
        // Save button
        IconButton(
          icon: Icon(Icons.save_outlined, color: ECGTheme.primaryColor),
          tooltip: 'Save Recording',
          onPressed: _showSaveDialog,
        ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
        
        // Reset button
        IconButton(
          icon: Icon(Icons.refresh, color: ECGTheme.primaryColor),
          tooltip: 'Reset Display',
          onPressed: _resetDisplay,
        ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
      ],
    );
  }
  /// Build the control bar with zoom controls and connection status
 /// Build the control bar with zoom controls and connection status
  Widget _buildControlBar(bool isConnected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Zoom controls with modern styling
          Row(
            children: [
              Text(
                'Zoom:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ECGTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ECGTheme.primaryColor.withAlpha(51),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Zoom out button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _adjustZoom(-0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          bottomLeft: Radius.circular(7),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.remove,
                            size: 18,
                            color: ECGTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    
                    Container(
                      height: 20,
                      width: 1,
                      color: ECGTheme.primaryColor.withAlpha(51),
                    ),
                    
                    // Zoom in button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _adjustZoom(0.1),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.add,
                            size: 18,
                            color: ECGTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Connection status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isConnected 
                  ? ECGTheme.successColor.withAlpha(26) 
                  : ECGTheme.errorColor.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected 
                    ? ECGTheme.successColor 
                    : ECGTheme.errorColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected 
                        ? ECGTheme.successColor 
                        : ECGTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isConnected 
                        ? ECGTheme.successColor 
                        : ECGTheme.errorColor,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  /// Build the main content area (ECG graph)
  Widget _buildMainContent(bool isConnected) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ECGTheme.borderRadius,
            boxShadow: [ECGTheme.cardShadow],
          ),
          child: ClipRRect(
            borderRadius: ECGTheme.borderRadius,
            child: _points.isEmpty 
                ? _buildEmptyGraphState(isConnected)
                : _buildECGGraph(),
          ),
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  /// Build the heart rate indicator (shown only when data available)
  Widget _buildHeartRateIndicator() {
    if (_points.isEmpty || currentHeartRate <= 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ECGTheme.borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite,
            color: ECGTheme.primaryColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'Heart Rate: ${currentHeartRate.round()} BPM',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ECGTheme.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  /// Build empty graph state with helpful information
  Widget _buildEmptyGraphState(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.monitor_heart_outlined : Icons.bluetooth_disabled,
              size: 64,
              color: isConnected ? ECGTheme.primaryColor.withAlpha(153) : ECGTheme.errorColor.withAlpha(153),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).fadeIn(duration: 600.ms).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: 1500.ms,
            ),
            const SizedBox(height: 20),
            Text(
              isConnected 
                ? 'Waiting for ECG data...' 
                : 'Device not connected',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: ECGTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isConnected 
                ? 'ECG data will display here once received'
                : 'Connect your device from the dashboard to start monitoring',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: ECGTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
  /// Build ECG graph with smooth scrolling
  Widget _buildECGGraph() {
    return SingleChildScrollView(
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
    );
  }
}

//==================================================
// ECG PAINTER CLASS
//==================================================

/// ECG Graph Painter with enhanced visuals
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

    // Draw grid lines with softer color
    final Paint gridPaint = Paint()
      ..color = ECGTheme.gridLineColor
      ..strokeWidth = 0.5;
    _drawGrid(canvas, leftMargin, topMargin, plotWidth, plotHeight, gridPaint);

    if (points.length < 2) return;

    // Scale factors for the data (using dynamic vertical range)
    final double xScale = (plotWidth * zoomLevel) / (points.length - 1);
    final double yScale = plotHeight / (maxY - minY);

    // Draw the ECG line with anti-aliasing and improved appearance
    final Paint linePaint = Paint()
      ..color = ECGTheme.ecgLineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    
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

    // Draw the axis labels and titles with modern styling
    _drawAxisLabels(
      canvas,
      size,
      leftMargin,
      topMargin,
      plotWidth,
      plotHeight,
    );
  }

  /// Draw grid lines for the ECG graph
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

  /// Draw axis labels for the ECG graph
  void _drawAxisLabels(Canvas canvas, Size size, double left, double top, double width, double height) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Y-Axis Title - with modern styling
    textPainter.text = TextSpan(
      text: 'Voltage (ADC)',
      style: TextStyle(
        color: ECGTheme.axisLabelColor, 
        fontSize: 12, 
        fontWeight: FontWeight.w500
      ),
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(5, top + height / 2);
    canvas.rotate(-pi / 2);
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
    canvas.restore();

    // Y-Axis Labels (5 labels)
    const int numYLabels = 5;
    for (int i = 0; i <= numYLabels; i++) {
      double value = minY + (maxY - minY) * i / numYLabels;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(color: ECGTheme.axisLabelColor, fontSize: 10),
      );
      textPainter.layout();
      double y = top + height - ((value - minY) / (maxY - minY) * height);
      textPainter.paint(canvas, Offset(left - textPainter.width - 5, y - textPainter.height / 2));
    }

    // X-Axis Title - with modern styling
    textPainter.text = TextSpan(
      text: 'Time (s)',
      style: TextStyle(
        color: ECGTheme.axisLabelColor, 
        fontSize: 12, 
        fontWeight: FontWeight.w500
      ),
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
        style: TextStyle(color: ECGTheme.axisLabelColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, top + height + 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
//==================================================
// PATIENT SELECTION DIALOG
//==================================================

/// Dialog for selecting a patient from the user's list
class PatientSelectionDialog extends StatefulWidget {
  const PatientSelectionDialog({super.key});

  @override
  State<PatientSelectionDialog> createState() => PatientSelectionDialogState();
}

class PatientSelectionDialogState extends State<PatientSelectionDialog> {
  List<Patient> patients = [];
  bool isLoading = true;
  String? error;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  /// Load patient list from Firebase
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

  /// Filter patients based on search query
  List<Patient> get filteredPatients {
    if (searchQuery.isEmpty) return patients;
    
    return patients.where((patient) {
      return patient.fullName.toLowerCase().contains(searchQuery.toLowerCase()) ||
             patient.medicalCardNumber.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDialogHeader(),
            _buildPatientList(),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }
  /// Build the dialog header with title and search box
  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: BoxDecoration(
        color: ECGTheme.primaryColor.withAlpha(26),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                color: ECGTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Select Patient',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ECGTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (!isLoading && patients.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Search box
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: ECGTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: ECGTheme.textLight,
                    size: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the patient list section
  Widget _buildPatientList() {
    return SizedBox(
      height: 300,
      child: isLoading
        ? _buildLoadingState()
        : error != null
          ? _buildErrorState()
          : patients.isEmpty
            ? _buildEmptyState()
            : _buildPatientListContent(),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ECGTheme.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading patients...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: ECGTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: ECGTheme.errorColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ECGTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: ECGTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            color: ECGTheme.textLight,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ECGTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Add patients in the patient management section',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: ECGTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// Build patient list content
  Widget _buildPatientListContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: filteredPatients.isEmpty
        ? _buildNoSearchResultsState()
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: filteredPatients.length,
            itemBuilder: (context, index) {
              final patient = filteredPatients[index];
              return _buildPatientListItem(patient);
            },
          ),
    );
  }

  /// Build no search results state
  Widget _buildNoSearchResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            color: ECGTheme.textLight,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No matching patients',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: ECGTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build dialog footer with cancel button
  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: ECGTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ],
      ),
    );
  }

  /// Build individual patient list item
  Widget _buildPatientListItem(Patient patient) {
    // Generate initials for avatar
    final initials = patient.fullName.split(' ')
        .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
        .join('')
        .substring(0, min(2, patient.fullName.split(' ').length));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(patient),
          borderRadius: BorderRadius.circular(12),
          splashColor: ECGTheme.primaryColor.withAlpha(26),
          highlightColor: ECGTheme.primaryColor.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Avatar with initials
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ECGTheme.primaryColor,
                        const Color(0xFF2E86C1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: ECGTheme.primaryColor.withAlpha(51),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Patient details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ECGTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 14,
                            color: ECGTheme.textLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patient.medicalCardNumber,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: ECGTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Select icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: ECGTheme.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


