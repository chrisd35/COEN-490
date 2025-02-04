import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:typed_data';

class AudioService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Save audio data to Firebase
  Future<void> saveAudioData(List<int> data) async {
    try {
      // Convert data to Uint8List
      Uint8List audioBytes = Uint8List.fromList(data);

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child("audio/${DateTime.now().millisecondsSinceEpoch}.wav");
      final uploadTask = storageRef.putData(audioBytes);

      // Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Realtime Database
      await _database.child("audio_recordings").push().set({
        "url": downloadUrl,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });

      print("Audio data saved to Firebase");
    } catch (e) {
      print("Error saving audio data: $e");
    }
  }

  // Fetch the latest audio recording URL
  Future<String?> getLatestAudioUrl() async {
    try {
      final databaseEvent = await _database.child("audio_recordings").orderByChild("timestamp").limitToLast(1).once();
      final dataSnapshot = databaseEvent.snapshot;

      if (dataSnapshot.value != null) {
        // Extract the URL from the latest recording
        final Map<dynamic, dynamic> recordings = dataSnapshot.value as Map<dynamic, dynamic>;
        final latestRecording = recordings.values.last;
        return latestRecording["url"];
      }
    } catch (e) {
      print("Error fetching audio URL: $e");
    }
    return null;
  }

  // Fetch audio data from Firebase Storage
 Future<Uint8List?> getAudioData(String url) async {
  try {
    if (url.isEmpty || !url.startsWith("https://")) {
      print("Invalid URL: $url");
      return null;
    }
    final ref = _storage.refFromURL(url);
    final data = await ref.getData();
    return data;
  } catch (e) {
    print("Error fetching audio data: $e");
  }
  return null;
}}