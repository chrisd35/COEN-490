import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';

// Design constants to maintain consistency with other screens
class LearningProgressTheme {
  // Main color palette - aligned with the app theme
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
  
  // Category colors
  static final List<Color> categoryColors = [
    const Color(0xFF1D557E),  // Primary blue
    const Color(0xFF2E86C1),  // Medium blue
    const Color(0xFF3498DB),  // Light blue
    const Color(0xFF0D47A1),  // Deep blue
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
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );
  
  static final TextStyle subheadingStyle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
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
  
  static final TextStyle bodyStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );
  
  static final TextStyle emphasisStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.5,
  );
  
  static final TextStyle captionStyle = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
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
  static final BorderRadius chipRadius = BorderRadius.circular(12);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  
  // Get color for score
  static Color getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF43A047); // Green
    if (score >= 70) return const Color(0xFF1E88E5); // Blue
    if (score >= 50) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFE53935); // Red
  }
  
  // Get color for difficulty
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF43A047); // Green
      case 'medium':
        return const Color(0xFFFF9800); // Orange
      case 'hard':
        return const Color(0xFFE53935); // Red
      default:
        return primaryColor;
    }
  }
}

class UserProgressScreen extends StatefulWidget {
  const UserProgressScreen({super.key});

  @override
  State<UserProgressScreen> createState() => _UserProgressScreenState();
}

class _UserProgressScreenState extends State<UserProgressScreen> with SingleTickerProviderStateMixin {
  final LearningCenterService _learningService = LearningCenterService();
  late String _userId;
  late Future<UserProgress> _userProgressFuture;
  late Future<List<LearningTopic>> _topicsFuture;
  late Future<List<Quiz>> _quizzesFuture;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _userProgressFuture = _learningService.getUserProgress(_userId);
    _topicsFuture = _learningService.getLearningTopics();
    _quizzesFuture = _learningService.getQuizzes();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showResetConfirmationDialog() {
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
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: LearningProgressTheme.warningColor,
                ).animate().shake(duration: 700.ms),
                const SizedBox(height: 16),
                Text(
                  'Reset Progress?',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: LearningProgressTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'This will delete all your learning progress and quiz results. '
                  'This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: LearningProgressTheme.textSecondary,
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
                            borderRadius: LearningProgressTheme.buttonRadius,
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: LearningProgressTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _resetProgress();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LearningProgressTheme.errorColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: LearningProgressTheme.buttonRadius,
                          ),
                        ),
                        child: Text(
                          'RESET',
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

  Future<void> _resetProgress() async {
    try {
      // Show loading indicator
      _showLoadingDialog('Resetting progress...');
      
      await _learningService.resetUserProgress(_userId);
      
      // Close the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Refresh the data
      if (mounted) {
        setState(() {
          _userProgressFuture = _learningService.getUserProgress(_userId);
          _topicsFuture = _learningService.getLearningTopics();
          _quizzesFuture = _learningService.getQuizzes();
        });
      }
      
      // Show success message
      if (mounted) {
        _showSnackBar(
          'Your progress has been reset successfully',
          isSuccess: true,
        );
      }
    } catch (e) {
      // Close the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        _showSnackBar(
          'Error resetting progress: $e',
          isError: true,
        );
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
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
                  color: LearningProgressTheme.primaryColor,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: LearningProgressTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
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
            ? LearningProgressTheme.errorColor
            : isSuccess
                ? LearningProgressTheme.successColor
                : LearningProgressTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearningProgressTheme.secondaryColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LearningProgressTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'My Learning Progress',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: LearningProgressTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: LearningProgressTheme.secondaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: LearningProgressTheme.primaryColor,
              ),
              tooltip: 'Reset Progress',
              onPressed: _showResetConfirmationDialog,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LearningProgressTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          labelColor: LearningProgressTheme.primaryColor,
          unselectedLabelColor: LearningProgressTheme.textSecondary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Quiz Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildQuizResultsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        _userProgressFuture,
        _topicsFuture,
        _quizzesFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: LearningProgressTheme.primaryColor,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: LearningProgressTheme.errorColor.withAlpha(200),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading progress data',
                    style: LearningProgressTheme.subheadingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: LearningProgressTheme.bodyStyle.copyWith(
                      color: LearningProgressTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _userProgressFuture = _learningService.getUserProgress(_userId);
                        _topicsFuture = _learningService.getLearningTopics();
                        _quizzesFuture = _learningService.getQuizzes();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LearningProgressTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: LearningProgressTheme.buttonRadius,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'No progress data available',
              style: LearningProgressTheme.bodyStyle,
            ),
          );
        }
        
        final userProgress = snapshot.data![0] as UserProgress;
        final topics = snapshot.data![1] as List<LearningTopic>;
        final quizzes = snapshot.data![2] as List<Quiz>;
        
        // Calculate completion percentages
        final completedTopics = userProgress.completedTopics.length;
        final totalTopics = topics.length;
        final topicCompletionPercentage = totalTopics > 0
            ? (completedTopics / totalTopics * 100).toStringAsFixed(1)
            : '0';
        
        // Calculate average score
        double averageScore = 0;
        if (userProgress.quizResults.isNotEmpty) {
          final totalScore = userProgress.quizResults.fold<double>(
            0, (sum, result) => sum + result.score);
          averageScore = totalScore / userProgress.quizResults.length;
        }
        
        // Get highest score per quiz
        Map<String, QuizResult> bestQuizResults = {};
        for (var result in userProgress.quizResults) {
          if (!bestQuizResults.containsKey(result.quizId) || 
              bestQuizResults[result.quizId]!.score < result.score) {
            bestQuizResults[result.quizId] = result;
          }
        }
        
        // Get last accessed topics
        final lastAccessedMap = userProgress.lastAccessedTopics;
        final lastAccessedTopics = lastAccessedMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _userProgressFuture = _learningService.getUserProgress(_userId);
              _topicsFuture = _learningService.getLearningTopics();
              _quizzesFuture = _learningService.getQuizzes();
            });
          },
          color: LearningProgressTheme.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressSummaryCard(
                    topicCompletionPercentage,
                    averageScore,
                  ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Topic progress
                  Text(
                    'Topic Progress',
                    style: LearningProgressTheme.subheadingStyle,
                  ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
                  const SizedBox(height: 16),
                  _buildTopicProgressCard(topics, userProgress)
                      .animate().fadeIn(duration: 500.ms, delay: 300.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Recently accessed topics
                  Text(
                    'Recently Accessed Topics',
                    style: LearningProgressTheme.subheadingStyle,
                  ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
                  const SizedBox(height: 16),
                  _buildRecentTopicsCard(lastAccessedTopics, topics)
                      .animate().fadeIn(duration: 500.ms, delay: 500.ms),
                  
                  const SizedBox(height: 24),
                  
                  // Quiz progress
                  Text(
                    'Quiz Progress',
                    style: LearningProgressTheme.subheadingStyle,
                  ).animate().fadeIn(duration: 500.ms, delay: 600.ms),
                  const SizedBox(height: 16),
                  _buildQuizProgressCard(quizzes, bestQuizResults)
                      .animate().fadeIn(duration: 500.ms, delay: 700.ms),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizResultsTab() {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        _userProgressFuture,
        _quizzesFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: LearningProgressTheme.primaryColor,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: LearningProgressTheme.errorColor.withAlpha(200),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading quiz results',
                    style: LearningProgressTheme.subheadingStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: LearningProgressTheme.bodyStyle.copyWith(
                      color: LearningProgressTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _userProgressFuture = _learningService.getUserProgress(_userId);
                        _quizzesFuture = _learningService.getQuizzes();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LearningProgressTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: LearningProgressTheme.buttonRadius,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        final userProgress = snapshot.data![0] as UserProgress;
        final quizzes = snapshot.data![1] as List<Quiz>;
        
        if (userProgress.quizResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_rounded,
                  size: 48,
                  color: Colors.grey.withAlpha(180),
                ),
                const SizedBox(height: 16),
                Text(
                  'You haven\'t taken any quizzes yet',
                  style: LearningProgressTheme.cardTitleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete quizzes to see your results here',
                  style: LearningProgressTheme.captionStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Go to Learning Center'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LearningProgressTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: LearningProgressTheme.buttonRadius,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Sort quiz results by date, newest first
        final results = userProgress.quizResults.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            
            // Find quiz details
            final quiz = quizzes.firstWhere(
              (q) => q.id == result.quizId,
              orElse: () => Quiz(
                id: 'unknown',
                title: 'Unknown Quiz',
                description: '',
                category: 'Unknown',
                difficulty: 'Medium',
                questions: [],
              ),
            );
            
            return _buildQuizResultCard(result, quiz, index)
                .animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100 * index))
                .slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }

  Widget _buildProgressSummaryCard(
    String topicCompletionPercentage,
    double averageScore,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: LearningProgressTheme.borderRadius,
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning Summary',
              style: LearningProgressTheme.cardTitleStyle,
            ),
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                _buildSummaryItem(
                  'Topics Completed',
                  '$topicCompletionPercentage%',
                  LearningProgressTheme.primaryColor,
                  Icons.book_rounded,
                ),
                _buildSummaryItem(
                  'Avg. Quiz Score',
                  '${averageScore.toStringAsFixed(1)}%',
                  LearningProgressTheme.getScoreColor(averageScore),
                  Icons.quiz_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopicProgressCard(
    List<LearningTopic> topics,
    UserProgress userProgress,
  ) {
    final completedTopicIds = userProgress.completedTopics;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: LearningProgressTheme.borderRadius,
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: ${completedTopicIds.length}/${topics.length}',
                  style: LearningProgressTheme.emphasisStyle,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LearningProgressTheme.primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(completedTopicIds.length / (topics.isEmpty ? 1 : topics.length) * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: LearningProgressTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: topics.isEmpty ? 0 : completedTopicIds.length / topics.length,
                backgroundColor: Colors.grey.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  LearningProgressTheme.primaryColor,
                ),
                minHeight: 8,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Topic list
            ...topics.map((topic) {
              final isCompleted = completedTopicIds.contains(topic.id);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? LearningProgressTheme.successColor.withAlpha(20)
                            : Colors.grey.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                        color: isCompleted
                            ? LearningProgressTheme.successColor
                            : Colors.grey,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        topic.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                          color: isCompleted
                              ? LearningProgressTheme.textPrimary
                              : LearningProgressTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTopicsCard(
    List<MapEntry<String, DateTime>> lastAccessedTopics,
    List<LearningTopic> allTopics,
  ) {
    if (lastAccessedTopics.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LearningProgressTheme.borderRadius,
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 40,
                    color: Colors.grey.withAlpha(150),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recently accessed topics',
                    style: LearningProgressTheme.emphasisStyle.copyWith(
                      color: LearningProgressTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Topics you view will appear here',
                    style: LearningProgressTheme.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Take only the 5 most recent
    final recentTopics = lastAccessedTopics.take(5).toList();
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: LearningProgressTheme.borderRadius,
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recentTopics.map((entry) {
            final topicId = entry.key;
            final accessDate = entry.value;
            
            // Find topic details
            final topic = allTopics.firstWhere(
              (t) => t.id == topicId,
              orElse: () => LearningTopic(
                id: topicId,
                title: 'Unknown Topic',
                description: '',
              ),
            );
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: LearningProgressTheme.primaryColor.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: LearningProgressTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title,
                          style: LearningProgressTheme.emphasisStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last accessed: ${_formatDate(accessDate)}',
                          style: LearningProgressTheme.captionStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQuizProgressCard(
    List<Quiz> quizzes,
    Map<String, QuizResult> bestQuizResults,
  ) {
    if (bestQuizResults.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LearningProgressTheme.borderRadius,
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.quiz_rounded,
                    size: 40,
                    color: Colors.grey.withAlpha(150),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No quizzes completed yet',
                    style: LearningProgressTheme.emphasisStyle.copyWith(
                      color: LearningProgressTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete quizzes to see your progress',
                    style: LearningProgressTheme.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // Count completed quizzes
    final completedQuizzes = bestQuizResults.length;
    final totalQuizzes = quizzes.length;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: LearningProgressTheme.borderRadius,
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: $completedQuizzes/$totalQuizzes',
                  style: LearningProgressTheme.emphasisStyle,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LearningProgressTheme.primaryColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(completedQuizzes / (totalQuizzes == 0 ? 1 : totalQuizzes) * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: LearningProgressTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalQuizzes > 0 ? completedQuizzes / totalQuizzes : 0,
                backgroundColor: Colors.grey.withAlpha(30),
                valueColor: AlwaysStoppedAnimation<Color>(
                  LearningProgressTheme.primaryColor,
                ),
                minHeight: 8,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quiz list with highest scores
            ...quizzes.map((quiz) {
              final hasResult = bestQuizResults.containsKey(quiz.id);
              final bestScore = hasResult ? bestQuizResults[quiz.id]!.score : 0.0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: hasResult
                            ? LearningProgressTheme.successColor.withAlpha(20)
                            : Colors.grey.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasResult ? Icons.check_rounded : Icons.circle_outlined,
                        color: hasResult
                            ? LearningProgressTheme.successColor
                            : Colors.grey,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        quiz.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: hasResult ? FontWeight.w500 : FontWeight.normal,
                          color: hasResult
                              ? LearningProgressTheme.textPrimary
                              : LearningProgressTheme.textSecondary,
                        ),
                      ),
                    ),
                    if (hasResult)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: LearningProgressTheme.getScoreColor(bestScore).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${bestScore.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LearningProgressTheme.getScoreColor(bestScore),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizResultCard(QuizResult result, Quiz quiz, int index) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quiz title and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    quiz.title,
                    style: LearningProgressTheme.cardTitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(result.timestamp),
                  style: LearningProgressTheme.captionStyle,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Quiz category and difficulty
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LearningProgressTheme.primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quiz.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: LearningProgressTheme.primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LearningProgressTheme.getDifficultyColor(quiz.difficulty).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quiz.difficulty,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: LearningProgressTheme.getDifficultyColor(quiz.difficulty),
                    ),
                  ),
                ),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1),
            ),
            
            // Score details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score',
                        style: LearningProgressTheme.captionStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.score.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: LearningProgressTheme.getScoreColor(result.score),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.withAlpha(50),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Correct Answers',
                        style: LearningProgressTheme.captionStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.correctAnswers}/${result.totalQuestions}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: LearningProgressTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: LearningProgressTheme.textSecondary,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}