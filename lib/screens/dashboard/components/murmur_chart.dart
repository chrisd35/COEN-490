import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import '/screens/registration/firebase_service.dart';
import '/utils/models.dart';

class MurmurChart extends StatefulWidget {
  final String uid;

  const MurmurChart({Key? key, required this.uid}) : super(key: key);

  @override
  _MurmurChartState createState() => _MurmurChartState();
}

class _MurmurChartState extends State<MurmurChart> {
  Patient? _selectedPatient;
  Recording? _selectedRecording;
  final FirebaseService _firebaseService = FirebaseService();
  String _result = "No result yet";
  late Interpreter _interpreter;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'backend/ModelTree/heart_murmur.tflite',
    );
  }

  Future<void> _analyzeRecording(Recording recording) async {
    try {
      // Print the download URL for debugging
      print('Download URL: ${recording.downloadUrl}');

      // Use the download URL as the file path
      final String filePath = recording.downloadUrl ?? '';
      if (filePath.isEmpty) {
        throw Exception('Download URL is empty');
      }

      const platform = MethodChannel('com.example.coen_490/extract_features');
      final String featuresJson = await platform.invokeMethod(
        'extractFeatures',
        {'filePath': filePath},
      );
      final dynamic decodedJson = json.decode(featuresJson);

      // Check if the decoded JSON is a Map and contains an error
      if (decodedJson is Map && decodedJson.containsKey('error')) {
        throw Exception('Feature extraction error: ${decodedJson['error']}');
      }

      // Ensure the decoded JSON is a List
      if (decodedJson is! List) {
        throw Exception('Unexpected JSON format');
      }

      List<double> features = List<double>.from(decodedJson);

      // Run AI model inference
      var output = List.filled(1, 0);
      _interpreter.run([features], output);
      setState(() {
        _result = output[0] == 0 ? "Normal" : "Murmur";
      });
    } catch (e) {
      print('Error analyzing recording: $e');
      setState(() {
        _result = 'Error analyzing recording: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Murmur Analysis'), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Patient>>(
              stream: _firebaseService.getPatientsStream(widget.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return Center(child: Text('No patients found'));
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final patient = snapshot.data![index];
                    return _buildPatientCard(patient);
                  },
                );
              },
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Analysis Result: $_result",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Patient patient) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          patient.fullName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          FutureBuilder<List<Recording>>(
            future: _firebaseService.getRecordingsForPatient(
              widget.uid,
              patient.medicalCardNumber,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No recordings found'));
              }

              return Column(
                children:
                    snapshot.data!.map((recording) {
                      return ListTile(
                        title: Text(recording.timestamp.toString()),
                        trailing: IconButton(
                          icon: Icon(Icons.analytics),
                          onPressed: () => _analyzeRecording(recording),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedRecording = recording;
                          });
                        },
                        selected: _selectedRecording == recording,
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }
}
