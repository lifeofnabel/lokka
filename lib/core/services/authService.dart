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

  /// Sends an SMS verification code to [phoneNumber].
  /// Mobile only (iOS + Android). No reCAPTCHA needed.
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) {
        onAutoVerified?.call(credential);
      },
      verificationFailed: onVerificationFailed,
      codeSent: (verificationId, resendToken) {
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Links the current user's account with the phone credential.
  /// Handles the case where the phone is already linked (re-auth).
  Future<void> verifyPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
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
