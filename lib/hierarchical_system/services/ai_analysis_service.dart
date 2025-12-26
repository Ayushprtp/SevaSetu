import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_analysis.dart';
import '../models/enums.dart';

/// Abstract interface for AI image analysis services.
abstract class AIAnalysisService {
  /// Analyzes an image and returns structured analysis.
  Future<AIAnalysis> analyzeImage(String imageUrl);

  /// Validates that analysis result contains required fields.
  bool validateAnalysis(AIAnalysis analysis);
}

/// Implementation using Google Gemini Vision API.
class GeminiAIAnalysisService implements AIAnalysisService {
  final String apiKey;
  final String modelId;
  final String baseUrl;

  GeminiAIAnalysisService({
    String? apiKey,
    this.modelId = 'gemini-1.5-flash',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  }) : apiKey = apiKey ?? 'AIzaSyAhu6MQEPj1pDUZP3DfTXFJX9C-GRug1Qw';

  /// Factory constructor with default API key for convenience.
  factory GeminiAIAnalysisService.withDefaults() {
    return GeminiAIAnalysisService();
  }

  @override
  Future<AIAnalysis> analyzeImage(String imageUrl) async {
    try {
      final prompt = _buildAnalysisPrompt();

      final response = await http.post(
        Uri.parse('$baseUrl/models/$modelId:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': await _fetchImageAsBase64(imageUrl),
                  },
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw AIAnalysisException(
          'API request failed with status ${response.statusCode}',
          imageUrl: imageUrl,
        );
      }

      final jsonResponse = jsonDecode(response.body);
      final textContent =
          jsonResponse['candidates'][0]['content']['parts'][0]['text'];

      // Parse the JSON response from the AI
      final analysisJson = _extractJsonFromResponse(textContent);

      return AIAnalysis(
        detectedCategory: _normalizeCategory(analysisJson['detected_category']),
        confidenceScore: (analysisJson['confidence_score'] as num).toDouble(),
        severityLevel: _normalizeSeverity(analysisJson['severity_level']),
        affectedAreaSqm:
            (analysisJson['affected_area_sqm'] as num?)?.toDouble() ?? 0.0,
        populationImpact: _normalizePopulationImpact(
          analysisJson['population_impact'],
        ),
        hazardIndicators: List<String>.from(
          analysisJson['hazard_indicators'] ?? [],
        ),
        recommendedPriority: analysisJson['recommended_priority'] as int? ?? 50,
        analysisNotes: analysisJson['analysis_notes'] as String? ?? '',
        analyzedAt: DateTime.now(),
      );
    } catch (e) {
      if (e is AIAnalysisException) rethrow;
      throw AIAnalysisException(
        'Failed to analyze image: $e',
        imageUrl: imageUrl,
      );
    }
  }

  @override
  bool validateAnalysis(AIAnalysis analysis) {
    // Validate required fields
    if (!IssueCategory.isValid(analysis.detectedCategory)) return false;
    if (analysis.confidenceScore < 0 || analysis.confidenceScore > 1)
      return false;
    if (!SeverityLevel.isValid(analysis.severityLevel)) return false;
    if (!PopulationImpact.isValid(analysis.populationImpact)) return false;
    if (analysis.recommendedPriority < 0 || analysis.recommendedPriority > 100)
      return false;

    return true;
  }

  String _buildAnalysisPrompt() {
    return '''
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
   - LOW: Affects <100 people
   - MEDIUM: Affects 100-500 people
   - HIGH: Affects 500-1000 people
   - CRITICAL: Affects 1000+ people

4. HAZARD INDICATORS:
   - Identify any of: traffic_risk, pedestrian_safety, vehicle_damage,
     health_hazard, water_contamination, disease_risk, night_safety,
     flooding, traffic_blocked, structural_damage, fire_hazard

5. ADDITIONAL CONTEXT:
   - Estimate affected area in square meters
   - Provide recommended priority score (0-100)
   - Add any relevant analysis notes

Return ONLY valid JSON in this exact format:
{
  "detected_category": "CATEGORY_NAME",
  "confidence_score": 0.95,
  "severity_level": "HIGH",
  "affected_area_sqm": 15.5,
  "population_impact": "MEDIUM",
  "hazard_indicators": ["traffic_risk", "pedestrian_safety"],
  "recommended_priority": 75,
  "analysis_notes": "Additional observations"
}
''';
  }

  Future<String> _fetchImageAsBase64(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw AIAnalysisException('Failed to fetch image', imageUrl: imageUrl);
    }
    return base64Encode(response.bodyBytes);
  }

  Map<String, dynamic> _extractJsonFromResponse(String text) {
    // Try to extract JSON from the response
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch == null) {
      throw AIAnalysisException('No JSON found in AI response');
    }
    return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
  }

  String _normalizeCategory(dynamic category) {
    if (category == null) return IssueCategory.other;
    return IssueCategory.normalize(category.toString());
  }

  String _normalizeSeverity(dynamic severity) {
    if (severity == null) return SeverityLevel.medium;
    return SeverityLevel.normalize(severity.toString());
  }

  String _normalizePopulationImpact(dynamic impact) {
    if (impact == null) return PopulationImpact.medium;
    final upper = impact.toString().toUpperCase();
    return PopulationImpact.isValid(upper) ? upper : PopulationImpact.medium;
  }
}

/// Creates a default analysis when AI analysis fails.
AIAnalysis createDefaultAnalysis(String manualCategory) {
  return AIAnalysis(
    detectedCategory: IssueCategory.normalize(manualCategory),
    confidenceScore: 0.0, // Indicates manual entry
    severityLevel: SeverityLevel.medium,
    affectedAreaSqm: 0.0,
    populationImpact: PopulationImpact.medium,
    hazardIndicators: [],
    recommendedPriority: 50,
    analysisNotes: 'Manual category selection - AI analysis unavailable',
    analyzedAt: DateTime.now(),
  );
}

/// Exception thrown when AI analysis fails.
class AIAnalysisException implements Exception {
  final String message;
  final String? imageUrl;

  AIAnalysisException(this.message, {this.imageUrl});

  @override
  String toString() {
    if (imageUrl != null) {
      return 'AIAnalysisException: $message (image: $imageUrl)';
    }
    return 'AIAnalysisException: $message';
  }
}
