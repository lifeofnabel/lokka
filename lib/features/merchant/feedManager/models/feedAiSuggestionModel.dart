class FeedAiSuggestionModel {
  const FeedAiSuggestionModel({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.ctaLabel,
    required this.reason,
  });

  final String type;
  final String title;
  final String subtitle;
  final String description;
  final String ctaLabel;
  final String reason;

  factory FeedAiSuggestionModel.fromMap(Map<String, dynamic> map) {
    return FeedAiSuggestionModel(
      type: (map['type'] ?? 'offer').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      ctaLabel: (map['ctaLabel'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
    );
  }
}
