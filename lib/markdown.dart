import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Minimal markdown renderer for agent replies.
///
/// Handles the common subset agents actually emit: fenced code blocks,
/// `#` headings, `> ` blockquotes, `-`/`1.` lists, horizontal rules, and
/// inline `code`, **bold**, *italic*, ~~strike~~ and [links](url). Written
/// in-house so the app needs no extra pub dependency.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.text, {super.key, this.style, this.accent = gold});

  final String text;
  final TextStyle? style;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final blocks = _parseBlocks(text);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final b in blocks) _buildBlock(b, base)],
      ),
    );
  }

  Widget _buildBlock(_MdBlock b, TextStyle base) {
    switch (b.type) {
      case _MdType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(children: _inline(b.text, base)),
              style: base),
        );
      case _MdType.heading:
        final size = base.fontSize ?? 14.0;
        final level = b.level.clamp(1, 4);
        final hs = base.copyWith(
          fontSize: size + (5 - level).toDouble(),
          fontWeight: FontWeight.w700,
          color: accent,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text.rich(TextSpan(children: _inline(b.text, hs)), style: hs),
        );
      case _MdType.code:
        final blockTint = (base.color ?? gold).withValues(alpha: 0.08);
        return Container(
          // No width:double.infinity — the block must shrink to its content
          // so the bubble is only as big as needed.
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: blockTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                b.text,
                style: base.copyWith(
                    fontFamily: 'monospace', fontSize: 12.5, height: 1.4),
              ),
            ),
          ),
        );
      case _MdType.quote:
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(
                    color: accent.withValues(alpha: 0.6), width: 3)),
          ),
          child: Text.rich(
            TextSpan(
                children: _inline(b.text,
                    base.copyWith(fontStyle: FontStyle.italic))),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      case _MdType.list:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < b.items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          b.ordered ? '${i + 1}.' : '•',
                          style: base.copyWith(
                              color: accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: _inline(b.items[i], base)),
                          style: base,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case _MdType.rule:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: SizedBox(
              width: 90,
              child: Divider(color: accent.withValues(alpha: 0.3), height: 1),
            ),
          ),
        );
    }
  }
}

// ─── inline parsing ─────────────────────────────────────────────────────
List<InlineSpan> _inline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      spans.add(TextSpan(text: buf.toString()));
      buf.clear();
    }
  }

  var i = 0;
  while (i < text.length) {
    final rest = text.substring(i);
    if (rest.startsWith('`')) {
      final end = text.indexOf('`', i + 1);
      if (end > i) {
        flush();
        spans.add(TextSpan(
          text: text.substring(i + 1, end),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor:
                (base.color ?? gold).withValues(alpha: 0.12),
            color: accentColorFor(base),
          ),
        ));
        i = end + 1;
        continue;
      }
    }
    if (rest.startsWith('**')) {
      final m = RegExp(r'\*\*(.+?)\*\*').matchAsPrefix(rest);
      if (m != null) {
        flush();
        spans.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ));
        i += m.group(0)!.length;
        continue;
      }
    }
    if (rest.startsWith('*')) {
      final m = RegExp(r'\*([^*]+)\*').matchAsPrefix(rest);
      if (m != null) {
        flush();
        spans.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
        i += m.group(0)!.length;
        continue;
      }
    }
    if (rest.startsWith('~~')) {
      final m = RegExp(r'~~(.+?)~~').matchAsPrefix(rest);
      if (m != null) {
        flush();
        spans.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(decoration: TextDecoration.lineThrough),
        ));
        i += m.group(0)!.length;
        continue;
      }
    }
    if (rest.startsWith('[')) {
      final m = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)').matchAsPrefix(rest);
      if (m != null) {
        flush();
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _InlineLink(
            label: m.group(1)!,
            url: m.group(2)!,
            style: base,
            accent: accentColorFor(base),
          ),
        ));
        i += m.group(0)!.length;
        continue;
      }
    }
    buf.write(text[i]);
    i++;
  }
  flush();
  return spans;
}

/// Pick a readable accent for inline code/links on any bubble color.
Color accentColorFor(TextStyle base) {
  final c = base.color;
  if (c == null) return gold;
  // On dark gold bubbles (user messages) use dark ink instead of gold.
  return c.computeLuminance() < 0.4 ? gold : bg;
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.label,
    required this.url,
    required this.style,
    required this.accent,
  });

  final String label;
  final String url;
  final TextStyle style;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLinkActions(context),
      child: Text(
        label,
        style: style.copyWith(
          color: accent,
          decoration: TextDecoration.underline,
          decorationColor: accent.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  void _showLinkActions(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(url,
                  style: const TextStyle(color: cream, fontSize: 13)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Link copied to clipboard')));
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(foregroundColor: gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── block parsing ──────────────────────────────────────────────────────
enum _MdType { paragraph, heading, code, quote, list, rule }

class _MdBlock {
  _MdBlock(
    this.type, {
    this.text = '',
    this.items = const [],
    this.level = 0,
    this.ordered = false,
  });

  final _MdType type;
  final String text;
  final List<String> items;
  final int level;
  final bool ordered;
}

List<_MdBlock> _parseBlocks(String src) {
  final lines = src.split('\n');
  final blocks = <_MdBlock>[];
  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.isEmpty) {
      i++;
      continue;
    }
    if (trimmed.startsWith('```')) {
      final buf = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
        buf.add(lines[i]);
        i++;
      }
      i++; // closing fence
      blocks.add(_MdBlock(_MdType.code, text: buf.join('\n')));
      continue;
    }
    final hm = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(trimmed);
    if (hm != null) {
      blocks.add(_MdBlock(_MdType.heading,
          text: hm.group(2)!, level: hm.group(1)!.length));
      i++;
      continue;
    }
    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      blocks.add(_MdBlock(_MdType.rule));
      i++;
      continue;
    }
    if (trimmed.startsWith('>')) {
      final buf = <String>[];
      while (i < lines.length) {
        final t = lines[i].trim();
        if (!t.startsWith('>')) break;
        buf.add(t.substring(1).trim());
        i++;
      }
      blocks.add(_MdBlock(_MdType.quote, text: buf.join(' ')));
      continue;
    }
    final listItem = RegExp(r'^([-*+]|\d+[.)])\s+(.*)$').firstMatch(trimmed);
    if (listItem != null) {
      final ordered = RegExp(r'^\d+[.)]').hasMatch(listItem.group(1)!);
      final items = <String>[listItem.group(2)!];
      i++;
      while (i < lines.length) {
        final t = lines[i].trim();
        if (t.isEmpty) {
          i++;
          break;
        }
        final m = RegExp(r'^([-*+]|\d+[.)])\s+(.*)$').firstMatch(t);
        if (m == null) break;
        items.add(m.group(2)!);
        i++;
      }
      blocks.add(_MdBlock(_MdType.list, items: items, ordered: ordered));
      continue;
    }
    final buf = <String>[trimmed];
    i++;
    while (i < lines.length) {
      final t = lines[i].trim();
      if (t.isEmpty) break;
      if (RegExp(r'^(#{1,4})\s+|^```|^>|^([-*+]|\d+[.)])\s+').hasMatch(t)) {
        break;
      }
      buf.add(t);
      i++;
    }
    blocks.add(_MdBlock(_MdType.paragraph, text: buf.join(' ')));
  }
  return blocks;
}
