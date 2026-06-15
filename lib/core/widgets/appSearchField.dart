import 'package:flutter/material.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';

/// Einheitliches Suchfeld für den gesamten User-Bereich.
///
/// Unterstützt sowohl Live-Suche ([onChanged]) als auch Suche bei Enter
/// ([onSubmitted]). Der Clear-Button erscheint automatisch, sobald Text
/// vorhanden ist. Ein eigener [controller] kann übergeben werden; sonst
/// verwaltet das Feld seinen eigenen.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Suchen…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final TextInputAction textInputAction;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasText = _controller.text.isNotEmpty;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: widget.textInputAction,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        prefixIcon: Icon(Icons.search_rounded,
            color: cs.onSurfaceVariant, size: 20),
        suffixIcon: hasText
            ? IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.clear_rounded, size: 18),
                color: cs.onSurfaceVariant,
                tooltip: 'Leeren',
                visualDensity: VisualDensity.compact,
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceGray,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(cs.primary, 1.5),
      ),
    );
  }
}
