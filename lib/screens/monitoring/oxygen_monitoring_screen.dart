import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../utils/app_routes.dart';
import '../../utils/ble_manager.dart';
import '../registration/firebase_service.dart';
import '../../utils/models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/navigation_service.dart';
import '../../widgets/back_button.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('OxygenMonitoring');

class OxygenMonitoring extends StatefulWidget {
  final String? preselectedPatientId;

  const OxygenMonitoring({super.key, this.preselectedPatientId});

  @override
  State<OxygenMonitoring> createState() => OxygenMonitoringState();
}

// Changed from private to public class
class OxygenMonitoringState extends State<OxygenMonitoring> {
  List<FlSpot> heartRateSpots = [];
  List<FlSpot> spO2Spots = [];
  double maxX = 3.0; // Changed to 3 seconds
  Patient? selectedPatient;
  double? firstTimestamp;
  int lastReadingIndex = 0;
  bool isActive = true; // Add state to track if monitoring is active
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    isActive = true;
    if (widget.preselectedPatientId != null) {
      _loadPatientDetails(widget.preselectedPatientId!);
    }
    _startPeriodicUpdate();
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
    for (var i = lastReadingIndex; i < readings.length; i++) {
      var reading = readings[i];
      double currentTime = (reading['timestamp'] / 1000) - firstTimestamp!;

      if (currentTime <= maxX) {
        setState(() {
          heartRateSpots.add(FlSpot(currentTime, reading['heartRate'].toDouble()));
          spO2Spots.add(FlSpot(currentTime, reading['spO2'].toDouble()));
        });
      }
    }

    lastReadingIndex = readings.length;
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
        ? 'Oxygen Monitoring - ${selectedPatient!.fullName}'
        : 'Oxygen Monitoring';

    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationService.goBack(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showHistory,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetGraph,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _showSaveDialog,
            ),
          ],
        ),
        body: Consumer<BLEManager>(
          builder: (context, bleManager, child) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildValueCards(bleManager),
                    const SizedBox(height: 20),
                    _buildGraphCard(
                      'Heart Rate',
                      heartRateSpots,
                      Colors.red,
                      40,
                      120,
                      'BPM',
                    ),
                    const SizedBox(height: 20),
                    _buildGraphCard(
                      'SpO2',
                      spO2Spots,
                      Colors.blue,
                      85,
                      100,
                      '%',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildValueCards(BLEManager bleManager) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildValueCard(
          'Heart Rate',
          bleManager.currentHeartRate.toStringAsFixed(1),
          'BPM',
          Colors.red,
          Icons.favorite,
        ),
        _buildValueCard(
          'SpO2',
          bleManager.currentSpO2.toStringAsFixed(1),
          '%',
          Colors.blue,
          Icons.water_drop,
        ),
        _buildValueCard(
          'Temperature',
          bleManager.currentTemperature.toStringAsFixed(1),
          '°C',
          Colors.orange,
          Icons.thermostat,
        ),
      ],
    );
  }

  Widget _buildValueCard(
    String title,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard(
    String title,
    List<FlSpot> spots,
    Color color,
    double minY,
    double maxY,
    String unit,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Points: ${spots.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: title == 'Heart Rate' ? 20 : 5, // Different intervals for HR and SpO2
                    verticalInterval: 0.5, // Show tick every 0.5 seconds
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
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
                        interval: title == 'Heart Rate' ? 20 : 5, // Different intervals for HR and SpO2
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        'Time (seconds)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 0.5, // Show tick every 0.5 seconds
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              value.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      axisNameWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            ' ($unit)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      sideTitles: const SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: Colors.grey[400]!),
                      bottom: BorderSide(color: Colors.grey[400]!),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withAlpha(26), // Using withAlpha instead of withOpacity (0.1)
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

  Future<void> _showHistory() async {
    if (!mounted) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
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
    
    if (bleManager.currentSessionReadings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to save')),
      );
      return;
    }

    try {
      await _firebaseService.savePulseOxSession(
        uid,
        patient.medicalCardNumber,
        List<Map<String, dynamic>>.from(bleManager.currentSessionReadings),
        bleManager.sessionAverages,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data saved successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }
}

class PatientSelectionDialog extends StatefulWidget {
  const PatientSelectionDialog({super.key});

  @override
  State<PatientSelectionDialog> createState() => PatientSelectionDialogState();
}

// Changed from private to public class
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