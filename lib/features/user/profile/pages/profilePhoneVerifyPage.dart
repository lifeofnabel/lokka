import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lokka/core/models/appUserModel.dart';
import 'package:lokka/core/services/authService.dart';
import 'package:lokka/core/services/firestoreService.dart';
import 'package:lokka/core/services/localCacheService.dart';
import 'package:lokka/core/theme/appColors.dart';
import 'package:lokka/core/theme/appRadius.dart';
import 'package:lokka/core/theme/appSpacing.dart';
import 'package:lokka/features/user/profile/services/userProfileService.dart';

class ProfilePhoneVerifyPage extends StatefulWidget {
  const ProfilePhoneVerifyPage({super.key, required this.user});

  final AppUserModel user;

  @override
  State<ProfilePhoneVerifyPage> createState() => _ProfilePhoneVerifyPageState();
}

class _ProfilePhoneVerifyPageState extends State<ProfilePhoneVerifyPage> {
  late final AuthService _authService;
  late final UserProfileService _profileService;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _profileService = UserProfileService(
      firestoreService: context.read<FirestoreService>(),
      authService: _authService,
      cacheService: context.read<LocalCacheService>(),
    );
    // Pre-fill phone if already set
    _phoneCtrl.text = widget.user.phone ?? '';
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Bitte Telefonnummer eingeben.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    await _authService.sendPhoneVerificationCode(
      phoneNumber: phone,
      onCodeSent: (verificationId, _) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _loading = false;
          });
        }
      },
      onVerificationFailed: (e) {
        if (mounted) {
          setState(() {
            _error = _friendlyError(e);
            _loading = false;
          });
        }
      },
      onAutoVerified: (credential) async {
        await _completeVerification(credential: credential);
      },
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _error = 'Bitte 6-stelligen Code eingeben.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _authService.verifyPhoneCode(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _profileService.updatePhoneVerified(_phoneCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() { _error = _friendlyError(e); _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _completeVerification({required PhoneAuthCredential credential}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = _authService.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'provider-already-linked') rethrow;
        }
      }
      await _profileService.updatePhoneVerified(_phoneCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-phone-number' => 'Ungültige Telefonnummer.',
      'too-many-requests' => 'Zu viele Versuche. Bitte warte einen Moment.',
      'invalid-verification-code' => 'Falscher Code. Bitte erneut versuchen.',
      'session-expired' => 'Code abgelaufen. Bitte neuen Code anfordern.',
      _ => 'Fehler: ${e.message ?? e.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surfaceBg,
      appBar: AppBar(title: const Text('Telefon verifizieren')),
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
              child: Icon(Icons.phone_android_rounded,
                  size: 36, color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _codeSent ? 'Code eingeben' : 'Telefonnummer eingeben',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _codeSent
                  ? 'Wir haben einen 6-stelligen Code an ${_phoneCtrl.text} gesendet.'
                  : 'Wir senden dir per SMS einen Code zur Verifizierung.',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_codeSent) ...[
              const _FieldLabel('Telefonnummer (mit Ländercode, z.B. +49...)'),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(hintText: '+49 123 456789'),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _sendCode,
                  child: _loading
                      ? const _Spinner()
                      : const Text('Code senden'),
                ),
              ),
            ] else ...[
              const _FieldLabel('6-stelliger SMS-Code'),
              const SizedBox(height: 6),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '123456',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _verifyCode,
                  child: _loading
                      ? const _Spinner()
                      : const Text('Verifizieren'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _codeCtrl.clear();
                            _error = null;
                          }),
                  child: const Text('Anderen Code anfordern'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}
