import '../models/ai_analysis.dart';
import '../models/civic_issue.dart';
import '../models/enums.dart';
import 'chaos_detector.dart';

/// Handles emergency escalation through the administrative hierarchy.
class EscalationHandler {
  final ChaosDetector _chaosDetector;

  EscalationHandler({ChaosDetector? chaosDetector})
    : _chaosDetector = chaosDetector ?? ChaosDetector();

  /// Determine escalation level based on chaos score.
  ///
  /// Thresholds:
  /// - chaos >= 0.8: emergency
  /// - 0.6 <= chaos < 0.8: highPriority
  /// - 0.4 <= chaos < 0.6: elevated
  /// - chaos < 0.4: none
  EscalationLevel getEscalationLevel(double chaosScore) {
    if (chaosScore >= 0.8) {
      return EscalationLevel.emergency;
    } else if (chaosScore >= 0.6) {
      return EscalationLevel.highPriority;
    } else if (chaosScore >= 0.4) {
      return EscalationLevel.elevated;
    } else {
      return EscalationLevel.none;
    }
  }

  /// Handle escalation based on AI analysis.
  ///
  /// Actions based on chaos score:
  /// - >= 0.8: Trigger emergency protocol
  /// - >= 0.6: Trigger high priority protocol
  /// - >= 0.4: Flag for supervisor review
  Future<EscalationResult> handleEscalation(
    CivicIssue issue,
    AIAnalysis analysis,
  ) async {
    final chaosScore = _chaosDetector.calculateChaosScore(analysis);
    final level = getEscalationLevel(chaosScore);

    switch (level) {
      case EscalationLevel.emergency:
        await triggerEmergencyProtocol(issue);
        return EscalationResult(
          level: level,
          chaosScore: chaosScore,
          priorityScore: 100, // Maximum priority
          actions: [
            'State admin notified',
            'Auto-assigned to nearest team',
            'Emergency services alerted',
          ],
        );

      case EscalationLevel.highPriority:
        await triggerHighPriorityProtocol(issue);
        return EscalationResult(
          level: level,
          chaosScore: chaosScore,
          priorityScore: 90,
          actions: [
            'District admin notified',
            'Fast-track assignment initiated',
          ],
        );

      case EscalationLevel.elevated:
        await flagForReview(issue);
        return EscalationResult(
          level: level,
          chaosScore: chaosScore,
          priorityScore: null, // Use calculated score + 20 bonus
          actions: ['Flagged for supervisor review', 'Priority boost applied'],
        );

      case EscalationLevel.none:
        return EscalationResult(
          level: level,
          chaosScore: chaosScore,
          priorityScore: null,
          actions: [],
        );
    }
  }

  /// Trigger emergency protocol for critical situations (chaos >= 0.8).
  ///
  /// Actions:
  /// - Immediate notification to State Admin
  /// - Auto-assign to nearest available team
  /// - Alert emergency services if needed
  /// - Set priority score to 100 (maximum)
  Future<void> triggerEmergencyProtocol(CivicIssue issue) async {
    // In a real implementation, this would:
    // 1. Send push notification to state admin
    // 2. Query for nearest available field team
    // 3. Auto-assign the issue
    // 4. Potentially alert emergency services (fire, ambulance)
    // 5. Update issue status to 'escalated'

    // For now, we just log the action
    print('EMERGENCY PROTOCOL TRIGGERED for issue ${issue.id}');
    print('- Notifying state admin');
    print('- Auto-assigning to nearest team');
    print('- Priority set to 100');
  }

  /// Trigger high priority protocol (chaos >= 0.6).
  ///
  /// Actions:
  /// - Notify District Admin immediately
  /// - Fast-track assignment
  /// - Priority score = 90+
  Future<void> triggerHighPriorityProtocol(CivicIssue issue) async {
    // In a real implementation, this would:
    // 1. Send push notification to district admin
    // 2. Move issue to front of assignment queue
    // 3. Update priority score to 90+

    print('HIGH PRIORITY PROTOCOL TRIGGERED for issue ${issue.id}');
    print('- Notifying district admin');
    print('- Fast-tracking assignment');
  }

  /// Flag issue for supervisor review (chaos >= 0.4).
  ///
  /// Actions:
  /// - Flag for supervisor review
  /// - Priority score boost +20
  Future<void> flagForReview(CivicIssue issue) async {
    // In a real implementation, this would:
    // 1. Add issue to supervisor review queue
    // 2. Apply +20 priority boost

    print('FLAGGED FOR REVIEW: issue ${issue.id}');
    print('- Added to supervisor review queue');
    print('- Priority boost +20 applied');
  }

  /// Calculate the priority boost based on escalation level.
  int getPriorityBoost(EscalationLevel level) {
    switch (level) {
      case EscalationLevel.emergency:
        return 100; // Override to max
      case EscalationLevel.highPriority:
        return 30;
      case EscalationLevel.elevated:
        return 20;
      case EscalationLevel.none:
        return 0;
    }
  }
}

/// Result of an escalation action.
class EscalationResult {
  final EscalationLevel level;
  final double chaosScore;
  final int? priorityScore;
  final List<String> actions;

  const EscalationResult({
    required this.level,
    required this.chaosScore,
    this.priorityScore,
    required this.actions,
  });

  @override
  String toString() {
    return 'EscalationResult(level: $level, chaos: ${chaosScore.toStringAsFixed(2)}, '
        'priority: $priorityScore, actions: $actions)';
  }
}
