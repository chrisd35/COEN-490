import 'package:tflite_flutter/tflite_flutter.dart';

class InferenceService {
  late Interpreter _interpreter;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/model/model.tflite');
  }

  Future<double> predict(List<double> features) async {
    final input = [features];
    final output = List<double>.filled(1, 0.0).reshape([1, 1]);
    _interpreter.run(input, output);
    return output[0][0];
  }
}
