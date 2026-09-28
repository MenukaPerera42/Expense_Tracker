import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/presentation/providers/account_settings_provider.dart';
import 'package:expense_tracker/presentation/screens/settings_screen.dart';

class _Repository extends Mock implements AuthRepository {}

void main() {
  late _Repository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _Repository();
    when(() => repository.updateName(any())).thenAnswer((_) async {});
    when(
      () => repository.changeEmail(
        email: any(named: 'email'),
        currentPassword: any(named: 'currentPassword'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repository.changePassword(
        currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});
    when(repository.refreshUser).thenAnswer((_) async {});
  });

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
    Stream<AuthUser?>? users,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) async => repository),
        authStateProvider.overrideWith(
          (ref) =>
              users ??
              Stream.value(
                const AuthUser(id: 'u', name: 'Alex', email: 'alex@gmail.com'),
              ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> open(WidgetTester tester, String title) async {
    final tile = find.widgetWithText(ListTile, title);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(tile), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  Future<void> submit(
    WidgetTester tester, [
    String label = 'Save changes',
  ]) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'name editor starts with current name and saves trimmed changes',
    (tester) async {
      await mount(tester);
      await open(tester, 'Profile name');
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Alex',
      );
      await fill(tester, 'Profile name', ' New Name ');
      await submit(tester);
      verify(() => repository.updateName('New Name')).called(1);
      expect(find.text('Profile name updated.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );
  testWidgets('Google-only account does not show change password', (
    tester,
  ) async {
    await mount(
      tester,
      users: Stream.value(
        const AuthUser(
          id: 'google-user',
          email: 'google@example.com',
          hasPasswordProvider: false,
        ),
      ),
    );

    expect(find.text('Change password'), findsNothing);
  });

  testWidgets(
    'profile events update the displayed name without reopening Settings',
    (tester) async {
      final users = StreamController<AuthUser?>();
      addTearDown(users.close);
      users.add(const AuthUser(id: 'u', name: 'Alex', email: 'alex@gmail.com'));
      await mount(tester, users: users.stream);
      when(() => repository.updateName('Updated')).thenAnswer((_) async {
        users.add(
          const AuthUser(id: 'u', name: 'Updated', email: 'alex@gmail.com'),
        );
      });
      await open(tester, 'Profile name');
      await fill(tester, 'Profile name', 'Updated');
      await submit(tester);
      expect(find.text('Updated'), findsOneWidget);
    },
  );

  testWidgets('closing the editor discards unsaved changes', (tester) async {
    await mount(tester);
    await open(tester, 'Profile name');
    await fill(tester, 'Profile name', 'Not saved');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.updateName(any()));
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('saving disables fields and closing until the write completes', (
    tester,
  ) async {
    final gate = Completer<void>();
    when(() => repository.updateName(any())).thenAnswer((_) => gate.future);
    await mount(tester);
    await open(tester, 'Profile name');
    await fill(tester, 'Profile name', 'Saved');
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Close',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Profile name updated.'), findsOneWidget);
  });

  testWidgets('invalid name prevents saving', (tester) async {
    await mount(tester);
    await open(tester, 'Profile name');
    await fill(tester, 'Profile name', ' ');
    await submit(tester);
    expect(find.text('Enter your name.'), findsOneWidget);
    verifyNever(() => repository.updateName(any()));
  });

  testWidgets('email is displayed without an edit action', (tester) async {
    await mount(tester);
    final email = find.widgetWithText(ListTile, 'Email address');
    await tester.scrollUntilVisible(
      email,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(email);
    expect(tile.onTap, isNull);
    expect(tile.trailing, isNull);
    expect(find.text('alex@gmail.com'), findsOneWidget);
    expect(find.text('Change email address'), findsNothing);
  });

  testWidgets(
    'password confirmation prevents mismatches and password can be revealed',
    (tester) async {
      await mount(tester);
      await open(tester, 'Change password');
      await fill(tester, 'Current password', 'old-secret');
      await fill(tester, 'New password', 'NewSecret123!');
      await fill(tester, 'Confirm new password', 'mismatch');
      await submit(tester);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
      await tester.ensureVisible(find.byTooltip('Show new password'));
      await tester.tap(find.byTooltip('Show new password'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.widgetWithText(TextFormField, 'New password'),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      await fill(tester, 'Confirm new password', 'NewSecret123!');
      await submit(tester);
      verify(
        () => repository.changePassword(
          currentPassword: 'old-secret',
          newPassword: 'NewSecret123!',
        ),
      ).called(1);
      expect(find.text('Password updated.'), findsOneWidget);
    },
  );

  testWidgets('failed save stays open with a recoverable error', (
    tester,
  ) async {
    when(() => repository.updateName(any())).thenThrow(
      const AppException(
        AppErrorCode.network,
        'Check your connection and try again.',
      ),
    );
    await mount(tester);
    await open(tester, 'Profile name');
    await fill(tester, 'Profile name', 'New');
    await submit(tester);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    when(() => repository.updateName(any())).thenAnswer((_) async {});
    await submit(tester);
    expect(find.text('Profile name updated.'), findsOneWidget);
  });

  testWidgets('editor scrolls above keyboard at large text in landscape', (
    tester,
  ) async {
    await mount(tester, size: const Size(568, 320), scale: 2);
    await open(tester, 'Change password');
    tester.view.viewInsets = const FakeViewPadding(bottom: 140);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await fill(tester, 'Confirm new password', 'secret');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find
          .ancestor(
            of: find.widgetWithText(FilledButton, 'Save changes'),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.widgetWithText(FilledButton, 'Save changes')).bottom,
      lessThanOrEqualTo(180),
    );
  });

  testWidgets('refresh profile reloads account data', (tester) async {
    await mount(tester);
    final refresh = find.text('Refresh profile');
    await tester.scrollUntilVisible(
      refresh,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    verify(repository.refreshUser).called(1);
    expect(find.text('Profile refreshed.'), findsOneWidget);
  });

  test(
    'controller prevents duplicate saves and ignores completion after disposal',
    () async {
      final gate = Completer<void>();
      when(() => repository.updateName(any())).thenAnswer((_) => gate.future);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      final subscription = container.listen(accountSettingsProvider, (_, _) {});
      final controller = container.read(accountSettingsProvider.notifier);
      final pending = controller.updateName('Alex');
      expect(await controller.updateName('Duplicate'), isFalse);
      await pumpEventQueue();
      subscription.close();
      container.dispose();
      gate.complete();
      expect(await pending, isFalse);
      verify(() => repository.updateName('Alex')).called(1);
      verifyNever(() => repository.updateName('Duplicate'));
    },
  );
}
