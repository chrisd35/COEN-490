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

  // Convert User object to a Map for Realtime Database
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

  // Create a User object from a Realtime Database snapshot
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
