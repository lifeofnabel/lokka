import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/services/postalCodeService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';

/// Persönliche Daten — der Nutzer kann Name und Adresse jederzeit bearbeiten.
/// (Geburtstag wird hier bewusst nicht mehr geführt; Telefon nur als Hinweis
/// auf die separate Verifizierung.)
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
    _loadPlz();
  }

  Future<void> _loadPlz() async {
    await _plzService.loadAll();
    if (!mounted) return;
    setState(() {
      _plzLoaded = true;
      _cityName = _plzService.findByPostalCode(_plzCtrl.text)?.placeName;
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _plzCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.updatePersonalData({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'postalCode': _plzCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Persönliche Daten')),
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
                onPlzChanged: (entry) =>
                    setState(() => _cityName = entry?.placeName),
              )
            else
              _field('PLZ', _plzCtrl),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Speichern'),
              ),
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
              decoration: InputDecoration(hintText: 'PLZ', suffixText: cityName),
              onChanged: (v) => onPlzChanged(plzService.findByPostalCode(v)),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(text, style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant));
  }
}
