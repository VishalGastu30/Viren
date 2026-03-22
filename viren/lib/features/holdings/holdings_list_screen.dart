import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/providers/database_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/market/market_data_service.dart';
import '../../core/market/live_price_cache.dart';
import '../../core/market/nse_price_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';
import '../../core/utils/currency_formatter.dart';
import 'stock_detail_screen.dart';

// ─── LiveHolding model ────────────────────────────────────────────────────────

class LiveHolding {
  final Holding holding;
  final double? cmp;
  final double? currentValue;
  final double? unrealisedPnL;
  final double? returnPct;
  // Sparkline candles — loaded lazily in background after prices are ready.
  // null = not yet fetched. empty list = fetch attempted but no data.
  final List<OhlcvCandle>? sparklineCandles;

  const LiveHolding({
    required this.holding,
    this.cmp,
    this.currentValue,
    this.unrealisedPnL,
    this.returnPct,
    this.sparklineCandles,
  });

  bool get hasPriceData => cmp != null;
  bool get isProfit => (unrealisedPnL ?? 0) >= 0;

  String get pnlString {
    if (unrealisedPnL == null) return '--';
    final sign = unrealisedPnL! >= 0 ? '+' : '';
    return '$sign${CurrencyFormatter.format(unrealisedPnL!, showDecimals: false)}';
  }

  String get returnString {
    if (returnPct == null) return '--';
    final sign = returnPct! >= 0 ? '+' : '';
    return '$sign${returnPct!.toStringAsFixed(2)}%';
  }

  // Used to attach sparkline data without rebuilding everything
  LiveHolding copyWith({List<OhlcvCandle>? sparklineCandles}) {
    return LiveHolding(
      holding: holding,
      cmp: cmp,
      currentValue: currentValue,
      unrealisedPnL: unrealisedPnL,
      returnPct: returnPct,
      sparklineCandles: sparklineCandles ?? this.sparklineCandles,
    );
  }
}

// ─── PortfolioTotals ──────────────────────────────────────────────────────────

class PortfolioTotals {
  final double totalInvested;
  final double totalCurrentValue;
  final double totalPnL;
  final double totalReturnPct;
  final bool hasPriceData;

  const PortfolioTotals({
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalPnL,
    required this.totalReturnPct,
    required this.hasPriceData,
  });

  bool get isProfit => totalPnL >= 0;

  String get pnlString {
    final sign = totalPnL >= 0 ? '+' : '';
    return '$sign${CurrencyFormatter.format(totalPnL, showDecimals: false)}';
  }

  String get returnString {
    final sign = totalReturnPct >= 0 ? '+' : '';
    return '$sign${totalReturnPct.toStringAsFixed(2)}%';
  }
}

// ─── Sort options ─────────────────────────────────────────────────────────────

enum HoldingSort { returnPct, pnlRupee, invested, name }

// ─── Sector / type lookup ─────────────────────────────────────────────────────

class _SectorLookup {
  static const Map<String, String> _tags = {
    'NIFTYBEES': 'ETF', 'GOLDBEES': 'ETF', 'SILVERBEES': 'ETF',
    'LIQUIDBEES': 'ETF', 'CPSEETF': 'ETF', 'BANKETF': 'ETF',
    'ICICIB22': 'ETF', 'SILVERIETF': 'ETF', 'SETFNIF50': 'ETF',
    'KOTAKBKETF': 'ETF', 'MOM100': 'ETF', 'PSUBNKBEES': 'ETF',
    'HDFCBANK': 'Bank', 'ICICIBANK': 'Bank', 'SBIN': 'Bank',
    'KOTAKBANK': 'Bank', 'AXISBANK': 'Bank', 'INDUSINDBK': 'Bank',
    'BANKBARODA': 'Bank', 'YESBANK': 'Bank', 'IDFCFIRSTB': 'Bank',
    'FEDERALBNK': 'Bank',
    'TCS': 'IT', 'INFY': 'IT', 'WIPRO': 'IT', 'HCLTECH': 'IT',
    'TECHM': 'IT', 'LTIM': 'IT', 'MPHASIS': 'IT', 'COFORGE': 'IT',
    'PERSISTENT': 'IT',
    'MARUTI': 'Auto', 'TATAMOTORS': 'Auto', 'M&M': 'Auto',
    'BAJAJ-AUTO': 'Auto', 'HEROMOTOCO': 'Auto', 'EICHERMOT': 'Auto',
    'SUNPHARMA': 'Pharma', 'DRREDDY': 'Pharma', 'CIPLA': 'Pharma',
    'DIVISLAB': 'Pharma', 'AUROPHARMA': 'Pharma',
    'RELIANCE': 'Energy', 'ONGC': 'Energy', 'BPCL': 'Energy',
    'IOC': 'Energy', 'POWERGRID': 'Energy', 'NTPC': 'Energy',
    'TATAPOWER': 'Energy',
    'HINDUNILVR': 'FMCG', 'ITC': 'FMCG', 'NESTLEIND': 'FMCG',
    'BRITANNIA': 'FMCG', 'DABUR': 'FMCG',
    'BAJFINANCE': 'NBFC', 'BAJAJFINSV': 'NBFC', 'CHOLAFIN': 'NBFC',
    'MUTHOOTFIN': 'NBFC',
    'TATASTEEL': 'Metal', 'HINDALCO': 'Metal', 'JSWSTEEL': 'Metal',
    'SAIL': 'Metal', 'COALINDIA': 'Metal',
    'LT': 'Infra', 'ULTRACEMCO': 'Infra', 'SHREECEM': 'Infra',
    'ADANIPORTS': 'Infra',
    'BHARTIARTL': 'Telecom', 'IDEA': 'Telecom',
  };

  static String getTag(String symbol) =>
      _tags[symbol.toUpperCase()] ?? 'Equity';

  static Color tagColor(String tag) {
    switch (tag) {
      case 'ETF':      return DesignTokens.obsidianTeal;
      case 'Bank':     return DesignTokens.ashGold;
      case 'IT':       return const Color(0xFF7B8CDE);
      case 'Pharma':   return const Color(0xFF6BBF8E);
      case 'Auto':     return const Color(0xFFE8956D);
      case 'Energy':   return const Color(0xFFE8C84A);
      case 'FMCG':     return const Color(0xFFD4A8E0);
      case 'Metal':    return const Color(0xFF9E9E9E);
      case 'NBFC':     return const Color(0xFFFFB347);
      case 'Infra':    return const Color(0xFF87CEEB);
      case 'Telecom':  return const Color(0xFFDDA0DD);
      default:         return DesignTokens.textMediumContrast;
    }
  }
}

// ─── Sparkline Painter ────────────────────────────────────────────────────────
// Tiny 72×36 line chart. No axes, no labels. Pure trend signal.
// Drawn with a CustomPainter — zero dependency on fl_chart.

class _SparklinePainter extends CustomPainter {
  final List<double> closes;
  final bool isProfit;
  final double? avgCost; // draw a subtle avg cost dot marker if provided

  const _SparklinePainter({
    required this.closes,
    required this.isProfit,
    this.avgCost,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (closes.length < 2) return;

    final minY = closes.reduce(math.min);
    final maxY = closes.reduce(math.max);
    final range = maxY - minY;
    // Flat line guard — add tiny padding so it renders as a horizontal line
    final effectiveRange = range < 0.001 ? 1.0 : range;

    double toY(double price) =>
        size.height - ((price - minY) / effectiveRange) * size.height;

    final color =
        isProfit ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;

    // Build path
    final path = Path();
    final step = size.width / (closes.length - 1);

    for (int i = 0; i < closes.length; i++) {
      final x = i * step;
      final y = toY(closes[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Smooth cubic bezier between points
        final prevX = (i - 1) * step;
        final prevY = toY(closes[i - 1]);
        final cpX = prevX + step / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    // Gradient fill below line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, gradientPaint);

    // Line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // End dot — shows current price position
    final lastX = (closes.length - 1) * step;
    final lastY = toY(closes.last);
    canvas.drawCircle(
      Offset(lastX, lastY),
      2.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.closes != closes || old.isProfit != isProfit;
}

// ─── HoldingsListScreen ───────────────────────────────────────────────────────

class HoldingsListScreen extends ConsumerStatefulWidget {
  const HoldingsListScreen({super.key});

  @override
  ConsumerState<HoldingsListScreen> createState() =>
      _HoldingsListScreenState();
}

class _HoldingsListScreenState extends ConsumerState<HoldingsListScreen> {
  bool _isLoaded = false;
  HoldingSort _sortBy = HoldingSort.returnPct;
  bool _isLoadingPrices = false;

  List<LiveHolding> _liveHoldings = [];
  PortfolioTotals? _totals;

  final _marketService = MarketDataService();
  Timer? _refreshTimer;

  // ── Sparkline cache ────────────────────────────────────────────────────────
  // Static so it survives widget rebuilds and screen re-visits within the
  // same app session. Key = uppercase symbol.
  static final Map<String, List<OhlcvCandle>> _sparklineCache = {};
  bool _sparklinesFetched = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _isLoaded = true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Step A — load live prices ──────────────────────────────────────────────
  Future<void> _loadLivePrices(List<Holding> holdings) async {
    if (holdings.isEmpty) return;
    if (mounted) setState(() => _isLoadingPrices = true);

    try {
      final symbols = holdings.map((h) => h.instrumentSymbol).toList();

      // NsePriceService batch first (proven reliable)
      final prices = await NsePriceService.getPrices(symbols);

      // MarketDataService fallback for anything NsePriceService missed
      final missing =
          symbols.where((s) => prices[s.toUpperCase()] == null).toList();
      for (final sym in missing) {
        final quote = await _marketService.fetchQuote(sym);
        if (quote != null) prices[sym.toUpperCase()] = quote.currentPrice;
      }

      double totalInvested = 0;
      double totalCurrentValue = 0;
      bool anyPrices = false;

      final enriched = holdings.map((h) {
        final sym = h.instrumentSymbol.toUpperCase();
        final cmp = prices[sym];
        totalInvested += h.investedValue;

        if (cmp != null) {
          anyPrices = true;
          final cv = cmp * h.totalQuantity;
          final pnl = cv - h.investedValue;
          final ret =
              h.investedValue > 0 ? (pnl / h.investedValue) * 100 : 0.0;
          totalCurrentValue += cv;
          // Re-attach cached sparkline if already fetched for this symbol
          return LiveHolding(
            holding: h,
            cmp: cmp,
            currentValue: cv,
            unrealisedPnL: pnl,
            returnPct: ret,
            sparklineCandles: _sparklineCache[sym],
          );
        } else {
          totalCurrentValue += h.investedValue;
          return LiveHolding(
            holding: h,
            sparklineCandles: _sparklineCache[sym],
          );
        }
      }).toList();

      final totalPnL = totalCurrentValue - totalInvested;
      final totalReturnPct =
          totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0.0;

      if (mounted) {
        // Register all these symbols with the background cache so it knows to watch them
        ref.read(livePriceCacheProvider.notifier).registerSymbols(symbols);
        
        setState(() {
          _liveHoldings = _sortHoldings(enriched);
          _totals = PortfolioTotals(
            totalInvested: totalInvested,
            totalCurrentValue: totalCurrentValue,
            totalPnL: totalPnL,
            totalReturnPct: totalReturnPct,
            hasPriceData: anyPrices,
          );
          _isLoadingPrices = false;
        });
      }

      // ── Step B — load sparklines in background after prices are shown ──────
      // Reset flag on manual refresh so sparklines re-fetch too
      _sparklinesFetched = false;
      _loadSparklines();
    } catch (_) {
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  // ── Step B — lazy sparkline loader ────────────────────────────────────────
  // Fires after _loadLivePrices completes. Fetches 1M daily candles per
  // symbol with a 150ms stagger so we never hammer Yahoo rate limits.
  // Each symbol updates the row the moment its data arrives — no spinner,
  // no blocking. Graceful: if any fetch fails the row just shows nothing.
  Future<void> _loadSparklines() async {
    if (_sparklinesFetched) return;
    _sparklinesFetched = true;

    // Short pause — let the price render complete and UI settle first
    await Future.delayed(const Duration(milliseconds: 400));

    final symbols = _liveHoldings
        .map((lh) => lh.holding.instrumentSymbol.toUpperCase())
        .toList();

    for (final sym in symbols) {
      if (!mounted) return;

      // Use cached data if available — no refetch needed
      if (_sparklineCache.containsKey(sym)) {
        // Make sure the row has it even if it was built before cache was warm
        _attachSparkline(sym, _sparklineCache[sym]!);
        continue;
      }

      try {
        // 1M with daily interval = ~22 data points — perfect sparkline size
        final candles = await _marketService.fetchCandles(sym, '1M');
        if (candles.isNotEmpty) {
          _sparklineCache[sym] = candles;
          _attachSparkline(sym, candles);
        } else {
          // Mark as attempted with empty list so we don't retry this session
          _sparklineCache[sym] = [];
        }
      } catch (_) {
        _sparklineCache[sym] = [];
      }

      // 150ms gap between fetches — avoids Yahoo rate-limit (429) responses
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  // Attaches freshly fetched sparkline data to the correct row and rebuilds
  // only that row via setState. Does NOT re-sort to avoid jarring reorders.
  void _attachSparkline(String sym, List<OhlcvCandle> candles) {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _liveHoldings.length; i++) {
        if (_liveHoldings[i].holding.instrumentSymbol.toUpperCase() == sym) {
          _liveHoldings[i] =
              _liveHoldings[i].copyWith(sparklineCandles: candles);
          break;
        }
      }
    });
  }

  // ── Sorting ────────────────────────────────────────────────────────────────
  List<LiveHolding> _sortHoldings(List<LiveHolding> list) {
    final sorted = List<LiveHolding>.from(list);
    switch (_sortBy) {
      case HoldingSort.returnPct:
        sorted.sort((a, b) =>
            (b.returnPct ?? double.negativeInfinity)
                .compareTo(a.returnPct ?? double.negativeInfinity));
      case HoldingSort.pnlRupee:
        sorted.sort((a, b) =>
            (b.unrealisedPnL ?? double.negativeInfinity)
                .compareTo(a.unrealisedPnL ?? double.negativeInfinity));
      case HoldingSort.invested:
        sorted.sort((a, b) =>
            b.holding.investedValue.compareTo(a.holding.investedValue));
      case HoldingSort.name:
        sorted.sort((a, b) => a.holding.instrumentSymbol
            .compareTo(b.holding.instrumentSymbol));
    }
    return sorted;
  }

  void _applySort(HoldingSort sort) {
    setState(() {
      _sortBy = sort;
      _liveHoldings = _sortHoldings(_liveHoldings);
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.graphiteSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SortBottomSheet(
        current: _sortBy,
        onSelected: (sort) {
          Navigator.pop(ctx);
          _applySort(sort);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Listen to live price cache and update rows if prices change
    ref.listen<LivePriceState>(livePriceCacheProvider, (previous, next) {
      if (_liveHoldings.isEmpty) return;
      
      bool needsRebuild = false;
      final updatedList = List<LiveHolding>.from(_liveHoldings);
      double totalInvested = 0;
      double totalCurrentValue = 0;
      bool anyPrices = false;

      for (int i = 0; i < updatedList.length; i++) {
        final lh = updatedList[i];
        final sym = lh.holding.instrumentSymbol.toUpperCase();
        final quote = next.quoteFor(sym);
        
        totalInvested += lh.holding.investedValue;
        
        if (quote != null) {
          anyPrices = true;
          // Only update if price changed
          if (lh.cmp != quote.currentPrice) {
            needsRebuild = true;
            final cv = quote.currentPrice * lh.holding.totalQuantity;
            final pnl = cv - lh.holding.investedValue;
            final ret = lh.holding.investedValue > 0 ? (pnl / lh.holding.investedValue) * 100 : 0.0;
            
            updatedList[i] = LiveHolding(
              holding: lh.holding,
              cmp: quote.currentPrice,
              currentValue: cv,
              unrealisedPnL: pnl,
              returnPct: ret,
              sparklineCandles: lh.sparklineCandles,
            );
          } else {
             totalCurrentValue += (lh.currentValue ?? lh.holding.investedValue);
          }
        } else {
           totalCurrentValue += (lh.currentValue ?? lh.holding.investedValue);
        }
      }

      if (needsRebuild && mounted) {
        // Recalculate totals since prices changed
        totalCurrentValue = 0;
        for (final lh in updatedList) {
           totalCurrentValue += (lh.currentValue ?? lh.holding.investedValue);
        }
        final totalPnL = totalCurrentValue - totalInvested;
        final totalReturnPct = totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0.0;
        
        setState(() {
          _liveHoldings = _sortHoldings(updatedList);
          _totals = PortfolioTotals(
            totalInvested: totalInvested,
            totalCurrentValue: totalCurrentValue,
            totalPnL: totalPnL,
            totalReturnPct: totalReturnPct,
            hasPriceData: anyPrices,
          );
        });
      }
    });

    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        backgroundColor: DesignTokens.graphiteBase,
        elevation: 0,
        title: Text('Holdings',
            style: Theme.of(context).textTheme.displaySmall),
        actions: [
          if (_isLoadingPrices)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.obsidianTeal,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: DesignTokens.textMediumContrast,
              onPressed: () {
                final holdings =
                    ref.read(holdingsStreamProvider).value ?? [];
                _loadLivePrices(holdings);
              },
            ),
          IconButton(
            icon: const Icon(Icons.sort_rounded, size: 20),
            color: DesignTokens.textMediumContrast,
            onPressed: _showSortSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ref.watch(holdingsStreamProvider).when(
            skipLoadingOnReload: true,
            data: (holdings) {
              if (holdings.isNotEmpty && _liveHoldings.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadLivePrices(holdings);
                });
              }

              if (holdings.isEmpty) return _buildEmptyState();

              return RefreshIndicator(
                color: DesignTokens.obsidianTeal,
                backgroundColor: DesignTokens.graphiteSurface,
                onRefresh: () => _loadLivePrices(holdings),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child:
                            _PortfolioSummaryCard(totals: _totals),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              '${holdings.length} HOLDINGS',
                              style: TextStyle(
                                color: DesignTokens.textMediumContrast
                                    .withValues(alpha: 0.5),
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showSortSheet,
                              child: Row(
                                children: [
                                  Text(
                                    _sortLabel(_sortBy),
                                    style: TextStyle(
                                      color: DesignTokens.obsidianTeal,
                                      fontSize: 10,
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: DesignTokens.obsidianTeal,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final lh = _liveHoldings.isNotEmpty
                              ? _liveHoldings[index]
                              : LiveHolding(holding: holdings[index]);

                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: _isLoaded ? 1 : 0),
                            duration: AnimationPresets.durationNormal +
                                AnimationPresets.staggerItem(index),
                            curve: AnimationPresets.entrance,
                            builder: (context, val, child) => Opacity(
                              opacity: val,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  20 *
                                      (1 - val) *
                                      AnimationPresets.parallaxFactor,
                                ),
                                child: child,
                              ),
                            ),
                            child: _HoldingRow(liveHolding: lh),
                          );
                        },
                        childCount: _liveHoldings.isNotEmpty
                            ? _liveHoldings.length
                            : holdings.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 100)),
                  ],
                ),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(
                    color: DesignTokens.obsidianTeal, strokeWidth: 2)),
            error: (err, _) => Center(
                child: Text('Error: $err',
                    style: TextStyle(
                        color: DesignTokens.textMediumContrast))),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56,
              color: DesignTokens.textMediumContrast
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No holdings yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: DesignTokens.textMediumContrast,
                  )),
          const SizedBox(height: 8),
          Text(
            'Import trades to see your portfolio here.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.textMediumContrast
                      .withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(HoldingSort sort) {
    switch (sort) {
      case HoldingSort.returnPct: return 'RETURN %';
      case HoldingSort.pnlRupee:  return 'P&L ₹';
      case HoldingSort.invested:  return 'INVESTED';
      case HoldingSort.name:      return 'NAME';
    }
  }
}

// ─── Portfolio Summary Card ───────────────────────────────────────────────────

class _PortfolioSummaryCard extends StatefulWidget {
  final PortfolioTotals? totals;
  const _PortfolioSummaryCard({this.totals});

  @override
  State<_PortfolioSummaryCard> createState() =>
      _PortfolioSummaryCardState();
}

class _PortfolioSummaryCardState extends State<_PortfolioSummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.totals;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: DesignTokens.graphiteSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Value',
                        style: TextStyle(
                          color: DesignTokens.textMediumContrast,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      t != null
                          ? CurrencyFormatter.format(
                              t.totalCurrentValue,
                              showDecimals: false)
                          : '--',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Spacer(),
                if (t != null)
                  _PnLChip(
                    label: '${t.pnlString}  ${t.returnString}',
                    isProfit: t.isProfit,
                    large: true,
                  ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  const SizedBox(height: 16),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.05),
                      height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _SummaryDetail(
                        label: 'Invested',
                        value: t != null
                            ? CurrencyFormatter.format(
                                t.totalInvested,
                                showDecimals: false)
                            : '--',
                      ),
                      _SummaryDetail(
                        label: 'Total P&L',
                        value: t?.pnlString ?? '--',
                        valueColor: t != null
                            ? (t.isProfit
                                ? DesignTokens.obsidianTeal
                                : DesignTokens.crimsonWarning)
                            : null,
                      ),
                      _SummaryDetail(
                        label: 'Return',
                        value: t?.returnString ?? '--',
                        valueColor: t != null
                            ? (t.isProfit
                                ? DesignTokens.obsidianTeal
                                : DesignTokens.crimsonWarning)
                            : null,
                      ),
                    ],
                  ),
                  if (t != null && !t.hasPriceData)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Live prices unavailable — showing invested values',
                        style: TextStyle(
                          color: DesignTokens.textMediumContrast
                              .withValues(alpha: 0.5),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: DesignTokens.textMediumContrast
                    .withValues(alpha: 0.3),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryDetail(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                color: DesignTokens.textMediumContrast
                    .withValues(alpha: 0.6),
                fontSize: 10,
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: valueColor ?? DesignTokens.textHighContrast,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  )),
        ],
      ),
    );
  }
}

// ─── Holding Row ──────────────────────────────────────────────────────────────

class _HoldingRow extends StatefulWidget {
  final LiveHolding liveHolding;
  const _HoldingRow({required this.liveHolding});

  @override
  State<_HoldingRow> createState() => _HoldingRowState();
}

class _HoldingRowState extends State<_HoldingRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final lh = widget.liveHolding;
    final h = lh.holding;
    final tag = _SectorLookup.getTag(h.instrumentSymbol);
    final tagColor = _SectorLookup.tagColor(tag);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => StockDetailScreen(holding: h)),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isPressed
              ? DesignTokens.graphiteSurface.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Left: symbol + sector tag + qty/avg ───────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            h.instrumentSymbol,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                          ),
                          const SizedBox(width: 7),
                          _SectorTag(label: tag, color: tagColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${h.totalQuantity.toStringAsFixed(0)} qty',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: DesignTokens.textMediumContrast,
                                  fontSize: 11,
                                ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('·',
                                style: TextStyle(
                                    color: DesignTokens.textMediumContrast
                                        .withValues(alpha: 0.35))),
                          ),
                          Text(
                            'avg ${CurrencyFormatter.format(h.averagePrice, showDecimals: true)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: DesignTokens.textMediumContrast,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Centre: sparkline ─────────────────────────────────
                _SparklineWidget(liveHolding: lh),

                const SizedBox(width: 12),

                // ── Right: current value + P&L chip ───────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lh.hasPriceData
                          ? CurrencyFormatter.format(lh.currentValue!,
                              showDecimals: false)
                          : CurrencyFormatter.format(h.investedValue,
                              showDecimals: false),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    _PnLChip(
                      label: lh.hasPriceData
                          ? '${lh.pnlString}  ${lh.returnString}'
                          : '--',
                      isProfit: lh.isProfit,
                      large: false,
                    ),
                  ],
                ),

                // ── Arrow ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: DesignTokens.textMediumContrast
                        .withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sparkline Widget ─────────────────────────────────────────────────────────
// Sits between the symbol column and the value column in each row.
// Shows a tiny 72×36 trend line. Three states:
//   1. null sparklineCandles  → invisible placeholder (loading)
//   2. empty sparklineCandles → nothing rendered (data unavailable)
//   3. candles present        → sparkline drawn

class _SparklineWidget extends StatelessWidget {
  final LiveHolding liveHolding;
  const _SparklineWidget({required this.liveHolding});

  @override
  Widget build(BuildContext context) {
    final candles = liveHolding.sparklineCandles;

    // Not yet fetched — show faint shimmer placeholder
    if (candles == null) {
      return SizedBox(
        width: 72,
        height: 36,
        child: Opacity(
          opacity: 0.15,
          child: Container(
            decoration: BoxDecoration(
              color: DesignTokens.textMediumContrast,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
    }

    // Fetched but empty — render nothing, don't take space
    if (candles.isEmpty) {
      return const SizedBox(width: 72, height: 36);
    }

    final closes = candles.map((c) => c.close).toList();
    final isProfit = liveHolding.hasPriceData
        ? liveHolding.isProfit
        : (closes.last >= closes.first);

    return SizedBox(
      width: 72,
      height: 36,
      child: CustomPaint(
        painter: _SparklinePainter(
          closes: closes,
          isProfit: isProfit,
          avgCost: liveHolding.holding.averagePrice,
        ),
      ),
    );
  }
}

// ─── P&L Chip ─────────────────────────────────────────────────────────────────

class _PnLChip extends StatelessWidget {
  final String label;
  final bool isProfit;
  final bool large;

  const _PnLChip(
      {required this.label,
      required this.isProfit,
      required this.large});

  @override
  Widget build(BuildContext context) {
    if (label == '--') {
      return Text('--',
          style: TextStyle(
            color:
                DesignTokens.textMediumContrast.withValues(alpha: 0.4),
            fontSize: large ? 13 : 11,
          ));
    }

    final color =
        isProfit ? DesignTokens.obsidianTeal : DesignTokens.crimsonWarning;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 8, vertical: large ? 5 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(large ? 10 : 8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isProfit
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: large ? 12 : 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: large ? 12 : 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              )),
        ],
      ),
    );
  }
}

// ─── Sector Tag ───────────────────────────────────────────────────────────────

class _SectorTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SectorTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
    );
  }
}

// ─── Sort Bottom Sheet ────────────────────────────────────────────────────────

class _SortBottomSheet extends StatelessWidget {
  final HoldingSort current;
  final ValueChanged<HoldingSort> onSelected;

  const _SortBottomSheet(
      {required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const options = [
      (HoldingSort.returnPct, 'Return %', 'Highest percentage gain first',
          Icons.trending_up_rounded),
      (HoldingSort.pnlRupee, 'P&L ₹', 'Highest rupee profit first',
          Icons.currency_rupee_rounded),
      (HoldingSort.invested, 'Invested', 'Largest investment first',
          Icons.account_balance_wallet_outlined),
      (HoldingSort.name, 'Name', 'Alphabetical order',
          Icons.sort_by_alpha_rounded),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort Holdings',
                style:
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final (sort, label, subtitle, icon) = opt;
              final isSelected = current == sort;
              return GestureDetector(
                onTap: () => onSelected(sort),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesignTokens.obsidianTeal
                            .withValues(alpha: 0.08)
                        : DesignTokens.graphiteBase,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? DesignTokens.obsidianTeal
                              .withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon,
                          size: 20,
                          color: isSelected
                              ? DesignTokens.obsidianTeal
                              : DesignTokens.textMediumContrast),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                  color: isSelected
                                      ? DesignTokens.textHighContrast
                                      : DesignTokens.textMediumContrast,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                )),
                            Text(subtitle,
                                style: TextStyle(
                                  color: DesignTokens.textMediumContrast
                                      .withValues(alpha: 0.5),
                                  fontSize: 11,
                                )),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            size: 18,
                            color: DesignTokens.obsidianTeal),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}