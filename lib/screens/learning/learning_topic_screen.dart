import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:logging/logging.dart' as logging;

final _logger = logging.Logger('LearningTopicScreen');

class LearningTopicScreen extends StatefulWidget {
  final LearningTopic topic;
  
  const LearningTopicScreen({
    Key? key,
    required this.topic,
  }) : super(key: key);

  @override
  State<LearningTopicScreen> createState() => _LearningTopicScreenState();
}

class _LearningTopicScreenState extends State<LearningTopicScreen> with SingleTickerProviderStateMixin {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<LearningTopic?> _topicFuture;
  late String _userId;
  int _currentResourceIndex = 0;
  bool _isCompleted = false;
  
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
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Topic marked as completed!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.severe('Error marking as completed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking as completed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.topic.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          if (_isCompleted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Tooltip(
                message: 'Completed',
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
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
                    icon: const Icon(Icons.check),
                    label: const Text('Mark Complete'),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                );
              },
            )
          : null,
      body: FutureBuilder<LearningTopic?>(
        future: _topicFuture,
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
                      'Error loading topic',
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
                        color: Colors.red[800],
                        fontSize: 14,
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
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
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
                    const Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No content available yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This topic has no learning resources available at the moment. Check back later for updates.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.description,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (topic.resources.length > 1) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Resources: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildResourceIndicator(topic.resources.length),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Resource navigation
              if (topic.resources.length > 1)
                _buildResourceNavigator(topic),
              
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
                ? Theme.of(context).primaryColor
                : Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
  
  Widget _buildResourceNavigator(LearningTopic topic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: _currentResourceIndex > 0
                ? () {
                    setState(() {
                      _currentResourceIndex--;
                    });
                  }
                : null,
            splashRadius: 24,
            tooltip: 'Previous resource',
          ),
          Expanded(
            child: Center(
              child: Text(
                topic.resources[_currentResourceIndex].title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: _currentResourceIndex < topic.resources.length - 1
                ? () {
                    setState(() {
                      _currentResourceIndex++;
                    });
                  }
                : null,
            splashRadius: 24,
            tooltip: 'Next resource',
          ),
        ],
      ),
    );
  }

  Widget _buildResourceContent(LearningResource resource) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resource title is now in the navigator
            
            // Tags
            if (resource.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: resource.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
            
            // Content based on type
            if (resource.type == 'text')
              _buildTextContent(resource.content),
            
            if (resource.type == 'audio' && resource.fileUrl != null)
              _buildAudioPlayer(resource.fileUrl!),
            
            if (resource.type == 'video' && resource.fileUrl != null)
              _buildVideoPlayer(resource.fileUrl!),
            
            const SizedBox(height: 80), // Space for the FAB
          ],
        ),
      ),
    );
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
          h1: const TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          h2: const TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          h3: const TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
          p: const TextStyle(
            fontSize: 16, 
            height: 1.6,
            letterSpacing: 0.15,
          ),
          strong: const TextStyle(fontWeight: FontWeight.w600),
          blockquote: TextStyle(
            color: Colors.grey[700],
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
          code: TextStyle(
            backgroundColor: Colors.grey[200],
            fontFamily: 'monospace',
            fontSize: 15,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          listBullet: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String audioUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.audiotrack,
            size: 64,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Audio Learning Material',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Listen to this audio resource to learn more about ${widget.topic.title}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Audio playback not implemented in this example'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Audio'),
            style: ElevatedButton.styleFrom(
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
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 64,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Video Learning Material',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Watch this video resource to learn more about ${widget.topic.title}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video playback not implemented in this example'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Video'),
            style: ElevatedButton.styleFrom(
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
    );
  }
}