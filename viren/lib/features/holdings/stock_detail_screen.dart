import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/market/market_data_service.dart';
import '../../core/market/market_status.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final Holding holding;

  const StockDetailScreen({super.key, required this.holding});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen>
    with TickerProviderStateMixin {
  final _marketService = MarketDataService();

  StockQuote? _quote;
  List<OhlcvCandle> _candles = [];
  bool _isLoadingQuote = true;
  bool _isLoadingCandles = true;
  bool _hasError = false;
  String _selectedTimeframe = '1M';
  bool _showCandleChart = false; // false = line, true = candle
  Timer? _refreshTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final List<String> _timeframes = ['1D', '1W', '1M', '1Y', '3Y', '5Y', 'ALL'];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _loadData();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _setupAutoRefresh() {
    final status = MarketStatusHelper.current();
    if (status == MarketStatus.live) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadQuote();
      });
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_loadQuote(), _loadCandles()]);
  }

  Future<void> _loadQuote() async {
    try {
      final quote =
          await _marketService.fetchQuote(widget.holding.instrumentSymbol);
      if (mounted) {
        setState(() {
          _quote = quote;
          _isLoadingQuote = false;
          _hasError = quote == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _loadCandles() async {
    setState(() => _isLoadingCandles = true);
    try {
      final candles = await _marketService.fetchCandles(
          widget.holding.instrumentSymbol, _selectedTimeframe);
      if (mounted) {
        setState(() {
          _candles = candles;
          _isLoadingCandles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCandles = false);
      }
    }
  }

  void _onTimeframeChanged(String tf) {
    if (tf == _selectedTimeframe) return;
    setState(() => _selectedTimeframe = tf);
    _loadCandles();
  }

  @override
  Widget build(BuildContext context) {
    final status = MarketStatusHelper.current();

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.holding.instrumentSymbol),
        actions: [
          _MarketStatusBadge(
            status: status,
            pulseAnimation: _pulseAnimation,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3B — Price Header
            _buildPriceHeader(status),
            const SizedBox(height: 24),

            // 3C — Timeframe Selector
            _buildTimeframeSelector(),
            const SizedBox(height: 16),

            // 3D — Chart Area
            _buildChartArea(),
            const SizedBox(height: 12),

            // Chart toggle
            _buildChartToggle(),
            const SizedBox(height: 32),

            // 3E — Your Position Card
            _buildPositionCard(),
            const SizedBox(height: 16),

            // 3F — Market Data Card
            _buildMarketDataCard(),
            const SizedBox(height: 16),

            // 3G — Your Entry Analysis Card
            _buildEntryAnalysisCard(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ─── 3B: Price Header ──────────────────────────────────────────────────────
  Widget _buildPriceHeader(MarketStatus status) {
    if (_isLoadingQuote) {
      return AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, _) => Opacity(
          opacity: _shimmerAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 180,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.graphiteSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: DesignTokens.graphiteSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError || _quote == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CurrencyFormatter.format(widget.holding.averagePrice,
                showDecimals: true),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Offline — showing avg cost',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ],
      );
    }

    final q = _quote!;
    final isPositive = q.dayChange >= 0;
    final changeColor =
        isPositive ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;
    final changePrefix = isPositive ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CurrencyFormatter.format(q.currentPrice, showDecimals: true),
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '$changePrefix${CurrencyFormatter.format(q.dayChange, showDecimals: true)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${changePrefix}${q.dayChangePercent.toStringAsFixed(2)}%)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: changeColor,
                  ),
            ),
          ],
        ),
        if (status == MarketStatus.closed && _quote != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'As of ${DateFormat('dd MMM, HH:mm').format(q.fetchedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 11,
                  ),
            ),
          ),
      ],
    );
  }

  // ─── 3C: Timeframe Selector ────────────────────────────────────────────────
  Widget _buildTimeframeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _timeframes.map((tf) {
          final isSelected = tf == _selectedTimeframe;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onTimeframeChanged(tf),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DesignTokens.obsidianTeal
                      : DesignTokens.graphiteSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tf,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? Colors.white
                            : DesignTokens.textMediumContrast,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 3D: Chart Area ────────────────────────────────────────────────────────
  Widget _buildChartArea() {
    if (_isLoadingCandles) {
      return SizedBox(
        height: 220,
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, _) => Opacity(
            opacity: _shimmerAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: DesignTokens.graphiteSurface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      );
    }

    if (_hasError && _candles.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Connect to internet for live data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ),
      );
    }

    if (_candles.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Insufficient data for this timeframe',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: _showCandleChart ? _buildCandleChart() : _buildLineChart(),
    );
  }

  Widget _buildLineChart() {
    final spots = _candles.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.close);
    }).toList();

    final minY =
        _candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) * 0.998;
    final maxY =
        _candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) * 1.002;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                DesignTokens.graphiteSurface.withValues(alpha: 0.95),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                if (idx < 0 || idx >= _candles.length) return null;
                final candle = _candles[idx];
                return LineTooltipItem(
                  '${CurrencyFormatter.format(candle.close, showDecimals: true)}\n${DateFormat('dd MMM HH:mm').format(candle.time)}',
                  TextStyle(
                    color: DesignTokens.textHighContrast,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: DesignTokens.obsidianTeal,
                    strokeColor: DesignTokens.graphiteBase,
                    strokeWidth: 2,
                  ),
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: DesignTokens.obsidianTeal,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  DesignTokens.obsidianTeal.withValues(alpha: 0.3),
                  DesignTokens.obsidianTeal.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandleChart() {
    // Use BarChart to simulate candlestick
    final barGroups = _candles.asMap().entries.map((entry) {
      final i = entry.key;
      final c = entry.value;
      final isUp = c.close >= c.open;
      final color =
          isUp ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;

      final bodyTop = isUp ? c.close : c.open;
      final bodyBottom = isUp ? c.open : c.close;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            fromY: bodyBottom,
            toY: bodyTop,
            width: _candles.length > 100 ? 1.5 : (_candles.length > 50 ? 3 : 5),
            color: color,
            borderRadius: BorderRadius.zero,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              fromY: c.low,
              toY: c.high,
              color: color.withValues(alpha: 0.4),
            ),
          ),
        ],
      );
    }).toList();

    final minY =
        _candles.map((c) => c.low).reduce((a, b) => a < b ? a : b) * 0.998;
    final maxY =
        _candles.map((c) => c.high).reduce((a, b) => a > b ? a : b) * 1.002;

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        barGroups: barGroups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                DesignTokens.graphiteSurface.withValues(alpha: 0.95),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= _candles.length) return null;
              final c = _candles[groupIndex];
              return BarTooltipItem(
                'O: ${c.open.toStringAsFixed(2)}\nH: ${c.high.toStringAsFixed(2)}\nL: ${c.low.toStringAsFixed(2)}\nC: ${c.close.toStringAsFixed(2)}',
                TextStyle(
                  color: DesignTokens.textHighContrast,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChartToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildToggleButton('Line', !_showCandleChart, () {
          setState(() => _showCandleChart = false);
        }),
        const SizedBox(width: 2),
        _buildToggleButton('Candle', _showCandleChart, () {
          setState(() => _showCandleChart = true);
        }),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? DesignTokens.graphiteSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? DesignTokens.obsidianTeal.withValues(alpha: 0.4)
                : DesignTokens.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive
                    ? DesignTokens.textHighContrast
                    : DesignTokens.textMediumContrast,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }

  // ─── 3E: Your Position Card ────────────────────────────────────────────────
  Widget _buildPositionCard() {
    return ref.watch(allTradesProvider).when(
          data: (allTrades) {
            final symbolTrades = allTrades
                .where((t) =>
                    t.trade.instrumentSymbol ==
                    widget.holding.instrumentSymbol)
                .toList();

            // Aggregate true cost basis
            double weightedTcb = 0;
            double totalBuyQty = 0;
            double totalChargesAmt = 0;
            for (final tw in symbolTrades) {
              final t = tw.trade;
              if (t.tradeType == db_enums.TradeType.buy) {
                if (t.trueCostBasis != null) {
                  weightedTcb += t.trueCostBasis! * t.quantity;
                  totalBuyQty += t.quantity;
                }
                totalChargesAmt += (t.brokerage ?? 0) +
                    (t.stt ?? 0) +
                    (t.gst ?? 0) +
                    (t.otherLevies ?? 0);
              }
            }

            final avgTcb =
                totalBuyQty > 0 ? weightedTcb / totalBuyQty : widget.holding.averagePrice;
            final totalInvested =
                widget.holding.averagePrice * widget.holding.totalQuantity;

            final currentPrice = _quote?.currentPrice ?? widget.holding.averagePrice;
            final currentValue = currentPrice * widget.holding.totalQuantity;
            final unrealizedPnL = currentValue - totalInvested;
            final unrealizedPnLPercent =
                totalInvested != 0 ? (unrealizedPnL / totalInvested) * 100 : 0.0;

            final isPositive = unrealizedPnL >= 0;
            final pnlColor = isPositive
                ? DesignTokens.obsidianTeal
                : DesignTokens.crimsonWarning;
            final pnlPrefix = isPositive ? '+' : '';

            return _InfoCard(
              title: 'Your Position',
              children: [
                _InfoRow(
                    label: 'Quantity',
                    value:
                        '${widget.holding.totalQuantity.toStringAsFixed(0)} units'),
                _InfoRow(
                    label: 'Avg Cost',
                    value: CurrencyFormatter.format(
                        widget.holding.averagePrice,
                        showDecimals: true)),
                _InfoRow(
                    label: 'True Cost Basis',
                    value:
                        CurrencyFormatter.format(avgTcb, showDecimals: true)),
                _InfoRow(
                    label: 'Total Invested',
                    value: CurrencyFormatter.format(totalInvested,
                        showDecimals: true)),
                _InfoRow(
                    label: 'Current Value',
                    value: CurrencyFormatter.format(currentValue,
                        showDecimals: true)),
                _InfoRow(
                  label: 'Unrealized P&L',
                  value:
                      '$pnlPrefix${CurrencyFormatter.format(unrealizedPnL, showDecimals: true)}',
                  valueColor: pnlColor,
                ),
                _InfoRow(
                  label: 'Return',
                  value:
                      '$pnlPrefix${unrealizedPnLPercent.toStringAsFixed(2)}%',
                  valueColor: pnlColor,
                ),
                if (totalChargesAmt > 0)
                  _InfoRow(
                    label: 'Total Charges',
                    value: CurrencyFormatter.format(totalChargesAmt,
                        showDecimals: true),
                    valueColor: DesignTokens.ashGold,
                  ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  // ─── 3F: Market Data Card ──────────────────────────────────────────────────
  Widget _buildMarketDataCard() {
    if (_quote == null) {
      return _InfoCard(
        title: 'Market Data',
        children: [
          Center(
            child: Text(
              'Market data unavailable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  ),
            ),
          ),
        ],
      );
    }

    final q = _quote!;
    final range52w = q.fiftyTwoWeekHigh - q.fiftyTwoWeekLow;
    final progress52w =
        range52w > 0 ? (q.currentPrice - q.fiftyTwoWeekLow) / range52w : 0.5;

    final volumeFormatter = NumberFormat('#,##,###', 'en_IN');

    return _InfoCard(
      title: 'Market Data',
      children: [
        _InfoRow(
            label: 'Day High',
            value:
                CurrencyFormatter.format(q.dayHigh, showDecimals: true)),
        _InfoRow(
            label: 'Day Low',
            value:
                CurrencyFormatter.format(q.dayLow, showDecimals: true)),
        _InfoRow(
            label: '52W High',
            value: CurrencyFormatter.format(q.fiftyTwoWeekHigh,
                showDecimals: true)),
        _InfoRow(
            label: '52W Low',
            value: CurrencyFormatter.format(q.fiftyTwoWeekLow,
                showDecimals: true)),
        const SizedBox(height: 12),
        // 52-week range bar
        Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress52w.clamp(0.0, 1.0),
                backgroundColor: DesignTokens.graphiteBase,
                color: DesignTokens.obsidianTeal,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyFormatter.format(q.fiftyTwoWeekLow,
                      showDecimals: true),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                        fontSize: 10,
                      ),
                ),
                Text(
                  '↑ Current',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.obsidianTeal,
                        fontSize: 10,
                      ),
                ),
                Text(
                  CurrencyFormatter.format(q.fiftyTwoWeekHigh,
                      showDecimals: true),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignTokens.textMediumContrast,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow(
            label: 'Volume', value: volumeFormatter.format(q.volume)),
        _InfoRow(
            label: 'Avg Volume',
            value: volumeFormatter.format(q.avgVolume)),
      ],
    );
  }

  // ─── 3G: Your Entry Analysis Card ──────────────────────────────────────────
  Widget _buildEntryAnalysisCard() {
    return ref.watch(allTradesProvider).when(
          data: (allTrades) {
            final symbolTrades = allTrades
                .where((t) =>
                    t.trade.instrumentSymbol ==
                        widget.holding.instrumentSymbol &&
                    t.trade.tradeType == db_enums.TradeType.buy)
                .toList()
              ..sort((a, b) =>
                  a.trade.tradeTimestamp.compareTo(b.trade.tradeTimestamp));

            if (symbolTrades.isEmpty) {
              return _InfoCard(
                title: 'Your Entry',
                children: [
                  Center(
                    child: Text(
                      'No buy trades found',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: DesignTokens.textMediumContrast,
                          ),
                    ),
                  ),
                ],
              );
            }

            final firstPurchaseDate = symbolTrades.first.trade.tradeTimestamp;
            final daysHeld =
                DateTime.now().difference(firstPurchaseDate).inDays;
            final bestBuyPrice = symbolTrades
                .map((t) => t.trade.pricePerUnit)
                .reduce((a, b) => a < b ? a : b);

            // True cost basis per share (break-even)
            double weightedTcb = 0;
            double totalBuyQty = 0;
            for (final tw in symbolTrades) {
              final t = tw.trade;
              if (t.trueCostBasis != null) {
                weightedTcb += t.trueCostBasis! * t.quantity;
                totalBuyQty += t.quantity;
              }
            }
            final breakEvenPrice = totalBuyQty > 0
                ? weightedTcb / totalBuyQty
                : widget.holding.averagePrice;

            final currentPrice =
                _quote?.currentPrice ?? widget.holding.averagePrice;
            final toBreakEven = currentPrice - breakEvenPrice;
            final toBreakEvenPercent =
                breakEvenPrice != 0 ? (toBreakEven / breakEvenPrice) * 100 : 0.0;

            final isAboveBreakEven = toBreakEven >= 0;
            final breakEvenColor = isAboveBreakEven
                ? DesignTokens.obsidianTeal
                : DesignTokens.crimsonWarning;
            final breakEvenPrefix = isAboveBreakEven ? '+' : '';

            return _InfoCard(
              title: 'Your Entry',
              children: [
                _InfoRow(
                  label: 'First Purchase',
                  value: DateFormat('dd MMM yyyy').format(firstPurchaseDate),
                ),
                _InfoRow(
                  label: 'Days Held',
                  value: '$daysHeld days',
                ),
                _InfoRow(
                  label: 'Break-even',
                  value: CurrencyFormatter.format(breakEvenPrice,
                      showDecimals: true),
                ),
                _InfoRow(
                  label: 'To Break-even',
                  value:
                      '$breakEvenPrefix${CurrencyFormatter.format(toBreakEven, showDecimals: true)} ($breakEvenPrefix${toBreakEvenPercent.toStringAsFixed(2)}%)',
                  valueColor: breakEvenColor,
                ),
                _InfoRow(
                  label: 'Best Buy Price',
                  value: CurrencyFormatter.format(bestBuyPrice,
                      showDecimals: true),
                ),
                _InfoRow(
                  label: 'Avg Buy Price',
                  value: CurrencyFormatter.format(
                      widget.holding.averagePrice,
                      showDecimals: true),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}

// ─── Market Status Badge ────────────────────────────────────────────────────
class _MarketStatusBadge extends StatelessWidget {
  final MarketStatus status;
  final Animation<double> pulseAnimation;

  const _MarketStatusBadge({
    required this.status,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final color = MarketStatusHelper.color(status);
    final label = MarketStatusHelper.label(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == MarketStatus.live)
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) => Opacity(
                opacity: pulseAnimation.value,
                child: child,
              ),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Card Container ────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ─── Info Row ───────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? DesignTokens.textHighContrast,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
