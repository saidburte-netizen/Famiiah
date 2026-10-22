import 'package:fam_mobile/theme/app_theme.dart';
import 'package:fam_mobile/theme/tokens.dart';
import 'package:fam_mobile/widgets/brand.dart';
import 'package:fam_mobile/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the brand mark and wordmark render at any size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FamLogo(size: 22),
              FamLogo(size: 138, glow: true),
              FamWordmark(size: 30, color: FamColors.navy),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(FamLogo), findsNWidgets(3)); // 2 marks + 1 inside the wordmark
    expect(find.text('Fam'), findsOneWidget);
  });

  testWidgets('FamPrimaryButton fires, and is inert while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFamTheme(),
        home: Scaffold(
          body: FamPrimaryButton(label: 'Save', onPressed: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFamTheme(),
        home: Scaffold(
          body: FamPrimaryButton(label: 'Save', loading: true, onPressed: () => taps++),
        ),
      ),
    );
    await tester.tap(find.byType(FamPrimaryButton), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('FamNotice.error uses the danger copy styling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FamNotice.error('Something broke')),
      ),
    );
    final text = tester.widget<Text>(find.text('Something broke'));
    expect(text.style?.color, FamColors.danger);
  });

  testWidgets('FamSegmented reports the tapped index', (tester) async {
    var picked = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFamTheme(),
        home: Scaffold(
          body: FamSegmented(
            labels: const ['Properties', 'Units'],
            selected: 0,
            onChanged: (i) => picked = i,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Units'));
    await tester.pumpAndSettle();
    expect(picked, 1);
  });

  test('the theme is built from the brand tokens', () {
    final theme = buildFamTheme();
    expect(theme.textTheme.bodyMedium?.fontFamily, FamFonts.body);
    expect(theme.colorScheme.primary, FamColors.royal);
    expect(theme.scaffoldBackgroundColor, FamColors.background);
  });
}
