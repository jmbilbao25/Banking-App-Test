import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persistence/persistence_store.dart';
import 'providers.dart';

class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
  });

  final String code;
  final String name;
  final String symbol;

  String get displayName => '$name ($symbol)';
}

const List<CurrencyOption> supportedCurrencies = [
  CurrencyOption(code: 'USD', name: 'US dollar', symbol: '\$'),
  CurrencyOption(code: 'EUR', name: 'Euro', symbol: '€'),
  CurrencyOption(code: 'GBP', name: 'British pound', symbol: '£'),
  CurrencyOption(code: 'JPY', name: 'Japanese yen', symbol: '¥'),
  CurrencyOption(code: 'PHP', name: 'Philippine peso', symbol: '₱'),
  CurrencyOption(code: 'CAD', name: 'Canadian dollar', symbol: 'CA\$'),
  CurrencyOption(code: 'AUD', name: 'Australian dollar', symbol: 'A\$'),
];

/// User preferences that affect the whole application.
@immutable
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.balancesHidden = false,
    this.currencyCode = 'USD',
    this.rememberedEmail,
    this.sessionTimeout = defaultSessionTimeout,
    this.biometricUnlock = true,
  });

  /// Requirement 5.4 names 120 seconds, so that is the default and the shortest
  /// option offered.
  static const defaultSessionTimeout = Duration(seconds: 120);

  /// The choices requirement 23.4 exposes in the security section.
  static const sessionTimeoutOptions = <Duration>[
    Duration(seconds: 120),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  final ThemeMode themeMode;

  /// When true, every monetary figure renders as a fixed mask glyph sequence.
  final bool balancesHidden;

  final String currencyCode;

  /// Remembered user email for quick 6-digit PIN unlock on subsequent sign-ins.
  final String? rememberedEmail;

  /// Idle time in the background after which App_Lock is presented again.
  /// Requirement 5.4 sets the floor at 120 seconds; requirement 23.4 lets the
  /// customer choose.
  final Duration sessionTimeout;

  /// Whether biometric confirmation is preferred over PIN entry when the device
  /// reports an enrolled biometric, per requirement 5.3.
  final bool biometricUnlock;

  CurrencyOption get activeCurrency => supportedCurrencies.firstWhere(
        (c) => c.code == currencyCode,
        orElse: () => supportedCurrencies.first,
      );

  Preferences copyWith({
    ThemeMode? themeMode,
    bool? balancesHidden,
    String? currencyCode,
    Object? rememberedEmail = _absent,
    Duration? sessionTimeout,
    bool? biometricUnlock,
  }) =>
      Preferences(
        themeMode: themeMode ?? this.themeMode,
        balancesHidden: balancesHidden ?? this.balancesHidden,
        currencyCode: currencyCode ?? this.currencyCode,
        rememberedEmail: rememberedEmail == _absent
            ? this.rememberedEmail
            : rememberedEmail as String?,
        sessionTimeout: sessionTimeout ?? this.sessionTimeout,
        biometricUnlock: biometricUnlock ?? this.biometricUnlock,
      );
}

const Object _absent = Object();

/// Reads its first state straight out of Persistence_Store, so an explicit theme
/// choice (requirement 1.14) and the masking preference (requirement 5.6) survive
/// a restart and the first frame is already correct rather than flashing a
/// default and then correcting itself.
class PreferencesController extends Notifier<Preferences> {
  PersistenceStore get _store => ref.read(persistenceStoreProvider);

  @override
  Preferences build() {
    final store = _store;
    final themeName = store.readString(StoreKeys.themeMode);
    final timeoutSeconds = store.readInt(StoreKeys.sessionTimeoutSeconds);
    return Preferences(
      themeMode: ThemeMode.values
              .where((mode) => mode.name == themeName)
              .firstOrNull ??
          ThemeMode.system,
      balancesHidden: store.readBool(StoreKeys.balancesHidden) ?? false,
      currencyCode: store.readString(StoreKeys.currencyCode) ?? 'USD',
      rememberedEmail: store.readString(StoreKeys.rememberedEmail),
      sessionTimeout: timeoutSeconds == null
          ? Preferences.defaultSessionTimeout
          : Duration(seconds: timeoutSeconds),
      biometricUnlock: store.readBool(StoreKeys.biometricUnlock) ?? true,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _store.writeString(StoreKeys.themeMode, mode.name);
  }

  void toggleBalanceVisibility() {
    final hidden = !state.balancesHidden;
    state = state.copyWith(balancesHidden: hidden);
    _store.writeBool(StoreKeys.balancesHidden, hidden);
  }

  void setCurrencyCode(String code) {
    state = state.copyWith(currencyCode: code);
    _store.writeString(StoreKeys.currencyCode, code);
  }

  void setSessionTimeout(Duration timeout) {
    state = state.copyWith(sessionTimeout: timeout);
    _store.writeInt(StoreKeys.sessionTimeoutSeconds, timeout.inSeconds);
  }

  void setBiometricUnlock(bool enabled) {
    state = state.copyWith(biometricUnlock: enabled);
    _store.writeBool(StoreKeys.biometricUnlock, enabled);
  }

  void setRememberedEmail(String? email) {
    state = state.copyWith(rememberedEmail: email);
    if (email == null || email.isEmpty) {
      _store.remove(StoreKeys.rememberedEmail);
    } else {
      _store.writeString(StoreKeys.rememberedEmail, email);
    }
  }

  void clearRememberedEmail() {
    state = state.copyWith(rememberedEmail: null);
    _store.remove(StoreKeys.rememberedEmail);
  }
}
