import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/services/postalCodeService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';

class ProfilePersonalDataPage extends StatefulWidget {
  const ProfilePersonalDataPage({super.key, required this.user});

  final AppUserModel user;

  @override
  State<ProfilePersonalDataPage> createState() =>
      _ProfilePersonalDataPageState();
}

class _ProfilePersonalDataPageState extends State<ProfilePersonalDataPage> {
  late final UserProfileService _profileService;
  final PostalCodeService _plzService = PostalCodeService();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _plzCtrl;
  DateTime? _birthday;

  bool _saving = false;
  bool _plzLoaded = false;
  String? _cityName;

  @override
  void initState() {
    super.initState();
    _profileService = UserProfileService(
      firestoreService: context.read<FirestoreService>(),
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _firstNameCtrl = TextEditingController(text: widget.user.firstName);
    _lastNameCtrl = TextEditingController(text: widget.user.lastName);
    _plzCtrl = TextEditingController(text: widget.user.postalCode ?? '');
    _birthday = widget.user.birthday;
    _loadPlz();
  }

  Future<void> _loadPlz() async {
    await _plzService.loadAll();
    setState(() {
      _plzLoaded = true;
      final entry = _plzService.findByPostalCode(_plzCtrl.text);
      _cityName = entry?.placeName;
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _plzCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.updatePersonalData({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'postalCode': _plzCtrl.text.trim(),
        if (_birthday != null) 'birthday': _birthday!.toIso8601String(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Persönliche Daten'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Speichern'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Vorname', _firstNameCtrl),
            const SizedBox(height: AppSpacing.md),
            _field('Nachname', _lastNameCtrl),
            const SizedBox(height: AppSpacing.md),
            if (_plzLoaded)
              _PlzField(
                controller: _plzCtrl,
                plzService: _plzService,
                cityName: _cityName,
                onPlzChanged: (entry) {
                  setState(() => _cityName = entry?.placeName);
                },
              )
            else
              _field('PLZ', _plzCtrl),
            const SizedBox(height: AppSpacing.md),
            _ReadonlyField(
              label: 'Telefon',
              value: widget.user.phone ?? '–',
              hint: 'Unter Sicherheit verifizieren',
            ),
            const SizedBox(height: AppSpacing.md),
            _BirthdayField(
              birthday: _birthday,
              onTap: _pickBirthday,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: label),
        ),
      ],
    );
  }
}

class _PlzField extends StatelessWidget {
  const _PlzField({
    required this.controller,
    required this.plzService,
    required this.cityName,
    required this.onPlzChanged,
  });

  final TextEditingController controller;
  final PostalCodeService plzService;
  final String? cityName;
  final void Function(PostalCodeEntry? entry) onPlzChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('PLZ'),
        const SizedBox(height: 6),
        Autocomplete<PostalCodeEntry>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (value) {
            if (value.text.length < 2) return const [];
            return plzService.suggestions(value.text, max: 5);
          },
          displayStringForOption: (e) => e.postalCode,
          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
            controller.text = ctrl.text;
            return TextField(
              controller: ctrl,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'PLZ',
                suffixText: cityName,
              ),
              onChanged: (v) {
                final entry = plzService.findByPostalCode(v);
                onPlzChanged(entry);
              },
            );
          },
          onSelected: (entry) {
            controller.text = entry.postalCode;
            onPlzChanged(entry);
          },
        ),
      ],
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BirthdayField extends StatelessWidget {
  const _BirthdayField({required this.birthday, required this.onTap});

  final DateTime? birthday;
  final VoidCallback onTap;

  String get _display {
    if (birthday == null) return 'Nicht angegeben';
    return '${birthday!.day.toString().padLeft(2, '0')}.${birthday!.month.toString().padLeft(2, '0')}.${birthday!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Geburtstag'),
        const SizedBox(height: 6),
        Material(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Text(
                    _display,
                    style: tt.bodyLarge?.copyWith(
                      color: birthday == null
                          ? cs.onSurfaceVariant
                          : cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
    );
  }
}
