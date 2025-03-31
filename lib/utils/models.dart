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
  final int bitsPerSample;
  final int channels;
  dynamic peakAmplitude;
  String? downloadUrl;
  
  // Heart murmur detection properties
  double murmurProbability = 0.0;
  String murmurType = 'None';
  String murmurGrade = 'N/A';
  bool isSystolicMurmur = false;
  bool isDiastolicMurmur = false;
  double dominantFrequency = 0.0;
  double signalToNoiseRatio = 0.0;

  Recording({
    required this.timestamp,
    required this.filename,
    required this.duration,
    required this.sampleRate,
    this.bitsPerSample = 16,
    this.channels = 1,
    required this.peakAmplitude,
    this.downloadUrl,
    this.murmurProbability = 0.0,
    this.murmurType = 'None',
    this.murmurGrade = 'N/A',
    this.isSystolicMurmur = false,
    this.isDiastolicMurmur = false,
    this.dominantFrequency = 0.0,
    this.signalToNoiseRatio = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'filename': filename,
      'duration': duration,
      'sampleRate': sampleRate,
      'bitsPerSample': bitsPerSample,
      'channels': channels,
      'peakAmplitude': peakAmplitude,
      'downloadUrl': downloadUrl,
      'murmurProbability': murmurProbability,
      'murmurType': murmurType,
      'murmurGrade': murmurGrade,
      'isSystolicMurmur': isSystolicMurmur,
      'isDiastolicMurmur': isDiastolicMurmur,
      'dominantFrequency': dominantFrequency,
      'signalToNoiseRatio': signalToNoiseRatio,
    };
  }

 factory Recording.fromMap(Map<dynamic, dynamic> data) {
  // Handle peak amplitude
  var amplitude = data['peakAmplitude'];
  double peakAmplitude = 0.0;
  if (amplitude is int) {
    peakAmplitude = amplitude.toDouble();
  } else if (amplitude is double) {
    peakAmplitude = amplitude;
  }
  
  // Helper function to safely extract numeric values
  double safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return 0.0;
  }
  
  // Helper function to safely extract boolean values
  bool safeBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }
  
  return Recording(
    timestamp: DateTime.parse(data['timestamp']),
    filename: data['filename'],
    duration: data['duration'] ?? 0,
    sampleRate: data['sampleRate'] ?? 2000,
    bitsPerSample: data['bitsPerSample'] ?? 16,
    channels: data['channels'] ?? 1,
    peakAmplitude: peakAmplitude,
    downloadUrl: data['downloadUrl'],
    // Heart murmur properties with safe type handling
    murmurProbability: safeDouble(data['murmurProbability']),
    murmurType: data['murmurType'] as String? ?? 'None',
    murmurGrade: data['murmurGrade'] as String? ?? 'N/A',
    isSystolicMurmur: safeBool(data['isSystolicMurmur']),
    isDiastolicMurmur: safeBool(data['isDiastolicMurmur']),
    dominantFrequency: safeDouble(data['dominantFrequency']),
    signalToNoiseRatio: safeDouble(data['signalToNoiseRatio']),
  );
}
  
  // Helper for displaying murmur info
  String getMurmurDescription() {
    if (murmurProbability < 0.3) {
      return 'No significant murmur detected';
    }
    
    String timing = '';
    if (isSystolicMurmur && isDiastolicMurmur) {
      timing = 'Continuous';
    } else if (isSystolicMurmur) {
      timing = 'Systolic';
    } else if (isDiastolicMurmur) {
      timing = 'Diastolic';
    }
    
    return '$timing $murmurType ($murmurGrade)';
  }
  
  // Helper to check if this recording has murmur data
  bool get hasMurmurData {
    return murmurProbability > 0.0 || murmurType != 'None';
  }
  
  // Helper to get murmur probability as a percentage string
  String get murmurProbabilityPercentage {
    return '${(murmurProbability * 100).toStringAsFixed(1)}%';
  }
  
  // Helper to get color based on murmur severity
  int getColorForMurmur() {
    if (murmurProbability < 0.3) {
      return 0xFF4CAF50; // Green
    } else if (murmurProbability < 0.6) {
      return 0xFFFFA726; // Orange
    } else {
      return 0xFFF44336; // Red
    }
  }
}