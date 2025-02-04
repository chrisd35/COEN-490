import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/audio_service.dart';
import '/utils/ble_manager.dart';
import 'dart:typed_data';

class BLEScreen extends StatefulWidget {
  @override
  _BLEScreenState createState() => _BLEScreenState();
}

class _BLEScreenState extends State<BLEScreen> with SingleTickerProviderStateMixin {
  List<ScanResult> scanResults = [];
  BluetoothDevice? connectedDevice;
  bool _isScanning = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _requestPermissions();
    _startScan();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _requestPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    if (await Permission.location.isGranted &&
        await Permission.bluetooth.isGranted &&
        await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted) {
      print("All permissions granted");
    } else {
      print("Permissions not granted");
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Permissions Required'),
          ],
        ),
        content: Text(
          'Please enable Bluetooth and Location permissions to scan for devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
    });
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    bleManager.scanDevices(timeout: Duration(seconds: 10)).listen(
      (results) {
        setState(() {
          scanResults = results;
          _isScanning = false;
        });
      },
      onError: (error) {
        print("BLE scan error: $error");
        setState(() {
          _isScanning = false;
        });
        _showErrorSnackBar("Scanning failed. Please try again.");
      },
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isScanning = true;
    });
    
    try {
      final bleManager = Provider.of<BLEManager>(context, listen: false);
      await bleManager.connectToDevice(device);

      List<BluetoothService> services = await bleManager.discoverServices(device);
      for (BluetoothService service in services) {
        if (service.uuid.toString() == "19B10000-E8F2-537E-4F6C-D104768A1214") {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == "19B10001-E8F2-537E-4F6C-D104768A1214") {
              bleManager.listenToCharacteristic(characteristic).listen((data) {
                AudioService().saveAudioData(data);
              });
              break;
            }
          }
          break;
        }
      }

      setState(() {
        connectedDevice = device;
        _isScanning = false;
      });

      _showSuccessSnackBar("Connected to ${device.name.isEmpty ? "Unknown Device" : device.name}");
      
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      _showErrorSnackBar("Connection failed. Please try again.");
    }
  }

  // Removing _disconnectDevice method as it's no longer needed since we're
  // not showing the persistent connection status

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Connect Device',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded),
                    onPressed: _isScanning ? null : _startScan,
                  ),
                ],
              ),
            ),

            // Scanning Animation and Status
            if (_isScanning)
              Container(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bluetooth_searching_rounded,
                              size: 40,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Scanning for devices...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

            // Device List
            Expanded(
              child: scanResults.isEmpty
                  ? Center(
                      child: Text(
                        _isScanning
                            ? ''
                            : 'No devices found\nPull down to refresh',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _startScan(),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: scanResults.length,
                        itemBuilder: (context, index) {
                          final device = scanResults[index].device;
                          final rssi = scanResults[index].rssi;
                          
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _connectToDevice(device),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.bluetooth_rounded,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.name.isEmpty ? "Unknown Device" : device.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            device.id.toString(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRssiColor(rssi).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${rssi}dBm',
                                        style: TextStyle(
                                          color: _getRssiColor(rssi),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // We've removed the permanent connection status container since we're
            // showing the snackbar and navigating away immediately after connection
          ],
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -70) return Colors.green;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }
}