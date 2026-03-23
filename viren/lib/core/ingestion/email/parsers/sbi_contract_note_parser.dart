import 'dart:developer' as developer;
import '../../../database/enums.dart';
import '../../../market/nse_calendar.dart';
import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SbiContractNoteParser v2 — CNB-primary, all fields extracted
//
// Extraction order:
//   1. Parse header → trade date (authoritative), contract note no,
//      settlement date
//   2. Parse Annexure B → per-scrip charges keyed by ISIN
//   3. Parse Annexure A → trades with Trade No, ISIN, time, price, qty
//   4. Join A + B on ISIN → complete trade with exact charges
//   5. Dedup: rawTradeNo (Trade No) is the unique NSE execution identifier
// ─────────────────────────────────────────────────────────────────────────────

class SbiContractNoteParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.sbiContractNote;

  // ── Known ISIN → NSE Symbol map (top 100 Indian ETFs & stocks) ────────────
  // Source: NSE instrument master. Update annually.
  // If ISIN not found here, symbol is derived from description.
  static const Map<String, String> _isinToSymbol = {
    // ── EXISTING ENTRIES (keep all) ──
    'INF204KB17I5': 'GOLDBEES',
    'INF204KB14I2': 'NIFTYBEES',
    'INF109KC1Y56': 'ICICISILVE',
    'INF204KB19I1': 'LIQUIDBEES',
    'INF460K01257': 'JUNIORBEES',
    'INF200K01TA2': 'SETFNIF50',
    'INF082J01034': 'BANKBEES',
    'INF847K01TP2': 'MOM100',
    'INF204KB10I0': 'SETFGOLD',
    'INF200K01RB8': 'SETFGOLD',
    'INF204KB16I7': 'SILVERIETF',
    'INF109KC1Z21': 'SILVRETF',
    'INF789F01010': 'MON100',
    'INE009A01021': 'INFY',
    'INE467B01029': 'TCS',
    'INE040A01034': 'HDFCBANK',
    'INE090A01021': 'ICICIBANK',
    'INE238A01034': 'AXISBANK',
    'INE669E01016': 'YESBANK',
    'INE002A01018': 'RELIANCE',
    'INE030A01027': 'ITC',
    'INE101A01026': 'COALINDIA',
    'INE585B01010': 'SBIN',
    'INE028A01039': 'ONGC',
    'INE018A01030': 'HCLTECH',
    'INE397D01024': 'BAJFINANCE',
    'INE414G01012': 'SUNPHARMA',
    'INE176A01028': 'WIPRO',
    'INE081A01012': 'TITAN',
    'INE213A01029': 'NESTLEIND',

    // ── CRITICAL MISSING ENTRIES ──
    'INE528G01035': 'YESBANK',      // ← YES BANK LIMITED (was causing BANKLIMITED)
    'INE528G01019': 'YESBANK',      // ← alternate ISIN (post-reconstruction)
    'INF846K01EW2': 'SILVERIETF',   // Mirae Silver ETF
  };

  @override
  EmailParseResult parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  }) {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];

    final normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalized.isEmpty) {
      errors.add('Empty CNB PDF: $filename');
      return EmailParseResult(
        messageId: 'DOCUMENT_PARSER_DELEGATE',
        aggregateConfidence: 0,
        warnings: warnings,
        errors: errors,
      );
    }

    // MANDATORY: Log first 1000 chars of normalized text
    // This tells us exactly what the parser sees
    developer.log(
      '[SBI_CN_DEBUG] === PARSING $filename ===\n'
      'Text length: ${normalized.length} chars\n'
      'First 500 chars:\n${normalized.substring(0, normalized.length.clamp(0, 500))}',
      name: 'SbiContractNoteParser',
    );

    // ── Step 1: Extract Header Fields ──────────────────────────────────────

    // Trade Date — the authoritative date. Format: 20-MAR-26 or 20-MAR-2026
    DateTime tradeDate = emailDate; // fallback only
    bool tradeDateFromPdf = false;

    final tradeDateRegex = RegExp(
      r'TRADE\s+DATE\s+(\d{1,2}[-/](?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[-/]\d{2,4})',
      caseSensitive: false,
    );
    final tradeDateMatch = tradeDateRegex.firstMatch(normalized);
    if (tradeDateMatch != null) {
      final parsed = _parseNseDate(tradeDateMatch.group(1)!);
      if (parsed != null) {
        tradeDate = parsed;
        if (!NseCalendar.isMarketDay(tradeDate)) {
          // If headers state a non-market day (e.g., Saturday), it's a typo.
          tradeDate = NseCalendar.nearestTradingDay(tradeDate);
        }
        tradeDateFromPdf = true;
      }
    }

    if (!tradeDateFromPdf) {
      warnings.add('Could not extract trade date from PDF header — using email date as fallback for $filename');
    }

    // Settlement Date
    DateTime? settlementDate;
    final settlementRegex = RegExp(
      r'SETTLEMENT\s+DATE\s+(\d{1,2}[-/](?:JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[-/]\d{2,4})',
      caseSensitive: false,
    );
    final settlementMatch = settlementRegex.firstMatch(normalized);
    if (settlementMatch != null) {
      settlementDate = _parseNseDate(settlementMatch.group(1)!);
    }

    // Contract Note Number (for sourceReference)
    String? contractNoteNo;
    final cnNoRegex = RegExp(r'CONTRACT\s+NOTE\s+NO\.?\s+(\d{10,15})', caseSensitive: false);
    final cnNoMatch = cnNoRegex.firstMatch(normalized);
    if (cnNoMatch != null) {
      contractNoteNo = cnNoMatch.group(1);
    }

    developer.log(
      '[SBI_CN_DEBUG] Trade date: $tradeDate (fromPdf=$tradeDateFromPdf)\n'
      'Settlement: $settlementDate\n'
      'Contract note: $contractNoteNo',
      name: 'SbiContractNoteParser',
    );

    // ── Step 2: Parse Annexure B — per-scrip exact charges ─────────────────
    // Annexure B: SecurityDesc-Cash-ISIN BoughtQty SoldQty AvgRate GrossTotal
    //             Brokerage NetBeforeLevies GST STT OtherLevies NetAfterLevies
    //
    // Key: ISIN → charges map

    final Map<String, _ScripCharges> chargesByIsin = {};

    final annexureBPattern = RegExp(
      r'(.+?)-Cash-(IN[A-Z0-9]{10})\s+'    // description + ISIN
      r'(\d+)\s+(\d+)\s+'                  // bought qty, sold qty
      r'([\d.]+)\s+([\d.]+)\s+'            // avg rate, gross total
      r'([\d.]+)\s+([\d.]+)\s+'            // brokerage, net before levies
      r'([\d.]+)\s+([\d.]+)\s+'            // GST, STT
      r'([\d.]+)\s+([\d.]+)',              // other levies, net after levies
      caseSensitive: true,
    );

    for (final match in annexureBPattern.allMatches(normalized)) {
      try {
        final isin = match.group(2)!;
        final brokerage = double.parse(match.group(7)!);
        final gst = double.parse(match.group(9)!);
        final stt = double.parse(match.group(10)!);
        final other = double.parse(match.group(11)!);
        final netAfterLevies = double.parse(match.group(12)!);

        chargesByIsin[isin] = _ScripCharges(
          brokerage: brokerage,
          gst: gst,
          stt: stt,
          otherLevies: other,
          netAfterLevies: netAfterLevies,
        );

        developer.log(
          '[SBI_CN_V2] Annexure B: ISIN=$isin brokerage=$brokerage '
          'gst=$gst stt=$stt other=$other net=$netAfterLevies',
          name: 'SbiContractNoteParser',
        );
      } catch (e) {
        warnings.add('Annexure B parse error: $e');
      }
    }
    
    // If Annexure B regex found 0 entries, try simpler pattern
    if (chargesByIsin.isEmpty) {
      developer.log(
        '[SBI_CN] Standard Annexure B found 0 entries. '
        'Trying old ISIN-first format (pre-2026)...',
        name: 'SbiContractNoteParser',
      );

      final oldFormatBPattern = RegExp(
        r'(IN[A-Z0-9]{10})\s+'    // ISIN (group 1)
        r'[\w\s\-\.]+?\s+'         // Security name (skip)
        r'([\d.]+)\s+'             // Bought qty (group 2)
        r'[\d.]+\s+'               // WAP (skip)
        r'([\d.]+)\s+'             // Brokerage per share (group 3)
        r'[\d.]+\s+'               // WAP after brokerage (skip)
        r'([\d.]+)',               // Total BUY value (group 4)
        caseSensitive: true,
      );

      for (final match in oldFormatBPattern.allMatches(normalized)) {
        try {
          final isin = match.group(1)!;
          // Skip if this ISIN is a header/footer row (too many false positives)
          if (!_isinToSymbol.containsKey(isin) && isin.length != 12) continue;

          final boughtQty = double.tryParse(match.group(2)!) ?? 0;
          if (boughtQty <= 0) continue; // SELL-only row — skip for now

          final brokeragePerShare = double.tryParse(match.group(3)!) ?? 0;
          final totalBuyValue = double.tryParse(match.group(4)!) ?? 0;
          final totalBrokerage = brokeragePerShare * boughtQty;

          // For old format, we don't have individual STT/GST/other per scrip
          // Extract from page 3 obligation table (global) and apportion
          chargesByIsin[isin] = _ScripCharges(
            brokerage: totalBrokerage,
            gst: 0.0,    // will be apportioned from global below
            stt: 0.0,    // will be apportioned from global below
            otherLevies: 0.0,
            netAfterLevies: totalBuyValue + totalBrokerage, // approximate
          );

          developer.log(
            '[SBI_CN_OLDFMT_B] ISIN=$isin qty=$boughtQty '
            'brok=$totalBrokerage totalValue=$totalBuyValue',
            name: 'SbiContractNoteParser',
          );
        } catch (e) {
          warnings.add('Old format Annexure B row error: $e');
        }
      }

      // If we found charges in old format, apportion global STT/GST
      if (chargesByIsin.isNotEmpty) {
        // Extract global STT from page 3 obligation table
        final globalStt = _extractGlobalAmount(normalized,
            r'Securities Transaction Tax[^0-9]+([\d,]+\.\d+)');
        final globalGst = _extractGlobalAmount(normalized,
            r'(?:CGST|SGST|IGST)[^0-9]+([\d,]+\.\d+)') * 2; // CGST+SGST
        final totalTradeValue = chargesByIsin.values
            .fold(0.0, (sum, c) => sum + c.netAfterLevies);

        // Apportion global charges proportionally
        final updatedCharges = <String, _ScripCharges>{};
        for (final entry in chargesByIsin.entries) {
          final proportion = totalTradeValue > 0
              ? entry.value.netAfterLevies / totalTradeValue
              : 1.0 / chargesByIsin.length;
          updatedCharges[entry.key] = _ScripCharges(
            brokerage: entry.value.brokerage,
            gst: globalGst * proportion,
            stt: globalStt * proportion,
            otherLevies: entry.value.otherLevies,
            netAfterLevies: entry.value.netAfterLevies +
                (globalStt * proportion) +
                (globalGst * proportion),
          );
        }
        chargesByIsin.clear();
        chargesByIsin.addAll(updatedCharges);
      }
    } else {
      developer.log(
        '[SBI_CN_DEBUG] Annexure B: ${chargesByIsin.length} scrips found\n'
        '${chargesByIsin.entries.map((e) => '  ${e.key}: brok=${e.value.brokerage}').join('\n')}',
        name: 'SbiContractNoteParser',
      );
    }

    // ── Step 3: Parse Annexure A with multiple format patterns ─────────

    // FORMAT V2 (2026): Order No + Trade No explicitly separated
    // 1300000022891224 10:15:05 02092971 10:15:05 ICICIPRAMC-Cash-INF109KC1Y56 B 4 233.52
    final annexureAV2 = RegExp(
      r'(\d{13,18})\s+'
      r'(\d{2}:\d{2}:\d{2})\s+'
      r'(\d{6,10})\s+'
      r'(\d{2}:\d{2}:\d{2})\s+'
      r'([\w\s\-\.]+?)'
      r'-Cash-(IN[A-Z0-9]{10})\s+'
      r'(B|S)\s+'
      r'(\d+)\s+'
      r'([\d.]+)',
      caseSensitive: true,
    );

    // FORMAT V1 (2025 and earlier): Simpler table structure
    // Some older SBI CNBs don't have separate Trade No column
    // or use different spacing. Match on ISIN + B/S + qty + price
    final annexureAV1 = RegExp(
      r'(IN[A-Z0-9]{10})\s+'
      r'(B|S)\s+'
      r'(\d+)\s+'
      r'([\d.]+(?:\.\d{2})?)',
      caseSensitive: true,
    );



    int rowsDetected = 0;
    int rowsParsed = 0;
    int rowsRejected = 0;

    // Find where trade summary starts to narrow the Annexure A search
    final tradeHeaderIdx = normalized.indexOf('Trade wise summary');
    final annexureAStartIdx = normalized.contains('ANNEXURE A')
        ? normalized.indexOf('ANNEXURE A')
        : (tradeHeaderIdx > 0 ? tradeHeaderIdx : 0);

    // Only search for trade rows AFTER the header
    final annexureAText = annexureAStartIdx > 0
        ? normalized.substring(annexureAStartIdx)
        : normalized;

    // Try V2 first (most specific)
    var matches = annexureAV2.allMatches(annexureAText).toList();
    String formatUsed = 'V2';

    // If V2 found 0 trades, try V1
    if (matches.isEmpty) {
      developer.log(
        '[SBI_CN] V2 regex found 0 matches. Trying V1...',
        name: 'SbiContractNoteParser',
      );

      // V1 matches: filter to only ISINs that appear in Annexure B
      // (prevents matching random numbers in the document)
      final v1Matches = annexureAV1.allMatches(normalized)
          .where((m) {
            final isin = m.group(1)!;
            // Must be a known ISIN (in map or in Annexure B charges)
            return _isinToSymbol.containsKey(isin) ||
                   chargesByIsin.containsKey(isin);
          })
          .toList();

      if (v1Matches.isNotEmpty) {
        formatUsed = 'V1';
        // Convert V1 matches to same processing loop below
        for (final match in v1Matches) {
          rowsDetected++;
          try {
            final isin = match.group(1)!;
            final side = match.group(2)!;
            final qty = double.parse(match.group(3)!);
            final price = double.parse(match.group(4)!);
            final symbol = _isinToSymbol[isin] ?? _symbolFromDescription(isin);
            if (!_isValidNseSymbol(symbol)) {
              rowsRejected++;
              warnings.add('Rejected invalid symbol "$symbol" (ISIN: $isin). Skipping.');
              continue;
            }
            final charges = chargesByIsin[isin];
            final brokerage = charges?.brokerage ?? 0.0;
            final gst = charges?.gst ?? 0.0;
            final stt = charges?.stt ?? 0.0;
            final otherLevies = charges?.otherLevies ?? 0.0;
            final netAmount = charges?.netAfterLevies ?? (qty * price);
            final totalCharges = brokerage + gst + stt + otherLevies;
            final trueCostBasis = qty > 0
                ? ((qty * price) + totalCharges) / qty
                : price;
            trades.add(EmailParsedTrade(
              symbol: symbol,
              instrumentName: symbol,
              exchange: 'NSE',
              tradeType: side == 'B' ? TradeType.buy : TradeType.sell,
              quantity: qty,
              pricePerUnit: price,
              tradeDate: tradeDate,
              broker: 'SBI Securities',
              confidence: tradeDateFromPdf ? 80 : 65,
              sourceMessageHash: attachmentHash,
              source: TradeSource.sbiContractNote,
              brokerage: brokerage,
              stt: stt,
              gst: gst,
              otherLevies: otherLevies,
              netAmountAfterLevies: netAmount,
              trueCostBasis: trueCostBasis,
              warnings: ['Parsed via V1 format (older CNB)'],
            ));
            rowsParsed++;
          } catch (e) {
            rowsRejected++;
            warnings.add('V1 row error: $e');
          }
        }
      }
    } else {
      // Process V2 matches (existing logic)
      for (final match in matches) {
        rowsDetected++;
        try {
          final tradeNo = match.group(3)!;
          final description = match.group(5)!.trim();
          final isin = match.group(6)!;
          final side = match.group(7)!;
          final qty = double.parse(match.group(8)!);
          // Skip rows where qty = 0 or qty looks like a year/timestamp artifact
          if (qty <= 0 || qty > 100000) {
            rowsRejected++;
            continue;
          }

          final price = double.parse(match.group(9)!);
          // Skip implausible prices (< ₹0.01 or > ₹1,000,000)
          if (price < 0.01 || price > 1000000) {
            rowsRejected++;
            continue;
          }

          final tradeType = side == 'B' ? TradeType.buy : TradeType.sell;
          final symbol = _isinToSymbol[isin] ?? _symbolFromDescription(description);

          if (!_isValidNseSymbol(symbol)) {
            rowsRejected++;
            warnings.add(
              'Rejected invalid symbol "$symbol" from description '
              '"$description" (ISIN: $isin). Skipping this row.',
            );
            continue;
          }

          final charges = chargesByIsin[isin];
          final brokerage = charges?.brokerage ?? 0.0;
          final gst = charges?.gst ?? 0.0;
          final stt = charges?.stt ?? 0.0;
          final otherLevies = charges?.otherLevies ?? 0.0;
          final netAmount = charges?.netAfterLevies ?? (qty * price);
          final totalCharges = brokerage + gst + stt + otherLevies;
          final trueCostBasis = qty > 0
              ? ((qty * price) + totalCharges) / qty
              : price;

          trades.add(EmailParsedTrade(
            symbol: symbol,
            instrumentName: description,
            exchange: 'NSE',
            tradeType: tradeType,
            quantity: qty,
            pricePerUnit: price,
            tradeDate: tradeDate,
            broker: 'SBI Securities',
            confidence: tradeDateFromPdf ? 97 : 80,
            sourceMessageHash: attachmentHash,
            tradeNo: tradeNo,
            source: TradeSource.sbiContractNote,
            brokerage: brokerage,
            stt: stt,
            gst: gst,
            otherLevies: otherLevies,
            netAmountAfterLevies: netAmount,
            trueCostBasis: trueCostBasis,
            warnings: [
              if (!tradeDateFromPdf) 'Trade date from email (PDF parse failed)',
              if (charges == null) 'Charges not found for $isin',
              'TradeNo: $tradeNo | ISIN: $isin',
            ],
          ));
          rowsParsed++;

          developer.log(
            '[SBI_CN_$formatUsed] $symbol ${side == 'B' ? 'BUY' : 'SELL'} '
            '$qty @ ₹$price | ISIN=$isin | Date=$tradeDate',
            name: 'SbiContractNoteParser',
          );
        } catch (e) {
          rowsRejected++;
          warnings.add('Row parse error: $e');
        }
      }
    }

    // ── Last resort: If ALL patterns found 0 trades but Annexure B has data ──
    // This handles completely unexpected formats — at least insert placeholder
    if (trades.isEmpty && chargesByIsin.isNotEmpty) {
      developer.log(
        '[SBI_CN] ALL regex patterns failed. Annexure B has '
        '${chargesByIsin.length} ISINs. Attempting ISIN-only extraction...',
        name: 'SbiContractNoteParser',
      );

      // Search for each known ISIN in the document and find qty+price near it
      for (final entry in chargesByIsin.entries) {
        final isin = entry.key;
        final charges = entry.value;
        final symbol = _isinToSymbol[isin];
        if (symbol == null) continue;
        if (!_isValidNseSymbol(symbol)) continue;

        // Find this ISIN in the text and extract qty/price from nearby context
        final isinIdx = normalized.indexOf(isin);
        if (isinIdx < 0) continue;

        // Look in a 200-char window after the ISIN
        final window = normalized.substring(
          isinIdx,
          (isinIdx + 200).clamp(0, normalized.length),
        );

        // Pattern: B/S qty price (common table format near ISIN)
        final nearbyPattern = RegExp(
          r'(B|S)\s+(\d+)\s+([\d.]+)',
          caseSensitive: true,
        );
        final nearbyMatch = nearbyPattern.firstMatch(window);
        if (nearbyMatch == null) continue;

        final side = nearbyMatch.group(1)!;
        final qty = double.tryParse(nearbyMatch.group(2)!);
        final price = double.tryParse(nearbyMatch.group(3)!);
        if (qty == null || price == null || qty <= 0 || price <= 0) continue;

        final totalCharges = charges.brokerage + charges.gst +
            charges.stt + charges.otherLevies;
        final trueCostBasis = ((qty * price) + totalCharges) / qty;

        trades.add(EmailParsedTrade(
          symbol: symbol,
          instrumentName: symbol,
          exchange: 'NSE',
          tradeType: side == 'B' ? TradeType.buy : TradeType.sell,
          quantity: qty,
          pricePerUnit: price,
          tradeDate: tradeDate,
          broker: 'SBI Securities',
          confidence: 70,
          sourceMessageHash: attachmentHash,
          source: TradeSource.sbiContractNote,
          brokerage: charges.brokerage,
          stt: charges.stt,
          gst: charges.gst,
          otherLevies: charges.otherLevies,
          netAmountAfterLevies: charges.netAfterLevies,
          trueCostBasis: trueCostBasis,
          warnings: ['Extracted via ISIN-only last-resort parser (confidence 70%)'],
        ));
        rowsParsed++;
        developer.log(
          '[SBI_CN_LASTRESORT] $symbol ${side == 'B' ? 'BUY' : 'SELL'} '
          '$qty @ ₹$price via ISIN-only fallback',
          name: 'SbiContractNoteParser',
        );
      }
    }

    // ── Step 4: Validation ──────────────────────────────────────────────────
    if (trades.isEmpty && normalized.contains('ANNEXURE A')) {
      errors.add(
        'Annexure A found but 0 trades extracted from $filename. '
        'PDF may have different formatting. '
        'Raw text length: ${normalized.length} chars.',
      );
      developer.log(
        '[SBI_CN_V2] PARSE FAILURE: 0 trades from $filename\n'
        'First 500 chars: ${normalized.substring(0, normalized.length.clamp(0, 500))}',
        name: 'SbiContractNoteParser',
      );
    }

    developer.log(
      '[SBI_CN_DEBUG] Annexure A: $rowsDetected detected, $rowsParsed parsed, $rowsRejected rejected\n'
      'Trades: ${trades.map((t) => '${t.symbol} ${t.tradeType} ${t.quantity}@${t.pricePerUnit}').join(', ')}',
      name: 'SbiContractNoteParser',
    );

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: trades,
      aggregateConfidence: trades.isEmpty ? 0 : (tradeDateFromPdf ? 97 : 80),
      warnings: warnings,
      errors: errors,
      rowsDetected: rowsDetected,
      rowsParsed: rowsParsed,
      rejectedRows: rowsRejected,
      rawCandidatesDetected: 0,
      rawCandidates: [],
      snapshots: [],
    );
  }

  // ── Date Parser ─────────────────────────────────────────────────────────
  // Handles formats: "20-MAR-26", "20-MAR-2026", "20/MAR/2026"
  static DateTime? _parseNseDate(String raw) {
    try {
      final clean = raw.trim().toUpperCase().replaceAll('/', '-');
      final parts = clean.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final year = parts[2].length == 2
          ? 2000 + int.parse(parts[2])
          : int.parse(parts[2]);

      const months = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
        'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
        'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
      };

      final month = months[parts[1]];
      if (month == null) return null;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  // ── Symbol Derivation from Description ───────────────────────────────────
  // For ISINs not in the known map.
  // "NIP IND ETF GOLD BEES" → "GOLDBEES"
  // "ICICIPRAMC - ICICISILVE" → "ICICISILVE"
  static String _symbolFromDescription(String description) {
    final d = description.trim().toUpperCase();

    // Special case: "YES BANK" maps to YESBANK directly
    if (d.contains('YES BANK')) return 'YESBANK';
    if (d.contains('YES BANK LIMITED')) return 'YESBANK';

    // If contains " - ", take the part AFTER " - "
    if (description.contains(' - ')) {
      final afterDash = description.split(' - ').last.trim();
      // Remove common suffixes that appear in descriptions
      final cleaned = afterDash
          .replaceAll(RegExp(r'\s+(LIMITED|LTD|PRIVATE|PVT|CORP)$',
              caseSensitive: false), '')
          .replaceAll(' ', '')
          .toUpperCase();
      if (cleaned.isNotEmpty && cleaned.length <= 20) return cleaned;
    }

    // Remove common company suffixes before extracting symbol
    final cleaned = d
        .replaceAll(RegExp(r'\s+(LIMITED|LTD|PRIVATE|PVT)(\s|$)'), ' ')
        .trim();

    final words = cleaned.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'UNKNOWN';

    // Try last word first
    final last = words.last;
    if (last.length >= 3 && last.length <= 12 &&
        RegExp(r'^[A-Z0-9]+$').hasMatch(last)) {
      return last;
    }

    // Try last 2 words combined
    if (words.length >= 2) {
      final last2 = '${words[words.length - 2]}${words.last}';
      if (last2.length <= 12) return last2;
    }

    return words.last;
  }

  /// Returns true if a symbol looks like a valid NSE instrument.
  /// Rejects corrupted strings like "BANKLIMITED", "UNKNOWN", etc.
  static bool _isValidNseSymbol(String symbol) {
    if (symbol.isEmpty || symbol.length > 20) return false;
    if (symbol == 'UNKNOWN') return false;
    if (symbol.contains(' ')) return false;
    // NSE symbols are uppercase alphanumeric + hyphen only
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(symbol)) return false;
    // Known bad patterns from margin/statement documents
    const badPatterns = [
      'LIMITED', 'LTD', 'PRIVATE', 'PVT',
      'BANKLIMITED', 'FUNDSSTATEMENT',
    ];
    for (final bad in badPatterns) {
      if (symbol.contains(bad)) return false;
    }
    return true;
  }

  static double _extractGlobalAmount(String text, String pattern) {
    try {
      final reg = RegExp(pattern, caseSensitive: false);
      final match = reg.firstMatch(text);
      if (match != null) {
        return double.tryParse(
                match.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
    } catch (_) {}
    return 0.0;
  }
}

class _ScripCharges {
  final double brokerage;
  final double gst;
  final double stt;
  final double otherLevies;
  final double netAfterLevies;

  double get totalCharges => brokerage + gst + stt + otherLevies;

  const _ScripCharges({
    required this.brokerage,
    required this.gst,
    required this.stt,
    required this.otherLevies,
    required this.netAfterLevies,
  });
}
