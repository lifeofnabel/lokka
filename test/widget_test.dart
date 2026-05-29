import 'package:flutter_test/flutter_test.dart';
import 'package:lokka/app/app.dart';

void main() {
  testWidgets('shows landing page', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Lokka'), findsOneWidget);
    expect(find.text('Local deals. Wallet. Loyalty.'), findsOneWidget);
    expect(find.text('Maschinenraum läuft.'), findsOneWidget);
  });
}
