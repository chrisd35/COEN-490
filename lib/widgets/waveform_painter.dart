import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A custom painter class to visualize audio waveforms
class WaveformPainter extends CustomPainter {
  final List<int> audioData;
  final Color waveColor;
  final Color backgroundColor;
  final double strokeWidth;
  final bool showGrid;
  final double maxAmplitude;
  final int sampleRate;

  WaveformPainter({
    required this.audioData,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.strokeWidth = 2.0,
    this.showGrid = true,
    this.maxAmplitude = 32768.0, // Full scale for 16-bit audio
    this.sampleRate = 16000, // Default to 16kHz
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    if (backgroundColor != Colors.transparent) {
      final Paint backgroundPaint = Paint()..color = backgroundColor;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    }

    // Draw grid if enabled
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Draw waveform
    if (audioData.isNotEmpty) {
      _drawWaveform(canvas, size);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withAlpha(77) // 0.3 * 255 ≈ 77
      ..strokeWidth = 1.0;

    // Draw horizontal center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      gridPaint,
    );

    // Draw horizontal grid lines
    for (int i = 1; i < 5; i++) {
      double y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      y = size.height * (10 - i) / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical time markers
    final double secondWidth = size.width / (audioData.length / sampleRate / 2);
    for (int i = 0; i < (audioData.length / sampleRate / 2).ceil(); i++) {
      final double x = i * secondWidth;
      if (x <= size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }
  }

  void _drawWaveform(Canvas canvas, Size size) {
    final Paint wavePaint = Paint()
      ..color = waveColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Calculate the number of points to plot
    final int totalPoints = math.min(audioData.length ~/ 2, size.width.toInt());
    final double pointSpacing = size.width / totalPoints;
    
    // Calculate how many samples to skip between points
    final int skipSamples = math.max(1, audioData.length ~/ 2 ~/ totalPoints);
    
    Path wavePath = Path();
    bool pathStarted = false;

    for (int i = 0; i < totalPoints; i++) {
      // Calculate sample index
      final int sampleIndex = (i * skipSamples) * 2;
      if (sampleIndex >= audioData.length - 1) break;
      
      // Convert bytes to 16-bit sample
      int sample = (audioData[sampleIndex] & 0xFF) | ((audioData[sampleIndex + 1] & 0xFF) << 8);
      if (sample > 32767) sample -= 65536; // Convert to signed
      
      // Normalize and scale the sample
      final double normalized = sample / maxAmplitude;
      final double y = size.height / 2 * (1 - normalized);
      final double x = i * pointSpacing;

      // Start the path at the first point
      if (!pathStarted) {
        wavePath.moveTo(x, y);
        pathStarted = true;
      } else {
        wavePath.lineTo(x, y);
      }
    }

    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return audioData != oldDelegate.audioData ||
        waveColor != oldDelegate.waveColor ||
        backgroundColor != oldDelegate.backgroundColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        showGrid != oldDelegate.showGrid;
  }
}

/// A widget to display a waveform visualization of audio data
class WaveformVisualizer extends StatelessWidget {
  final List<int> audioData;
  final Color waveColor;
  final Color backgroundColor;
  final double strokeWidth;
  final bool showGrid;
  final double height;
  final int sampleRate;

  const WaveformVisualizer({
    super.key,
    required this.audioData,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.strokeWidth = 2.0,
    this.showGrid = true,
    this.height = 200.0,
    this.sampleRate = 16000,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: WaveformPainter(
          audioData: audioData,
          waveColor: waveColor,
          backgroundColor: backgroundColor,
          strokeWidth: strokeWidth,
          showGrid: showGrid,
          sampleRate: sampleRate,
        ),
        size: Size.infinite,
      ),
    );
  }
}