import 'package:flutter/material.dart';
import '/utils/models.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';

class PatientDetails extends StatelessWidget {
  final Patient patient;

  // Use super parameter syntax for key
  const PatientDetails({super.key, required this.patient});

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
}