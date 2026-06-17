/// Ein Runner (Servicekraft) im Runner-Modus: Name + Verfügbarkeit. Wird im
/// publicMerchants-Dokument als Liste gespeichert, damit das Bestell-Gerät im
/// Shop die verfügbaren Runner direkt zur Auswahl anzeigen kann (kein PIN mehr).
class RunnerData {
  const RunnerData({
    required this.id,
    required this.name,
    this.available = true,
  });

  final String id;
  final String name;

  /// Steht der Runner gerade zur Auswahl (verfügbar) oder nicht.
  final bool available;

  factory RunnerData.fromMap(Map<String, dynamic> map) {
    final rawAvailable = map['available'];
    return RunnerData(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      // Alt-Dokumente (noch mit PIN, ohne Feld) gelten als verfügbar.
      available: rawAvailable is bool ? rawAvailable : true,
    );
  }

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'available': available};

  RunnerData copyWith({String? name, bool? available}) => RunnerData(
        id: id,
        name: name ?? this.name,
        available: available ?? this.available,
      );

  static List<RunnerData> listFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    final result = <RunnerData>[];
    for (final item in raw) {
      if (item is Map) {
        result.add(RunnerData.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }
}
