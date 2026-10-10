import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/models/asset.dart';
import 'package:harbor_vault/services/portfolio_summary.dart';

void main() {
  test('Never represent unchecked balances as a confirmed zero total', () {
    final summary = PortfolioSummary.calculate({}, {ChainAsset.btc: 64000});
    expect(summary.usd, isNull);
    expect(summary.counted, 0);
    expect(summary.complete, false);
    expect(PortfolioSummary.formatUsd(summary.usd), '\$—');
  });

  test('Portfolio estimate is marked partial when an asset is missing', () {
    final summary = PortfolioSummary.calculate({
      ChainAsset.btc: '0.01',
      ChainAsset.eth: '1.5',
    }, {
      ChainAsset.btc: 70000,
      ChainAsset.eth: 3000,
      ChainAsset.usdt: 1,
    });
    expect(summary.usd, 5200);
    expect(summary.counted, 2);
    expect(summary.complete, false);
    expect(PortfolioSummary.formatUsd(summary.usd), '\$5,200.00');
  });

  test('Extremely large estimates do not crash USD formatting', () {
    expect(PortfolioSummary.formatUsd(1e24), '\$1.00e+24');
  });

  test('Zero is shown only when each asset returns a real zero balance', () {
    final balances = {for (final a in ChainAsset.values) a: '0'};
    final prices = {for (final a in ChainAsset.values) a: 1.0};
    final summary = PortfolioSummary.calculate(balances, prices);
    expect(summary.usd, 0);
    expect(summary.complete, true);
    expect(PortfolioSummary.formatUsd(summary.usd), '\$0.00');
  });
}
