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
      appBar: AppBar(
        title: Text("Audio Playback"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Audio Playback",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            if (_audioData != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    iconSize: 48,
                    onPressed: _isPlaying ? _pauseAudio : _playAudio,
                  ),
                  IconButton(
                    icon: Icon(Icons.stop),
                    iconSize: 48,
                    onPressed: _stopAudio,
                  ),
                ],
              ),
            if (_audioData == null)
              Text(
                "No audio data available.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}