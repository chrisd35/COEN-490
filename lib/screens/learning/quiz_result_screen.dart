// lib/screens/learning/quiz_result_screen.dart

import 'package:flutter/material.dart';
import '../../utils/learning_center_models.dart';
import 'package:fl_chart/fl_chart.dart';

class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final QuizResult result;
  final List<QuizQuestion> questions;
  final Map<String, int> userAnswers;
  final bool isTimeUp;
  
  const QuizResultScreen({
    Key? key,
    required this.quiz,
    required this.result,
    required this.questions,
    required this.userAnswers,
    this.isTimeUp = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Go back to the quiz list screen
        Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/quiz-list');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quiz Results',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 2,
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildResultHeader(context),
              _buildScoreCard(context),
              _buildStatisticsCard(context),
              _buildFeedbackMessage(context),
              _buildAnswersList(context),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _getScoreColor(result.score).withAlpha(20),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Show time's up message if applicable
          if (isTimeUp)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.timer_off,
                    color: Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Time\'s Up!',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Quiz title
          Text(
            quiz.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Quiz completion status
          Text(
            'Quiz Completed on ${_formatDate(result.timestamp)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Score display
          CircleAvatar(
            radius: 60,
            backgroundColor: _getScoreColor(result.score).withAlpha(50),
            child: Text(
              '${result.score.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _getScoreColor(result.score),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Pass/Fail status
          Text(
            _getResultMessage(result.score),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getScoreColor(result.score),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Score Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                _buildScoreItem(
                  'Correct',
                  result.correctAnswers.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildScoreItem(
                  'Incorrect',
                  (result.totalQuestions - result.correctAnswers).toString(),
                  Icons.cancel,
                  Colors.red,
                ),
                _buildScoreItem(
                  'Total',
                  result.totalQuestions.toString(),
                  Icons.quiz,
                  Colors.blue,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Time taken
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Time taken: ',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  _formatDuration(result.timeTaken),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(BuildContext context) {
    // Calculate statistics
    int correct = result.correctAnswers;
    int incorrect = result.totalQuestions - result.correctAnswers;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    if (correct > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: correct.toDouble(),
                        title: '${(correct / result.totalQuestions * 100).toStringAsFixed(0)}%',
                        radius: 100,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    if (incorrect > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: incorrect.toDouble(),
                        title: '${(incorrect / result.totalQuestions * 100).toStringAsFixed(0)}%',
                        radius: 100,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Correct', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('Incorrect', Colors.red),
              ],
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
      icon = Icons.star;
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 36,
              color: color,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswersList(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Answers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ...List.generate(questions.length, (index) {
              final question = questions[index];
              final userAnswer = userAnswers[question.id];
              final isCorrect = userAnswer == question.correctAnswerIndex;
              
              return _buildAnswerItem(
                questionNumber: index + 1,
                question: question.question,
                isCorrect: isCorrect,
                userAnswer: userAnswer != null
                    ? question.options[userAnswer]
                    : 'Not answered',
                correctAnswer: question.options[question.correctAnswerIndex],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Navigate back to quiz list
              Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/quiz-list');
            },
            icon: const Icon(Icons.list),
            label: const Text('Quiz List'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Pop twice to go back to quiz screen and try again
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.replay),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildAnswerItem({
    required int questionNumber,
    required String question,
    required bool isCorrect,
    required String userAnswer,
    required String correctAnswer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isCorrect ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and status
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    questionNumber.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isCorrect ? 'Correct' : 'Incorrect',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Question text
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // User answer
          Row(
            children: [
              const Text(
                'Your answer: ',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: Text(
                  userAnswer,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          
          // Show correct answer if wrong
          if (!isCorrect) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Correct answer: ',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: Text(
                    correctAnswer,
                    style: const TextStyle(
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
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes min ${seconds} sec';
  }

  String _getResultMessage(double score) {
    if (score >= 90) return 'Excellent!';
    if (score >= 70) return 'Good Job!';
    if (score >= 50) return 'Not Bad';
    return 'Keep Practicing';
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}