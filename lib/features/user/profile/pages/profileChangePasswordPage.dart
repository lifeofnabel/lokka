import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';

class ProfileChangePasswordPage extends StatefulWidget {
  const ProfileChangePasswordPage({super.key});

  @override
  State<ProfileChangePasswordPage> createState() =>
      _ProfileChangePasswordPageState();
}

class _ProfileChangePasswordPageState
    extends State<ProfileChangePasswordPage> {
  late final AuthService _authService;

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Bitte alle Felder ausfüllen.');
      return;
    }
    if (next.length < 6) {
      setState(() =>
          _error = 'Das neue Passwort muss mindestens 6 Zeichen lang sein.');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'Die Passwörter stimmen nicht überein.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await _authService.reauthenticateAndChangePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort erfolgreich geändert.')),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendly(e);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _friendly(FirebaseAuthException e) {
    return switch (e.code) {
      'wrong-password' || 'invalid-credential' =>
        'Aktuelles Passwort ist falsch.',
      'weak-password' => 'Das neue Passwort ist zu schwach.',
      'requires-recent-login' =>
        'Bitte melde dich erneut an und versuche es noch einmal.',
      _ => 'Fehler: ${e.message ?? e.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Passwort ändern'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Icon(Icons.lock_reset_rounded,
                  size: 36, color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Neues Passwort setzen',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Gib zuerst dein aktuelles Passwort ein, dann das neue.',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _FieldLabel('Aktuelles Passwort'),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _currentCtrl,
              hint: '••••••••',
              visible: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Neues Passwort'),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _newCtrl,
              hint: 'Mindestens 6 Zeichen',
              visible: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: AppSpacing.md),
            const _FieldLabel('Neues Passwort bestätigen'),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _confirmCtrl,
              hint: '••••••••',
              visible: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorBox(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Passwort ändern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.visible,
    required this.onToggle,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
          ),
        ),
      ),
    );
  }
}
