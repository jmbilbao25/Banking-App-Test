import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/credential_vault.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/presentation/screens/forgot_password_screen.dart';
import 'package:mobile_bank_app/state/providers.dart';

const _emailFieldKey = Key('forgot-password-email-field');
const _codeFieldKey = Key('forgot-password-code-field');
const _newPasswordFieldKey = Key('forgot-password-new-field');
const _confirmPasswordFieldKey = Key('forgot-password-confirm-field');

/// A registered address, seeded with a credential before the screen is pumped.
const _registered = 'ava.mercado@frostbank.app';

/// An address with no credential in the vault.
const _unregistered = 'nobody.at.all@frostbank.app';

/// The screen calls `context.go('/login')` on success, so the harness supplies a
/// two route router rather than the real one. That keeps the navigation
/// assertable without this test depending on the application router.
Widget _harness(PersistenceStore store) {
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: Text('LOGIN PLACEHOLDER')),
      ),
    ],
  );

  return ProviderScope(
    retry: noAutomaticRetry,
    overrides: [persistenceStoreProvider.overrideWithValue(store)],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

/// A vault over the same store the harness uses, for seeding and for asserting.
CredentialVault _vaultOver(PersistenceStore store) {
  final container = ProviderContainer(
    overrides: [persistenceStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container.read(credentialVaultProvider);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

/// Takes the email step through to the code step.
Future<void> _sendCodeTo(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(_emailFieldKey), email);
  await _tap(tester, 'Send code');
}

/// Every string the screen is currently rendering, with [email] masked so two
/// runs against different addresses can be compared directly.
List<String> _renderedText(WidgetTester tester, String email) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => (widget.data ?? '').replaceAll(email, '<address>'))
    .toList();

/// Unmounts the tree, which disposes the screen and cancels its resend timer.
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  testWidgets('collects the registered email address, per Req 11.1', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    expect(find.byKey(_emailFieldKey), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('rejects a malformed email inline and stays on the email step', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    await _sendCodeTo(tester, 'not-an-email');

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.byKey(_emailFieldKey), findsOneWidget);
    expect(find.byKey(_codeFieldKey), findsNothing);
  });

  testWidgets(
    'shows the same code entry step and the same message whether or not the '
    'address is registered, per Req 11.2 and Req 11.3',
    (tester) async {
      final store = InMemoryPersistenceStore();
      final vault = _vaultOver(store);
      await vault.setPassword(
        email: _registered,
        password: 'seeded-password-1',
      );
      expect(vault.hasCredential(_registered), isTrue);
      expect(vault.hasCredential(_unregistered), isFalse);

      // Registered address.
      await tester.pumpWidget(_harness(store));
      await tester.pumpAndSettle();
      await _sendCodeTo(tester, _registered);
      expect(find.byKey(_codeFieldKey), findsOneWidget);
      expect(
        find.text('We sent a six digit code to $_registered.'),
        findsOneWidget,
      );
      final registeredText = _renderedText(tester, _registered);
      await _unmount(tester);

      // Unregistered address, same store.
      await tester.pumpWidget(_harness(store));
      await tester.pumpAndSettle();
      await _sendCodeTo(tester, _unregistered);
      expect(find.byKey(_codeFieldKey), findsOneWidget);
      expect(
        find.text('We sent a six digit code to $_unregistered.'),
        findsOneWidget,
      );
      final unregisteredText = _renderedText(tester, _unregistered);
      await _unmount(tester);

      expect(
        unregisteredText,
        equals(registeredText),
        reason:
            'Req 11.3: an unregistered address must render exactly what a '
            'registered address renders, so the form cannot be used to '
            'enumerate accounts',
      );
    },
  );

  testWidgets('advances to the new password step on the accepted code, per '
      'Req 11.4', (tester) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    await _sendCodeTo(tester, _registered);
    await tester.enterText(
      find.byKey(_codeFieldKey),
      ForgotPasswordScreen.verificationCodeFor(_registered),
    );
    await _tap(tester, 'Verify code');

    expect(find.byKey(_newPasswordFieldKey), findsOneWidget);
    expect(find.byKey(_confirmPasswordFieldKey), findsOneWidget);
    expect(find.byKey(_codeFieldKey), findsNothing);

    await _unmount(tester);
  });

  testWidgets('keeps the user on the code step and says the code is wrong, per '
      'Req 11.5', (tester) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    await _sendCodeTo(tester, _registered);

    final accepted = ForgotPasswordScreen.verificationCodeFor(_registered);
    final rejected = accepted == '000000' ? '111111' : '000000';
    await tester.enterText(find.byKey(_codeFieldKey), rejected);
    await _tap(tester, 'Verify code');

    expect(
      find.text('That code is incorrect. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(_codeFieldKey), findsOneWidget);
    expect(find.byKey(_newPasswordFieldKey), findsNothing);

    await _unmount(tester);
  });

  testWidgets('rejects a code that is not six digits and stays on the step', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    await _sendCodeTo(tester, _registered);
    await tester.enterText(find.byKey(_codeFieldKey), '123');
    await _tap(tester, 'Verify code');

    expect(
      find.text('Enter the six digit code from your email.'),
      findsOneWidget,
    );
    expect(find.byKey(_codeFieldKey), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets(
    'a completed reset replaces the stored credential and returns to sign in, '
    'per Req 11.6',
    (tester) async {
      final store = InMemoryPersistenceStore();
      final vault = _vaultOver(store);
      await vault.setPassword(email: _registered, password: 'seeded-password-1');
      expect(vault.verify(email: _registered, password: 'seeded-password-1'),
          isTrue);

      await tester.pumpWidget(_harness(store));
      await tester.pumpAndSettle();

      await _sendCodeTo(tester, _registered);
      await tester.enterText(
        find.byKey(_codeFieldKey),
        ForgotPasswordScreen.verificationCodeFor(_registered),
      );
      await _tap(tester, 'Verify code');

      await tester.enterText(find.byKey(_newPasswordFieldKey), 'chosen-anew-2');
      await tester.enterText(
        find.byKey(_confirmPasswordFieldKey),
        'chosen-anew-2',
      );
      await _tap(tester, 'Save password');
      await tester.pump();

      expect(
        vault.verify(email: _registered, password: 'chosen-anew-2'),
        isTrue,
        reason: 'the new password must be accepted',
      );
      expect(
        vault.verify(email: _registered, password: 'seeded-password-1'),
        isFalse,
        reason: 'Req 11.6: the previous credential must no longer be accepted',
      );

      expect(find.text('LOGIN PLACEHOLDER'), findsOneWidget);
      expect(
        find.text('Your password is updated. Please sign in.'),
        findsOneWidget,
        reason: 'Req 11.6: the outcome is stated on arrival at sign in',
      );
    },
  );

  testWidgets('rejects a new password under 8 characters inline', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    await _sendCodeTo(tester, _registered);
    await tester.enterText(
      find.byKey(_codeFieldKey),
      ForgotPasswordScreen.verificationCodeFor(_registered),
    );
    await _tap(tester, 'Verify code');

    await tester.enterText(find.byKey(_newPasswordFieldKey), 'short');
    await tester.enterText(find.byKey(_confirmPasswordFieldKey), 'short');
    await _tap(tester, 'Save password');

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(find.text('LOGIN PLACEHOLDER'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('rejects a confirmation that does not match', (tester) async {
    await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
    await tester.pumpAndSettle();

    await _sendCodeTo(tester, _registered);
    await tester.enterText(
      find.byKey(_codeFieldKey),
      ForgotPasswordScreen.verificationCodeFor(_registered),
    );
    await _tap(tester, 'Verify code');

    await tester.enterText(find.byKey(_newPasswordFieldKey), 'chosen-anew-2');
    await tester.enterText(
      find.byKey(_confirmPasswordFieldKey),
      'chosen-anew-3',
    );
    await _tap(tester, 'Save password');

    expect(find.text('Those passwords do not match.'), findsOneWidget);
    expect(find.text('LOGIN PLACEHOLDER'), findsNothing);

    await _unmount(tester);
  });

  testWidgets(
    'the resend control is unavailable until 30 seconds after the send, per '
    'Req 11.7',
    (tester) async {
      await tester.pumpWidget(_harness(InMemoryPersistenceStore()));
      await tester.pumpAndSettle();

      await _sendCodeTo(tester, _registered);

      TextButton resend() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'Resend code'));

      expect(resend().onPressed, isNull, reason: 'disabled the moment it sends');
      expect(find.text('Available in 30s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 29));
      expect(
        resend().onPressed,
        isNull,
        reason: 'Req 11.7: still unavailable one second short of the wait',
      );
      expect(find.text('Available in 1s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(
        resend().onPressed,
        isNotNull,
        reason: 'Req 11.7: available once 30 seconds have passed',
      );
      expect(find.textContaining('Available in'), findsNothing);

      // Resending restarts the wait, so the control cannot be hammered.
      await _tap(tester, 'Resend code');
      expect(resend().onPressed, isNull);
      expect(find.text('Available in 30s'), findsOneWidget);

      await _unmount(tester);
    },
  );
}
