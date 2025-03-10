import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'quiz_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('QuizListScreen');

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({Key? key}) : super(key: key);

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<List<Quiz>> _quizzesFuture;
  late Future<UserProgress> _userProgressFuture;
  String _selectedCategory = 'All';
  
  final List<String> _categories = ['All', 'ECG', 'PulseOx', 'Heart Murmurs'];
  
  @override
  void initState() {
    super.initState();
    _refreshData();
  }
  
  Future<void> _refreshData() async {
    _quizzesFuture = _learningService.getQuizzes();
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
          'Assessment Quizzes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshData();
          setState(() {});
        },
        child: Column(
          children: [
            _buildCategoryFilter(),
            Expanded(
              child: _buildQuizList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Filter by category',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map(_buildFilterChip).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String category) {
    final isSelected = _selectedCategory == category;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          category,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        selected: isSelected,
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withAlpha(40),
        checkmarkColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected 
                ? Theme.of(context).primaryColor.withAlpha(60) 
                : Colors.grey.withAlpha(30),
            width: 1,
          ),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
      ),
    );
  }

  Widget _buildQuizList() {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        _quizzesFuture,
        _userProgressFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
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
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading quizzes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(
            child: Text('No quizzes available'),
          );
        }
        
        final quizzes = snapshot.data![0] as List<Quiz>;
        final userProgress = snapshot.data![1] as UserProgress;
        
        // Filter quizzes by category
        var filteredQuizzes = quizzes;
        if (_selectedCategory != 'All') {
          filteredQuizzes = quizzes.where((quiz) => 
            quiz.category == _selectedCategory
          ).toList();
        }
        
        if (filteredQuizzes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No quizzes available in the "$_selectedCategory" category',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                      });
                    },
                    icon: const Icon(Icons.filter_list_off),
                    label: const Text('Show All Categories'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Group quizzes by category
        Map<String, List<Quiz>> quizzesByCategory = {};
        for (var quiz in filteredQuizzes) {
          if (!quizzesByCategory.containsKey(quiz.category)) {
            quizzesByCategory[quiz.category] = [];
          }
          quizzesByCategory[quiz.category]!.add(quiz);
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quizzesByCategory.length,
          itemBuilder: (context, categoryIndex) {
            final category = quizzesByCategory.keys.toList()[categoryIndex];
            final categoryQuizzes = quizzesByCategory[category]!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                if (_selectedCategory == 'All') ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0, top: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        _getCategoryIcon(category),
                        const SizedBox(width: 8),
                        Text(
                          category,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Quizzes in this category
                ...categoryQuizzes.map((quiz) {
                  // Check if user has taken this quiz
                  final quizResults = userProgress.quizResults
                      .where((result) => result.quizId == quiz.id)
                      .toList();
                  
                  final bool hasAttempted = quizResults.isNotEmpty;
                  final int attempts = quizResults.length;
                  
                  // Get best score
                  double bestScore = 0;
                  if (hasAttempted) {
                    bestScore = quizResults
                        .map((result) => result.score)
                        .reduce((a, b) => a > b ? a : b);
                  }
                  
                  return _buildQuizCard(
                    quiz,
                    hasAttempted,
                    attempts,
                    bestScore,
                  );
                }).toList(),
                
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData iconData;
    Color iconColor;
    
    switch (category) {
      case 'ECG':
        iconData = Icons.monitor_heart;
        iconColor = Colors.redAccent;
        break;
      case 'PulseOx':
        iconData = Icons.bloodtype;
        iconColor = Colors.blueAccent;
        break;
      case 'Heart Murmurs':
        iconData = Icons.hearing;
        iconColor = Colors.purpleAccent;
        break;
      default:
        iconData = Icons.quiz;
        iconColor = Colors.teal;
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 18,
        color: iconColor,
      ),
    );
  }

  Widget _buildQuizCard(
    Quiz quiz,
    bool hasAttempted,
    int attempts,
    double bestScore,
  ) {
    // Color based on difficulty
    Color difficultyColor;
    switch (quiz.difficulty.toLowerCase()) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'medium':
        difficultyColor = Colors.orange;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.blue;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withAlpha(30), width: 0.5),
      ),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToQuiz(quiz),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz title and difficulty badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quiz.difficulty,
                      style: TextStyle(
                        color: difficultyColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Description
              Text(
                quiz.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Quiz metrics cards
              Row(
                children: [
                  _buildMetricCard(
                    Icons.quiz_outlined,
                    '${quiz.questions.length}',
                    'Questions',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  if (quiz.timeLimit > 0)
                    _buildMetricCard(
                      Icons.timer_outlined,
                      '${quiz.timeLimit ~/ 60}',
                      'Minutes',
                      Colors.amber,
                    ),
                  if (hasAttempted) ...[
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      Icons.emoji_events_outlined,
                      '${bestScore.toInt()}%',
                      'Best Score',
                      _getScoreColor(bestScore),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Attempts badge
                  if (hasAttempted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, 
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 14,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$attempts ${attempts == 1 ? 'attempt' : 'attempts'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                    
                  // Start button
                  ElevatedButton.icon(
                    icon: Icon(
                      hasAttempted ? Icons.replay : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(hasAttempted ? 'Retry Quiz' : 'Start Quiz'),
                    onPressed: () => _navigateToQuiz(quiz),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.9),
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  void _navigateToQuiz(Quiz quiz) {
    _logger.info('Navigating to quiz: ${quiz.title}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(quiz: quiz),
      ),
    ).then((_) {
      // Refresh data when returning from quiz
      setState(() {
        _refreshData();
      });
    });
  }
}