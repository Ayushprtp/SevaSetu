# Requirements Document

## Introduction

SevaSetu implements a multi-tier hierarchical system for civic issue management that combines administrative hierarchy, AI-powered image analysis, and intelligent prioritization to ensure efficient issue resolution. The system enables citizens to report civic issues which are automatically categorized, prioritized, and routed to the appropriate government department and office for resolution.

## Glossary

- **Civic_Issue**: A reported problem in public infrastructure (pothole, garbage, streetlight, etc.)
- **AI_Analysis_Service**: The service that analyzes uploaded images using multi-modal AI (Gemini/GPT-4V)
- **Priority_Calculator**: The component that computes priority scores (0-100) for issues
- **Department_Router**: The component that maps issue categories to government departments
- **Office_Assigner**: The component that assigns issues to the nearest appropriate office
- **Chaos_Detector**: The component that identifies emergency/chaos situations from AI analysis
- **Escalation_Handler**: The component that manages issue escalation through the hierarchy
- **Severity_Level**: Classification of issue danger (LOW, MEDIUM, HIGH, CRITICAL)
- **Population_Impact**: Estimated number of people affected (LOW, MEDIUM, HIGH, CRITICAL)
- **Priority_Zone**: Geographic classification affecting priority (criticalInfrastructure, educationalZone, etc.)

## Requirements

### Requirement 1: AI-Powered Image Analysis

**User Story:** As a citizen, I want the system to automatically analyze my uploaded issue images, so that the issue is correctly categorized and assessed without manual intervention.

#### Acceptance Criteria

1. WHEN a citizen uploads an image of a civic issue, THE AI_Analysis_Service SHALL analyze the image and return a detected category from: POTHOLE, GARBAGE, STREETLIGHT, WATER_LEAK, SEWAGE_OVERFLOW, DRAINAGE_PROBLEM, POWER_CUT, OTHER
2. WHEN the AI_Analysis_Service analyzes an image, THE AI_Analysis_Service SHALL return a confidence score between 0.0 and 1.0
3. WHEN the AI_Analysis_Service analyzes an image, THE AI_Analysis_Service SHALL assess severity as one of: LOW, MEDIUM, HIGH, CRITICAL
4. WHEN the AI_Analysis_Service analyzes an image, THE AI_Analysis_Service SHALL estimate population impact as one of: LOW, MEDIUM, HIGH, CRITICAL
5. WHEN the AI_Analysis_Service analyzes an image, THE AI_Analysis_Service SHALL identify hazard indicators from the visual context
6. IF the AI_Analysis_Service fails to analyze an image, THEN THE system SHALL allow manual category selection and use default severity assessment

### Requirement 2: Department Routing

**User Story:** As a system administrator, I want issues to be automatically routed to the correct department, so that the right team handles each type of problem.

#### Acceptance Criteria

1. WHEN an issue has category POTHOLE or DRAINAGE_PROBLEM, THE Department_Router SHALL route it to PWD (Public Works Department)
2. WHEN an issue has category GARBAGE or SEWAGE_OVERFLOW, THE Department_Router SHALL route it to SANITATION department
3. WHEN an issue has category STREETLIGHT or POWER_CUT, THE Department_Router SHALL route it to ELECTRICITY department
4. WHEN an issue has category WATER_LEAK, THE Department_Router SHALL route it to WATER department
5. WHEN an issue has category OTHER, THE Department_Router SHALL route it to GENERAL department
6. THE Department_Router SHALL map every valid issue category to exactly one department

### Requirement 3: Office Assignment

**User Story:** As a district administrator, I want issues to be assigned to the nearest appropriate office, so that response times are minimized.

#### Acceptance Criteria

1. WHEN an issue is routed to a department, THE Office_Assigner SHALL find all offices of that department in the issue's district
2. WHEN district offices exist for the department, THE Office_Assigner SHALL select the office nearest to the issue location
3. IF no district offices exist for the department, THEN THE Office_Assigner SHALL escalate to state-level offices and select the nearest one
4. WHEN an issue is escalated to state level, THE Office_Assigner SHALL mark the assignment as escalated
5. THE Office_Assigner SHALL always return an assignment result with an office and escalation status

### Requirement 4: Priority Score Calculation

**User Story:** As a government official, I want issues to be prioritized based on multiple factors, so that the most critical issues are addressed first.

#### Acceptance Criteria

1. THE Priority_Calculator SHALL calculate a priority score between 0 and 100 for each issue
2. WHEN calculating priority, THE Priority_Calculator SHALL weight severity at 30% (max 30 points)
3. WHEN calculating priority, THE Priority_Calculator SHALL weight population impact at 25% (max 25 points)
4. WHEN calculating priority, THE Priority_Calculator SHALL weight category urgency at 15% (max 15 points)
5. WHEN calculating priority, THE Priority_Calculator SHALL weight community support (upvotes) at 15% (max 15 points)
6. WHEN calculating priority, THE Priority_Calculator SHALL weight time factor at 10% (max 10 points)
7. WHEN AI analysis has confidence > 0.8, THE Priority_Calculator SHALL add an AI confidence bonus up to 5 points
8. THE Priority_Calculator SHALL clamp the final score to the range 0-100

### Requirement 5: Severity Scoring

**User Story:** As a priority system, I want to score severity consistently, so that dangerous issues receive appropriate urgency.

#### Acceptance Criteria

1. WHEN severity is CRITICAL, THE Priority_Calculator SHALL assign 30 severity points
2. WHEN severity is HIGH, THE Priority_Calculator SHALL assign 24 severity points
3. WHEN severity is MEDIUM, THE Priority_Calculator SHALL assign 15 severity points
4. WHEN severity is LOW, THE Priority_Calculator SHALL assign 8 severity points
5. WHEN severity is unknown, THE Priority_Calculator SHALL assign 10 severity points as default

### Requirement 6: Population Impact Scoring

**User Story:** As a priority system, I want to score population impact based on how many people are affected, so that issues affecting more people get higher priority.

#### Acceptance Criteria

1. WHEN population impact is CRITICAL (1000+ people), THE Priority_Calculator SHALL assign base score of 25 points
2. WHEN population impact is HIGH (500-1000 people), THE Priority_Calculator SHALL assign base score of 20 points
3. WHEN population impact is MEDIUM (100-500 people), THE Priority_Calculator SHALL assign base score of 12 points
4. WHEN population impact is LOW (<100 people), THE Priority_Calculator SHALL assign base score of 5 points
5. WHEN location is near a school or hospital, THE Priority_Calculator SHALL apply a 2.0x multiplier to population score
6. WHEN location is on a main road or highway, THE Priority_Calculator SHALL apply a 1.8x multiplier to population score
7. WHEN location is in a commercial zone, THE Priority_Calculator SHALL apply a 1.5x multiplier to population score
8. THE Priority_Calculator SHALL clamp the final population score to maximum 25 points

### Requirement 7: Category Urgency Scoring

**User Story:** As a priority system, I want different issue categories to have inherent urgency scores, so that time-sensitive issues are prioritized appropriately.

#### Acceptance Criteria

1. WHEN category is POWER_CUT, THE Priority_Calculator SHALL assign 15 category urgency points
2. WHEN category is WATER_LEAK or SEWAGE_OVERFLOW, THE Priority_Calculator SHALL assign 14 category urgency points
3. WHEN category is POTHOLE, THE Priority_Calculator SHALL assign 12 category urgency points
4. WHEN category is DRAINAGE_PROBLEM, THE Priority_Calculator SHALL assign 11 category urgency points
5. WHEN category is STREETLIGHT, THE Priority_Calculator SHALL assign 10 category urgency points
6. WHEN category is GARBAGE, THE Priority_Calculator SHALL assign 8 category urgency points
7. WHEN category is OTHER or unknown, THE Priority_Calculator SHALL assign 6 category urgency points

### Requirement 8: Community Support Scoring

**User Story:** As a priority system, I want to factor in community support through upvotes, so that issues affecting many concerned citizens get attention while preventing gaming.

#### Acceptance Criteria

1. WHEN upvotes are 0 or negative, THE Priority_Calculator SHALL assign 0 community points
2. WHEN upvotes are between 1 and 5, THE Priority_Calculator SHALL assign points equal to upvote count
3. WHEN upvotes are between 6 and 20, THE Priority_Calculator SHALL assign 5 plus half of (upvotes minus 5) points
4. WHEN upvotes are between 21 and 100, THE Priority_Calculator SHALL assign 12 plus 10% of (upvotes minus 20) points
5. WHEN upvotes exceed 100, THE Priority_Calculator SHALL cap community score at 15 points
6. THE Priority_Calculator SHALL use logarithmic scaling to prevent gaming through mass upvoting

### Requirement 9: Time Factor Scoring

**User Story:** As a priority system, I want to consider issue age, so that both fresh reports and long-pending issues receive appropriate attention.

#### Acceptance Criteria

1. WHEN issue age is less than 24 hours, THE Priority_Calculator SHALL assign 10 time points
2. WHEN issue age is between 1 and 3 days, THE Priority_Calculator SHALL assign 8 time points
3. WHEN issue age is between 3 and 7 days, THE Priority_Calculator SHALL assign 6 time points
4. WHEN issue age is between 7 and 14 days, THE Priority_Calculator SHALL assign 7 time points (bump for getting stale)
5. WHEN issue age is between 14 and 30 days, THE Priority_Calculator SHALL assign 8 time points (overdue priority)
6. WHEN issue age exceeds 30 days, THE Priority_Calculator SHALL assign 10 time points (needs urgent attention)

### Requirement 10: Chaos/Emergency Detection

**User Story:** As a system administrator, I want the system to detect emergency situations from images, so that critical incidents receive immediate escalation.

#### Acceptance Criteria

1. THE Chaos_Detector SHALL calculate a chaos score between 0.0 and 1.0 based on AI analysis
2. WHEN multiple hazard indicators are detected, THE Chaos_Detector SHALL add 0.1 to chaos score per hazard
3. WHEN severity is CRITICAL, THE Chaos_Detector SHALL add 0.3 to chaos score
4. WHEN severity is HIGH, THE Chaos_Detector SHALL add 0.2 to chaos score
5. WHEN population impact is CRITICAL, THE Chaos_Detector SHALL add 0.25 to chaos score
6. WHEN population impact is HIGH, THE Chaos_Detector SHALL add 0.15 to chaos score
7. WHEN flooding hazard is detected, THE Chaos_Detector SHALL add 0.15 to chaos score
8. WHEN traffic_blocked hazard is detected, THE Chaos_Detector SHALL add 0.1 to chaos score
9. WHEN structural_damage hazard is detected, THE Chaos_Detector SHALL add 0.2 to chaos score
10. WHEN fire_hazard is detected, THE Chaos_Detector SHALL add 0.3 to chaos score
11. THE Chaos_Detector SHALL clamp the final chaos score to range 0.0-1.0

### Requirement 11: Emergency Escalation

**User Story:** As a state administrator, I want emergency situations to trigger automatic escalation, so that critical issues receive immediate attention at the appropriate level.

#### Acceptance Criteria

1. WHEN chaos score is >= 0.8, THE Escalation_Handler SHALL trigger emergency protocol with state admin notification and auto-assignment
2. WHEN chaos score is >= 0.6 and < 0.8, THE Escalation_Handler SHALL trigger high priority protocol with district admin notification
3. WHEN chaos score is >= 0.4 and < 0.6, THE Escalation_Handler SHALL flag the issue for supervisor review
4. WHEN chaos score >= 0.6, THE Priority_Calculator SHALL apply a chaos multiplier of (1 + chaosScore * 0.5) to the priority score
5. WHEN emergency protocol is triggered, THE system SHALL set priority score to 100 (maximum)

### Requirement 12: Priority Zone Bonus

**User Story:** As a priority system, I want to give bonus priority to issues in critical areas, so that issues near hospitals, schools, and other important locations are addressed faster.

#### Acceptance Criteria

1. WHEN issue is in criticalInfrastructure zone (hospitals, fire stations, police), THE Priority_Calculator SHALL add 20 bonus points
2. WHEN issue is in educationalZone (schools, colleges), THE Priority_Calculator SHALL add 15 bonus points
3. WHEN issue is in commercialHub (markets, business districts), THE Priority_Calculator SHALL add 12 bonus points
4. WHEN issue is in residentialDense zone (apartment complexes), THE Priority_Calculator SHALL add 10 bonus points
5. WHEN issue is in industrial zone, THE Priority_Calculator SHALL add 8 bonus points
6. WHEN issue is in residentialSparse zone, THE Priority_Calculator SHALL add 5 bonus points
7. WHEN issue is in rural zone, THE Priority_Calculator SHALL add 3 bonus points

### Requirement 13: High Priority Determination

**User Story:** As a system user, I want to clearly identify high priority issues, so that they can be visually distinguished and fast-tracked.

#### Acceptance Criteria

1. WHEN priority score exceeds 70, THE system SHALL mark the issue as high priority
2. WHEN AI analysis severity is CRITICAL, THE system SHALL mark the issue as high priority regardless of score
3. WHEN chaos score is >= 0.7, THE system SHALL mark the issue as high priority regardless of score

### Requirement 14: AI Analysis Data Model

**User Story:** As a developer, I want a well-defined data model for AI analysis results, so that analysis data can be consistently stored and processed.

#### Acceptance Criteria

1. THE AIAnalysis model SHALL include detectedCategory as a string
2. THE AIAnalysis model SHALL include confidenceScore as a double between 0.0 and 1.0
3. THE AIAnalysis model SHALL include severityLevel as a string (LOW, MEDIUM, HIGH, CRITICAL)
4. THE AIAnalysis model SHALL include affectedAreaSqm as a double
5. THE AIAnalysis model SHALL include populationImpact as a string (LOW, MEDIUM, HIGH, CRITICAL)
6. THE AIAnalysis model SHALL include hazardIndicators as a list of strings
7. THE AIAnalysis model SHALL include recommendedPriority as an integer (0-100)
8. THE AIAnalysis model SHALL include analysisNotes as a string
9. THE AIAnalysis model SHALL include analyzedAt as a DateTime timestamp
10. THE AIAnalysis model SHALL support JSON serialization and deserialization
