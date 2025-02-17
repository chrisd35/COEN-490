
class User {
  final String fullName;
  final String email;
  final String password;
  final String dateOfBirth;
  final String gender;
  final String role;
  final String phoneNumber;
  final String uid;

  User({
    required this.fullName,
    required this.email,
    required this.password,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
    required this.phoneNumber,
    required this.uid,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'password': password,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'role': role,
      'phoneNumber': phoneNumber,
      'uid': uid,
    };
  }

  factory User.fromMap(Map<dynamic, dynamic> data) {
    return User(
      fullName: data['fullName'],
      email: data['email'],
      password: data['password'],
      dateOfBirth: data['dateOfBirth'],
      gender: data['gender'],
      role: data['role'],
      phoneNumber: data['phoneNumber'],
      uid: data['uid'],
    );
  }
}

class Patient {
  final String fullName;
  final String email;
  final String medicalCardNumber;
  final String dateOfBirth;
  final String gender;
  final String phoneNumber;
  List<Map<String, dynamic>> pulseOxData;
  List<Map<String, dynamic>> ecgData;

  Patient({
    required this.fullName,
    required this.email,
    required this.medicalCardNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.phoneNumber,
    List<Map<String, dynamic>>? pulseOxData,
    List<Map<String, dynamic>>? ecgData,
  })  : pulseOxData = pulseOxData ?? [],
        ecgData = ecgData ?? [];

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'medicalCardNumber': medicalCardNumber,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'pulseOxData': pulseOxData,
      'ecgData': ecgData,
    };
  }

  factory Patient.fromMap(Map<dynamic, dynamic> data) {
    return Patient(
      fullName: data['fullName'],
      email: data['email'],
      medicalCardNumber: data['medicalCardNumber'],
      dateOfBirth: data['dateOfBirth'],
      gender: data['gender'],
      phoneNumber: data['phoneNumber'],
      pulseOxData: List<Map<String, dynamic>>.from(data['pulseOxData'] ?? []),
      ecgData: List<Map<String, dynamic>>.from(data['ecgData'] ?? []),
    );
  }

  void addPulseOxData(int value, int timestamp) {
    pulseOxData.add({
      'value': value,
      'timestamp': timestamp,
    });
  }

  void addEcgData(String url, int timestamp) {
    ecgData.add({
      'url': url,
      'timestamp': timestamp,
    });
  }
}

class Recording {
  final DateTime timestamp;
  final String filename;
  final int duration;
  final int sampleRate;
  final dynamic peakAmplitude; 
  String? downloadUrl; // New field for the download URL

  Recording({
    required this.timestamp,
    required this.filename,
    required this.duration,
    required this.sampleRate,
    required this.peakAmplitude,
    this.downloadUrl,  // Optional parameter for download URL
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'filename': filename,
      'duration': duration,
      'sampleRate': sampleRate,
      'peakAmplitude': peakAmplitude,
      // We don't save the downloadUrl to the database as it's generated dynamically
    };
  }

 factory Recording.fromMap(Map<dynamic, dynamic> data) {
    var amplitude = data['peakAmplitude'];
    // Convert to double if it's an int
    double peakAmplitude = (amplitude is int) ? amplitude.toDouble() : amplitude;
    
    return Recording(
      timestamp: DateTime.parse(data['timestamp']),
      filename: data['filename'],
      duration: data['duration'],
      sampleRate: data['sampleRate'],
      peakAmplitude: peakAmplitude,
    );
  }
}