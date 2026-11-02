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

  /// 关闭回调：由展示层（OverlayEntry / 模态）注入，用于关闭浮层。
  /// 未提供时回退到 [Navigator.of(context).pop]，以兼容旧的调用方式。
  /// Close callback injected by the presenter (OverlayEntry / dialog) to dismiss
  /// the overlay. Falls back to [Navigator.of(context).pop] when null, for
  /// backward compatibility with the old showModalBottomSheet usage.
  final VoidCallback? onClose;

  const InspectorReplayEditor({super.key, required this.request, this.onClose});

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
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
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

/// 显示可编辑重放编辑器 / Show the editable replay editor
///
/// 不用 showModalBottomSheet：本面板是插入宿主 Navigator Overlay 的浮层，
/// sheet 的 route 在嵌套 Navigator 下会被推入内层 Overlay，渲染在面板之下
/// （正是此前弹窗被主面板挡住的问题）。这里改向 root overlay 手动插入独立
/// OverlayEntry，与持久化弹层、toast 同一条已验证能显示在面板之上的通道。
/// Why not showModalBottomSheet: the inspector panel itself is an overlay layer
/// inserted into the host Navigator's Overlay. Under a nested Navigator the sheet
/// route can land on an inner Overlay and render *under* the panel (the exact bug
/// reported). Instead we insert a dedicated OverlayEntry into the root overlay —
/// the same verified channel the toast / persisted sheet use (always above panel).
void showReplayEditor(BuildContext context, NetworkRequest request) {
  final messenger = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  void close() => entry.remove();
  entry = OverlayEntry(
    builder: (_) => _ReplayEditorOverlay(request: request, onClose: close),
  );
  messenger.insert(entry);
}

/// 重放编辑器的浮层包装：全屏遮罩 + 底部对齐的编辑器卡片。
/// Overlay wrapper for the replay editor: a full-screen barrier plus a
/// bottom-aligned editor card.
class _ReplayEditorOverlay extends StatelessWidget {
  const _ReplayEditorOverlay({required this.request, required this.onClose});

  final NetworkRequest request;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 全屏遮罩：点空白关闭 / Full-screen barrier: tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
          // 底部对齐的编辑器卡片 / Bottom-aligned editor card
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screen.width,
                  maxHeight: screen.height * 0.9,
                ),
                child: InspectorReplayEditor(
                  request: request,
                  onClose: onClose,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
