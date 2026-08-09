import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';

// ── Category icon data ────────────────────────────────────────────────────────

class _IconOption {
  const _IconOption(this.icon, this.label, this.key);
  final IconData icon;
  final String label;
  /// Stable string key stored in GoalSave.emoji.
  final String key;
}

class _Category {
  const _Category(this.label, this.icons);
  final String label;
  final List<_IconOption> icons;
}

const _categories = [
  _Category('Travel', [
    _IconOption(Icons.flight_rounded, 'Flight', 'flight'),
    _IconOption(Icons.beach_access_rounded, 'Beach', 'beach'),
    _IconOption(Icons.sailing_rounded, 'Sailing', 'sailing'),
    _IconOption(Icons.luggage_rounded, 'Luggage', 'luggage'),
    _IconOption(Icons.map_rounded, 'Map', 'map'),
    _IconOption(Icons.hotel_rounded, 'Hotel', 'hotel'),
  ]),
  _Category('Home', [
    _IconOption(Icons.home_rounded, 'Home', 'home'),
    _IconOption(Icons.chair_rounded, 'Furniture', 'chair'),
    _IconOption(Icons.construction_rounded, 'Renovation', 'construction'),
    _IconOption(Icons.garage_rounded, 'Garage', 'garage'),
    _IconOption(Icons.yard_rounded, 'Garden', 'yard'),
    _IconOption(Icons.kitchen_rounded, 'Kitchen', 'kitchen'),
  ]),
  _Category('Tech', [
    _IconOption(Icons.laptop_rounded, 'Laptop', 'laptop'),
    _IconOption(Icons.smartphone_rounded, 'Phone', 'smartphone'),
    _IconOption(Icons.headphones_rounded, 'Audio', 'headphones'),
    _IconOption(Icons.videogame_asset_rounded, 'Gaming', 'gaming'),
    _IconOption(Icons.camera_alt_rounded, 'Camera', 'camera'),
    _IconOption(Icons.tv_rounded, 'TV', 'tv'),
  ]),
  _Category('Health', [
    _IconOption(Icons.fitness_center_rounded, 'Fitness', 'fitness'),
    _IconOption(Icons.spa_rounded, 'Wellness', 'spa'),
    _IconOption(Icons.local_hospital_rounded, 'Medical', 'medical'),
    _IconOption(Icons.directions_run_rounded, 'Running', 'running'),
    _IconOption(Icons.self_improvement_rounded, 'Mindfulness', 'mindfulness'),
    _IconOption(Icons.restaurant_rounded, 'Diet', 'restaurant'),
  ]),
  _Category('Life', [
    _IconOption(Icons.school_rounded, 'Education', 'school'),
    _IconOption(Icons.diamond_rounded, 'Ring', 'diamond'),
    _IconOption(Icons.child_care_rounded, 'Baby', 'baby'),
    _IconOption(Icons.pets_rounded, 'Pets', 'pets'),
    _IconOption(Icons.cake_rounded, 'Celebration', 'cake'),
    _IconOption(Icons.volunteer_activism_rounded, 'Giving', 'giving'),
  ]),
  _Category('Finance', [
    _IconOption(Icons.savings_rounded, 'Savings', 'savings'),
    _IconOption(Icons.shield_rounded, 'Emergency', 'shield'),
    _IconOption(Icons.trending_up_rounded, 'Investment', 'trending'),
    _IconOption(Icons.account_balance_rounded, 'Bank', 'bank'),
    _IconOption(Icons.currency_exchange_rounded, 'Currency', 'currency'),
    _IconOption(Icons.wallet_rounded, 'Wallet', 'wallet'),
  ]),
];

/// Flat key → IconData lookup, tree-shake safe (all references are constants).
const Map<String, IconData> _iconByKey = {
  'flight': Icons.flight_rounded,
  'beach': Icons.beach_access_rounded,
  'sailing': Icons.sailing_rounded,
  'luggage': Icons.luggage_rounded,
  'map': Icons.map_rounded,
  'hotel': Icons.hotel_rounded,
  'home': Icons.home_rounded,
  'chair': Icons.chair_rounded,
  'construction': Icons.construction_rounded,
  'garage': Icons.garage_rounded,
  'yard': Icons.yard_rounded,
  'kitchen': Icons.kitchen_rounded,
  'laptop': Icons.laptop_rounded,
  'smartphone': Icons.smartphone_rounded,
  'headphones': Icons.headphones_rounded,
  'gaming': Icons.videogame_asset_rounded,
  'camera': Icons.camera_alt_rounded,
  'tv': Icons.tv_rounded,
  'fitness': Icons.fitness_center_rounded,
  'spa': Icons.spa_rounded,
  'medical': Icons.local_hospital_rounded,
  'running': Icons.directions_run_rounded,
  'mindfulness': Icons.self_improvement_rounded,
  'restaurant': Icons.restaurant_rounded,
  'school': Icons.school_rounded,
  'diamond': Icons.diamond_rounded,
  'baby': Icons.child_care_rounded,
  'pets': Icons.pets_rounded,
  'cake': Icons.cake_rounded,
  'giving': Icons.volunteer_activism_rounded,
  'savings': Icons.savings_rounded,
  'shield': Icons.shield_rounded,
  'trending': Icons.trending_up_rounded,
  'bank': Icons.account_balance_rounded,
  'currency': Icons.currency_exchange_rounded,
  'wallet': Icons.wallet_rounded,
};

/// Resolves a goal icon key to an [IconData]. Falls back to [Icons.savings_rounded].
/// Exported so savings_screen.dart and goal_detail_screen.dart can use it.
IconData resolveGoalIcon(String key) =>
    _iconByKey[key] ?? Icons.savings_rounded;

// ── Sheet ─────────────────────────────────────────────────────────────────────

class OpenGoalSheet extends ConsumerStatefulWidget {
  const OpenGoalSheet({super.key});

  @override
  ConsumerState<OpenGoalSheet> createState() => _OpenGoalSheetState();
}

class _OpenGoalSheetState extends ConsumerState<OpenGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedIconKey = 'savings'; // default — Finance category
  int _selectedCategoryIndex = 5; // Finance
  String _targetRaw = '';
  String _depositRaw = '';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.x5, Space.x5, Space.x5, Space.x3,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: Space.x4),
                    decoration: BoxDecoration(
                      color: tokens.border,
                      borderRadius: AppRadius.all(AppRadius.pill),
                    ),
                  ),
                ),

                Text(
                  'Open a goal save',
                  style: AppType.headlineMedium.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: Space.x1),
                Text(
                  'Earn 4.35% APY, credited daily to your balance.',
                  style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
                ),

                const SizedBox(height: Space.x5),

                // ── Category + icon picker ───────────────────────────────
                _CategoryIconPicker(
                  selectedIconKey: _selectedIconKey,
                  selectedCategoryIndex: _selectedCategoryIndex,
                  onCategoryChanged: (i) =>
                      setState(() => _selectedCategoryIndex = i),
                  onIconSelected: (key) =>
                      setState(() => _selectedIconKey = key),
                ),

                const SizedBox(height: Space.x4),

                // ── Goal name ────────────────────────────────────────────
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Goal name',
                    hintText: 'e.g. Europe Trip',
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.all(AppRadius.md),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Give your goal a name';
                    }
                    if (v.trim().length > 40) {
                      return 'Keep it under 40 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: Space.x4),

                // ── Target amount ────────────────────────────────────────
                _AmountTapField(
                  label: 'Target amount',
                  helperText: 'Optional. Leave blank for open ended.',
                  value: _targetRaw,
                  onChanged: (v) => setState(() => _targetRaw = v),
                ),

                const SizedBox(height: Space.x4),

                // ── Initial deposit ──────────────────────────────────────
                _AmountTapField(
                  label: 'Initial deposit',
                  helperText: 'Optional. You can add funds any time.',
                  value: _depositRaw,
                  onChanged: (v) => setState(() => _depositRaw = v),
                ),

                const SizedBox(height: Space.x4),

                // ── APY reminder ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(Space.x3),
                  decoration: BoxDecoration(
                    color: tokens.interactiveSecondary,
                    borderRadius: AppRadius.all(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded,
                          size: 16, color: tokens.accent),
                      const SizedBox(width: Space.x2),
                      Expanded(
                        child: Text(
                          '4.35% APY · Interest credited every day',
                          style: AppType.labelSmall.copyWith(
                            color: tokens.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Space.x5),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.all(AppRadius.pill),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Open goal save'),
                  ),
                ),

                const SizedBox(height: Space.x2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final target = _targetRaw.isEmpty ? 0.0 : double.tryParse(_targetRaw) ?? 0.0;
    final deposit =
        _depositRaw.isEmpty ? 0.0 : double.tryParse(_depositRaw) ?? 0.0;

    setState(() => _loading = true);

    final ok = await ref.read(savingsControllerProvider.notifier).openGoal(
          name: name,
          emoji: _selectedIconKey,
          targetAmount: target,
          initialDeposit: deposit,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      final state = ref.read(savingsControllerProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name goal save opened!')),
      );
      if (state is SavingsSuccess) {
        context.push('/savings/${state.goal.id}');
      }
    } else {
      final err = ref.read(savingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err is SavingsError ? err.message : 'Something went wrong.',
          ),
        ),
      );
    }
  }
}

// ── Category + icon picker ────────────────────────────────────────────────────

class _CategoryIconPicker extends StatelessWidget {
  const _CategoryIconPicker({
    required this.selectedIconKey,
    required this.selectedCategoryIndex,
    required this.onCategoryChanged,
    required this.onIconSelected,
  });

  final String selectedIconKey;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategoryChanged;
  final ValueChanged<String> onIconSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final category = _categories[selectedCategoryIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Goal icon',
          style: AppType.labelMedium.copyWith(color: tokens.textSecondary),
        ),
        const SizedBox(height: Space.x2),

        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _categories.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: Space.x2),
                  child: _CategoryChip(
                    label: _categories[i].label,
                    selected: i == selectedCategoryIndex,
                    onTap: () => onCategoryChanged(i),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: Space.x3),

        // Icon grid — fixed 44×44 cells in a wrapping row
        Wrap(
          spacing: Space.x2,
          runSpacing: Space.x2,
          children: [
            for (final option in category.icons)
              _IconCell(
                icon: option.icon,
                label: option.label,
                selected: selectedIconKey == option.key,
                onTap: () => onIconSelected(option.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x2,
        ),
        decoration: BoxDecoration(
          color:
              selected ? tokens.interactivePrimary : tokens.surface,
          borderRadius: AppRadius.all(AppRadius.pill),
          border: Border.all(
            color: selected ? tokens.interactivePrimary : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: AppType.labelSmall.copyWith(
            color: selected ? Colors.white : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _IconCell extends StatelessWidget {
  const _IconCell({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? tokens.interactivePrimary : tokens.surface,
            borderRadius: AppRadius.all(AppRadius.sm),
            border: Border.all(
              color: selected ? tokens.interactivePrimary : tokens.border,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Amount tap-field + numeric keypad ─────────────────────────────────────────

/// A read-only field that, when tapped, opens a modal numeric keypad.
class _AmountTapField extends StatelessWidget {
  const _AmountTapField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? helperText;

  String get _display => value.isEmpty ? '' : '\$$value';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _NumPadSheet(label: label, initial: value),
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x4,
        ),
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          borderRadius: AppRadius.all(AppRadius.md),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppType.bodySmall.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _display.isEmpty ? 'Tap to enter amount' : _display,
                    style: _display.isEmpty
                        ? AppType.bodyMedium.copyWith(
                            color: tokens.textSecondary.withValues(alpha: 0.5),
                          )
                        : AppType.titleSmall.copyWith(
                            color: tokens.textPrimary,
                          ),
                  ),
                  if (helperText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      helperText!,
                      style: AppType.bodySmall.copyWith(
                        color: tokens.textSecondary.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: tokens.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Numeric keypad modal — the same one also used by the transfer sheet.
class _NumPadSheet extends StatefulWidget {
  const _NumPadSheet({required this.label, required this.initial});

  final String label;
  final String initial;

  @override
  State<_NumPadSheet> createState() => _NumPadSheetState();
}

class _NumPadSheetState extends State<_NumPadSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  void _tap(String key) {
    setState(() {
      if (key == '⌫') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
        return;
      }
      if (key == '.') {
        if (_value.contains('.')) return;
        if (_value.isEmpty) _value = '0';
        _value = '$_value.';
        return;
      }
      // Guard: max 2 decimal places
      if (_value.contains('.')) {
        final parts = _value.split('.');
        if (parts.last.length >= 2) return;
      }
      // Guard: max 10 digits before decimal
      if (!_value.contains('.') && _value.replaceAll(',', '').length >= 10) {
        return;
      }
      // Strip leading zeros unless followed by decimal
      if (_value == '0') {
        _value = key;
        return;
      }
      _value = '$_value$key';
    });
  }

  bool get _isValid {
    final parsed = double.tryParse(_value);
    return parsed != null && parsed > 0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: Space.x4, bottom: Space.x3),
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: AppRadius.all(AppRadius.pill),
              ),
            ),

            // Label
            Text(
              widget.label,
              style: AppType.labelMedium.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: Space.x3),

            // Amount display
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: Space.x8),
              child: Text(
                _value.isEmpty ? '0' : '\$$_value',
                style: AppType.numericLarge.copyWith(
                  color: tokens.textPrimary,
                  fontSize: 44,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: Space.x5),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x6),
              child: _Keypad(onKey: _tap),
            ),

            const SizedBox(height: Space.x4),

            // Confirm
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: Space.x5),
              child: FilledButton(
                onPressed: _isValid
                    ? () => Navigator.pop(context, _value)
                    : null,
                child: const Text('Confirm'),
              ),
            ),
            const SizedBox(height: Space.x3),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _keys)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: Row(
              children: [
                for (final key in row) ...[
                  Expanded(child: _KeyCell(label: key, onTap: () => onKey(key))),
                  if (key != row.last) const SizedBox(width: Space.x2),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _KeyCell extends StatelessWidget {
  const _KeyCell({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isBackspace = label == '⌫';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.all(AppRadius.md),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: AppRadius.all(AppRadius.md),
          ),
          alignment: Alignment.center,
          child: isBackspace
              ? Icon(Icons.backspace_outlined,
                  size: 20, color: tokens.textSecondary)
              : Text(
                  label,
                  style: AppType.headlineMedium.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Public numeric keypad sheet — reused by the transfer sheets in
/// goal_detail_screen.dart.
class NumPadSheet extends StatelessWidget {
  const NumPadSheet({required this.label, required this.initial, super.key});

  final String label;
  final String initial;

  @override
  Widget build(BuildContext context) =>
      _NumPadSheet(label: label, initial: initial);
}
