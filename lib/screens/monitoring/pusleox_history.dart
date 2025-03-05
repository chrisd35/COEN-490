import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/models.dart';
import '../registration/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
// Add a logging package import
import 'package:logging/logging.dart' as logging;

// Create a logger instance
final _logger = logging.Logger('PulseOxHistory');

class PulseOxHistory extends StatefulWidget {
  final String? preselectedPatientId;

  // Use super parameter syntax for key
  const PulseOxHistory({super.key, this.preselectedPatientId});

  @override
  State<PulseOxHistory> createState() => _PulseOxHistoryState();
}

class _PulseOxHistoryState extends State<PulseOxHistory> {
  final FirebaseService _firebaseService = FirebaseService();
  List<PulseOxSession> sessions = [];
  bool isLoading = true;
  PulseOxSession? selectedSession;
  String? patientName;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedPatientId != null) {
      _loadSessionsForPatient(widget.preselectedPatientId!);
    }
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

      // Check if widget is still mounted before using setState
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
          title: Text(patientName ?? 'Pulse Ox History'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationService.goBack(),
          ),
        ),
        body: isLoading 
            ? const Center(child: CircularProgressIndicator())
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
                      // Session selection with date/time
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: DropdownButton<PulseOxSession>(
                              isExpanded: true,
                              value: selectedSession,
                              items: sessions.map((session) {
                                return DropdownMenuItem(
                                  value: session,
                                  child: Text(
                                    DateFormat('MMM dd, yyyy - HH:mm:ss')
                                        .format(session.timestamp),
                                    style: const TextStyle(
                                      fontSize: 16,
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
                      ),
                      if (selectedSession != null) ...[
                        _buildAveragesCard(selectedSession!),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                               _buildGraphCard(
                                  'Heart Rate',
                                  selectedSession!.heartRateReadings,  // Ensure this is List<num>
                                  selectedSession!.timestamps,
                                  Colors.red,
                                  40,
                                  120,
                                  'BPM',
                                ),
                                _buildGraphCard(
                                  'SpO2',
                                  selectedSession!.spO2Readings,  // Ensure this is List<num>
                                  selectedSession!.timestamps,
                                  Colors.blue,
                                  85,
                                  100,
                                  '%',
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

  Widget _buildAveragesCard(PulseOxSession session) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Averages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAverageItem(
                  'Heart Rate',
                  session.averages['heartRate']?.toStringAsFixed(1) ?? 'N/A',
                  'BPM',
                  Colors.red,
                  Icons.favorite,
                ),
                _buildAverageItem(
                  'SpO2',
                  session.averages['spO2']?.toStringAsFixed(1) ?? 'N/A',
                  '%',
                  Colors.blue,
                  Icons.water_drop,
                ),
                _buildAverageItem(
                  'Temperature',
                  session.averages['temperature']?.toStringAsFixed(1) ?? 'N/A',
                  '°C',
                  Colors.orange,
                  Icons.thermostat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageItem(
    String title,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          '$value $unit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGraphCard(
    String title,
    List<num> values,  // Changed from List<double> to List<num>
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
      return FlSpot(relativeTime, values[i].toDouble());  // Convert to double explicitly
    });

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(  // Changed from Container to SizedBox
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: title == 'Heart Rate' ? 20 : 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
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
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 0.5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withAlpha(26), // Using withAlpha(26) instead of withOpacity(0.1)
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}