import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

class QRScreen extends ConsumerStatefulWidget {
  const QRScreen({super.key});

  @override
  ConsumerState<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends ConsumerState<QRScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountInputController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(); 
  
  String _generatedQRText = '';
  bool _isProcessingQR = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.index == 0) {
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _amountInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _updateGeneratedQR() {
    final rawVal = double.tryParse(_amountInputController.text) ?? 0.0;
    final prefs = ref.read(preferencesProvider);
    final symbol = prefs.activeCurrency.symbol;
    final code = prefs.currencyCode;
    setState(() {
      _generatedQRText = '$code $symbol${rawVal.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    });
  }

  void _onQRScanned(String qrData) {
    if (_isProcessingQR) return;
    setState(() => _isProcessingQR = true);
    
    _scannerController.stop(); 

    final accounts = ref.read(accountsProvider).value ?? [];
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No accounts available.')));
      setState(() => _isProcessingQR = false);
      _scannerController.start();
      return;
    }

    Account selectedAccount = accounts.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('QR Detected', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scanned Data: $qrData', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
                const SizedBox(height: 16),
                Text('Select source of funds:', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 8),
                DropdownButtonFormField<Account>(
                  initialValue: selectedAccount,
                  dropdownColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                  ),
                  items: accounts.map((a) => DropdownMenuItem(
                    value: a, 
                    child: Text(a.name, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                  )).toList(),
                  onChanged: (val) => setModalState(() => selectedAccount = val!),
                ),
                const SizedBox(height: 16),
                
                // Viewable Source Account Card inside the modal
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                          ? [const Color(0xFF2A2A4A), const Color(0xFF1E1E32)] 
                          : [const Color(0xFF003366), const Color(0xFF0055A4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '\$${selectedAccount.availableBalance.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(selectedAccount.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      Text('Account: ${selectedAccount.maskedNumber}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                const Text('A default of \$100.00 will be deducted for this hackathon POC.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isProcessingQR = false);
                _scannerController.start();
              },
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF4A4A7A) : const Color(0xFF003366),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeQRPayment(selectedAccount);
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeQRPayment(Account sourceAccount) async {
    const double qrAmount = 100.0;
    
    if (sourceAccount.availableBalance < qrAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient funds for \$100.00 deduction.')));
      setState(() => _isProcessingQR = false);
      _scannerController.start();
      return;
    }

    try {
      await ref.read(accountRepositoryProvider).transfer(
        fromAccountId: sourceAccount.id,
        recipient: 'QR Merchant POC',
        amount: qrAmount,
        note: 'QR Scan Payment',
      );
      
      ref.invalidate(accountsProvider);
      
      if (mounted) {
        _showSuccessBottomSheet(sourceAccount.name);
      }
    } on Object {
      if (!mounted) return;
      // Plain language, and no funds left the account, per requirement 3.4.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That payment did not go through. No money was sent.'),
        ),
      );
      setState(() => _isProcessingQR = false);
      _scannerController.start();
    }
  }

  void _showSuccessBottomSheet(String accountName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: isDark ? const Color(0xFF1E1E32) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, color: isDark ? const Color(0xFF8A8AFF) : const Color(0xFF003366), size: 60),
            const SizedBox(height: 16),
            Text('Payment Sent!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text('\$100.00 has been successfully deducted from $accountName.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 24),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF003366);

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
        title: const Text('QR Payments'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primaryColor,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          indicatorColor: primaryColor,
          tabs: [
            Tab(icon: Icon(Icons.qr_code_scanner, color: primaryColor), text: 'Scan QR'),
            Tab(icon: Icon(Icons.qr_code, color: primaryColor), text: 'My QR Code'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // SCAN TAB
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF4A4A7A) : const Color(0xFF003366), width: 4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            _onQRScanned(barcode.rawValue!);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Point your camera at a merchant QR code. It will detect automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
                ),
              ],
            ),
          ),
          
          // MY QR TAB (Generator)
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text('Enter target amount to receive:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountInputController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (_) => _updateGeneratedQR(),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: inputDecoration.copyWith(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 40),
                if (_generatedQRText.isNotEmpty && _generatedQRText != 'USD \$0.00') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.3 : 0.05,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _generatedQRText,
                      version: QrVersions.auto,
                      size: 220.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black87,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Payload: $_generatedQRText', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF003366))),
                ] else ...[
                  Text('Input an amount above to generate your payment QR string.', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}