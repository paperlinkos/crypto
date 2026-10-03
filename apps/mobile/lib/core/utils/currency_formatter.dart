import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _ngnFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
  static final _ghsFormat = NumberFormat.currency(locale: 'en_GH', symbol: '₵', decimalDigits: 2);
  static final _numFormat = NumberFormat('#,##0.00', 'en_US');

  /// Formats fiat minor units (kobo / pesewas) to formatted string e.g. ₦150,000.00
  static String formatFiatMinor(dynamic minorAmount, {String currency = 'NGN'}) {
    if (minorAmount == null) return currency == 'NGN' ? '₦0.00' : '₵0.00';

    final BigInt minor = minorAmount is BigInt
        ? minorAmount
        : BigInt.tryParse(minorAmount.toString()) ?? BigInt.zero;

    final double major = minor.toDouble() / 100.0;
    if (currency.toUpperCase() == 'GHS') {
      return _ghsFormat.format(major);
    }
    return _ngnFormat.format(major);
  }

  /// Formats fiat major decimal number
  static String formatFiat(double amount, {String currency = 'NGN'}) {
    if (currency.toUpperCase() == 'GHS') {
      return _ghsFormat.format(amount);
    }
    return _ngnFormat.format(amount);
  }

  /// Formats crypto minor units (micro-USDT / satoshis) to standard decimal
  static String formatCryptoMinor(dynamic minorAmount, String asset) {
    if (minorAmount == null) return '0.00';
    final BigInt minor = minorAmount is BigInt
        ? minorAmount
        : BigInt.tryParse(minorAmount.toString()) ?? BigInt.zero;

    if (asset.toUpperCase() == 'BTC') {
      // 1 BTC = 100,000,000 satoshis
      final double btc = minor.toDouble() / 100000000.0;
      return NumberFormat('#,##0.00000000', 'en_US').format(btc);
    } else {
      // USDT / USDC = 1,000,000 micro-units
      final double usd = minor.toDouble() / 1000000.0;
      return _numFormat.format(usd);
    }
  }

  /// Formats exchange rates (e.g. ₦1,521.82 / USDT)
  static String formatRate(dynamic rate, {String fiat = 'NGN', String asset = 'USDT'}) {
    final double r = double.tryParse(rate.toString()) ?? 0.0;
    final symbol = fiat == 'GHS' ? '₵' : '₦';
    return '$symbol${_numFormat.format(r)} / $asset';
  }
}
