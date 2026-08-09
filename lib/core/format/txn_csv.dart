/// CSV encoding for the transaction export of requirement 15.11.
///
/// Encoding is a pure function of the rows, and the file write sits behind
/// [TxnExportWriter]. Nothing here touches a filesystem, so the format is unit
/// testable and the platform specific half is a single seam the presentation
/// layer binds.
library;

import '../../domain/models.dart';

/// Writes [contents] under [filename] and resolves to the path written.
///
/// The presentation layer resolves this through a provider, so the default can
/// be a no op that reports a stub path and the real device backed writer can be
/// bound at composition time without the screen importing a platform plugin.
typedef TxnExportWriter =
    Future<String> Function(String filename, String contents);

/// Column order of the export. Declared once so the header row and the value
/// row cannot drift apart.
const List<String> txnCsvHeader = <String>[
  'Date',
  'Merchant',
  'Category',
  'Type',
  'Status',
  'Direction',
  'Amount',
  'Currency',
  'Reference',
  'Note',
];

/// Row separator. RFC 4180 specifies a carriage return and line feed pair.
const String txnCsvLineEnding = '\r\n';

/// Encodes [rows] as RFC 4180 CSV, header row first.
///
/// Merchant names, references, and notes are user data, so every field is
/// quoted when it carries a comma, a double quote, a carriage return, or a line
/// feed, and inner double quotes are doubled.
String encodeTxnCsv(List<Txn> rows) {
  final buffer = StringBuffer()
    ..write(txnCsvHeader.map(encodeTxnCsvField).join(','))
    ..write(txnCsvLineEnding);

  for (final txn in rows) {
    buffer
      ..write(
        <String>[
          txn.date.toIso8601String(),
          txn.merchant,
          txn.category,
          txn.type.label,
          txn.status.label,
          txn.isInflow ? 'Inflow' : 'Outflow',
          txn.signedAmount.toStringAsFixed(2),
          txn.currencyCode,
          txn.reference,
          txn.note ?? '',
        ].map(encodeTxnCsvField).join(','),
      )
      ..write(txnCsvLineEnding);
  }

  return buffer.toString();
}

/// Quotes one field per RFC 4180. Exposed so the rule can be tested directly
/// rather than only through a whole document.
String encodeTxnCsvField(String value) {
  final needsQuotes =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// Stable export filename. Dated, so two exports on different days do not
/// overwrite one another.
String txnCsvFilename({DateTime? now}) {
  final at = now ?? DateTime.now();
  final month = at.month.toString().padLeft(2, '0');
  final day = at.day.toString().padLeft(2, '0');
  return 'frostbank_activity_${at.year}$month$day.csv';
}

/// Default [TxnExportWriter]. Reports where the file would land and writes
/// nothing, so no build or test depends on a platform path provider. The real
/// device backed writer is bound over this at composition time.
Future<String> stubTxnExportWriter(String filename, String contents) async =>
    'Downloads/$filename';
