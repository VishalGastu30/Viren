import 'dart:convert';
import 'dart:developer' as developer;

/// Core document types that the pipeline can explicitly recognize and parse.
enum PdfDocumentType {
  nseTradeConfirmation,
  nseAlertsStatement,
  sbiContractNote,
  sbiMarginStatement,
  sbiFundsStatement,
  sbiSecuritiesStatement,
  unknown,
}

/// LAYER 3: DOCUMENT CLASSIFICATION
/// Statically analyzes decrypted PDF text + metadata to determine the exact
/// structural type of the document before attempting to parse it.
class PdfClassifier {
  
  static PdfDocumentType classify({
    required String filename,
    required String senderEmail,
    required String rawText,
  }) {
    final lowerName = filename.toLowerCase();
    final lowerSender = senderEmail.toLowerCase();

    // ── Reject non-trade SBI documents by filename prefix ──────────────────
    // These are margin reports, fund statements, and account statements
    // that contain no trade execution data.
    if (lowerName.startsWith('dmrg_')) return PdfDocumentType.unknown;
    if (lowerName.startsWith('funds_')) return PdfDocumentType.unknown;
    if (lowerName.contains('weekly_statement')) return PdfDocumentType.unknown;
    if (lowerName.contains('statement_of_account')) return PdfDocumentType.unknown;
    if (lowerName.contains('margin_statement')) return PdfDocumentType.unknown;

    // Normalize text for easier keyword searching (compress whitespace)
    final normalizedText = rawText.replaceAll(RegExp(r'\s+'), ' ');

    // ── Reject by content keywords ────────────────────────────────────────
    if (normalizedText.contains('DAILY MARGIN REPORT') ||
        normalizedText.contains('Daily Margin Report')) {
      return PdfDocumentType.unknown;
    }
    if (normalizedText.contains('WEEKLY STATEMENT') ||
        normalizedText.contains('Weekly Statement of Account')) {
      return PdfDocumentType.unknown;
    }

    // ── Positive classifier: CNB filename pattern ─────────────────────────
    if (lowerName.startsWith('cnb_') && lowerName.contains('contract')) {
      return PdfDocumentType.sbiContractNote;
    }

    if (lowerSender.contains('nse-direct@nse.co.in')) {
      // Sender-first: NSE Direct emails are ALWAYS nseTradeConfirmation
      // regardless of text quality (text may be garbage/empty from PDFBox)
      return PdfDocumentType.nseTradeConfirmation;
    }

    if (lowerSender.contains('nse_alerts@nse.co.in')) {
       return PdfDocumentType.nseAlertsStatement;
    }

    if (lowerSender.contains('digidocemail@sbicapsec.com') || lowerSender.contains('sbicapsec')) {
      if (lowerName.contains('cnb_')) {
        return PdfDocumentType.sbiContractNote;
      }
      if (lowerName.contains('dmrg_') || normalizedText.contains('Margin Balance')) {
        return PdfDocumentType.sbiMarginStatement;
      }
      if (lowerName.contains('weekly') || lowerName.contains('monthly') || lowerName.contains('quarterly')) {
        return PdfDocumentType.sbiFundsStatement;
      }
      if (normalizedText.contains('Securities Statement') || normalizedText.contains('Holding Statement')) {
         return PdfDocumentType.sbiSecuritiesStatement;
      }
    }
    
    // If we reach here, it's either an unsupported broker or an unsupported PDF type
    developer.log(jsonEncode({
      'event': 'classification_failed',
      'filename': filename,
      'sender': senderEmail,
    }), name: 'PdfClassifier');
    
    return PdfDocumentType.unknown;
  }
}
