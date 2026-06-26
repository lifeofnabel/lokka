import 'package:flutter/material.dart';

import 'adminTheme.dart';
import 'pages/adminFirestorePage.dart';

/// Opens the raw Firestore editor pre-filled with [path], re-wrapped in the
/// Godmode theme (pushed routes don't inherit the route-level Theme).
void openAdminEditor(BuildContext context, String path) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => adminThemed(AdminFirestorePage(initialPath: path)),
  ));
}

void adminSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
}
