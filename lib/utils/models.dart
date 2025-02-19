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
    // Convert averages map
    Map<String, double> parseAverages() {
      var averagesData = data['averages'];
      if (averagesData == null) return {};
      
      Map<String, double> result = {};
      (averagesData as Map).forEach((key, value) {
        if (value is num) {
          result[key.toString()] = value.toDouble();
        }
      });
      return result;
    }

    // Convert readings list
    List<Map<String, dynamic>> parseReadings() {
  var readingsData = data['readings'];
  if (readingsData == null) return [];
  
  List<Map<String, dynamic>> readingsList = [];
  
  void convertReading(Map<String, dynamic> readingMap) {
    if (readingMap.containsKey('heartRate')) {
      readingMap['heartRate'] = (readingMap['heartRate'] as num).toDouble();
    }
    if (readingMap.containsKey('spO2')) {
      readingMap['spO2'] = (readingMap['spO2'] as num).toDouble();
    }
    if (readingMap.containsKey('temperature')) {
      readingMap['temperature'] = (readingMap['temperature'] as num).toDouble();
    }
  }
  
  if (readingsData is List) {
    for (var reading in readingsData) {
      if (reading is Map) {
        var readingMap = Map<String, dynamic>.from(reading);
        convertReading(readingMap);
        readingsList.add(readingMap);
      }
    }
  } else if (readingsData is Map) {
    for (var reading in readingsData.values) {
      if (reading is Map) {
        var readingMap = Map<String, dynamic>.from(reading);
        convertReading(readingMap);
        readingsList.add(readingMap);
      }
    }
  }
  
  return readingsList;
}


    return PulseOxSession(
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      averages: parseAverages(),
      readings: parseReadings(),
      readingCount: (data['readingCount'] as num?)?.toInt() ?? 0,
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
extension PulseOxSessionExtension on PulseOxSession {
  List<double> get heartRateReadings {
    return readings.map((r) {
      final value = r['heartRate'];
      if (value is int) {
        return value.toDouble();
      } else if (value is double) {
        return value;
      }
      return 0.0;
    }).toList();
  }

  List<double> get spO2Readings {
    return readings.map((r) {
      final value = r['spO2'];
      if (value is int) {
        return value.toDouble();
      } else if (value is double) {
        return value;
      }
      return 0.0;
    }).toList();
  }

  List<int> get timestamps {
    return readings.map((r) {
      final value = r['timestamp'];
      if (value is int) {
        return value;
      }
      return 0;
    }).toList();
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
  List<PulseOxSession> pulseOxSessions;
  List<ECGReading> ecgReadings;

  Patient({
    required this.fullName,
    required this.email,
    required this.medicalCardNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.phoneNumber,
    List<Recording>? recordings,
    List<PulseOxSession>? pulseOxSessions,
    List<ECGReading>? ecgReadings,
  })  : recordings = recordings ?? [],
        pulseOxSessions = pulseOxSessions ?? [],
        ecgReadings = ecgReadings ?? [];

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'medicalCardNumber': medicalCardNumber,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'phoneNumber': phoneNumber,
    };
  }

  factory Patient.fromMap(Map<dynamic, dynamic> data) {
    // Handle optional fields that might be null or in different formats
    List<Recording> parseRecordings() {
      var recordingsData = data['recordings'];
      if (recordingsData == null) return [];
      
      if (recordingsData is List) {
        return recordingsData
            .map((x) => Recording.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      } else if (recordingsData is Map) {
        return recordingsData.values
            .map((x) => Recording.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    }

    List<PulseOxSession> parsePulseOxSessions() {
      var sessionsData = data['pulseOxSessions'];
      if (sessionsData == null) return [];
      
      if (sessionsData is List) {
        return sessionsData
            .map((x) => PulseOxSession.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      } else if (sessionsData is Map) {
        return sessionsData.values
            .map((x) => PulseOxSession.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    }

    List<ECGReading> parseECGReadings() {
      var readingsData = data['ecgReadings'];
      if (readingsData == null) return [];
      
      if (readingsData is List) {
        return readingsData
            .map((x) => ECGReading.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      } else if (readingsData is Map) {
        return readingsData.values
            .map((x) => ECGReading.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    }

    return Patient(
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      medicalCardNumber: data['medicalCardNumber'] ?? '',
      dateOfBirth: data['dateOfBirth'] ?? '',
      gender: data['gender'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      recordings: parseRecordings(),
      pulseOxSessions: parsePulseOxSessions(),
      ecgReadings: parseECGReadings(),
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