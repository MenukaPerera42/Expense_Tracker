import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/presentation/screens/auth_screen.dart';
import 'package:expense_tracker/presentation/widgets/expense_filter_bar.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/presentation/providers/expense_providers.dart';
import 'package:expense_tracker/presentation/providers/theme_mode_provider.dart';
import 'package:expense_tracker/presentation/widgets/accessible_action.dart';
import 'package:expense_tracker/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(1024, 768),
  ]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('screens reflow at $size and text scale $scale', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final now = DateTime.now();
        final expenses = [
          for (final category in ExpenseCategory.values)
            Expense(
              id: category.name,
              userId: 'u',
              title: 'A long transaction title that needs to remain readable',
              amount: 1234567.89,
              category: category,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
        ];
        final container = ProviderContainer(
          overrides: [
            appInitializerProvider.overrideWithValue(() async {}),
            authStateProvider.overrideWith(
              (ref) => Stream.value(const AuthUser(id: 'u', name: 'Alex')),
            ),
            expenseListProvider.overrideWith((ref) => Stream.value(expenses)),
            expenseByIdProvider('food')
                .overrideWith((ref) async => expenses.first),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const ExpenseTrackerApp(),
          ),
        );
        await tester.pumpAndSettle();
        final router = container.read(appRouterProvider);
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          await container.read(themeModeProvider.notifier).setMode(mode);
          for (final route in [
            '/',
            '/analytics',
            '/expenses',
            '/settings',
            '/expenses/add',
            '/expenses/food/edit',
          ]) {
            router.go(route);
            await tester.pumpAndSettle();
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$route $mode');
            if (route == '/' || route == '/settings') {
              final label = find.text(route == '/' ? 'History' : 'System');
              if (route == '/settings') {
                await tester.scrollUntilVisible(
                  label,
                  120,
                  scrollable: find.byType(Scrollable).first,
                );
                await tester.pumpAndSettle();
              }
              final text = tester.widget<Text>(label);
              final style = DefaultTextStyle.of(tester.element(label)).style
                  .merge(text.style);
              final backgrounds = tester
                  .widgetList<Container>(
                    find.ancestor(of: label, matching: find.byType(Container)),
                  )
                  .map((c) => c.decoration)
                  .whereType<BoxDecoration>()
                  .map((d) => d.color)
                  .whereType<Color>();
              final a = style.color!.computeLuminance();
              final b = backgrounds.first.computeLuminance();
              final ratio = a > b
                  ? (a + .05) / (b + .05)
                  : (b + .05) / (a + .05);
              expect(
                ratio,
                greaterThanOrEqualTo(4.5),
                reason: '$route $mode label contrast',
              );
            }

            final scroll = find.byType(Scrollable).first;
            for (var i = 0; i < 6; i++) {
              await tester.drag(scroll, const Offset(0, -400));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '$route scrolled $mode',
              );
            }
          }
        }
      });
    }
  }

  testWidgets('keyboard leaves search and expense fields reachable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final now = DateTime.now();
    final container = ProviderContainer(
      overrides: [
        appInitializerProvider.overrideWithValue(() async {}),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(id: 'u')),
        ),
        expenseListProvider.overrideWith(
          (ref) => Stream.value([
            Expense(
              id: 'a',
              userId: 'u',
              title: 'Coffee',
              amount: 5,
              category: ExpenseCategory.food,
              date: now,
              createdAt: now,
              updatedAt: now,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExpenseTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    for (final route in ['/expenses', '/expenses/add']) {
      router.go(route);
      await tester.pumpAndSettle();
      final field = route == '/expenses'
          ? find.byType(TextField).first
          : find.widgetWithText(TextFormField, 'Note (optional)');
      await tester.ensureVisible(field);
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('navigation-add-expense')),
        findsNothing,
      );
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      expect(tester.getRect(editable).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(editable).bottom, lessThanOrEqualTo(308));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('category sheet scrolls at large text in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ExpenseFilterBar())),
      ),
    );
    await tester.ensureVisible(find.text('Category'));
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Other'));
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets(
    'registration remains scrollable with large text and keyboard in landscape',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AuthScreen(register: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final password = find.widgetWithText(TextFormField, 'Confirm password');
      await tester.ensureVisible(password);
      await tester.tap(password);
      tester.view.viewInsets = const FakeViewPadding(bottom: 150);
      await tester.pumpAndSettle();
      await tester.ensureVisible(password);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getRect(
              find.descendant(
                of: password,
                matching: find.byType(EditableText),
              ),
            )
            .bottom,
        lessThanOrEqualTo(170),
      );
    },
  );

  testWidgets(
    'custom controls expose selected button semantics and keyboard activation',
    (tester) async {
      final handle = tester.ensureSemantics();

      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleAction(
              label: 'Add expense',
              selected: true,
              onTap: () => taps++,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AccessibleAction)),
        matchesSemantics(
          label: 'Add expense',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSize(find.byType(AccessibleAction)).shortestSide,
        greaterThanOrEqualTo(48),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    },
  );
}
