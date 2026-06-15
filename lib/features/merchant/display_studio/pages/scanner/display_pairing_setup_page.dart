import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../../services/display_studio_service.dart';

class DisplayPairingSetupPage extends StatefulWidget {
  const DisplayPairingSetupPage({
    super.key,
    required this.service,
    required this.pairingId,
    required this.token,
    required this.sessionData,
  });

  final DisplayStudioService service;
  final String pairingId;
  final String token;
  final Map<String, dynamic> sessionData;

  @override
  State<DisplayPairingSetupPage> createState() =>
      _DisplayPairingSetupPageState();
}

class _DisplayPairingSetupPageState extends State<DisplayPairingSetupPage> {
  final _nameCtrl = TextEditingController();

  String _deviceType = 'Android TV';
  String _orientation = 'landscape';
  double _screenSizeInch = 43;
  String _resolution = 'Full HD';
  bool _isSaving = false;

  static const _deviceTypes = [
    'Android TV',
    'Fire TV',
    'Android Box',
    'Tablet',
    'Monitor',
    'Beamer',
    'Other',
  ];

  static const _resolutions = ['HD', 'Full HD', '4K', 'Other'];
  static const _orientations = ['landscape', 'portrait'];

  @override
  void initState() {
    super.initState();
    _prefillFromSession();
  }

  void _prefillFromSession() {
    final info = _asMap(widget.sessionData['deviceInfo']);
    if (info == null) return;

    final name = info['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      _nameCtrl.text = name;
    }

    final deviceType = info['deviceType']?.toString().trim();
    if (deviceType != null && _deviceTypes.contains(deviceType)) {
      _deviceType = deviceType;
    }

    final orientation = info['orientation']?.toString().trim();
    if (orientation != null && _orientations.contains(orientation)) {
      _orientation = orientation;
    }

    final screenSize = info['screenSizeInch'];
    if (screenSize is num) {
      _screenSizeInch = screenSize.toDouble().clamp(15, 100);
    }

    final resolution = info['resolution']?.toString().trim();
    if (resolution != null && _resolutions.contains(resolution)) {
      _resolution = resolution;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.sessionData['code']?.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Display verbinden',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR-Code erkannt!',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      Text(
                        code != null && code.isNotEmpty
                            ? 'Pairing-Code: $code'
                            : 'Gib deinem Display einen Namen und bestätige.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          _Section('Display-Daten', [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_isSaving) _confirm();
              },
              decoration: InputDecoration(
                labelText: 'Display-Name',
                hintText: 'z.B. Kasse Eingang, Theke Links',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DropField(
              label: 'Gerätetyp',
              value: _deviceType,
              options: _deviceTypes,
              onChanged: (v) => setState(() => _deviceType = v),
            ),
          ]),

          const SizedBox(height: AppSpacing.md),

          _Section('Anzeige', [
            const Text(
              'Ausrichtung',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _OrientChip(
                  label: 'Querformat',
                  icon: Icons.stay_current_landscape_rounded,
                  selected: _orientation == 'landscape',
                  onTap: () => setState(() => _orientation = 'landscape'),
                ),
                const SizedBox(width: 8),
                _OrientChip(
                  label: 'Hochformat',
                  icon: Icons.stay_current_portrait_rounded,
                  selected: _orientation == 'portrait',
                  onTap: () => setState(() => _orientation = 'portrait'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bildschirmgröße: ${_screenSizeInch.toStringAsFixed(0)}"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gray500,
                        ),
                      ),
                      Slider(
                        value: _screenSizeInch,
                        min: 15,
                        max: 100,
                        divisions: 85,
                        activeColor: AppColors.black,
                        label: '${_screenSizeInch.toStringAsFixed(0)}"',
                        onChanged: (v) => setState(() => _screenSizeInch = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: _DropField(
                    label: 'Auflösung',
                    value: _resolution,
                    options: _resolutions,
                    onChanged: (v) => setState(() => _resolution = v),
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _isSaving ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            )
                : const Text(
              'Display hinzufügen',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Bitte einen Namen für das Display eingeben.');
      return;
    }

    final validationError = _validateSessionBeforeClaim();
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.service.claimPairingAndCreateDevice(
        pairingId: widget.pairingId,
        token: widget.token,
        deviceName: name,
        deviceType: _deviceType,
        orientation: _orientation,
        screenSizeInch: _screenSizeInch,
        resolution: _resolution,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" wurde verbunden! ✓'),
          backgroundColor: const Color(0xFF065F46),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      _showSnack(
        'Fehler: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  String? _validateSessionBeforeClaim() {
    if (widget.pairingId.trim().isEmpty) {
      return 'Pairing-ID fehlt.';
    }

    if (widget.token.trim().isEmpty) {
      return 'Sicherheits-Token fehlt.';
    }

    final status = widget.sessionData['status']?.toString();
    final claimed = widget.sessionData['claimed'] as bool? ?? false;

    if (claimed || status == 'claimed') {
      return 'Dieser Code wurde bereits verwendet.';
    }

    final sessionToken = widget.sessionData['token']?.toString();
    if (sessionToken != null &&
        sessionToken.isNotEmpty &&
        sessionToken != widget.token) {
      return 'Sicherheits-Token stimmt nicht überein.';
    }

    final expiresAt = _parseDateTime(widget.sessionData['expiresAt']);
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return 'Code ist abgelaufen. Bitte am Fernseher einen neuen QR anzeigen.';
    }

    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _DropField extends StatelessWidget {
  const _DropField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.contains(value) ? value : options.first;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      items: options
          .map(
            (o) => DropdownMenuItem(
          value: o,
          child: Text(o),
        ),
      )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _OrientChip extends StatelessWidget {
  const _OrientChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.black : AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.black : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.white : AppColors.gray500,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.white : AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;

  if (value is Map) {
    return value.map(
          (key, val) => MapEntry(key.toString(), val),
    );
  }

  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  try {
    final dynamic dynamicValue = value;
    final converted = dynamicValue.toDate();

    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    return null;
  }

  return null;
}