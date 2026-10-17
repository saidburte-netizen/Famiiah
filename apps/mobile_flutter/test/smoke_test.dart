import 'package:fam_mobile/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FamCard and EmptyState render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FamCard(child: EmptyState(message: 'Nothing here yet.')),
        ),
      ),
    );
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('ErrorState shows a retry when given one', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorState(message: 'Boom', onRetry: () => retried = true),
        ),
      ),
    );
    expect(find.text('Boom'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
