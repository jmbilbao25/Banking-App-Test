import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/persistence/pin_vault.dart';
import '../../state/providers.dart';

/// Which entry the sheet is collecting.
enum _Step {
  /// Requirement 23.5: the current PIN is required first.
  current,
  next,
  confirm,
}

/// Changes the App_Lock PIN.
///
/// Requirement 23.5 requires the current PIN before two matching new six digit
/// entries, and requirement 23.6 requires an inline message that keeps the
/// current PIN in place when the check fails. When no PIN exists yet the sheet
/// opens on the new entry, because there is nothing to confirm against.
class ChangePinSheet extends ConsumerStatefulWidget {
  const ChangePinSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const ChangePinSheet(),
  );

  @override
  ConsumerState<ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<ChangePinSheet> {
  final _controller = TextEditingController();
  late _Step _step;
  String? _error;
  String? _firstEntry;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _step = ref.read(pinVaultProvider).hasPin ? _Step.current : _Step.next;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title => switch (_step) {
    _Step.current => 'Enter your current PIN',
    _Step.next => 'Choose a new PIN',
    _Step.confirm => 'Confirm your new PIN',
  };

  String get _helper => switch (_step) {
    _Step.current => 'We ask for this before any change.',
    _Step.next => 'Use ${PinVault.pinLength} digits you will remember.',
    _Step.confirm => 'Enter the same ${PinVault.pinLength} digits again.',
  };

  Future<void> _submit() async {
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

    switch (_step) {
      case _Step.current:
        if (!vault.verify(entry)) {
          // Requirement 23.6: the current PIN stays in place.
          HapticFeedback.vibrate();
          setState(() {
            _working = false;
            _error = 'That PIN is incorrect. Your PIN has not changed.';
            _controller.clear();
          });
          return;
        }
        setState(() {
          _working = false;
          _step = _Step.next;
          _controller.clear();
        });
      case _Step.next:
        setState(() {
          _working = false;
          _firstEntry = entry;
          _step = _Step.confirm;
          _controller.clear();
        });
      case _Step.confirm:
        if (entry != _firstEntry) {
          HapticFeedback.vibrate();
          setState(() {
            _working = false;
            _error = 'Those PINs did not match. Choose a new PIN again.';
            _firstEntry = null;
            _step = _Step.next;
            _controller.clear();
          });
          return;
        }
        await vault.setPin(entry);
        if (!mounted) return;
        Navigator.of(context).pop(true);
    }
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
          Text(
            _title,
            style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: Space.x2),
          Text(
            _helper,
            style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
          ),
          const SizedBox(height: Space.x5),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: PinVault.pinLength,
            style: AppType.numericMedium.copyWith(
              color: tokens.textPrimary,
              letterSpacing: 8,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              labelText: 'PIN',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: AppRadius.all(AppRadius.md),
              ),
            ),
            onSubmitted: (_) => _working ? null : _submit(),
          ),
          const SizedBox(height: Space.x5),
          SizedBox(
            width: double.infinity,
            height: 52,
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
                  : Text(_step == _Step.confirm ? 'Save PIN' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
