import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/design_tokens.dart';
import '../../core/intelligence/news/yahoo_historical_service.dart';

/// Top-level entry point. Parses a model response and renders
/// text blocks, tables, stat cards, and ranked lists natively.
class MessageRenderer extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const MessageRenderer({
    super.key,
    required this.text,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final blocks = _ResponseParser.parse(text);
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((b) => _renderBlock(context, b)).toList(),
    );
  }

  Widget _renderBlock(BuildContext context, _Block block) {
    switch (block.type) {
      case _BlockType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichText(context, block.content),
        );
      case _BlockType.table:
        return _TableWidget(rows: block.rows);
      case _BlockType.statCard:
        return _StatCardWidget(label: block.label, value: block.value);
      case _BlockType.rankedList:
        return _RankedListWidget(items: block.items);
      case _BlockType.chart:
        return _ChartWidget(chartType: block.chartType, rows: block.rows);
      case _BlockType.insightCard:
        return _InsightCardWidget(title: block.title, content: block.content);
      case _BlockType.timeline:
        return _TimelineWidget(rows: block.rows);
      case _BlockType.warningBox:
        return _WarningBoxWidget(content: block.content);
    }
  }

  /// Builds a RichText widget that renders **bold** markers with accent color
  /// and handles • bullet formatting.
  Widget _buildRichText(BuildContext context, String text) {
    final baseStyle = textStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DesignTokens.textHighContrast,
              height: 1.65,
            ) ??
        const TextStyle(color: Colors.white, height: 1.65);

    final boldStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: DesignTokens.obsidianTeal,
    );

    // Parse **bold** segments
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add normal text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      // Add bold text
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      lastEnd = match.end;
    }

    // Add remaining normal text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    // If no bold markers found, fall back to plain text
    if (spans.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Parser ───────────────────────────────────────────────────────────────────

enum _BlockType { text, table, statCard, rankedList, chart, insightCard, timeline, warningBox }

class _Block {
  final _BlockType type;
  final String content;
  final List<String> rows;
  final String label;
  final String value;
  final List<_RankedItem> items;
  final String chartType;
  final String title;

  const _Block.text(this.content)
      : type = _BlockType.text,
        rows = const [],
        label = '',
        value = '',
        items = const [],
        chartType = '',
        title = '';

  const _Block.table(this.rows)
      : type = _BlockType.table,
        content = '',
        label = '',
        value = '',
        items = const [],
        chartType = '',
        title = '';

  // ignore: unused_element
  const _Block.statCard(this.label, this.value)
      : type = _BlockType.statCard,
        content = '',
        rows = const [],
        items = const [],
        chartType = '',
        title = '';

  const _Block.rankedList(this.items)
      : type = _BlockType.rankedList,
        content = '',
        rows = const [],
        label = '',
        value = '',
        chartType = '',
        title = '';

  const _Block.chart(this.chartType, this.rows)
      : type = _BlockType.chart,
        content = '',
        label = '',
        value = '',
        items = const [],
        title = '';

  const _Block.insightCard(this.title, this.content)
      : type = _BlockType.insightCard,
        rows = const [],
        label = '',
        value = '',
        items = const [],
        chartType = '';

  const _Block.timeline(this.rows)
      : type = _BlockType.timeline,
        content = '',
        label = '',
        value = '',
        items = const [],
        chartType = '',
        title = '';

  const _Block.warningBox(this.content)
      : type = _BlockType.warningBox,
        rows = const [],
        label = '',
        value = '',
        items = const [],
        chartType = '',
        title = '';
}

class _RankedItem {
  final int rank;
  final String symbol;
  final String metric;
  final bool isPositive;
  final double? magnitude;

  const _RankedItem({
    required this.rank,
    required this.symbol,
    required this.metric,
    required this.isPositive,
    this.magnitude,
  });
}

class _ResponseParser {
  static List<_Block> parse(String raw) {
    String normalised = raw
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', ' ')
        .trim();

    // Preserve **bold** markers for rich text rendering
    // Only strip single-star italic markers
    normalised = normalised.replaceAllMapped(
        RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'), (m) => m.group(1) ?? '');
    normalised = normalised.replaceAll(r'$1', '');

    normalised = normalised.split('\n').where((line) {
      final t = line.trim();
      return !RegExp(r'^`{3}[a-zA-Z]*$').hasMatch(t);
    }).join('\n');

    final blocks = <_Block>[];
    final lines = normalised.split('\n');
    final textBuffer = StringBuffer();
    
    List<String>? listRows;
    StringBuffer? specialBuffer;
    
    bool inTable = false;
    bool inMarkdownTable = false;
    bool inChart = false;
    bool inCard = false;
    bool inTimeline = false;
    bool inWarning = false;
    
    String currentChartType = '';
    String currentCardTitle = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // 1. END markers
      if (line == 'END_TABLE') {
        if (listRows != null && listRows.isNotEmpty) blocks.add(_Block.table(listRows));
        listRows = null; inTable = false; continue;
      }
      if (line == 'END_CHART') {
        if (listRows != null && listRows.isNotEmpty) blocks.add(_Block.chart(currentChartType, listRows));
        listRows = null; inChart = false; continue;
      }
      if (line == 'END_CARD') {
        if (specialBuffer != null) blocks.add(_Block.insightCard(currentCardTitle, specialBuffer.toString().trim()));
        specialBuffer = null; inCard = false; continue;
      }
      if (line == 'END_TIMELINE') {
        if (listRows != null && listRows.isNotEmpty) blocks.add(_Block.timeline(listRows));
        listRows = null; inTimeline = false; continue;
      }
      if (line == 'END_WARNING') {
        if (specialBuffer != null) blocks.add(_Block.warningBox(specialBuffer.toString().trim()));
        specialBuffer = null; inWarning = false; continue;
      }

      // 2. BEGIN markers
      if (line == 'TABLE:') {
        _flushText(textBuffer, blocks);
        listRows = []; inTable = true; continue;
      }
      if (line.startsWith('CHART:')) {
        _flushText(textBuffer, blocks);
        currentChartType = line.substring(6).replaceAll(':', '').trim();
        listRows = []; inChart = true; continue;
      }
      if (line.startsWith('CARD:')) {
        _flushText(textBuffer, blocks);
        currentCardTitle = line.substring(5).trim();
        specialBuffer = StringBuffer(); inCard = true; continue;
      }
      if (line == 'TIMELINE:') {
        _flushText(textBuffer, blocks);
        listRows = []; inTimeline = true; continue;
      }
      if (line == 'WARNING:') {
        _flushText(textBuffer, blocks);
        specialBuffer = StringBuffer(); inWarning = true; continue;
      }

      // 3. Collect State Data
      if (inTable || inChart || inTimeline) {
        if (line.isNotEmpty) listRows!.add(line);
        continue;
      }
      if (inCard || inWarning) {
        if (line.isNotEmpty) specialBuffer!.writeln(line);
        continue;
      }

      // 4. Markdown Table fallback
      final segments = line.split('|');
      final nonEmptySegments = segments.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final isPipeLine = nonEmptySegments.length >= 2 && (line.startsWith('|') || line.endsWith('|') || segments.length >= 3);
      final isSeparator = line.contains('-') && RegExp(r'^[\|\-\s:]+$').hasMatch(line) && line.contains('|');

      if (isSeparator) continue;

      if (isPipeLine) {
        if (!inMarkdownTable) {
          _flushText(textBuffer, blocks);
          listRows = [];
          inMarkdownTable = true;
        }
        final stripped = line.replaceAll(RegExp(r'^\|'), '').replaceAll(RegExp(r'\|$'), '');
        final normalRow = stripped.replaceAll(RegExp(r'\|\s*\|'), '|—|');
        if (normalRow.trim().isNotEmpty) listRows!.add(normalRow);
        continue;
      }

      if (inMarkdownTable && !isPipeLine) {
        if (listRows != null && listRows.isNotEmpty) blocks.add(_Block.table(listRows));
        listRows = null;
        inMarkdownTable = false;
      }

      textBuffer.writeln(line);
    }

    // Flush any open blocks
    if ((inTable || inMarkdownTable) && listRows != null && listRows.isNotEmpty) blocks.add(_Block.table(listRows));
    if (inChart && listRows != null && listRows.isNotEmpty) blocks.add(_Block.chart(currentChartType, listRows));
    if (inTimeline && listRows != null && listRows.isNotEmpty) blocks.add(_Block.timeline(listRows));
    if (inCard && specialBuffer != null) blocks.add(_Block.insightCard(currentCardTitle, specialBuffer.toString().trim()));
    if (inWarning && specialBuffer != null) blocks.add(_Block.warningBox(specialBuffer.toString().trim()));
    
    _flushText(textBuffer, blocks);

    return _detectSpecialBlocks(blocks);
  }

  static void _flushText(StringBuffer buffer, List<_Block> blocks) {
    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      blocks.add(_Block.text(text));
    }
    buffer.clear();
  }

  static List<_Block> _detectSpecialBlocks(List<_Block> blocks) {
    final result = <_Block>[];
    for (final block in blocks) {
      if (block.type != _BlockType.text) {
        result.add(block);
        continue;
      }
      final ranked = _tryParseRankedList(block.content);
      if (ranked != null) {
        result.add(ranked);
        continue;
      }
      result.add(block);
    }
    return result;
  }

  static _Block? _tryParseRankedList(String text) {
    // Component 7: Opt-in only ranked list. Only parse if explicitly marked by the engine.
    if (!text.trimLeft().startsWith('RANKED:')) return null;
    
    // Remote the RANKED: marker
    final cleanText = text.replaceFirst('RANKED:', '').trim();

    final lines = cleanText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length < 2) return null;

    final rankPattern = RegExp(
      r'^(\d+)[.)]\s+([A-Z]{1,10})[\s\-:]+(.+)$',
      caseSensitive: false,
    );

    final items = <_RankedItem>[];

    // ── FIX 9: Don't break on first non-match — skip non-matching lines ─────
    // OLD: used `break` which dropped everything after a non-matching line.
    // NEW: use `continue` so stray lines (like a header sentence) are skipped.
    for (final line in lines) {
      final match = rankPattern.firstMatch(line);
      if (match == null) continue; // skip, don't break

      final rank = int.tryParse(match.group(1)!) ?? items.length + 1;
      final symbol = match.group(2)!.toUpperCase();
      final metric = match.group(3)!.trim();

      final isPositive = !metric.startsWith('-');
      double? magnitude;
      final pctMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(metric);
      if (pctMatch != null) {
        final pct = double.tryParse(pctMatch.group(1)!) ?? 0;
        magnitude = (pct / 50).clamp(0.0, 1.0);
      }

      items.add(_RankedItem(
        rank: rank,
        symbol: symbol,
        metric: metric,
        isPositive: isPositive,
        magnitude: magnitude,
      ));
    }

    if (items.length >= 2) return _Block.rankedList(items);
    return null;
  }
}

// ─── Table Widget ─────────────────────────────────────────────────────────────

class _TableWidget extends StatelessWidget {
  final List<String> rows;
  const _TableWidget({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final headers = rows.first
        .split('|')
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();

    if (headers.isEmpty) return const SizedBox.shrink();

    final dataRows = rows.skip(1).map((r) {
      final cells = r.split('|').map((c) => c.trim()).toList();
      while (cells.length < headers.length) {
        cells.add('—');
      }
      return cells.take(headers.length).toList();
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(headers),
              Container(
                height: 1,
                color: DesignTokens.obsidianTeal.withValues(alpha: 0.35),
              ),
              ...dataRows.asMap().entries.map((entry) {
                final isLast = entry.key == dataRows.length - 1;
                return Column(
                  children: [
                    _buildDataRow(entry.value, entry.key),
                    if (!isLast)
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<String> headers) {
    return Container(
      color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
      child: IntrinsicHeight(
        child: Row(
          children: headers.asMap().entries.map((entry) {
            return _buildCell(
              text: entry.value,
              isHeader: true,
              showRightBorder: entry.key < headers.length - 1,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataRow(List<String> cells, int rowIndex) {
    return Container(
      color: rowIndex.isOdd
          ? Colors.white.withValues(alpha: 0.015)
          : Colors.transparent,
      child: IntrinsicHeight(
        child: Row(
          children: cells.asMap().entries.map((entry) {
            final text = entry.value;
            final isPositive =
                text.contains('+') || (text.contains('%') && !text.contains('-'));
            final isNegative = text.startsWith('-') ||
                text.contains('-₹') ||
                text.contains('(-');
            return _buildCell(
              text: text,
              isHeader: false,
              showRightBorder: entry.key < cells.length - 1,
              valueColor: isPositive && !isNegative
                  ? const Color(0xFF4ECDC4)
                  : isNegative
                      ? const Color(0xFFFF6B6B)
                      : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCell({
    required String text,
    required bool isHeader,
    required bool showRightBorder,
    Color? valueColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: showRightBorder
            ? Border(
                right: BorderSide(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.2),
                ),
              )
            : null,
      ),
      child: _parseCellText(
        text,
        TextStyle(
          color: isHeader
              ? DesignTokens.obsidianTeal
              : valueColor ?? DesignTokens.textHighContrast,
          fontSize: isHeader ? 11 : 13,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: isHeader ? 0.8 : 0,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _parseCellText(String text, TextStyle baseStyle) {
    if (!text.contains('**')) return Text(text, style: baseStyle);

    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w800);
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Stat Card Widget ─────────────────────────────────────────────────────────

class _StatCardWidget extends StatelessWidget {
  final String label;
  final String value;
  const _StatCardWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isPositive =
        value.contains('+') || (!value.contains('-') && value.contains('%'));
    final isNegative = value.startsWith('-');

    final valueColor = isPositive && !isNegative
        ? const Color(0xFF4ECDC4)
        : isNegative
            ? const Color(0xFFFF6B6B)
            : DesignTokens.ashGold;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: valueColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: DesignTokens.textMediumContrast,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ranked List Widget ───────────────────────────────────────────────────────

class _RankedListWidget extends StatelessWidget {
  final List<_RankedItem> items;
  const _RankedListWidget({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: DesignTokens.obsidianTeal.withValues(alpha: 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;

          final barColor = item.isPositive
              ? const Color(0xFF4ECDC4)
              : const Color(0xFFFF6B6B);
          final metricColor = barColor;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    // Rank circle
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: item.rank == 1
                            ? DesignTokens.obsidianTeal.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.rank == 1
                              ? DesignTokens.obsidianTeal.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${item.rank}',
                          style: TextStyle(
                            color: item.rank == 1
                                ? DesignTokens.obsidianTeal
                                : DesignTokens.textMediumContrast,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Symbol
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.symbol,
                        style: TextStyle(
                          color: DesignTokens.textHighContrast,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Metric + bar
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.metric,
                            style: TextStyle(
                              color: metricColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.magnitude != null) ...[
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: item.magnitude!,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.06),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  barColor.withValues(alpha: 0.7),
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Chart Widget ─────────────────────────────────────────────────────────────

class _ChartWidget extends StatelessWidget {
  final String chartType;
  final List<String> rows;

  const _ChartWidget({required this.chartType, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Currently supporting custom Bar Chart natively for stability & aesthetics
    if (chartType == 'bar' || chartType == 'stacked_bar') {
      return _buildBarChart(context);
    }
    
    if (chartType == 'donut') {
      return _buildDonutChart(context);
    }

    if (chartType == 'line') {
      return _buildLineChart(context);
    }
    
    // For line/area/donut we render a stylized placeholder or simple representation
    // since building complex vector charts from scratch takes more space
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: DesignTokens.obsidianTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Data Visualisation (${chartType.toUpperCase()})',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) {
            final parts = row.split('|').map((s) => s.trim()).toList();
            if (parts.length < 2) return Text(row, style: TextStyle(color: Colors.white54, fontSize: 13));
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(parts[0], style: TextStyle(color: DesignTokens.textHighContrast, fontSize: 14)),
                  Text(parts[1], style: TextStyle(color: DesignTokens.textMediumContrast, fontSize: 13)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context) {
    // Parse rows to find max value for relative scaling
    final parsedRows = <_ChartRow>[];
    double maxVal = 0;
    for (final r in rows) {
      final parts = r.split('|').map((s) => s.trim()).toList();
      if (parts.length < 2) continue;
      final label = parts[0];
      final valStr = parts[1];
      
      // Extract number
      final numMatch = RegExp(r'-?\d+(\.\d+)?').firstMatch(valStr);
      double val = 0;
      if (numMatch != null) {
        val = double.tryParse(numMatch.group(0)!) ?? 0;
      }
      if (val.abs() > maxVal) maxVal = val.abs();
      
      parsedRows.add(_ChartRow(label, valStr, val));
    }

    if (maxVal == 0) maxVal = 1; // Prevent division by zero

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parsedRows.map((row) {
          final isPositive = row.value >= 0;
          final pct = (row.value.abs() / maxVal).clamp(0.0, 1.0);
          final barColor = isPositive ? const Color(0xFF4ECDC4) : const Color(0xFFFF6B6B);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: TextStyle(
                        color: DesignTokens.textHighContrast,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      row.displayValue,
                      style: TextStyle(
                        color: barColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 8,
                    color: Colors.white.withValues(alpha: 0.04),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDonutChart(BuildContext context) {
    final parsedRows = <_ChartRow>[];
    double total = 0;
    for (final r in rows) {
      final parts = r.split('|').map((s) => s.trim()).toList();
      if (parts.length < 2) continue;
      final label = parts[0];
      final valStr = parts[1];
      
      final numMatch = RegExp(r'-?\d+(\.\d+)?').firstMatch(valStr);
      double val = 0;
      if (numMatch != null) {
        val = double.tryParse(numMatch.group(0)!) ?? 0;
      }
      val = val.abs();
      total += val;
      if (val > 0) {
        parsedRows.add(_ChartRow(label, valStr, val));
      }
    }

    if (parsedRows.isEmpty || total == 0) return const SizedBox.shrink();

    parsedRows.sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      DesignTokens.obsidianTeal,
      DesignTokens.ashGold,
      const Color(0xFF6B4EE6), 
      const Color(0xFFE2A442), 
      const Color(0xFF00B4D8), 
      const Color(0xFFE63946), 
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 0,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: DesignTokens.obsidianTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Portfolio Composition',
                style: TextStyle(
                  color: DesignTokens.textMediumContrast,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  sections: parsedRows.map((e) => e.value).toList(),
                  colors: colors.take(parsedRows.length).toList(),
                  total: total,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(parsedRows.length, (index) {
            final row = parsedRows[index];
            final color = colors[index % colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                   Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        color: DesignTokens.textHighContrast,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    row.displayValue.contains('%') ? row.displayValue : '${row.displayValue}%',
                    style: TextStyle(
                      color: DesignTokens.textMediumContrast,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLineChart(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    // rows[0] should be "GOLDBEES,SILVERIETF|30" or "ITC.NS,HINDUNILVR.NS|30|Last 30 Days"
    final parts = rows[0].split('|');
    if (parts.length < 2) return const SizedBox.shrink();
    
    final symbols = parts[0].split(',').map((s) => s.trim()).toList();
    final rangeTag = parts[1].trim();
    final label = parts.length > 2 ? parts[2].trim() : 'Performance Comparison';

    return _LineChartWidget(symbols: symbols, rangeTag: rangeTag, label: label);
  }
}

// ─── Chart Data Wrapper ────────────────────────────────────────────────────────

class _ChartRow {
  final String label;
  final String displayValue;
  final double value;
  _ChartRow(this.label, this.displayValue, this.value);
}

// ─── Custom Painters ──────────────────────────────────────────────────────────

class _DonutChartPainter extends CustomPainter {
  final List<double> sections;
  final List<Color> colors;
  final double total;

  _DonutChartPainter({
    required this.sections,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0 || sections.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.4; 
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2; 

    for (int i = 0; i < sections.length; i++) {
      final sweepAngle = (sections[i] / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.05, 
        false,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return true; 
  }
}

// ─── Insight Card Widget ──────────────────────────────────────────────────────

class _InsightCardWidget extends StatelessWidget {
  final String title;
  final String content;

  const _InsightCardWidget({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414), // Slightly lighter dark
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.insights_rounded, color: DesignTokens.obsidianTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: DesignTokens.obsidianTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: DesignTokens.obsidianTeal.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
          ],
          Text(
            content,
            style: TextStyle(
              color: DesignTokens.textHighContrast,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Widget ──────────────────────────────────────────────────────────

class _TimelineWidget extends StatelessWidget {
  final List<String> rows;

  const _TimelineWidget({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isLast = i == rows.length - 1;
          
          final parts = r.split('|').map((s) => s.trim()).toList();
          final title = parts[0];
          final desc = parts.length > 1 ? parts.sublist(1).join(' - ') : null;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line and Node
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: DesignTokens.obsidianTeal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: DesignTokens.obsidianTeal.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: DesignTokens.textHighContrast,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (desc != null && desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: TextStyle(
                              color: DesignTokens.textMediumContrast,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Warning Box Widget ───────────────────────────────────────────────────────

class _WarningBoxWidget extends StatelessWidget {
  final String content;

  const _WarningBoxWidget({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1010), // Deep red tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFFF6B6B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                color: Color(0xFFFFECEC),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Line Chart Widget ────────────────────────────────────────────────────────

class _LineChartWidget extends StatefulWidget {
  final List<String> symbols;
  final String rangeTag;
  final String label;
  
  const _LineChartWidget({required this.symbols, required this.rangeTag, required this.label});

  @override
  State<_LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<_LineChartWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, List<({DateTime date, double price})>> _seriesData = {};
  
  final _colors = [
    DesignTokens.obsidianTeal, // Teal
    const Color(0xFFFF6B6B),   // Coral
    const Color(0xFFE2A442),   // Amber
    const Color(0xFF6B4EE6),   // Violet
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = <String, List<({DateTime date, double price})>>{};
      
      for (final rawSymbol in widget.symbols.take(4)) {
        final parts = rawSymbol.split('::');
        final yahooSymbol = parts[0];
        final displayName = parts.length > 1 ? parts[1] : yahooSymbol;

        final data = await YahooHistoricalService.fetchHistorical(yahooSymbol, widget.rangeTag);
        if (data.isNotEmpty) {
          results[displayName] = data.map((d) {
            return (date: d.date, price: d.close);
          }).toList();
        }
      }
      
      if (mounted) {
        setState(() {
          _seriesData = results;
          _isLoading = false;
          _hasError = results.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildContainer(
        Center(
          child: CircularProgressIndicator(
            color: DesignTokens.obsidianTeal,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_hasError) {
      return _buildContainer(
        const Center(
          child: Text(
            'Historical data unavailable.',
            style: TextStyle(color: Color(0xFF8E8E93)),
          ),
        ),
      );
    }

    return _buildContainer(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _LineChartPainter(
                    seriesData: _seriesData,
                    colors: _colors,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _seriesData.keys.toList().asMap().entries.map((entry) {
              final color = _colors[entry.key % _colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  )
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContainer(Widget child) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.obsidianTeal.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.obsidianTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 0,
          )
        ],
      ),
      child: child,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final Map<String, List<({DateTime date, double price})>> seriesData;
  final List<Color> colors;

  _LineChartPainter({required this.seriesData, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (seriesData.isEmpty) return;

    double minV = double.infinity;
    double maxV = double.negativeInfinity;
    int maxPts = 0;

    for (final series in seriesData.values) {
      if (series.length > maxPts) maxPts = series.length;
      for (final pt in series) {
        if (pt.price < minV) minV = pt.price;
        if (pt.price > maxV) maxV = pt.price;
      }
    }

    if (minV == double.infinity) return;

    // Expand bounds slightly
    final range = maxV - minV;
    final padding = range == 0 ? 5.0 : range * 0.1;
    minV -= padding;
    maxV += padding;

    final drawRect = Rect.fromLTWH(0, 0, size.width - 40, size.height - 20);

    // Grid details
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final zeroPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw grid
    final steps = 4;
    for (int i = 0; i <= steps; i++) {
      final y = drawRect.bottom - (i / steps) * drawRect.height;
      final val = minV + (i / steps) * (maxV - minV);
      
      canvas.drawLine(Offset(drawRect.left, y), Offset(drawRect.right + 35, y),
          val.abs() < 0.1 ? zeroPaint : gridPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '₹${val.toStringAsFixed(1)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(drawRect.right + 5, y - 6));
    }

    // Draw series
    final symbols = seriesData.keys.toList();
    for (int s = 0; s < symbols.length; s++) {
      final series = seriesData[symbols[s]]!;
      if (series.length < 2) continue;

      final color = colors[s % colors.length];
      final path = Path();

      for (int i = 0; i < series.length; i++) {
        final pt = series[i];
        final x = drawRect.left + (i / (series.length - 1)) * drawRect.width;
        final y = drawRect.bottom - ((pt.price - minV) / (maxV - minV)) * drawRect.height;
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}