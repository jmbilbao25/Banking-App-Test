import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/dates.dart';
import '../../domain/models.dart';
import '../../state/preferences_controller.dart';
import '../../state/providers.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'change_pin_sheet.dart';

/// Profile, settings, security, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final profile = ref.watch(profileProvider);
    final preferences = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveShell(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x2,
            Space.x5,
            Space.x16 + Space.x16,
          ),
          children: [
            AsyncSection<UserProfile>(
              value: profile,
              onRetry: () => ref.invalidate(profileProvider),
              skeleton: Row(
                children: const [
                  SkeletonBlock(width: 64, height: 64, radius: AppRadius.pill),
                  SizedBox(width: Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(width: 140, height: 18),
                        SizedBox(height: Space.x2),
                        SkeletonBlock(width: 180, height: 13),
                      ],
                    ),
                  ),
                ],
              ),
              builder: (data) => Row(
                children: [
                  Monogram(
                    initials: data.initials,
                    size: 64,
                    background: tokens.interactiveSecondary,
                  ),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.fullName,
                          style: AppType.headlineMedium.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: Space.x1),
                        Text(
                          data.maskedEmail,
                          style: AppType.bodySmall.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        Text(
                          data.maskedMobile,
                          style: AppType.bodySmall.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        Text(
                          'Member since ${Dates.monthYear(data.memberSince)}',
                          style: AppType.bodySmall.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.x6),
            OutlinedButton.icon(
              onPressed: profile.value == null
                  ? null
                  : () => _showEditProfileModal(context, ref, profile.value!),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit details'),
            ),
            const SizedBox(height: Space.x8),
            const SectionHeader(title: 'Settings'),
            _SettingsCard(
              children: [
                _ThemeRow(mode: preferences.themeMode),
                _Divider(),
                _ActionRow(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: 'English',
                  onTap: () => _pickLanguage(context),
                ),
                _Divider(),
                _NavRow(
                  icon: Icons.attach_money_rounded,
                  label: 'Currency display',
                  value: preferences.activeCurrency.displayName,
                  route: '/currency',
                ),
              ],
            ),
            const SizedBox(height: Space.x6),
            const SectionHeader(title: 'Security'),
            _SettingsCard(
              children: [
                _ToggleRow(
                  icon: Icons.visibility_off_rounded,
                  label: 'Hide balances',
                  value: preferences.balancesHidden,
                  onChanged: (_) => ref
                      .read(preferencesProvider.notifier)
                      .toggleBalanceVisibility(),
                ),
                _Divider(),
                _ActionRow(
                  icon: Icons.pin_rounded,
                  label: ref.watch(pinVaultProvider).hasPin
                      ? 'Change PIN'
                      : 'Set PIN',
                  onTap: () => _changePin(context),
                ),
                _Divider(),
                const _BiometricRow(),
                _Divider(),
                _ActionRow(
                  icon: Icons.timer_outlined,
                  label: 'Session timeout',
                  value: _timeoutLabel(preferences.sessionTimeout),
                  onTap: () => _pickSessionTimeout(context, ref),
                ),
              ],
            ),
            const SizedBox(height: Space.x6),
            const SectionHeader(title: 'About'),
            _SettingsCard(
              children: [
                _ActionRow(
                  icon: Icons.info_outline_rounded,
                  label: 'About this build',
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text(
              'Every balance, card, rate, and transaction in this application is mock data.',
              style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: Space.x8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.all(AppRadius.pill),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final tokens = context.tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Space.x2),
              decoration: BoxDecoration(
                color: tokens.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, color: tokens.error, size: 22),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                'Log out',
                style: AppType.titleMedium.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out? You will need to sign in again to access your accounts.',
          style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          Space.x4,
          0,
          Space.x4,
          Space.x4,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: Space.x3),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: Space.x3),
                  ),
                  child: const Text('Log Out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(sessionProvider.notifier).signOut();
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: AppRadius.all(AppRadius.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: context.tokens.border,
    indent: Space.x4,
    endIndent: Space.x4,
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.route,
    this.value,
  });

  final IconData icon;
  final String label;
  final String route;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Pressable(
      onTap: () => context.push(route),
      semanticLabel: value == null ? label : '$label, $value',
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.textSecondary),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                label,
                style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
              ),
            const SizedBox(width: Space.x1),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A settings row that runs a callback instead of pushing a route, so a control
/// can open a sheet without a placeholder destination.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Pressable(
      onTap: onTap,
      semanticLabel: value == null ? label : '$label, $value',
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x4,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.textSecondary),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Text(
                label,
                style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
              ),
            ),
            if (value != null)
              Text(
                value!,
                style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
              ),
            const SizedBox(width: Space.x1),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Biometric unlock toggle.
///
/// Requirement 23.7: where the device reports no enrolled biometric the control
/// renders disabled with a message saying so, rather than offering a switch that
/// silently does nothing. The state is read from the platform, so it is a real
/// semantic value as requirement 25.4 asks.
class _BiometricRow extends ConsumerWidget {
  const _BiometricRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolled = ref.watch(biometricEnrolledProvider);
    final preferences = ref.watch(preferencesProvider);

    return enrolled.when(
      loading: () => const _ToggleRow(
        icon: Icons.fingerprint_rounded,
        label: 'Biometric unlock',
        value: false,
        onChanged: null,
        subtitle: 'Checking this device',
      ),
      error: (_, _) => const _ToggleRow(
        icon: Icons.fingerprint_rounded,
        label: 'Biometric unlock',
        value: false,
        onChanged: null,
        subtitle: 'We could not check this device',
      ),
      data: (isEnrolled) => _ToggleRow(
        icon: Icons.fingerprint_rounded,
        label: 'Biometric unlock',
        value: isEnrolled && preferences.biometricUnlock,
        subtitle: isEnrolled
            ? null
            : 'No biometric is enrolled on this device',
        onChanged: isEnrolled
            ? (next) =>
                  ref.read(preferencesProvider.notifier).setBiometricUnlock(next)
            : null,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool value;

  /// Null renders the switch disabled.
  final ValueChanged<bool>? onChanged;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x2,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: disabled ? tokens.disabled : tokens.textSecondary,
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.titleSmall.copyWith(
                    color: disabled ? tokens.textSecondary : tokens.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.x1),
                  Text(
                    subtitle!,
                    style: AppType.bodySmall.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: tokens.accent,
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  const _ThemeRow({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_rounded,
                size: 20,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: Space.x3),
              Text(
                'Theme',
                style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => ref
                .read(preferencesProvider.notifier)
                .setThemeMode(selection.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: tokens.surface,
              foregroundColor: tokens.textSecondary,
              selectedBackgroundColor: tokens.interactiveSecondary,
              selectedForegroundColor: tokens.interactivePrimary,
              side: BorderSide(color: tokens.border),
              textStyle: AppType.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

String _timeoutLabel(Duration timeout) {
  if (timeout.inMinutes < 1) return '${timeout.inSeconds} seconds';
  final minutes = timeout.inMinutes;
  return minutes == 1 ? '1 minute' : '$minutes minutes';
}

Future<void> _changePin(BuildContext context) async {
  final changed = await ChangePinSheet.show(context);
  if (changed != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Your PIN has been updated.')),
  );
}

/// Requirement 23.4: the customer sets the session timeout. The shortest option
/// is the 120 seconds requirement 5.4 names, so the choice cannot weaken the
/// floor the specification sets.
Future<void> _pickSessionTimeout(BuildContext context, WidgetRef ref) async {
  final current = ref.read(preferencesProvider).sessionTimeout;

  final chosen = await showModalBottomSheet<Duration>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      final tokens = sheetContext.tokens;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session timeout',
                    style: AppType.titleLarge.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Text(
                    'How long FrostBank can sit in the background before it asks '
                    'for your PIN again.',
                    style: AppType.bodySmall.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            RadioGroup<Duration>(
              groupValue: current,
              onChanged: (value) => Navigator.of(sheetContext).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in Preferences.sessionTimeoutOptions)
                    RadioListTile<Duration>(
                      value: option,
                      activeColor: tokens.accent,
                      title: Text(
                        _timeoutLabel(option),
                        style: AppType.titleSmall.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.x4),
          ],
        ),
      );
    },
  );

  if (chosen == null) return;
  ref.read(preferencesProvider.notifier).setSessionTimeout(chosen);
}

/// Requirement 23.3 asks for a language option. Only English ships, so the sheet
/// says exactly that instead of routing to a placeholder screen.
Future<void> _pickLanguage(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (sheetContext) {
    final tokens = sheetContext.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language',
              style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: Space.x2),
            Text(
              'FrostBank is available in English. More languages are not part of '
              'this build.',
              style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: Space.x5),
            Row(
              children: [
                Icon(Icons.check_rounded, size: 20, color: tokens.accent),
                const SizedBox(width: Space.x3),
                Text(
                  'English',
                  style: AppType.titleSmall.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

/// Requirement 23.9: the About section states that every figure is mock data.
Future<void> _showAbout(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (sheetContext) {
    final tokens = sheetContext.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About this build',
              style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: Space.x3),
            Text(
              'FrostBank is a presentation build. Every balance, card number, '
              'rate, holding and transaction in this application is mock data '
              'generated on this device. No real account is reachable and no '
              'money can move.',
              style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: Space.x4),
            Text(
              'Your PIN is stored on this device as a salted digest, never as '
              'the digits you chose.',
              style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  },
);

void _showEditProfileModal(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) {
  final nameCtrl = TextEditingController(text: profile.fullName);
  final emailCtrl = TextEditingController(text: profile.email);
  final mobileCtrl = TextEditingController(text: profile.mobile);

  showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: mobileCtrl,
            decoration: const InputDecoration(labelText: 'Mobile'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final updated = UserProfile(
              id: profile.id,
              fullName: nameCtrl.text.trim(),
              email: emailCtrl.text.trim(),
              mobile: mobileCtrl.text.trim(),
              memberSince: profile.memberSince,
            );

            try {
              await ref.read(profileRepositoryProvider).updateProfile(updated);
              ref.invalidate(profileProvider);
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not update profile: $e')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
