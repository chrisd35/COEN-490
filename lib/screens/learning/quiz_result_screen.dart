import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/app_routes.dart';


// Using the same theme class from the Quiz screens
class QuizResultTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Result colors
  static const Color excellentColor = Color(0xFF4CAF50); // Green for excellent
  static const Color goodColor = Color(0xFF2196F3);      // Blue for good
  static const Color averageColor = Color(0xFFFF9800);   // Orange for average
  static const Color poorColor = Color(0xFFE53935);      // Red for poor
  
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
  
  static final TextStyle buttonTextStyle = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );
  
  // Border radius
  static final BorderRadius borderRadius = BorderRadius.circular(16);
  static final BorderRadius chipRadius = BorderRadius.circular(12);
  static final BorderRadius buttonRadius = BorderRadius.circular(12);
  
  // Get color for score
  static Color getScoreColor(double score) {
    if (score >= 90) return excellentColor;
    if (score >= 70) return goodColor;
    if (score >= 50) return averageColor;
    return poorColor;
  }
  
  // Get color for difficulty
  static Color getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return excellentColor;
      case 'medium':
        return averageColor;
      case 'hard':
        return poorColor;
      default:
        return accentColor;
    }
  }
}

class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final QuizResult result;
  final List<QuizQuestion> questions;
  final Map<String, int> userAnswers;
  final bool isTimeUp;
  
  const QuizResultScreen({
    super.key,
    required this.quiz,
    required this.result,
    required this.questions,
    required this.userAnswers,
    this.isTimeUp = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic _) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: QuizResultTheme.secondaryColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: QuizResultTheme.textPrimary,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Quiz Results',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: QuizResultTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.home_rounded),
                tooltip: 'Return to Learning Center',
                onPressed: () {
                  Navigator.of(context).popUntil(
                    (route) => route.settings.name == AppRoutes.learningCenter
                  );
                },
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildResultHeader(context).animate().fadeIn(duration: 800.ms),
              _buildScoreCards(context).animate().fadeIn(duration: 800.ms, delay: 200.ms),
              _buildFeedbackMessage(context).animate().fadeIn(duration: 800.ms, delay: 400.ms),
              _buildStatisticsSection(context).animate().fadeIn(duration: 800.ms, delay: 600.ms),
              _buildAnswersList(context),
              _buildActionButtons(context).animate().fadeIn(duration: 800.ms, delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    final scoreColor = QuizResultTheme.getScoreColor(result.score);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 32, bottom: 40, left: 24, right: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withAlpha(160),
            scoreColor.withAlpha(100),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Show time's up message if applicable
          if (isTimeUp)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(60),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(100),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Time\'s Up!',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          
          // Score display with circle
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(40),
                  border: Border.all(
                    color: Colors.white.withAlpha(180),
                    width: 2,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${result.score.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getResultMessage(result.score),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Quiz title and completion info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  quiz.title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed on ${_formatDate(result.timestamp)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildScoreCards(BuildContext context) {
    // Calculate statistics
    int correct = result.correctAnswers;
    int incorrect = result.totalQuestions - result.correctAnswers;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          _buildMetricCard(
            'Correct',
            correct.toString(),
            Icons.check_circle_outline_rounded,
            QuizResultTheme.excellentColor,
          ),
          const SizedBox(width: 12),
          _buildMetricCard(
            'Incorrect',
            incorrect.toString(),
            Icons.close,  // Alternative 1
            QuizResultTheme.poorColor,
          ),
          const SizedBox(width: 12),
          _buildMetricCard(
            'Total',
            result.totalQuestions.toString(),
            Icons.quiz_rounded,
            QuizResultTheme.accentColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: QuizResultTheme.borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 6, 
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: QuizResultTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackMessage(BuildContext context) {
    String message;
    IconData icon;
    Color color;
    
    if (result.score >= 90) {
      message = 'Excellent! You have a strong understanding of this topic.';
      icon = Icons.emoji_events_rounded;
      color = QuizResultTheme.excellentColor;
    } else if (result.score >= 70) {
      message = 'Good job! You have a good grasp of the material.';
      icon = Icons.thumb_up_rounded;
      color = QuizResultTheme.goodColor;
    } else if (result.score >= 50) {
      message = 'You\'re making progress. Review the material to improve your score.';
      icon = Icons.trending_up_rounded;
      color = QuizResultTheme.averageColor;
    } else {
      message = 'Keep practicing. Review the learning materials and try again.';
      icon = Icons.refresh_rounded;
      color = QuizResultTheme.poorColor;
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: QuizResultTheme.borderRadius,
        ),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback',
                      style: QuizResultTheme.cardTitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: QuizResultTheme.bodyStyle.copyWith(
                        color: QuizResultTheme.textSecondary,
                      ),
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

  Widget _buildStatisticsSection(BuildContext context) {
    // Calculate statistics
    int correct = result.correctAnswers;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Performance Statistics'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: QuizResultTheme.borderRadius,
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Time taken
                  _buildInfoRow(
                    title: 'Time Taken:',
                    value: _formatDuration(result.timeTaken),
                    icon: Icons.access_time_rounded,
                    iconColor: QuizResultTheme.accentColor,
                  ),
                  const SizedBox(height: 12),
                  
                  // Difficulty 
                  _buildInfoRow(
                    title: 'Difficulty:',
                    value: quiz.difficulty,
                    icon: Icons.speed_rounded,
                    iconColor: QuizResultTheme.getDifficultyColor(quiz.difficulty),
                  ),
                  const SizedBox(height: 12),
                  
                  // Category
                  _buildInfoRow(
                    title: 'Category:',
                    value: quiz.category,
                    icon: Icons.category_rounded,
                    iconColor: QuizResultTheme.accentColor,
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  
                  // Summary text
                  Text(
                    'You answered $correct out of ${result.totalQuestions} questions correctly.',
                    style: QuizResultTheme.emphasisStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: QuizResultTheme.emphasisStyle,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: QuizResultTheme.bodyStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: QuizResultTheme.subheadingStyle,
      ),
    );
  }

  Widget _buildAnswersList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Question Summary'),
          const SizedBox(height: 12),
          ...List.generate(questions.length, (index) {
            final question = questions[index];
            final userAnswer = userAnswers[question.id];
            final isCorrect = userAnswer == question.correctAnswerIndex;
            final isSkipped = userAnswer == null;
            
            return _buildAnswerItem(
              questionNumber: index + 1,
              question: question.question,
              isCorrect: isCorrect,
              isSkipped: isSkipped,
              userAnswer: isSkipped
                  ? 'Not answered'
                  : question.options[userAnswer],
              correctAnswer: question.options[question.correctAnswerIndex],
              index: index,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnswerItem({
    required int questionNumber,
    required String question,
    required bool isCorrect,
    required bool isSkipped,
    required String userAnswer,
    required String correctAnswer,
    required int index,
  }) {
    final Color statusColor = isSkipped
        ? QuizResultTheme.averageColor
        : isCorrect
            ? QuizResultTheme.excellentColor
            : QuizResultTheme.poorColor;
    
    final String statusText = isSkipped
        ? 'Skipped'
        : isCorrect
            ? 'Correct'
            : 'Incorrect';
    
    final IconData statusIcon = isSkipped
        ? Icons.help_outline_rounded
        : isCorrect
            ? Icons.check_circle_outline_rounded
            : Icons.cancel_outlined;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: QuizResultTheme.borderRadius,
      ),
      color: statusColor.withAlpha(10),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question number and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      questionNumber.toString(),
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Status and question
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        question,
                        style: QuizResultTheme.emphasisStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            
            // User answer
            if (!isSkipped) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your answer: ',
                    style: GoogleFonts.inter(
                      color: QuizResultTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      userAnswer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isCorrect ? QuizResultTheme.excellentColor : QuizResultTheme.poorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'You did not answer this question',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: QuizResultTheme.averageColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Show correct answer if wrong or skipped
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Correct answer: ',
                    style: GoogleFonts.inter(
                      color: QuizResultTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      correctAnswer,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: QuizResultTheme.excellentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100 * index + 800));
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.quizList, 
                  (route) => route.settings.name == AppRoutes.learningCenter || route.isFirst
                );
              },
              icon: const Icon(Icons.list_rounded),
              label: const Text('Quiz List'),
              style: OutlinedButton.styleFrom(
                foregroundColor: QuizResultTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: QuizResultTheme.buttonRadius,
                ),
                side: BorderSide(
                  color: QuizResultTheme.primaryColor.withAlpha(100),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.quiz,
                  arguments: {'quiz': quiz}
                );
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuizResultTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: QuizResultTheme.buttonRadius,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes min $seconds sec';
  }

  String _getResultMessage(double score) {
    if (score >= 90) return 'Excellent!';
    if (score >= 80) return 'Great Job!';
    if (score >= 70) return 'Good Work!';
    if (score >= 60) return 'Not Bad';
    if (score >= 50) return 'Keep Learning';
    return 'Try Again';
  }
}