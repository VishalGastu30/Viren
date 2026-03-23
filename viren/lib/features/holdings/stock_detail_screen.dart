import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/market/live_price_cache.dart';
import '../../core/market/market_data_service.dart';
import '../../core/market/market_status.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/insights/emotion_recall_service.dart';
import '../../core/market/symbol_classifier.dart';
import 'dart:convert';
import 'widgets/price_alert_sheet.dart';
import 'widgets/trade_note_dialog.dart';

// ─── XIRR Calculator ──────────────────────────────────────────────────────────
class _XirrCalc {
  static double? calculate(
      List<({double amount, DateTime date})> cashflows) {
    if (cashflows.length < 2) return null;
    try {
      double rate = 0.1;
      const maxIter = 100;
      const tol = 1e-6;
      final t0 = cashflows.first.date;
      for (int i = 0; i < maxIter; i++) {
        double f = 0;
        double df = 0;
        for (final cf in cashflows) {
          final t = cf.date.difference(t0).inDays / 365.0;
          final pow = math.pow(1 + rate, t);
          f += cf.amount / pow;
          df += -t * cf.amount / (pow * (1 + rate));
        }
        if (df.abs() < tol) break;
        final newRate = rate - f / df;
        if ((newRate - rate).abs() < tol) return newRate * 100;
        rate = newRate;
        if (rate <= -1) return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ─── Candlestick Painter ──────────────────────────────────────────────────────
// Uses dart:ui TextDirection (imported as ui) — avoids flutter/material conflict.
class _CandlePainter extends CustomPainter {
  final List<OhlcvCandle> candles;
  final double minY;
  final double maxY;
  final int? touchedIndex;
  final double? avgCostLine;
  final String timeframe;

  _CandlePainter({
    required this.candles,
    required this.minY,
    required this.maxY,
    this.touchedIndex,
    this.avgCostLine,
    required this.timeframe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) { return; }
    final priceRange = maxY - minY;
    if (priceRange <= 0) { return; }

    const bottomPad = 28.0;
    final chartH = size.height - bottomPad;

    double priceToY(double price) =>
        chartH - ((price - minY) / priceRange) * chartH;

    final candleWidth =
        (size.width / candles.length).clamp(2.0, 14.0);
    final bodyWidth = (candleWidth * 0.6).clamp(1.5, 10.0);

    final bullPaint = Paint()
      ..color = DesignTokens.obsidianTeal
      ..style = PaintingStyle.fill;
    final bearPaint = Paint()
      ..color = DesignTokens.crimsonWarning
      ..style = PaintingStyle.fill;
    final wickPaint = Paint()..strokeWidth = 1;
    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final cx = (i + 0.5) * (size.width / candles.length);
      final isUp = c.close >= c.open;
      final color = isUp
          ? DesignTokens.obsidianTeal
          : DesignTokens.crimsonWarning;

      final bodyTop = priceToY(math.max(c.open, c.close));
      final bodyBottom = priceToY(math.min(c.open, c.close));

      wickPaint.color = color.withValues(alpha: 0.8);
      canvas.drawLine(
          Offset(cx, priceToY(c.high)),
          Offset(cx, priceToY(c.low)),
          wickPaint);

      final bodyH = math.max(bodyBottom - bodyTop, 2.0);
      canvas.drawRect(
        Rect.fromLTWH(cx - bodyWidth / 2, bodyTop, bodyWidth, bodyH),
        isUp ? bullPaint : bearPaint,
      );
    }

    // Avg cost dashed line
    if (avgCostLine != null &&
        avgCostLine! >= minY &&
        avgCostLine! <= maxY) {
      final y = priceToY(avgCostLine!);
      final p = Paint()
        ..color = DesignTokens.ashGold.withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      _dash(canvas, Offset(0, y), Offset(size.width, y), p,
          [6, 4]);
      final tp = TextPainter(
        text: TextSpan(
          text: ' avg ₹${avgCostLine!.toStringAsFixed(0)} ',
          style: TextStyle(
            color: DesignTokens.ashGold,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y - tp.height - 2));
    }

    // Crosshair
    if (touchedIndex != null &&
        touchedIndex! >= 0 &&
        touchedIndex! < candles.length) {
      final cx =
          (touchedIndex! + 0.5) * (size.width / candles.length);
      final closeY = priceToY(candles[touchedIndex!].close);
      _dash(canvas, Offset(cx, 0), Offset(cx, chartH),
          crosshairPaint, [4, 4]);
      _dash(canvas, Offset(0, closeY),
          Offset(size.width, closeY), crosshairPaint, [4, 4]);
      canvas.drawCircle(
          Offset(cx, closeY), 4, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx, closeY), 2.5,
          Paint()..color = DesignTokens.obsidianTeal);
    }

    // X-axis labels
    final labelIndices =
        MarketDataService.xAxisLabelIndices(candles.length);
    for (final idx in labelIndices) {
      if (idx >= candles.length) { continue; }
      final label = MarketDataService.formatCandleDate(
          candles[idx].time, timeframe);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: DesignTokens.textMediumContrast
                .withValues(alpha: 0.5),
            fontSize: 9,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 60);
      final cx = (idx + 0.5) * (size.width / candles.length);
      final x =
          (cx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartH + 6));
    }
  }

  void _dash(Canvas canvas, Offset start, Offset end, Paint p,
      List<double> pat) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) { return; }
    final ux = dx / len;
    final uy = dy / len;
    double dist = 0;
    int di = 0;
    bool draw = true;
    while (dist < len) {
      final d = pat[di % pat.length];
      final next = math.min(dist + d, len);
      if (draw) {
        canvas.drawLine(
          Offset(start.dx + ux * dist, start.dy + uy * dist),
          Offset(start.dx + ux * next, start.dy + uy * next),
          p,
        );
      }
      dist = next;
      di++;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.candles != candles ||
      old.touchedIndex != touchedIndex ||
      old.avgCostLine != avgCostLine ||
      old.timeframe != timeframe;
}

// ─── Volume Painter ───────────────────────────────────────────────────────────
// Semi-transparent bars at bottom 20% of chart. Teal = up, red = down.
class _VolumePainter extends CustomPainter {
  final List<OhlcvCandle> candles;
  final int? touchedIndex;

  const _VolumePainter({required this.candles, this.touchedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) { return; }
    final maxVol =
        candles.map((c) => c.volume).reduce(math.max).toDouble();
    if (maxVol <= 0) { return; }

    final maxBarH = size.height * 0.20;
    final barW = (size.width / candles.length).clamp(1.0, 14.0);

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      if (c.volume <= 0) { continue; }
      final isUp = c.close >= c.open;
      final isTouched = i == touchedIndex;
      final color = isUp
          ? DesignTokens.obsidianTeal
          : DesignTokens.crimsonWarning;
      final barH = (c.volume / maxVol) * maxBarH;
      final cx = (i + 0.5) * (size.width / candles.length);
      canvas.drawRect(
        Rect.fromLTWH(
            cx - barW * 0.4, size.height - barH, barW * 0.8, barH),
        Paint()
          ..color =
              color.withValues(alpha: isTouched ? 0.55 : 0.22)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_VolumePainter old) =>
      old.candles != candles || old.touchedIndex != touchedIndex;
}

// ─── StockDetailScreen ────────────────────────────────────────────────────────
class StockDetailScreen extends ConsumerStatefulWidget {
  final Holding holding;
  const StockDetailScreen({super.key, required this.holding});

  @override
  ConsumerState<StockDetailScreen> createState() =>
      _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen>
    with TickerProviderStateMixin {
  final _marketService = MarketDataService();

  StockQuote? _quote;
  List<OhlcvCandle> _candles = [];
  bool _isLoadingQuote = true;
  bool _isLoadingCandles = true;
  bool _hasQuoteError = false;
  String _selectedTimeframe = '1M';
  bool _showCandleChart = false;

  int? _touchedCandleIndex;
  OhlcvCandle? _touchedCandle;
  int? _lastHapticIndex;

  // Maps tradeId → note text for the Investment Journey note icons.
  // Loaded once on initState and updated when user saves/deletes a note.
  final Map<String, String> _tradeNotes = {};

  Timer? _refreshTimer;
  Timer? _liveRefreshTimer;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final _calcAmountController =
      TextEditingController(text: '10000');
  DateTime _calcDate =
      DateTime.now().subtract(const Duration(days: 365));
  double? _calcResult;

  // True while fetching ALL-timeframe candles for historical calculator
  bool _isFetchingHistoricalCandles = false;
  // All-timeframe candles for historical date calculation
  List<OhlcvCandle> _historicalCandles = [];

  final List<String> _timeframes = [
    '1D', '1W', '1M', '1Y', '3Y', '5Y', 'ALL'
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _shimmerAnimation =
        Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(
          parent: _shimmerController, curve: Curves.easeInOut),
    );
    _loadData();
    _setupAutoRefresh();
    _loadTradeNotes();

    // Register this symbol with the live price cache
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(livePriceCacheProvider.notifier)
            .registerSymbols([widget.holding.instrumentSymbol]);
        _startLiveRefresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _liveRefreshTimer?.cancel();
    _shimmerController.dispose();
    _calcAmountController.dispose();
    super.dispose();
  }

  void _startLiveRefresh() {
    if (!MarketStatusHelper.isMarketOpen()) return;
    _liveRefreshTimer?.cancel();
    // 5-second refresh while this screen is visible and market is open
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (!MarketStatusHelper.isMarketOpen()) {
        _liveRefreshTimer?.cancel();
        return;
      }
      ref.read(livePriceCacheProvider.notifier)
          .fetchSymbol(widget.holding.instrumentSymbol);
    });
  }

  void _setupAutoRefresh() {
    if (MarketStatusHelper.current() == MarketStatus.live) {
      _refreshTimer =
          Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) _loadQuote();
      });
    }
  }

  Future<void> _loadTradeNotes() async {
    final db = ref.read(appDatabaseProvider);
    final service = EmotionRecallService(db);
    final notes = await service.getNotesForSymbol(
        widget.holding.instrumentSymbol.toUpperCase());

    final map = <String, String>{};
    for (final note in notes) {
      try {
        final data =
            jsonDecode(note.triggerData) as Map<String, dynamic>;
        final tradeId = data['tradeId'] as String?;
        if (tradeId != null) {
          map[tradeId] = note.description;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _tradeNotes.addAll(map));
  }

  Future<void> _loadData() =>
      Future.wait([_loadQuote(), _loadCandles()]);

  Future<void> _loadQuote() async {
    try {
      final quote = await _marketService
          .fetchQuote(widget.holding.instrumentSymbol);
      if (mounted) {
        setState(() {
          _quote = quote;
          _isLoadingQuote = false;
          _hasQuoteError = quote == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
          _hasQuoteError = true;
        });
      }
    }
  }

  Future<void> _loadCandles() async {
    if (mounted) setState(() => _isLoadingCandles = true);
    try {
      final candles = await _marketService.fetchCandles(
          widget.holding.instrumentSymbol, _selectedTimeframe);
      if (mounted) {
        // Clamp the calculator date to the available candle range
        // so the calculator works immediately without the user picking a date
        if (candles.isNotEmpty) {
          final firstCandleDate = candles.first.time;
          final lastCandleDate = candles.last.time;

          setState(() {
            _candles = candles;
            _isLoadingCandles = false;
            _touchedCandleIndex = null;
            _touchedCandle = null;
            
            // Clamp: if current _calcDate is before first candle, move it to first candle
            // If after last candle, move to last candle
            if (_calcDate.isBefore(firstCandleDate)) {
              _calcDate = firstCandleDate;
            } else if (_calcDate.isAfter(lastCandleDate)) {
              _calcDate = lastCandleDate;
            }
          });
          _computeCalcResult();
        } else {
          setState(() {
            _candles = candles;
            _isLoadingCandles = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCandles = false);
    }
  }

  void _onTimeframeChanged(String tf) {
    if (tf == _selectedTimeframe) { return; }
    if (mounted) {
      setState(() => _selectedTimeframe = tf);
    }
    _loadCandles();
  }

  /// Computes the calculator result for a given date.
  /// If the date is within the current candle range, uses loaded candles.
  /// If the date is outside (historical), fetches ALL timeframe candles.
  Future<void> _computeCalcResultForDate(DateTime date) async {
    final amount = double.tryParse(_calcAmountController.text);
    if (amount == null || amount <= 0) {
      if (mounted) setState(() => _calcResult = null);
      return;
    }

    // Check if current candles cover this date
    final candlesCoverDate = _candles.isNotEmpty &&
        !date.isBefore(_candles.first.time) &&
        !date.isAfter(_candles.last.time);

    if (candlesCoverDate) {
      // Use current candles directly
      _computeCalcResult();
      return;
    }

    // Need to fetch ALL timeframe candles for historical calculation
    if (mounted) {
      setState(() {
        _isFetchingHistoricalCandles = true;
        _calcResult = null;
      });
    }

    try {
      // Use cached historical candles if available, otherwise fetch
      List<OhlcvCandle> candles = _historicalCandles;
      if (candles.isEmpty) {
        candles = await _marketService.fetchCandles(
            widget.holding.instrumentSymbol, 'ALL');
        if (mounted) setState(() => _historicalCandles = candles);
      }

      if (candles.isEmpty) {
        if (mounted) {
          setState(() {
            _isFetchingHistoricalCandles = false;
            _calcResult = null;
          });
        }
        return;
      }

      // Find closest candle to the selected date
      OhlcvCandle? target;
      Duration minDiff = const Duration(days: 999999);
      for (final c in candles) {
        final diff = c.time.difference(date).abs();
        if (diff < minDiff) {
          minDiff = diff;
          target = c;
        }
      }

      if (target == null || target.close <= 0) {
        if (mounted) {
          setState(() {
            _isFetchingHistoricalCandles = false;
            _calcResult = null;
          });
        }
        return;
      }

      final currentPrice =
          _quote?.currentPrice ?? _candles.last.close;
      if (mounted) {
        setState(() {
          _calcResult = (amount / target!.close) * currentPrice;
          _isFetchingHistoricalCandles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFetchingHistoricalCandles = false;
          _calcResult = null;
        });
      }
    }
  }

  void _computeCalcResult() {
    if (_candles.isEmpty) {
      if (mounted) {
        setState(() => _calcResult = null);
      }
      return;
    }
    final amount =
        double.tryParse(_calcAmountController.text);
    if (amount == null || amount <= 0) {
      if (mounted) {
        setState(() => _calcResult = null);
      }
      return;
    }
    OhlcvCandle? target;
    Duration minDiff =
        const Duration(days: 999999);
    for (final c in _candles) {
      final diff = c.time.difference(_calcDate).abs();
      if (diff < minDiff) {
        minDiff = diff;
        target = c;
      }
    }
    
    // If no target found in current candles, check historical candles
    if (target == null && _historicalCandles.isNotEmpty) {
      for (final c in _historicalCandles) {
        final diff = c.time.difference(_calcDate).abs();
        if (diff < minDiff) {
          minDiff = diff;
          target = c;
        }
      }
    }

    if (target == null || target.close <= 0) {
      if (mounted) {
        setState(() => _calcResult = null);
      }
      return;
    }
    final currentPrice =
        _quote?.currentPrice ?? _candles.last.close;
    if (mounted) {
      setState(
          () => _calcResult = (amount / target!.close) * currentPrice);
    }
  }

  double? _computeXirr(List trades) {
    if (trades.isEmpty) return null;
    final cashflows = <({double amount, DateTime date})>[];
    for (final tw in trades) {
      final t = tw.trade;
      if (t.tradeType == db_enums.TradeType.buy) {
        cashflows.add((
          amount: -(t.pricePerUnit * t.quantity),
          date: t.tradeTimestamp,
        ));
      } else {
        cashflows.add((
          amount: t.pricePerUnit * t.quantity,
          date: t.tradeTimestamp,
        ));
      }
    }
    final currentPrice =
        _quote?.currentPrice ?? widget.holding.averagePrice;
    cashflows.add((
      amount: currentPrice * widget.holding.totalQuantity,
      date: DateTime.now(),
    ));
    return _XirrCalc.calculate(cashflows);
  }

  String _formatVolume(int vol) {
    if (vol >= 10000000) {
      return '${(vol / 10000000).toStringAsFixed(1)}Cr';
    }
    if (vol >= 100000) {
      return '${(vol / 100000).toStringAsFixed(1)}L';
    }
    if (vol >= 1000) { return '${(vol / 1000).toStringAsFixed(1)}K'; }
    return vol.toString();
  }

  Widget _shimmerBox(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(8),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Listen for live price updates from the cache
    ref.listen<LivePriceState>(livePriceCacheProvider, (_, state) {
      final symbol = widget.holding.instrumentSymbol.toUpperCase();
      final liveQuote = state.quoteFor(symbol);
      if (liveQuote != null && mounted) {
        setState(() {
          _quote = liveQuote;
          _hasQuoteError = false;
          _isLoadingQuote = false;
        });
        _computeCalcResult();
      }
    });

    final status = MarketStatusHelper.current();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: DesignTokens.graphiteBase,
        appBar: AppBar(
          backgroundColor: DesignTokens.graphiteBase,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.holding.instrumentSymbol,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Position'),
              Tab(text: 'Fundamentals'),
              Tab(text: 'Returns'),
              Tab(text: 'Intelligence'),
            ],
          ),
        actions: [
          // Live update timestamp
          Consumer(
            builder: (context, ref, _) {
              final cacheState = ref.watch(livePriceCacheProvider);
              if (!MarketStatusHelper.isMarketOpen()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    cacheState.lastUpdatedLabel,
                    style: TextStyle(
                      color: DesignTokens.textMediumContrast.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: DesignTokens.textMediumContrast),
            tooltip: 'Set price alert',
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => PriceAlertSheet(
                holding: widget.holding,
                currentPrice: _quote?.currentPrice,
              ),
            ),
          ),
          const _MarketStatusBadge(),
          const SizedBox(width: 12),
        ],
      ),
      body: TabBarView(
        children: [
          // Overview
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPriceHeader(status),
                const SizedBox(height: 20),
                _buildDayRangeBar(),
                const SizedBox(height: 20),
                _buildTimeframeSelector(),
                const SizedBox(height: 12),
                _buildChartArea(),
                const SizedBox(height: 8),
                _buildChartToggle(),
                const SizedBox(height: 28),
                _buildSymbolInfoCard(),
                const SizedBox(height: 48),
              ],
            ),
          ),
          // Position
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildPositionCard(),
                const SizedBox(height: 14),
                _buildBrokerageBreakdownCard(),
                const SizedBox(height: 14),
                _buildEntryAnalysisCard(),
                const SizedBox(height: 48),
              ],
            ),
          ),
          // Fundamentals
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildFundamentalsCard(),
                const SizedBox(height: 14),
                _buildMarketDataCard(),
                const SizedBox(height: 48),
              ],
            ),
          ),
          // Returns
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildReturnsCalculator(),
                const SizedBox(height: 14),
                _buildTaxCalculatorCard(),
                const SizedBox(height: 48),
              ],
            ),
          ),
          // Intelligence
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildInvestmentJourney(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ─── Price Header ──────────────────────────────────────────────────────────
  Widget _buildPriceHeader(MarketStatus status) {
    if (_isLoadingQuote) {
      return AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (_, __) => Opacity(
          opacity: _shimmerAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(200, 44),
              const SizedBox(height: 8),
              _shimmerBox(140, 22),
            ],
          ),
        ),
      );
    }

    if (_hasQuoteError || _quote == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CurrencyFormatter.format(
                widget.holding.averagePrice,
                showDecimals: true),
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 4),
          Text('Offline — showing avg cost',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  )),
        ],
      );
    }

    final q = _quote!;
    final isPos = q.dayChange >= 0;
    final changeColor = isPos
        ? DesignTokens.obsidianTeal
        : DesignTokens.crimsonWarning;
    final sign = isPos ? '+' : '';
    final displayPrice =
        _touchedCandle?.close ?? q.currentPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            CurrencyFormatter.format(displayPrice,
                showDecimals: true),
            key: ValueKey(
                displayPrice.toStringAsFixed(2)),
            style:
                Theme.of(context).textTheme.displayMedium,
          ),
        ),
        const SizedBox(height: 4),
        if (_touchedCandle != null)
          Text(
            MarketDataService.formatCandleDate(
                _touchedCandle!.time, _selectedTimeframe),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: DesignTokens.textMediumContrast,
                  fontStyle: FontStyle.italic,
                ),
          )
        else
          Row(
            children: [
              Text(
                '$sign${CurrencyFormatter.format(q.dayChange, showDecimals: true)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '($sign${q.dayChangePercent.toStringAsFixed(2)}%)',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: changeColor),
              ),
              if (status == MarketStatus.closed) ...[
                const SizedBox(width: 10),
                Text(
                  'as of ${DateFormat('dd MMM, HH:mm').format(q.fetchedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: DesignTokens.textMediumContrast,
                        fontSize: 10,
                      ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  // ─── Day Range Thermometer ─────────────────────────────────────────────────
  Widget _buildDayRangeBar() {
    if (_quote == null) { return const SizedBox.shrink(); }
    final q = _quote!;
    if (q.dayHigh <= q.dayLow) { return const SizedBox.shrink(); }

    final range = q.dayHigh - q.dayLow;
    final progress =
        ((q.currentPrice - q.dayLow) / range).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Day Range',
                  style: TextStyle(
                      color: DesignTokens.textMediumContrast,
                      fontSize: 10,
                      letterSpacing: 0.5)),
              Text(
                '${CurrencyFormatter.format(q.dayLow, showDecimals: true)}  —  ${CurrencyFormatter.format(q.dayHigh, showDecimals: true)}',
                style: TextStyle(
                    color: DesignTokens.textHighContrast,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: DesignTokens.crimsonWarning
                      .withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      DesignTokens.obsidianTeal
                          .withValues(alpha: 0.6)),
                  minHeight: 5,
                ),
              ),
              Positioned(
                left: (MediaQuery.of(context).size.width -
                            72) *
                        progress -
                    5,
                top: -3,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: DesignTokens.obsidianTeal,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: DesignTokens.graphiteBase,
                        width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Timeframe Selector ────────────────────────────────────────────────────
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
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DesignTokens.obsidianTeal
                      : DesignTokens.graphiteSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(tf,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: isSelected
                              ? Colors.white
                              : DesignTokens.textMediumContrast,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Chart Area ────────────────────────────────────────────────────────────
  Widget _buildChartArea() {
    if (_isLoadingCandles) {
      return SizedBox(
        height: 280,
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (_, __) => Opacity(
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

    if (_candles.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Text(
            _hasQuoteError
                ? 'Connect to internet for chart data'
                : 'No data for this timeframe',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  color: DesignTokens.textMediumContrast,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: _showCandleChart
          ? _buildCandleChart()
          : _buildLineChart(),
    );
  }

  // ─── Line Chart ────────────────────────────────────────────────────────────
  Widget _buildLineChart() {
    final spots = _candles
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();

    final minY =
        _candles.map((c) => c.low).reduce(math.min) * 0.998;
    final maxY =
        _candles.map((c) => c.high).reduce(math.max) * 1.002;
    final avgCost = widget.holding.averagePrice;
    final showAvgLine = avgCost >= minY && avgCost <= maxY;

    return Stack(
      children: [
        // Volume bars behind price line
        Positioned.fill(
          child: CustomPaint(
            painter: _VolumePainter(candles: _candles),
          ),
        ),

        LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    final labelIndices =
                        MarketDataService.xAxisLabelIndices(
                            _candles.length);
                    if (!labelIndices.contains(idx) ||
                        idx >= _candles.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        MarketDataService.formatCandleDate(
                            _candles[idx].time,
                            _selectedTimeframe),
                        style: TextStyle(
                          color: DesignTokens.textMediumContrast
                              .withValues(alpha: 0.5),
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: minY,
            maxY: maxY,
            extraLinesData: showAvgLine
                ? ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: avgCost,
                      color: DesignTokens.ashGold
                          .withValues(alpha: 0.7),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.only(
                            left: 4, bottom: 2),
                        style: TextStyle(
                          color: DesignTokens.ashGold,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        labelResolver: (_) =>
                            'avg ₹${avgCost.toStringAsFixed(0)}',
                      ),
                    ),
                  ])
                : null,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) =>
                    DesignTokens.graphiteSurface
                        .withValues(alpha: 0.95),
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.x.toInt();
                    if (idx < 0 || idx >= _candles.length) {
                      return null;
                    }
                    final c = _candles[idx];
                    return LineTooltipItem(
                      '${CurrencyFormatter.format(c.close, showDecimals: true)}\n',
                      TextStyle(
                        color: DesignTokens.textHighContrast,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(
                          text: MarketDataService
                              .formatCandleDate(
                                  c.time, _selectedTimeframe),
                          style: TextStyle(
                            color:
                                DesignTokens.textMediumContrast,
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        if (c.volume > 0)
                          TextSpan(
                            text:
                                '\nVol: ${_formatVolume(c.volume)}',
                            style: TextStyle(
                              color: DesignTokens
                                  .textMediumContrast
                                  .withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                      ],
                    );
                  }).toList();
                },
              ),
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: DesignTokens.obsidianTeal
                          .withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    FlDotData(
                      getDotPainter:
                          (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                        radius: 4,
                        color: DesignTokens.obsidianTeal,
                        strokeColor:
                            DesignTokens.graphiteBase,
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
                      DesignTokens.obsidianTeal
                          .withValues(alpha: 0.25),
                      DesignTokens.obsidianTeal
                          .withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Candle Chart ──────────────────────────────────────────────────────────
  Widget _buildCandleChart() {
    if (_candles.isEmpty) return const SizedBox.shrink();

    final minY =
        _candles.map((c) => c.low).reduce(math.min) * 0.998;
    final maxY =
        _candles.map((c) => c.high).reduce(math.max) * 1.002;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final chartWidth = box.size.width - 40;
        final idx = ((details.localPosition.dx / chartWidth) *
                _candles.length)
            .floor()
            .clamp(0, _candles.length - 1);
        
        if (idx != _lastHapticIndex) {
          HapticFeedback.selectionClick();
          _lastHapticIndex = idx;
        }

        if (mounted) {
          setState(() {
            _touchedCandleIndex = idx;
            _touchedCandle = _candles[idx];
          });
        }
      },
      onHorizontalDragEnd: (_) {
        _lastHapticIndex = null;
        if (mounted) {
          setState(() {
            _touchedCandleIndex = null;
            _touchedCandle = null;
          });
        }
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final chartWidth = box.size.width - 40;
        final idx = ((details.localPosition.dx / chartWidth) *
                _candles.length)
            .floor()
            .clamp(0, _candles.length - 1);
        if (mounted) {
          setState(() {
            _touchedCandleIndex = idx;
            _touchedCandle = _candles[idx];
          });
        }
      },
      onTapUp: (_) => Future.delayed(
        const Duration(milliseconds: 800),
        () {
          if (mounted) {
            setState(() {
              _touchedCandleIndex = null;
              _touchedCandle = null;
            });
          }
        },
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _touchedCandle != null
                ? _buildOhlcTooltip(_touchedCandle!)
                : const SizedBox(height: 32),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Stack(
              children: [
                CustomPaint(
                  painter: _VolumePainter(
                    candles: _candles,
                    touchedIndex: _touchedCandleIndex,
                  ),
                  child: const SizedBox.expand(),
                ),
                CustomPaint(
                  painter: _CandlePainter(
                    candles: _candles,
                    minY: minY,
                    maxY: maxY,
                    touchedIndex: _touchedCandleIndex,
                    avgCostLine: widget.holding.averagePrice,
                    timeframe: _selectedTimeframe,
                  ),
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOhlcTooltip(OhlcvCandle c) {
    return Container(
      key: const ValueKey('ohlc'),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: DesignTokens.obsidianTeal
                .withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ohlcItem('O',
              CurrencyFormatter.format(c.open,
                  showDecimals: true)),
          _ohlcItem(
              'H',
              CurrencyFormatter.format(c.high,
                  showDecimals: true),
              color: DesignTokens.obsidianTeal),
          _ohlcItem(
              'L',
              CurrencyFormatter.format(c.low,
                  showDecimals: true),
              color: DesignTokens.crimsonWarning),
          _ohlcItem('C',
              CurrencyFormatter.format(c.close,
                  showDecimals: true)),
          _ohlcItem(
            MarketDataService.formatCandleDate(
                c.time, _selectedTimeframe),
            '',
            isDate: true,
          ),
        ],
      ),
    );
  }

  Widget _ohlcItem(String label, String value,
      {Color? color, bool isDate = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
              color: isDate
                  ? DesignTokens.textMediumContrast
                  : (color ?? DesignTokens.textMediumContrast),
              fontSize: isDate ? 10 : 9,
              fontWeight: isDate
                  ? FontWeight.w500
                  : FontWeight.normal,
              letterSpacing: 0.3,
            )),
        if (!isDate) ...[
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                color: color ?? DesignTokens.textHighContrast,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ],
      ],
    );
  }

  // ─── Chart Toggle ──────────────────────────────────────────────────────────
  Widget _buildChartToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _toggleBtn('Line', !_showCandleChart,
            () { if (mounted) setState(() => _showCandleChart = false); }),
        const SizedBox(width: 4),
        _toggleBtn('Candle', _showCandleChart,
            () { if (mounted) setState(() => _showCandleChart = true); }),
      ],
    );
  }

  Widget _toggleBtn(
      String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? DesignTokens.graphiteSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? DesignTokens.obsidianTeal
                    .withValues(alpha: 0.4)
                : DesignTokens.graphiteSurface,
          ),
        ),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: isActive
                      ? DesignTokens.textHighContrast
                      : DesignTokens.textMediumContrast,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.normal,
                )),
      ),
    );
  }

  // ─── Brokerage Breakdown ───────────────────────────────────────────────────
  Widget _chargeItem(String label, num value) {
    if (value <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: DesignTokens.textMediumContrast, fontSize: 13)),
        Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(color: DesignTokens.textHighContrast, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBrokerageBreakdownCard() {
    return ref.watch(allTradesProvider).when(
      data: (allTrades) {
        final symbolTrades = allTrades.where((t) => t.trade.instrumentSymbol == widget.holding.instrumentSymbol).toList();
        
        double brk = 0;
        double stt = 0;
        double gst = 0;
        double oth = 0;
        
        for (final tw in symbolTrades) {
          final t = tw.trade;
          if (t.tradeType == db_enums.TradeType.buy) {
            brk += (t.brokerage ?? 0);
            stt += (t.stt ?? 0);
            gst += (t.gst ?? 0);
            oth += (t.otherLevies ?? 0);
          }
        }
        
        final num totalCharges = brk + stt + gst + oth;
        if (totalCharges <= 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DesignTokens.graphiteSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: DesignTokens.obsidianTeal, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Taxes & Charges',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        )),
                  ),
                  Text(
                    '₹${totalCharges.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textHighContrast,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _chargeItem('Brokerage', brk),
              const SizedBox(height: 12),
              _chargeItem('STT', stt),
              const SizedBox(height: 12),
              _chargeItem('GST (18%)', gst),
              const SizedBox(height: 12),
              _chargeItem('Other Levies', oth),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ─── Position Card ─────────────────────────────────────────────────────────
  Widget _buildPositionCard() {
    return ref.watch(allTradesProvider).when(
          data: (allTrades) {
            final symbolTrades = allTrades
                .where((t) =>
                    t.trade.instrumentSymbol ==
                    widget.holding.instrumentSymbol)
                .toList();

            double weightedTcb = 0;
            double totalBuyQty = 0;
            double totalCharges = 0;
            for (final tw in symbolTrades) {
              final t = tw.trade;
              if (t.tradeType == db_enums.TradeType.buy) {
                if (t.trueCostBasis != null) {
                  weightedTcb +=
                      t.trueCostBasis! * t.quantity;
                  totalBuyQty += t.quantity;
                }
                totalCharges += (t.brokerage ?? 0) +
                    (t.stt ?? 0) +
                    (t.gst ?? 0) +
                    (t.otherLevies ?? 0);
              }
            }

            final avgTcb = totalBuyQty > 0
                ? weightedTcb / totalBuyQty
                : widget.holding.averagePrice;
            final totalInvested = widget.holding.averagePrice *
                widget.holding.totalQuantity;
            final currentPrice = _quote?.currentPrice ??
                widget.holding.averagePrice;
            final currentValue =
                currentPrice * widget.holding.totalQuantity;
            final pnl = currentValue - totalInvested;
            final pnlPct = totalInvested != 0
                ? (pnl / totalInvested) * 100
                : 0.0;
            final isPos = pnl >= 0;
            final pnlColor = isPos
                ? DesignTokens.obsidianTeal
                : DesignTokens.crimsonWarning;
            final sign = isPos ? '+' : '';
            final xirr = _computeXirr(symbolTrades);

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
                    value: CurrencyFormatter.format(avgTcb,
                        showDecimals: true)),
                _InfoRow(
                    label: 'Total Invested',
                    value: CurrencyFormatter.format(
                        totalInvested,
                        showDecimals: true)),
                _InfoRow(
                    label: 'Current Value',
                    value: CurrencyFormatter.format(
                        currentValue,
                        showDecimals: true)),
                _InfoRow(
                  label: 'Unrealized P&L',
                  value:
                      '$sign${CurrencyFormatter.format(pnl, showDecimals: true)}',
                  valueColor: pnlColor,
                ),
                _InfoRow(
                  label: 'Simple Return',
                  value:
                      '$sign${pnlPct.toStringAsFixed(2)}%',
                  valueColor: pnlColor,
                ),
                if (xirr != null)
                  _InfoRowWithInfo(
                    label: 'XIRR (annualised)',
                    value:
                        '${xirr >= 0 ? '+' : ''}${xirr.toStringAsFixed(2)}%',
                    valueColor: xirr >= 0
                        ? DesignTokens.obsidianTeal
                        : DesignTokens.crimsonWarning,
                    tooltipText: 'Extended Internal Rate of Return accounts for irregular deposit/withdrawal dates, providing a more accurate annualised return over time.',
                  ),
                if (totalCharges > 0)
                  _InfoRow(
                    label: 'Total Charges',
                    value: CurrencyFormatter.format(
                        totalCharges,
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

  // ─── Market Data Card ──────────────────────────────────────────────────────
  Widget _buildMarketDataCard() {
    if (_quote == null) {
      return _InfoCard(
        title: 'Market Data',
        children: [
          Center(
            child: Text('Market data unavailable',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: DesignTokens.textMediumContrast,
                    )),
          ),
        ],
      );
    }

    final q = _quote!;
    final range52w =
        q.fiftyTwoWeekHigh - q.fiftyTwoWeekLow;
    final progress52w = range52w > 0
        ? ((q.currentPrice - q.fiftyTwoWeekLow) / range52w)
            .clamp(0.0, 1.0)
        : 0.5;
    final volFmt = NumberFormat('#,##,###', 'en_IN');

    return _InfoCard(
      title: 'Market Data',
      children: [
        _InfoRow(
            label: 'Day High',
            value: CurrencyFormatter.format(q.dayHigh,
                showDecimals: true)),
        _InfoRow(
            label: 'Day Low',
            value: CurrencyFormatter.format(q.dayLow,
                showDecimals: true)),
        _InfoRowWithInfo(
            label: '52W High',
            value: CurrencyFormatter.format(
                q.fiftyTwoWeekHigh,
                showDecimals: true),
            tooltipText: 'The highest price this instrument has traded at over the past 52 weeks (1 year).'),
        _InfoRowWithInfo(
            label: '52W Low',
            value: CurrencyFormatter.format(q.fiftyTwoWeekLow,
                showDecimals: true),
            tooltipText: 'The lowest price this instrument has traded at over the past 52 weeks (1 year).'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress52w,
            backgroundColor: DesignTokens.graphiteBase,
            color: DesignTokens.obsidianTeal,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                CurrencyFormatter.format(q.fiftyTwoWeekLow,
                    showDecimals: true),
                style: TextStyle(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 10)),
            Text('52W Range',
                style: TextStyle(
                    color: DesignTokens.textMediumContrast
                        .withValues(alpha: 0.5),
                    fontSize: 9)),
            Text(
                CurrencyFormatter.format(q.fiftyTwoWeekHigh,
                    showDecimals: true),
                style: TextStyle(
                    color: DesignTokens.textMediumContrast,
                    fontSize: 10)),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRowWithInfo(
            label: 'Volume',
            value: volFmt.format(q.volume),
            tooltipText: 'The total number of shares/units traded during the current day.'),
        _InfoRow(
            label: 'Avg Volume (3M)',
            value: volFmt.format(q.avgVolume)),
      ],
    );
  }

  // ─── Entry Analysis Card ───────────────────────────────────────────────────
  Widget _buildEntryAnalysisCard() {
    return ref.watch(allTradesProvider).when(
          data: (allTrades) {
            final buys = allTrades
                .where((t) =>
                    t.trade.instrumentSymbol ==
                        widget.holding.instrumentSymbol &&
                    t.trade.tradeType ==
                        db_enums.TradeType.buy)
                .toList()
              ..sort((a, b) => a.trade.tradeTimestamp
                  .compareTo(b.trade.tradeTimestamp));

            if (buys.isEmpty) return const SizedBox.shrink();

            final firstDate =
                buys.first.trade.tradeTimestamp;
            final daysHeld =
                DateTime.now().difference(firstDate).inDays;
            final bestBuy = buys
                .map((t) => t.trade.pricePerUnit)
                .reduce(math.min);

            double weightedTcb = 0;
            double totalQty = 0;
            for (final tw in buys) {
              final t = tw.trade;
              if (t.trueCostBasis != null) {
                weightedTcb +=
                    t.trueCostBasis! * t.quantity;
                totalQty += t.quantity;
              }
            }
            final breakEven = totalQty > 0
                ? weightedTcb / totalQty
                : widget.holding.averagePrice;
            final currentPrice = _quote?.currentPrice ??
                widget.holding.averagePrice;
            final toBreakEven = currentPrice - breakEven;
            final toBreakEvenPct = breakEven != 0
                ? (toBreakEven / breakEven) * 100
                : 0.0;
            final isAbove = toBreakEven >= 0;
            final beColor = isAbove
                ? DesignTokens.obsidianTeal
                : DesignTokens.crimsonWarning;
            final beSign = isAbove ? '+' : '';

            return _InfoCard(
              title: 'Your Entry',
              children: [
                _InfoRow(
                    label: 'First Purchase',
                    value: DateFormat('dd MMM yyyy')
                        .format(firstDate)),
                _InfoRow(
                    label: 'Days Held',
                    value: '$daysHeld days'),
                _InfoRow(
                    label: 'Break-even',
                    value: CurrencyFormatter.format(breakEven,
                        showDecimals: true)),
                _InfoRow(
                  label: 'To Break-even',
                  value:
                      '$beSign${CurrencyFormatter.format(toBreakEven, showDecimals: true)} ($beSign${toBreakEvenPct.toStringAsFixed(2)}%)',
                  valueColor: beColor,
                ),
                _InfoRow(
                    label: 'Best Buy Price',
                    value: CurrencyFormatter.format(bestBuy,
                        showDecimals: true)),
                _InfoRow(
                    label: 'Avg Buy Price',
                    value: CurrencyFormatter.format(
                        widget.holding.averagePrice,
                        showDecimals: true)),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  // ─── Investment Journey ────────────────────────────────────────────────────
  Widget _buildInvestmentJourney() {
    return ref.watch(allTradesProvider).when(
          data: (allTrades) {
            final buys = allTrades
                .where((t) =>
                    t.trade.instrumentSymbol ==
                        widget.holding.instrumentSymbol &&
                    t.trade.tradeType ==
                        db_enums.TradeType.buy)
                .toList()
              ..sort((a, b) => b.trade.tradeTimestamp
                  .compareTo(a.trade.tradeTimestamp));

            if (buys.isEmpty) return const SizedBox.shrink();

            final currentPrice = _quote?.currentPrice ??
                widget.holding.averagePrice;

            return _InfoCard(
              title: 'Investment Journey',
              children: [
                ...buys.asMap().entries.map((entry) {
                  final i = entry.key;
                  final t = entry.value.trade;
                  final lotInvested =
                      t.pricePerUnit * t.quantity;
                  final lotCurrent =
                      currentPrice * t.quantity;
                  final lotPnL = lotCurrent - lotInvested;
                  final lotPct = lotInvested > 0
                      ? (lotPnL / lotInvested) * 100
                      : 0.0;
                  final isPos = lotPnL >= 0;
                  final pnlColor = isPos
                      ? DesignTokens.obsidianTeal
                      : DesignTokens.crimsonWarning;
                  final sign = isPos ? '+' : '';

                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: pnlColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (i < buys.length - 1)
                              Container(
                                width: 1.5,
                                height: 36,
                                color: Colors.white
                                    .withValues(alpha: 0.08),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(
                                            t.tradeTimestamp),
                                    style: TextStyle(
                                      color: DesignTokens
                                          .textHighContrast,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2),
                                    decoration: BoxDecoration(
                                      color: pnlColor
                                          .withValues(
                                              alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              6),
                                    ),
                                    child: Text(
                                      '$sign${lotPct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: pnlColor,
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final existingNote = _tradeNotes[t.id];
                                      final result = await showDialog<String>(
                                        context: context,
                                        builder: (_) => TradeNoteDialog(
                                          tradeId: t.id,
                                          symbol: widget.holding.instrumentSymbol.toUpperCase(),
                                          tradeDate: t.tradeTimestamp,
                                          tradePrice: t.pricePerUnit,
                                          existingNote: existingNote,
                                        ),
                                      );
                                      if (result != null) {
                                        setState(() {
                                          if (result.isEmpty) {
                                            _tradeNotes.remove(t.id);
                                          } else {
                                            _tradeNotes[t.id] = result;
                                          }
                                        });
                                      }
                                    },
                                    child: Icon(
                                      _tradeNotes.containsKey(t.id)
                                          ? Icons.sticky_note_2_rounded
                                          : Icons.sticky_note_2_outlined,
                                      size: 16,
                                      color: _tradeNotes.containsKey(t.id)
                                          ? DesignTokens.ashGold
                                          : DesignTokens.textMediumContrast
                                              .withValues(alpha: 0.3),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${t.quantity.toStringAsFixed(0)} units @ ${CurrencyFormatter.format(t.pricePerUnit, showDecimals: true)}',
                                    style: TextStyle(
                                      color: DesignTokens
                                          .textMediumContrast,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$sign${CurrencyFormatter.format(lotPnL, showDecimals: false)}',
                                    style: TextStyle(
                                      color: pnlColor,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (_tradeNotes.containsKey(t.id)) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: DesignTokens.ashGold.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: DesignTokens.ashGold.withValues(alpha: 0.15)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.format_quote_rounded,
                                          size: 12,
                                          color: DesignTokens.ashGold.withValues(alpha: 0.6)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _tradeNotes[t.id]!,
                                          style: TextStyle(
                                            color: DesignTokens.ashGold.withValues(alpha: 0.8),
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  // ─── Returns Calculator ────────────────────────────────────────────────────
  Widget _buildReturnsCalculator() {
    return _InfoCard(
      title: 'Returns Calculator',
      children: [
        Text('If you had invested...',
            style: TextStyle(
              color: DesignTokens.textMediumContrast,
              fontSize: 11,
            )),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: DesignTokens.graphiteBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white
                          .withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Text('₹',
                        style: TextStyle(
                          color:
                              DesignTokens.textMediumContrast,
                          fontSize: 14,
                        )),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _calcAmountController,
                        keyboardType: TextInputType.number,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: DesignTokens
                                  .textHighContrast,
                            ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) =>
                            _computeCalcResult(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                // Always allow picking from 2010 (GOLDBEES started 2007,
                // NIFTYBEES started 2002 — 2010 covers all practical cases)
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _calcDate,
                  firstDate: DateTime(2010),   // ← full historical range
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: DesignTokens.obsidianTeal,
                        surface: DesignTokens.graphiteSurface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked == null) return;
                if (!mounted) return;
                setState(() => _calcDate = picked);
                _computeCalcResultForDate(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: DesignTokens.graphiteBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white
                          .withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 14,
                        color:
                            DesignTokens.textMediumContrast),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd MMM yy')
                          .format(_calcDate),
                      style: TextStyle(
                        color: DesignTokens.textHighContrast,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isFetchingHistoricalCandles)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.obsidianTeal,
                ),
              ),
            ),
          )
        else if (_calcResult != null)
          Builder(builder: (context) {
            final invested = double.tryParse(
                    _calcAmountController.text) ??
                0;
            final gain = _calcResult! - invested;
            final isGain = gain >= 0;
            final pct = invested > 0
                ? (gain / invested) * 100
                : 0.0;
            final resultColor = isGain
                ? DesignTokens.obsidianTeal
                : DesignTokens.crimsonWarning;
            final sign = isGain ? '+' : '';

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        resultColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text('Would be worth today',
                      style: TextStyle(
                        color:
                            DesignTokens.textMediumContrast,
                        fontSize: 11,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(
                        _calcResult!,
                        showDecimals: false),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: resultColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$sign${CurrencyFormatter.format(gain, showDecimals: false)}  ($sign${pct.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          })
        else
          Center(
            child: Text(
              _candles.isEmpty
                  ? 'Load chart data to use calculator'
                  : 'Enter amount and pick a date',
              style: TextStyle(
                color: DesignTokens.textMediumContrast
                    .withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildSymbolInfoCard() {
    final cls = SymbolClassifier.classify(widget.holding.instrumentSymbol);
    return _InfoCard(
      title: 'Symbol Info',
      children: [
        _InfoRowWithInfo(
          label: 'Type',
          value: cls.isEtf ? 'ETF' : 'Equity',
          tooltipText: 'Asset Class indicates the type of security. ETFs are funds tracking an index, while Equity represents ownership in a company.',
        ),
        _InfoRowWithInfo(
          label: 'Category',
          value: cls.assetClass.name,
          tooltipText: 'The broad classification assigned to this asset by Viren Intelligence.',
        ),
      ],
    );
  }

  Widget _buildFundamentalsCard() {
    return _InfoCard(
      title: 'Fundamentals',
      children: const [
        _InfoRowWithInfo(label: 'Gross Profit', value: '₹--', tooltipText: 'Total revenue minus the cost of goods sold.'),
        _InfoRowWithInfo(label: 'Net Profit', value: '₹--', tooltipText: 'The actual profit after working expenses not included in the calculation of gross profit have been paid.'),
        _InfoRowWithInfo(label: 'P/E Ratio', value: '--', tooltipText: 'Price-to-Earnings ratio.'),
      ],
    );
  }

  Widget _buildTaxCalculatorCard() {
    return ref.watch(allTradesProvider).when(
      data: (allTrades) {
        // Filter to buy trades for this symbol only
        final buyTrades = allTrades
            .where((tw) =>
                tw.trade.instrumentSymbol ==
                    widget.holding.instrumentSymbol &&
                tw.trade.tradeType == db_enums.TradeType.buy)
            .toList()
          ..sort((a, b) => a.trade.tradeTimestamp
              .compareTo(b.trade.tradeTimestamp));

        if (buyTrades.isEmpty) return const SizedBox.shrink();

        // Use current price or fall back to avg cost
        final currentPrice =
            _quote?.currentPrice ?? widget.holding.averagePrice;
        final totalQty = widget.holding.totalQuantity;
        final avgCost = widget.holding.averagePrice;
        final totalInvested = avgCost * totalQty;
        final currentValue = currentPrice * totalQty;
        final grossProfit = currentValue - totalInvested;

        // Determine holding period from FIRST buy
        final firstBuyDate = buyTrades.first.trade.tradeTimestamp;
        final daysHeld =
            DateTime.now().difference(firstBuyDate).inDays;
        final isLongTerm = daysHeld >= 365;

        // Build the card for a loss position
        if (grossProfit <= 0) {
          return _InfoCard(
            title: 'Tax Estimator',
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DesignTokens.crimsonWarning
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: DesignTokens.crimsonWarning
                          .withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14,
                        color: DesignTokens.crimsonWarning
                            .withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Position is at a loss — no tax applicable '
                        'if you sell now. Loss can be used to offset '
                        'gains from other holdings.',
                        style: TextStyle(
                          fontSize: 11,
                          color: DesignTokens.crimsonWarning
                              .withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Current Loss',
                value:
                    CurrencyFormatter.format(grossProfit, showDecimals: true),
                valueColor: DesignTokens.crimsonWarning,
              ),
              _InfoRow(
                label: 'Held for',
                value: '$daysHeld days '
                    '(${isLongTerm ? "Long Term" : "Short Term"})',
              ),
            ],
          );
        }

        // ── Profitable position — compute tax ──────────────────

        // Indian Capital Gains Tax (post July 2024 Budget):
        // STCG  < 12 months: 20% flat on equity/ETF gains
        // LTCG >= 12 months: 12.5% above ₹1,25,000 annual exemption
        double taxAmount;
        double taxableProfit;
        String taxType;
        String taxRateNote;
        String holdingNote;

        if (isLongTerm) {
          const ltcgExemption = 125000.0; // ₹1.25 lakh
          taxableProfit =
              (grossProfit - ltcgExemption).clamp(0.0, double.infinity);
          taxAmount = taxableProfit * 0.125; // 12.5%
          taxType = 'Long Term Capital Gains (LTCG)';
          taxRateNote = '12.5% on gains above ₹1.25L exemption';
          holdingNote = '$daysHeld days held — qualifies for LTCG';
        } else {
          taxableProfit = grossProfit;
          taxAmount = grossProfit * 0.20; // 20%
          taxType = 'Short Term Capital Gains (STCG)';
          taxRateNote = '20% flat rate';
          holdingNote = '$daysHeld days held — STCG applies'
              ' (sell after ${365 - daysHeld} more days for LTCG)';
        }

        final netProfit = grossProfit - taxAmount;
        final effectiveTaxRate = grossProfit > 0
            ? (taxAmount / grossProfit) * 100
            : 0.0;

        return _InfoCard(
          title: 'Tax Estimator',
          children: [
            // Status banner
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isLongTerm
                    ? DesignTokens.obsidianTeal.withValues(alpha: 0.08)
                    : DesignTokens.ashGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLongTerm
                      ? DesignTokens.obsidianTeal.withValues(alpha: 0.2)
                      : DesignTokens.ashGold.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isLongTerm
                        ? Icons.check_circle_outline_rounded
                        : Icons.schedule_rounded,
                    size: 14,
                    color: isLongTerm
                        ? DesignTokens.obsidianTeal
                        : DesignTokens.ashGold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          taxType,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isLongTerm
                                ? DesignTokens.obsidianTeal
                                : DesignTokens.ashGold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          holdingNote,
                          style: TextStyle(
                            fontSize: 10,
                            color: isLongTerm
                                ? DesignTokens.obsidianTeal
                                    .withValues(alpha: 0.7)
                                : DesignTokens.ashGold
                                    .withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Numbers breakdown
            _InfoRowWithInfo(
              label: 'Gross Profit',
              value:
                  '+${CurrencyFormatter.format(grossProfit, showDecimals: true)}',
              tooltipText:
                  'Total gain before tax: current value minus your total invested amount.',
            ),

            if (isLongTerm && taxableProfit < grossProfit) ...[
              _InfoRow(
                label: 'LTCG Exemption',
                value:
                    '-₹1,25,000',
                valueColor: DesignTokens.obsidianTeal,
              ),
              _InfoRow(
                label: 'Taxable Amount',
                value: CurrencyFormatter.format(taxableProfit,
                    showDecimals: true),
              ),
            ],

            _InfoRowWithInfo(
              label: 'Tax @ $taxRateNote',
              value:
                  '-${CurrencyFormatter.format(taxAmount, showDecimals: true)}',
              tooltipText:
                  'Estimated tax liability. $taxType: $taxRateNote. '
                  'This is an estimate only — consult a CA for exact liability.',
              valueColor: DesignTokens.crimsonWarning,
            ),

            Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 20),

            _InfoRowWithInfo(
              label: 'Net Profit (after tax)',
              value:
                  '+${CurrencyFormatter.format(netProfit, showDecimals: true)}',
              tooltipText:
                  'What you actually take home after paying capital gains tax.',
              valueColor: DesignTokens.obsidianTeal,
            ),

            _InfoRow(
              label: 'Effective Tax Rate',
              value: '${effectiveTaxRate.toStringAsFixed(1)}%',
              valueColor: DesignTokens.textMediumContrast,
            ),

            // Tip if short term and close to LTCG threshold
            if (!isLongTerm && daysHeld > 300) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DesignTokens.ashGold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          DesignTokens.ashGold.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 13,
                        color: DesignTokens.ashGold
                            .withValues(alpha: 0.8)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'You are ${365 - daysHeld} days away from LTCG. '
                        'Waiting saves you ₹${CurrencyFormatter.format(grossProfit * 0.20 - (grossProfit - 125000).clamp(0, double.infinity) * 0.125, showDecimals: false)} in tax.',
                        style: TextStyle(
                          fontSize: 10,
                          color: DesignTokens.ashGold
                              .withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              '* Estimate only. Based on simplified LTCG/STCG rules '
              'for listed equity and ETFs. Actual liability may differ '
              'based on your total gains across all investments. '
              'Consult a CA for exact advice.',
              style: TextStyle(
                color: DesignTokens.textMediumContrast
                    .withValues(alpha: 0.4),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─── Market Status Badge ──────────────────────────────────────────────────────
class _MarketStatusBadge extends StatefulWidget {
  const _MarketStatusBadge();

  @override
  State<_MarketStatusBadge> createState() => _MarketStatusBadgeState();
}

class _MarketStatusBadgeState extends State<_MarketStatusBadge> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late MarketStatus _status;

  @override
  void initState() {
    super.initState();
    _status = MarketStatusHelper.current();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        setState(() => _status = MarketStatusHelper.current());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = MarketStatusHelper.color(_status);
    final label = MarketStatusHelper.label(_status);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_status == MarketStatus.live)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) => Opacity(
                  opacity: _pulseAnimation.value, child: child),
              child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
            )
          else
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
        ],
      ),
    );
  }
}


class _InfoRowWithInfo extends StatelessWidget {
  final String label;
  final String value;
  final String tooltipText;
  final Color? valueColor;

  const _InfoRowWithInfo({
    required this.label,
    required this.value,
    required this.tooltipText,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: DesignTokens.textMediumContrast,
                      )),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: DesignTokens.graphiteSurface,
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Text(tooltipText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.textMediumContrast, height: 1.5)),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
                child: Icon(Icons.info_outline_rounded, size: 14, color: DesignTokens.textMediumContrast.withValues(alpha: 0.5)),
              ),
            ],
          ),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: valueColor ??
                        DesignTokens.textHighContrast,
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────
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
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(
      {required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  )),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: valueColor ??
                        DesignTokens.textHighContrast,
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }
}