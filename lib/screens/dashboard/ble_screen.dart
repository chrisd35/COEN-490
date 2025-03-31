import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '/utils/ble_manager.dart';
import 'package:logging/logging.dart' as logging;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

final _logger = logging.Logger('BLEScreen');

class BLEScreen extends StatefulWidget {
  const BLEScreen({super.key});

  @override
  State<BLEScreen> createState() => _BLEScreenState();
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
      duration: const Duration(seconds: 2),
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
      _logger.info("All permissions granted");
    } else {
      _logger.warning("Permissions not granted");
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Permissions Required',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Please enable Bluetooth and Location permissions to scan for devices.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D557E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Open Settings',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
    });
    
    final currentContext = context;
    
    final bleManager = Provider.of<BLEManager>(currentContext, listen: false);
    bleManager.scanDevices(timeout: const Duration(seconds: 10)).listen(
      (results) {
        if (!mounted) return;
        
        setState(() {
          const targetService = "19B10000-E8F2-537E-4F6C-D104768A1214";
          const targetName = "ESP32_Combined";
          scanResults = results.where((result) {
            final hasTargetUuid = result.advertisementData.serviceUuids.any(
              (uuid) => uuid.toString().toUpperCase() == targetService.toUpperCase(),
            );
            final deviceName = result.device.platformName;
            final isTargetName = deviceName.toUpperCase() == targetName.toUpperCase();
            return hasTargetUuid || isTargetName;
          }).toList();
          _isScanning = false;
        });
      },
      onError: (error) {
        _logger.severe("BLE scan error: $error");
        
        if (!mounted) return;
        
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
      final currentContext = context;
      final bleManager = Provider.of<BLEManager>(currentContext, listen: false);
      
      _logger.info("Attempting to connect to device: ${device.platformName}");
      
      await bleManager.connectToDevice(device);
      _logger.info("Connection attempt completed");
      
      if (!mounted) return;
      
      setState(() {
        connectedDevice = device;
        _isScanning = false;
      });

      final deviceName = device.platformName.isEmpty ? "Unknown Device" : device.platformName;
      _showSuccessSnackBar("Connected to $deviceName");
      
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.pop(context);
      });
    } catch (e) {
      _logger.severe("Connection error: $e");
      
      if (!mounted) return;
      
      setState(() {
        _isScanning = false;
      });
      _showErrorSnackBar("Connection failed. Please try again.");
    }
  }
 
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Custom signal strength icon
  Widget _buildSignalStrengthIcon(int rssi) {
    Color color;
    int signalLevel;

    if (rssi >= -70) {
      color = Colors.green;
      signalLevel = 3;
    } else if (rssi >= -80) {
      color = Colors.orange;
      signalLevel = 2;
    } else {
      color = Colors.red;
      signalLevel = 1;
    }

    return Row(
      children: List.generate(
        3, 
        (index) => Container(
          width: 6,
          height: index < signalLevel ? 12 : 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: index < signalLevel 
              ? color.withAlpha(100 * (index + 1)) 
              : color.withAlpha(26),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Redesigned App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Connect Device',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF263238),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _isScanning ? null : _startScan,
                  ),
                ],
              ),
            ),

            // Scanning Animation
            if (_isScanning)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
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
                              color: const Color(0xFF1D557E).withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bluetooth_searching_rounded,
                              size: 40,
                              color: const Color(0xFF1D557E),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scanning for devices...',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF546E7A),
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
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: const Color(0xFF546E7A),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _startScan(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
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
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1D557E).withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.bluetooth_rounded,
                                        color: const Color(0xFF1D557E),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        device.platformName.isEmpty ? "Unknown Device" : device.platformName,
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF263238),
                                        ),
                                      ),
                                    ),
                                    _buildSignalStrengthIcon(rssi),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 300.ms);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}