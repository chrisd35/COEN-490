import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_routes.dart';
import '../../utils/ble_manager.dart';
import '../registration/firebase_service.dart';
import '../../utils/models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('OxygenMonitoring');

// AppTheme class to maintain design consistency with dashboard
class AppTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors
  static const Color successColor = Color(0xFF2E7D32); // Darker green for better contrast
  static const Color warningColor = Color(0xFFF57F17); // Amber shade
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red for better readability
  
  // Text colors
  static const Color textPrimary = Color(0xFF263238);   // Darker for better contrast
  static const Color textSecondary = Color(0xFF546E7A); // Medium dark for subtext
  static const Color textLight = Color(0xFF78909C);     // Light text for tertiary info
  
  // Medical data colors
  static const Color heartRateColor = Color(0xFFE53935);  // Vibrant red for heart rate
  static const Color spO2Color = Color(0xFF1E88E5);       // Blue for oxygen
  static const Color temperatureColor = Color(0xFFFF8F00); // Orange for temperature
  
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
  
  static final TextStyle dataValueStyle = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static final TextStyle dataUnitStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0,
    height: 1.2,
  );
  
  // Animation durations
  static const Duration defaultAnimDuration = Duration(milliseconds: 300);
  static const Duration quickAnimDuration = Duration(milliseconds: 150);
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  static final BorderRadius smallRadius = BorderRadius.circular(8);
}

class OxygenMonitoring extends StatefulWidget {
  final String? preselectedPatientId;

  const OxygenMonitoring({super.key, this.preselectedPatientId});

  @override
  State<OxygenMonitoring> createState() => OxygenMonitoringState();
}

class OxygenMonitoringState extends State<OxygenMonitoring> with SingleTickerProviderStateMixin {
  List<FlSpot> heartRateSpots = [];
  List<FlSpot> spO2Spots = [];
  double maxX = 20.0; // Show last 20 seconds of data
  Patient? selectedPatient;
  double? firstTimestamp;
  int lastReadingIndex = 0;
  bool isActive = true;
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;
  bool isFullScreen = false;
  String activeTab = "heart_rate";
  
  // Warning thresholds
  final double lowHeartRateThreshold = 60.0;
  final double highHeartRateThreshold = 100.0;
  final double lowSpO2Threshold = 95.0;
  final double highTempThreshold = 37.5;

  @override
  void initState() {
    super.initState();
    isActive = true;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          activeTab = _tabController.index == 0 ? "heart_rate" : "spo2";
        });
      }
    });
    
    if (widget.preselectedPatientId != null) {
      _loadPatientDetails(widget.preselectedPatientId!);
    }
    _startPeriodicUpdate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _startPeriodicUpdate() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && isActive) {
        final bleManager = Provider.of<BLEManager>(context, listen: false);
        _updateGraphData(bleManager);
      }
      return mounted;
    });
  }

  void _updateGraphData(BLEManager bleManager) {
    if (!isActive) return;

    final readings = bleManager.currentSessionReadings;
    if (readings.isEmpty) {
      setState(() {
        heartRateSpots.clear();
        spO2Spots.clear();
        firstTimestamp = null;
        lastReadingIndex = 0;
      });
      return;
    }

    // Initialize firstTimestamp if not set
    if (firstTimestamp == null && readings.isNotEmpty) {
      firstTimestamp = readings[0]['timestamp'] / 1000;
      lastReadingIndex = 0; // Reset index when starting new session
    }

    // Process new readings
    final newHeartRateSpots = <FlSpot>[];
    final newSpO2Spots = <FlSpot>[];
    
    for (var i = lastReadingIndex; i < readings.length; i++) {
      var reading = readings[i];
      double currentTime = (reading['timestamp'] / 1000) - firstTimestamp!;
      
      newHeartRateSpots.add(FlSpot(currentTime, reading['heartRate'].toDouble()));
      newSpO2Spots.add(FlSpot(currentTime, reading['spO2'].toDouble()));
    }
    
    if (newHeartRateSpots.isNotEmpty) {
      setState(() {
        heartRateSpots.addAll(newHeartRateSpots);
        spO2Spots.addAll(newSpO2Spots);
        
        // Keep only points within maxX timeframe
        if (heartRateSpots.isNotEmpty) {
          final lastTime = heartRateSpots.last.x;
          heartRateSpots = heartRateSpots.where((spot) => spot.x > lastTime - maxX).toList();
          spO2Spots = spO2Spots.where((spot) => spot.x > lastTime - maxX).toList();
        }
        
        lastReadingIndex = readings.length;
      });
    }
  }

  void _resetGraph() {
    if (!mounted) return;
    
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    setState(() {
      isActive = false;
      heartRateSpots.clear();
      spO2Spots.clear();
      firstTimestamp = null;
      lastReadingIndex = 0;
    });
    
    // Reset BLE Manager state
    bleManager.clearPulseOxReadings();
    
    // Start a new session after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isActive = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String title = selectedPatient != null 
        ? selectedPatient!.fullName
        : 'Oxygen Monitoring';

    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        backgroundColor: AppTheme.secondaryColor,
        appBar: isFullScreen 
          ? null 
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oxygen Monitoring',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (selectedPatient != null)
                    Text(
                      selectedPatient!.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.textPrimary),
                onPressed: () => NavigationService.goBack(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history, color: AppTheme.primaryColor),
                  onPressed: _showHistory,
                  tooltip: 'View History',
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: AppTheme.primaryColor),
                  onPressed: _showSaveDialog,
                  tooltip: 'Save Session',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: _resetGraph,
                  tooltip: 'Reset',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.grey[200],
                  height: 1.0,
                ),
              ),
            ),
        body: Consumer<BLEManager>(
          builder: (context, bleManager, child) {
            return Stack(
              children: [
                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      if (!isFullScreen) ...[
                        _buildValueCards(bleManager),
                        
                        // Tab bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [AppTheme.subtleShadow],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: AppTheme.primaryColor,
                            labelColor: AppTheme.primaryColor,
                            unselectedLabelColor: AppTheme.textSecondary,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: const [
                              Tab(text: 'Heart Rate'),
                              Tab(text: 'Oxygen Saturation'),
                            ],
                          ),
                        ),
                      ],
                      
                      // Tab content
                      Expanded(
                        child: isFullScreen
                          ? _buildFullScreenGraph()
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                // Heart Rate Graph
                                _buildGraphPanel(
                                  'Heart Rate',
                                  heartRateSpots,
                                  AppTheme.heartRateColor,
                                  40,
                                  160,
                                  'BPM',
                                  bleManager.currentHeartRate,
                                  isWarning: _isHeartRateWarning(bleManager.currentHeartRate),
                                ),
                                
                                // SpO2 Graph
                                _buildGraphPanel(
                                  'SpO2',
                                  spO2Spots,
                                  AppTheme.spO2Color,
                                  85,
                                  100,
                                  '%',
                                  bleManager.currentSpO2,
                                  isWarning: _isSpO2Warning(bleManager.currentSpO2),
                                ),
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
                
                // Fullscreen toggle button
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 4,
                    mini: true,
                    onPressed: () {
                      setState(() {
                        isFullScreen = !isFullScreen;
                      });
                    },
                    child: Icon(
                      isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  bool _isHeartRateWarning(double heartRate) {
    return heartRate < lowHeartRateThreshold || heartRate > highHeartRateThreshold;
  }
  
  bool _isSpO2Warning(double spO2) {
    return spO2 < lowSpO2Threshold;
  }
  
  bool _isTempWarning(double temp) {
    return temp > highTempThreshold;
  }
  Widget _buildValueCards(BLEManager bleManager) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildValueCard(
              'Heart Rate',
              bleManager.currentHeartRate,
              'BPM',
              AppTheme.heartRateColor,
              Icons.favorite,
              isWarning: _isHeartRateWarning(bleManager.currentHeartRate),
            ),
          ),
          Container(
            width: 1,
            height: 70,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildValueCard(
              'SpO2',
              bleManager.currentSpO2,
              '%',
              AppTheme.spO2Color,
              Icons.water_drop,
              isWarning: _isSpO2Warning(bleManager.currentSpO2),
            ),
          ),
          Container(
            width: 1,
            height: 70,
            color: Colors.grey[200],
          ),
          Expanded(
            child: _buildValueCard(
              'Temperature',
              bleManager.currentTemperature,
              '°C',
              AppTheme.temperatureColor,
              Icons.thermostat,
              isWarning: _isTempWarning(bleManager.currentTemperature),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildValueCard(
    String title,
    double value,
    String unit,
    Color color,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isWarning ? AppTheme.errorColor : color, 
              size: 18
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isWarning ? AppTheme.errorColor : color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isWarning ? AppTheme.errorColor.withAlpha(204) : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullScreenGraph() {
    if (activeTab == "heart_rate") {
      return _buildGraphContent(
        'Heart Rate',
        heartRateSpots,
        AppTheme.heartRateColor,
        40,
        160,
        'BPM',
      );
    } else {
      return _buildGraphContent(
        'SpO2',
        spO2Spots,
        AppTheme.spO2Color,
        85,
        100,
        '%',
      );
    }
  }

  Widget _buildGraphPanel(
    String title,
    List<FlSpot> spots,
    Color color,
    double minY,
    double maxY,
    String unit,
    double currentValue,
    {bool isWarning = false}
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: _buildGraphContent(
              title,
              spots,
              color,
              minY,
              maxY,
              unit,
            ),
          ),
          if (!isFullScreen)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current $title',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            currentValue.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isWarning ? AppTheme.errorColor : color,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            unit,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isWarning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.errorColor.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.errorColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title == 'Heart Rate' 
                              ? (currentValue < lowHeartRateThreshold ? 'Low' : 'High') 
                              : 'Low',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraphContent(
    String title,
    List<FlSpot> spots,
    Color color,
    double minY,
    double maxY,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isFullScreen) ...[
            Row(
              children: [
                Icon(
                  title == 'Heart Rate' ? Icons.favorite : Icons.water_drop,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$title ($unit)',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: spots.length < 2
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Waiting for data...',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : LineChart(
                  LineChartData(
                    minX: spots.isEmpty ? 0 : (spots.last.x - maxX > 0 ? spots.last.x - maxX : 0),
                    maxX: spots.isEmpty ? maxX : spots.last.x,
                    minY: minY,
                    maxY: maxY,
                    clipData: FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: title == 'Heart Rate' ? 20 : 5,
                      verticalInterval: 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: title == 'Heart Rate' ? 20 : 5,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                value.toInt().toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: Text(
                          'Time (seconds)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textLight,
                          ),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            // Only show clean integers
                            if (value.toInt() != value) return const SizedBox.shrink();
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                value.toInt().toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!),
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: false,
                          checkToShowDot: (spot, barData) {
                            // Show dot for the latest value
                            return spot == spots.last;
                          },
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: color,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              color.withAlpha(77),  // 0.3 opacity
                              color.withAlpha(13),  // 0.05 opacity
                            ],
                          ),
                        ),
                      ),
                      // Add warning threshold lines
                      if (title == 'Heart Rate') ...[
                        LineChartBarData(
                          spots: [
                            FlSpot(spots.isEmpty ? 0 : (spots.last.x - maxX > 0 ? spots.last.x - maxX : 0), highHeartRateThreshold),
                            FlSpot(spots.isEmpty ? maxX : spots.last.x, highHeartRateThreshold),
                          ],
                          isCurved: false,
                          color: AppTheme.errorColor.withAlpha(128),
                          barWidth: 1.5,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: [
                            FlSpot(spots.isEmpty ? 0 : (spots.last.x - maxX > 0 ? spots.last.x - maxX : 0), lowHeartRateThreshold),
                            FlSpot(spots.isEmpty ? maxX : spots.last.x, lowHeartRateThreshold),
                          ],
                          isCurved: false,
                          color: AppTheme.errorColor.withAlpha(128),
                          barWidth: 1.5,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      if (title == 'SpO2') ...[
                        LineChartBarData(
                          spots: [
                            FlSpot(spots.isEmpty ? 0 : (spots.last.x - maxX > 0 ? spots.last.x - maxX : 0), lowSpO2Threshold),
                            FlSpot(spots.isEmpty ? maxX : spots.last.x, lowSpO2Threshold),
                          ],
                          isCurved: false,
                          color: AppTheme.errorColor.withAlpha(128),
                          barWidth: 1.5,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ],
                  ),
                ),
            ),
        ],
      ),
    );
  }
  Future<void> _showHistory() async {
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showSnackBar(
        message: 'Please log in to view history',
        isError: true,
      );
      return;
    }

    // If we have a preselected patient, go directly to history
    if (selectedPatient != null) {
      NavigationService.navigateTo(
        AppRoutes.pulseOxHistory,
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
        AppRoutes.pulseOxHistory,
        arguments: {
          'preselectedPatientId': patient.medicalCardNumber,
        },
      );
    }
  }

  Future<void> _showSaveDialog() async {
    if (!mounted) return;
    
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showSnackBar(
        message: 'Please log in to save data',
        isError: true,
      );
      return;
    }

    if (bleManager.currentSessionReadings.isEmpty) {
      _showSnackBar(
        message: 'No data to save',
        isError: true,
      );
      return;
    }

    // If we have a preselected patient, use it directly
    if (selectedPatient != null) {
      _savePulseOxData(currentUser.uid, selectedPatient!, bleManager);
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
      _savePulseOxData(currentUser.uid, patient, bleManager);
    }
  }

  Future<void> _savePulseOxData(String uid, Patient patient, BLEManager bleManager) async {
    if (!mounted) return;
    
    // Show saving indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Saving data...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await _firebaseService.savePulseOxSession(
        uid,
        patient.medicalCardNumber,
        List<Map<String, dynamic>>.from(bleManager.currentSessionReadings),
        bleManager.sessionAverages,
      );
      
      if (!mounted) return;
      
      // Dismiss progress dialog
      Navigator.pop(context);
      
      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Data Saved Successfully',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The session data has been saved to ${patient.fullName}\'s records.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                NavigationService.navigateTo(
                  AppRoutes.pulseOxHistory,
                  arguments: {
                    'preselectedPatientId': patient.medicalCardNumber,
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'View History',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Dismiss progress dialog
      Navigator.pop(context);
      
      _showSnackBar(
        message: 'Error saving data: $e',
        isError: true,
      );
    }
  }

  void _showSnackBar({
    required String message,
    bool isError = false,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
  }
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
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<Patient> get filteredPatients {
    if (searchQuery.isEmpty) {
      return patients;
    }
    
    final query = searchQuery.toLowerCase();
    return patients.where((patient) {
      return patient.fullName.toLowerCase().contains(query) ||
             patient.medicalCardNumber.toLowerCase().contains(query);
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
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(13),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Patient',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search patients...',
                      hintStyle: GoogleFonts.inter(
                        color: AppTheme.textLight,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Patient List
            SizedBox(
              height: 300,
              child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ).animate()
                      .fadeIn(duration: 300.ms)
                      .shimmer(delay: 1000.ms, duration: 1000.ms),
                  )
                : error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppTheme.errorColor,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error!,
                            style: GoogleFonts.inter(
                              color: AppTheme.errorColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : patients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off,
                              color: Colors.grey[400],
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No patients found',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                NavigationService.navigateTo(AppRoutes.patientCard);
                              },
                              child: Text(
                                'Add New Patient',
                                style: GoogleFonts.inter(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredPatients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                color: Colors.grey[400],
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matches found',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredPatients.length,
                          padding: const EdgeInsets.all(0),
                          itemBuilder: (context, index) {
                            final patient = filteredPatients[index];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(patient),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withAlpha(26),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            patient.fullName[0].toUpperCase(),
                                            style: GoogleFonts.inter(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              patient.fullName,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'ID: ${patient.medicalCardNumber}',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textLight,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!patients.isEmpty)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        NavigationService.navigateTo(AppRoutes.patientCard);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add New',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}