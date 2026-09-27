import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.light
        ? AppTheme.light()
        : AppTheme.dark();

    test('$brightness theme gives inputs distinct focus and error states', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, brightness);
      final inputs = theme.inputDecorationTheme;
      expect(inputs.focusedBorder!.borderSide.color, theme.colorScheme.primary);
      expect(inputs.errorBorder!.borderSide.color, theme.colorScheme.error);
      expect(
        inputs.focusedErrorBorder!.borderSide.color,
        theme.colorScheme.error,
      );
      expect(
        inputs.focusedBorder!.borderSide.width,
        greaterThan(inputs.enabledBorder!.borderSide.width),
      );
      expect(
        theme.textTheme.bodyLarge!.color,
        isNot(theme.scaffoldBackgroundColor),
      );
    });

    testWidgets('$brightness components stay usable with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Account settings'),
                      ),
                    ),
                    const TextField(
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    FilledButton(
                      onPressed: () => taps++,
                      child: const Text('Continue'),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Cancel'),
                    ),
                    TextButton(onPressed: () {}, child: const Text('Help')),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (final type in [
        FilledButton,
        OutlinedButton,
        TextButton,
        ElevatedButton,
      ]) {
        expect(
          tester.getSize(find.byType(type)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.text('Continue'));
      await tester.enterText(find.byType(TextField), 'Alex');
      expect(taps, 1);
      expect(find.text('Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
