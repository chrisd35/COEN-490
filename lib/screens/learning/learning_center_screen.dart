// lib/screens/learning/learning_center_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/learning_center_service.dart';
import '../../utils/learning_center_models.dart';
import 'learning_topic_screen.dart';
import 'heart_murmur_library_screen.dart';
import 'quiz_list_screen.dart';
import 'user_progress_screen.dart';

class LearningCenterScreen extends StatefulWidget {
  const LearningCenterScreen({Key? key}) : super(key: key);

  @override
  State<LearningCenterScreen> createState() => _LearningCenterScreenState();
}

class _LearningCenterScreenState extends State<LearningCenterScreen> {
  final LearningCenterService _learningService = LearningCenterService();
  late Future<List<LearningTopic>> _topicsFuture;
  late Future<UserProgress> _userProgressFuture;
  
  @override
  void initState() {
    super.initState();
    _topicsFuture = _learningService.getLearningTopics();
    _userProgressFuture = _learningService.getUserProgress(
      FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Learning Center',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _navigateToUserProgress(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _topicsFuture = _learningService.getLearningTopics();
            _userProgressFuture = _learningService.getUserProgress(
              FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
            );
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(),
                const SizedBox(height: 24),
                
                // Topics Section
                _buildSectionHeader('Learning Resources', Icons.menu_book),
                const SizedBox(height: 16),
                _buildTopicsList(),
                const SizedBox(height: 24),
                
                // Murmur Library
                _buildSectionHeader('Heart Murmur Library', Icons.hearing),
                const SizedBox(height: 16),
                _buildMurmurLibraryCard(),
                const SizedBox(height: 24),
                
                // Quiz Section
                _buildSectionHeader('Knowledge Assessment', Icons.quiz),
                const SizedBox(height: 16),
                _buildQuizCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withAlpha(180),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to the Learning Center',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<UserProgress>(
            future: _userProgressFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  'Loading your learning progress...',
                  style: TextStyle(color: Colors.white),
                );
              }
              
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text(
                  'Explore educational resources, heart murmur sounds, and test your knowledge.',
                  style: TextStyle(color: Colors.white),
                );
              }
              
              final progress = snapshot.data!;
              final completedTopics = progress.completedTopics.length;
              final quizResults = progress.quizResults.length;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Learning Progress:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Topics completed: $completedTopics',
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Quizzes taken: $quizResults',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () => _navigateToUserProgress(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('View My Progress'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTopicsList() {
    return FutureBuilder<List<LearningTopic>>(
      future: _topicsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading topics: ${snapshot.error}',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No topics available'),
          );
        }
        
        final topics = snapshot.data!;
        
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  topic.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  topic.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToTopic(topic),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMurmurLibraryCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _navigateToMurmurLibrary,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hearing,
                  color: Colors.redAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Heart Murmur Sound Library',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Listen to different heart murmurs and learn their clinical significance',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _navigateToQuizzes,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Interactive Quizzes',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Test your knowledge with quizzes on ECG, PulseOx, and heart murmurs',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTopic(LearningTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningTopicScreen(topic: topic),
      ),
    );
  }

  void _navigateToMurmurLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HeartMurmurLibraryScreen(),
      ),
    );
  }

  void _navigateToQuizzes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizListScreen(),
      ),
    );
  }

  void _navigateToUserProgress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProgressScreen(),
      ),
    );
  }
}