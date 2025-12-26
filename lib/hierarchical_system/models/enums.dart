/// Government departments that handle civic issues.
enum Department {
  pwd, // Public Works Department - roads, drainage
  sanitation, // Sanitation - garbage, sewage
  electricity, // Electricity - streetlights, power
  water, // Water - water supply, leaks
  general, // General - unclassified issues
}

/// Priority zones based on location type.
enum PriorityZone {
  criticalInfrastructure, // Hospitals, fire stations, police
  educationalZone, // Schools, colleges
  commercialHub, // Markets, business districts
  residentialDense, // Apartment complexes
  residentialSparse, // Individual houses
  industrial, // Factories, warehouses
  rural, // Village areas
}

/// Escalation levels based on chaos score.
enum EscalationLevel {
  none, // No escalation needed (chaos < 0.4)
  elevated, // Flag for supervisor review (0.4 <= chaos < 0.6)
  highPriority, // Notify district admin (0.6 <= chaos < 0.8)
  emergency, // Trigger emergency protocol (chaos >= 0.8)
}

/// Valid issue categories for civic issues.
class IssueCategory {
  static const String pothole = 'POTHOLE';
  static const String garbage = 'GARBAGE';
  static const String streetlight = 'STREETLIGHT';
  static const String waterLeak = 'WATER_LEAK';
  static const String sewageOverflow = 'SEWAGE_OVERFLOW';
  static const String drainageProblem = 'DRAINAGE_PROBLEM';
  static const String powerCut = 'POWER_CUT';
  static const String other = 'OTHER';

  static const List<String> all = [
    pothole,
    garbage,
    streetlight,
    waterLeak,
    sewageOverflow,
    drainageProblem,
    powerCut,
    other,
  ];

  static bool isValid(String category) {
    return all.contains(category.toUpperCase());
  }

  static String normalize(String category) {
    final upper = category.toUpperCase();
    return isValid(upper) ? upper : other;
  }
}

/// Valid severity levels for issues.
class SeverityLevel {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String critical = 'CRITICAL';

  static const List<String> all = [low, medium, high, critical];

  static bool isValid(String level) {
    return all.contains(level.toUpperCase());
  }

  static String normalize(String level) {
    final upper = level.toUpperCase();
    return isValid(upper) ? upper : medium;
  }
}

/// Valid population impact levels.
class PopulationImpact {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String critical = 'CRITICAL';

  static const List<String> all = [low, medium, high, critical];

  static bool isValid(String level) {
    return all.contains(level.toUpperCase());
  }
}

/// Known hazard indicators detected by AI.
class HazardIndicator {
  static const String trafficRisk = 'traffic_risk';
  static const String pedestrianSafety = 'pedestrian_safety';
  static const String vehicleDamage = 'vehicle_damage';
  static const String healthHazard = 'health_hazard';
  static const String waterContamination = 'water_contamination';
  static const String diseaseRisk = 'disease_risk';
  static const String nightSafety = 'night_safety';
  static const String flooding = 'flooding';
  static const String trafficBlocked = 'traffic_blocked';
  static const String structuralDamage = 'structural_damage';
  static const String fireHazard = 'fire_hazard';
}
