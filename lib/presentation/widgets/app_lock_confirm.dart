import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/persistence/pin_vault.dart';
import '../../core/security/biometric_service.dart';
import '../../state/providers.dart';

/// Requires PIN entry or biometric confirmation before an action proceeds.
///
/// Requirement 16.9 requires this before a transfer is performed, requirement
/// 17.7 before a QR payment debits an account, and the card screen uses the same
/// gate before revealing a number. Having one implementation means a new money
/// movement flow cannot accidentally ship without the check, and means the five
/// attempt lockout of requirement 5.2 is counted in one place.
///
/// Returns true only when the customer was confirmed. A dismissed sheet, a
/// cancelled biometric prompt, or a spent attempt budget all return false, and
/// the caller must treat false as "do not move any money".
Future<bool> confirmWithAppLock(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final vault = ref.read(pinVaultProvider);

  // With no PIN set there is nothing to check against. Refusing here would make
  // the flow impossible, so the caller is told to send the customer to set one.
  if (!vault.hasPin) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Set a PIN in your profile before moving money.'),
      ),
    );
    return false;
  }

  // Requirement 5.3: biometric first where one is enrolled, PIN as the fallback.
  if (ref.read(preferencesProvider).biometricUnlock) {
    final service = ref.read(biometricServiceProvider);
    if (await service.isEnrolled()) {
      final result = await service.authenticate(reason: reason);
      if (result == BiometricResult.success) {
        await vault.clearFailures();
        return true;
      }
      // A cancelled or unavailable prompt falls through to PIN entry rather
      // than failing the action outright.
    }
  }

  if (!context.mounted) return false;

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    builder: (_) => _PinConfirmSheet(reason: reason),
  );
  return confirmed ?? false;
}

class _PinConfirmSheet extends ConsumerStatefulWidget {
  const _PinConfirmSheet({required this.reason});

  final String reason;

  @override
  ConsumerState<_PinConfirmSheet> createState() => _PinConfirmSheetState();
}

class _PinConfirmSheetState extends ConsumerState<_PinConfirmSheet> {
  final _controller = TextEditingController();
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    final entry = _controller.text.trim();

    final formatError = PinVault.formatError(entry);
    if (formatError != null) {
      setState(() => _error = formatError);
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    final vault = ref.read(pinVaultProvider);

    if (vault.verify(entry)) {
      await vault.clearFailures();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    await vault.recordFailure();
    if (!mounted) return;

    // Requirement 5.2 applies here too: the attempt budget is shared with
    // App_Lock, so it cannot be reset by retrying from a payment sheet.
    if (vault.isLockedOut) {
      await ref.read(sessionProvider.notifier).signOut(
        notice:
            'You entered an incorrect PIN ${PinVault.maxAttempts} times, so we '
            'signed you out. Please sign in again.',
      );
      if (!mounted) return;
      Navigator.of(context).pop(false);
      return;
    }

    HapticFeedback.vibrate();
    final remaining = vault.attemptsRemaining;
    setState(() {
      _working = false;
      _controller.clear();
      _error = remaining == 1
          ? 'Incorrect PIN. One more attempt before you are signed out.'
          : 'Incorrect PIN. $remaining attempts remaining.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(
        left: Space.x6,
        right: Space.x6,
        top: Space.x6,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Space.x6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Confirm with your PIN',
              style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
            ),
          ),
          const SizedBox(height: Space.x2),
          Text(
            widget.reason,
            style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: Space.x5),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinVault.pinLength,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppType.numericMedium.copyWith(
              color: tokens.textPrimary,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              labelText: 'PIN',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.x5),
          SizedBox(
            width: double.infinity,
            height: Layout.minTapTarget,
            child: FilledButton(
              onPressed: _working ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.all(AppRadius.pill),
                ),
              ),
              child: _working
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm'),
            ),
          ),
          const SizedBox(height: Space.x2),
          SizedBox(
            width: double.infinity,
            height: Layout.minTapTarget,
            child: TextButton(
              onPressed: _working
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
