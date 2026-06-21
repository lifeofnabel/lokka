import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/firebasePaths.dart';
import '../../../core/models/uploadedMediaModel.dart';
import '../../../core/services/authService.dart';
import '../../../core/services/firebaseService.dart';
import '../../../core/services/firestoreService.dart';
import '../../../core/services/languageService.dart';
import '../../../core/services/uploadService.dart';
import '../../../core/theme/appColors.dart';
import '../../../core/theme/appRadius.dart';
import '../../../core/theme/appSpacing.dart';

class DevFoundationPage extends StatefulWidget {
  const DevFoundationPage({super.key});

  @override
  State<DevFoundationPage> createState() => _DevFoundationPageState();
}

class _DevFoundationPageState extends State<DevFoundationPage> {
  String _firestoreStatus = 'Bereit';
  String? _firestoreError;
  UploadedMediaModel? _uploadedMedia;
  String? _uploadError;
  bool _testingFirestore = false;
  bool _uploading = false;

  Future<void> _testFirestore() async {
    setState(() {
      _testingFirestore = true;
      _firestoreError = null;
      _firestoreStatus = 'Läuft';
    });

    try {
      final firestoreService = context.read<FirestoreService>();
      final path = FirebasePaths.devCheck('foundation');
      await firestoreService.setDocument(path, {
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'devFoundationPage',
      });
      final data = await firestoreService.readDocument(path);
      setState(() {
        _firestoreStatus = data == null
            ? 'Dokument wurde nicht gefunden.'
            : 'Schreiben und Lesen erfolgreich.';
      });
    } catch (error) {
      setState(() {
        _firestoreError = error.toString();
        _firestoreStatus = 'Fehler';
      });
    } finally {
      if (mounted) {
        setState(() => _testingFirestore = false);
      }
    }
  }

  Future<void> _uploadImage() async {
    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadedMedia = null;
    });

    try {
      final uploadService = context.read<UploadService>();
      final media = await uploadService.pickAndUploadImage();
      setState(() {
        _uploadedMedia = media;
        if (media == null) {
          _uploadError = 'Keine Datei ausgewählt.';
        }
      });
    } catch (error) {
      setState(() => _uploadError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.watch<LanguageService>();
    final firebaseService = context.watch<FirebaseService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: Text(texts.text('dev.foundation.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _StatusCard(
              label: texts.text('dev.firebaseInitialized'),
              value: firebaseService.initialized
                  ? texts.text('common.yes')
                  : texts.text('common.no'),
            ),
            StreamBuilder<User?>(
              stream: authService.authStateChanges(),
              initialData: authService.currentUser,
              builder: (context, snapshot) {
                return _StatusCard(
                  label: texts.text('dev.authCurrentUser'),
                  value: snapshot.data?.email ?? texts.text('common.none'),
                );
              },
            ),
            _ActionCard(
              title: 'Firestore test read',
              status: _firestoreStatus,
              error: _firestoreError,
              buttonLabel: texts.text('dev.firestoreTest'),
              busy: _testingFirestore,
              onPressed: _testFirestore,
            ),
            _StatusCard(
              label: texts.text('dev.storageBucket'),
              value: FirebaseStorage.instance.bucket,
            ),
            _ActionCard(
              title: 'Storage upload test',
              status: _uploadedMedia?.secureUrl ?? 'Bereit',
              error: _uploadError,
              buttonLabel: texts.text('dev.storageUpload'),
              busy: _uploading,
              onPressed: _uploading ? null : _uploadImage,
            ),
            if (_uploadedMedia?.secureUrl.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: SelectableText(_uploadedMedia!.secureUrl),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.status,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
    this.error,
  });

  final String title;
  final String status;
  final String buttonLabel;
  final bool busy;
  final VoidCallback? onPressed;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(status),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              error!,
              style: const TextStyle(color: Color(0xFFB3261E)),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: busy ? null : onPressed,
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.large),
    border: Border.all(color: AppColors.border),
  );
}
