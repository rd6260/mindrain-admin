import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvParseResult {
  const CsvParseResult({required this.headers, required this.rows});

  final List<String> headers;
  final List<Map<String, String>> rows;
}

class CsvParser {
  static const _emailCandidates = {'email', 'emails', 'e-mail', 'e-mails'};

  /// Opens the system file picker, parses the chosen CSV and returns the
  /// result, or [null] if the user cancelled or the file was empty.
  static Future<CsvParseResult?> pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null) return null;

    final content = utf8.decode(result.files.first.bytes!);
    final rawRows = const CsvToListConverter(eol: '\n').convert(content);
    if (rawRows.isEmpty) return null;

    final headers =
        rawRows.first.map((e) => e.toString().trim()).toList();

    final rows = rawRows.skip(1).map((r) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < r.length ? r[i].toString().trim() : '';
      }
      return map;
    }).toList();

    return CsvParseResult(headers: headers, rows: rows);
  }

  /// Returns the first header that looks like an email column, or [null].
  static String? findEmailColumn(List<String> headers) {
    for (final h in headers) {
      if (_emailCandidates.contains(h.toLowerCase())) return h;
    }
    return null;
  }

  /// Resolves `{{var}}` placeholders in [template] using values from [row]
  /// and [defaults] as fallback.
  static String resolveTemplate(
    String template,
    Map<String, String> row,
    Map<String, String> defaults,
  ) {
    return template.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
      final key = m.group(1)!;
      final cell = row[key];
      if (cell != null && cell.isNotEmpty) return cell;
      final def = defaults[key] ?? '';
      return def.isNotEmpty ? def : '{{$key}}';
    });
  }
}
