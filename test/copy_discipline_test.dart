import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Requirement 25 is a property of the source, not of one screen, so it is
/// enforced by scanning `lib/` rather than by pumping widgets.
///
/// A rule that is only checked once decays. These tests fail the build the next
/// time a decorative dash or a version label is introduced, which is the only
/// way a copy rule survives contact with a growing application.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  /// Every single quoted Dart string literal on one line, which is what the
  /// application actually renders. Comments are excluded, because requirement
  /// 25.1 constrains UI_String, not prose written for the next developer.
  final stringLiteral = RegExp(r"'(?:[^'\\\n]|\\.)*'");

  /// A line whose content begins a comment.
  bool isComment(String line) {
    final t = line.trimLeft();
    return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
  }

  Iterable<({String file, int line, String text})> literals() sync* {
    for (final file in dartFiles) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        for (final match in stringLiteral.allMatches(lines[i])) {
          yield (
            file: file.path,
            line: i + 1,
            text: match.group(0)!.substring(1, match.group(0)!.length - 1),
          );
        }
      }
    }
  }

  test('lib contains dart files to scan', () {
    expect(dartFiles, isNotEmpty);
  });

  test('Req 25.1: no em dash or en dash in any UI string', () {
    final offenders = <String>[];
    for (final entry in literals()) {
      if (entry.text.contains('\u2014') || entry.text.contains('\u2013')) {
        offenders.add('${entry.file}:${entry.line}: ${entry.text}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Requirement 25.1 forbids the em dash and the en dash in UI copy. '
          'Use a full stop, a comma, or two sentences instead.\n'
          '${offenders.join('\n')}',
    );
  });

  test('Req 25.3: no version label and no build label in any UI string', () {
    // A version or build *label* is a figure presented as one, such as v2.1.0
    // or "Build 4821". Prose that happens to contain the word build, for example
    // "Every figure in this build is mock data", is not a label.
    final versionish = RegExp(r'\bv?\d+\.\d+\.\d+\b|\bbuild\s+\d+\b', caseSensitive: false);
    final offenders = <String>[];
    for (final entry in literals()) {
      if (versionish.hasMatch(entry.text)) {
        offenders.add('${entry.file}:${entry.line}: ${entry.text}');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Req 25.2: no scroll cue copy', () {
    final cue = RegExp(
      r'\bscroll (?:down|up|for more)\b|\bswipe (?:up|down) (?:for|to see)\b',
      caseSensitive: false,
    );
    final offenders = <String>[];
    for (final entry in literals()) {
      if (cue.hasMatch(entry.text)) {
        offenders.add('${entry.file}:${entry.line}: ${entry.text}');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Req 5.9: no credential value in the source', () {
    // The shapes that actually leaked before: a Supabase anon JWT, a bare hex
    // API key, and a six digit PIN presented as a default.
    final jwt = RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}');
    final hexKey = RegExp(r"'[0-9a-f]{32}'");
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (jwt.hasMatch(lines[i]) || hexKey.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Requirement 5.9 forbids API keys, access tokens and credential '
          'values in the source. Pass them with --dart-define instead.\n'
          '${offenders.join('\n')}',
    );
  });

  test('Req 5.9: the PIN is never compared against a literal', () {
    // The original build accepted a hardcoded PIN on two screens in addition to
    // the stored one. Verification must go through PinVault.
    final literalPin = RegExp(r"==\s*'\d{4,6}'|'\d{6}'\s*==");
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (literalPin.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Req 1.7: no raw hex colour outside the token and palette files', () {
    // Requirement 1.7 gives the design system one accent and requirement 1.15
    // makes a missing token fail loudly. A hex literal in a screen bypasses
    // both, so the palette is the only place allowed to name a colour.
    final hex = RegExp(r'0x[fF][fF][0-9a-fA-F]{6}');
    final allowed = {
      // The palette is where colour is allowed to be named.
      'lib/core/design/tokens.dart',
      'lib/core/design/theme.dart',
      // Third party brand marks. A Mastercard circle has to be Mastercard red
      // and Bitcoin orange has to be Bitcoin orange, so a semantic token cannot
      // stand in for either without misrepresenting the mark.
      'lib/presentation/widgets/card_face.dart',
      'lib/presentation/widgets/market.dart',
    };
    final offenders = <String>[];

    for (final file in dartFiles) {
      final normalised = file.path.replaceAll(r'\', '/');
      if (allowed.contains(normalised)) continue;
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (hex.hasMatch(lines[i])) {
          offenders.add('$normalised:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    // Recorded rather than asserted at zero: the screens listed here predate the
    // rule and are being migrated. The count must never grow.
    expect(
      offenders.length,
      lessThanOrEqualTo(_knownRawHexCount),
      reason:
          'A new raw hex colour was added. Read it from context.tokens '
          'instead.\n${offenders.join('\n')}',
    );
  });
}

/// Raw hex colour sites still awaiting migration onto the token set.
///
/// A ratchet rather than a clean assertion, because these predate the rule and
/// clearing all of them is a separate change. The point is that the number can
/// only go down: a new hex literal fails this test. The concentrations are
/// opening_ad_screen.dart, qr_screen.dart, transfer_screen.dart and
/// deposit_screen.dart, which are the screens that were written against literal
/// colours rather than against the theme.
const _knownRawHexCount = 55;
