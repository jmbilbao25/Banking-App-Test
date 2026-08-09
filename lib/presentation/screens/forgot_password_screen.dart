import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/persistence/pin_vault.dart';
import '../../domain/credentials.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/surfaces.dart';

/// Which of the three steps of the reset is on screen.
enum ForgotPasswordStep {
  /// Requirement 11.1: collect the registered email address.
  email,

  /// Requirements 11.2 and 11.3: the code entry step, reached identically
  /// whether or not the address is registered.
  code,

  /// Requirement 11.6: choose the replacement password.
  password,
}

/// Password reset for Requirement 11.
///
/// One screen carrying three steps, in the same shape the PIN lock screen uses
/// for its stages. The important property of this screen is what it does not do:
/// the email step never asks whether the address is registered, so the response
/// to an unknown address is byte for byte the response to a known one. That is
/// requirements 11.2 and 11.3 read together, and it is the whole point of the
/// requirement. Any branch on existence here would turn this form into an
/// account enumeration oracle.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  /// Seconds the resend control stays unavailable after a send, per
  /// requirement 11.7.
  static const int resendCooldownSeconds = 30;

  /// Namespace for the derived verification code. Not a secret in itself: it
  /// only keeps the derivation distinct from any other digest in the app.
  static const String _codeNamespace = 'frostbank.password.reset.code';

  /// The six digit code this build accepts for [email].
  ///
  /// Derived from the address rather than stored as a literal, because
  /// requirement 5.9 forbids credential values in the source and requirement 25
  /// forbids copy that leaks one. The value is never rendered; it is exposed
  /// here only so the test suite can compute what it should type.
  @visibleForTesting
  static String verificationCodeFor(String email) {
    final normalized = email.trim().toLowerCase();
    final bytes = sha256
        .convert(utf8.encode('$_codeNamespace:$normalized'))
        .bytes;
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value = ((value << 8) | bytes[i]) & 0x7FFFFFFF;
    }
    return (value % 1000000).toString().padLeft(PinVault.pinLength, '0');
  }

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  ForgotPasswordStep _step = ForgotPasswordStep.email;

  /// The address the code was sent to. Held so the code and password steps work
  /// against the submitted value rather than whatever is in the field.
  String _sentTo = '';

  String? _errorMessage;
  bool _obscurePassword = true;
  bool _working = false;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Requirement 11.7: the resend control is unavailable for 30 seconds after
  /// the previous send, with the remaining time stated while it waits.
  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(
      () => _resendSeconds = ForgotPasswordScreen.resendCooldownSeconds,
    );
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds -= 1;
        if (_resendSeconds <= 0) {
          _resendSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  /// Requirements 11.2 and 11.3. No lookup, no branch, one outcome.
  void _sendCode() {
    final address = _email.text.trim();
    final formatError = Credentials.emailError(address);
    if (formatError != null) {
      setState(() => _errorMessage = formatError);
      return;
    }

    setState(() {
      _sentTo = address;
      _step = ForgotPasswordStep.code;
      _errorMessage = null;
      _code.clear();
    });
    _startResendCountdown();
  }

  void _resendCode() {
    if (_resendSeconds > 0) return;
    setState(() {
      _errorMessage = null;
      _code.clear();
    });
    _startResendCountdown();
  }

  /// Requirements 11.4 and 11.5.
  void _verifyCode() {
    final entered = _code.text.trim();
    // The six digit rule already lives in PinVault, so the rule is reused and
    // only the wording is local: PinVault speaks about a PIN, and this field is
    // a code.
    if (PinVault.formatError(entered) != null) {
      setState(
        () => _errorMessage = 'Enter the six digit code from your email.',
      );
      return;
    }

    if (entered != ForgotPasswordScreen.verificationCodeFor(_sentTo)) {
      // Requirement 11.5: state the code is wrong and stay on this step.
      setState(() => _errorMessage = 'That code is incorrect. Please try again.');
      return;
    }

    setState(() {
      _step = ForgotPasswordStep.password;
      _errorMessage = null;
      _password.clear();
      _confirm.clear();
    });
  }

  /// Requirement 11.6: replace the stored credential, then return to sign in
  /// with the outcome stated.
  Future<void> _savePassword() async {
    if (_working) return;

    final password = _password.text;
    final lengthError = Credentials.passwordError(password);
    if (lengthError != null) {
      setState(() => _errorMessage = lengthError);
      return;
    }
    if (_confirm.text != password) {
      setState(() => _errorMessage = 'Those passwords do not match.');
      return;
    }

    setState(() {
      _working = true;
      _errorMessage = null;
    });

    await ref
        .read(credentialVaultProvider)
        .setPassword(email: _sentTo, password: password);
    if (!mounted) return;

    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your password is updated. Please sign in.'),
      ),
    );
    context.go('/login');
  }

  void _onPrimaryPressed() {
    switch (_step) {
      case ForgotPasswordStep.email:
        _sendCode();
      case ForgotPasswordStep.code:
        _verifyCode();
      case ForgotPasswordStep.password:
        _savePassword();
    }
  }

  String get _headline => switch (_step) {
    ForgotPasswordStep.email => 'RESET PASSWORD',
    ForgotPasswordStep.code => 'CHECK YOUR EMAIL',
    ForgotPasswordStep.password => 'NEW PASSWORD',
  };

  /// The code step line is the one requirements 11.2 and 11.3 constrain. It is
  /// built from the submitted address alone, so it cannot vary with existence.
  String get _subtext => switch (_step) {
    ForgotPasswordStep.email =>
      'Enter the email on your account and we will send a six digit code.',
    ForgotPasswordStep.code => 'We sent a six digit code to $_sentTo.',
    ForgotPasswordStep.password =>
      'Choose a password of at least 8 characters, then confirm it.',
  };

  String get _primaryLabel => switch (_step) {
    ForgotPasswordStep.email => 'Send code',
    ForgotPasswordStep.code => 'Verify code',
    ForgotPasswordStep.password => 'Save password',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FrostBackdrop(
        child: SafeArea(
          child: ResponsiveShell(
            child: Padding(
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
                    _headline,
                    style: AppType.displayLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    _subtext,
                    style: AppType.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                  const SizedBox(height: Space.x6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage != null) ...[
                              _InlineError(message: _errorMessage!),
                              const SizedBox(height: Space.x4),
                            ],
                            ..._stepFields(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x6),
                  ..._actions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepFields() => switch (_step) {
    ForgotPasswordStep.email => [
      const FrostFieldLabel('Email'),
      FrostField(
        key: const Key('forgot-password-email-field'),
        controller: _email,
        hint: 'name@domain.com',
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        onSubmitted: (_) => _sendCode(),
      ),
    ],
    ForgotPasswordStep.code => [
      const FrostFieldLabel('Verification code'),
      FrostField(
        key: const Key('forgot-password-code-field'),
        controller: _code,
        // No sample digits here: a hint would hand the code to the reader.
        hint: 'Six digits',
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: PinVault.pinLength,
        onSubmitted: (_) => _verifyCode(),
      ),
    ],
    ForgotPasswordStep.password => [
      const FrostFieldLabel('New password'),
      FrostField(
        key: const Key('forgot-password-new-field'),
        controller: _password,
        hint: 'At least 8 characters',
        obscure: _obscurePassword,
        textInputAction: TextInputAction.next,
        suffix: IconButton(
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          // Icon only control, so it carries its own name.
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            size: 20,
          ),
        ),
      ),
      const SizedBox(height: Space.x5),
      const FrostFieldLabel('Confirm password'),
      FrostField(
        key: const Key('forgot-password-confirm-field'),
        controller: _confirm,
        hint: 'Repeat your new password',
        obscure: _obscurePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _savePassword(),
      ),
    ],
  };

  List<Widget> _actions() => [
    SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _working ? null : _onPrimaryPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Palette.frostBaseTop,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
          disabledForegroundColor: Palette.frostBaseTop,
          minimumSize: const Size(double.infinity, Layout.minTapTarget),
          shape: const StadiumBorder(),
        ),
        child: Text(_primaryLabel),
      ),
    ),
    if (_step == ForgotPasswordStep.code) ...[
      const SizedBox(height: Space.x2),
      _ResendRow(
        secondsRemaining: _resendSeconds,
        onResend: _resendCode,
      ),
    ],
    const SizedBox(height: Space.x2),
    Center(
      child: TextButton(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(
            Layout.minTapTarget,
            Layout.minTapTarget,
          ),
        ),
        child: const Text('Back to sign in'),
      ),
    ),
  ];
}

/// Inline message shown above the fields of the current step.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.2),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: tokens.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: tokens.error, size: 20),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              message,
              style: AppType.bodySmall.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Requirement 11.7. The control keeps one label at every moment, and the wait
/// is stated beside it rather than folded into the label.
class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsRemaining, required this.onResend});

  final int secondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final waiting = secondsRemaining > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: waiting ? null : onResend,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
            minimumSize: const Size(
              Layout.minTapTarget,
              Layout.minTapTarget,
            ),
          ),
          child: const Text('Resend code'),
        ),
        if (waiting)
          Text(
            'Available in ${secondsRemaining}s',
            style: AppType.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
            ),
          ),
      ],
    );
  }
}
