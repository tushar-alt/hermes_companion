import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// Returns the attachment's bytes (device build: read from the local file).
Future<Uint8List?> attachmentBytes(Attachment att) async {
  if (att.bytes != null) return att.bytes;
  final f = File(att.localPath);
  if (!await f.exists()) return null;
  return f.readAsBytes();
}
