import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async'; // Import Timer
import 'components/patient_card.dart';
import 'components/murmur_chart.dart';
import 'components/murmur_record.dart';
import 'ble_screen.dart'; // Import the BLEScreen
import '/utils/ble_manager.dart'; // Import the BLEManager

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _wasConnected = false; // Track if the device was previously connected

  @override
  Widget build(BuildContext context) {
    // Access the BLEManager instance and listen for changes
    final bleManager = Provider.of<BLEManager>(context, listen: true);
    final connectedDevice = bleManager.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          // Add a BLE Connection Button
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BLEScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Display Connected Device Info
              if (connectedDevice != null)
                StreamBuilder<BluetoothConnectionState>(
                  stream: bleManager.getDeviceState(connectedDevice),
                  builder: (context, snapshot) {
                    final isConnected = snapshot.data == BluetoothConnectionState.connected;

                    // Handle disconnection
                    if (!isConnected && _wasConnected) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showDisconnectionPrompt(context);
                      });
                      _wasConnected = false; // Reset the flag after showing the prompt
                    } else if (isConnected) {
                      _wasConnected = true; // Set the flag when connected
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.circle,
                          color: isConnected ? Colors.green : Colors.red,
                          size: 12,
                        ),
                        SizedBox(width: 8),
                        Text(
                          isConnected
                              ? 'Connected to: ${connectedDevice.name.isEmpty ? "Unknown Device" : connectedDevice.name}'
                              : 'Disconnected',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    );
                  },
                ),
              if (connectedDevice == null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle,
                      color: Colors.blue,
                      size: 12,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'No device connected',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              SizedBox(height: 20),

              Text(
                'Hello "Insert First Name"',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Patient Folders Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PatientCard(), // Leads to patient folders component
                    ),
                  );
                },
                child: Text('Patient Folders'),
              ),
              SizedBox(height: 20),

              // AI Murmur Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MurmurChart(), // Leads to AI murmur component
                    ),
                  );
                },
                child: Text('AI Murmur'),
              ),
              SizedBox(height: 20),

              // Murmur Recording Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MurmurRecord(), // Leads to murmur recording component
                    ),
                  );
                },
                child: Text('Murmur Record'),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisconnectionPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Device Disconnected'),
          content: Text(
              'A disconnection has occurred. To use the full functionalities of the device, please pair the device using Bluetooth.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BLEScreen(),
                  ),
                ); // Go to pairing screen
              },
              child: Text('Go to Pairing'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: Text('Maybe Later'),
            ),
          ],
        );
      },
    );
  }
}