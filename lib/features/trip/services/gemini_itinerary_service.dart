import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:logger/logger.dart';
import 'package:xplore/features/itinerary/models/itinerary_models.dart';
import 'package:xplore/features/trip/models/trip_draft.dart';
import 'package:xplore/features/trip/services/itinerary_generator.dart';
import 'package:xplore/utilities/utilities.dart';

/// Gemini-backed [ItineraryGenerator] (FEAT-007 phase 2 / absorbs FEAT-010).
///
/// Builds a structured prompt from the [TripDraft], asks Gemini for a strict
/// JSON day plan, and parses it into [DailyPlanModel]s. Every failure mode —
/// missing/empty `GEMINI_API_KEY`, network/API error, malformed or empty JSON —
/// falls back to the [DeterministicItineraryGenerator] skeleton so the create
/// flow always produces something.
///
/// Generated stops carry an empty `place_id`; resolving real Google Places ids
/// (for believable cards + map pins) is a follow-up (see FEAT-007 open
/// questions).
class GeminiItineraryService implements ItineraryGenerator {
  GeminiItineraryService({ItineraryGenerator? fallback, Logger? logger})
    : _fallback = fallback ?? const DeterministicItineraryGenerator(),
      _logger = logger ?? createLogger('GeminiItinerary');

  final ItineraryGenerator _fallback;
  final Logger _logger;

  static bool _initialised = false;

  /// Reads the key lazily so tests / unconfigured environments don't crash.
  String get _apiKey => dotenv.maybeGet('GEMINI_API_KEY')?.trim() ?? '';

  bool _ensureInitialised() {
    final key = _apiKey;
    if (key.isEmpty) {
      return false;
    }
    if (!_initialised) {
      Gemini.init(apiKey: key);
      _initialised = true;
    }
    return true;
  }

  @override
  Future<List<DailyPlanModel>> generate(TripDraft draft) async {
    if (!_ensureInitialised()) {
      _logger.d('No GEMINI_API_KEY configured; using deterministic skeleton.');
      return _fallback.generate(draft);
    }

    try {
      final response = await Gemini.instance.prompt(
        parts: [Part.text(_buildPrompt(draft))],
        generationConfig: GenerationConfig(temperature: 0.8, maxOutputTokens: 2048),
      );
      final output = response?.output;
      final plans = _parse(output, draft);
      if (plans.isEmpty) {
        _logger.w('Gemini returned no usable days; falling back to skeleton.');
        return _fallback.generate(draft);
      }
      return plans;
    } catch (err) {
      _logger.w('Gemini generation failed ($err); falling back to skeleton.');
      return _fallback.generate(draft);
    }
  }

  String _buildPrompt(TripDraft draft) {
    final interests = draft.interests.isEmpty
        ? 'a balanced mix'
        : draft.interests.map((i) => i.label.toLowerCase()).join(', ');
    final notes = draft.notes.trim().isEmpty ? '' : '\nTraveller notes: "${draft.notes.trim()}"';

    return '''
You are a travel-planning assistant. Plan a ${draft.durationDays}-day trip to ${draft.destination}.
Travellers: ${draft.groupKind.label.toLowerCase()} (${draft.groupSize}). Pace: ${draft.pace.label.toLowerCase()}. Budget: ${draft.budget.description.toLowerCase()}.
Interests: $interests.$notes

Return ONLY a JSON array (no markdown, no prose) with exactly ${draft.durationDays} objects, one per day, in this shape:
[
  {
    "title": "short, evocative day title",
    "location": "${draft.destination}",
    "stops": [
      { "name": "place or activity name", "description": "one sentence why it fits" }
    ]
  }
]
Each day should have 3-4 stops ordered sensibly. Keep names real and specific to ${draft.destination}.''';
  }

  List<DailyPlanModel> _parse(String? output, TripDraft draft) {
    if (output == null || output.trim().isEmpty) {
      return const [];
    }

    final cleaned = _stripCodeFences(output);
    final decoded = jsonDecode(cleaned);
    if (decoded is! List) {
      return const [];
    }

    final plans = <DailyPlanModel>[];
    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }
      final title = (entry['title'] as Object?)?.toString().trim();
      final location = (entry['location'] as Object?)?.toString().trim();
      final stops = <LocationPlanModel>[];
      final rawStops = entry['stops'];
      if (rawStops is List) {
        for (final stop in rawStops) {
          if (stop is! Map) {
            continue;
          }
          final name = (stop['name'] as Object?)?.toString().trim();
          if (name == null || name.isEmpty) {
            continue;
          }
          stops.add(
            LocationPlanModel(
              name: name,
              completed: false,
              placeId: '',
              description: (stop['description'] as Object?)?.toString().trim() ?? '',
            ),
          );
        }
      }

      plans.add(
        DailyPlanModel(
          title: (title == null || title.isEmpty) ? 'Day ${plans.length + 1}' : title,
          location: (location == null || location.isEmpty) ? draft.destination : location,
          plan: PlanModel(favorited: const [], locations: stops),
        ),
      );
    }

    return plans;
  }

  /// Gemini often wraps JSON in ```json … ``` fences despite instructions.
  String _stripCodeFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trim();
      }
    }
    return text;
  }
}
