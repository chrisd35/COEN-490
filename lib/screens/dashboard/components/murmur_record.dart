import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart'; 
import '/utils/ble_manager.dart';
import '../../registration/firebase_service.dart';

class MurmurRecord extends StatefulWidget {
  final String patientId;

  const MurmurRecord({Key? key, required this.patientId}) : super(key: key);

  @override
  _MurmurRecordState createState() => _MurmurRecordState();
}

class _MurmurRecordState extends State<MurmurRecord> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isPlaying = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  double _bufferSize = 0; // To show recording progress
  Duration _recordingDuration = Duration.zero; // Track recording duration
  Timer? _recordingTimer; // Timer for recording duration

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  void _startRecording() async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    if (bleManager.connectedDevice != null) {
      try {
        await bleManager.startRecording();
        setState(() {
          _isRecording = true;
          _bufferSize = 0;
          _recordingDuration = Duration.zero; // Reset duration
        });

        // Start monitoring buffer size
        _startBufferSizeMonitoring();

        // Start recording timer
        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += Duration(seconds: 1);
          });
        });
      } catch (e) {
        _showErrorSnackBar("Failed to start recording: $e");
      }
    } else {
      _showErrorSnackBar("No device connected");
    }
  }

  void _startBufferSizeMonitoring() {
    // Update buffer size every 100ms
    Stream.periodic(Duration(milliseconds: 100)).listen((_) {
      if (_isRecording) {
        final bleManager = Provider.of<BLEManager>(context, listen: false);
        setState(() {
          _bufferSize = bleManager.audioBuffer.length.toDouble();
        });
      }
    });
  }

  void _stopRecording() async {
    final bleManager = Provider.of<BLEManager>(context, listen: false);
    try {
      _recordingTimer?.cancel(); // Stop the recording timer

      // Get the recorded data from BLE Manager
      List<int> audioData = await bleManager.stopRecording();

      if (audioData.isEmpty) {
        _showErrorSnackBar("No audio data recorded");
        return;
      }

      // Show loading indicator
      _showLoadingDialog("Saving recording...");

      // Save to Firebase with additional metadata
      await _firebaseService.saveRecording(
        widget.patientId,
        DateTime.now(),
        audioData,
        {
          'duration': _recordingDuration.inSeconds,
          'sampleRate': BLEManager.SAMPLE_RATE,
          'peakAmplitude': bleManager.peakAmplitude,
        },
      );

      // Hide loading indicator
      Navigator.pop(context);

      setState(() {
        _isRecording = false;
        _bufferSize = 0;
      });

      _showSuccessSnackBar("Recording saved successfully");
    } catch (e) {
      // Hide loading indicator if showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorSnackBar("Failed to save recording: $e");
    }
  }

  Widget _buildWaveform(BuildContext context, BLEManager bleManager) {
    return Container(
      height: 120,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: bleManager.recentAmplitudes.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: Colors.blue[700],
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue[700]!.withOpacity(0.1),
              ),
            ),
          ],
          minY: 0,
          maxY: 1,
        ),
      ),
    );
  }

  Widget _buildRecordingStatus() {
    return Column(
      children: [
        Text(
          _recordingDuration.toString().split('.').first,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        Consumer<BLEManager>(
          builder: (context, bleManager, child) {
            return Text(
              'Peak Amplitude: ${(bleManager.peakAmplitude * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

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
  void dispose() {
    _audioPlayer.dispose();
    _recordingTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Murmur Analysis",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Container with waveform
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Consumer<BLEManager>(
                builder: (context, bleManager, child) {
                  return Column(
                    children: [
                      _buildWaveform(context, bleManager),
                      SizedBox(height: 16),
                      _buildRecordingStatus(),
                    ],
                  );
                },
              ),
            ),

            Expanded(
              child: Center(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _isRecording
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(0.1),
                              ),
                              child: Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                  child: Icon(
                                    Icons.mic,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              "Recording in progress...",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue[700]!.withOpacity(0.1),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.mic_none,
                                  color: Colors.blue[700],
                                  size: 48,
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              "Tap the button below to start recording",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRecording ? _stopRecording : _startRecording,
        backgroundColor: _isRecording ? Colors.red : Colors.blue[700],
        label: Text(_isRecording ? "Stop Recording" : "Start Recording"),
        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}