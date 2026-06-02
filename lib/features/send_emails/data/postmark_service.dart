import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PostmarkAttachment {
  final String name;
  final Uint8List bytes;
  final String contentType;

  const PostmarkAttachment({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  Map<String, dynamic> toJson() => {
        'Name': name,
        'Content': base64Encode(bytes),
        'ContentType': contentType,
      };
}

class PostmarkResult {
  final bool success;
  final String? errorMessage;

  const PostmarkResult._({required this.success, this.errorMessage});

  factory PostmarkResult.ok() => const PostmarkResult._(success: true);
  factory PostmarkResult.failure(String msg) =>
      PostmarkResult._(success: false, errorMessage: msg);
}

class PostmarkService {
  static const _from = 'Mind Rain <team@mindrain.org>';
  static const _replyTo = 'team@mindrain.org';

  static Future<PostmarkResult> sendEmail({
    required String token,
    required String to,
    required String subject,
    required String? textBody,
    String? htmlBody,
    List<PostmarkAttachment> attachments = const [],
  }) async {
    final payload = <String, dynamic>{
      'From': _from,
      'To': to,
      'ReplyTo': _replyTo,
      'Subject': subject,
      'TextBody': ?textBody,
      'HtmlBody': ?htmlBody,
      'MessageStream': 'outbound',
      if (attachments.isNotEmpty)
        'Attachments': attachments.map((a) => a.toJson()).toList(),
    };

    try {
      final res = await http.post(
        Uri.parse('https://api.postmarkapp.com/email'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Postmark-Server-Token': token,
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) return PostmarkResult.ok();

      String msg;
      try {
        msg = (jsonDecode(res.body) as Map)['Message'] as String? ??
            'HTTP ${res.statusCode}';
      } catch (_) {
        msg = 'HTTP ${res.statusCode}';
      }
      return PostmarkResult.failure(msg);
    } catch (e) {
      return PostmarkResult.failure('$e');
    }
  }
}
