import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/tokens.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/app_lock_confirm.dart';
import '../widgets/money_text.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedSourceAccountId;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit(Account sourceAccount) async {
    if (_submitting) return;

    final recipient = _recipientController.text.trim();
    final amountText = _amountController.text.trim();
    final note = _noteController.text.trim();

    final amount = double.tryParse(amountText);
    if (recipient.isEmpty) {
      setState(() => _errorMessage = 'Please enter a recipient.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid amount.');
      return;
    }

    final prefs = ref.read(preferencesProvider);
    final symbol = prefs.activeCurrency.symbol;
    final currencyCode = prefs.currencyCode;

    final convertedAvail = Money.convert(
      sourceAccount.availableBalance,
      fromCurrency: sourceAccount.currencyCode,
      toCurrency: currencyCode,
    );

    if (amount > convertedAvail) {
      setState(() => _errorMessage = 'Insufficient funds.');
      return;
    }

    final baseUsdAmount = Money.convert(
      amount,
      fromCurrency: currencyCode,
      toCurrency: 'USD',
    );

    // Requirement 16.9: App_Lock confirms the customer before Repository_Layer
    // performs the transfer. Nothing has moved at this point, so a refusal
    // simply returns to the form.
    final confirmed = await confirmWithAppLock(
      context,
      ref,
      reason:
          'Confirm sending $symbol${amount.toStringAsFixed(2)} to $recipient.',
    );
    if (!mounted || !confirmed) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(accountRepositoryProvider).transfer(
            fromAccountId: sourceAccount.id,
            recipient: recipient,
            amount: baseUsdAmount,
            note: note.isEmpty ? null : note,
          );

      ref.invalidate(accountsProvider);
      ref.invalidate(accountProvider(sourceAccount.id));
      ref.invalidate(transactionsProvider);

      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 70),
                const SizedBox(height: 16),
                Text('Transfer Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                Text(
                  '$symbol${amount.toStringAsFixed(2)} was successfully withdrawn from ${sourceAccount.name} and sent to $recipient.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF4A4A7A) : const Color(0xFF003366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx); 
                      Navigator.pop(context); 
                    },
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Transfer failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final activeSymbol = ref.watch(preferencesProvider).activeCurrency.symbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Send Money'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: isDark ? Colors.redAccent : Colors.red))),
        data: (accounts) {
          if (accounts.isEmpty) return const Center(child: Text('No accounts available.'));
          if (_selectedSourceAccountId == null && accounts.isNotEmpty) {
            _selectedSourceAccountId = accounts.first.id;
          }
          final sourceAccount = accounts.firstWhere((a) => a.id == _selectedSourceAccountId, orElse: () => accounts.first);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From Account', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceAccountId,
                  decoration: inputDecoration,
                  dropdownColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
                  items: accounts.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text(a.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSourceAccountId = val);
                  },
                ),
                const SizedBox(height: 20),
                
                // Viewable Source Account Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [const Color(0xFF2A2A4A), const Color(0xFF1E1E32)] 
                          : [const Color(0xFF003366), const Color(0xFF0055A4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      MoneyText(
                        sourceAccount.availableBalance,
                        currencyCode: sourceAccount.currencyCode,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(sourceAccount.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      Text('Account: ${sourceAccount.maskedNumber}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                
                // SPACER ADJUSTMENT: Increased spacing between card and recipient
                const SizedBox(height: 32), 

                Text('Recipient Name', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipientController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: inputDecoration.copyWith(hintText: 'e.g. John Doe'),
                ),
                const SizedBox(height: 20),
                
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
                const SizedBox(height: 20),

                Text('Note (Optional)', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: inputDecoration.copyWith(hintText: 'What is this for?'),
                ),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF4A4A7A) : const Color(0xFF003366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                    onPressed: _submitting ? null : () => _submit(sourceAccount),
                    child: _submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send Funds', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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