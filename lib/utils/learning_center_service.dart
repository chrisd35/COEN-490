// lib/services/learning_center_service.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/learning_center_models.dart';
import 'package:logging/logging.dart' as logging;


final _logger = logging.Logger('LearningCenterService');

class LearningCenterService {
  final DatabaseReference _database;
  final FirebaseStorage _storage;

  LearningCenterService()
      : _database = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: 'https://respirhythm-default-rtdb.firebaseio.com/',
        ).ref(),
        _storage = FirebaseStorage.instanceFor(
          app: Firebase.app(),
          bucket: 'respirhythm.firebasestorage.app',
        );

  // Learning Topics methods
  Future<List<LearningTopic>> getLearningTopics() async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('topics')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return await _initializeDefaultTopics();
      }

      Map<dynamic, dynamic> topicsMap = snapshot.value as Map<dynamic, dynamic>;
      List<LearningTopic> topics = [];

      try {
        for (var entry in topicsMap.entries) {
          try {
            LearningTopic topic = LearningTopic.fromMap(entry.value as Map<dynamic, dynamic>);
            topics.add(topic);
          } catch (e) {
            _logger.warning('Error parsing topic data: $e');
          }
        }
      } catch (e) {
        _logger.severe('Error iterating through topics: $e');
      }

      // Sort alphabetically by title
      topics.sort((a, b) => a.title.compareTo(b.title));
      return topics;
    } catch (e) {
      _logger.severe('Error fetching learning topics: $e');
      rethrow;
    }
  }

  Future<LearningTopic?> getLearningTopic(String topicId) async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('topics')
          .child(topicId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return LearningTopic.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      _logger.severe('Error fetching learning topic: $e');
      return null;
    }
  }

  // Heart Murmurs methods
  Future<List<HeartMurmur>> getHeartMurmurs() async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('heartMurmurs')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return await _initializeDefaultHeartMurmurs();
      }

      Map<dynamic, dynamic> murmuersMap = snapshot.value as Map<dynamic, dynamic>;
      List<HeartMurmur> murmurs = [];

      try {
        for (var entry in murmuersMap.entries) {
          try {
            HeartMurmur murmur = HeartMurmur.fromMap(entry.value as Map<dynamic, dynamic>);
            murmurs.add(murmur);
          } catch (e) {
            _logger.warning('Error parsing heart murmur data: $e');
          }
        }
      } catch (e) {
        _logger.severe('Error iterating through heart murmurs: $e');
      }

      // Sort alphabetically by name
      murmurs.sort((a, b) => a.name.compareTo(b.name));
      return murmurs;
    } catch (e) {
      _logger.severe('Error fetching heart murmurs: $e');
      rethrow;
    }
  }

  Future<HeartMurmur?> getHeartMurmur(String murmurId) async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('heartMurmurs')
          .child(murmurId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return HeartMurmur.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      _logger.severe('Error fetching heart murmur: $e');
      return null;
    }
  }

  Future<String> getImageUrl(String? path) async {
  if (path == null || path.isEmpty) {
    throw Exception('Image path is null or empty');
  }
  
  try {
    _logger.info('Fetching image URL from path: $path');
    return await _storage.ref(path).getDownloadURL();
  } catch (e) {
    _logger.severe('Error getting image URL: $e');
    throw Exception('Failed to load image: $e');
  }
}

  // Quiz methods
  Future<List<Quiz>> getQuizzes() async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('quizzes')
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return await _initializeDefaultQuizzes();
      }

      Map<dynamic, dynamic> quizzesMap = snapshot.value as Map<dynamic, dynamic>;
      List<Quiz> quizzes = [];

      try {
        for (var entry in quizzesMap.entries) {
          try {
            Quiz quiz = Quiz.fromMap(entry.value as Map<dynamic, dynamic>);
            quizzes.add(quiz);
          } catch (e) {
            _logger.warning('Error parsing quiz data: $e');
          }
        }
      } catch (e) {
        _logger.severe('Error iterating through quizzes: $e');
      }

      // Sort by category and then difficulty
      quizzes.sort((a, b) {
        int categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        
        // Custom difficulty sort (Easy, Medium, Hard)
        Map<String, int> difficultyOrder = {
          'Easy': 0,
          'Medium': 1,
          'Hard': 2,
        };
        
        return (difficultyOrder[a.difficulty] ?? 1)
            .compareTo(difficultyOrder[b.difficulty] ?? 1);
      });
      
      return quizzes;
    } catch (e) {
      _logger.severe('Error fetching quizzes: $e');
      rethrow;
    }
  }

  Future<Quiz?> getQuiz(String quizId) async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('quizzes')
          .child(quizId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      return Quiz.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      _logger.severe('Error fetching quiz: $e');
      return null;
    }
  }

  // User Progress methods
  Future<UserProgress> getUserProgress(String userId) async {
    try {
      DataSnapshot snapshot = await _database
          .child('learningCenter')
          .child('userProgress')
          .child(userId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        // Create new user progress record
        UserProgress newProgress = UserProgress(userId: userId);
        await saveUserProgress(newProgress);
        return newProgress;
      }

      return UserProgress.fromMap(snapshot.value as Map<dynamic, dynamic>);
    } catch (e) {
      _logger.severe('Error fetching user progress: $e');
      // Return empty progress object on error
      return UserProgress(userId: userId);
    }
  }

  Future<void> saveUserProgress(UserProgress progress) async {
    try {
      await _database
          .child('learningCenter')
          .child('userProgress')
          .child(progress.userId)
          .set(progress.toMap());
      
      _logger.info('User progress saved successfully!');
    } catch (e) {
      _logger.severe('Error saving user progress: $e');
      rethrow;
    }
  }

  Future<void> updateCompletedTopic(String userId, String topicId) async {
    try {
      UserProgress progress = await getUserProgress(userId);
      
      if (!progress.completedTopics.contains(topicId)) {
        progress.completedTopics.add(topicId);
      }
      
      // Update last accessed
      Map<String, DateTime> updatedLastAccessed = Map.from(progress.lastAccessedTopics);
      updatedLastAccessed[topicId] = DateTime.now();
      
      UserProgress updatedProgress = UserProgress(
        userId: userId,
        completedTopics: progress.completedTopics,
        quizResults: progress.quizResults,
        lastAccessedTopics: updatedLastAccessed,
      );
      
      await saveUserProgress(updatedProgress);
    } catch (e) {
      _logger.severe('Error updating completed topic: $e');
      rethrow;
    }
  }

  Future<void> saveQuizResult(QuizResult result) async {
    try {
      UserProgress progress = await getUserProgress(result.userId);
      
      List<QuizResult> updatedResults = List.from(progress.quizResults);
      updatedResults.add(result);
      
      UserProgress updatedProgress = UserProgress(
        userId: result.userId,
        completedTopics: progress.completedTopics,
        quizResults: updatedResults,
        lastAccessedTopics: progress.lastAccessedTopics,
      );
      
      await saveUserProgress(updatedProgress);
      
      // Also save individual quiz result
      await _database
          .child('learningCenter')
          .child('quizResults')
          .child(result.userId)
          .child(result.id)
          .set(result.toMap());
      
      _logger.info('Quiz result saved successfully!');
    } catch (e) {
      _logger.severe('Error saving quiz result: $e');
      rethrow;
    }
  }
  
  Future<String> getAudioUrl(String path) async {
    try {
      return await _storage.ref(path).getDownloadURL();
    } catch (e) {
      _logger.severe('Error getting audio URL: $e');
      rethrow;
    }
  }

  // Helper methods to initialize default data
  Future<List<LearningTopic>> _initializeDefaultTopics() async {
    List<LearningTopic> defaultTopics = [
      LearningTopic(
        id: 'ecg_basics',
        title: 'ECG Basics',
        description: 'Learn the fundamentals of electrocardiogram (ECG) interpretation.',
        resources: [
          LearningResource(
            id: 'ecg_intro',
            title: 'Introduction to ECG',
            content: 'An electrocardiogram (ECG) is a test that records the electrical activity of the heart. It is a non-invasive procedure...',
            type: 'text',
          ),
          LearningResource(
            id: 'ecg_components',
            title: 'ECG Components',
            content: 'The main components of an ECG include: P wave, PR interval, QRS complex, ST segment, T wave, and QT interval...',
            type: 'text',
          ),
        ],
      ),
      LearningTopic(
        id: 'pulseox_basics',
        title: 'Pulse Oximetry Fundamentals',
        description: 'Understanding pulse oximetry measurements and clinical significance.',
        resources: [
          LearningResource(
            id: 'pulseox_intro',
            title: 'Introduction to Pulse Oximetry',
            content: 'Pulse oximetry is a non-invasive method for monitoring a person\'s oxygen saturation and heart rate...',
            type: 'text',
          ),
        ],
      ),
      LearningTopic(
        id: 'heart_murmurs',
        title: 'Heart Murmur Identification',
        description: 'Learn to identify and classify different types of heart murmurs.',
        resources: [
          LearningResource(
            id: 'murmur_basics',
            title: 'Heart Murmur Basics',
            content: 'Heart murmurs are sounds caused by turbulent blood flow through the heart valves or near the heart...',
            type: 'text',
          ),
        ],
      ),
    ];

    // Save default topics to Firebase
    for (var topic in defaultTopics) {
      await _database
          .child('learningCenter')
          .child('topics')
          .child(topic.id)
          .set(topic.toMap());
    }

    return defaultTopics;
  }

  Future<List<HeartMurmur>> _initializeDefaultHeartMurmurs() async {
    List<HeartMurmur> defaultMurmurs = [
      HeartMurmur(
        id: 'aortic_stenosis',
        name: 'Aortic Stenosis',
        description: 'Systolic ejection murmur due to narrowing of the aortic valve opening.',
        position: 'Right 2nd intercostal space',
        timing: 'Systolic',
        quality: 'Harsh, crescendo-decrescendo',
        grade: 'II-VI',
        audioUrl: 'audio/heart_murmurs/aortic_stenosis.mp3',
        clinicalImplications: [
          'Left ventricular hypertrophy',
          'Angina',
          'Syncope',
          'Heart failure'
        ],
      ),
      HeartMurmur(
        id: 'mitral_regurgitation',
        name: 'Mitral Regurgitation',
        description: 'Holosystolic murmur caused by backflow of blood from the left ventricle to the left atrium.',
        position: 'Apex (5th intercostal space, midclavicular line)',
        timing: 'Holosystolic',
        quality: 'Blowing',
        grade: 'I-VI',
        audioUrl: 'audio/heart_murmurs/mitral_regurgitation.mp3',
        clinicalImplications: [
          'Left atrial enlargement',
          'Left ventricular enlargement',
          'Heart failure',
          'Atrial fibrillation'
        ],
      ),
      HeartMurmur(
        id: 'ventricular_septal_defect',
        name: 'Ventricular Septal Defect (VSD)',
        description: 'Holosystolic murmur caused by blood flow from the left ventricle to the right ventricle through a septal defect.',
        position: 'Left lower sternal border',
        timing: 'Holosystolic',
        quality: 'Harsh',
        grade: 'III-VI',
        audioUrl: 'audio/heart_murmurs/vsd.mp3',
        clinicalImplications: [
          'Right ventricular hypertrophy',
          'Pulmonary hypertension',
          'Eisenmenger syndrome',
          'Heart failure'
        ],
      ),
    ];

    // Save default murmurs to Firebase
    for (var murmur in defaultMurmurs) {
      await _database
          .child('learningCenter')
          .child('heartMurmurs')
          .child(murmur.id)
          .set(murmur.toMap());
    }

    return defaultMurmurs;
  }

  Future<List<Quiz>> _initializeDefaultQuizzes() async {
    List<Quiz> defaultQuizzes = [
      Quiz(
        id: 'ecg_basics_quiz',
        title: 'ECG Basics Quiz',
        description: 'Test your knowledge of basic ECG interpretation.',
        category: 'ECG',
        difficulty: 'Easy',
        questions: [
          QuizQuestion(
            id: 'ecg_q1',
            question: 'What does the P wave represent in an ECG?',
            options: [
              'Ventricular depolarization',
              'Atrial depolarization',
              'Ventricular repolarization',
              'Atrial repolarization'
            ],
            correctAnswerIndex: 1,
            explanation: 'The P wave represents atrial depolarization (contraction of the atria).',
            category: 'ECG',
            difficulty: 'Easy',
          ),
          QuizQuestion(
            id: 'ecg_q2',
            question: 'What does the QRS complex represent in an ECG?',
            options: [
              'Atrial depolarization',
              'Ventricular depolarization',
              'Atrial repolarization',
              'Ventricular repolarization'
            ],
            correctAnswerIndex: 1,
            explanation: 'The QRS complex represents ventricular depolarization (contraction of the ventricles).',
            category: 'ECG',
            difficulty: 'Easy',
          ),
        ],
        timeLimit: 300,
      ),
      Quiz(
        id: 'heart_murmurs_quiz',
        title: 'Heart Murmur Identification',
        description: 'Test your knowledge of heart murmur identification and classification.',
        category: 'Heart Murmurs',
        difficulty: 'Medium',
        questions: [
          QuizQuestion(
            id: 'murmur_q1',
            question: 'Which heart murmur is characterized by a harsh, crescendo-decrescendo systolic ejection murmur at the right upper sternal border?',
            options: [
              'Mitral regurgitation',
              'Aortic stenosis',
              'Ventricular septal defect',
              'Patent ductus arteriosus'
            ],
            correctAnswerIndex: 1,
            explanation: 'Aortic stenosis produces a harsh, crescendo-decrescendo (diamond-shaped) systolic ejection murmur best heard at the right upper sternal border (2nd intercostal space).',
            category: 'Heart Murmurs',
            difficulty: 'Medium',
          ),
          QuizQuestion(
            id: 'murmur_q2',
            question: 'Which auscultation position is best for hearing a mitral regurgitation murmur?',
            options: [
              'Right 2nd intercostal space',
              'Left 2nd intercostal space',
              'Left lower sternal border',
              'Apex (5th intercostal space, midclavicular line)'
            ],
            correctAnswerIndex: 3,
            explanation: 'Mitral regurgitation murmurs are best heard at the cardiac apex (5th intercostal space, midclavicular line) and often radiate to the axilla.',
            category: 'Heart Murmurs',
            difficulty: 'Medium',
          ),
        ],
        timeLimit: 300,
      ),
      Quiz(
        id: 'pulseox_quiz',
        title: 'Pulse Oximetry Fundamentals',
        description: 'Test your knowledge of pulse oximetry and oxygen saturation.',
        category: 'PulseOx',
        difficulty: 'Easy',
        questions: [
          QuizQuestion(
            id: 'pulseox_q1',
            question: 'What is the normal range for oxygen saturation (SpO2)?',
            options: [
              '70-80%',
              '80-90%',
              '90-100%',
              '60-70%'
            ],
            correctAnswerIndex: 2,
            explanation: 'Normal oxygen saturation (SpO2) is between 95-100%. Values of 90-94% may indicate mild hypoxemia, while values below 90% indicate significant hypoxemia requiring intervention.',
            category: 'PulseOx',
            difficulty: 'Easy',
          ),
          QuizQuestion(
            id: 'pulseox_q2',
            question: 'Which of the following can cause an artificially low SpO2 reading?',
            options: [
              'Anemia',
              'Nail polish',
              'Supplemental oxygen',
              'Hyperventilation'
            ],
            correctAnswerIndex: 1,
            explanation: 'Nail polish (especially dark colors) can interfere with the light transmission of the pulse oximeter sensor, leading to artificially low SpO2 readings. Other factors that can cause inaccurate readings include poor peripheral circulation, cold extremities, and motion artifacts.',
            category: 'PulseOx',
            difficulty: 'Easy',
          ),
        ],
        timeLimit: 300,
      ),
    ];

    // Save default quizzes to Firebase
    for (var quiz in defaultQuizzes) {
      await _database
          .child('learningCenter')
          .child('quizzes')
          .child(quiz.id)
          .set(quiz.toMap());
    }

    return defaultQuizzes;
  }
}