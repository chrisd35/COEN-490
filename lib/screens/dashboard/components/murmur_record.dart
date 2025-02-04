import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import '../../../services/audio_service.dart';

class MurmurRecord extends StatefulWidget {
  @override
  _MurmurRecordState createState() => _MurmurRecordState();
}

class _MurmurRecordState extends State<MurmurRecord> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  Uint8List? _audioData;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
    _fetchLatestAudioData();
  }

  Future<void> _fetchLatestAudioData() async {
    final url = await _audioService.getLatestAudioUrl();
    if (url != null) {
      final data = await _audioService.getAudioData(url);
      setState(() {
        _audioData = data;
      });
    }
  }

  void _playAudio() async {
    if (_audioData != null) {
      await _audioPlayer.play(BytesSource(_audioData!));
    }
  }

  void _pauseAudio() async {
    await _audioPlayer.pause();
  }

  void _stopAudio() async {
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
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
            // Header Container
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[700]!.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.volume_up,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Audio Analysis",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Review recorded heart sounds",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: _audioData != null
                    ? Container(
                        padding: EdgeInsets.all(32),
                        margin: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Waveform placeholder
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.blue[700]!.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.graphic_eq,
                                  size: 48,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                            SizedBox(height: 32),
                            
                            // Control buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildControlButton(
                                  icon: Icons.skip_previous,
                                  onPressed: () {},
                                  color: Colors.grey[400]!,
                                ),
                                SizedBox(width: 16),
                                _buildControlButton(
                                  icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                                  onPressed: _isPlaying ? _pauseAudio : _playAudio,
                                  color: Colors.blue[700]!,
                                  isMain: true,
                                ),
                                SizedBox(width: 16),
                                _buildControlButton(
                                  icon: Icons.skip_next,
                                  onPressed: () {},
                                  color: Colors.grey[400]!,
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            _buildControlButton(
                              icon: Icons.stop,
                              onPressed: _stopAudio,
                              color: Colors.red[400]!,
                              label: "Stop",
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.volume_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            "No audio data available",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Record a new murmur or select an existing recording",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
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

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isMain = false,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMain ? 72 : 56,
          height: isMain ? 72 : 56,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMain ? 36 : 28),
              ),
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: Icon(
              icon,
              size: isMain ? 36 : 24,
              color: Colors.white,
            ),
          ),
        ),
        if (label != null) ...[
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}