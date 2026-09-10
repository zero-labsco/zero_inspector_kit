import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/network_request.dart';
import '../../utils/network_replay.dart';
import '../theme/inspector_theme.dart';

/// 可编辑重放编辑器 / Editable replay editor
///
/// URL、Header、Body 均为只读（按既定设计不可修改）。仅允许编辑 URL 的
/// 查询参数（请求参数），重放时会用修改后的参数重建 URL，其余部分原样重发。
/// URL, headers and body are read-only by design. Only the URL query
/// parameters may be edited; on replay the URL is rebuilt from the edited
/// params while everything else is re-sent verbatim.
class InspectorReplayEditor extends StatefulWidget {
  /// 原始被重放的请求 / The original captured request
  final NetworkRequest request;

  const InspectorReplayEditor({super.key, required this.request});

  @override
  State<InspectorReplayEditor> createState() => _InspectorReplayEditorState();
}

class _InspectorReplayEditorState extends State<InspectorReplayEditor> {
  /// 可编辑的查询参数行 / Editable query-parameter rows
  final List<_ParamRow> _params = [];
  bool _sending = false;
  String? _responseText;

  @override
  void initState() {
    super.initState();
    // 从原始 URL 解析查询参数作为初始可编辑行 / seed from the captured URL
    final original = <String, String>{};
    try {
      original.addAll(Uri.parse(widget.request.url).queryParameters);
    } catch (_) {
      // 解析失败时留空，仍可手动添加 / fall back to empty if URL is unparseable
    }
    if (original.isEmpty) {
      _params.add(_ParamRow('', ''));
    } else {
      for (final entry in original.entries) {
        _params.add(_ParamRow(entry.key, entry.value));
      }
    }
  }

  @override
  void dispose() {
    for (final p in _params) {
      p.key.dispose();
      p.value.dispose();
    }
    super.dispose();
  }

  /// 把当前参数行重新组装回 URL 的 query / Rebuild the URL query from the rows
  String _rebuildUrl() {
    final map = <String, String>{};
    for (final p in _params) {
      final k = p.key.text.trim();
      if (k.isEmpty) continue;
      map[k] = p.value.text;
    }
    try {
      final uri = Uri.parse(widget.request.url);
      return uri.replace(queryParameters: map).toString();
    } catch (_) {
      return widget.request.url;
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _responseText = null;
    });
    final client = http.Client();
    try {
      final req = buildReplayRequest(widget.request, url: _rebuildUrl());
      final start = DateTime.now();
      final streamed = await client.send(req);
      final response = await http.Response.fromStream(streamed);
      final elapsed = DateTime.now().difference(start);
      final preview = response.body.length > 400
          ? '${response.body.substring(0, 400)}…'
          : response.body;
      if (mounted) {
        setState(() {
          _responseText =
              'Status: ${response.statusCode}  ·  ${elapsed.inMilliseconds} ms\n\n'
              '$preview';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _responseText = 'Replay failed: $e');
      }
    } finally {
      client.close();
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 14,
        right: 14,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: InspectorColors.backgroundStart,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: BorderSide(color: InspectorColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.replay_rounded,
                    size: 16,
                    color: InspectorColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Replay Request',
                    style: TextStyle(
                      color: InspectorColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _label('URL (read-only)'),
              _readOnlyBox(r.url),
              const SizedBox(height: 10),
              _label('Query Parameters (editable)'),
              for (final p in _params) _paramRow(p),
              TextButton.icon(
                onPressed: () => setState(() => _params.add(_ParamRow('', ''))),
                icon: Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: InspectorColors.info,
                ),
                label: Text(
                  'Add parameter',
                  style: TextStyle(color: InspectorColors.info, fontSize: 11),
                ),
              ),
              const SizedBox(height: 10),
              _label('Headers (read-only)'),
              _readOnlyBlock(
                r.headers == null || r.headers!.isEmpty
                    ? '(none)'
                    : r.headers!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
              ),
              const SizedBox(height: 10),
              _label('Body (read-only)'),
              _readOnlyBlock(r.body?.toString() ?? '(none)'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: InspectorColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(_sending ? 'Sending…' : 'Send'),
              ),
              if (_responseText != null) ...[
                const SizedBox(height: 12),
                _label('Response'),
                _readOnlyBlock(
                  _responseText!,
                  textColor: InspectorColors.textPrimary,
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        color: InspectorColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// 单行只读展示（如 URL）/ A single-line read-only box (e.g. URL)
  Widget _readOnlyBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: InspectorColors.surface,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: InspectorColors.border, width: 0.5),
    ),
    child: SelectableText(
      text,
      style: TextStyle(
        color: InspectorColors.textSecondary,
        fontSize: 11.5,
        fontFamily: 'monospace',
        height: 1.4,
      ),
    ),
  );

  /// 多行只读展示（如 headers / body / response）/
  /// A multi-line read-only block (e.g. headers / body / response)
  Widget _readOnlyBlock(String text, {Color? textColor}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: InspectorColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: InspectorColors.border, width: 0.5),
    ),
    child: SelectableText(
      text,
      style: TextStyle(
        color: textColor ?? InspectorColors.textSecondary,
        fontSize: 11.5,
        fontFamily: 'monospace',
        height: 1.4,
      ),
    ),
  );

  Widget _paramRow(_ParamRow p) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(flex: 2, child: _textField(p.key)),
        const SizedBox(width: 6),
        Expanded(flex: 3, child: _textField(p.value)),
        IconButton(
          icon: Icon(
            Icons.remove_circle_outline_rounded,
            size: 16,
            color: InspectorColors.textHint,
          ),
          onPressed: () => setState(() {
            p.key.dispose();
            p.value.dispose();
            _params.remove(p);
            if (_params.isEmpty) _params.add(_ParamRow('', ''));
          }),
        ),
      ],
    ),
  );

  Widget _textField(TextEditingController c) => TextField(
    controller: c,
    style: TextStyle(
      color: InspectorColors.textPrimary,
      fontSize: 11.5,
      fontFamily: 'monospace',
    ),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: InspectorColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: InspectorColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: InspectorColors.border, width: 1),
      ),
    ),
  );
}

/// 可编辑的查询参数行：持有自己的两个 [TextEditingController]
/// An editable query-parameter row: owns its two [TextEditingController]s
class _ParamRow {
  final TextEditingController key;
  final TextEditingController value;
  _ParamRow(String k, String v)
    : key = TextEditingController(text: k),
      value = TextEditingController(text: v);
}

/// 显示可编辑重放弹窗 / Show the editable replay sheet
void showReplayEditor(BuildContext context, NetworkRequest request) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InspectorReplayEditor(request: request),
  );
}
