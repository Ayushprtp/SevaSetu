import '../models/ai_analysis.dart';
import '../models/enums.dart';

/// Detects emergency and chaos situations from AI analysis.
class ChaosDetector {
  /// Calculate chaos score (0.0 to 1.0) based on AI analysis.
  ///
  /// Factors contributing to chaos score:
  /// - Multiple hazards: +0.1 per hazard
  /// - CRITICAL severity: +0.3
  /// - HIGH severity: +0.2
  /// - CRITICAL population impact: +0.25
  /// - HIGH population impact: +0.15
  /// - Specific hazards: flooding (+0.15), traffic_blocked (+0.1),
  ///   structural_damage (+0.2), fire_hazard (+0.3)
  double calculateChaosScore(AIAnalysis analysis) {
    double score = 0.0;

    // Multiple hazards compound the chaos
    score += analysis.hazardIndicators.length * 0.1;

    // Severity amplifies chaos
    switch (analysis.severityLevel.toUpperCase()) {
      case 'CRITICAL':
        score += 0.3;
        break;
      case 'HIGH':
        score += 0.2;
        break;
    }

    // Population impact amplifies chaos
    switch (analysis.populationImpact.toUpperCase()) {
      case 'CRITICAL':
        score += 0.25;
        break;
      case 'HIGH':
        score += 0.15;
        break;
    }

    // Specific hazard indicators
    final hazards = analysis.hazardIndicators;

    if (hazards.contains(HazardIndicator.flooding)) {
      score += 0.15;
    }
    if (hazards.contains(HazardIndicator.trafficBlocked)) {
      score += 0.1;
    }
    if (hazards.contains(HazardIndicator.structuralDamage)) {
      score += 0.2;
    }
    if (hazards.contains(HazardIndicator.fireHazard)) {
      score += 0.3;
    }

    // Clamp to valid range
    return score.clamp(0.0, 1.0);
  }

  /// Check if a specific hazard is present in the analysis.
  bool hasHazard(AIAnalysis analysis, String hazardType) {
    return analysis.hazardIndicators.contains(hazardType);
  }

  /// Get all detected hazards from the analysis.
  List<String> getDetectedHazards(AIAnalysis analysis) {
    return List.unmodifiable(analysis.hazardIndicators);
  }

  /// Check if the situation qualifies as an emergency (chaos >= 0.8).
  bool isEmergency(AIAnalysis analysis) {
    return calculateChaosScore(analysis) >= 0.8;
  }

  /// Check if the situation is high priority (chaos >= 0.6).
  bool isHighPrioritySituation(AIAnalysis analysis) {
    return calculateChaosScore(analysis) >= 0.6;
  }

  /// Check if the situation needs elevated attention (chaos >= 0.4).
  bool needsElevatedAttention(AIAnalysis analysis) {
    return calculateChaosScore(analysis) >= 0.4;
  }
}
