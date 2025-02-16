import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';
import 'dart:typed_data';

class MurmurChart extends StatefulWidget {
  @override
  _MurmurChartState createState() => _MurmurChartState();
}

class _MurmurChartState extends State<MurmurChart> {
  String _result = "No result yet";

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: "backend/ModelTree/heart_murmur.tflite",
    );
    print("Model loaded: $res");
  }

  Future<void> runInference(List<double> input) async {
    var output = await Tflite.runModelOnBinary(
      binary: inputToByteList(input),
      numResults: 2,
      threshold: 0.5,
    );
    setState(() {
      _result = output.toString();
    });
    print("Output: $output");
  }

  Uint8List inputToByteList(List<double> input) {
    var buffer = Float32List.fromList(input).buffer;
    return buffer.asUint8List();
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Murmur Detection')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Murmur Findings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Replace with actual input data
                  List<double> sampleInput = List<double>.filled(323, 0.0);
                  runInference(sampleInput);
                },
                child: Text('Run Inference'),
              ),
              SizedBox(height: 20),
              Text(
                'Result: $_result',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
