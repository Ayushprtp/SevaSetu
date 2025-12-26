# Implementation Plan: SevaSetu Hierarchical System

## Overview

This implementation plan breaks down the SevaSetu Hierarchical System into discrete coding tasks. The system will be implemented in Dart/Flutter, following the existing project structure. Tasks are organized to build incrementally, with core data models first, then business logic components, and finally integration.

## Tasks

- [x] 1. Set up project structure and core data models
  - [x] 1.1 Create data models directory and base files
    - Create `lib/hierarchical_system/` directory structure
    - Create `models/`, `services/`, `utils/` subdirectories
    - _Requirements: 14.1-14.9_

  - [x] 1.2 Implement AIAnalysis data model
    - Create `lib/hierarchical_system/models/ai_analysis.dart`
    - Implement all fields: detectedCategory, confidenceScore, severityLevel, affectedAreaSqm, populationImpact, hazardIndicators, recommendedPriority, analysisNotes, analyzedAt
    - Implement fromJson and toJson methods
    - _Requirements: 14.1-14.10_

  - [x] 1.3 Write property test for AIAnalysis JSON round-trip
    - **Property 14: AIAnalysis JSON Round-Trip**
    - **Validates: Requirements 14.10**

  - [x] 1.4 Implement CivicIssue data model
    - Create `lib/hierarchical_system/models/civic_issue.dart`
    - Implement all fields: id, category, description, imageUrl, location, district, state, upvotes, createdAt, status, aiAnalysis, priorityScore, isHighPriority
    - Implement IssueStatus enum
    - _Requirements: 4.1_

  - [x] 1.5 Implement GeoPoint and Office data models
    - Create `lib/hierarchical_system/models/geo_point.dart` with distanceTo method using Haversine formula
    - Create `lib/hierarchical_system/models/office.dart`
    - _Requirements: 3.2_

  - [x] 1.6 Implement enums and constants
    - Create `lib/hierarchical_system/models/enums.dart`
    - Implement Department enum (PWD, SANITATION, ELECTRICITY, WATER, GENERAL)
    - Implement PriorityZone enum
    - Implement EscalationLevel enum
    - _Requirements: 2.1-2.6, 12.1-12.7_

- [x] 2. Checkpoint - Ensure data models compile correctly
  - Ensure all data models compile without errors, ask the user if questions arise.

- [x] 3. Implement DepartmentRouter
  - [x] 3.1 Create DepartmentRouter service
    - Create `lib/hierarchical_system/services/department_router.dart`
    - Implement mapCategoryToDepartment method with all category mappings
    - Implement getCategoriesForDepartment method
    - _Requirements: 2.1-2.6_

  - [x] 3.2 Write property test for department routing
    - **Property 2: Department Routing Totality and Determinism**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**

- [x] 4. Implement PriorityCalculator - Scoring Components
  - [x] 4.1 Create PriorityCalculator service with severity scoring
    - Create `lib/hierarchical_system/services/priority_calculator.dart`
    - Implement calculateSeverityScore method
    - _Requirements: 5.1-5.5_

  - [x] 4.2 Write property test for severity score determinism
    - **Property 3: Severity Score Determinism**
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5**

  - [x] 4.3 Implement population impact scoring
    - Implement calculatePopulationScore method with base scores
    - Implement location multiplier logic
    - Implement clamping to max 25 points
    - _Requirements: 6.1-6.8_

  - [x] 4.4 Write property test for population score bounds
    - **Property 4: Population Score Bounds**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.8**

  - [x] 4.5 Implement category urgency scoring
    - Implement getCategoryUrgencyScore method
    - _Requirements: 7.1-7.7_

  - [x] 4.6 Write property test for category urgency determinism
    - **Property 5: Category Urgency Score Determinism**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7**

  - [x] 4.7 Implement community support scoring
    - Implement calculateCommunityScore method with logarithmic scaling
    - Implement cap at 15 points
    - _Requirements: 8.1-8.5_

  - [x] 4.8 Write property test for community score scaling
    - **Property 6: Community Score Logarithmic Scaling with Cap**
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

  - [x] 4.9 Implement time factor scoring
    - Implement calculateTimeScore method with age-based rules
    - _Requirements: 9.1-9.6_

  - [x] 4.10 Write property test for time score rules
    - **Property 7: Time Score Age-Based Rules**
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5, 9.6**

- [x] 5. Checkpoint - Ensure scoring components work correctly
  - Ensure all scoring methods compile and pass tests, ask the user if questions arise.

- [x] 6. Implement PriorityCalculator - Main Calculation
  - [x] 6.1 Implement priority zone bonus
    - Implement getZonePriorityBonus method
    - _Requirements: 12.1-12.7_

  - [x] 6.2 Write property test for zone bonus determinism
    - **Property 10: Priority Zone Bonus Determinism**
    - **Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7**

  - [x] 6.3 Implement main calculatePriorityScore method
    - Combine all scoring components with weights
    - Implement AI confidence bonus
    - Implement score clamping to [0, 100]
    - _Requirements: 4.1-4.8_

  - [x] 6.4 Write property test for priority score bounds
    - **Property 1: Priority Score Bounds**
    - **Validates: Requirements 4.1, 4.8**

  - [x] 6.5 Write property test for component score bounds
    - **Property 15: Component Score Bounds**
    - **Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6, 4.7**

  - [x] 6.6 Implement isHighPriority method
    - Check priority score > 70
    - Check severity == CRITICAL
    - Check chaos score >= 0.7
    - _Requirements: 13.1-13.3_

  - [x] 6.7 Write property test for high priority determination
    - **Property 11: High Priority Determination**
    - **Validates: Requirements 13.1, 13.2, 13.3**

- [x] 7. Implement ChaosDetector
  - [x] 7.1 Create ChaosDetector service
    - Create `lib/hierarchical_system/services/chaos_detector.dart`
    - Implement calculateChaosScore method with all hazard indicators
    - Implement score clamping to [0.0, 1.0]
    - _Requirements: 10.1-10.11_

  - [x] 7.2 Write property test for chaos score bounds
    - **Property 8: Chaos Score Bounds**
    - **Validates: Requirements 10.1, 10.11**

- [x] 8. Implement EscalationHandler
  - [x] 8.1 Create EscalationHandler service
    - Create `lib/hierarchical_system/services/escalation_handler.dart`
    - Implement getEscalationLevel method with threshold logic
    - Implement triggerEmergencyProtocol, triggerHighPriorityProtocol, flagForReview methods
    - _Requirements: 11.1-11.5_

  - [x] 8.2 Write property test for escalation thresholds
    - **Property 9: Escalation Level Thresholds**
    - **Validates: Requirements 11.1, 11.2, 11.3**

- [x] 9. Checkpoint - Ensure priority and escalation logic works
  - Ensure PriorityCalculator, ChaosDetector, and EscalationHandler compile and pass tests, ask the user if questions arise.

- [x] 10. Implement OfficeAssigner
  - [x] 10.1 Create OfficeAssigner service
    - Create `lib/hierarchical_system/services/office_assigner.dart`
    - Implement selectByDistance method using GeoPoint.distanceTo
    - Implement findOffices and findStateOffices methods (with Supabase integration)
    - _Requirements: 3.1-3.5_

  - [x] 10.2 Write property test for nearest office selection
    - **Property 12: Nearest Office Selection**
    - **Validates: Requirements 3.2**

  - [x] 10.3 Implement assignIssue method
    - Implement district office lookup
    - Implement state-level escalation when no district offices
    - Return AssignmentResult with escalation status
    - _Requirements: 3.1-3.5_

  - [x] 10.4 Write property test for escalated assignment marking
    - **Property 13: Escalated Assignment Marking**
    - **Validates: Requirements 3.4**

- [x] 11. Implement AIAnalysisService
  - [x] 11.1 Create AIAnalysisService interface and implementation
    - Create `lib/hierarchical_system/services/ai_analysis_service.dart`
    - Define abstract AIAnalysisService interface
    - Implement GeminiAIAnalysisService with API integration
    - Implement prompt engineering for civic issue analysis
    - _Requirements: 1.1-1.5_

  - [x] 11.2 Implement fallback for AI analysis failures
    - Implement createDefaultAnalysis method
    - Handle API errors gracefully
    - _Requirements: 1.6_

- [x] 12. Checkpoint - Ensure all services compile and integrate
  - Ensure all services compile without errors and can be instantiated, ask the user if questions arise.

- [x] 13. Integration and wiring
  - [x] 13.1 Create HierarchicalSystemService facade
    - Create `lib/hierarchical_system/hierarchical_system_service.dart`
    - Wire all components together
    - Implement processNewIssue method that orchestrates the full flow
    - _Requirements: All_

  - [x] 13.2 Create barrel export file
    - Create `lib/hierarchical_system/hierarchical_system.dart`
    - Export all public classes and enums
    - _Requirements: All_

  - [x] 13.3 Write integration tests
    - Test full issue processing flow
    - Test emergency escalation flow
    - Test normal assignment flow
    - _Requirements: All_

- [x] 14. Final checkpoint - Ensure all tests pass
  - All 107 tests pass successfully. Implementation complete.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- The implementation uses Dart/Flutter following the existing project structure
- Supabase is used for database operations (offices, issues)
- Google Gemini Vision API is used for AI image analysis
