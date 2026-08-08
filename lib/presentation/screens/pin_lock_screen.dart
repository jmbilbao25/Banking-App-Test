import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import '../../state/session_controller.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';
import '../widgets/surfaces.dart';

/// Full-screen 6-Digit PIN Unlock Screen used for initial application unlock.
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  bool _working = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_pin.length >= 6 || _working) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });

    if (_pin.length == 6) {
      _verifyAndUnlock();
    }
  }

  void _onBackspacePressed() {
    if (_pin.isEmpty || _working) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyAndUnlock() async {
    setState(() => _working = true);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    final profileAsync = ref.read(profileProvider);
    final expectedPin = profileAsync.value?.pinCode ?? '123456';

    if (_pin == expectedPin || _pin == '123456') {
      try {
        final session = ref.read(sessionProvider);
        if (session is! SessionSignedIn) {
          final preferences = ref.read(preferencesProvider);
          final activeProfileEmail = ref.read(profileProvider).value?.email;
          final emailToUse = (preferences.rememberedEmail != null && preferences.rememberedEmail!.isNotEmpty)
              ? preferences.rememberedEmail!
              : (activeProfileEmail ?? 'ava.mercado@frostbank.app');
          final passwordToUse = emailToUse.toLowerCase() == 'ava.mercado@frostbank.app' ? 'frost2026' : 'ive2026';

          await ref.read(sessionProvider.notifier).signIn(
                email: emailToUse,
                password: passwordToUse,
              );
        }
        if (mounted) context.go('/');
      } catch (e) {
        if (mounted) {
          setState(() {
            _working = false;
            _errorMessage = 'Could not unlock session. Try again.';
            _pin = '';
          });
        }
      }
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _working = false;
        _errorMessage = 'Incorrect PIN. Try 123456.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FrostBackdrop(
        child: SafeArea(
          child: ResponsiveShell(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x6,
                vertical: Space.x6,
              ),
              child: Column(
                children: [
                  const SizedBox(height: Space.x4),
                  const FrostLockup(markSize: 40),
                  const Spacer(),

                  // Title & Description
                  Text(
                    'SECURITY UNLOCK',
                    style: AppType.displayLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: 1.2,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Builder(
                    builder: (context) {
                      final remembered = ref.watch(preferencesProvider).rememberedEmail;
                      final activeProfileEmail = ref.watch(profileProvider).value?.email;
                      final email = (remembered != null && remembered.isNotEmpty)
                          ? remembered
                          : (activeProfileEmail ?? 'ava.mercado@frostbank.app');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: AppRadius.all(AppRadius.pill),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_circle_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: Space.x2),
                            Text(
                              email,
                              style: AppType.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: Space.x3),
                  Text(
                    'Enter your 6-digit security PIN to unlock',
                    style: AppType.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: Space.x8),

                  // 6 Passcode Indicator Circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: isFilled
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: Space.x4),

                  // Error Message
                  SizedBox(
                    height: 24,
                    child: _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            style: AppType.bodySmall.copyWith(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),

                  const Spacer(),

                  // Custom Numeric Keypad (3x4 Grid)
                  Column(
                    children: [
                      _buildKeypadRow(['1', '2', '3']),
                      const SizedBox(height: Space.x4),
                      _buildKeypadRow(['4', '5', '6']),
                      const SizedBox(height: Space.x4),
                      _buildKeypadRow(['7', '8', '9']),
                      const SizedBox(height: Space.x4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Sign in with Password alternative
                          _KeypadButton(
                            child: const Icon(
                              Icons.key_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onTap: () async {
                              await ref.read(sessionProvider.notifier).signOut();
                              if (context.mounted) context.go('/login');
                            },
                          ),
                          _KeypadButton(
                            label: '0',
                            onTap: () => _onDigitPressed('0'),
                          ),
                          _KeypadButton(
                            onTap: _onBackspacePressed,
                            child: const Icon(
                              Icons.backspace_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: Space.x6),

                  // Password Sign In / Switch Account Button
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.8),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Switch Account / Use Password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (digit) => _KeypadButton(
              label: digit,
              onTap: () => _onDigitPressed(digit),
            ),
          )
          .toList(),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({this.label, this.child, required this.onTap});

  final String? label;
  final Widget? child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: 36,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: child ??
            Text(
              label!,
              style: AppType.displayLarge.copyWith(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w500,
              ),
            ),
      ),
    );
  }
}
