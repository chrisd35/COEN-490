import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_service.dart';
import '../../utils/learning_center_models.dart';
import 'learning_topic_screen.dart';
import 'heart_murmur_library_screen.dart';
import 'quiz_list_screen.dart';
import 'user_progress_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('LearningCenterScreen');

class LearningCenterScreen extends StatefulWidget {
  const LearningCenterScreen({super.key});

  @override
  State<LearningCenterScreen> createState() => _LearningCenterScreenState();
}

class _LearningCenterScreenState extends State<LearningCenterScreen> {
  // Design Constants aligned with dashboard theme
  static final Color primaryColor = const Color(0xFF1D557E);
  static final Color backgroundColor = Colors.white;
  static final Color textPrimaryColor = const Color(0xFF263238);
  static final Color textSecondaryColor = const Color(0xFF546E7A);

  final LearningCenterService _learningService = LearningCenterService();
  late Future<List<LearningTopic>> _topicsFuture;
  late Future<UserProgress> _userProgressFuture;
  
  @override
  void initState() {
    super.initState();
    _refreshData();
  }
  
  Future<void> _refreshData() async {
    _topicsFuture = _learningService.getLearningTopics();
    _userProgressFuture = _learningService.getUserProgress(
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    );
  }

  // Progress Stat Widget
  Widget _buildProgressStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51), // 0.2 * 255 ≈ 51
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Welcome Card Method
  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(50),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to the Learning Center',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<UserProgress>(
              future: _userProgressFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Loading your progress...',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData) {
                  return Text(
                    'Explore educational resources, heart murmur sounds, and test your knowledge.',
                    style: GoogleFonts.inter(color: Colors.white),
                  );
                }
                
                final progress = snapshot.data!;
                final completedTopics = progress.completedTopics.length;
                final quizResults = progress.quizResults.length;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Learning Progress:',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildProgressStat(
                          'Topics',
                          '$completedTopics',
                          Icons.book,
                        ),
                        const SizedBox(width: 16),
                        _buildProgressStat(
                          'Quizzes',
                          '$quizResults',
                          Icons.quiz,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Center(
              
            ),
          ],
        ),
      ),
    );
  }

  // Quick Access Section
  Widget _buildQuickAccessSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 8.0, bottom: 12.0),
            child: Text(
              'Quick Access',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildQuickAccessButton(
                  'Heart Murmurs',
                  Icons.hearing,
                  Colors.redAccent,
                  _navigateToMurmurLibrary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickAccessButton(
                  'Quizzes',
                  Icons.quiz,
                  Colors.blueAccent,
                  _navigateToQuizzes,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick Access Button
  Widget _buildQuickAccessButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: primaryColor.withAlpha(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Section Header Method
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // Topics List Builder
  Widget _buildTopicsList() {
    return FutureBuilder<List<LearningTopic>>(
      future: _topicsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading topics',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _refreshData();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No topics available',
                style: GoogleFonts.inter(),
              ),
            ),
          );
        }
        
        final topics = snapshot.data!;
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return _buildTopicCard(topic);
          },
        );
      },
    );
  }

  // Topic Card
  Widget _buildTopicCard(LearningTopic topic) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(30), width: 0.5),
      ),
      elevation: 3,
      shadowColor: primaryColor.withAlpha(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToTopic(topic),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic icon in a circle
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTopicIcon(topic.title),
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Topic title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic.description,
                         style: GoogleFonts.inter(
                            fontSize: 14,
                            color: textSecondaryColor,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Resources count and button
              Padding(
                padding: const EdgeInsets.only(top: 12.0, left: 56.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Resources count
                    Text(
                      '${topic.resources.length} resource${topic.resources.length != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: textSecondaryColor,
                      ),
                    ),
                    
                    // View button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Icon selection method
  IconData _getTopicIcon(String topicTitle) {
    final title = topicTitle.toLowerCase();
    
    if (title.contains('ecg')) return Icons.monitor_heart;
    if (title.contains('heart') || title.contains('murmur')) return Icons.favorite;
    if (title.contains('pulse') || title.contains('ox')) return Icons.bloodtype;
    if (title.contains('breath') || title.contains('lung')) return Icons.air;
    
    // Default icon
    return Icons.school;
  }

  // Navigation methods
  void _navigateToTopic(LearningTopic topic) {
    _logger.info('Navigating to topic: ${topic.title}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningTopicScreen(topic: topic),
      ),
    );
  }

  void _navigateToMurmurLibrary() {
    _logger.info('Navigating to heart murmur library');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HeartMurmurLibraryScreen(),
      ),
    );
  }

  void _navigateToQuizzes() {
    _logger.info('Navigating to quizzes');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QuizListScreen(),
      ),
    );
  }

  void _navigateToUserProgress() {
    _logger.info('Navigating to user progress');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserProgressScreen(),
      ),
    ).then((_) {
      // Refresh data when returning from progress screen
      setState(() {
        _refreshData();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Learning Center',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: textPrimaryColor,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: textPrimaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.person_outline, color: primaryColor, size: 28),
              tooltip: 'My Progress',
              onPressed: () => _navigateToUserProgress(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          await _refreshData();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // Welcome Card
              _buildWelcomeCard(),
              
              const SizedBox(height: 24),
              
              // Quick Access Buttons
              _buildQuickAccessSection(),
              
              const SizedBox(height: 24),

              // Topics Section
              _buildSectionHeader('Learning Resources', Icons.menu_book),
              const SizedBox(height: 12),
              _buildTopicsList(),

              // Bottom padding
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}