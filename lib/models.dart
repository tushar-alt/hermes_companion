/// Data models shared across the app (API DTOs + local queue types).
library;

import 'dart:convert';
import 'dart:typed_data';

class ChatInfo {
  ChatInfo({
    required this.id,
    required this.name,
    required this.lastId,
    this.isMain = false,
    this.avatar = '⚕',
    this.lastTs = 0,
  });

  factory ChatInfo.fromJson(Map<String, dynamic> json) => ChatInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        lastId: (json['lastId'] as num?)?.toInt() ?? 0,
        isMain: json['isMain'] as bool? ?? false,
        avatar: json['avatar'] as String? ?? '⚕',
        lastTs: (json['lastTs'] as num?)?.toDouble() ?? 0,
      );

  final String id;
  final String name;
  final int lastId;
  final bool isMain;
  final String avatar;

  /// Unix seconds of the chat's last message (optional, relay-provided).
  final double lastTs;
}

/// Live run-state of a chat (relay /api/status).
class ChatStatus {
  ChatStatus({
    required this.status,
    required this.since,
    required this.detail,
    this.paused = false,
  });

  factory ChatStatus.fromJson(Map<String, dynamic> json) => ChatStatus(
        status: json['status'] as String? ?? 'idle',
        since: (json['since'] as num?)?.toDouble() ?? 0,
        detail: json['detail'] as String? ?? '',
        paused: json['paused'] as bool? ?? false,
      );

  final String status;
  final double since;
  final String detail;

  /// True when the agent session for this chat is paused (sleeping).
  final bool paused;

  bool get isRunning => status == 'running';
}

class FileEntry {
  FileEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.mtime,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        mtime: (json['mtime'] as num?)?.toDouble() ?? 0,
      );

  final String name;
  final String path;
  final int size;
  final double mtime;

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.ts,
    this.media = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as num).toInt(),
        role: json['role'] as String,
        text: json['text'] as String? ?? '',
        ts: (json['ts'] as num?)?.toDouble() ?? 0,
        media: (json['media'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  final int id;
  final String role;
  final String text;
  final double ts;
  final List<String> media;

  bool get isUser => role == 'user';

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'ts': ts,
        'media': media,
      };
}

class MessagePage {
  MessagePage({required this.messages, required this.lastId});

  final List<ChatMessage> messages;
  final int lastId;
}

/// A message waiting for the agent to become free (persisted outbox item).
class QueuedMessage {
  QueuedMessage(this.text, this.media);

  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
        json['text'] as String? ?? '',
        (json['media'] as List<dynamic>? ?? [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String text;
  final List<Attachment> media;

  Map<String, dynamic> toJson() => {
        'text': text,
        'media': media.map((m) => m.toJson()).toList(),
      };
}

/// A locally-picked file waiting to be uploaded with a queued message.
///
/// On device builds the file lives at [localPath]; on the web there is no
/// file system, so the picked bytes are kept in [bytes] instead.
class Attachment {
  const Attachment(this.localPath, this.name, {this.bytes});

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final b64 = json['bytes'] as String?;
    return Attachment(
      json['localPath'] as String? ?? '',
      json['name'] as String? ?? '',
      bytes: (b64 == null || b64.isEmpty) ? null : base64Decode(b64),
    );
  }

  final String localPath;
  final String name;

  /// Raw file bytes (web builds, where there is no local file system).
  final Uint8List? bytes;

  Map<String, dynamic> toJson() => {
        'localPath': localPath,
        'name': name,
        if (bytes != null) 'bytes': base64Encode(bytes!),
      };
}
