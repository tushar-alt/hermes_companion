import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hermes_companion/agent_prompt.dart';
import 'package:hermes_companion/api.dart';
import 'package:hermes_companion/models.dart';
import 'package:hermes_companion/prompts.dart';
import 'package:hermes_companion/screens/home_screen.dart';
import 'package:hermes_companion/storage.dart';

void main() {
  group('sortChats', () {
    test('admin pinned on top, then by latest activity', () {
      final chats = [
        ChatInfo(id: 'a', name: 'A', lastId: 1),
        ChatInfo(id: 'main', name: 'Hermes', lastId: 1, isMain: true),
        ChatInfo(id: 'b', name: 'B', lastId: 1),
        ChatInfo(id: 'c', name: 'C', lastId: 1),
      ];
      double activity(ChatInfo c) => switch (c.id) {
            'b' => 300,
            'c' => 100,
            'a' => 50,
            _ => 0,
          };
      final sorted = sortChats(chats, activity);
      expect(sorted.first.id, 'main'); // Hermes Admin always on top
      expect(sorted[1].id, 'b'); // most recent response next
      expect(sorted[2].id, 'c');
      expect(sorted[3].id, 'a');
    });

    test('ties break alphabetically', () {
      final chats = [
        ChatInfo(id: 'x', name: 'Zeta', lastId: 1),
        ChatInfo(id: 'y', name: 'Alpha', lastId: 1),
      ];
      final sorted = sortChats(chats, (_) => 0);
      expect(sorted.map((c) => c.name).toList(), ['Alpha', 'Zeta']);
    });
  });

  group('agentPairingPrompt', () {
    test('asks for only a pairing link, nothing else', () {
      final p = agentPairingPrompt();
      expect(p, contains('hermes://pair'));
      expect(p, contains('url='));
      expect(p, contains('token='));
      expect(p, contains('openssl rand -hex 24'));
      expect(p, contains('EXACTLY ONE LINE'));
    });
  });

  group('prompt folders', () {
    test('Prompts folder holds the single master prompt', () {
      final folders = promptFolders;
      expect(folders.any((f) => f.name == 'Prompts'), isTrue);
      final prompts = folders.firstWhere((f) => f.name == 'Prompts');
      expect(prompts.items, hasLength(1));
      final master = prompts.items.first;
      expect(master.name, 'Master prompt');
      expect(master.body, agentPairingPrompt());
      // The master covers all the old separate prompts.
      expect(master.body, contains('hermes://pair'));
      expect(master.body, contains('openssl rand -hex 24'));
      expect(master.body, contains('pause'));
      expect(master.body, contains('DELETE /api/chat/<id>'));
      expect(master.body, contains('Cloudflare Tunnel'));
    });
  });

  group('parsePairLink', () {
    test('parses a hermes:// pairing link', () {
      final cfg = parsePairLink(
          'hermes://pair?url=http%3A%2F%2F192.168.0.56%3A8124&token=abc123');
      expect(cfg, isNotNull);
      expect(cfg!.url, 'http://192.168.0.56:8124');
      expect(cfg.token, 'abc123');
    });

    test('accepts a bare http(s) URL', () {
      final cfg = parsePairLink('https://relay.example.com');
      expect(cfg!.url, 'https://relay.example.com');
      expect(cfg.token, '');
    });

    test('accepts url|token', () {
      final cfg = parsePairLink('http://x:8124|tok');
      expect(cfg!.url, 'http://x:8124');
      expect(cfg.token, 'tok');
    });

    test('rejects junk', () {
      expect(parsePairLink('hello world'), isNull);
      expect(parsePairLink(''), isNull);
    });
  });

  group('AppPrefs.clearChat', () {
    test('wipes every local trace of a deleted session', () async {
      SharedPreferences.setMockInitialValues({
        'lastId_abc': 5,
        'seen_abc': 5,
        'notified_abc': 5,
        'muted_abc': true,
        'outbox_abc': '[{"text":"hi","media":[]}]',
        'cache_abc': '[{"id":1,"role":"assistant","text":"yo","ts":0,"media":[]}]',
        'serverUrl': 'http://x',
        'token': 't',
      });
      final prefs = await AppPrefs.load();
      await prefs.clearChat('abc');
      expect(prefs.lastIdFor('abc'), 0);
      expect(prefs.seenFor('abc'), 0);
      expect(prefs.notifiedFor('abc'), 0);
      expect(prefs.mutedFor('abc'), false);
      expect(prefs.outboxFor('abc'), isEmpty);
      expect(prefs.cachedMessagesFor('abc'), isNull);
      // Unrelated keys survive.
      expect(prefs.serverUrl, 'http://x');
      expect(prefs.token, 't');
    });
  });

  group('isLanHost', () {
    test('recognises private/LAN hosts', () {
      expect(isLanHost('http://192.168.0.56:8124'), isTrue);
      expect(isLanHost('http://10.0.0.5:8124'), isTrue);
      expect(isLanHost('http://localhost:8124'), isTrue);
    });

    test('treats hostnames as public', () {
      expect(isLanHost('https://relay.example.com'), isFalse);
    });
  });

  group('normalizeBaseUrl', () {
    test('strips a %20 pasted into the host (cloudflare paste artifact)', () {
      expect(
        normalizeBaseUrl(
            'https://specifies-head%20-cylinder-giving.trycloudflare.com'),
        'https://specifies-head-cylinder-giving.trycloudflare.com',
      );
    });

    test('strips stray whitespace', () {
      expect(normalizeBaseUrl('  https://a.example.com \n '),
          'https://a.example.com');
      expect(
          normalizeBaseUrl('http://10.0.0.5: 8124'), 'http://10.0.0.5:8124');
    });

    test('leaves clean URLs untouched', () {
      const clean = 'https://specifies-head-cylinder-giving.trycloudflare.com';
      expect(normalizeBaseUrl(clean), clean);
      expect(
          normalizeBaseUrl('http://192.168.0.56:8124'), 'http://192.168.0.56:8124');
    });
  });

  group('parsePairLink mangled input', () {
    test('fixes a space-mangled cloudflare link inside hermes://', () {
      final cfg = parsePairLink(
          'hermes://pair?url=https%3A%2F%2Fspecifies-head%20-cylinder-giving.trycloudflare.com&token=abc');
      expect(cfg, isNotNull);
      expect(cfg!.url,
          'https://specifies-head-cylinder-giving.trycloudflare.com');
      expect(cfg.token, 'abc');
    });

    test('RelayApi normalizes its baseUrl', () {
      final api = RelayApi(
          'https://specifies-head%20-cylinder-giving.trycloudflare.com');
      expect(api.baseUrl,
          'https://specifies-head-cylinder-giving.trycloudflare.com');
    });
  });
}
