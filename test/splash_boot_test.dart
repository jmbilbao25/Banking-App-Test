// Requirement 8.5 caps the splash at 2000ms and requirement 8.6 requires it to
// route to login with a notice when session resolution fails. A restore that
// never answers is the case that used to strand the user on the launch screen
// forever, so this is a regression guard rather than the throwaway it was
// originally written as.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/domain/repositories.dart';
import 'package:mobile_bank_app/main.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// Stands in for a backend that accepted the request and never replied, which is
/// what an unreachable project or a stalled profiles query looks like.
class _HangingAuth implements AuthRepository {
  @override
  Future<UserProfile?> restoreSession() => Completer<UserProfile?>().future;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<UserProfile> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('the app leaves the splash even when restore never answers', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const ui.Size(1170, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [authRepositoryProvider.overrideWithValue(_HangingAuth())],
        child: const FrostBankApp(),
      ),
    );

    // The splash animates forever, so frames are advanced by hand.
    await tester.pump();
    expect(
      find.text('Everyday banking, clearly presented.'),
      findsOneWidget,
      reason: 'should start on the splash',
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    debugPrint(
      'still on splash after 20s: '
      '${find.text('Everyday banking, clearly presented.').evaluate().isNotEmpty}',
    );

    expect(
      find.text('Everyday banking, clearly presented.'),
      findsNothing,
      reason: 'a restore that never answers must not pin the app to the splash',
    );
  });
}
