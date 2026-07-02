import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/firebasePaths.dart';
import '../../../core/services/authService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../merchant/shared/widgets/merchantPremiumUi.dart';
import '../providers/authProvider.dart';
import '../services/authNavigation.dart';
import '../widgets/authFlowWidgets.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.next});

  final String next;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  String? _statusKey;
  bool _phoneVerified = false;
  String _initialPhone = '';
  bool _phoneStatusLoading = false;

  bool get _isMerchant => widget.next == 'merchant';

  @override
  void initState() {
    super.initState();
    if (_isMerchant) {
      _phoneStatusLoading = true;
      _loadPhoneStatus();
    }
  }

  Future<void> _loadPhoneStatus() async {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) {
      setState(() => _phoneStatusLoading = false);
      return;
    }
    try {
      final doc =
          await context.read<FirestoreService>().getMerchantProfile(uid);
      if (!mounted) return;
      setState(() {
        _initialPhone = (doc?['phone'] as String?) ?? '';
        _phoneVerified = (doc?['phoneVerified'] as bool?) ?? false;
        _phoneStatusLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _phoneStatusLoading = false);
    }
  }

  Future<void> _check() async {
    if (_isMerchant && !_phoneVerified) {
      setState(() => _statusKey = 'auth.email.phoneRequired');
      return;
    }
    final destination = await context.read<AuthProvider>().reloadVerifyAndResolveDestination();
    if (!mounted) return;
    if (destination == null) {
      setState(() => _statusKey = 'auth.email.notYet');
      return;
    }
    context.go(pathForAuthDestination(destination));
  }

  void _continue() {
    if (_isMerchant && !_phoneVerified) {
      setState(() => _statusKey = 'auth.email.phoneRequired');
      return;
    }
    context.go(widget.next == 'merchant' ? '/auth/merchantPending' : '/user/discover');
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final provider = context.watch<AuthProvider>();
    return AuthPageShell(
      titleKey: 'auth.email.title',
      subtitleKey: widget.next == 'merchant'
          ? 'auth.email.merchantSubtitle'
          : 'auth.email.subtitle',
      dark: widget.next == 'merchant',
      icon: Icons.mark_email_read_rounded,
      children: [
        AuthErrorBox(message: provider.error),
        if (_isMerchant) ...[
          if (_phoneStatusLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            _MerchantPhoneVerifyBlock(
              initialPhone: _initialPhone,
              verified: _phoneVerified,
              onVerified: () => setState(() {
                _phoneVerified = true;
                _statusKey = null;
              }),
            ),
          const SizedBox(height: 4),
        ],
        const AuthWarningBox(messageKey: 'auth.email.warning'),
        if (_statusKey != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              texts.text(_statusKey!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        AuthPrimaryButton(
          labelKey: 'auth.email.resend',
          onPressed: () => context.read<AuthProvider>().sendVerificationAgain(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _check,
          child: Text(texts.text('auth.email.checked')),
        ),
        TextButton(
          onPressed: _continue,
          child: Text(texts.text('auth.continue')),
        ),
      ],
    );
  }
}

/// Phone-OTP verification embedded in the merchant email-verification step —
/// the merchant confirms both email and phone here before reaching the
/// dashboard. Mirrors ProfilePhoneVerifyPage's send/confirm flow (Germany
/// only, national digits + fixed +49 prefix).
class _MerchantPhoneVerifyBlock extends StatefulWidget {
  const _MerchantPhoneVerifyBlock({
    required this.initialPhone,
    required this.verified,
    required this.onVerified,
  });

  final String initialPhone;
  final bool verified;
  final VoidCallback onVerified;

  @override
  State<_MerchantPhoneVerifyBlock> createState() =>
      _MerchantPhoneVerifyBlockState();
}

class _MerchantPhoneVerifyBlockState extends State<_MerchantPhoneVerifyBlock> {
  late final AuthService _authService;
  late final FirestoreService _firestoreService;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  PhoneVerificationSession? _session;
  late bool _verified;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _firestoreService = context.read<FirestoreService>();
    _verified = widget.verified;
    final existing = widget.initialPhone.replaceAll(RegExp(r'\s'), '');
    if (existing.startsWith('+49')) {
      _phoneCtrl.text = existing.substring(3);
    } else if (existing.isNotEmpty) {
      _phoneCtrl.text = existing.replaceAll(RegExp(r'[^0-9]'), '');
    }
  }

  String get _national => _phoneCtrl.text
      .replaceAll(RegExp(r'[^0-9]'), '')
      .replaceFirst(RegExp(r'^0+'), '');

  String get _fullPhone => '+49$_national';

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final national = _national;
    if (national.length < 6 || national.length > 12) {
      setState(() => _error = 'Bitte eine gültige deutsche Handynummer eingeben.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await _authService.sendPhoneVerificationCode(
      phoneNumber: _fullPhone,
      onCodeSent: (session) {
        if (!mounted) return;
        setState(() {
          _session = session;
          _codeSent = true;
          _loading = false;
        });
      },
      onVerificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _error = _friendlyError(e);
          _loading = false;
        });
      },
      onAutoVerified: (credential) => _completeWithCredential(credential),
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || _session == null) {
      setState(() => _error = 'Bitte 6-stelligen Code eingeben.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.confirmPhoneCode(session: _session!, smsCode: code);
      await _markVerified();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeWithCredential(PhoneAuthCredential credential) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _authService.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'provider-already-linked') rethrow;
        }
      }
      await _markVerified();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markVerified() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestoreService.updateDocument(FirebasePaths.merchant(uid), {
          'phone': _fullPhone,
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Non-fatal — the phone IS linked to the auth account; a failed
        // Firestore write just means the dashboard re-checks next load.
      }
    }
    if (!mounted) return;
    setState(() {
      _verified = true;
      _loading = false;
    });
    widget.onVerified();
  }

  String _friendlyError(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-phone-number' => 'Ungültige Telefonnummer.',
      'too-many-requests' => 'Zu viele Versuche. Bitte warte einen Moment.',
      'invalid-verification-code' => 'Falscher Code. Bitte erneut versuchen.',
      'session-expired' => 'Code abgelaufen. Bitte neuen Code anfordern.',
      'captcha-check-failed' ||
      'invalid-app-credential' =>
        'Sicherheitsprüfung fehlgeschlagen. Bitte Seite neu laden und erneut versuchen.',
      'credential-already-in-use' =>
        'Diese Nummer ist bereits mit einem anderen Konto verknüpft.',
      'quota-exceeded' || 'billing-not-enabled' =>
        'SMS-Kontingent erschöpft oder Abrechnung nicht aktiv.',
      _ => 'Fehler: ${e.message ?? e.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    if (_verified) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MerchantPremiumColors.goldSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 20, color: MerchantPremiumColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Telefon verifiziert ($_fullPhone)',
                style: tt.bodyMedium
                    ?.copyWith(color: MerchantPremiumColors.ink),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MerchantPremiumColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MerchantPremiumColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  size: 18, color: MerchantPremiumColors.muted),
              const SizedBox(width: 8),
              Text(
                _codeSent ? 'Code eingeben' : 'Telefon verifizieren',
                style: tt.titleSmall
                    ?.copyWith(color: MerchantPremiumColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_codeSent) ...[
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: MerchantPremiumColors.ink),
              decoration: InputDecoration(
                prefixText: '+49 ',
                prefixStyle: const TextStyle(color: MerchantPremiumColors.ink),
                hintText: '151 23456789',
                hintStyle:
                    const TextStyle(color: MerchantPremiumColors.muted),
                filled: true,
                fillColor: MerchantPremiumColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _sendCode,
                child: _loading
                    ? const _InlineSpinner()
                    : const Text('Code senden'),
              ),
            ),
          ] else ...[
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: MerchantPremiumColors.ink),
              decoration: InputDecoration(
                hintText: '123456',
                hintStyle:
                    const TextStyle(color: MerchantPremiumColors.muted),
                counterText: '',
                filled: true,
                fillColor: MerchantPremiumColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _verifyCode,
                child: _loading
                    ? const _InlineSpinner()
                    : const Text('Verifizieren'),
              ),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _codeSent = false;
                        _codeCtrl.clear();
                        _error = null;
                      }),
              child: const Text('Anderen Code anfordern'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: tt.bodySmall?.copyWith(color: MerchantPremiumColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineSpinner extends StatelessWidget {
  const _InlineSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
