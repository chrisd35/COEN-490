import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_sound_processing/flutter_sound_processing.dart';

class FeatureProcessor {
  static List<String> featureNames = [];
  static List<double> means = [];
  static List<double> scales = [];

  static Future<void> init() async {
    final params =
        await rootBundle.loadString('assets/model/scaler_params.json');
    final data = json.decode(params);
    featureNames = List<String>.from(data['feature_names']);
    means = List<double>.from(data['mean']);
    scales = List<double>.from(data['scale']);
  }

  // Make this method async
  static Future<List<double>> processAudio(List<double> audio) async {
    final mfccs = await _extractMFCC(audio); // Await the async MFCC extraction
    return _normalize(mfccs);
  }

  // Updated MFCC extraction using flutter_sound_processing
  static Future<List<double>> _extractMFCC(List<double> audio) async {
    try {
      // Extract MFCC matrix (2D list of frames)
      final featureMatrix = await FlutterSoundProcessing().getFeatureMatrix(
        signals: audio,
        sampleRate: 44100,
        mfcc: 13,
        fftSize: 512,
        hopLength: 256,
        nMels: 40,
      );

      // Handle null check
      if (featureMatrix == null) {
        throw Exception('Failed to extract MFCC features: null matrix');
      }

      // Convert the feature matrix to List<double>
      List<double> mfccFeatures = [];

      // Handle different possible types of feature matrix
      if (featureMatrix is List) {
        for (dynamic frame in featureMatrix) {
          if (frame is List) {
            // Handle list of numbers
            for (dynamic value in frame) {
              if (value is num) {
                mfccFeatures.add(value.toDouble());
              }
            }
          } else if (frame is num) {
            // Handle single number
            mfccFeatures.add(frame.toDouble());
          }
        }
      }

      if (mfccFeatures.isEmpty) {
        throw Exception('No MFCC features extracted');
      }

      return mfccFeatures;
    } catch (e) {
      print('Error extracting MFCC features: $e');
      throw Exception('MFCC extraction failed: $e');
    }
  }

  // Normalization logic remains the same
  static List<double> _normalize(List<double> features) {
    return List.generate(
        features.length, (i) => (features[i] - means[i]) / scales[i]);
  }
}
