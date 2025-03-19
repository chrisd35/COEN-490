import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Learning Center',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'My Progress',
              onPressed: () => _navigateToUserProgress(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshData();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              
              const SizedBox(height: 16),
              
              // Quick Access Buttons
              _buildQuickAccessSection(),
              
              // Topics Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSectionHeader('Learning Resources', Icons.menu_book),
              ),
              const SizedBox(height: 12),
              _buildTopicsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to the Learning Center',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<UserProgress>(
              future: _userProgressFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Loading your progress...',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text(
                    'Explore educational resources, heart murmur sounds, and test your knowledge.',
                    style: TextStyle(color: Colors.white),
                  );
                }
                
                final progress = snapshot.data!;
                final completedTopics = progress.completedTopics.length;
                final quizResults = progress.quizResults.length;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Learning Progress:',
                      style: TextStyle(
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
              child: ElevatedButton.icon(
                onPressed: () => _navigateToUserProgress(),
                icon: const Icon(Icons.analytics, size: 18),
                label: const Text('View My Progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
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

  Widget _buildQuickAccessButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black.withAlpha(26), // 0.1 * 255 ≈ 26
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26), // 0.1 * 255 ≈ 26
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
                style: const TextStyle(
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsList() {
    return FutureBuilder<List<LearningTopic>>(
      future: _topicsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
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
                  const Text(
                    'Error loading topics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No topics available'),
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

  Widget _buildTopicCard(LearningTopic topic) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withAlpha(30), width: 0.5),
      ),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                      color: Theme.of(context).primaryColor.withAlpha(26), // 0.1 * 255 ≈ 26
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTopicIcon(topic.title),
                      color: Theme.of(context).primaryColor,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          topic.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    
                    // View button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Theme.of(context).primaryColor,
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

  IconData _getTopicIcon(String topicTitle) {
    final title = topicTitle.toLowerCase();
    
    if (title.contains('ecg')) return Icons.monitor_heart;
    if (title.contains('heart') || title.contains('murmur')) return Icons.favorite;
    if (title.contains('pulse') || title.contains('ox')) return Icons.bloodtype;
    if (title.contains('breath') || title.contains('lung')) return Icons.air;
    
    // Default icon
    return Icons.school;
  }

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
}