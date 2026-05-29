class CampaignEntryModel {
  const CampaignEntryModel({
    required this.id,
  });

  final String id;

  factory CampaignEntryModel.fromMap(Map<String, dynamic> map) {
    return CampaignEntryModel(
      id: map['id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
    };
  }
}

