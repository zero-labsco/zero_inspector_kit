import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/inspector_theme.dart';

/// 响应体图片预览 / Response-body image preview
///
/// 此前响应体一律按文本渲染，`Content-Type: image/*` 的响应在面板里只是一串
/// 乱码。这里对可识别的图片字节做缩略图渲染。
/// Response bodies were always rendered as text, so an `image/*` response was
/// just a wall of mojibake. Recognizable image bytes now render as a thumbnail.
class InspectorImagePreview extends StatelessWidget {
  /// 响应体文本 / Response body text
  final String body;

  const InspectorImagePreview({super.key, required this.body});

  /// 从响应体里提取图片字节；不是图片时返回 null。
  /// Extract image bytes from the body; returns null when it isn't an image.
  ///
  /// 支持两种承载方式 / Two carriers are supported:
  /// - 检查器对非 UTF-8 响应写入的 `[Binary response …]\nbase64: <…>`
  ///   The `[Binary response …]\nbase64: <…>` form written by the inspector for
  ///   non-UTF-8 responses.
  /// - `data:image/…;base64,…` 形式的 data URI / A `data:image/…;base64,…` URI
  static Uint8List? imageBytesOf(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    String? encoded;
    if (trimmed.startsWith('data:image/')) {
      final comma = trimmed.indexOf(',');
      if (comma < 0) return null;
      encoded = trimmed.substring(comma + 1);
    } else {
      const marker = 'base64:';
      final idx = trimmed.indexOf(marker);
      if (idx < 0) return null;
      encoded = trimmed.substring(idx + marker.length).trim();
    }

    Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } catch (_) {
      return null;
    }
    return _looksLikeImage(bytes) ? bytes : null;
  }

  /// 按魔数嗅探常见图片格式 / Sniff common image formats by magic bytes
  static bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // GIF
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }
    // WebP: "RIFF" .... "WEBP"
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // BMP
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytesOf(body);
    if (bytes == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.image_rounded,
              size: 13,
              color: InspectorColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              'Preview · ${(bytes.length / 1024).toStringAsFixed(1)} KB',
              style: TextStyle(
                color: InspectorColors.textHint,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: InspectorColors.border, width: 1),
          ),
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              // 超出可视高度时限制，避免大图把详情页顶飞。
              // Cap the height so a huge image can't blow up the detail page.
              height: 220,
              errorBuilder: (_, _, _) => Text(
                'Unable to decode this image',
                style: TextStyle(color: InspectorColors.textHint, fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
