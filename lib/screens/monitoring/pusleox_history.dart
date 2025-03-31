import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/models.dart';
import '../registration/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('PulseOxHistory');

// AppTheme class to maintain design consistency
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

class PulseOxHistory extends StatefulWidget {
  final String? preselectedPatientId;

  const PulseOxHistory({super.key, this.preselectedPatientId});

  @override
  State<PulseOxHistory> createState() => _PulseOxHistoryState();
}
class _PulseOxHistoryState extends State<PulseOxHistory> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<PulseOxSession> sessions = [];
  bool isLoading = true;
  PulseOxSession? selectedSession;
  String? patientName;
  late TabController _tabController;
  bool isFullScreen = false;
  String activeTab = "heart_rate";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          activeTab = _tabController.index == 0 ? "heart_rate" : "spo2";
        });
      }
    });
    
    if (widget.preselectedPatientId != null) {
      _loadSessionsForPatient(widget.preselectedPatientId!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionsForPatient(String medicalCardNumber) async {
    setState(() {
      isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load patient details to get the name
      final patient = await _firebaseService.getPatient(
        currentUser.uid,
        medicalCardNumber,
      );

      final loadedSessions = await _firebaseService.getPulseOxSessions(
        currentUser.uid,
        medicalCardNumber,
      );

      if (!mounted) return;
      
      setState(() {
        sessions = loadedSessions;
        patientName = patient?.fullName ?? 'Unknown Patient';
        isLoading = false;
        if (sessions.isNotEmpty) {
          selectedSession = sessions.first;
        }
      });
    } catch (e) {
      _logger.severe('Error loading sessions: $e');
      
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
      
      _showSnackBar(message: 'Error loading sessions: $e', isError: true);
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
  @override
  Widget build(BuildContext context) {
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
                    'Pulse Ox History',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (patientName != null)
                    Text(
                      patientName!,
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
                if (sessions.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.textPrimary),
                    onPressed: () {
                      if (widget.preselectedPatientId != null) {
                        _loadSessionsForPatient(widget.preselectedPatientId!);
                      }
                    },
                    tooltip: 'Refresh',
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
        body: Stack(
          children: [
            // Main content
            SafeArea(
              child: isLoading 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading history...',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : sessions.isEmpty
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
                              'No recorded sessions found',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                         
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          if (!isFullScreen) ...[
                            // Session selection dropdown
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.history_toggle_off,
                                        size: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Select Session',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: DropdownButton<PulseOxSession>(
                                        isExpanded: true,
                                        value: selectedSession,
                                        icon: const Icon(Icons.keyboard_arrow_down),
                                        iconEnabledColor: AppTheme.primaryColor,
                                        underline: const SizedBox(),
                                        items: sessions.map((session) {
                                          return DropdownMenuItem(
                                            value: session,
                                            child: Text(
                                              DateFormat('MMM dd, yyyy - HH:mm')
                                                  .format(session.timestamp),
                                              style: GoogleFonts.inter(
                                                fontSize: 15,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (session) {
                                          setState(() {
                                            selectedSession = session;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (selectedSession != null)
                              _buildAveragesCard(selectedSession!),
                              
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
                          if (selectedSession != null)
                            Expanded(
                              child: isFullScreen
                                ? _buildFullScreenGraph()
                                : TabBarView(
                                    controller: _tabController,
                                    children: [
                                      // Heart Rate Graph
                                      _buildGraphPanel(
                                        'Heart Rate',
                                        selectedSession!.heartRateReadings,
                                        selectedSession!.timestamps,
                                        AppTheme.heartRateColor,
                                        40,
                                        160,
                                        'BPM',
                                      ),
                                      
                                      // SpO2 Graph
                                      _buildGraphPanel(
                                        'SpO2',
                                        selectedSession!.spO2Readings,
                                        selectedSession!.timestamps,
                                        AppTheme.spO2Color,
                                        85,
                                        100,
                                        '%',
                                      ),
                                    ],
                                  ),
                            ),
                        ],
                      ),
            ),
            
            // Fullscreen toggle button
            if (selectedSession != null)
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
        ),
      ),
    );
  }
  Widget _buildFullScreenGraph() {
    if (activeTab == "heart_rate") {
      return _buildGraphContent(
        'Heart Rate',
        selectedSession!.heartRateReadings,
        selectedSession!.timestamps,
        AppTheme.heartRateColor,
        40,
        160,
        'BPM',
      );
    } else {
      return _buildGraphContent(
        'SpO2',
        selectedSession!.spO2Readings,
        selectedSession!.timestamps,
        AppTheme.spO2Color,
        85,
        100,
        '%',
      );
    }
  }

  Widget _buildAveragesCard(PulseOxSession session) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Session Averages',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildAverageItem(
                  'Heart Rate',
                  session.averages['heartRate']?.toStringAsFixed(1) ?? 'N/A',
                  'BPM',
                  AppTheme.heartRateColor,
                  Icons.favorite,
                ),
              ),
              Container(
                width: 1,
                height: 70,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildAverageItem(
                  'SpO2',
                  session.averages['spO2']?.toStringAsFixed(1) ?? 'N/A',
                  '%',
                  AppTheme.spO2Color,
                  Icons.water_drop,
                ),
              ),
              Container(
                width: 1,
                height: 70,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildAverageItem(
                  'Temperature',
                  session.averages['temperature']?.toStringAsFixed(1) ?? 'N/A',
                  '°C',
                  AppTheme.temperatureColor,
                  Icons.thermostat,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildAverageItem(
    String title,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
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
              value,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildGraphPanel(
    String title,
    List<num> values,
    List<int> timestamps,
    Color color,
    double minY,
    double maxY,
    String unit,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: _buildGraphContent(
              title,
              values,
              timestamps,
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
                        'Recording Details',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(selectedSession!.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${values.length} points',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraphContent(
    String title,
    List<num> values,
    List<int> timestamps,
    Color color,
    double minY,
    double maxY,
    String unit,
  ) {
    // Convert timestamps to relative seconds from start
    final startTime = timestamps.first;
    final spots = List.generate(values.length, (i) {
      final relativeTime = (timestamps[i] - startTime) / 1000.0;
      return FlSpot(relativeTime, values[i].toDouble());
    });
    
    // Calculate duration of recording
    final recordingDuration = (timestamps.last - startTime) / 1000.0;
    
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
            child: spots.isEmpty
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
                        'No data available',
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
                    minX: 0,
                    maxX: recordingDuration,  // Use actual session duration
                    minY: minY,
                    maxY: maxY,
                    clipData: FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: title == 'Heart Rate' ? 20 : 5,
                      verticalInterval: recordingDuration > 10 ? 5 : 1, // Adjust grid based on duration
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
                    // Set tooltip behavior with basic touch data
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((LineBarSpot touchedSpot) {
                            return LineTooltipItem(
                              '${touchedSpot.y.toStringAsFixed(1)} $unit',
                              GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
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
                          interval: recordingDuration > 20 ? 5 : (recordingDuration > 10 ? 2 : 1),
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
                      // Add reference lines for normal ranges
                      if (title == 'Heart Rate') ...[
                        LineChartBarData(
                          spots: [
                            FlSpot(0, 100),
                            FlSpot(recordingDuration, 100),
                          ],
                          isCurved: false,
                          color: AppTheme.textLight.withAlpha(128),
                          barWidth: 1,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: [
                            FlSpot(0, 60),
                            FlSpot(recordingDuration, 60),
                          ],
                          isCurved: false,
                          color: AppTheme.textLight.withAlpha(128),
                          barWidth: 1,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      if (title == 'SpO2') ...[
                        LineChartBarData(
                          spots: [
                            FlSpot(0, 95),
                            FlSpot(recordingDuration, 95),
                          ],
                          isCurved: false,
                          color: AppTheme.textLight.withAlpha(128),
                          barWidth: 1,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ],
                  ),
                ),
          ),
          if (!isFullScreen) ...[
            const SizedBox(height: 8),
            // Add statistics with better spacing for smaller screens
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildStatBadge(
                  title == 'Heart Rate' ? 'Min HR' : 'Min SpO2', 
                  _calculateMin(values).toStringAsFixed(1), 
                  unit,
                  color,
                  isMin: true,
                ),
                _buildStatBadge(
                  title == 'Heart Rate' ? 'Avg HR' : 'Avg SpO2', 
                  _calculateAverage(values).toStringAsFixed(1), 
                  unit,
                  color,
                ),
                _buildStatBadge(
                  title == 'Heart Rate' ? 'Max HR' : 'Max SpO2', 
                  _calculateMax(values).toStringAsFixed(1), 
                  unit,
                  color,
                  isMax: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatBadge(
    String label, 
    String value, 
    String unit, 
    Color color, 
    {bool isMin = false, bool isMax = false}
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMin)
            const Icon(Icons.arrow_downward, size: 12, color: AppTheme.textPrimary)
          else if (isMax)
            const Icon(Icons.arrow_upward, size: 12, color: AppTheme.textPrimary)
          else
            const Icon(Icons.horizontal_rule, size: 12, color: AppTheme.textPrimary),
          const SizedBox(width: 2),
          Text(
            // Shorten labels for better fit
            label.replaceAll('HR', '').replaceAll('SpO2', ''), 
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$value$unit',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper methods to calculate statistics while ensuring proper type handling
  double _calculateMin(List<num> values) {
    if (values.isEmpty) return 0.0;
    double min = values.first.toDouble();
    for (var val in values) {
      if (val.toDouble() < min) {
        min = val.toDouble();
      }
    }
    return min;
  }
  
  double _calculateMax(List<num> values) {
    if (values.isEmpty) return 0.0;
    double max = values.first.toDouble();
    for (var val in values) {
      if (val.toDouble() > max) {
        max = val.toDouble();
      }
    }
    return max;
  }
  
  double _calculateAverage(List<num> values) {
    if (values.isEmpty) return 0.0;
    double sum = 0.0;
    for (var val in values) {
      sum += val.toDouble();
    }
    return sum / values.length;
  }
}
