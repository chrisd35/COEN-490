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

class PulseOxSession {
  final DateTime timestamp;
  final Map<String, double> averages;
  final List<Map<String, dynamic>> readings;
  final int readingCount;

  PulseOxSession({
    required this.timestamp,
    required this.averages,
    required this.readings,
    required this.readingCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'averages': averages,
      'readings': readings,
      'readingCount': readingCount,
    };
  }

  factory PulseOxSession.fromMap(Map<dynamic, dynamic> data) {
    return PulseOxSession(
      timestamp: DateTime.parse(data['timestamp']),
      averages: Map<String, double>.from(data['averages']),
      readings: List<Map<String, dynamic>>.from(data['readings']),
      readingCount: data['readingCount'],
    );
  }

  // Helper methods to get specific readings
  List<double> get heartRateReadings {
    return readings.map((r) => r['heartRate'] as double).toList();
  }

  List<double> get spO2Readings {
    return readings.map((r) => r['spO2'] as double).toList();
  }

  List<double> get temperatureReadings {
    return readings.map((r) => r['temperature'] as double).toList();
  }

  List<int> get timestamps {
    return readings.map((r) => r['timestamp'] as int).toList();
  }
}

class ECGReading {
  final DateTime timestamp;
  final String filename;
  final int duration;
  final int sampleRate;
  String? downloadUrl;

  ECGReading({
    required this.timestamp,
    required this.filename,
    required this.duration,
    required this.sampleRate,
    this.downloadUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'filename': filename,
      'duration': duration,
      'sampleRate': sampleRate,
      'downloadUrl': downloadUrl,
    };
  }

  factory ECGReading.fromMap(Map<dynamic, dynamic> data) {
    return ECGReading(
      timestamp: DateTime.parse(data['timestamp']),
      filename: data['filename'],
      duration: data['duration'],
      sampleRate: data['sampleRate'],
      downloadUrl: data['downloadUrl'],
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
  List<Recording> recordings;
  List<PulseOxSession> pulseOxSessions;  // Changed from pulseOxReadings
  List<ECGReading> ecgReadings;

  Patient({
    required this.fullName,
    required this.email,
    required this.medicalCardNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.phoneNumber,
    List<Recording>? recordings,
    List<PulseOxSession>? pulseOxSessions,  // Updated parameter
    List<ECGReading>? ecgReadings,
  })  : recordings = recordings ?? [],
        pulseOxSessions = pulseOxSessions ?? [],  // Updated initialization
        ecgReadings = ecgReadings ?? [];

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'medicalCardNumber': medicalCardNumber,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'recordings': recordings.map((r) => r.toMap()).toList(),
      'pulseOxSessions': pulseOxSessions.map((s) => s.toMap()).toList(),  // Updated
      'ecgReadings': ecgReadings.map((r) => r.toMap()).toList(),
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
      recordings: data['recordings'] != null
          ? List<Recording>.from(
              (data['recordings'] as List).map((x) => Recording.fromMap(x)))
          : [],
      pulseOxSessions: data['pulseOxSessions'] != null  // Updated
          ? List<PulseOxSession>.from(
              (data['pulseOxSessions'] as List).map((x) => PulseOxSession.fromMap(x)))
          : [],
      ecgReadings: data['ecgReadings'] != null
          ? List<ECGReading>.from(
              (data['ecgReadings'] as List).map((x) => ECGReading.fromMap(x)))
          : [],
    );
  }

  void addRecording(Recording recording) {
    recordings.add(recording);
  }

void addPulseOxSession(PulseOxSession session) {  // Updated method
    pulseOxSessions.add(session);
  }

  void addECGReading(ECGReading reading) {
    ecgReadings.add(reading);
  }
}

class Recording {
  final DateTime timestamp;
  final String filename;
  final int duration;
  final int sampleRate;
  final dynamic peakAmplitude;
  String? downloadUrl;

  Recording({
    required this.timestamp,
    required this.filename,
    required this.duration,
    required this.sampleRate,
    required this.peakAmplitude,
    this.downloadUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'filename': filename,
      'duration': duration,
      'sampleRate': sampleRate,
      'peakAmplitude': peakAmplitude,
    };
  }

  factory Recording.fromMap(Map<dynamic, dynamic> data) {
    var amplitude = data['peakAmplitude'];
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