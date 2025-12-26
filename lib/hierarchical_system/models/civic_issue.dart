import 'ai_analysis.dart';
import 'geo_point.dart';

/// Status of a civic issue in the system.
enum IssueStatus { pending, assigned, inProgress, resolved, escalated }

/// Represents a civic issue reported by a citizen.
class CivicIssue {
  final String id;
  final String category;
  final String description;
  final String imageUrl;
  final GeoPoint location;
  final String district;
  final String state;
  final int upvotes;
  final DateTime createdAt;
  final IssueStatus status;
  final AIAnalysis? aiAnalysis;
  final int priorityScore;
  final bool isHighPriority;

  CivicIssue({
    required this.id,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.district,
    required this.state,
    this.upvotes = 0,
    required this.createdAt,
    this.status = IssueStatus.pending,
    this.aiAnalysis,
    this.priorityScore = 0,
    this.isHighPriority = false,
  });

  /// Creates a CivicIssue from JSON map.
  factory CivicIssue.fromJson(Map<String, dynamic> json) {
    return CivicIssue(
      id: json['id'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
      district: json['district'] as String,
      state: json['state'] as String,
      upvotes: json['upvotes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: IssueStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => IssueStatus.pending,
      ),
      aiAnalysis: json['ai_analysis'] != null
          ? AIAnalysis.fromJson(json['ai_analysis'] as Map<String, dynamic>)
          : null,
      priorityScore: json['priority_score'] as int? ?? 0,
      isHighPriority: json['is_high_priority'] as bool? ?? false,
    );
  }

  /// Converts CivicIssue to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'description': description,
      'image_url': imageUrl,
      'location': location.toJson(),
      'district': district,
      'state': state,
      'upvotes': upvotes,
      'created_at': createdAt.toIso8601String(),
      'status': status.name,
      'ai_analysis': aiAnalysis?.toJson(),
      'priority_score': priorityScore,
      'is_high_priority': isHighPriority,
    };
  }

  /// Creates a copy with optional field overrides.
  CivicIssue copyWith({
    String? id,
    String? category,
    String? description,
    String? imageUrl,
    GeoPoint? location,
    String? district,
    String? state,
    int? upvotes,
    DateTime? createdAt,
    IssueStatus? status,
    AIAnalysis? aiAnalysis,
    int? priorityScore,
    bool? isHighPriority,
  }) {
    return CivicIssue(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      district: district ?? this.district,
      state: state ?? this.state,
      upvotes: upvotes ?? this.upvotes,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      priorityScore: priorityScore ?? this.priorityScore,
      isHighPriority: isHighPriority ?? this.isHighPriority,
    );
  }

  @override
  String toString() {
    return 'CivicIssue(id: $id, category: $category, status: $status, '
        'priority: $priorityScore, highPriority: $isHighPriority)';
  }
}
