import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/tokens.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit(Account account) async {
    if (_submitting) return;

    final amountText = _amountController.text.trim();
    final inputAmount = double.tryParse(amountText);
    
    if (inputAmount == null || inputAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid deposit amount.');
      return;
    }

    final prefs = ref.read(preferencesProvider);
    final symbol = prefs.activeCurrency.symbol;
    final currencyCode = prefs.currencyCode;

    final baseUsdAmount = Money.convert(
      inputAmount,
      fromCurrency: currencyCode,
      toCurrency: 'USD',
    );

    final refCode = 'DEP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Deposit Receipt', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Destination: ${account.name}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            Text('Inputted Amount: $symbol${inputAmount.toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            Text('Reference Code: $refCode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
            const Divider(height: 24),
            Text(
              'To complete this deposit in the real world, input this reference code at a cash machine. \n\nClosing this dialog will simulate a machine deposit to your account.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF4A4A7A) : const Color(0xFF003366),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                Navigator.pop(ctx); 
                await _executeDefaultDeposit(account, baseUsdAmount, inputAmount, symbol); 
              },
              child: Text('Confirm Deposit ($symbol${inputAmount.toStringAsFixed(2)})', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDefaultDeposit(Account account, double baseUsdAmount, double inputAmount, String symbol) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(accountRepositoryProvider).deposit(
            accountId: account.id,
            amount: baseUsdAmount,
          );

      ref.invalidate(accountsProvider);
      ref.invalidate(accountProvider(account.id));
      ref.invalidate(transactionsProvider);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deposit of $symbol${inputAmount.toStringAsFixed(2)} to ${account.name} successful!')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Deposit failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final activeSymbol = ref.watch(preferencesProvider).activeCurrency.symbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Themed Input Decoration
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: isDark ? Colors.white60 : const Color(0xFF003366), width: 1),
      ),
      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Deposit Funds'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: isDark ? Colors.redAccent : Colors.red))),
        data: (accounts) {
          if (accounts.isEmpty) return const Center(child: Text('No accounts available.'));
          if (_selectedAccountId == null && accounts.isNotEmpty) {
            _selectedAccountId = accounts.first.id;
          }
          final selectedAccount = accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Destination Account', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: inputDecoration,
                  dropdownColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
                  items: accounts.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAccountId = val);
                  },
                ),
                const SizedBox(height: 24),
                Text('Amount', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: inputDecoration.copyWith(
                    prefixText: '$activeSymbol ',
                    prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                    hintText: '0.00',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF4A4A7A) : const Color(0xFF003366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                    onPressed: _submitting ? null : () => _submit(selectedAccount),
                    child: _submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm Deposit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}