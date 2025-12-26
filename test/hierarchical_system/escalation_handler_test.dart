import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sevasetu/hierarchical_system/models/enums.dart';
import 'package:sevasetu/hierarchical_system/services/escalation_handler.dart';

void main() {
  late EscalationHandler handler;

  setUp(() {
    handler = EscalationHandler();
  });

  group('EscalationHandler', () {
    // Feature: sevasetu-hierarchical-system, Property 9: Escalation Level Thresholds
    // Validates: Requirements 11.1, 11.2, 11.3
    group('Property 9: Escalation Level Thresholds', () {
      test('chaos >= 0.8 returns emergency level', () {
        expect(
          handler.getEscalationLevel(0.8),
          equals(EscalationLevel.emergency),
        );
        expect(
          handler.getEscalationLevel(0.9),
          equals(EscalationLevel.emergency),
        );
        expect(
          handler.getEscalationLevel(1.0),
          equals(EscalationLevel.emergency),
        );
      });

      test('0.6 <= chaos < 0.8 returns highPriority level', () {
        expect(
          handler.getEscalationLevel(0.6),
          equals(EscalationLevel.highPriority),
        );
        expect(
          handler.getEscalationLevel(0.7),
          equals(EscalationLevel.highPriority),
        );
        expect(
          handler.getEscalationLevel(0.79),
          equals(EscalationLevel.highPriority),
        );
      });

      test('0.4 <= chaos < 0.6 returns elevated level', () {
        expect(
          handler.getEscalationLevel(0.4),
          equals(EscalationLevel.elevated),
        );
        expect(
          handler.getEscalationLevel(0.5),
          equals(EscalationLevel.elevated),
        );
        expect(
          handler.getEscalationLevel(0.59),
          equals(EscalationLevel.elevated),
        );
      });

      test('chaos < 0.4 returns none level', () {
        expect(handler.getEscalationLevel(0.0), equals(EscalationLevel.none));
        expect(handler.getEscalationLevel(0.2), equals(EscalationLevel.none));
        expect(handler.getEscalationLevel(0.39), equals(EscalationLevel.none));
      });

      test('escalation levels are mutually exclusive', () {
        final random = Random(42);

        for (int i = 0; i < 100; i++) {
          final chaosScore = random.nextDouble();
          final level = handler.getEscalationLevel(chaosScore);

          // Verify exactly one level is returned
          expect(EscalationLevel.values.contains(level), isTrue);

          // Verify the level matches the threshold
          if (chaosScore >= 0.8) {
            expect(level, equals(EscalationLevel.emergency));
          } else if (chaosScore >= 0.6) {
            expect(level, equals(EscalationLevel.highPriority));
          } else if (chaosScore >= 0.4) {
            expect(level, equals(EscalationLevel.elevated));
          } else {
            expect(level, equals(EscalationLevel.none));
          }
        }
      });

      test('boundary values are handled correctly', () {
        // Test exact boundary values
        expect(
          handler.getEscalationLevel(0.4),
          equals(EscalationLevel.elevated),
        );
        expect(
          handler.getEscalationLevel(0.6),
          equals(EscalationLevel.highPriority),
        );
        expect(
          handler.getEscalationLevel(0.8),
          equals(EscalationLevel.emergency),
        );

        // Test just below boundaries
        expect(handler.getEscalationLevel(0.399), equals(EscalationLevel.none));
        expect(
          handler.getEscalationLevel(0.599),
          equals(EscalationLevel.elevated),
        );
        expect(
          handler.getEscalationLevel(0.799),
          equals(EscalationLevel.highPriority),
        );
      });
    });

    group('Priority Boost', () {
      test('emergency level gives 100 priority (override to max)', () {
        expect(
          handler.getPriorityBoost(EscalationLevel.emergency),
          equals(100),
        );
      });

      test('highPriority level gives 30 priority boost', () {
        expect(
          handler.getPriorityBoost(EscalationLevel.highPriority),
          equals(30),
        );
      });

      test('elevated level gives 20 priority boost', () {
        expect(handler.getPriorityBoost(EscalationLevel.elevated), equals(20));
      });

      test('none level gives 0 priority boost', () {
        expect(handler.getPriorityBoost(EscalationLevel.none), equals(0));
      });
    });

    group('Escalation Level Ordering', () {
      test('escalation levels have correct severity ordering', () {
        // Higher chaos should result in more severe escalation
        final levels = [
          handler.getEscalationLevel(0.1),
          handler.getEscalationLevel(0.5),
          handler.getEscalationLevel(0.7),
          handler.getEscalationLevel(0.9),
        ];

        expect(levels[0], equals(EscalationLevel.none));
        expect(levels[1], equals(EscalationLevel.elevated));
        expect(levels[2], equals(EscalationLevel.highPriority));
        expect(levels[3], equals(EscalationLevel.emergency));
      });
    });
  });
}
