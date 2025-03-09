

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'quiz_screen.dart';

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
  
  @override
  void initState() {
    super.initState();
    _quizzesFuture = _learningService.getQuizzes();
    _userProgressFuture = _learningService.getUserProgress(
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quizzes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(
            child: _buildQuizList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by category:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('ECG'),
                _buildFilterChip('PulseOx'),
                _buildFilterChip('Heart Murmurs'),
              ],
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
        label: Text(category),
        selected: isSelected,
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withAlpha(40),
        checkmarkColor: Theme.of(context).primaryColor,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading quizzes: ${snapshot.error}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _quizzesFuture = _learningService.getQuizzes();
                      _userProgressFuture = _learningService.getUserProgress(
                        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
                      );
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
            child: Text('No quizzes available'),
          );
        }
        
        final quizzes = snapshot.data![0] as List<Quiz>;
        final userProgress = snapshot.data![1] as UserProgress;
        
        // Filter quizzes by category
        var filteredQuizzes = quizzes;
        if (_selectedCategory != 'All') {
          filteredQuizzes = quizzes.where((quiz) {
            return quiz.category == _selectedCategory;
          }).toList();
        }
        
        if (filteredQuizzes.isEmpty) {
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
                Text(
                  'No quizzes available in the $_selectedCategory category',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'All';
                    });
                  },
                  child: const Text('Show All Categories'),
                ),
              ],
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                
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
              ],
            );
          },
        );
      },
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
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quiz.difficulty,
                      style: TextStyle(
                        color: difficultyColor,
                        fontWeight: FontWeight.w500,
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
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Quiz details
              Row(
                children: [
                  _buildQuizDetailItem(
                    Icons.quiz,
                    'Questions',
                    quiz.questions.length.toString(),
                  ),
                  const SizedBox(width: 16),
                  if (quiz.timeLimit > 0)
                    _buildQuizDetailItem(
                      Icons.timer,
                      'Time Limit',
                      '${quiz.timeLimit ~/ 60} mins',
                    ),
                ],
              ),
              
              // Progress section if attempted
              if (hasAttempted) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Attempts: $attempts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Best Score: ${bestScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _getScoreColor(bestScore),
                      ),
                    ),
                  ],
                ),
              ],
              
              const Divider(height: 24),
              
              // Start button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(hasAttempted ? Icons.replay : Icons.play_arrow),
                    label: Text(hasAttempted ? 'Retry Quiz' : 'Start Quiz'),
                    onPressed: () => _navigateToQuiz(quiz),
                    style: ElevatedButton.styleFrom(
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

  Widget _buildQuizDetailItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  void _navigateToQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(quiz: quiz),
      ),
    );
  }
  }