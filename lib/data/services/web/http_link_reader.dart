import 'package:http/http.dart' as http;

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/text_utils.dart';
import '../../../domain/services/ai_services.dart';

/// Best-effort fetch of a saved link. Only the URL the user saved is
/// requested; failures simply mean the note is saved without page text.
final class HttpLinkReader implements LinkReader {
  const HttpLinkReader(this._client, this._logger, {this.timeout = const Duration(seconds: 8)});

  final http.Client _client;
  final AppLogger _logger;
  final Duration timeout;

  static const _ok = 200;

  @override
  Future<LinkContent?> read(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null || !uri.hasAuthority) return null;
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != _ok) return null;
      return HtmlContentExtractor.extract(response.body);
    } on Object catch (e) {
      _logger.error('Reading $url failed', e);
      return null;
    }
  }
}

/// Pulls the title and paragraph text out of an HTML page.
abstract final class HtmlContentExtractor {
  static const _maxTextChars = 5000;
  static const _minParagraphChars = 40;
  static final _title = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false);
  static final _paragraph = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);
  static final _tag = RegExp('<[^>]+>');
  static const _entities = {
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&nbsp;': ' ',
  };

  static LinkContent extract(String html) {
    final title = _title.firstMatch(html)?[1];
    final text = _paragraph
        .allMatches(html)
        .map((m) => _decode(m[1]!.replaceAll(_tag, '')).trim())
        .where((p) => p.length > _minParagraphChars)
        .join('\n');
    return LinkContent(
      title: title == null ? null : _decode(title.trim()),
      text: text.isEmpty ? null : TextUtils.truncate(text, _maxTextChars),
    );
  }

  static String _decode(String s) =>
      _entities.entries.fold(s, (acc, e) => acc.replaceAll(e.key, e.value));
}
