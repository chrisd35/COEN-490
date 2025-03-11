import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'quiz_result_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('QuizScreen');

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  
  const QuizScreen({
    super.key,
    required this.quiz,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  final LearningCenterService _learningService = LearningCenterService();
  late String _userId;
  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  final Map<String, int> _userAnswers = {};
  bool _isQuizCompleted = false;
  int? _selectedAnswerIndex;
  
  // States for showing correct/incorrect answers
  bool _shouldShowAnswer = false;
  bool _isTransitioning = false;
  
  // Track which questions have had their answers checked
  final Set<String> _checkedQuestions = {};
  
  // Timer related
  late Timer? _timer;
  late int _remainingSeconds;
  bool _isTimeLimitReached = false;
  
  // Animation controller for option selection
  late AnimationController _animationController;
  late Animation<double> _animation;
  
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
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  void _shuffleQuestions() {
    // Shuffle questions
    _questions.shuffle(Random());
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _finishQuiz();
            _timer?.cancel();
            _isTimeLimitReached = true;
          }
        });
      }
    });
  }

  void _answerQuestion(int answerIndex) {
    if (_shouldShowAnswer || _isTransitioning) return;
    
    // Play selection animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    setState(() {
      _selectedAnswerIndex = answerIndex;
      
      // Save user's answer
      _userAnswers[_questions[_currentQuestionIndex].id] = answerIndex;
    });
  }

  void _showAnswer() {
    // Only proceed if an answer is selected - this is the core safeguard
    if (_selectedAnswerIndex == null) {
      // Show a simple toast message when trying to check without selecting an answer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an answer first'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Show the correct answer 
    setState(() {
      _shouldShowAnswer = true;
      // Add this question to checked questions set
      _checkedQuestions.add(_questions[_currentQuestionIndex].id);
      // Create a transition lock that prevents immediate button presses
      _isTransitioning = true;
    });
    
    // Just unlock interactions after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }
    });
  }

  Future<void> _finishQuiz() async {
    if (_isQuizCompleted) return;
    
    setState(() {
      _isQuizCompleted = true;
    });
    
    // Cancel timer to prevent memory leaks
    _timer?.cancel();
    
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
    
    try {
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
      
      // Store just the mounted state - no need to store context
      final isMounted = mounted;
      
      // Save result to Firebase
      await _learningService.saveQuizResult(result);
      
      // Navigate to results screen - wrapped in mounted check
      if (isMounted && mounted) {
        // Using context directly after the mounted check - no async gap
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
    } catch (error) {
      _logger.severe('Error saving quiz result: $error');
      
      // Check if widget is still mounted before using context
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving quiz result: $error'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // Show confirmation dialog when user tries to exit
        if (!didPop) {
          if (_userAnswers.isEmpty) {
            // No answers yet, safe to pop immediately
            if (!context.mounted) return;
            Navigator.of(context).pop();
            return;
          }
          
          // Make a local function to handle the popup
          Future<void> showQuitDialog() async {
            // Put all code that uses BuildContext inside here
            final shouldPop = await showDialog<bool>(
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
            
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          }
          
          // Call the function
          await showQuitDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: _isQuizCompleted
            ? _buildLoadingResults()
            : _buildQuizContent(),
        bottomNavigationBar: _isQuizCompleted
            ? null
            : _buildBottomNavBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.quiz.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      elevation: 0,
    );
  }

  Widget _buildLoadingResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            _isTimeLimitReached
                ? 'Time\'s up! Submitting your answers...'
                : 'Calculating your results...',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait a moment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final question = _questions[_currentQuestionIndex];
    final double progressPercent = (_currentQuestionIndex + 1) / _questions.length;
    final bool isTimeAlmostUp = widget.quiz.timeLimit > 0 && 
        _remainingSeconds < min(30, widget.quiz.timeLimit * 0.1);
    
    return Column(
      children: [
        // Progress and time information
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withAlpha(13), // 0.05 opacity
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withAlpha(51), // 0.2 opacity
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Timer display (more prominent)
              if (widget.quiz.timeLimit > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isTimeAlmostUp
                        ? Colors.red.withAlpha(26) // 0.1 opacity
                        : Theme.of(context).primaryColor.withAlpha(26), // 0.1 opacity
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTimeAlmostUp
                          ? Colors.red.withAlpha(77) // 0.3 opacity
                          : Theme.of(context).primaryColor.withAlpha(77), // 0.3 opacity
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        color: isTimeAlmostUp ? Colors.red : Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time Remaining: ${_formatTime(_remainingSeconds)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isTimeAlmostUp ? Colors.red : Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Progress indicator
              Row(
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Category and Difficulty
              Row(
                children: [
                  _buildTag(widget.quiz.category, Colors.blue),
                  const SizedBox(width: 8),
                  _buildTag(widget.quiz.difficulty, _getDifficultyColor(widget.quiz.difficulty)),
                ],
              ),
            ],
          ),
        ),
        
        // Question and Answers
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13), // 0.05 opacity
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.question,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      
                      // Question image if available
                      if (question.imageUrl != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            question.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) {
                              _logger.warning('Error loading image: $error');
                              return Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const Text(
                  'Select your answer:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 12),
                
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

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26), // 0.1 opacity
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha(77), // 0.3 opacity
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
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

  Widget _buildAnswerOption(
    int index,
    String optionText,
    int correctIndex,
  ) {
    bool isSelected = _selectedAnswerIndex == index;
    bool showCorrect = _shouldShowAnswer && index == correctIndex;
    bool showIncorrect = _shouldShowAnswer && isSelected && index != correctIndex;
    
    Color cardColor = Colors.white;
    if (showCorrect) {
      cardColor = Colors.green.shade50;
    } else if (showIncorrect) {
      cardColor = Colors.red.shade50;
    } else if (isSelected) {
      cardColor = Theme.of(context).primaryColor.withAlpha(13); // 0.05 opacity
    }
    
    final iconData = showCorrect 
        ? Icons.check_circle_outline
        : showIncorrect 
            ? Icons.cancel_outlined
            : null;
    
    final iconColor = showCorrect 
        ? Colors.green 
        : showIncorrect 
            ? Colors.red 
            : null;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final scale = isSelected && _animationController.status == AnimationStatus.forward
            ? 1.0 + (_animation.value * 0.03)
            : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          elevation: isSelected ? 1 : 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _shouldShowAnswer || _isTransitioning ? null : () => _answerQuestion(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: showCorrect
                      ? Colors.green
                      : showIncorrect
                          ? Colors.red
                          : isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                  width: (showCorrect || showIncorrect || isSelected) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Option letter
                  Container(
                    width: 36,
                    height: 36,
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
                          color: (isSelected || showCorrect || showIncorrect)
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Option text
                  Expanded(
                    child: Text(
                      optionText,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: isSelected || showCorrect || showIncorrect
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  
                  // Indicator icon
                  if (iconData != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // 0.05 opacity
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous button
            TextButton.icon(
              onPressed: (_isTransitioning || _currentQuestionIndex <= 0)
                  ? null
                  : () {
                      setState(() {
                        _currentQuestionIndex--;
                        String questionId = _questions[_currentQuestionIndex].id;
                        // Restore the "checked" state if we previously checked this question
                        _shouldShowAnswer = _checkedQuestions.contains(questionId);
                        _selectedAnswerIndex = _userAnswers[questionId];
                      });
                    },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Previous'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            
            // Next/Submit button
            ElevatedButton.icon(
              onPressed: _isTransitioning
                  ? null
                  : _shouldShowAnswer
                      ? isLastQuestion
                          ? _finishQuiz
                          : () {
                              // When moving to next question, add this question to checked set
                              _checkedQuestions.add(_questions[_currentQuestionIndex].id);
                              
                              setState(() {
                                _currentQuestionIndex++;
                                String questionId = _questions[_currentQuestionIndex].id;
                                // Check if we've already seen this question's answer before
                                _shouldShowAnswer = _checkedQuestions.contains(questionId);
                                _selectedAnswerIndex = _userAnswers[questionId];
                              });
                            }
                      : _selectedAnswerIndex != null
                          ? _showAnswer  // Check answer only when an answer is selected
                          : null,  // Explicitly disable if no answer selected
              icon: Icon(
                isLastQuestion 
                    ? (_shouldShowAnswer ? Icons.check_circle : Icons.visibility) 
                    : (_shouldShowAnswer ? Icons.arrow_forward : Icons.visibility),
                size: 18,
              ),
              label: Text(
                isLastQuestion 
                    ? (_shouldShowAnswer ? 'Submit' : 'Check Answer') 
                    : (_shouldShowAnswer ? 'Next' : 'Check Answer'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastQuestion && _shouldShowAnswer
                    ? Colors.green
                    : _shouldShowAnswer
                        ? Colors.blue
                        : Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
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

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}