import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';

/// Opens the operating system settings page for this application.
///
/// Behind a provider so a widget test can assert the control was activated
/// without a platform channel, and so the two scanner screens share one
/// implementation.
final openAppSettingsProvider = Provider<Future<bool> Function()>(
  (ref) => openAppSettings,
);

/// Shown in place of the camera viewport when permission has been refused.
///
/// Requirement 17.5 asks for two things: a message explaining the denial, and a
/// control that opens the operating system settings. The previous inline version
/// of this view had the message and a retry, but no way to reach the settings,
/// so a customer who had denied the permission once could not recover inside the
/// application.
class CameraPermissionDeniedView extends ConsumerWidget {
  const CameraPermissionDeniedView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return ColoredBox(
      // The viewport this replaces is black, so the surround stays black rather
      // than flashing a light surface over the camera area.
      color: Colors.black,
      child: Center(
        child: Padding
        (
          padding: const EdgeInsets.symmetric(horizontal: Space.x10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white54,
                size: 72,
              ),
              const SizedBox(height: Space.x5),
              Semantics(
                header: true,
                child: Text(
                  'Camera access is off',
                  style: AppType.titleMedium.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.x3),
              Text(
                'FrostBank needs the camera to scan a payment code. Turn it on '
                'in Settings to continue.',
                style: AppType.bodySmall.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.x7),
              SizedBox(
                width: double.infinity,
                height: Layout.minTapTarget,
                child: FilledButton.icon(
                  onPressed: () => ref.read(openAppSettingsProvider)(),
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  // Three words, per requirement 25.6.
                  label: const Text('Open settings'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: Space.x3),
              SizedBox(
                height: Layout.minTapTarget,
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Try again',
                    style: AppType.labelMedium.copyWith(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
