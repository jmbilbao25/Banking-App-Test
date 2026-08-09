import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import '../../state/session_controller.dart';
import 'brand.dart';

/// Watches the application lifecycle for App_Lock.
///
/// Two requirements are served here. Requirement 5.4 re-locks after 120 seconds
/// or more in the background, measured across a process death because the
/// timestamp is written to Persistence_Store. Requirement 5.5 obscures
/// authenticated content in the task switcher preview: Android also sets
/// FLAG_SECURE natively, and painting a cover whenever the application is not
/// resumed gives iOS the same behaviour, since the system snapshots the window
/// after it leaves the foreground.
class AppLockScope extends ConsumerStatefulWidget {
  const AppLockScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockScope> createState() => _AppLockScopeState();
}

class _AppLockScopeState extends ConsumerState<AppLockScope>
    with WidgetsBindingObserver {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appLockProvider.notifier);
    final signedIn = ref.read(sessionProvider) is SessionSignedIn;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (signedIn && !_obscured) setState(() => _obscured = true);
        controller.noteBackgrounded(DateTime.now());
      case AppLifecycleState.resumed:
        controller.noteResumed(DateTime.now());
        if (_obscured) setState(() => _obscured = false);
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_obscured)
          const Positioned.fill(
            // Hierarchy: not an animation, a cover. It has to be present in the
            // very frame the system snapshots, so it never transitions in.
            child: _PrivacyCover(),
          ),
      ],
    );
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Semantics(
      label: 'FrostBank is hidden while the application is in the background',
      child: FrostBackdrop(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FrostMark(size: 72),
              const SizedBox(height: Space.x4),
              Text(
                'FrostBank',
                style: AppType.titleMedium.copyWith(color: tokens.textOnBrand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
