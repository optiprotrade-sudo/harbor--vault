import '../models/asset.dart';

/// UI-only valuation for the FIRST receiving address of each listed asset.
/// This is not a full account scanner or proof of total wallet holdings.
class PortfolioSummary {
  final double? usd;
  final int counted;
  final int total;
  const PortfolioSummary({required this.usd, required this.counted, required this.total});

  bool get complete => counted == total;

  static PortfolioSummary calculate(
    Map<ChainAsset, String> balances,
    Map<ChainAsset, double> usdPrices,
  ) {
    var counted = 0;
    var value = 0.0;
    for (final asset in ChainAsset.values) {
      final amount = double.tryParse(balances[asset] ?? '');
      final quote = usdPrices[asset];
      if (amount == null || amount < 0 || !amount.isFinite ||
          quote == null || quote <= 0 || !quote.isFinite) {
        continue;
      }
      final subtotal = amount * quote;
      if (!subtotal.isFinite) continue;
      value += subtotal;
      counted += 1;
    }
    return PortfolioSummary(
      usd: counted == 0 || !value.isFinite ? null : value,
      counted: counted,
      total: ChainAsset.values.length,
    );
  }

  static String formatUsd(double? value) {
    if (value == null || !value.isFinite || value < 0) return '\$—';
    // Protect the formatter against impossibly large/malformed provider totals.
    if (value >= 1e18) return '\$${value.toStringAsExponential(2)}';
    final parts = value.toStringAsFixed(2).split('.');
    final digits = parts[0];
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) result.write(',');
      result.write(digits[i]);
    }
    return '\$${result.toString()}.${parts[1]}';
  }
}
