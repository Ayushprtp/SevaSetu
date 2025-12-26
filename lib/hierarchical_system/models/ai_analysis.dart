/// AI Analysis result from image analysis service.
/// Contains detected category, severity, population impact, and hazard indicators.
class AIAnalysis {
  final String detectedCategory;
  final double confidenceScore;
  final String severityLevel;
  final double affectedAreaSqm;
  final String populationImpact;
  final List<String> hazardIndicators;
  final int recommendedPriority;
  final String analysisNotes;
  final DateTime analyzedAt;

  AIAnalysis({
    required this.detectedCategory,
    required this.confidenceScore,
    required this.severityLevel,
    required this.affectedAreaSqm,
    required this.populationImpact,
    required this.hazardIndicators,
    required this.recommendedPriority,
    required this.analysisNotes,
    required this.analyzedAt,
  });

  /// Creates an AIAnalysis from JSON map.
  factory AIAnalysis.fromJson(Map<String, dynamic> json) {
    return AIAnalysis(
      detectedCategory: json['detected_category'] as String,
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      severityLevel: json['severity_level'] as String,
      affectedAreaSqm: (json['affected_area_sqm'] as num).toDouble(),
      populationImpact: json['population_impact'] as String,
      hazardIndicators: List<String>.from(json['hazard_indicators'] ?? []),
      recommendedPriority: json['recommended_priority'] as int,
      analysisNotes: json['analysis_notes'] as String? ?? '',
      analyzedAt: DateTime.parse(json['analyzed_at'] as String),
    );
  }

  /// Converts AIAnalysis to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'detected_category': detectedCategory,
      'confidence_score': confidenceScore,
      'severity_level': severityLevel,
      'affected_area_sqm': affectedAreaSqm,
      'population_impact': populationImpact,
      'hazard_indicators': hazardIndicators,
      'recommended_priority': recommendedPriority,
      'analysis_notes': analysisNotes,
      'analyzed_at': analyzedAt.toIso8601String(),
    };
  }

  /// Creates a copy with optional field overrides.
  AIAnalysis copyWith({
    String? detectedCategory,
    double? confidenceScore,
    String? severityLevel,
    double? affectedAreaSqm,
    String? populationImpact,
    List<String>? hazardIndicators,
    int? recommendedPriority,
    String? analysisNotes,
    DateTime? analyzedAt,
  }) {
    return AIAnalysis(
      detectedCategory: detectedCategory ?? this.detectedCategory,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      severityLevel: severityLevel ?? this.severityLevel,
      affectedAreaSqm: affectedAreaSqm ?? this.affectedAreaSqm,
      populationImpact: populationImpact ?? this.populationImpact,
      hazardIndicators: hazardIndicators ?? this.hazardIndicators,
      recommendedPriority: recommendedPriority ?? this.recommendedPriority,
      analysisNotes: analysisNotes ?? this.analysisNotes,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AIAnalysis) return false;
    return detectedCategory == other.detectedCategory &&
        confidenceScore == other.confidenceScore &&
        severityLevel == other.severityLevel &&
        affectedAreaSqm == other.affectedAreaSqm &&
        populationImpact == other.populationImpact &&
        _listEquals(hazardIndicators, other.hazardIndicators) &&
        recommendedPriority == other.recommendedPriority &&
        analysisNotes == other.analysisNotes &&
        analyzedAt == other.analyzedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      detectedCategory,
      confidenceScore,
      severityLevel,
      affectedAreaSqm,
      populationImpact,
      Object.hashAll(hazardIndicators),
      recommendedPriority,
      analysisNotes,
      analyzedAt,
    );
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'AIAnalysis(category: $detectedCategory, severity: $severityLevel, '
        'confidence: $confidenceScore, population: $populationImpact)';
  }
}
