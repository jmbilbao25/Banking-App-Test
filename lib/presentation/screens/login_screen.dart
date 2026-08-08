import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/surfaces.dart';

/// Clean BPI Mobile-Style Sign-In Screen with quick 6-Digit PIN Pad navigation.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesProvider);
    final email = prefs.rememberedEmail ?? '';
    _email = TextEditingController(text: email);
    _password = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (_submitting) return;

    final emailText = _email.text.trim();
    final passwordText = _password.text;

    if (emailText.isEmpty || passwordText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email and password.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      ref.read(preferencesProvider.notifier).setRememberedEmail(emailText);
      await ref
          .read(sessionProvider.notifier)
          .signIn(email: emailText, password: passwordText);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FrostBackdrop(
        child: SafeArea(
          child: ResponsiveShell(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Space.x6,
                Space.x8,
                Space.x6,
                Space.x6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FrostLockup(markSize: 44),
                  const SizedBox(height: Space.x10),
                  Text(
                    'WELCOME BACK',
                    style: AppType.displayLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    'Sign in using your account password or 6-digit PIN.',
                    style: AppType.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                  const SizedBox(height: Space.x6),

                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(Space.x3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: Space.x2),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppType.bodySmall.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.x4),
                        ],

                        // Shared Email Field
                        const FrostFieldLabel('Email'),
                        FrostField(
                          controller: _email,
                          hint: 'name@domain.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                        ),

                        const SizedBox(height: Space.x5),

                        const FrostFieldLabel('Password'),
                        FrostField(
                          controller: _password,
                          hint: 'Your password',
                          obscure: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitPassword(),
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.x2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                context.push('/soon/password-reset'),
                            style: TextButton.styleFrom(
                              foregroundColor: Palette.frostIcePale,
                            ),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: Space.x3),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submitPassword,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Palette.frostBaseTop,
                              disabledBackgroundColor:
                                  Colors.white.withValues(alpha: 0.7),
                              disabledForegroundColor: Palette.frostBaseTop,
                            ),
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Palette.frostBaseTop,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ),
                        const SizedBox(height: Space.x3),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final emailText = _email.text.trim();
                              if (emailText.isNotEmpty) {
                                ref
                                    .read(preferencesProvider.notifier)
                                    .setRememberedEmail(emailText);
                              }
                              context.go('/pin-lock');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.pin_rounded, size: 18),
                            label: const Text('Use PIN instead'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Space.x6),

                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New to FrostBank?',
                          style: AppType.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/register'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
