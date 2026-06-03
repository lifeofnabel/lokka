import 'package:cloud_firestore/cloud_firestore.dart';

enum DisplayDeviceStatus {
  online,
  offline,
  playing,
  stopped,
  error;

  String get label {
    switch (this) {
      case online:
        return 'Online';
      case offline:
        return 'Offline';
      case playing:
        return 'Läuft';
      case stopped:
        return 'Gestoppt';
      case error:
        return 'Fehler';
    }
  }

  static DisplayDeviceStatus fromString(String? value) {
    return DisplayDeviceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DisplayDeviceStatus.offline,
    );
  }
}

enum DisplayDeviceCommand {
  startLayout,
  stopPlayback,
  unlink,
  refresh,
  clearCache;

  static DisplayDeviceCommand? fromString(String? value) {
    if (value == null) return null;
    return DisplayDeviceCommand.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DisplayDeviceCommand.refresh,
    );
  }
}

class DisplayDevice {
  const DisplayDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.orientation,
    required this.screenSizeInch,
    required this.resolution,
    required this.activeLayoutId,
    required this.activeLayoutTitle,
    required this.status,
    required this.lastSeenAt,
    required this.pairedAt,
    required this.isLinked,
    this.command,
  });

  final String id;
  final String name;
  final String deviceType;
  final String orientation;
  final double screenSizeInch;
  final String resolution;
  final String activeLayoutId;
  final String activeLayoutTitle;
  final DisplayDeviceStatus status;
  final DateTime? lastSeenAt;
  final DateTime? pairedAt;
  final bool isLinked;
  final String? command;

  factory DisplayDevice.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return DisplayDevice.fromMap(map, id: doc.id);
  }

  factory DisplayDevice.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return DisplayDevice(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? 'Display',
      deviceType: map['deviceType'] as String? ?? 'tv',
      orientation: map['orientation'] as String? ?? 'landscape',
      screenSizeInch: (map['screenSizeInch'] as num?)?.toDouble() ?? 0.0,
      resolution: map['resolution'] as String? ?? '',
      activeLayoutId: map['activeLayoutId'] as String? ?? '',
      activeLayoutTitle: map['activeLayoutTitle'] as String? ?? '',
      status: DisplayDeviceStatus.fromString(map['status'] as String?),
      lastSeenAt: (map['lastSeenAt'] as Timestamp?)?.toDate(),
      pairedAt: (map['pairedAt'] as Timestamp?)?.toDate(),
      isLinked: map['isLinked'] as bool? ?? false,
      command: map['command'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'deviceType': deviceType,
        'orientation': orientation,
        'screenSizeInch': screenSizeInch,
        'resolution': resolution,
        'activeLayoutId': activeLayoutId,
        'activeLayoutTitle': activeLayoutTitle,
        'status': status.name,
        'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : null,
        'pairedAt': pairedAt != null ? Timestamp.fromDate(pairedAt!) : null,
        'isLinked': isLinked,
        'command': command,
      };

  DisplayDevice copyWith({
    String? name,
    String? activeLayoutId,
    String? activeLayoutTitle,
    DisplayDeviceStatus? status,
    String? command,
  }) {
    return DisplayDevice(
      id: id,
      name: name ?? this.name,
      deviceType: deviceType,
      orientation: orientation,
      screenSizeInch: screenSizeInch,
      resolution: resolution,
      activeLayoutId: activeLayoutId ?? this.activeLayoutId,
      activeLayoutTitle: activeLayoutTitle ?? this.activeLayoutTitle,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt,
      pairedAt: pairedAt,
      isLinked: isLinked,
      command: command ?? this.command,
    );
  }
}
