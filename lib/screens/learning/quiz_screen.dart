

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  
  const QuizScreen({
    Key? key,
    required this.quiz,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late String _userId;
  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  Map<String, int> _userAnswers = {};
  bool _isAnswered = false;
  bool _isQuizCompleted = false;
  int? _selectedAnswerIndex;
  
  // Timer related
  late Timer? _timer;
  late int _remainingSeconds;
  bool _isTimeLimitReached = false;
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _questions = List.from(widget.quiz.questions);
    _shuffleQuestions();
    
    // Set up timer if time limit exists
    if (widget.quiz.timeLimit > 0) {
      _remainingSeconds = widget.quiz.timeLimit;
      _startTimer();
    } else {
      _remainingSeconds = 0;
      _timer = null;
    }
  }

  void _shuffleQuestions() {
    // Shuffle questions
    _questions.shuffle(Random());
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _finishQuiz();
          _timer?.cancel();
          _isTimeLimitReached = true;
        }
      });
    });
  }

  void _answerQuestion(int answerIndex) {
    if (_isAnswered) return;
    
    setState(() {
      _isAnswered = true;
      _selectedAnswerIndex = answerIndex;
      
      // Save user's answer
      _userAnswers[_questions[_currentQuestionIndex].id] = answerIndex;
    });
    
    // Auto-advance to next question after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _goToNextQuestion();
      }
    });
  }

  void _goToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isAnswered = false;
        _selectedAnswerIndex = null;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    // Calculate results
    int totalQuestions = _questions.length;
    int correctAnswers = 0;
    
    // Create map of questionId -> wasCorrect
    Map<String, bool> questionResults = {};
    
    for (var i = 0; i < _questions.length; i++) {
      String questionId = _questions[i].id;
      int? userAnswer = _userAnswers[questionId];
      
      bool isCorrect = userAnswer != null && 
                       userAnswer == _questions[i].correctAnswerIndex;
      
      if (isCorrect) {
        correctAnswers++;
      }
      
      questionResults[questionId] = isCorrect;
    }
    
    double score = totalQuestions > 0 
        ? (correctAnswers / totalQuestions) * 100 
        : 0;
    
    // Calculate time taken
    Duration timeTaken = Duration(seconds: widget.quiz.timeLimit - _remainingSeconds);
    if (widget.quiz.timeLimit == 0) {
      // If no time limit, just use a placeholder value
      timeTaken = const Duration(seconds: 0);
    }
    
    // Create quiz result
    QuizResult result = QuizResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      quizId: widget.quiz.id,
      userId: _userId,
      timestamp: DateTime.now(),
      correctAnswers: correctAnswers,
      totalQuestions: totalQuestions,
      score: score,
      timeTaken: timeTaken,
      questionResults: questionResults,
    );
    
    // Save result to Firebase
    _learningService.saveQuizResult(result).then((_) {
      // Navigate to results screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultScreen(
              quiz: widget.quiz,
              result: result,
              questions: _questions,
              userAnswers: _userAnswers,
              isTimeUp: _isTimeLimitReached,
            ),
          ),
        );
      }
    }).catchError((error) {
      print('Error saving quiz result: $error');
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving quiz result: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    
    setState(() {
      _isQuizCompleted = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when user tries to exit
        if (_userAnswers.isEmpty) {
          return true; // Allow exit if no answers yet
        }
        
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quit Quiz?'),
            content: const Text(
              'Your progress will be lost if you quit now.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Quit'),
              ),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.quiz.title,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 2,
          actions: [
            if (widget.quiz.timeLimit > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds < 30 ? Colors.red : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isQuizCompleted
            ? _buildLoadingResults()
            : _buildQuizContent(),
        bottomNavigationBar: _isQuizCompleted
            ? null
            : _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildLoadingResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Calculating your results...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final question = _questions[_currentQuestionIndex];
    
    return Column(
      children: [
        // Progress indicator
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
        
        // Question counter
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.quiz.category,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Question text
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Question image if available
                if (question.imageUrl != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Image.network(
                      question.imageUrl!,
                      fit: BoxFit.contain,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Text('Image not available'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Answer options
                ...List.generate(question.options.length, (index) {
                  return _buildAnswerOption(
                    index,
                    question.options[index],
                    question.correctAnswerIndex,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerOption(
    int index,
    String optionText,
    int correctIndex,
  ) {
    bool isSelected = _selectedAnswerIndex == index;
    bool showCorrect = _isAnswered && index == correctIndex;
    bool showIncorrect = _isAnswered && isSelected && index != correctIndex;
    
    Color cardColor = Colors.white;
    if (showCorrect) {
      cardColor = Colors.green.shade50;
    } else if (showIncorrect) {
      cardColor = Colors.red.shade50;
    } else if (isSelected) {
      cardColor = Theme.of(context).primaryColor.withAlpha(30);
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: showCorrect
              ? Colors.green
              : showIncorrect
                  ? Colors.red
                  : isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
          width: isSelected || showCorrect || showIncorrect ? 2 : 1,
        ),
      ),
      color: cardColor,
      elevation: isSelected ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isAnswered ? null : () => _answerQuestion(index),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: showCorrect
                      ? Colors.green
                      : showIncorrect
                          ? Colors.red
                          : isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade200,
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D...
                    style: TextStyle(
                      color: isSelected || showCorrect || showIncorrect
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  optionText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected || showCorrect ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (showCorrect)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                )
              else if (showIncorrect)
                const Icon(
                  Icons.cancel,
                  color: Colors.red,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          TextButton.icon(
            onPressed: _currentQuestionIndex > 0
                ? () {
                    setState(() {
                      _currentQuestionIndex--;
                      _isAnswered = _userAnswers.containsKey(
                        _questions[_currentQuestionIndex].id,
                      );
                      _selectedAnswerIndex = _userAnswers[
                        _questions[_currentQuestionIndex].id
                      ];
                    });
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
          
          // Next/Submit button
          ElevatedButton(
            onPressed: _isAnswered
                ? _goToNextQuestion
                : _currentQuestionIndex == _questions.length - 1
                    ? () {
                        // Show confirmation for submitting with unanswered questions
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Submit Quiz?'),
                            content: Text(
                              'You have left ${_questions.length - _userAnswers.length} of ${_questions.length} questions unanswered. Are you sure you want to submit?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _finishQuiz();
                                },
                                child: const Text('Submit'),
                              ),
                            ],
                          ),
                        );
                      }
                    : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: Text(
              _currentQuestionIndex == _questions.length - 1
                  ? 'Submit'
                  : 'Next',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}