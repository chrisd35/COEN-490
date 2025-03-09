
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_models.dart';
import '../../utils/learning_center_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class LearningTopicScreen extends StatefulWidget {
  final LearningTopic topic;
  
  const LearningTopicScreen({
    Key? key,
    required this.topic,
  }) : super(key: key);

  @override
  State<LearningTopicScreen> createState() => _LearningTopicScreenState();
}

class _LearningTopicScreenState extends State<LearningTopicScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<LearningTopic?> _topicFuture;
  late String _userId;
  int _currentResourceIndex = 0;
  bool _isCompleted = false;
  
  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    _topicFuture = _fetchLatestTopic();
    _checkCompletionStatus();
    _updateLastAccessed();
  }

  Future<LearningTopic?> _fetchLatestTopic() async {
    return _learningService.getLearningTopic(widget.topic.id);
  }

  Future<void> _checkCompletionStatus() async {
    final progress = await _learningService.getUserProgress(_userId);
    setState(() {
      _isCompleted = progress.completedTopics.contains(widget.topic.id);
    });
  }

  Future<void> _updateLastAccessed() async {
    await _learningService.updateCompletedTopic(_userId, widget.topic.id);
  }

  Future<void> _markAsCompleted() async {
    await _learningService.updateCompletedTopic(_userId, widget.topic.id);
    setState(() {
      _isCompleted = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Topic marked as completed!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topic.title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_isCompleted ? Icons.check_circle : Icons.check_circle_outline),
            color: _isCompleted ? Colors.green : null,
            onPressed: _isCompleted ? null : _markAsCompleted,
            tooltip: _isCompleted ? 'Completed' : 'Mark as completed',
          ),
        ],
      ),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading topic: ${snapshot.error}',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _topicFuture = _fetchLatestTopic();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final topic = snapshot.data ?? widget.topic;
          
          if (topic.resources.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No content available for this topic yet.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check back later for updates.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return Column(
            children: [
              // Topic description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withAlpha(15),
                child: Text(
                  topic.description,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              // Resource navigation
              if (topic.resources.length > 1)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Text(
                        'Resources (${_currentResourceIndex + 1}/${topic.resources.length}):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: _currentResourceIndex > 0
                            ? () {
                                setState(() {
                                  _currentResourceIndex--;
                                });
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: _currentResourceIndex < topic.resources.length - 1
                            ? () {
                                setState(() {
                                  _currentResourceIndex++;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              
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

  Widget _buildResourceContent(LearningResource resource) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resource title
          Text(
            resource.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Tags
          if (resource.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: resource.tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(40),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          
          // Content based on type
          if (resource.type == 'text')
            MarkdownBody(
              data: resource.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                p: TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          
          if (resource.type == 'audio' && resource.fileUrl != null)
            _buildAudioPlayer(resource.fileUrl!),
          
          if (resource.type == 'video' && resource.fileUrl != null)
            _buildVideoPlayer(resource.fileUrl!),
          
          const SizedBox(height: 32),
          
          // Mark as completed button
          if (!_isCompleted)
            Center(
              child: ElevatedButton.icon(
                onPressed: _markAsCompleted,
                icon: const Icon(Icons.check),
                label: const Text('Mark as Completed'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(String audioUrl) {
    // Placeholder for audio player
    // In a real app, use a proper audio player widget/plugin
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.audiotrack,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            'Audio content available',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('URL: $audioUrl'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Implement audio playback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Audio playback not implemented in this example'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    // Placeholder for video player
    // In a real app, use a proper video player widget/plugin
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.video_library,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            'Video content available',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('URL: $videoUrl'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // Implement video playback
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video playback not implemented in this example'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
          ),
        ],
      ),
    );
  }
}