import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '/utils/models.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
import '../registration/firebase_service.dart';

class PatientDetails extends StatelessWidget {
  final Patient patient;
  final FirebaseService _firebaseService = FirebaseService();

  PatientDetails({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            patient.fullName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => NavigationService.goBack(),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'edit') {
                  // Check if the route exists, otherwise show a message
                  try {
                    NavigationService.navigateTo(
                      AppRoutes.editPatient,
                      arguments: {'patient': patient},
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Edit patient feature is coming soon!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } else if (value == 'delete') {
                  _showDeletePatientDialog(context);
                } else if (value == 'manage_data') {
                  _showManageDataDialog(context);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit Patient'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'manage_data',
                  child: Row(
                    children: [
                      Icon(Icons.storage, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Manage Patient Data'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Patient'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.grey[100],
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Patient Overview Card
                _buildPatientCard(context),
                
                SizedBox(height: 16),
                
                // Categories grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildCategoryCard(
                      context: context,
                      icon: Icons.monitor_heart,
                      title: 'ECG',
                      color: Colors.red[400]!,
                      onTap: () => NavigationService.navigateTo(
                        AppRoutes.ecgMonitoring,
                        arguments: {
                          'preselectedPatientId': patient.medicalCardNumber,
                        },
                      ),
                    ),
                    _buildCategoryCard(
                      context: context,
                      icon: Icons.air,
                      title: 'Oxygen',
                      color: Colors.blue[400]!,
                      onTap: () => NavigationService.navigateTo(
                        AppRoutes.oxygenMonitoring,
                        arguments: {
                          'preselectedPatientId': patient.medicalCardNumber,
                        },
                      ),
                    ),
                    _buildCategoryCard(
                      context: context,
                      icon: Icons.volume_up,
                      title: 'Murmur',
                      color: Colors.purple[400]!,
                      onTap: () => NavigationService.navigateTo(
                        AppRoutes.murmurRecord,
                        arguments: {
                          'preselectedPatientId': patient.medicalCardNumber,
                        },
                      ),
                    ),
                    _buildCategoryCard(
                      context: context,
                      icon: Icons.history,
                      title: 'History',
                      color: Colors.green[400]!,
                      onTap: () => _showHistoryOptions(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.blue[700],
                  child: Text(
                    patient.fullName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: ${patient.medicalCardNumber}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            _buildInfoRow(Icons.calendar_today, 'Date of Birth', patient.dateOfBirth),
            SizedBox(height: 8),
            _buildInfoRow(Icons.people, 'Gender', patient.gender),
            SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Phone', patient.phoneNumber),
            SizedBox(height: 8),
            _buildInfoRow(Icons.email, 'Email', patient.email),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color,
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue[700]),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showHistoryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[100],
                  child: Icon(Icons.monitor_heart, color: Colors.red),
                ),
                title: Text('ECG History'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteDataConfirmation(
                      context, 
                      'ECG',
                      'This will permanently delete all ECG readings for this patient.',
                      () => _deleteAllECGReadings(context),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  NavigationService.navigateTo(
                    AppRoutes.ecgHistory,
                    arguments: {
                      'preselectedPatientId': patient.medicalCardNumber,
                    },
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.air, color: Colors.blue),
                ),
                title: Text('Oxygen Monitoring History'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteDataConfirmation(
                      context, 
                      'Oxygen Monitoring',
                      'This will permanently delete all oxygen monitoring sessions for this patient.',
                      () => _deleteAllPulseOxSessions(context),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  NavigationService.navigateTo(
                    AppRoutes.pulseOxHistory,
                    arguments: {
                      'preselectedPatientId': patient.medicalCardNumber,
                    },
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  child: Icon(Icons.volume_up, color: Colors.purple),
                ),
                title: Text('Audio Recordings'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[300]),
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteDataConfirmation(
                      context, 
                      'Audio Recordings',
                      'This will permanently delete all audio recordings for this patient.',
                      () => _deleteAllRecordings(context),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  NavigationService.navigateTo(
                    AppRoutes.recordingPlayback,
                    arguments: {
                      'preselectedPatientId': patient.medicalCardNumber,
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeletePatientDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Patient?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete all patient data, including:',
                style: TextStyle(color: Colors.red[700]),
              ),
              SizedBox(height: 12),
              _buildDeleteBulletPoint('ECG readings'),
              _buildDeleteBulletPoint('Oxygen monitoring data'),
              _buildDeleteBulletPoint('Audio recordings'),
              _buildDeleteBulletPoint('Patient information'),
              SizedBox(height: 16),
              Text(
                'Type "DELETE" to confirm:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'DELETE',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text == 'DELETE') {
                  Navigator.of(dialogContext).pop();
                  _deletePatient(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please type "DELETE" to confirm'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
              child: Text('DELETE PATIENT'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeleteBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showManageDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Manage Patient Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.monitor_heart, color: Colors.red),
                title: Text('Delete All ECG Data'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showDeleteDataConfirmation(
                    context, 
                    'ECG Data',
                    'This will permanently delete all ECG readings for this patient.',
                    () => _deleteAllECGReadings(context),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.air, color: Colors.blue),
                title: Text('Delete All Oxygen Data'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showDeleteDataConfirmation(
                    context, 
                    'Oxygen Data',
                    'This will permanently delete all oxygen monitoring sessions for this patient.',
                    () => _deleteAllPulseOxSessions(context),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.volume_up, color: Colors.purple),
                title: Text('Delete All Audio Recordings'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showDeleteDataConfirmation(
                    context, 
                    'Audio Recordings',
                    'This will permanently delete all audio recordings for this patient.',
                    () => _deleteAllRecordings(context),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red[700]),
                title: Text('Delete All Patient Data'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showDeleteDataConfirmation(
                    context, 
                    'All Patient Data',
                    'This will permanently delete all data for this patient (but keep the patient record).',
                    () => _deleteAllPatientData(context),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDataConfirmation(
    BuildContext context, 
    String dataType, 
    String message,
    Function() onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete $dataType?'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
              child: Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePatient(BuildContext context) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Delete all patient data
      await _deleteAllPatientData(context, showLoadingIndicator: false);
      
      // Delete the patient
      await _firebaseService.deletePatient(
        uid, 
        patient.medicalCardNumber,
        "DELETE", // This is the required confirmation text
      );

      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      NavigationService.goBack();
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting patient: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAllPatientData(BuildContext context, {bool showLoadingIndicator = true}) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator if requested
    if (showLoadingIndicator) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext loadingContext) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }

    try {
      // Delete all recordings
      await _firebaseService.deleteAllRecordings(uid, patient.medicalCardNumber);
      
      // Delete all ECG readings
      await _firebaseService.deleteAllECGReadings(uid, patient.medicalCardNumber);
      
      // Delete all PulseOx sessions
      await _firebaseService.deleteAllPulseOxSessions(uid, patient.medicalCardNumber);

      // Dismiss loading indicator if we showed it
      if (showLoadingIndicator) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All patient data deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator if we showed it
      if (showLoadingIndicator) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting patient data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        rethrow; // Rethrow for the _deletePatient method to catch
      }
    }
  }

  Future<void> _deleteAllRecordings(BuildContext context) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await _firebaseService.deleteAllRecordings(uid, patient.medicalCardNumber);
      
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All recordings deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting recordings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAllECGReadings(BuildContext context) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await _firebaseService.deleteAllECGReadings(uid, patient.medicalCardNumber);
      
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All ECG readings deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting ECG readings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAllPulseOxSessions(BuildContext context) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await _firebaseService.deleteAllPulseOxSessions(uid, patient.medicalCardNumber);
      
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All oxygen monitoring data deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting oxygen monitoring data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}