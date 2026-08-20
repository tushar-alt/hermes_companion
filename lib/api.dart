import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Thin client for the Hermes Companion relay (on the user's machine).
class RelayApi {
  /// [baseUrl] is normalized on construction so a mangled paste (stray
  /// spaces, `%20` in the host) can never break networking later.
  RelayApi(String baseUrl, {this.token = ''})
      : baseUrl = normalizeBaseUrl(baseUrl);

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<ChatInfo> fetchChat() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/chat'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) throw Exception('unauthorized');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatInfo(
      id: data['chatId'] as String? ?? 'main',
      name: data['displayName'] as String? ?? 'Hermes',
      lastId: (data['lastId'] as num?)?.toInt() ?? 0,
      isMain: true,
    );
  }

  /// Upload raw bytes to the relay; returns the server-side path.
  Future<String> uploadFile(String chatId, String name, List<int> bytes) async {
    final uri = Uri.parse(
        '$baseUrl/api/upload?name=${Uri.encodeQueryComponent(name)}'
        '&chat=${Uri.encodeQueryComponent(chatId)}');
    final res = await http
        .post(uri,
            headers: {..._headers, 'Content-Type': 'application/octet-stream'},
            body: bytes)
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('upload failed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['path'] as String;
  }

  Future<List<ChatInfo>> fetchChats() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/chats'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) throw Exception('unauthorized');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['chats'] as List<dynamic>? ?? [])
        .map((c) => ChatInfo.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Live run-state for every chat: {chatId: ChatStatus}.
  Future<Map<String, ChatStatus>> fetchStatus() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/status'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) throw Exception('unauthorized');
    final data = jsonDecode(res.body)['chats'] as Map<String, dynamic>;
    return data.map((k, v) =>
        MapEntry(k, ChatStatus.fromJson(v as Map<String, dynamic>)));
  }

  /// List files in ~/Shared on the machine.
  Future<List<FileEntry>> fetchFiles() async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/files'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['files'] as List<dynamic>? ?? [])
        .map((f) => FileEntry.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Stream a media file from the relay (for progress-aware downloads).
  Future<http.StreamedResponse> streamMedia(String path) async {
    final req = http.Request(
        'GET',
        Uri.parse(
            '$baseUrl/api/media?path=${Uri.encodeQueryComponent(path)}'))
      ..headers.addAll(_headers);
    final client = http.Client();
    try {
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      return res;
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  Future<List<int>> fetchMediaBytes(String path) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/api/media?path=${Uri.encodeQueryComponent(path)}'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  /// Delete a non-main chat from the relay.
  Future<bool> deleteChat(String id) async {
    final res = await http
        .delete(Uri.parse('$baseUrl/api/chat/$id'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    return res.statusCode == 200;
  }

  Future<ChatInfo> createChat(String name) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/chat/new'),
          headers: {'Content-Type': 'application/json', ..._headers},
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('create failed');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatInfo(
      id: data['id'] as String,
      name: data['name'] as String,
      lastId: 0,
      isMain: false,
    );
  }

  Future<MessagePage> fetchMessages(int after, {String chatId = 'main'}) async {
    final res = await http
        .get(Uri.parse('$baseUrl/api/messages?after=$after&chat=$chatId'),
            headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) throw Exception('unauthorized');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['messages'] as List<dynamic>? ?? [])
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return MessagePage(
      messages: list,
      lastId: (data['lastId'] as num?)?.toInt() ?? after,
    );
  }

  Future<void> send(String text,
      {String chatId = 'main', List<String>? media}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/send'),
          headers: {'Content-Type': 'application/json', ..._headers},
          body: jsonEncode({
            'text': text,
            'chat': chatId,
            if (media != null && media.isNotEmpty) 'media': media,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('send failed: ${res.statusCode}');
    }
  }

  /// Pause/resume an agent session for a chat. When paused, the relay should
  /// stop that session's CLI so it uses zero resources.
  Future<bool> pauseChat(String id) => _setPaused(id, true);
  Future<bool> resumeChat(String id) => _setPaused(id, false);

  Future<bool> _setPaused(String id, bool paused) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/chat/$id/${paused ? 'pause' : 'resume'}'),
            headers: {'Content-Type': 'application/json', ..._headers},
            body: jsonEncode(const {}),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/health'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Whether [url] points at a private/LAN address (or localhost). Used to warn
/// the user about plain `http://` when the relay is exposed to the internet.
/// Works on every platform (no dart:io, so it also compiles for the web).
bool isLanHost(String url) {
  try {
    final host = Uri.parse(url).host;
    if (host.isEmpty || host == 'localhost') return true;
    // IPv6 loopback / link-local literals.
    if (host == '::1' || host.startsWith('fe80:')) return true;
    // IPv4 literals: private ranges 10/8, 172.16/12, 192.168/16, loopback
    // 127/8 and link-local 169.254/16.
    final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
        .firstMatch(host);
    if (m == null) return false; // a hostname → assume it is public
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    if (a == 10) return true;
    if (a == 127) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    if (a == 169 && b == 254) return true;
    return false;
  } catch (_) {
    return false;
  }
}

/// Cleans a relay base URL that got mangled in transit (chat apps love to
/// wrap or space out links, and a stray space in the host shows up as `%20`
/// and breaks URL parsing).
///
/// - strips all whitespace (spaces/newlines/tabs anywhere in the URL)
/// - removes `%20`/spaces inside the host portion
String normalizeBaseUrl(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'\s+'), '');
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasAuthority) return s;
  final host = uri.host.replaceAll('%20', '').replaceAll(' ', '');
  if (host == uri.host) return s;
  return uri.replace(host: host).toString();
}

/// Human-readable reason a relay request failed (for "Test connection").
String describeConnectionError(Object error) {
  if (error is FormatException) {
    return 'Invalid URL — check the link for stray spaces or characters';
  }
  if (error is TimeoutException) {
    return 'Timed out — no response from that address';
  }
  if (error is http.ClientException) {
    // On the web, connection failures surface as ClientException
    // ("Failed to fetch", "Connection refused", ...).
    return 'Network error: ${error.message}';
  }
  final msg = error.toString();
  if (msg.contains('unauthorized')) {
    return 'Unauthorized (401) — check the token';
  }
  if (msg.contains('TLS') || msg.contains('certificate')) {
    return 'TLS problem — use https:// with a valid certificate';
  }
  return 'Connection failed — $msg';
}

/// Connection settings parsed from the pairing link an agent generates.
class PairConfig {
  const PairConfig(this.url, this.token);

  final String url;
  final String token;
}

/// Accepts several forgiving input shapes:
///   `hermes://pair?url=<urlencoded>&token=<token>`  (agent-generated)
///   `https://relay.tld#bearer_token`                (URL#token)
///   `http://192.168.0.56:8124`                      (bare relay URL)
///   `http://...|token`                              (URL|token)
///
/// Whitespace is stripped everywhere and the URL is normalized, because chat
/// apps wrap/space links and a stray space in the host breaks URL parsing.
PairConfig? parsePairLink(String input) {
  final s = input.replaceAll(RegExp(r'\s+'), '').trim();
  if (s.isEmpty) return null;
  final uri = Uri.tryParse(s);
  if (uri != null && uri.scheme == 'hermes') {
    final url = normalizeBaseUrl(uri.queryParameters['url']?.trim() ?? '');
    final token = uri.queryParameters['token']?.trim() ?? '';
    if (url.isEmpty) return null;
    return PairConfig(url, token);
  }
  // `https://relay.tld#bearer_token` — the URL fragment holds the token.
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.fragment.isNotEmpty) {
    final url = normalizeBaseUrl(uri.replace(fragment: '').toString());
    return PairConfig(url, uri.fragment);
  }
  // `url|token` — checked before the bare-URL branch so a pasted
  // "http://host:port|token" splits correctly.
  if (s.contains('|')) {
    final parts = s.split('|');
    final url = normalizeBaseUrl(parts.first.trim());
    final token = parts.sublist(1).join('|').trim();
    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      return PairConfig(url, token);
    }
  }
  if (s.startsWith('http://') || s.startsWith('https://')) {
    return PairConfig(normalizeBaseUrl(s), '');
  }
  return null;
}
