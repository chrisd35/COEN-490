import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:math';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'quiz_result_screen.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('QuizScreen');

// Using the same theme class from the QuizListScreen
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
  
  // Quiz specific colors
  static const Color correctColor = Color(0xFF4CAF50);  // Green for correct answers
  static const Color incorrectColor = Color(0xFFE53935); // Red for incorrect answers
  static const Color selectedColor = Color(0xFF1D557E); // Blue for selected answers
  static const Color timeWarningColor = Color(0xFFFF9800); // Warning color for low time
  
  // Difficulty colors
  static const Color easyColor = Color(0xFF4CAF50);     // Green for easy
  static const Color mediumColor = Color(0xFFFF9800);   // Orange for medium
  static const Color hardColor = Color(0xFFE53935);     // Red for hard
  
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
  
  static final TextStyle labelStyle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
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
  static final BorderRadius optionRadius = BorderRadius.circular(12);
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
}

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
    // Only proceed if an answer is selected
    if (_selectedAnswerIndex == null) {
      _showSnackBar('Please select an answer first');
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
    
    // Unlock interactions after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }
    });
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
        duration: const Duration(seconds: 2),
      ),
    );
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
      
      if (mounted) {
        _showSnackBar('Error saving quiz result. Please try again.');
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
        if (!didPop) {
          if (_userAnswers.isEmpty) {
            // No answers yet, safe to pop immediately
            if (!context.mounted) return;
            Navigator.of(context).pop();
            return;
          }
          
          // Show confirmation dialog
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Colors.amber,
                    ).animate().shake(duration: 700.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Quit Quiz?',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: QuizTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your progress will be lost if you quit now.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: QuizTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: QuizTheme.buttonRadius,
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: QuizTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QuizTheme.incorrectColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: QuizTheme.buttonRadius,
                              ),
                            ),
                            child: Text(
                              'QUIT',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ) ?? false;
          
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: QuizTheme.secondaryColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: QuizTheme.textPrimary,
          elevation: 0,
          centerTitle: false,
          title: Text(
            widget.quiz.title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: QuizTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
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
        children: [
          CircularProgressIndicator(
            color: QuizTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          Text(
            _isTimeLimitReached
                ? 'Time\'s up! Submitting your answers...'
                : 'Calculating your results...',
            style: QuizTheme.subheadingStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait a moment',
            style: QuizTheme.captionStyle,
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
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [QuizTheme.subtleShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timer display
              if (widget.quiz.timeLimit > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isTimeAlmostUp
                        ? QuizTheme.timeWarningColor.withAlpha(20)
                        : QuizTheme.primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: isTimeAlmostUp ? QuizTheme.timeWarningColor : QuizTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time Remaining: ${_formatTime(_remainingSeconds)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isTimeAlmostUp ? QuizTheme.timeWarningColor : QuizTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ).animate(
                  autoPlay: isTimeAlmostUp,
                  onPlay: (controller) => controller.repeat(),
                ).shimmer(
                  duration: 1500.ms,
                  color: isTimeAlmostUp ? QuizTheme.timeWarningColor : QuizTheme.primaryColor,
                  // Apply shimmer only when time is almost up
                  delay: isTimeAlmostUp ? 0.ms : 9999999.ms,
                ),
                
              // Progress indicator
              Row(
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}/${_questions.length}',
                    style: QuizTheme.emphasisStyle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        backgroundColor: Colors.grey.withAlpha(40),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          QuizTheme.primaryColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: QuizTheme.primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(progressPercent * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: QuizTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Category and Difficulty
              Row(
                children: [
                  _buildTag(widget.quiz.category, QuizTheme.getCategoryColor(widget.quiz.category)),
                  const SizedBox(width: 8),
                  _buildTag(widget.quiz.difficulty, QuizTheme.getDifficultyColor(widget.quiz.difficulty)),
                ],
              ),
            ],
          ),
        ),
        
        // Question and Answers
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: QuizTheme.borderRadius,
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.question,
                          style: QuizTheme.cardTitleStyle.copyWith(
                            fontSize: 18,
                            height: 1.4,
                          ),
                        ),
                        
                        // Question image if available
                        if (question.imageUrl != null) ...[
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                                    color: Colors.grey.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 48,
                                        color: Colors.grey.withAlpha(150),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Image not available',
                                        style: QuizTheme.labelStyle.copyWith(
                                          color: QuizTheme.textSecondary,
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
                ),
                
                const SizedBox(height: 24),
                
                // Answer heading
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                  child: Text(
                    'Select your answer:',
                    style: QuizTheme.emphasisStyle,
                  ),
                ),
                
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
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
    Color borderColor;
    double borderWidth = 1.0;
    
    if (showCorrect) {
      cardColor = QuizTheme.correctColor.withAlpha(10);
      borderColor = QuizTheme.correctColor;
      borderWidth = 1.5;
    } else if (showIncorrect) {
      cardColor = QuizTheme.incorrectColor.withAlpha(10);
      borderColor = QuizTheme.incorrectColor;
      borderWidth = 1.5;
    } else if (isSelected) {
      cardColor = QuizTheme.selectedColor.withAlpha(10);
      borderColor = QuizTheme.selectedColor;
      borderWidth = 1.5;
    } else {
      borderColor = Colors.grey.withAlpha(40);
    }
    
    final IconData? iconData = showCorrect 
        ? Icons.check_circle_rounded
        : showIncorrect 
            ? Icons.cancel_rounded
            : null;
    
    final Color? iconColor = showCorrect 
        ? QuizTheme.correctColor 
        : showIncorrect 
            ? QuizTheme.incorrectColor 
            : null;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final scale = isSelected && _animationController.status == AnimationStatus.forward
            ? 1.0 + (_animation.value * 0.02)
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
          borderRadius: QuizTheme.optionRadius,
          child: InkWell(
            borderRadius: QuizTheme.optionRadius,
            onTap: _shouldShowAnswer || _isTransitioning ? null : () => _answerQuestion(index),
            splashColor: QuizTheme.selectedColor.withAlpha(20),
            highlightColor: QuizTheme.selectedColor.withAlpha(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: QuizTheme.optionRadius,
                border: Border.all(
                  color: borderColor,
                  width: borderWidth,
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
                          ? QuizTheme.correctColor
                          : showIncorrect
                              ? QuizTheme.incorrectColor
                              : isSelected
                                  ? QuizTheme.selectedColor
                                  : Colors.grey.withAlpha(40),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + index), // A, B, C, D...
                        style: GoogleFonts.inter(
                          color: (isSelected || showCorrect || showIncorrect)
                              ? Colors.white
                              : QuizTheme.textPrimary,
                          fontWeight: FontWeight.w600,
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
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: isSelected || showCorrect || showIncorrect
                            ? FontWeight.w500
                            : FontWeight.normal,
                        color: QuizTheme.textPrimary,
                      ),
                    ),
                  ),
                  
                  // Indicator icon
                  if (iconData != null)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (iconColor?.withAlpha(20) ?? Colors.transparent),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 20,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous button
            OutlinedButton.icon(
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
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: QuizTheme.primaryColor,
                side: BorderSide(
                  color: (_isTransitioning || _currentQuestionIndex <= 0)
                      ? Colors.grey.withAlpha(60)
                      : QuizTheme.primaryColor.withAlpha(100),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: QuizTheme.buttonRadius,
                ),
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
                              // When moving to next question
                              setState(() {
                                _currentQuestionIndex++;
                                String questionId = _questions[_currentQuestionIndex].id;
                                // Check if we've already seen this question's answer before
                                _shouldShowAnswer = _checkedQuestions.contains(questionId);
                                _selectedAnswerIndex = _userAnswers[questionId];
                              });
                            }
                      : _selectedAnswerIndex != null
                          ? _showAnswer
                          : null,
              icon: Icon(
                isLastQuestion 
                    ? (_shouldShowAnswer ? Icons.check_circle_rounded : Icons.visibility_rounded) 
                    : (_shouldShowAnswer ? Icons.arrow_forward_rounded : Icons.visibility_rounded),
                size: 18,
              ),
              label: Text(
                isLastQuestion 
                    ? (_shouldShowAnswer ? 'Submit Quiz' : 'Check Answer') 
                    : (_shouldShowAnswer ? 'Next Question' : 'Check Answer'),
                style: QuizTheme.buttonTextStyle,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastQuestion && _shouldShowAnswer
                    ? QuizTheme.correctColor
                    : QuizTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.withAlpha(100),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}