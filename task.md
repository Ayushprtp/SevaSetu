# SevaSetu Hierarchical System Architecture

## Overview

SevaSetu implements a multi-tier hierarchical system for civic issue management that combines administrative hierarchy, AI-powered analysis, and intelligent prioritization to ensure efficient issue resolution.

---

## 1. Administrative Hierarchy Structure

### 1.1 Four-Tier Government Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    STATE LEVEL                               │
│  • State Admin Dashboard                                     │
│  • Cross-district analytics & escalation handling            │
│  • Policy-level decisions                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   DEPARTMENT LEVEL                           │
│  • PWD, Sanitation, Electricity, Water, General              │
│  • Department-wide resource allocation                       │
│  • Performance monitoring across districts                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   DISTRICT/OFFICE LEVEL                      │
│  • Local government offices                                  │
│  • Direct issue assignment                                   │
│  • Field worker management                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   FIELD WORKER LEVEL                         │
│  • On-ground issue resolution                                │
│  • Status updates & photo verification                       │
│  • Direct citizen communication                              │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Issue Flow Through Hierarchy

1. **Citizen Reports Issue** → Issue enters system with location, category, media
2. **AI Analysis** → Automatic categorization, severity assessment, population impact
3. **Department Routing** → Category maps to responsible department
4. **Office Assignment** → Nearest office in district receives issue
5. **Worker Assignment** → Office admin assigns to available field worker
6. **Escalation Path** → Unresolved issues escalate up the hierarchy

---

## 2. Department-Category Mapping

### 2.1 Automatic Routing Logic

| Issue Category     | Assigned Department        | Rationale                           |
|--------------------|----------------------------|-------------------------------------|
| POTHOLE            | PWD (Public Works)         | Road infrastructure                 |
| DRAINAGE_PROBLEM   | PWD (Public Works)         | Civil infrastructure                |
| GARBAGE            | SANITATION                 | Waste management                    |
| SEWAGE_OVERFLOW    | SANITATION                 | Sewage systems                      |
| STREETLIGHT        | ELECTRICITY                | Electrical infrastructure           |
| POWER_CUT          | ELECTRICITY                | Power supply issues                 |
| WATER_LEAK         | WATER                      | Water supply infrastructure         |
| OTHER              | GENERAL                    | Unclassified issues                 |

### 2.2 Assignment Engine Logic

```dart
// Pseudocode for assignment flow
assignIssue(issue):
  1. department = mapCategoryToDepartment(issue.category)
  2. districtOffices = findOffices(department, issue.district)
  3. if districtOffices.isNotEmpty:
       nearestOffice = selectByDistance(districtOffices, issue.location)
       return AssignmentResult(nearestOffice, escalated: false)
  4. else:
       stateOffices = findStateOffices(department, issue.state)
       nearestOffice = selectByDistance(stateOffices, issue.location)
       return AssignmentResult(nearestOffice, escalated: true)
```

---

## 3. Generative AI Image Analysis System

### 3.1 How AI Categorization Works

The system uses a multi-modal AI model (e.g., Google Gemini Vision, GPT-4 Vision) to analyze uploaded images and automatically:

1. **Identify Issue Type** - Detect what civic problem is shown
2. **Assess Severity** - Determine how critical the situation is
3. **Estimate Impact** - Calculate affected population/area
4. **Extract Context** - Identify location markers, time indicators

### 3.2 AI Analysis Pipeline

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Image      │────▶│   Pre-       │────▶│   AI Model   │────▶│   Post-      │
│   Upload     │     │   Processing │     │   Inference  │     │   Processing │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                                       │
                                                                       ▼
                     ┌─────────────────────────────────────────────────────────┐
                     │                    AI Analysis Output                    │
                     │  • detected_category: "POTHOLE"                         │
                     │  • confidence_score: 0.94                               │
                     │  • severity_level: "HIGH"                               │
                     │  • affected_area_sqm: 15.5                              │
                     │  • population_impact: "MEDIUM"                          │
                     │  • hazard_indicators: ["traffic_risk", "pedestrian"]    │
                     │  • recommended_priority: 85                             │
                     └─────────────────────────────────────────────────────────┘
```

### 3.3 AI Prompt Engineering for Image Analysis

```
SYSTEM PROMPT FOR CIVIC ISSUE IMAGE ANALYSIS:

You are an AI assistant specialized in analyzing civic infrastructure issues.
Analyze the provided image and return a JSON response with:

1. CATEGORY DETECTION:
   - Identify the primary issue type from: POTHOLE, GARBAGE, STREETLIGHT, 
     WATER_LEAK, SEWAGE_OVERFLOW, DRAINAGE_PROBLEM, POWER_CUT, OTHER
   - Provide confidence score (0.0 to 1.0)

2. SEVERITY ASSESSMENT:
   - LOW: Minor inconvenience, no safety risk
   - MEDIUM: Moderate impact, potential safety concern
   - HIGH: Significant hazard, immediate attention needed
   - CRITICAL: Emergency situation, public safety at risk

3. POPULATION IMPACT ESTIMATION:
   - Analyze visible context (residential area, commercial zone, school nearby)
   - Estimate affected population density
   - Consider time-sensitive factors (rush hour traffic, school timings)

4. SITUATIONAL CONTEXT:
   - Identify environmental hazards
   - Detect infrastructure damage extent
   - Note any visible safety risks

Return structured JSON only.
```

### 3.4 AI Analysis Data Model

```dart
class AIAnalysis {
  final String detectedCategory;      // AI-detected issue type
  final double confidenceScore;       // 0.0 to 1.0
  final String severityLevel;         // LOW, MEDIUM, HIGH, CRITICAL
  final double affectedAreaSqm;       // Estimated affected area
  final String populationImpact;      // LOW, MEDIUM, HIGH, CRITICAL
  final List<String> hazardIndicators; // Detected hazards
  final int recommendedPriority;      // 0-100 score
  final String analysisNotes;         // Additional AI observations
  final DateTime analyzedAt;          // Timestamp
}
```

---

## 4. Priority Scoring Algorithm

### 4.1 Multi-Factor Priority Calculation

The priority score (0-100) is calculated using weighted factors:

```
PRIORITY_SCORE = 
    (SEVERITY_WEIGHT × Severity_Score) +
    (POPULATION_WEIGHT × Population_Impact_Score) +
    (CATEGORY_WEIGHT × Category_Urgency_Score) +
    (UPVOTE_WEIGHT × Community_Support_Score) +
    (AGE_WEIGHT × Time_Decay_Score) +
    (AI_WEIGHT × AI_Confidence_Bonus)
```

### 4.2 Weight Distribution

| Factor              | Weight | Max Points | Description                          |
|---------------------|--------|------------|--------------------------------------|
| Severity            | 30%    | 30         | How dangerous/critical is the issue  |
| Population Impact   | 25%    | 25         | How many people are affected         |
| Category Urgency    | 15%    | 15         | Inherent urgency of issue type       |
| Community Support   | 15%    | 15         | Upvotes from other citizens          |
| Time Factor         | 10%    | 10         | How long issue has been pending      |
| AI Confidence       | 5%     | 5          | Bonus for high-confidence AI analysis|

### 4.3 Severity Scoring

```dart
int calculateSeverityScore(String severityLevel) {
  switch (severityLevel) {
    case 'CRITICAL':
      return 30;  // Maximum severity - immediate danger
    case 'HIGH':
      return 24;  // Significant hazard
    case 'MEDIUM':
      return 15;  // Moderate concern
    case 'LOW':
      return 8;   // Minor inconvenience
    default:
      return 10;
  }
}
```

### 4.4 Population Impact Scoring

The AI estimates population impact based on:

1. **Location Type Analysis**
   - Residential area: Base multiplier 1.0x
   - Commercial zone: Base multiplier 1.5x
   - School/Hospital vicinity: Base multiplier 2.0x
   - Main road/Highway: Base multiplier 1.8x

2. **Density Estimation**
   ```dart
   int calculatePopulationScore(AIAnalysis analysis) {
     // Base score from AI population impact assessment
     int baseScore = switch (analysis.populationImpact) {
       'CRITICAL' => 25,  // Affects 1000+ people
       'HIGH' => 20,      // Affects 500-1000 people
       'MEDIUM' => 12,    // Affects 100-500 people
       'LOW' => 5,        // Affects <100 people
       _ => 8,
     };
     
     // Location type multiplier
     double locationMultiplier = getLocationMultiplier(analysis);
     
     return (baseScore * locationMultiplier).clamp(0, 25).toInt();
   }
   ```

3. **Contextual Factors**
   - Time of day (rush hour = higher impact)
   - Day of week (weekday vs weekend)
   - Seasonal factors (monsoon = drainage issues more critical)

### 4.5 Category Urgency Scoring

```dart
int getCategoryUrgencyScore(String category) {
  // Categories ranked by inherent urgency
  const categoryScores = {
    'POWER_CUT': 15,        // Affects daily life immediately
    'WATER_LEAK': 14,       // Resource wastage + damage
    'SEWAGE_OVERFLOW': 14,  // Health hazard
    'POTHOLE': 12,          // Safety risk
    'DRAINAGE_PROBLEM': 11, // Flooding risk
    'STREETLIGHT': 10,      // Night safety
    'GARBAGE': 8,           // Health/aesthetic
    'OTHER': 6,
  };
  return categoryScores[category] ?? 6;
}
```

### 4.6 Community Support Scoring

```dart
int calculateCommunityScore(int upvotes) {
  // Logarithmic scaling to prevent gaming
  if (upvotes <= 0) return 0;
  if (upvotes <= 5) return upvotes;
  if (upvotes <= 20) return 5 + ((upvotes - 5) * 0.5).toInt();
  if (upvotes <= 100) return 12 + ((upvotes - 20) * 0.1).toInt();
  return 15; // Cap at 15 points
}
```

### 4.7 Time Decay Scoring

```dart
int calculateTimeScore(DateTime createdAt) {
  final age = DateTime.now().difference(createdAt);
  
  // Newer issues get slight priority, but old unresolved issues also prioritized
  if (age.inHours < 24) return 10;      // Fresh report
  if (age.inDays < 3) return 8;         // Recent
  if (age.inDays < 7) return 6;         // Week old
  if (age.inDays < 14) return 7;        // Getting stale - bump up
  if (age.inDays < 30) return 8;        // Overdue - higher priority
  return 10;                             // Very old - needs attention
}
```

---

## 5. Chaos/Emergency Situation Handling

### 5.1 Chaos Detection Indicators

The AI analyzes images for emergency/chaos indicators:

```dart
class ChaosIndicators {
  final bool multipleHazardsDetected;    // More than one issue type
  final bool crowdPresent;                // People gathered around issue
  final bool vehicleInvolvement;          // Vehicles affected/stuck
  final bool waterAccumulation;           // Flooding visible
  final bool structuralDamage;            // Building/road damage
  final bool fireOrSmoke;                 // Fire hazard detected
  final bool medicalEmergency;            // Injured persons visible
  final double chaosScore;                // 0.0 to 1.0
}
```

### 5.2 Chaos Score Calculation

```dart
double calculateChaosScore(AIAnalysis analysis) {
  double score = 0.0;
  
  // Multiple hazards compound the chaos
  score += analysis.hazardIndicators.length * 0.1;
  
  // Severity amplifies chaos
  if (analysis.severityLevel == 'CRITICAL') score += 0.3;
  if (analysis.severityLevel == 'HIGH') score += 0.2;
  
  // Population impact amplifies chaos
  if (analysis.populationImpact == 'CRITICAL') score += 0.25;
  if (analysis.populationImpact == 'HIGH') score += 0.15;
  
  // Specific hazard indicators
  if (analysis.hazardIndicators.contains('flooding')) score += 0.15;
  if (analysis.hazardIndicators.contains('traffic_blocked')) score += 0.1;
  if (analysis.hazardIndicators.contains('structural_damage')) score += 0.2;
  if (analysis.hazardIndicators.contains('fire_hazard')) score += 0.3;
  
  return score.clamp(0.0, 1.0);
}
```

### 5.3 Emergency Escalation Rules

```dart
void handleEmergencyEscalation(CivicIssue issue, AIAnalysis analysis) {
  final chaosScore = calculateChaosScore(analysis);
  
  if (chaosScore >= 0.8) {
    // CRITICAL EMERGENCY
    // - Immediate notification to State Admin
    // - Auto-assign to nearest available team
    // - Alert emergency services if needed
    // - Priority score = 100 (maximum)
    triggerEmergencyProtocol(issue);
  } else if (chaosScore >= 0.6) {
    // HIGH PRIORITY SITUATION
    // - Notify District Admin immediately
    // - Fast-track assignment
    // - Priority score = 90+
    triggerHighPriorityProtocol(issue);
  } else if (chaosScore >= 0.4) {
    // ELEVATED CONCERN
    // - Flag for supervisor review
    // - Priority score boost +20
    flagForReview(issue);
  }
}
```

---

## 6. Population-Based Prioritization

### 6.1 Affected Population Estimation

The AI estimates affected population using:

1. **Visual Context Analysis**
   ```
   Image Analysis Factors:
   ├── Building density visible
   ├── Road type (main road vs lane)
   ├── Presence of shops/businesses
   ├── School/hospital signage
   ├── Vehicle traffic density
   └── Pedestrian presence
   ```

2. **Location Data Enrichment**
   ```dart
   Future<PopulationData> enrichWithLocationData(GeoPoint location) async {
     // Query external APIs or local database for:
     // - Census data for the area
     // - Land use classification
     // - Points of interest nearby
     // - Historical foot traffic data
   }
   ```

3. **Time-Based Adjustment**
   ```dart
   double getTimeBasedMultiplier(DateTime reportTime) {
     final hour = reportTime.hour;
     final isWeekend = reportTime.weekday >= 6;
     
     // Rush hours have higher population impact
     if (!isWeekend && (hour >= 8 && hour <= 10 || hour >= 17 && hour <= 20)) {
       return 1.5; // Rush hour multiplier
     }
     
     // Night time lower impact for most issues
     if (hour >= 23 || hour <= 5) {
       return 0.7;
     }
     
     return 1.0;
   }
   ```

### 6.2 Area-Specific Priority Zones

```dart
enum PriorityZone {
  criticalInfrastructure,  // Hospitals, fire stations, police
  educationalZone,         // Schools, colleges
  commercialHub,           // Markets, business districts
  residentialDense,        // Apartment complexes
  residentialSparse,       // Individual houses
  industrial,              // Factories, warehouses
  rural,                   // Village areas
}

int getZonePriorityBonus(PriorityZone zone) {
  return switch (zone) {
    PriorityZone.criticalInfrastructure => 20,
    PriorityZone.educationalZone => 15,
    PriorityZone.commercialHub => 12,
    PriorityZone.residentialDense => 10,
    PriorityZone.residentialSparse => 5,
    PriorityZone.industrial => 8,
    PriorityZone.rural => 3,
  };
}
```

---

## 7. Complete Priority Calculation Implementation

```dart
class PriorityCalculator {
  
  /// Calculate comprehensive priority score for an issue
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
      final chaosScore = calculateChaosScore(aiAnalysis);
      if (chaosScore >= 0.6) {
        totalScore = (totalScore * (1 + chaosScore * 0.5)).toInt();
      }
    }
    
    // Ensure score is within bounds
    return totalScore.clamp(0, 100);
  }
  
  /// Determine if issue should be marked as high priority
  bool isHighPriority(int priorityScore, AIAnalysis? aiAnalysis) {
    // High priority if score > 70 OR critical severity OR high chaos
    if (priorityScore > 70) return true;
    if (aiAnalysis?.severityLevel == 'CRITICAL') return true;
    if (aiAnalysis != null && calculateChaosScore(aiAnalysis) >= 0.7) return true;
    return false;
  }
}
```

---

## 8. Real-World Scenario Examples

### Scenario 1: Pothole on Main Road During Rush Hour

```
INPUT:
- Image: Large pothole on busy road
- Time: 8:30 AM (Monday)
- Location: Near school zone

AI ANALYSIS:
- Category: POTHOLE (confidence: 0.95)
- Severity: HIGH (traffic hazard)
- Population Impact: HIGH (school children, commuters)
- Hazards: [traffic_risk, pedestrian_safety, vehicle_damage]

PRIORITY CALCULATION:
- Severity Score: 24/30
- Population Score: 20/25 (school zone + rush hour)
- Category Score: 12/15
- Community Score: 0/15 (new report)
- Time Score: 10/10 (fresh)
- AI Bonus: 4/5

TOTAL: 70/100 → HIGH PRIORITY
```

### Scenario 2: Sewage Overflow in Residential Area

```
INPUT:
- Image: Sewage water on street
- Time: 2:00 PM (Wednesday)
- Location: Dense residential colony

AI ANALYSIS:
- Category: SEWAGE_OVERFLOW (confidence: 0.92)
- Severity: CRITICAL (health hazard)
- Population Impact: CRITICAL (500+ residents)
- Hazards: [health_hazard, water_contamination, disease_risk]
- Chaos Score: 0.65

PRIORITY CALCULATION:
- Severity Score: 30/30
- Population Score: 25/25
- Category Score: 14/15
- Community Score: 8/15 (20 upvotes)
- Time Score: 8/10
- AI Bonus: 4/5
- Chaos Multiplier: 1.32x

TOTAL: 89 × 1.32 = 100 (capped) → EMERGENCY
```

### Scenario 3: Streetlight Not Working

```
INPUT:
- Image: Dark street with non-functional light
- Time: 7:00 PM (Saturday)
- Location: Residential lane

AI ANALYSIS:
- Category: STREETLIGHT (confidence: 0.88)
- Severity: MEDIUM (night safety)
- Population Impact: LOW (single lane)
- Hazards: [night_safety]

PRIORITY CALCULATION:
- Severity Score: 15/30
- Population Score: 5/25
- Category Score: 10/15
- Community Score: 2/15 (2 upvotes)
- Time Score: 10/10
- AI Bonus: 4/5

TOTAL: 46/100 → NORMAL PRIORITY
```

---

## 9. System Integration Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE ISSUE LIFECYCLE                             │
└─────────────────────────────────────────────────────────────────────────────┘

CITIZEN REPORTS ISSUE
        │
        ▼
┌───────────────────┐
│  Image Upload     │
│  + Location       │
│  + Description    │
└───────────────────┘
        │
        ▼
┌───────────────────┐     ┌───────────────────┐
│  AI ANALYSIS      │────▶│  Category         │
│  (Gemini/GPT-4V)  │     │  Severity         │
│                   │     │  Population       │
│                   │     │  Chaos Score      │
└───────────────────┘     └───────────────────┘
        │
        ▼
┌───────────────────┐
│  PRIORITY         │
│  CALCULATION      │
│  (0-100 score)    │
└───────────────────┘
        │
        ▼
┌───────────────────┐     ┌───────────────────┐
│  DEPARTMENT       │────▶│  PWD / SANITATION │
│  ROUTING          │     │  ELECTRICITY /    │
│                   │     │  WATER / GENERAL  │
└───────────────────┘     └───────────────────┘
        │
        ▼
┌───────────────────┐
│  OFFICE           │
│  ASSIGNMENT       │
│  (Nearest office) │
└───────────────────┘
        │
        ├──────────────────────────────────────┐
        │                                      │
        ▼                                      ▼
┌───────────────────┐              ┌───────────────────┐
│  NORMAL FLOW      │              │  EMERGENCY FLOW   │
│  - Queue by       │              │  - Immediate      │
│    priority       │              │    notification   │
│  - Admin assigns  │              │  - Auto-assign    │
│    worker         │              │  - State alert    │
└───────────────────┘              └───────────────────┘
        │                                      │
        └──────────────────┬───────────────────┘
                           │
                           ▼
                  ┌───────────────────┐
                  │  FIELD WORKER     │
                  │  RESOLUTION       │
                  └───────────────────┘
                           │
                           ▼
                  ┌───────────────────┐
                  │  VERIFICATION     │
                  │  & CLOSURE        │
                  └───────────────────┘
```

---

## 10. API Endpoints for AI Integration

### 10.1 Image Analysis Endpoint

```dart
// POST /api/analyze-image
Future<AIAnalysis> analyzeImage(String imageUrl) async {
  final response = await http.post(
    Uri.parse('$AI_SERVICE_URL/analyze'),
    body: jsonEncode({
      'image_url': imageUrl,
      'analysis_type': 'civic_issue',
      'return_format': 'structured_json',
    }),
  );
  
  return AIAnalysis.fromJson(jsonDecode(response.body));
}
```

### 10.2 Priority Recalculation Trigger

```dart
// Called when:
// - New upvote received
// - Issue age crosses threshold
// - Related issues reported nearby
// - Manual admin override

Future<void> recalculatePriority(String issueId) async {
  final issue = await getIssue(issueId);
  final aiAnalysis = issue.aiAnalysis;
  
  final newScore = priorityCalculator.calculatePriorityScore(issue, aiAnalysis);
  
  await updateIssuePriority(issueId, newScore);
  
  // Check if escalation needed
  if (newScore > 80 && issue.status == IssueStatus.pending) {
    await triggerEscalation(issue);
  }
}
```

---

## 11. Summary

The SevaSetu hierarchical system ensures:

1. **Intelligent Routing** - Issues automatically reach the right department
2. **AI-Powered Analysis** - Images analyzed for category, severity, and impact
3. **Fair Prioritization** - Multi-factor scoring prevents gaming
4. **Population-Aware** - Higher impact areas get faster response
5. **Emergency Handling** - Chaos situations trigger immediate escalation
6. **Transparent Process** - Citizens can track their issue through the hierarchy

This system balances automation with human oversight, ensuring efficient civic issue resolution while maintaining accountability at every level.
