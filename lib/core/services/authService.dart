import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  static bool _googleInitialized = false;

  static Future<void> configurePersistence() async {
    if (!kIsWeb) return;
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  /// Frictionless sign-in for the NFC stamp tap: if nobody is logged in, attach
  /// the stamp to a fresh anonymous account (later linkable). Anonymous auth is
  /// enabled in firebase.json.
  Future<User?> ensureSignedIn() async {
    final existing = _firebaseAuth.currentUser;
    if (existing != null) return existing;
    final cred = await _firebaseAuth.signInAnonymously();
    return cred.user;
  }

  Future<UserCredential> signInUserWithEmail({
    required String email,
    required String password,
  }) =>
      _signInWithEmail(email: email, password: password);

  Future<UserCredential> signInMerchantWithEmail({
    required String email,
    required String password,
  }) =>
      _signInWithEmail(email: email, password: password);

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _signInWithEmail(email: email, password: password);

  Future<UserCredential> registerUserWithEmail({
    required String email,
    required String password,
  }) =>
      _registerWithEmail(email: email, password: password);

  Future<UserCredential> registerMerchantWithEmail({
    required String email,
    required String password,
  }) =>
      _registerWithEmail(email: email, password: password);

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _registerWithEmail(email: email, password: password);

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _firebaseAuth.signInWithPopup(GoogleAuthProvider());
    }

    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'google-unsupported',
        message: 'Google Anmeldung ist auf dieser Plattform nicht verfügbar.',
      );
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<User?> reloadCurrentUser() async {
    await currentUser?.reload();
    return _firebaseAuth.currentUser;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  /// Re-authenticates with email+password, then updates to [newPassword].
  Future<void> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Kein Benutzer eingeloggt.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Starts SMS verification for [phoneNumber] and reports a
  /// [PhoneVerificationSession] via [onCodeSent].
  ///
  /// Web and mobile use different Firebase APIs: on **web** phone auth requires
  /// a reCAPTCHA app-verifier — we use `linkWithPhoneNumber`/`signInWithPhoneNumber`
  /// (invisible reCAPTCHA, auto-created by FlutterFire) instead of the
  /// mobile-only `verifyPhoneNumber`, which produces "invalid application
  /// verifier / reCAPTCHA token invalid" on web.
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(PhoneVerificationSession session) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    if (kIsWeb) {
      try {
        final user = currentUser;
        final ConfirmationResult confirmation = user != null
            ? await user.linkWithPhoneNumber(phoneNumber)
            : await _firebaseAuth.signInWithPhoneNumber(phoneNumber);
        onCodeSent(PhoneVerificationSession._(confirmation: confirmation));
      } on FirebaseAuthException catch (e) {
        onVerificationFailed(e);
      }
      return;
    }

    // Mobile (iOS/Android): native flow, no reCAPTCHA needed.
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) => onAutoVerified?.call(credential),
      verificationFailed: onVerificationFailed,
      codeSent: (verificationId, _) =>
          onCodeSent(PhoneVerificationSession._(verificationId: verificationId)),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Confirms [smsCode] for [session] and links the phone to the current user.
  /// Works on both web (ConfirmationResult) and mobile (verificationId).
  Future<void> confirmPhoneCode({
    required PhoneVerificationSession session,
    required String smsCode,
  }) async {
    // Web: complete the linkWithPhoneNumber / signInWithPhoneNumber flow.
    final confirmation = session.confirmation;
    if (confirmation != null) {
      try {
        await confirmation.confirm(smsCode);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'provider-already-linked') rethrow;
      }
      return;
    }

    // Mobile: build the credential and link it (re-auth if already linked).
    final verificationId = session.verificationId;
    if (verificationId == null) {
      throw FirebaseAuthException(
        code: 'invalid-verification-session',
        message: 'Keine aktive Verifizierung.',
      );
    }
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Kein Benutzer eingeloggt.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        await user.reauthenticateWithCredential(credential);
      } else {
        rethrow;
      }
    }
  }

  Future<UserCredential> _signInWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> _registerWithEmail({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }
}

/// An in-progress phone verification. Holds either a mobile [verificationId]
/// (native flow) or a web [confirmation] (reCAPTCHA flow) — never both.
class PhoneVerificationSession {
  const PhoneVerificationSession._({this.verificationId, this.confirmation});

  final String? verificationId;
  final ConfirmationResult? confirmation;
}
