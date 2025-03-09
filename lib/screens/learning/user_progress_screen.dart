// lib/screens/learning/user_progress_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'package:fl_chart/fl_chart.dart';

class UserProgressScreen extends StatefulWidget {
  const UserProgressScreen({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Learning Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
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
            
        final quizzesTaken = userProgress.quizResults.length;
        final totalQuizzes = quizzes.length;
        final quizCompletionPercentage = totalQuizzes > 0
            ? (quizzesTaken / totalQuizzes * 100).toStringAsFixed(1)
            : '0';
        
        // Calculate average score
        double averageScore = 0;
        if (userProgress.quizResults.isNotEmpty) {
          final totalScore = userProgress.quizResults.fold<double>(
            0, (sum, result) => sum + result.score);
          averageScore = totalScore / userProgress.quizResults.length;
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
                    quizCompletionPercentage,
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
                  
                  // Quiz performance by category
                  const Text(
                    'Quiz Performance by Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuizPerformanceCard(userProgress, quizzes),
                  
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
    String quizCompletionPercentage,
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
                  'Topics',
                  '$topicCompletionPercentage%',
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Quizzes',
                  '$quizCompletionPercentage%',
                  Colors.orange,
                ),
                _buildSummaryItem(
                  'Avg. Score',
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
            }).toList(),
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

  Widget _buildQuizPerformanceCard(
    UserProgress userProgress,
    List<Quiz> quizzes,
  ) {
    if (userProgress.quizResults.isEmpty) {
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
                  Icons.bar_chart,
                  size: 32,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text(
                  'No quiz data available yet',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Complete quizzes to see your performance',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Group results by category
    Map<String, List<QuizResult>> resultsByCategory = {};
    
    for (var result in userProgress.quizResults) {
      // Find quiz to get its category
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
      
      final category = quiz.category;
      
      if (!resultsByCategory.containsKey(category)) {
        resultsByCategory[category] = [];
      }
      
      resultsByCategory[category]!.add(result);
    }
    
    // Calculate average score by category
    Map<String, double> avgScoreByCategory = {};
    resultsByCategory.forEach((category, results) {
      double totalScore = results.fold(0.0, (sum, result) => sum + result.score);
      avgScoreByCategory[category] = totalScore / results.length;
    });
    
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
            // Bar chart
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  // Disable touch handling for simplicity and compatibility
                  barTouchData: BarTouchData(
                    enabled: false,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    // Simplify titles for better compatibility across versions
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < avgScoreByCategory.length) {
                            String category = avgScoreByCategory.keys.elementAt(value.toInt());
                            String abbr = category.substring(0, min(3, category.length));
                            return Text(
                              abbr,
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    avgScoreByCategory.length,
                    (index) {
                      final category = avgScoreByCategory.keys.elementAt(index);
                      final score = avgScoreByCategory[category]!;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: score,
                            color: _getScoreColor(score),
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Legend
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: avgScoreByCategory.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getScoreColor(entry.value),
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${entry.key}: ${entry.value.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
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
            
            // Score and details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                OutlinedButton(
                  onPressed: () {
                    // For a real implementation, you would navigate to a detailed view
                    // Here we'll just show a simple alert
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quiz result details not available in this demo'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('View Details'),
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

  int min(int a, int b) {
    return a < b ? a : b;
  }
}