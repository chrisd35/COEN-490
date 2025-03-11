// lib/screens/learning/user_progress_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';

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
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Reset Progress'),
            ],
          ),
          content: const Text(
            'This will delete all your learning progress and quiz results. '
            'This action cannot be undone. Are you sure you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _resetProgress();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetProgress() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your progress has been reset successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting progress: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Learning Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Progress',
            onPressed: _showResetConfirmationDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
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
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading progress: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _userProgressFuture = _learningService.getUserProgress(_userId);
                      _topicsFuture = _learningService.getLearningTopics();
                      _quizzesFuture = _learningService.getQuizzes();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(
            child: Text('No progress data available'),
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressSummaryCard(
                    topicCompletionPercentage,
                    averageScore,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Topic progress
                  const Text(
                    'Topic Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTopicProgressCard(topics, userProgress),
                  
                  const SizedBox(height: 24),
                  
                  // Recently accessed topics
                  const Text(
                    'Recently Accessed Topics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRecentTopicsCard(lastAccessedTopics, topics),
                  
                  const SizedBox(height: 24),
                  
                  // Quiz progress
                  const Text(
                    'Quiz Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuizProgressCard(quizzes, bestQuizResults),
                  
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
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading quiz results: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _userProgressFuture = _learningService.getUserProgress(_userId);
                      _quizzesFuture = _learningService.getQuizzes();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
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
                const Icon(
                  Icons.quiz,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You haven\'t taken any quizzes yet',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete quizzes to see your results here',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Go to Learning Center'),
                ),
              ],
            ),
          );
        }
        
        // Sort quiz results by date, newest first
        final results = userProgress.quizResults.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
            
            return _buildQuizResultCard(result, quiz);
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learning Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                _buildSummaryItem(
                  'Topics Completed',
                  '$topicCompletionPercentage%',
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Avg. Quiz Score',
                  '${averageScore.toStringAsFixed(1)}%',
                  _getScoreColor(averageScore),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: ${completedTopicIds.length}/${topics.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(completedTopicIds.length / topics.length * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Progress bar
            LinearProgressIndicator(
              value: topics.isEmpty ? 0 : completedTopicIds.length / topics.length,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Topic list
            ...topics.map((topic) {
              final isCompleted = completedTopicIds.contains(topic.id);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isCompleted ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        topic.title,
                        style: TextStyle(
                          fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
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
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: const [
                Icon(
                  Icons.history,
                  size: 32,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'No recently accessed topics',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Take only the 5 most recent
    final recentTopics = lastAccessedTopics.take(5).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.menu_book,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Last accessed: ${_formatDate(accessDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: const [
                Icon(
                  Icons.quiz,
                  size: 32,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'No quizzes completed yet',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Complete quizzes to see your progress',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Count completed quizzes
    final completedQuizzes = bestQuizResults.length;
    final totalQuizzes = quizzes.length;
    
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: $completedQuizzes/$totalQuizzes',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(completedQuizzes / totalQuizzes * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Progress bar
            LinearProgressIndicator(
              value: totalQuizzes > 0 ? completedQuizzes / totalQuizzes : 0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quiz list with highest scores
            ...quizzes.map((quiz) {
              final hasResult = bestQuizResults.containsKey(quiz.id);
              final bestScore = hasResult ? bestQuizResults[quiz.id]!.score : 0.0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      hasResult ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: hasResult ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        quiz.title,
                        style: TextStyle(
                          fontWeight: hasResult ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (hasResult)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getScoreColor(bestScore).withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${bestScore.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getScoreColor(bestScore),
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

  Widget _buildQuizResultCard(QuizResult result, Quiz quiz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quiz title and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    quiz.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  _formatDate(result.timestamp),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            
            // Quiz category and difficulty
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quiz.category,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(quiz.difficulty).withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quiz.difficulty,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getDifficultyColor(quiz.difficulty),
                    ),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Score details - removed the "View Details" button
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: ${result.score.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(result.score),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Correct: ${result.correctAnswers}/${result.totalQuestions}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}