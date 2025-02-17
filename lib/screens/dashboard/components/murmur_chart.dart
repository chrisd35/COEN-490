import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '/screens/registration/firebase_service.dart';
import '/utils/models.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'dart:io'; // Import dart:io

class MurmurChart extends StatefulWidget {
  @override
  _MurmurChartState createState() => _MurmurChartState();
}

class _MurmurChartState extends State<MurmurChart> {
  String _result = "No result yet";
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: "assets/backend/ModelTree/heart_murmur.tflite",
    );
    print("Model loaded: $res");
  }

  Future<void> runInference(Uint8List input) async {
    var output = await Tflite.runModelOnBinary(
      binary: input,
      numResults: 2,
      threshold: 0.5,
    );
    setState(() {
      _result = output.toString();
    });
    print("Output: $output");
  }

  Future<void> fetchAndAnalyzeRecording(
      String uid, String medicalCardNumber) async {
    List<Recording> recordings =
        await _firebaseService.getRecordingsForPatient(uid, medicalCardNumber);
    if (recordings.isNotEmpty) {
      // For simplicity, we'll use the latest recording
      Recording latestRecording = recordings.first;
      String downloadUrl = latestRecording.downloadUrl ?? '';
      Uint8List fileBytes = await downloadFile(downloadUrl);
      Uint8List input = await processAudioFile(fileBytes);
      runInference(input);
    } else {
      setState(() {
        _result = "No recordings found for this patient.";
      });
    }
  }

  Future<Uint8List> downloadFile(String url) async {
    final ref = FirebaseStorage.instance.refFromURL(url);
    final data = await ref.getData();
    if (data == null) {
      throw Exception("Failed to download file");
    }
    return data;
  }

  Future<Uint8List> processAudioFile(Uint8List fileBytes) async {
    // Save the fileBytes to a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_audio.wav');
    await tempFile.writeAsBytes(fileBytes);

    // Use a platform channel to call the Python script and extract features
    final methodChannel =
        MethodChannel('com.example.coen_490/extract_features');
    final result = await methodChannel
        .invokeMethod('extractFeatures', {'filePath': tempFile.path});

    // Convert the result to Uint8List
    final features = jsonDecode(result) as List<dynamic>;
    final float32List =
        Float32List.fromList(features.map((e) => e as double).toList());
    return float32List.buffer.asUint8List();
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
                  // Replace with actual user ID and medical card number
                  String uid = "user_id";
                  String medicalCardNumber = "medical_card_number";
                  fetchAndAnalyzeRecording(uid, medicalCardNumber);
                },
                child: Text('Fetch and Analyze Recording'),
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
