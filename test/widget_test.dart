import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/features/user/shared/widgets/quickActionBar.dart';

/// Smoke-Test für den geteilten QuickActionBar (Partner-/Post-/Wallet-Seiten).
/// Bewusst Firebase-frei – der frühere Default-Scaffold-Test pumpte die ganze
/// App und scheiterte an `Firebase.initializeApp()`.
void main() {
  Widget host(List<QuickAction> actions) => MaterialApp(
        home: Scaffold(body: Center(child: QuickActionBar(actions: actions))),
      );

  testWidgets('zeigt alle Aktions-Labels', (tester) async {
    await tester.pumpWidget(host(const [
      QuickAction(icon: Icons.near_me_rounded, label: 'Route', enabled: true),
      QuickAction(icon: Icons.schedule_rounded, label: 'Zeiten', enabled: true),
    ]));
    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Zeiten'), findsOneWidget);
  });

  testWidgets('deaktivierte Aktion ist nicht tappbar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host([
      QuickAction(
        icon: Icons.call_rounded,
        label: 'Anrufen',
        enabled: false,
        onTap: () => taps++,
      ),
    ]));
    await tester.tap(find.text('Anrufen'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('aktive Aktion löst onTap aus', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host([
      QuickAction(
        icon: Icons.call_rounded,
        label: 'Anrufen',
        enabled: true,
        onTap: () => taps++,
      ),
    ]));
    await tester.tap(find.text('Anrufen'));
    await tester.pump();
    expect(taps, 1);
  });
}
