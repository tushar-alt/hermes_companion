import 'dart:typed_data';

import 'models.dart';

/// Returns the attachment's bytes (web build: the picked file is already in
/// memory — there is no local file system to read from).
Future<Uint8List?> attachmentBytes(Attachment att) async => att.bytes;
