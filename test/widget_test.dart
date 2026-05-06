import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eunoia/main.dart';

void main() {
  testWidgets('Shell shows practice tab title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EunoiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('预备烤鸭'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
  });
}
