// ─────────────────────────────────────────────────────────────────────────────
// BrokerEmailFilter — Exact Sender Whitelist
//
// Rejects all emails not from the exactly known broker addresses. No exceptions,
// no fuzzy domain matching. This guarantees we only scan trusted, structured sources.
// ─────────────────────────────────────────────────────────────────────────────

/// Specific sender addresses for targeted scanning.
const List<String> targetSenderAddresses = [
  'nse_alerts@nse.co.in',
  'nse-direct@nse.co.in',
  'digidocemail@sbicapsec.com',
];

/// Checks if an email sender matches EXACTLY one of the known broker addresses.
bool isBrokerSender(String senderEmail) {
  // Extract the actual email address if it's in the format "Name <email@domain.com>"
  final RegExp emailRegex = RegExp(r'<([^>]+)>');
  final match = emailRegex.firstMatch(senderEmail);
  
  final extracted = match != null 
      ? match.group(1)!.toLowerCase().trim() 
      : senderEmail.toLowerCase().trim();

  return targetSenderAddresses.contains(extracted);
}

/// Filters a list of email addresses, keeping only exact broker senders.
List<String> filterBrokerSenders(List<String> emails) {
  return emails.where(isBrokerSender).toList();
}
