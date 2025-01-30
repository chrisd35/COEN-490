class Patient {
  final String fullName;
  final String email;
  final String medicalCardNumber;
  final String dateOfBirth;
  final String gender;
  final String phoneNumber;
  // final String ID

  Patient({
    required this.fullName,
    required this.email,
    required this.medicalCardNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.phoneNumber,
  });

  // Convert Patient object to a Map for Realtime Database
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

  // Create a Patient object from a Realtime Database snapshot
  factory Patient.fromMap(Map<dynamic, dynamic> data) {
    return Patient(
      fullName: data['fullName'],
      email: data['email'],
      medicalCardNumber: data['medicalCardNumber'],
      dateOfBirth: data['dateOfBirth'],
      gender: data['gender'],
      phoneNumber: data['phoneNumber'],
    );
  }
}
