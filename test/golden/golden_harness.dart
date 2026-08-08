import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/persistence/persistence_store.dart';
import 'package:mobile_bank_app/core/security/biometric_service.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// Loads the real typefaces into the test font collection.
///
/// Without this every golden renders in the placeholder test font, which draws
/// filled boxes instead of glyphs. A golden made of boxes cannot be compared
/// against a design reference, so the visual gate would be meaningless.
Future<void> loadAppFonts() async {
  final families = <String, String>{
    'Outfit': 'assets/fonts/Outfit.ttf',
    'Geist': 'assets/fonts/Geist.ttf',
    'GeistMono': 'assets/fonts/GeistMono.ttf',
  };

  // The Material icon font is not registered in the test font collection either,
  // so without it every Icon draws as an empty box and the render cannot be
  // judged against a design reference. Resolved from the SDK cache rather than
  // vendored, so it always matches the Flutter version in use.
  final materialIcons = _materialIconsFile();
  if (materialIcons != null) {
    families['MaterialIcons'] = materialIcons;
  }

  for (final family in families.entries) {
    final loader = FontLoader(family.key)
      ..addFont(File(family.value).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

/// Locates MaterialIcons in the active Flutter SDK. Returns null when it cannot
/// be found, so a golden run degrades to boxed icons rather than failing to
/// start.
String? _materialIconsFile() {
  final flutterRoot = _flutterRoot();
  if (flutterRoot == null) return null;
  final candidate = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  return candidate.existsSync() ? candidate.path : null;
}

String? _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // dart is executed from <flutter>/bin/cache/dart-sdk/bin, so walk back up.
  final executable = File(Platform.resolvedExecutable).absolute.path;
  final marker = '${Platform.pathSeparator}bin${Platform.pathSeparator}cache';
  final index = executable.indexOf(marker);
  return index == -1 ? null : executable.substring(0, index);
}

/// The device the mock was drawn at. A comparison at a different aspect ratio
/// would judge the layout on the wrong canvas, so both sides use this.
const goldenViewport = Size(390, 844);

class DismissedAdController extends OpeningAdDismissedController {
  @override
  bool build() => true;
}

MockDataSource goldenSource() =>
    MockDataSource(now: DateTime(2026, 8, 5))
      ..latencyOverride = (() => Duration.zero);

/// Pumps [child] on the golden viewport with the seeded world and no latency, so
/// the frame captured is the loaded state rather than a skeleton.
Future<void> pumpForGolden(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Size viewport = goldenViewport,
}) async {
  tester.view
    ..physicalSize = viewport * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        persistenceStoreProvider.overrideWithValue(InMemoryPersistenceStore()),
        biometricServiceProvider.overrideWithValue(
          const UnavailableBiometricService(),
        ),
        mockDataSourceProvider.overrideWithValue(goldenSource()),
        openingAdDismissedProvider.overrideWith(DismissedAdController.new),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.light(),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
