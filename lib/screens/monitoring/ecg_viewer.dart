import 'dart:ui' as ui;

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
import 'package:logging/logging.dart' as logging;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Create a logger instance
final _logger = logging.Logger('ECGViewer');

// Design theme constants to match the app
class ECGViewerTheme {
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

/// The ECG Viewer screen for displaying saved ECG recordings
class ECGViewer extends StatefulWidget {
  final ECGReading reading;
  final String patientName;

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

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
  /// Load ECG data from Firebase
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
          SnackBar(
            content: Text(
              'Failed to load ECG data - empty result',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: ECGViewerTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
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
            content: Text(
              'Error loading ECG data: ${e.toString()}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: ECGViewerTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          )
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Try to load ECG data using the download URL
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

  /// Try to load ECG data using the filename
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
  /// Update download URL in the database
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

  /// Adjust the zoom level of the ECG display
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
        backgroundColor: ECGViewerTheme.secondaryColor,
        appBar: _buildAppBar(),
        body: isLoading
            ? _buildLoadingState()
            : _buildContent(),
      ),
    );
  }

  /// Build app bar with title and actions
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'ECG Data - ${widget.patientName}',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ECGViewerTheme.textPrimary,
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: ECGViewerTheme.primaryColor,
        ),
        onPressed: () => NavigationService.goBack(),
      ),
      actions: [
        // Zoom in button
        IconButton(
          icon: Icon(
            Icons.zoom_in,
            color: ECGViewerTheme.primaryColor,
          ),
          tooltip: 'Zoom In',
          onPressed: () => _adjustZoom(0.1),
        ),
        // Zoom out button
        IconButton(
          icon: Icon(
            Icons.zoom_out,
            color: ECGViewerTheme.primaryColor,
          ),
          tooltip: 'Zoom Out',
          onPressed: () => _adjustZoom(-0.1),
        ),
      ],
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ECGViewerTheme.primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading ECG data...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: ECGViewerTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  /// Build the main content with recording info and ECG graph
  Widget _buildContent() {
    return Column(
      children: [
        _buildRecordingInfoCard(),
        _buildECGGraphContainer(),
      ],
    );
  }

  /// Build recording information card
  Widget _buildRecordingInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: ECGViewerTheme.borderRadius,
          boxShadow: [ECGViewerTheme.cardShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: ECGViewerTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording Information',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ECGViewerTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Recording details
              _buildInfoRow(
                icon: Icons.timer_outlined,
                label: 'Duration:',
                value: '${widget.reading.duration} seconds',
              ),
              
              const SizedBox(height: 8),
              
              _buildInfoRow(
                icon: Icons.speed_outlined,
                label: 'Sample Rate:',
                value: '${widget.reading.sampleRate} Hz',
              ),
              
              const SizedBox(height: 8),
              
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date:',
                value: DateFormat('MMM dd, yyyy - HH:mm:ss').format(widget.reading.timestamp),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Build a row for the info card
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: ECGViewerTheme.textLight,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: ECGViewerTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: ECGViewerTheme.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Build ECG graph container
  Widget _buildECGGraphContainer() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ECGViewerTheme.borderRadius,
            boxShadow: [ECGViewerTheme.cardShadow],
          ),
          child: ClipRRect(
            borderRadius: ECGViewerTheme.borderRadius,
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
                    minY: 0,
                    maxY: 4095,
                    zoomLevel: zoomLevel,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
    );
  }
}
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
    ..color = ECGViewerTheme.gridLineColor
    ..strokeWidth = 0.5;
  _drawGrid(canvas, leftMargin, topMargin, plotWidth, plotHeight, gridPaint);

  if (points.length < 2) return;

  // ADDED: Calculate actual min and max values from data
  double actualMin = double.infinity;
  double actualMax = double.negativeInfinity;
  
  for (var point in points) {
    if (point.y < actualMin) actualMin = point.y;
    if (point.y > actualMax) actualMax = point.y;
  }
  
  // ADDED: Add padding (10% on top and bottom)
  double range = actualMax - actualMin;
  if (range <= 0) range = maxY - minY; // Fallback if all values are the same
  
  double paddedMin = max(minY, actualMin - (range * 0.1));
  double paddedMax = min(maxY, actualMax + (range * 0.1));
  
  // CHANGED: Use these values instead of minY/maxY for scaling
  final double xScale = (plotWidth * zoomLevel) / (points.length - 1);
  final double yScale = plotHeight / (paddedMax - paddedMin);

  // Draw the ECG line with anti-aliasing and improved appearance
  final Paint linePaint = Paint()
    ..color = ECGViewerTheme.ecgLineColor
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  
  Path path = Path();
  // CHANGED: Use paddedMin instead of minY
  path.moveTo(
    leftMargin,
    topMargin + plotHeight - (points[0].y - paddedMin) * yScale,
  );
  
  for (int i = 1; i < points.length; i++) {
    double x = leftMargin + i * xScale;
    // CHANGED: Use paddedMin instead of minY
    double y = topMargin + plotHeight - (points[i].y - paddedMin) * yScale;
    path.lineTo(x, y);
  }
  
  canvas.drawPath(path, linePaint);

  // Draw the axis labels and titles with modern styling
  // CHANGED: Pass the new min/max values to draw correct labels
  _drawAxisLabels(
    canvas,
    size,
    leftMargin,
    topMargin,
    plotWidth,
    plotHeight,
    paddedMin,
    paddedMax,
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
  void _drawAxisLabels( Canvas canvas, 
  Size size, 
  double left, 
  double top, 
  double width, 
  double height,
  double effectiveMinY,
  double effectiveMaxY,) {
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Y-Axis Title - with modern styling
    textPainter.text = TextSpan(
      text: 'Voltage (ADC)',
      style: TextStyle(
        color: ECGViewerTheme.axisLabelColor, 
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
        style: TextStyle(color: ECGViewerTheme.axisLabelColor, fontSize: 10),
      );
      textPainter.layout();
      double y = top + height - ((value - minY) / (maxY - minY) * height);
      textPainter.paint(canvas, Offset(left - textPainter.width - 5, y - textPainter.height / 2));
    }

    // X-Axis Title - with modern styling
    textPainter.text = TextSpan(
      text: 'Time (s)',
      style: TextStyle(
        color: ECGViewerTheme.axisLabelColor, 
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
        style: TextStyle(color: ECGViewerTheme.axisLabelColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, top + height + 5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}