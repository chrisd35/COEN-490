import 'package:flutter/material.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/app_routes.dart';

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
    // Using PopScope with onPopInvokedWithResult instead of deprecated onPopInvoked
    canPop: false,
    onPopInvokedWithResult: (didPop, dynamic _) {
      // If didPop is true, the pop already happened and we shouldn't navigate
      if (!didPop) {
        // Go back to the quiz screen (single pop)
        Navigator.of(context).pop();
      }
      // Return false to prevent the default pop behavior
    },
    child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Quiz Results',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Return to Learning Center',
              onPressed: () {
                // Navigate to the learning center screen
                Navigator.of(context).popUntil(
                  (route) => route.settings.name == AppRoutes.learningCenter
                );
              },
            ),
          ),
        ],
      ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildResultHeader(context),
              _buildScoreCards(context),
              _buildFeedbackMessage(context),
              _buildStatisticsSection(context),
              _buildAnswersList(context),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    final scoreColor = _getScoreColor(result.score);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 32, left: 24, right: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scoreColor.withAlpha(179), // 0.7 * 255 ≈ 179
            scoreColor.withAlpha(128), // 0.5 * 255 ≈ 128
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
            color: scoreColor.withAlpha(77), // 0.3 * 255 ≈ 77
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
                color: Colors.white.withAlpha(77), // 0.3 * 255 ≈ 77
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(128), // 0.5 * 255 ≈ 128
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.timer_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Time\'s Up!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                  color: Colors.white.withAlpha(51), // 0.2 * 255 ≈ 51
                  border: Border.all(
                    color: Colors.white.withAlpha(204), // 0.8 * 255 ≈ 204
                    width: 2,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${result.score.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getResultMessage(result.score),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quiz title and completion info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51), // 0.2 * 255 ≈ 51
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  quiz.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed on ${_formatDate(result.timestamp)}',
                  style: const TextStyle(
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildMetricCard(
            'Correct',
            correct.toString(),
            Icons.check_circle_outline,
            Colors.green,
            context,
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            'Incorrect',
            incorrect.toString(),
            Icons.cancel_outlined,
            Colors.red,
            context,
          ),
          const SizedBox(width: 8),
          _buildMetricCard(
            'Total',
            result.totalQuestions.toString(),
            Icons.quiz_outlined,
            Colors.blue,
            context,
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
    BuildContext context,
  ) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.withAlpha(26), // 0.1 * 255 ≈ 26
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
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
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (result.score >= 70) {
      message = 'Good job! You have a good grasp of the material.';
      icon = Icons.thumb_up;
      color = Colors.blue;
    } else if (result.score >= 50) {
      message = 'You\'re making progress. Review the material to improve your score.';
      icon = Icons.trending_up;
      color = Colors.orange;
    } else {
      message = 'Keep practicing. Review the learning materials and try again.';
      icon = Icons.refresh;
      color = Colors.red;
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(26), // 0.1 * 255 ≈ 26
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.3,
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

  Widget _buildStatisticsSection(BuildContext context) {
    // Calculate statistics
    int correct = result.correctAnswers;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Performance Statistics'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.grey.withAlpha(26), // 0.1 * 255 ≈ 26
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Time taken
                  _buildInfoRow(
                    title: 'Time Taken:',
                    value: _formatDuration(result.timeTaken),
                    icon: Icons.access_time,
                    iconColor: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  
                  // Difficulty 
                  _buildInfoRow(
                    title: 'Difficulty:',
                    value: quiz.difficulty,
                    icon: Icons.speed,
                    iconColor: _getDifficultyColor(quiz.difficulty),
                  ),
                  const SizedBox(height: 8),
                  
                  // Category
                  _buildInfoRow(
                    title: 'Category:',
                    value: quiz.category,
                    icon: Icons.category,
                    iconColor: Colors.purple,
                  ),
                  
                  // Summary text instead of chart
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'You answered $correct out of ${result.totalQuestions} questions correctly.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
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
        Icon(
          icon,
          size: 18,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswersList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Question Summary'),
          const SizedBox(height: 8),
          ...List.generate(questions.length, (index) {
            final question = questions[index];
            final userAnswer = userAnswers[question.id];
            final isCorrect = userAnswer == question.correctAnswerIndex;
            final isSkipped = userAnswer == null;
            
            return _buildAnswerItem(
              context: context,
              questionNumber: index + 1,
              question: question.question,
              isCorrect: isCorrect,
              isSkipped: isSkipped,
              userAnswer: isSkipped
                  ? 'Not answered'
                  : question.options[userAnswer],
              correctAnswer: question.options[question.correctAnswerIndex],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAnswerItem({
    required BuildContext context,
    required int questionNumber,
    required String question,
    required bool isCorrect,
    required bool isSkipped,
    required String userAnswer,
    required String correctAnswer,
  }) {
    final Color statusColor = isSkipped
        ? Colors.amber
        : isCorrect
            ? Colors.green
            : Colors.red;
    
    final String statusText = isSkipped
        ? 'Skipped'
        : isCorrect
            ? 'Correct'
            : 'Incorrect';
    
    final IconData statusIcon = isSkipped
        ? Icons.help_outline
        : isCorrect
            ? Icons.check_circle_outline
            : Icons.cancel_outlined;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withAlpha(128), // 0.5 * 255 ≈ 128
          width: 1,
        ),
      ),
      color: statusColor.withAlpha(13), // 0.05 * 255 ≈ 13
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: statusColor.withAlpha(26), // 0.1 * 255 ≈ 26
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      questionNumber.toString(),
                      style: TextStyle(
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
                            style: TextStyle(
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(
                color: statusColor.withAlpha(51), // 0.2 * 255 ≈ 51
                height: 1,
              ),
            ),
            
            // User answer
            if (!isSkipped) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your answer: ',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      userAnswer,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'You did not answer this question',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.amber,
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
                  const Text(
                    'Correct answer: ',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      correctAnswer,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // Navigate directly to the quiz list screen
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.quizList, 
                (route) => route.settings.name == AppRoutes.learningCenter || route.isFirst
              );
            },
            icon: const Icon(Icons.list),
            label: const Text('Quiz List'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Pop back to the quiz screen
              Navigator.of(context).pop();
              
              // Send the same quiz data to restart it
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.quiz,
                arguments: {'quiz': quiz}
              );
            },
            icon: const Icon(Icons.replay),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              elevation: 0,
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
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