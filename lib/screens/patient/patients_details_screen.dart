import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '/utils/models.dart';
import '../../utils/navigation_service.dart';
import '../../utils/app_routes.dart';
import '../../widgets/back_button.dart';
import '../registration/firebase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Design constants to maintain consistency with dashboard theme
class PatientDetailsTheme {
  // Main color palette - aligned with the dashboard
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Status colors
  static const Color successColor = Color(0xFF2E7D32); // Darker green
  static const Color warningColor = Color(0xFFF57F17); // Amber
  static const Color errorColor = Color(0xFFD32F2F);   // Dark red
  
  // Text colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textLight = Color(0xFF78909C);
  
  // Category card colors
  static final List<Color> categoryColors = [
    const Color(0xFFEF5350),  // Red for ECG
    const Color(0xFF42A5F5),  // Blue for Oxygen
    const Color(0xFF9C27B0),  // Purple for Murmur
    const Color(0xFF66BB6A),  // Green for History
  ];
  
  // Shadows
  static final cardShadow = BoxShadow(
    color: Colors.black.withAlpha(18),
    blurRadius: 12,
    spreadRadius: 0,
    offset: const Offset(0, 3),
  );
  
  static final subtleShadow = BoxShadow(
    color: Colors.black.withAlpha(10),
    blurRadius: 6,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  );
  
  // Text styles
  static final TextStyle headingStyle = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  static final TextStyle subheadingStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: -0.2,
    height: 1.4,
  );
  
  static final TextStyle cardTitleStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );
  
  static final TextStyle buttonTextStyle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );
  
  // Animation durations
  static const Duration defaultAnimDuration = Duration(milliseconds: 300);
  static const Duration quickAnimDuration = Duration(milliseconds: 150);
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
}

class PatientDetails extends StatefulWidget {
  final Patient patient;

  const PatientDetails({super.key, required this.patient});

  @override
  State<PatientDetails> createState() => _PatientDetailsState();
}

class _PatientDetailsState extends State<PatientDetails> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: PatientDetailsTheme.defaultAnimDuration,
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackButtonHandler(
      strategy: BackButtonHandlingStrategy.normal,
      child: Scaffold(
        backgroundColor: PatientDetailsTheme.secondaryColor,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Profile Header
                  _buildPatientHeader().animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: -0.2, end: 0),
                  
                  const SizedBox(height: 32),
                  
                  // Patient Details Card
                  _buildPatientDetailsCard().animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  
                  const SizedBox(height: 32),
                  
                  // Categories Section Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, left: 4),
                    child: Text(
                      'Monitoring',
                      style: PatientDetailsTheme.headingStyle,
                    ),
                  ).animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  
                  // Categories grid
                  _buildCategoriesGrid(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: PatientDetailsTheme.textPrimary,
      centerTitle: false,
      title: Text(
        'Patient Profile',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: PatientDetailsTheme.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => NavigationService.goBack(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.more_vert_rounded,
            color: PatientDetailsTheme.textPrimary,
            size: 24,
          ),
          onPressed: () => _showOptionsMenu(),
          tooltip: 'More options',
        ),
      ],
    );
  }

  Widget _buildPatientHeader() {
    return Row(
      children: [
        // Patient Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: PatientDetailsTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [PatientDetailsTheme.subtleShadow],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.patient.fullName.substring(0, 1).toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 20),
        
        // Patient Name and ID
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patient.fullName,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: PatientDetailsTheme.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: PatientDetailsTheme.primaryColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ID: ${widget.patient.medicalCardNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PatientDetailsTheme.primaryColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientDetailsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: PatientDetailsTheme.borderRadius,
        boxShadow: [PatientDetailsTheme.cardShadow],
      ),
      child: Column(
        children: [
          // Basic Info
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date of Birth',
                  value: widget.patient.dateOfBirth,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.people_alt_rounded,
                  label: 'Gender',
                  value: widget.patient.gender,
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey.withAlpha(20),
            margin: const EdgeInsets.symmetric(horizontal: 24),
          ),
          
          // Contact Info
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Contact Information'),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: widget.patient.phoneNumber,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: widget.patient.email,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: PatientDetailsTheme.primaryColor,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PatientDetailsTheme.secondaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: PatientDetailsTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PatientDetailsTheme.textLight,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: PatientDetailsTheme.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid() {
    final screenSize = MediaQuery.of(context).size;
    final crossAxisCount = screenSize.width > 600 ? 3 : 2;
    final childAspectRatio = screenSize.width > 600 ? 1.3 : 1.1;
    
    final categories = [
      CategoryData(
        title: 'ECG',
        icon: Icons.monitor_heart_rounded,
        color: PatientDetailsTheme.categoryColors[0],
        onTap: () => NavigationService.navigateTo(
          AppRoutes.ecgMonitoring,
          arguments: {
            'preselectedPatientId': widget.patient.medicalCardNumber,
          },
        ),
      ),
      CategoryData(
        title: 'Oxygen',
        icon: Icons.air_rounded,
        color: PatientDetailsTheme.categoryColors[1],
        onTap: () => NavigationService.navigateTo(
          AppRoutes.oxygenMonitoring,
          arguments: {
            'preselectedPatientId': widget.patient.medicalCardNumber,
          },
        ),
      ),
      CategoryData(
        title: 'Murmur',
        icon: Icons.volume_up_rounded,
        color: PatientDetailsTheme.categoryColors[2],
        onTap: () => NavigationService.navigateTo(
          AppRoutes.murmurRecord,
          arguments: {
            'preselectedPatientId': widget.patient.medicalCardNumber,
          },
        ),
      ),
      CategoryData(
        title: 'History',
        icon: Icons.history_rounded,
        color: PatientDetailsTheme.categoryColors[3],
        onTap: () => _showHistoryOptions(),
      ),
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return CategoryCard(
          title: categories[index].title,
          icon: categories[index].icon,
          color: categories[index].color,
          onTap: categories[index].onTap,
        ).animate().fadeIn(
          duration: 400.ms, 
          delay: Duration(milliseconds: 400 + (index * 100))
        ).slideY(begin: 0.2, end: 0);
      },
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Patient Options',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: PatientDetailsTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionTile(
                icon: Icons.edit_rounded,
                iconColor: PatientDetailsTheme.accentColor,
                title: 'Edit Patient',
                onTap: () {
                  Navigator.pop(context);
                  try {
                    NavigationService.navigateTo(
                      AppRoutes.editPatient,
                      arguments: {'patient': widget.patient},
                    );
                  } catch (e) {
                    _showSnackBar(
                      'Edit patient feature is coming soon!',
                      isError: false,
                      isWarning: true,
                    );
                  }
                },
              ),
              _buildOptionTile(
                icon: Icons.storage_rounded,
                iconColor: Colors.orange[700]!,
                title: 'Manage Patient Data',
                onTap: () {
                  Navigator.pop(context);
                  _showManageDataDialog();
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_rounded,
                iconColor: PatientDetailsTheme.errorColor,
                title: 'Delete Patient',
                onTap: () {
                  Navigator.pop(context);
                  _showDeletePatientDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: iconColor,
              ),
            ),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: PatientDetailsTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: PatientDetailsTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'View History',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: PatientDetailsTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildHistoryTile(
                title: 'ECG History',
                icon: Icons.monitor_heart_rounded,
                color: PatientDetailsTheme.categoryColors[0],
                onTap: () {
                  Navigator.pop(context);
                  NavigationService.navigateTo(
                    AppRoutes.ecgHistory,
                    arguments: {
                      'preselectedPatientId': widget.patient.medicalCardNumber,
                    },
                  );
                },
                onDelete: () {
                  Navigator.pop(context);
                  _showDeleteDataConfirmation(
                    dataType: 'ECG',
                    message: 'This will permanently delete all ECG readings for this patient.',
                    onConfirm: () => _deleteAllECGReadings(),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildHistoryTile(
                title: 'Oxygen Monitoring History',
                icon: Icons.air_rounded,
                color: PatientDetailsTheme.categoryColors[1],
                onTap: () {
                  Navigator.pop(context);
                  NavigationService.navigateTo(
                    AppRoutes.pulseOxHistory,
                    arguments: {
                      'preselectedPatientId': widget.patient.medicalCardNumber,
                    },
                  );
                },
                onDelete: () {
                  Navigator.pop(context);
                  _showDeleteDataConfirmation(
                    dataType: 'Oxygen Monitoring',
                    message: 'This will permanently delete all oxygen monitoring sessions for this patient.',
                    onConfirm: () => _deleteAllPulseOxSessions(),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildHistoryTile(
                title: 'Audio Recordings',
                icon: Icons.volume_up_rounded,
                color: PatientDetailsTheme.categoryColors[2],
                onTap: () {
                  Navigator.pop(context);
                  NavigationService.navigateTo(
                    AppRoutes.recordingPlayback,
                    arguments: {
                      'preselectedPatientId': widget.patient.medicalCardNumber,
                    },
                  );
                },
                onDelete: () {
                  Navigator.pop(context);
                  _showDeleteDataConfirmation(
                    dataType: 'Audio Recordings',
                    message: 'This will permanently delete all audio recordings for this patient.',
                    onConfirm: () => _deleteAllRecordings(),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: PatientDetailsTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: PatientDetailsTheme.errorColor.withAlpha(200),
                    size: 22,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete all data',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showManageDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Manage Patient Data',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PatientDetailsTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                _buildManageDataTile(
                  icon: Icons.monitor_heart_rounded,
                  color: PatientDetailsTheme.categoryColors[0],
                  title: 'Delete All ECG Data',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showDeleteDataConfirmation(
                      dataType: 'ECG Data',
                      message: 'This will permanently delete all ECG readings for this patient.',
                      onConfirm: () => _deleteAllECGReadings(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildManageDataTile(
                  icon: Icons.air_rounded,
                  color: PatientDetailsTheme.categoryColors[1],
                  title: 'Delete All Oxygen Data',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showDeleteDataConfirmation(
                      dataType: 'Oxygen Data',
                      message: 'This will permanently delete all oxygen monitoring sessions for this patient.',
                      onConfirm: () => _deleteAllPulseOxSessions(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildManageDataTile(
                  icon: Icons.volume_up_rounded,
                  color: PatientDetailsTheme.categoryColors[2],
                  title: 'Delete All Audio Recordings',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showDeleteDataConfirmation(
                      dataType: 'Audio Recordings',
                      message: 'This will permanently delete all audio recordings for this patient.',
                      onConfirm: () => _deleteAllRecordings(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _buildManageDataTile(
                  icon: Icons.delete_forever_rounded,
                  color: PatientDetailsTheme.errorColor,
                  title: 'Delete All Patient Data',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showDeleteDataConfirmation(
                      dataType: 'All Patient Data',
                      message: 'This will permanently delete all data for this patient (but keep the patient record).',
                      onConfirm: () => _deleteAllPatientData(showLoadingIndicator: true),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CLOSE',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PatientDetailsTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManageDataTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: PatientDetailsTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePatientDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Get available screen height to adjust dialog size
        final screenHeight = MediaQuery.of(dialogContext).size.height;
        final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight - 64 - keyboardHeight, // Account for padding and keyboard
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: PatientDetailsTheme.errorColor,
                    ).animate().shake(duration: 700.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Delete Patient?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: PatientDetailsTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'This will permanently delete all patient data, including:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: PatientDetailsTheme.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDeleteBulletPoint('ECG readings'),
                    _buildDeleteBulletPoint('Oxygen monitoring data'),
                    _buildDeleteBulletPoint('Audio recordings'),
                    _buildDeleteBulletPoint('Patient information'),
                    const SizedBox(height: 24),
                    Text(
                      'Type "DELETE" to confirm:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PatientDetailsTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'DELETE',
                        hintStyle: GoogleFonts.inter(
                          color: PatientDetailsTheme.textLight,
                        ),
                        filled: true,
                        fillColor: Colors.grey.withAlpha(20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: PatientDetailsTheme.primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: PatientDetailsTheme.textPrimary,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: PatientDetailsTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (controller.text == 'DELETE') {
                                Navigator.pop(dialogContext);
                                _deletePatient();
                              } else {
                                _showSnackBar(
                                  'Please type "DELETE" to confirm',
                                  isError: true,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PatientDetailsTheme.errorColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'DELETE PATIENT',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeleteBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: PatientDetailsTheme.errorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: PatientDetailsTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDataConfirmation({
    required String dataType,
    required String message,
    required Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 48,
                  color: PatientDetailsTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete $dataType?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: PatientDetailsTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: PatientDetailsTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PatientDetailsTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PatientDetailsTheme.errorColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'DELETE',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false, SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError
            ? PatientDetailsTheme.errorColor
            : isWarning
                ? PatientDetailsTheme.warningColor
                : PatientDetailsTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _deletePatient() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    _showLoadingDialog('Deleting patient...');

    try {
      // Delete all patient data
      await _deleteAllPatientData(showLoadingIndicator: false);
      
      // Delete the patient
      await _firebaseService.deletePatient(
        uid, 
        widget.patient.medicalCardNumber,
        "DELETE", // This is the required confirmation text
      );

      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      // Show success message and navigate back
      _showSnackBar('Patient deleted successfully');
      NavigationService.goBack();
    } catch (e) {
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);

      // Show error message
      _showSnackBar(
        'Error deleting patient: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _deleteAllPatientData({required bool showLoadingIndicator}) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator if requested
    if (showLoadingIndicator) {
      _showLoadingDialog('Deleting patient data...');
    }

    try {
      // Delete all recordings
      await _firebaseService.deleteAllRecordings(uid, widget.patient.medicalCardNumber);
      
      // Delete all ECG readings
      await _firebaseService.deleteAllECGReadings(uid, widget.patient.medicalCardNumber);
      
      // Delete all PulseOx sessions
      await _firebaseService.deleteAllPulseOxSessions(uid, widget.patient.medicalCardNumber);

      // Dismiss loading indicator if we showed it
      if (showLoadingIndicator && mounted) {
        Navigator.pop(context);
        
        // Show success message
        _showSnackBar('All patient data deleted successfully');
      }
    } catch (e) {
      // Dismiss loading indicator if we showed it
      if (showLoadingIndicator && mounted) {
        Navigator.pop(context);
        
        // Show error message
        _showSnackBar(
          'Error deleting patient data: ${e.toString()}',
          isError: true,
        );
      } else {
        rethrow; // Rethrow for the _deletePatient method to catch
      }
    }
  }

  Future<void> _deleteAllRecordings() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    _showLoadingDialog('Deleting recordings...');

    try {
      await _firebaseService.deleteAllRecordings(uid, widget.patient.medicalCardNumber);
      
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);
      
      // Show success message
      _showSnackBar('All recordings deleted successfully');
    } catch (e) {
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);
      
      // Show error message
      _showSnackBar(
        'Error deleting recordings: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _deleteAllECGReadings() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    _showLoadingDialog('Deleting ECG readings...');

    try {
      await _firebaseService.deleteAllECGReadings(uid, widget.patient.medicalCardNumber);
      
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);
      
      // Show success message
      _showSnackBar('All ECG readings deleted successfully');
    } catch (e) {
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);
      
      // Show error message
      _showSnackBar(
        'Error deleting ECG readings: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _deleteAllPulseOxSessions() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show loading indicator
    _showLoadingDialog('Deleting oxygen monitoring data...');

    try {
      await _firebaseService.deleteAllPulseOxSessions(uid, widget.patient.medicalCardNumber);
      
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);
      
      // Show success message
      _showSnackBar('All oxygen monitoring data deleted successfully');
    } catch (e) {
      // Dismiss loading indicator
      if (mounted) Navigator.pop(context);
      
      // Show error message
      _showSnackBar(
        'Error deleting oxygen monitoring data: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: PatientDetailsTheme.primaryColor,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: PatientDetailsTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryData {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  CategoryData({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [PatientDetailsTheme.subtleShadow],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withAlpha(26),
          highlightColor: color.withAlpha(13),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(26),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PatientDetailsTheme.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}