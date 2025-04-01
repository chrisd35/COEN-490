import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'quiz_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('QuizListScreen');

// Design constants to maintain consistency with other screens
class QuizTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Category colors
  static const Color ecgColor = Color(0xFFF44336);      // Red for ECG
  static const Color pulseOxColor = Color(0xFF2196F3);  // Blue for PulseOx 
  static const Color murmurColor = Color(0xFF00ACC1);   // Cyan for Heart Murmurs
  static const Color generalColor = Color(0xFF009688); // Teal for general quizzes
  
  // Difficulty colors
  static const Color easyColor = Color(0xFF4CAF50);     // Green for easy
  static const Color mediumColor = Color(0xFFFF9800);   // Orange for medium
  static const Color hardColor = Color(0xFFE53935);     // Red for hard
  
  // Score colors
  static const Color excellentColor = Color(0xFF43A047); // Dark green
  static const Color goodColor = Color(0xFF1E88E5);      // Medium blue
  static const Color averageColor = Color(0xFFFF9800);   // Orange
  static const Color poorColor = Color(0xFFE53935);      // Red
  
  // Text colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textLight = Color(0xFF78909C);
  
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
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: -0.1,
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
  
  static final TextStyle chipTextStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: primaryColor,
  );
  
  static final TextStyle buttonTextStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius chipRadius = BorderRadius.circular(12);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  
  // Get color for category
  static Color getCategoryColor(String category) {
    switch (category) {
      case 'ECG':
        return ecgColor;
      case 'PulseOx':
        return pulseOxColor;
      case 'Heart Murmurs':
        return murmurColor;
      default:
        return generalColor;
    }
  }
  
  // Get color for difficulty
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return easyColor;
      case 'medium':
        return mediumColor;
      case 'hard':
        return hardColor;
      default:
        return accentColor;
    }
  }
  
  // Get color for score
  static Color getScoreColor(double score) {
    if (score >= 90) return excellentColor;
    if (score >= 70) return goodColor;
    if (score >= 50) return averageColor;
    return poorColor;
  }
}

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<List<Quiz>> _quizzesFuture;
  late Future<UserProgress> _userProgressFuture;
  String _selectedCategory = 'All';
  
  final List<String> _categories = ['All', 'ECG', 'PulseOx', 'Heart Murmurs'];
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _refreshData();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _refreshData() async {
    _quizzesFuture = _learningService.getQuizzes();
    _userProgressFuture = _learningService.getUserProgress(
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: QuizTheme.primaryColor,
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
      backgroundColor: QuizTheme.secondaryColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: QuizTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Assessment Quizzes',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: QuizTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshData();
          setState(() {});
        },
        color: QuizTheme.primaryColor,
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
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by category',
            style: QuizTheme.emphasisStyle,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(_categories[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String category) {
    final isSelected = _selectedCategory == category;
    final Color categoryColor = category == 'All' 
        ? QuizTheme.primaryColor 
        : QuizTheme.getCategoryColor(category);
    
    return FilterChip(
      label: Text(
        category,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? categoryColor : QuizTheme.textSecondary,
        ),
      ),
      selected: isSelected,
      backgroundColor: Colors.white,
      selectedColor: categoryColor.withAlpha(20),
      checkmarkColor: categoryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected 
              ? categoryColor.withAlpha(60) 
              : Colors.grey.withAlpha(40),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = category;
        });
      },
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
          return Center(
            child: CircularProgressIndicator(
              color: QuizTheme.primaryColor,
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
                    color: Colors.red.withAlpha(200),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading quizzes',
                    style: QuizTheme.cardTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.red[700],
                      height: 1.5,
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
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QuizTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: QuizTheme.buttonRadius,
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
              'No quizzes available',
              style: QuizTheme.bodyStyle,
            ),
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
                    Icons.quiz_rounded,
                    size: 64,
                    color: Colors.grey.withAlpha(150),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No quizzes available in the "$_selectedCategory" category',
                    style: QuizTheme.cardTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = 'All';
                      });
                    },
                    icon: const Icon(Icons.filter_list_off_rounded),
                    label: const Text('Show All Categories'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: QuizTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: BorderSide(
                        color: QuizTheme.primaryColor.withAlpha(100),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: QuizTheme.buttonRadius,
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
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          itemCount: quizzesByCategory.length,
          itemBuilder: (context, categoryIndex) {
            final category = quizzesByCategory.keys.toList()[categoryIndex];
            final categoryQuizzes = quizzesByCategory[category]!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header (only show if not filtering by a specific category)
                if (_selectedCategory == 'All') ...[
                  Row(
                    children: [
                      _getCategoryIcon(category),
                      const SizedBox(width: 12),
                      Text(
                        category,
                        style: QuizTheme.subheadingStyle,
                      ),
                    ],
                  ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: 100 * categoryIndex)),
                  const SizedBox(height: 16),
                ],
                
                // Quizzes in this category
                ...categoryQuizzes.asMap().entries.map((entry) {
                  final int quizIndex = entry.key;
                  final Quiz quiz = entry.value;
                  
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
                    categoryIndex,
                    quizIndex,
                  );
                }),
                
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData iconData;
    final Color iconColor = QuizTheme.getCategoryColor(category);
    
    switch (category) {
      case 'ECG':
        iconData = Icons.monitor_heart_rounded;
        break;
      case 'PulseOx':
        iconData = Icons.bloodtype_rounded;
        break;
      case 'Heart Murmurs':
        iconData = Icons.hearing_rounded;
        break;
      default:
        iconData = Icons.quiz_rounded;
    }
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(20),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: 20,
        color: iconColor,
      ),
    );
  }

  Widget _buildQuizCard(
    Quiz quiz,
    bool hasAttempted,
    int attempts,
    double bestScore,
    int categoryIndex,
    int quizIndex,
  ) {
    // Get colors based on quiz properties
    final Color categoryColor = QuizTheme.getCategoryColor(quiz.category);
    final Color difficultyColor = QuizTheme.getDifficultyColor(quiz.difficulty);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: QuizTheme.borderRadius,
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: QuizTheme.borderRadius,
        onTap: () => _navigateToQuiz(quiz),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and difficulty
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withAlpha(40),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: QuizTheme.cardTitleStyle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      quiz.difficulty,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: difficultyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Quiz details and stats
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    quiz.description,
                    style: QuizTheme.bodyStyle.copyWith(
                      color: QuizTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Quiz metrics
                  Row(
                    children: [
                      _buildMetricCard(
                        Icons.quiz_rounded,
                        '${quiz.questions.length}',
                        'Questions',
                        categoryColor,
                      ),
                      const SizedBox(width: 12),
                      if (quiz.timeLimit > 0)
                        _buildMetricCard(
                          Icons.timer_rounded,
                          '${quiz.timeLimit ~/ 60}',
                          'Minutes',
                          QuizTheme.accentColor,
                        ),
                      if (hasAttempted) ...[
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          Icons.emoji_events_rounded,
                          '${bestScore.toInt()}%',
                          'Best Score',
                          QuizTheme.getScoreColor(bestScore),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Attempts info
                      if (hasAttempted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, 
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: QuizTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$attempts ${attempts == 1 ? 'attempt' : 'attempts'}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: QuizTheme.textSecondary,
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
                          hasAttempted ? Icons.replay_rounded : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                        label: Text(hasAttempted ? 'Retry Quiz' : 'Start Quiz'),
                        onPressed: () => _navigateToQuiz(quiz),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: QuizTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: QuizTheme.buttonRadius,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: 400.ms,
      delay: Duration(milliseconds: 100 * categoryIndex + 50 * quizIndex),
    ).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMetricCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: color.withAlpha(200),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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