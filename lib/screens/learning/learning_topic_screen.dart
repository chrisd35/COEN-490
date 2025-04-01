import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('LearningTopicScreen');

// Design constants to maintain consistency with other screens
class LearningTheme {
  // Main color palette
  static const Color primaryColor = Color(0xFF1D557E);  // Main blue
  static const Color secondaryColor = Color(0xFFE6EDF7); // Light blue background
  static const Color accentColor = Color(0xFF2E86C1);   // Medium blue for accents
  
  // Resource type colors
  static const Color textColor = Color(0xFF1976D2);     // Blue for text content
  static const Color audioColor = Color(0xFF00ACC1);    // Cyan for audio content
  static const Color videoColor = Color(0xFF2196F3);    // Light blue for video content
  
  // Action colors
  static const Color completedColor = Color(0xFF4CAF50); // Green for completed
  
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
  
  // Get color for resource type
  static Color getResourceTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return textColor;
      case 'audio':
        return audioColor;
      case 'video':
        return videoColor;
      default:
        return accentColor;
    }
  }
}

class LearningTopicScreen extends StatefulWidget {
  final LearningTopic topic;
  
  const LearningTopicScreen({
    super.key,
    required this.topic,
  });

  @override
  State<LearningTopicScreen> createState() => _LearningTopicScreenState();
}

class _LearningTopicScreenState extends State<LearningTopicScreen> with SingleTickerProviderStateMixin {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<LearningTopic?> _topicFuture;
  late String _userId;
  int _currentResourceIndex = 0;
  bool _isCompleted = false;
  final ScrollController _scrollController = ScrollController();
  
  // Animation controller for the completion button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _topicFuture = _fetchLatestTopic();
    _checkCompletionStatus();
    _updateLastAccessed();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<LearningTopic?> _fetchLatestTopic() async {
    try {
      return await _learningService.getLearningTopic(widget.topic.id);
    } catch (e) {
      _logger.severe('Error fetching topic: $e');
      return null;
    }
  }

  Future<void> _checkCompletionStatus() async {
    try {
      final progress = await _learningService.getUserProgress(_userId);
      if (mounted) {
        setState(() {
          _isCompleted = progress.completedTopics.contains(widget.topic.id);
        });
      }
    } catch (e) {
      _logger.warning('Error checking completion status: $e');
    }
  }

  Future<void> _updateLastAccessed() async {
    try {
      await _learningService.updateCompletedTopic(_userId, widget.topic.id);
    } catch (e) {
      _logger.warning('Error updating last accessed: $e');
    }
  }

  Future<void> _markAsCompleted() async {
    try {
      // Play animation
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      
      await _learningService.updateCompletedTopic(_userId, widget.topic.id);
      
      if (mounted) {
        setState(() {
          _isCompleted = true;
        });
        
        _showSnackBar('Topic marked as completed!', isSuccess: true);
      }
    } catch (e) {
      _logger.severe('Error marking as completed: $e');
      if (mounted) {
        _showSnackBar('Error marking as completed', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError
            ? Colors.red[700]
            : isSuccess
                ? LearningTheme.completedColor
                : LearningTheme.primaryColor,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearningTheme.secondaryColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LearningTheme.textPrimary,
        elevation: 0,
        centerTitle: false,
        title: Text(
          widget.topic.title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: LearningTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Tooltip(
                message: 'Completed',
                child: Icon(
                  Icons.check_circle_rounded,
                  color: LearningTheme.completedColor,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: !_isCompleted
          ? AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FloatingActionButton.extended(
  onPressed: _markAsCompleted,
  icon: const Icon(
    Icons.check_rounded, 
    color: Colors.white, // Add this to make the checkmark white
  ),
  label: Text(
    'Mark Complete',
    style: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
  backgroundColor: LearningTheme.primaryColor,
  elevation: 2,
),
                );
              },
            ).animate().fadeIn(duration: 500.ms, delay: 800.ms)
          : null,
      body: FutureBuilder<LearningTopic?>(
        future: _topicFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: LearningTheme.primaryColor,
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
                      'Error loading topic',
                      style: LearningTheme.cardTitleStyle,
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
                          _topicFuture = _fetchLatestTopic();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LearningTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: LearningTheme.buttonRadius,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final topic = snapshot.data ?? widget.topic;
          
          if (topic.resources.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 64,
                      color: Colors.grey.withAlpha(150),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No content available yet',
                      style: LearningTheme.cardTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This topic has no learning resources available at the moment. Check back later for updates.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: LearningTheme.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LearningTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        side: BorderSide(
                          color: LearningTheme.primaryColor.withAlpha(100),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: LearningTheme.buttonRadius,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return Column(
            children: [
              // Topic description card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.description,
                      style: LearningTheme.bodyStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: LearningTheme.textSecondary,
                      ),
                    ),
                    if (topic.resources.length > 1) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Resources: ',
                            style: LearningTheme.emphasisStyle,
                          ),
                          const SizedBox(width: 4),
                          _buildResourceIndicator(topic.resources.length),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
              
              // Resource navigation
              if (topic.resources.length > 1)
                _buildResourceNavigator(topic).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              
              // Resource content
              Expanded(
                child: _buildResourceContent(topic.resources[_currentResourceIndex]),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildResourceIndicator(int total) {
    return Row(
      children: List.generate(
        total,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentResourceIndex
                ? LearningTheme.primaryColor
                : LearningTheme.primaryColor.withAlpha(60),
          ),
        ),
      ),
    );
  }
  
  Widget _buildResourceNavigator(LearningTopic topic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [LearningTheme.subtleShadow],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _currentResourceIndex > 0
                  ? LearningTheme.primaryColor.withAlpha(20)
                  : Colors.grey.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              onPressed: _currentResourceIndex > 0
                  ? () {
                      setState(() {
                        _currentResourceIndex--;
                      });
                    }
                  : null,
              color: _currentResourceIndex > 0
                  ? LearningTheme.primaryColor
                  : Colors.grey,
              tooltip: 'Previous resource',
              splashRadius: 24,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                topic.resources[_currentResourceIndex].title,
                style: LearningTheme.cardTitleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _currentResourceIndex < topic.resources.length - 1
                  ? LearningTheme.primaryColor.withAlpha(20)
                  : Colors.grey.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: _currentResourceIndex < topic.resources.length - 1
                  ? () {
                      setState(() {
                        _currentResourceIndex++;
                      });
                    }
                  : null,
              color: _currentResourceIndex < topic.resources.length - 1
                  ? LearningTheme.primaryColor
                  : Colors.grey,
              tooltip: 'Next resource',
              splashRadius: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceContent(LearningResource resource) {
    final resourceColor = LearningTheme.getResourceTypeColor(resource.type);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LearningTheme.borderRadius,
        ),
        color: Colors.white,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tags
              if (resource.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: resource.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: resourceColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: resourceColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              
              // Content based on type
              if (resource.type == 'text')
                _buildTextContent(resource.content).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              
              if (resource.type == 'audio' && resource.fileUrl != null)
                _buildAudioPlayer(resource.fileUrl!).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              
              if (resource.type == 'video' && resource.fileUrl != null)
                _buildVideoPlayer(resource.fileUrl!).animate().fadeIn(duration: 500.ms, delay: 300.ms),
              
              const SizedBox(height: 80), // Space for the FAB
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 300.ms);
  }
  
  Widget _buildTextContent(String content) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: GoogleFonts.inter(
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            height: 1.4,
            color: LearningTheme.textPrimary,
          ),
          h2: GoogleFonts.inter(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            height: 1.4,
            color: LearningTheme.textPrimary,
          ),
          h3: GoogleFonts.inter(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            height: 1.4,
            color: LearningTheme.textPrimary,
          ),
          p: GoogleFonts.inter(
            fontSize: 16, 
            height: 1.6,
            letterSpacing: 0.15,
            color: LearningTheme.textPrimary,
          ),
          strong: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: LearningTheme.textPrimary,
          ),
          blockquote: GoogleFonts.inter(
            color: LearningTheme.textSecondary,
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
          code: GoogleFonts.sourceCodePro(
            backgroundColor: Colors.grey[200],
            fontSize: 15,
            color: LearningTheme.textPrimary,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          listBullet: GoogleFonts.inter(
            fontSize: 16,
            color: LearningTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String audioUrl) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: LearningTheme.secondaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: LearningTheme.audioColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.headphones_rounded,
              size: 48,
              color: LearningTheme.audioColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Audio Learning Material',
            style: LearningTheme.cardTitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Listen to this audio resource to learn more about ${widget.topic.title}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: LearningTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showSnackBar('Audio playback not implemented in this example');
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play Audio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LearningTheme.audioColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: LearningTheme.buttonRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LearningTheme.secondaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [LearningTheme.subtleShadow],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Play button overlay
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _showSnackBar('Video playback not implemented in this example');
                    },
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withAlpha(40),
                    highlightColor: Colors.transparent,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Video Learning Material',
            style: LearningTheme.cardTitleStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Watch this video resource to learn more about ${widget.topic.title}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: LearningTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showSnackBar('Video playback not implemented in this example');
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LearningTheme.videoColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: LearningTheme.buttonRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}