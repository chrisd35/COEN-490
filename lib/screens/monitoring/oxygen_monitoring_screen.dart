import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../utils/ble_manager.dart';
import '../registration/firebase_service.dart';
import '../../utils/models.dart';

class OxygenMonitoring extends StatefulWidget {
  @override
  _OxygenMonitoringState createState() => _OxygenMonitoringState();
}

class _OxygenMonitoringState extends State<OxygenMonitoring> {
  List<FlSpot> heartRateSpots = [];
  List<FlSpot> spO2Spots = [];
  double maxX = 20; // Show last 20 seconds of data
  Patient? selectedPatient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Oxygen Monitoring'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () => _showSaveDialog(context),
          ),
        ],
      ),
      body: Consumer<BLEManager>(
        builder: (context, bleManager, child) {
          // Add new data points
          if (bleManager.pulseOxReadings.isNotEmpty) {
            _updateGraphData(bleManager);
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Values Cards
                  _buildValueCards(bleManager),
                  SizedBox(height: 20),

                  // Heart Rate Graph
                  _buildGraphCard(
                    'Heart Rate',
                    heartRateSpots,
                    Colors.red,
                    40,
                    120,
                    'BPM',
                  ),
                  SizedBox(height: 20),

                  // SpO2 Graph
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
    );
  }

  Widget _buildValueCards(BLEManager bleManager) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildValueCard(
          'Heart Rate',
          '${bleManager.currentHeartRate.toStringAsFixed(1)}',
          'BPM',
          Colors.red,
          Icons.favorite,
        ),
        _buildValueCard(
          'SpO2',
          '${bleManager.currentSpO2.toStringAsFixed(1)}',
          '%',
          Colors.blue,
          Icons.water_drop,
        ),
        _buildValueCard(
          'Temperature',
          '${bleManager.currentTemperature.toStringAsFixed(1)}',
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
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
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
                SizedBox(width: 4),
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
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}$unit');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}s');
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
                        color: color.withOpacity(0.1),
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

  void _updateGraphData(BLEManager bleManager) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000; // Convert to seconds
    
    if (heartRateSpots.isEmpty) {
      // Initialize with current value if empty
      heartRateSpots.add(FlSpot(0, bleManager.currentHeartRate));
      spO2Spots.add(FlSpot(0, bleManager.currentSpO2));
    } else {
      final lastTime = heartRateSpots.last.x;
      final newTime = lastTime + 1; // Add point every second
      
      heartRateSpots.add(FlSpot(newTime, bleManager.currentHeartRate));
      spO2Spots.add(FlSpot(newTime, bleManager.currentSpO2));

      // Remove old points
      if (newTime > maxX) {
        heartRateSpots.removeAt(0);
        spO2Spots.removeAt(0);
        
        // Shift all points left
        heartRateSpots = heartRateSpots.map((spot) => 
          FlSpot(spot.x - 1, spot.y)).toList();
        spO2Spots = spO2Spots.map((spot) => 
          FlSpot(spot.x - 1, spot.y)).toList();
      }
    }
  }

  Future<void> _showSaveDialog(BuildContext context) async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    // Show patient selection dialog
    selectedPatient = await showDialog<Patient>(
      context: context,
      builder: (context) => PatientSelectionDialog(),
    );

    if (selectedPatient != null) {
      try {
        await firebaseService.savePulseOxSession(
          'your_uid_here', // Replace with actual user ID
          selectedPatient!.medicalCardNumber,
          bleManager.pulseOxReadings,
          bleManager.sessionAverages,
      
          
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data saved successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    }
  }
}

// Add this as a separate widget
class PatientSelectionDialog extends StatefulWidget {
  @override
  _PatientSelectionDialogState createState() => _PatientSelectionDialogState();
}

class _PatientSelectionDialogState extends State<PatientSelectionDialog> {
  Patient? selectedPatient;
  List<Patient> patients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    try {
      patients = await firebaseService.getPatientsForUser('your_uid_here');
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading patients: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Patient'),
      content: isLoading
          ? CircularProgressIndicator()
          : Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return ListTile(
                    title: Text(patient.fullName),
                    subtitle: Text(patient.medicalCardNumber),
                    onTap: () {
                      Navigator.of(context).pop(patient);
                    },
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