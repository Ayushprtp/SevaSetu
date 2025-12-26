import 'dart:math';

/// Represents a geographic point with latitude and longitude.
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});

  /// Creates a GeoPoint from JSON map.
  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// Converts GeoPoint to JSON map.
  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  /// Calculates the distance to another GeoPoint using the Haversine formula.
  /// Returns distance in kilometers.
  double distanceTo(GeoPoint other) {
    const double earthRadiusKm = 6371.0;

    final double lat1Rad = _toRadians(latitude);
    final double lat2Rad = _toRadians(other.latitude);
    final double deltaLatRad = _toRadians(other.latitude - latitude);
    final double deltaLonRad = _toRadians(other.longitude - longitude);

    final double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLonRad / 2) *
            sin(deltaLonRad / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GeoPoint) return false;
    return latitude == other.latitude && longitude == other.longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint(lat: $latitude, lon: $longitude)';
}
