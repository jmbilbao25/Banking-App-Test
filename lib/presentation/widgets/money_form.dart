import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import 'brand.dart';
import 'money_text.dart';

/// Shared vocabulary for the money movement screens.
///
/// Transfer, Deposit and QR payment each hand rolled their own field styling,
/// their own gradient, their own button and their own success sheet, none of
/// which came from the design system. The result was three screens that read as
/// three different products, using a corporate blue that appears nowhere in the
/// brand palette and a balance figure that lost its typeface and its contrast.
///
/// Everything here resolves through `context.tokens`, `AppType`, `Space` and
/// `AppRadius`, so a money screen inherits the same surface language as the
/// dashboard, in both themes, for free.

/// Source or destination account context, shown inside the brand region.
///
/// The figure reads through [MoneyText] with the on brand colour passed as
/// `color`, not inside `style`. MoneyText overwrites the style colour with
/// `color ?? tokens.textPrimary`, so a colour set inside `style` is silently
/// discarded, which is how the previous version ended up rendering a near black
/// balance on a dark gradient.
class AccountContextCard extends StatelessWidget {
  const AccountContextCard({
    required this.account,
    this.caption = 'Available balance',
    super.key,
  });

  final Account account;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final onBrand = tokens.textOnBrand;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: AppType.labelMedium.copyWith(
              color: onBrand.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: Space.x2),
          MoneyText(
            account.availableBalance,
            currencyCode: account.currencyCode,
            style: AppType.numericLarge,
            color: onBrand,
            label: '${account.name} available',
          ),
          const SizedBox(height: Space.x3),
          Row(
            children: [
              Expanded(
                child: Text(
                  account.name,
                  style: AppType.titleSmall.copyWith(color: onBrand),
                ),
              ),
              Text(
                account.maskedNumber,
                style: AppType.numericSmall.copyWith(
                  color: onBrand.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Field label for the light content sheet, the counterpart of FrostFieldLabel.
class SheetFieldLabel extends StatelessWidget {
  const SheetFieldLabel(this.text, {this.optional = false, super.key});

  final String text;

  /// Renders a quieter "Optional" suffix rather than folding the word into the
  /// label, so the label itself stays the same length in every state.
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x2),
      child: Row(
        children: [
          Text(
            text,
            style: AppType.labelMedium.copyWith(color: tokens.textSecondary),
          ),
          if (optional) ...[
            const SizedBox(width: Space.x2),
            Text(
              'Optional',
              style: AppType.labelSmall.copyWith(
                color: tokens.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared input decoration for the light content sheet.
InputDecoration sheetFieldDecoration(
  BuildContext context, {
  String? hint,
  String? errorText,
  String? helperText,
  Widget? prefix,
  Widget? suffix,
  String? prefixText,
}) {
  final tokens = context.tokens;
  OutlineInputBorder border(Color colour, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colour, width: width),
      );

  return InputDecoration(
    counterText: '',
    hintText: hint,
    errorText: errorText,
    helperText: helperText,
    helperStyle: AppType.bodySmall.copyWith(color: tokens.textSecondary),
    errorStyle: AppType.bodySmall.copyWith(color: tokens.error),
    hintStyle: AppType.bodyMedium.copyWith(
      color: tokens.textSecondary.withValues(alpha: 0.7),
    ),
    prefixIcon: prefix,
    suffixIcon: suffix,
    prefixText: prefixText,
    prefixStyle: AppType.numericMedium.copyWith(color: tokens.textPrimary),
    filled: true,
    fillColor: tokens.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: Space.x4,
      vertical: Space.x4,
    ),
    border: border(tokens.border),
    enabledBorder: border(tokens.border),
    // Requirement 4.8: the focus indicator resolves from the accent token.
    focusedBorder: border(tokens.accent, 2),
    errorBorder: border(tokens.error),
    focusedErrorBorder: border(tokens.error, 2),
    disabledBorder: border(tokens.disabled),
  );
}

/// Text input for the light content sheet.
class SheetField extends StatelessWidget {
  const SheetField({
    required this.controller,
    this.hint,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.prefixText,
    this.numeric = false,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final String? prefixText;

  /// Sets the field in GeistMono, which requirement 1.8 mandates for every
  /// monetary figure, including the one being typed.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLength: maxLength,
      cursorColor: tokens.accent,
      style: (numeric ? AppType.numericMedium : AppType.bodyLarge).copyWith(
        color: tokens.textPrimary,
      ),
      decoration: sheetFieldDecoration(
        context,
        hint: hint,
        errorText: errorText,
        helperText: helperText,
        prefixText: prefixText,
      ),
    );
  }
}

/// Amount input. GeistMono, currency prefixed, two decimal places at most.
class AmountField extends ConsumerWidget {
  const AmountField({
    required this.controller,
    this.errorText,
    this.helperText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(preferencesProvider).activeCurrency.symbol;
    return SheetField(
      controller: controller,
      numeric: true,
      hint: '0.00',
      prefixText: '$symbol ',
      errorText: errorText,
      helperText: helperText,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
    );
  }
}

/// Account picker for the light content sheet.
class AccountSelectField extends StatelessWidget {
  const AccountSelectField({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    super.key,
  });

  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: sheetFieldDecoration(context),
      dropdownColor: tokens.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.md),
      icon: Icon(Icons.expand_more_rounded, color: tokens.textSecondary),
      style: AppType.bodyLarge.copyWith(color: tokens.textPrimary),
      // Name only. A dropdown measures its items against an unbounded width, so
      // a flexible child here throws during layout, and the balance would be
      // redundant anyway: AccountContextCard already shows the selected
      // account's available balance in the GeistMono that requirement 1.8 asks
      // for, which a mixed Geist and GeistMono row could not do.
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Text(
              account.name,
              style: AppType.bodyLarge.copyWith(color: tokens.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

/// Full width primary action.
///
/// Requirement 3.7: while a submission is in flight it renders a busy indicator,
/// keeps its resting width, and rejects further activation.
class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.hint,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  /// What the user still has to do before the action is offered.
  ///
  /// The money screens keep their primary action disabled until the form is
  /// valid, because the spec asks for the next step to stay disabled rather
  /// than to fail on press. On its own that reads as a dead button: a design
  /// review of the money screens called every one of them "permanently
  /// disabled" with "nothing to tell the user which field unlocks them". So a
  /// disabled action now states what is missing, in the same place, on every
  /// screen. This is guidance and not an error: it is shown for an untouched
  /// form, where the user has not yet made a mistake, and it sits below the
  /// button in secondary text rather than in the red [InlineFormError] used
  /// for something the user actually got wrong.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final disabled = onPressed == null && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: Layout.minTapTarget + Space.x1,
          child: FilledButton(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              foregroundColor: tokens.textOnBrand,
              disabledBackgroundColor: tokens.disabled,
              disabledForegroundColor: tokens.textSecondary,
              textStyle: AppType.labelLarge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: busy
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tokens.textOnBrand,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18),
                        const SizedBox(width: Space.x2),
                      ],
                      Text(label),
                    ],
                  ),
          ),
        ),
        if (disabled && hint != null) ...[
          const SizedBox(height: Space.x3),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Inline failure message above a primary action.
class InlineFormError extends StatelessWidget {
  const InlineFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: tokens.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tokens.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.error),
          const SizedBox(width: Space.x2),
          Expanded(
            child: Text(
              message,
              style: AppType.bodySmall.copyWith(color: tokens.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One label and value row, used by the review step and the receipt.
class MoneyReviewRow extends StatelessWidget {
  const MoneyReviewRow({
    required this.label,
    required this.value,
    this.emphasised = false,
    super.key,
  });

  final String label;
  final Widget value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      // No fixed height, so nothing clips at a 1.3 text scale (Req 4.3).
      padding: const EdgeInsets.symmetric(vertical: Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: (emphasised ? AppType.titleSmall : AppType.bodyMedium)
                  .copyWith(
                    color: emphasised
                        ? tokens.textPrimary
                        : tokens.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: Space.x3),
          value,
        ],
      ),
    );
  }
}

/// Outcome sheet shared by every money movement flow.
///
/// Requirement 16.10 and 16.11: a success states the reference and offers a way
/// back, and a failure states the reason and that no funds left the account.
class MoneyOutcomeSheet extends StatelessWidget {
  const MoneyOutcomeSheet({
    required this.succeeded,
    required this.heading,
    required this.detail,
    this.reference,
    super.key,
  });

  final bool succeeded;
  final String heading;
  final String detail;
  final String? reference;

  static Future<void> show(
    BuildContext context, {
    required bool succeeded,
    required String heading,
    required String detail,
    String? reference,
  }) => showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => MoneyOutcomeSheet(
      succeeded: succeeded,
      heading: heading,
      detail: detail,
      reference: reference,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = succeeded ? tokens.success : tokens.error;

    return Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              succeeded
                  ? Icons.check_rounded
                  : Icons.priority_high_rounded,
              color: accent,
              size: 32,
            ),
          ),
          const SizedBox(height: Space.x4),
          Semantics(
            header: true,
            child: Text(
              heading,
              textAlign: TextAlign.center,
              style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
            ),
          ),
          const SizedBox(height: Space.x2),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
          ),
          if (reference != null) ...[
            const SizedBox(height: Space.x4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x4,
                vertical: Space.x2,
              ),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                reference!,
                style: AppType.numericSmall.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.x6),
          PrimaryAction(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
