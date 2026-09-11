class PhotoQualityResult {
  final double overallScore;
  final PhotoQualityScores scores;
  final bool isGoodEnough;
  final PhotoQualityFeedback feedback;
  final List<String> suggestions;

  PhotoQualityResult({
    required this.overallScore,
    required this.scores,
    required this.isGoodEnough,
    required this.feedback,
    required this.suggestions,
  });

  factory PhotoQualityResult.fromMap(Map<String, dynamic> map) {
    return PhotoQualityResult(
      overallScore: (map['overallScore'] as num).toDouble(),
      scores: PhotoQualityScores.fromMap(map['scores'] as Map<String, dynamic>),
      isGoodEnough: map['isGoodEnough'] as bool,
      feedback: PhotoQualityFeedback.fromMap(
        map['feedback'] as Map<String, dynamic>,
      ),
      suggestions: List<String>.from(map['suggestions'] as List),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'scores': scores.toMap(),
      'isGoodEnough': isGoodEnough,
      'feedback': feedback.toMap(),
      'suggestions': suggestions,
    };
  }

  QualityLevel get qualityLevel {
    if (overallScore >= 8.0) return QualityLevel.excellent;
    if (overallScore >= 6.0) return QualityLevel.good;
    return QualityLevel.needsImprovement;
  }

  String get qualityText {
    if (overallScore >= 9.0) return 'מצוין!';
    if (overallScore >= 8.0) return 'טוב מאוד';
    if (overallScore >= 7.0) return 'טוב';
    if (overallScore >= 6.0) return 'סביר';
    if (overallScore >= 4.0) return 'צריך שיפור';
    return 'לא מספיק טוב';
  }
}

class PhotoQualityScores {
  final int lighting;
  final int sharpness;
  final int angle;
  final int background;
  final int presentation;

  PhotoQualityScores({
    required this.lighting,
    required this.sharpness,
    required this.angle,
    required this.background,
    required this.presentation,
  });

  factory PhotoQualityScores.fromMap(Map<String, dynamic> map) {
    return PhotoQualityScores(
      lighting: map['lighting'] as int,
      sharpness: map['sharpness'] as int,
      angle: map['angle'] as int,
      background: map['background'] as int,
      presentation: map['presentation'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lighting': lighting,
      'sharpness': sharpness,
      'angle': angle,
      'background': background,
      'presentation': presentation,
    };
  }

  List<ScoreItem> toList() {
    return [
      ScoreItem(label: 'תאורה', score: lighting, icon: '💡'),
      ScoreItem(label: 'חדות', score: sharpness, icon: '🎯'),
      ScoreItem(label: 'זווית', score: angle, icon: '📐'),
      ScoreItem(label: 'רקע', score: background, icon: '🖼️'),
      ScoreItem(label: 'הצגה', score: presentation, icon: '✨'),
    ];
  }
}

class ScoreItem {
  final String label;
  final int score;
  final String icon;

  ScoreItem({required this.label, required this.score, required this.icon});
}

class PhotoQualityFeedback {
  final String lighting;
  final String sharpness;
  final String angle;
  final String background;
  final String presentation;

  PhotoQualityFeedback({
    required this.lighting,
    required this.sharpness,
    required this.angle,
    required this.background,
    required this.presentation,
  });

  factory PhotoQualityFeedback.fromMap(Map<String, dynamic> map) {
    return PhotoQualityFeedback(
      lighting: map['lighting'] as String,
      sharpness: map['sharpness'] as String,
      angle: map['angle'] as String,
      background: map['background'] as String,
      presentation: map['presentation'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lighting': lighting,
      'sharpness': sharpness,
      'angle': angle,
      'background': background,
      'presentation': presentation,
    };
  }

  String getForAspect(String aspect) {
    switch (aspect) {
      case 'lighting':
        return lighting;
      case 'sharpness':
        return sharpness;
      case 'angle':
        return angle;
      case 'background':
        return background;
      case 'presentation':
        return presentation;
      default:
        return '';
    }
  }
}

enum QualityLevel { excellent, good, needsImprovement }
