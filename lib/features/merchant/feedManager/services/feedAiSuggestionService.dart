import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/environmentConfig.dart';
import '../models/feedAiSuggestionModel.dart';

class FeedAiSuggestionService {
  const FeedAiSuggestionService({
    http.Client? client,
  }) : _client = client;

  final http.Client? _client;

  /// Hartkodierte deutsche Anweisung für die reine Korrektur-Funktion.
  /// Wichtig: Inhalt bleibt identisch, nur Rechtschreibung/Grammatik/Stil.
  static const String _correctionInstruction =
      'Korrigiere nur Rechtschreibung, Grammatik und Stil der folgenden drei '
      'Felder eines Shop-Beitrags. Behalte den Inhalt exakt identisch, '
      'übertreibe nicht und ändere nicht den Sinn. Gib ausschließlich die '
      'korrigierten Felder zurück.';

  /// Schickt die drei Basisfelder (Titel/Untertitel/Beschreibung) an das
  /// bestehende KI-Endpoint und gibt die korrigierte Variante zurück.
  ///
  /// Wirft bei leerer Antwort oder Endpoint-Fehler – der Aufrufer behandelt
  /// das graceful (Hinweis anzeigen, Felder NICHT leeren, nicht zählen).
  Future<FeedAiSuggestionModel> correctFields({
    required String merchantId,
    required String type,
    required String title,
    required String subtitle,
    required String description,
    required Map<String, dynamic> merchant,
  }) async {
    final endpoint = EnvironmentConfig.aiSuggestionEndpoint.trim();
    if (endpoint.isEmpty) {
      throw StateError('merchant.feedCreate.aiEndpointMissing');
    }

    final client = _client ?? http.Client();
    final response = await client.post(
      Uri.parse(endpoint),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'merchantId': merchantId,
        'type': type,
        'mode': 'correct',
        'instruction': _correctionInstruction,
        'input': _correctionInstruction,
        'fields': {
          'title': title,
          'subtitle': subtitle,
          'description': description,
        },
        'merchant': {
          'shopName': merchant['shopName'] ?? merchant['businessName'] ?? '',
          'area': merchant['area'] ?? '',
          'shopType': merchant['shopType'] ?? merchant['shopTypePrimary'] ?? '',
          'description': merchant['description'] ?? '',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('merchant.feedCreate.aiFailed');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('merchant.feedCreate.aiFailed');
    }
    final suggestion = decoded['suggestion'] is Map
        ? Map<String, dynamic>.from(decoded['suggestion'] as Map)
        : decoded;
    final model = FeedAiSuggestionModel.fromMap(suggestion);
    // Leere Antwort -> als Fehler behandeln, damit nichts geleert wird.
    if (model.title.trim().isEmpty &&
        model.subtitle.trim().isEmpty &&
        model.description.trim().isEmpty) {
      throw StateError('merchant.feedCreate.aiFailed');
    }
    return model;
  }

  Future<FeedAiSuggestionModel> suggest({
    required String merchantId,
    required String type,
    required String input,
    required Map<String, dynamic> merchant,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> items,
  }) async {
    final endpoint = EnvironmentConfig.aiSuggestionEndpoint.trim();
    if (endpoint.isEmpty) {
      throw StateError('merchant.feedCreate.aiEndpointMissing');
    }

    final client = _client ?? http.Client();
    final response = await client.post(
      Uri.parse(endpoint),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'merchantId': merchantId,
        'type': type,
        'input': input,
        'merchant': {
          'shopName': merchant['shopName'] ?? merchant['businessName'] ?? '',
          'area': merchant['area'] ?? '',
          'shopType': merchant['shopType'] ?? merchant['shopTypePrimary'] ?? '',
          'description': merchant['description'] ?? '',
        },
        'categories': categories.take(12).toList(),
        'items': items.take(18).toList(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('merchant.feedCreate.aiFailed');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('merchant.feedCreate.aiFailed');
    }
    final suggestion = decoded['suggestion'] is Map
        ? Map<String, dynamic>.from(decoded['suggestion'] as Map)
        : decoded;
    return FeedAiSuggestionModel.fromMap(suggestion);
  }
}
