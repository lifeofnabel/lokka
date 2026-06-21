import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/geoapifyService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/core/widgets/appButton.dart';
import 'package:lokka/core/widgets/appLoadingState.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';

/// Onboarding-Survey: fragt einmalig (gated) die Interessen ab und lässt sie
/// später über das Profil ([isEditMode]) erneut anpassen.
class OnboardingSurveyPage extends StatefulWidget {
  const OnboardingSurveyPage({
    super.key,
    this.isEditMode = false,
    this.initialCategories = const [],
    this.onCompleted,
  });

  final bool isEditMode;
  final List<String> initialCategories;

  /// Wird nach erfolgreichem Speichern im Onboarding-Modus aufgerufen.
  /// Im Edit-Modus wird stattdessen die Seite gepoppt.
  final VoidCallback? onCompleted;

  @override
  State<OnboardingSurveyPage> createState() => _OnboardingSurveyPageState();
}

class _OnboardingSurveyPageState extends State<OnboardingSurveyPage> {
  /// Feste Beitrags-Typen, nach denen der Feed personalisiert wird.
  static const _postTypeOptions = [
    'Aktion 1+1',
    'Aktion 1+2',
    'Retter-Deal',
    'Angebote',
    'Happy Hour',
    'Events',
    'Jobs',
  ];

  late final FirestoreService _firestoreService;
  late final UserProfileService _profileService;
  final _geo = GeoapifyService();

  List<String> _categoryOptions = [];
  List<String> _originOptions = [];
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedOrigins = {};
  final Set<String> _selectedPostTypes = {};

  /// Orte des Users: {label, street, postalCode, city, district, lat, lng}.
  final List<Map<String, dynamic>> _places = [];
  final _placeCtrl = TextEditingController();
  Timer? _placeDebounce;
  List<GeoResult> _placeSuggestions = [];
  bool _placeLoading = false;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firestoreService = context.read<FirestoreService>();
    _profileService = UserProfileService(
      firestoreService: _firestoreService,
      authService: context.read<AuthService>(),
      cacheService: context.read<LocalCacheService>(),
    );
    _selectedCategories.addAll(widget.initialCategories);
    _load();
  }

  @override
  void dispose() {
    _placeDebounce?.cancel();
    _placeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _firestoreService.loadChooserShopTypes(),
        _firestoreService.loadChooserOrigins(),
      ]);
      // Im Edit-Modus die neuen Felder aus dem Profil vorbelegen (Kategorien
      // kommen weiterhin vom Aufrufer über initialCategories).
      AppUserModel? user;
      if (widget.isEditMode) {
        try {
          user = await _profileService.profileStream().first;
        } catch (_) {
          user = null;
        }
      }
      if (mounted) {
        setState(() {
          _categoryOptions = results[0];
          _originOptions = results[1];
          if (user != null) {
            _selectedOrigins.addAll(user.interestOrigins);
            _selectedPostTypes.addAll(user.interestPostTypes);
            _places.addAll(
              user.interestPlaces.map((p) => Map<String, dynamic>.from(p)),
            );
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  void _onPlaceQueryChanged(String text) {
    _placeDebounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        _placeSuggestions = [];
        _placeLoading = false;
      });
      return;
    }
    _placeDebounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _placeLoading = true);
      final res = await _geo.autocomplete(
        text,
        filterRect: GeoapifyService.hessenRect,
      );
      if (!mounted) return;
      setState(() {
        _placeSuggestions = res;
        _placeLoading = false;
      });
    });
  }

  void _addPlace(GeoResult g) {
    final place = <String, dynamic>{
      'label': g.formatted,
      'street': g.street,
      'postalCode': g.postalCode,
      'city': g.city,
      'district': g.district,
      'lat': g.lat,
      'lng': g.lng,
    };
    setState(() {
      final exists = _places.any((p) => p['label'] == place['label']);
      if (!exists) _places.add(place);
      _placeCtrl.clear();
      _placeSuggestions = [];
      _placeLoading = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _removePlace(int index) {
    setState(() => _places.removeAt(index));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profileService.saveInterests(
        categories: _selectedCategories.toList(),
        origins: _selectedOrigins.toList(),
        postTypes: _selectedPostTypes.toList(),
        places: List<Map<String, dynamic>>.from(_places),
      );
      if (!mounted) return;
      if (widget.isEditMode) {
        Navigator.pop(context);
      } else {
        widget.onCompleted?.call();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speichern fehlgeschlagen. Bitte erneut.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: widget.isEditMode
          ? AppBar(
              backgroundColor: AppColors.surfaceBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Text(
                'Interessen anpassen',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: _loading
          ? const AppLoadingState()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        if (!widget.isEditMode) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const _WelcomeHeader(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (_categoryOptions.isNotEmpty) ...[
                          _Section(
                            title: 'Welche Läden magst du?',
                            options: _categoryOptions,
                            selected: _selectedCategories,
                            onToggle: (v) => _toggle(_selectedCategories, v),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        if (_originOptions.isNotEmpty) ...[
                          _Section(
                            title: 'Herkunft & Küche',
                            options: _originOptions,
                            selected: _selectedOrigins,
                            onToggle: (v) => _toggle(_selectedOrigins, v),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        _Section(
                          title: 'Was interessiert dich?',
                          options: _postTypeOptions,
                          selected: _selectedPostTypes,
                          onToggle: (v) => _toggle(_selectedPostTypes, v),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _PlacesSection(
                          controller: _placeCtrl,
                          places: _places,
                          suggestions: _placeSuggestions,
                          loading: _placeLoading,
                          onChanged: _onPlaceQueryChanged,
                          onPick: _addPlace,
                          onRemove: _removePlace,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: _saving
                            ? 'Speichern…'
                            : (widget.isEditMode ? 'Speichern' : 'Los geht\'s'),
                        icon: widget.isEditMode ? null : Icons.arrow_forward_rounded,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.waving_hand_rounded,
              color: cs.onSecondaryContainer, size: 32),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Willkommen bei Lokka',
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Womit fangen wir an?',
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map((o) {
            return _InterestChip(
              label: o,
              selected: selected.contains(o),
              onTap: () => onToggle(o),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: selected ? cs.secondaryContainer : AppColors.surfaceGray,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.onSecondaryContainer : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// „Deine Orte": Adress-Suche (Geoapify-Autocomplete) + entfernbare Orts-Chips.
class _PlacesSection extends StatelessWidget {
  const _PlacesSection({
    required this.controller,
    required this.places,
    required this.suggestions,
    required this.loading,
    required this.onChanged,
    required this.onPick,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<Map<String, dynamic>> places;
  final List<GeoResult> suggestions;
  final bool loading;
  final ValueChanged<String> onChanged;
  final ValueChanged<GeoResult> onPick;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deine Orte',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Damit zeigen wir dir, was in deiner Nähe los ist.',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (places.isNotEmpty) ...[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < places.length; i++)
                _PlaceChip(
                  label: (places[i]['label'] ?? '').toString(),
                  onRemove: () => onRemove(i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Adresse oder Ort suchen…',
            hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            prefixIcon: Icon(
              Icons.add_location_alt_outlined,
              color: cs.onSurfaceVariant,
            ),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 48),
            filled: true,
            fillColor: AppColors.surfaceGray,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: cs.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < suggestions.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: cs.outlineVariant),
                  ListTile(
                    leading: Icon(
                      Icons.place_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    title: Text(
                      suggestions[i].formatted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => onPick(suggestions[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.secondaryContainer,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 2),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(100),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: cs.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
