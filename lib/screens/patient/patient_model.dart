class Patient {
  final String fullName;
  final String email;
  final String medicalCardNumber;
  final String dateOfBirth;
  final String gender;
  final String phoneNumber;
  // Remove the separate audioRecordings list
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

  // Convert Patient object to a Map for Realtime Database
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

  // Create a Patient object from a Realtime Database snapshot
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

  // Remove the addAudioRecording method
  // Method to add PulseOx data
  void addPulseOxData(int value, int timestamp) {
    pulseOxData.add({
      'value': value,
      'timestamp': timestamp,
    });
  }

  // Method to add ECG data
  void addEcgData(String url, int timestamp) {
    ecgData.add({
      'url': url,
      'timestamp': timestamp,
    });
  }
}