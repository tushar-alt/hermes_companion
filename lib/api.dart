import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
bool isLanHost(String url) {
  try {
    final host = Uri.parse(url).host;
    if (host.isEmpty || host == 'localhost') return true;
    final addr = InternetAddress.tryParse(host);
    if (addr == null) return false; // a hostname → assume it is public
    if (addr.isLoopback || addr.isLinkLocal) return true;
    // RFC 1918 private ranges: 10/8, 172.16/12, 192.168/16.
    final o = addr.rawAddress;
    final n = o.length;
    if (n == 4 || n == 16) {
      final a = o[n - 4];
      final b = o[n - 3];
      if (a == 10) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
      if (a == 192 && b == 168) return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// Cleans a relay base URL that got mangled in transit (chat apps love to
/// wrap or space out links, and a stray space in the host shows up as `%20`
/// and makes dart:io throw "not a valid link-local address").
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
  if (error is SocketException) {
    return 'Can\'t reach that address — wrong IP/port, or the relay is down';
  }
  if (error is http.ClientException) {
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
