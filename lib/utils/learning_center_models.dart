
class LearningTopic {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final List<LearningResource> resources;

  LearningTopic({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.resources = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'resources': resources.map((resource) => resource.toMap()).toList(),
    };
  }

  factory LearningTopic.fromMap(Map<dynamic, dynamic> map) {
    List<LearningResource> parseResources() {
      var resourcesData = map['resources'];
      if (resourcesData == null) return [];
      
      if (resourcesData is List) {
        return resourcesData
            .map((x) => LearningResource.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      } else if (resourcesData is Map) {
        return resourcesData.values
            .map((x) => LearningResource.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    }

    return LearningTopic(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      resources: parseResources(),
    );
  }
}

class LearningResource {
  final String id;
  final String title;
  final String content;
  final String type; // 'text', 'audio', 'video', etc.
  final String? fileUrl;
  final List<String> tags;

  LearningResource({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.fileUrl,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'fileUrl': fileUrl,
      'tags': tags,
    };
  }

  factory LearningResource.fromMap(Map<dynamic, dynamic> map) {
    List<String> parseTags() {
      var tagsData = map['tags'];
      if (tagsData == null) return [];
      
      if (tagsData is List) {
        return tagsData.map((tag) => tag.toString()).toList();
      }
      return [];
    }

    return LearningResource(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      fileUrl: map['fileUrl'],
      tags: parseTags(),
    );
  }
}

class HeartMurmur {
  final String id;
  final String name;
  final String description;
  final String position;  // Where to auscultate
  final String timing;    // Systolic, diastolic, continuous
  final String quality;   // Harsh, blowing, musical, etc.
  final String grade;     // I-VI for intensity
  final String audioUrl;
  final List<String> clinicalImplications;
  final String? imageUrl; // Diagram showing murmur location

  HeartMurmur({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.timing,
    required this.quality,
    required this.grade,
    required this.audioUrl,
    required this.clinicalImplications,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'position': position,
      'timing': timing,
      'quality': quality,
      'grade': grade,
      'audioUrl': audioUrl,
      'clinicalImplications': clinicalImplications,
      'imageUrl': imageUrl,
    };
  }

  factory HeartMurmur.fromMap(Map<dynamic, dynamic> map) {
    List<String> parseImplications() {
      var implicationsData = map['clinicalImplications'];
      if (implicationsData == null) return [];
      
      if (implicationsData is List) {
        return implicationsData.map((implication) => implication.toString()).toList();
      }
      return [];
    }

    return HeartMurmur(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      position: map['position'] ?? '',
      timing: map['timing'] ?? '',
      quality: map['quality'] ?? '',
      grade: map['grade'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      clinicalImplications: parseImplications(),
      imageUrl: map['imageUrl'],
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String? imageUrl;
  final String category; // ECG, PulseOx, Heart Murmurs, etc.
  final String difficulty; // Easy, Medium, Hard

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.imageUrl,
    required this.category,
    required this.difficulty,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'imageUrl': imageUrl,
      'category': category,
      'difficulty': difficulty,
    };
  }

  factory QuizQuestion.fromMap(Map<dynamic, dynamic> map) {
    List<String> parseOptions() {
      var optionsData = map['options'];
      if (optionsData == null) return [];
      
      if (optionsData is List) {
        return optionsData.map((option) => option.toString()).toList();
      }
      return [];
    }

    return QuizQuestion(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: parseOptions(),
      correctAnswerIndex: map['correctAnswerIndex'] ?? 0,
      explanation: map['explanation'] ?? '',
      imageUrl: map['imageUrl'],
      category: map['category'] ?? '',
      difficulty: map['difficulty'] ?? 'Medium',
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final List<QuizQuestion> questions;
  final int timeLimit; // in seconds, 0 for no limit

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.questions,
    this.timeLimit = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'questions': questions.map((question) => question.toMap()).toList(),
      'timeLimit': timeLimit,
    };
  }

  factory Quiz.fromMap(Map<dynamic, dynamic> map) {
    List<QuizQuestion> parseQuestions() {
      var questionsData = map['questions'];
      if (questionsData == null) return [];
      
      if (questionsData is List) {
        return questionsData
            .map((x) => QuizQuestion.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      } else if (questionsData is Map) {
        return questionsData.values
            .map((x) => QuizQuestion.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    }

    return Quiz(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      difficulty: map['difficulty'] ?? 'Medium',
      questions: parseQuestions(),
      timeLimit: map['timeLimit'] ?? 0,
    );
  }
}

class QuizResult {
  final String id;
  final String quizId;
  final String userId;
  final DateTime timestamp;
  final int correctAnswers;
  final int totalQuestions;
  final double score; // Percentage
  final Duration timeTaken;
  final Map<String, bool> questionResults; // QuestionId -> isCorrect

  QuizResult({
    required this.id,
    required this.quizId,
    required this.userId,
    required this.timestamp,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.score,
    required this.timeTaken,
    required this.questionResults,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'score': score,
      'timeTakenSeconds': timeTaken.inSeconds,
      'questionResults': questionResults,
    };
  }

  factory QuizResult.fromMap(Map<dynamic, dynamic> map) {
    Map<String, bool> parseQuestionResults() {
      var resultsData = map['questionResults'];
      if (resultsData == null) return {};
      
      Map<String, bool> questionResults = {};
      (resultsData as Map).forEach((key, value) {
        questionResults[key.toString()] = value as bool;
      });
      return questionResults;
    }

    return QuizResult(
      id: map['id'] ?? '',
      quizId: map['quizId'] ?? '',
      userId: map['userId'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      correctAnswers: map['correctAnswers'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      score: (map['score'] ?? 0).toDouble(),
      timeTaken: Duration(seconds: map['timeTakenSeconds'] ?? 0),
      questionResults: parseQuestionResults(),
    );
  }
}

class UserProgress {
  final String userId;
  final List<String> completedTopics;
  final List<QuizResult> quizResults;
  final Map<String, DateTime> lastAccessedTopics;

  UserProgress({
    required this.userId,
    this.completedTopics = const [],
    this.quizResults = const [],
    this.lastAccessedTopics = const {},
  });

  Map<String, dynamic> toMap() {
    Map<String, String> lastAccessedMap = {};
    lastAccessedTopics.forEach((key, value) {
      lastAccessedMap[key] = value.toIso8601String();
    });

    return {
      'userId': userId,
      'completedTopics': completedTopics,
      'quizResults': quizResults.map((result) => result.toMap()).toList(),
      'lastAccessedTopics': lastAccessedMap,
    };
  }

  factory UserProgress.fromMap(Map<dynamic, dynamic> map) {
    List<String> parseCompletedTopics() {
      var topicsData = map['completedTopics'];
      if (topicsData == null) return [];
      
      if (topicsData is List) {
        return topicsData.map((topic) => topic.toString()).toList();
      }
      return [];
    }

    List<QuizResult> parseQuizResults() {
      var resultsData = map['quizResults'];
      if (resultsData == null) return [];
      
      if (resultsData is List) {
        return resultsData
            .map((x) => QuizResult.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      } else if (resultsData is Map) {
        return resultsData.values
            .map((x) => QuizResult.fromMap(x as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    }

    Map<String, DateTime> parseLastAccessedTopics() {
      var lastAccessedData = map['lastAccessedTopics'];
      if (lastAccessedData == null) return {};
      
      Map<String, DateTime> lastAccessedMap = {};
      (lastAccessedData as Map).forEach((key, value) {
        lastAccessedMap[key.toString()] = DateTime.parse(value);
      });
      return lastAccessedMap;
    }

    return UserProgress(
      userId: map['userId'] ?? '',
      completedTopics: parseCompletedTopics(),
      quizResults: parseQuizResults(),
      lastAccessedTopics: parseLastAccessedTopics(),
    );
  }
}