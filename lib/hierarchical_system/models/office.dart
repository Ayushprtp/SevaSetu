import 'enums.dart';
import 'geo_point.dart';

/// Represents a government office that handles civic issues.
class Office {
  final String id;
  final String name;
  final Department department;
  final String district;
  final String state;
  final GeoPoint location;
  final bool isStateLevel;

  const Office({
    required this.id,
    required this.name,
    required this.department,
    required this.district,
    required this.state,
    required this.location,
    this.isStateLevel = false,
  });

  /// Creates an Office from JSON map.
  factory Office.fromJson(Map<String, dynamic> json) {
    return Office(
      id: json['id'] as String,
      name: json['name'] as String,
      department: Department.values.firstWhere(
        (e) => e.name == json['department'],
        orElse: () => Department.general,
      ),
      district: json['district'] as String,
      state: json['state'] as String,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      isStateLevel: json['is_state_level'] as bool? ?? false,
    );
  }

  /// Converts Office to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department.name,
      'district': district,
      'state': state,
      'location': location.toJson(),
      'is_state_level': isStateLevel,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Office) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Office(id: $id, name: $name, department: $department, district: $district)';
}

/// Result of assigning an issue to an office.
class AssignmentResult {
  final Office office;
  final bool escalated;
  final double distance;

  const AssignmentResult({
    required this.office,
    required this.escalated,
    required this.distance,
  });

  @override
  String toString() =>
      'AssignmentResult(office: ${office.name}, escalated: $escalated, distance: ${distance.toStringAsFixed(2)}km)';
}
