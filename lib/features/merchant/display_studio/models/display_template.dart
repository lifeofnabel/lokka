import 'package:flutter/material.dart';

import 'display_layout.dart';

class DisplayTemplate {
  const DisplayTemplate({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.defaultBlocks,
    this.defaultOrientation = DisplayOrientation.landscape,
    this.defaultMode = 'day',
    this.defaultAnimation = 'fade',
  });

  final String id;
  final DisplayLayoutType type;
  final String name;
  final String description;
  final IconData icon;

  /// Pre-built block maps (no IDs yet — IDs are assigned on creation)
  final List<Map<String, dynamic>> defaultBlocks;

  final DisplayOrientation defaultOrientation;
  final String defaultMode;
  final String defaultAnimation;
}
