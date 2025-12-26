import '../models/ai_analysis.dart';
import '../models/civic_issue.dart';
import '../models/enums.dart';
import 'chaos_detector.dart';

/// Calculates priority scores for civic issues using a multi-factor weighted algorithm.
class PriorityCalculator {
  final ChaosDetector _chaosDetector;

  PriorityCalculator({ChaosDetector? chaosDetector})
    : _chaosDetector = chaosDetector ?? ChaosDetector();

  /// Calculate comprehensive priority score (0-100) for an issue.
  ///
  /// Components:
  /// - Severity: 30% weight, max 30 points
  /// - Population Impact: 25% weight, max 25 points
  /// - Category Urgency: 15% weight, max 15 points
  /// - Community Support: 15% weight, max 15 points
  /// - Time Factor: 10% weight, max 10 points
  /// - AI Confidence Bonus: 5% weight, max 5 points
  int calculatePriorityScore(CivicIssue issue, AIAnalysis? aiAnalysis) {
    int totalScore = 0;

    // 1. SEVERITY COMPONENT (30% weight, max 30 points)
    if (aiAnalysis != null) {
      totalScore += calculateSeverityScore(aiAnalysis.severityLevel);
    } else {
      totalScore += getDefaultSeverityScore(issue.category);
    }

    // 2. POPULATION IMPACT COMPONENT (25% weight, max 25 points)
    if (aiAnalysis != null) {
      totalScore += calculatePopulationScore(aiAnalysis);
    } else {
      totalScore += 10; // Default medium impact
    }

    // 3. CATEGORY URGENCY COMPONENT (15% weight, max 15 points)
    totalScore += getCategoryUrgencyScore(issue.category);

    // 4. COMMUNITY SUPPORT COMPONENT (15% weight, max 15 points)
    totalScore += calculateCommunityScore(issue.upvotes);

    // 5. TIME FACTOR COMPONENT (10% weight, max 10 points)
    totalScore += calculateTimeScore(issue.createdAt);

    // 6. AI CONFIDENCE BONUS (5% weight, max 5 points)
    if (aiAnalysis != null && aiAnalysis.confidenceScore > 0.8) {
      totalScore += (aiAnalysis.confidenceScore * 5).toInt();
    }

    // 7. CHAOS/EMERGENCY MULTIPLIER
    if (aiAnalysis != null) {
      final chaosScore = _chaosDetector.calculateChaosScore(aiAnalysis);
      if (chaosScore >= 0.6) {
        totalScore = (totalScore * (1 + chaosScore * 0.5)).toInt();
      }
    }

    // Ensure score is within bounds
    return totalScore.clamp(0, 100);
  }

  /// Calculate severity score (max 30 points).
  ///
  /// - CRITICAL: 30 points
  /// - HIGH: 24 points
  /// - MEDIUM: 15 points
  /// - LOW: 8 points
  /// - Unknown: 10 points (default)
  int calculateSeverityScore(String severityLevel) {
    switch (severityLevel.toUpperCase()) {
      case 'CRITICAL':
        return 30;
      case 'HIGH':
        return 24;
      case 'MEDIUM':
        return 15;
      case 'LOW':
        return 8;
      default:
        return 10;
    }
  }

  /// Get default severity score based on category when AI analysis is unavailable.
  int getDefaultSeverityScore(String category) {
    switch (category.toUpperCase()) {
      case 'POWER_CUT':
      case 'SEWAGE_OVERFLOW':
        return 20; // Higher default for critical categories
      case 'WATER_LEAK':
      case 'POTHOLE':
        return 15;
      case 'DRAINAGE_PROBLEM':
      case 'STREETLIGHT':
        return 12;
      case 'GARBAGE':
        return 10;
      default:
        return 10;
    }
  }

  /// Calculate population impact score (max 25 points).
  ///
  /// Base scores:
  /// - CRITICAL (1000+ people): 25 points
  /// - HIGH (500-1000 people): 20 points
  /// - MEDIUM (100-500 people): 12 points
  /// - LOW (<100 people): 5 points
  int calculatePopulationScore(AIAnalysis analysis) {
    int baseScore;

    switch (analysis.populationImpact.toUpperCase()) {
      case 'CRITICAL':
        baseScore = 25;
        break;
      case 'HIGH':
        baseScore = 20;
        break;
      case 'MEDIUM':
        baseScore = 12;
        break;
      case 'LOW':
        baseScore = 5;
        break;
      default:
        baseScore = 8;
    }

    // Apply location multiplier based on hazard indicators
    double locationMultiplier = _getLocationMultiplier(analysis);

    return (baseScore * locationMultiplier).clamp(0, 25).toInt();
  }

  /// Get location-based multiplier from hazard indicators.
  double _getLocationMultiplier(AIAnalysis analysis) {
    // Check for location-related hazards that indicate high-traffic areas
    final hazards = analysis.hazardIndicators;

    // School/Hospital vicinity: 2.0x
    if (hazards.any((h) => h.contains('school') || h.contains('hospital'))) {
      return 2.0;
    }

    // Main road/Highway: 1.8x
    if (hazards.contains(HazardIndicator.trafficBlocked) ||
        hazards.contains(HazardIndicator.trafficRisk)) {
      return 1.8;
    }

    // Commercial zone indicators: 1.5x
    if (hazards.any((h) => h.contains('commercial') || h.contains('market'))) {
      return 1.5;
    }

    return 1.0;
  }

  /// Get category urgency score (max 15 points).
  ///
  /// Categories ranked by inherent urgency:
  /// - POWER_CUT: 15 points
  /// - WATER_LEAK, SEWAGE_OVERFLOW: 14 points
  /// - POTHOLE: 12 points
  /// - DRAINAGE_PROBLEM: 11 points
  /// - STREETLIGHT: 10 points
  /// - GARBAGE: 8 points
  /// - OTHER: 6 points
  int getCategoryUrgencyScore(String category) {
    switch (category.toUpperCase()) {
      case 'POWER_CUT':
        return 15;
      case 'WATER_LEAK':
      case 'SEWAGE_OVERFLOW':
        return 14;
      case 'POTHOLE':
        return 12;
      case 'DRAINAGE_PROBLEM':
        return 11;
      case 'STREETLIGHT':
        return 10;
      case 'GARBAGE':
        return 8;
      case 'OTHER':
      default:
        return 6;
    }
  }

  /// Calculate community support score (max 15 points).
  ///
  /// Uses logarithmic scaling to prevent gaming:
  /// - 0 or negative: 0 points
  /// - 1-5: equal to upvote count
  /// - 6-20: 5 + (upvotes - 5) * 0.5
  /// - 21-100: 12 + (upvotes - 20) * 0.1
  /// - >100: capped at 15 points
  int calculateCommunityScore(int upvotes) {
    if (upvotes <= 0) return 0;
    if (upvotes <= 5) return upvotes;
    if (upvotes <= 20) return 5 + ((upvotes - 5) * 0.5).toInt();
    if (upvotes <= 100) return 12 + ((upvotes - 20) * 0.1).toInt();
    return 15; // Cap at 15 points
  }

  /// Calculate time factor score (max 10 points).
  ///
  /// Age-based scoring:
  /// - <24 hours: 10 points (fresh)
  /// - 1-3 days: 8 points (recent)
  /// - 3-7 days: 6 points (week old)
  /// - 7-14 days: 7 points (getting stale - bump up)
  /// - 14-30 days: 8 points (overdue)
  /// - >30 days: 10 points (needs urgent attention)
  int calculateTimeScore(DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);

    if (age.inHours < 24) return 10; // Fresh report
    if (age.inDays < 3) return 8; // Recent
    if (age.inDays < 7) return 6; // Week old
    if (age.inDays < 14) return 7; // Getting stale - bump up
    if (age.inDays < 30) return 8; // Overdue - higher priority
    return 10; // Very old - needs attention
  }

  /// Get priority zone bonus points.
  ///
  /// Zone bonuses:
  /// - criticalInfrastructure: 20 points
  /// - educationalZone: 15 points
  /// - commercialHub: 12 points
  /// - residentialDense: 10 points
  /// - industrial: 8 points
  /// - residentialSparse: 5 points
  /// - rural: 3 points
  int getZonePriorityBonus(PriorityZone zone) {
    switch (zone) {
      case PriorityZone.criticalInfrastructure:
        return 20;
      case PriorityZone.educationalZone:
        return 15;
      case PriorityZone.commercialHub:
        return 12;
      case PriorityZone.residentialDense:
        return 10;
      case PriorityZone.industrial:
        return 8;
      case PriorityZone.residentialSparse:
        return 5;
      case PriorityZone.rural:
        return 3;
    }
  }

  /// Determine if an issue should be marked as high priority.
  ///
  /// High priority if:
  /// - Priority score > 70, OR
  /// - Severity is CRITICAL, OR
  /// - Chaos score >= 0.7
  bool isHighPriority(int priorityScore, AIAnalysis? aiAnalysis) {
    if (priorityScore > 70) return true;
    if (aiAnalysis?.severityLevel.toUpperCase() == 'CRITICAL') return true;
    if (aiAnalysis != null) {
      final chaosScore = _chaosDetector.calculateChaosScore(aiAnalysis);
      if (chaosScore >= 0.7) return true;
    }
    return false;
  }
}
