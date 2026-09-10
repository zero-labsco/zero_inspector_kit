import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/inspector_theme.dart';

/// JSON 折叠树查看器 / Collapsible JSON tree viewer
///
/// 此前响应体只能用 `JsonEncoder.withIndent` 做纯缩进的纯文本展示：没有语法
/// 高亮、不能折叠、无法搜索，深层嵌套的响应只能靠肉眼扫。
/// Response bodies were previously rendered as indented plain text only: no
/// syntax highlighting, no collapsing, no search — digging into nested payloads
/// was pure eyeballing.
///
/// 本组件提供 / This widget provides:
/// - 按类型着色的键与值 / type-colored keys and values
/// - 逐节点折叠 / 展开 / per-node collapse / expand
/// - 全部展开 / 折叠 / expand-all / collapse-all
/// - 关键字搜索（命中节点自动展开并高亮）/ keyword search (auto-expands hits)
class InspectorJsonView extends StatefulWidget {
  /// 原始 JSON 文本（解析失败时按纯文本渲染）
  /// Raw JSON text (falls back to plain text when it cannot be parsed)
  final String text;

  /// 最大渲染节点数，超出后其余节点折叠为占位（避免超大响应卡死 UI）
  /// Max rendered nodes; the rest collapse into a placeholder so huge payloads
  /// can't freeze the UI.
  final int maxNodes;

  const InspectorJsonView({super.key, required this.text, this.maxNodes = 500});

  @override
  State<InspectorJsonView> createState() => _InspectorJsonViewState();
}

class _InspectorJsonViewState extends State<InspectorJsonView> {
  /// 折叠状态：节点路径 -> 是否已展开 / Collapse state: node path -> expanded
  final Map<String, bool> _expanded = {};

  /// 搜索输入框控制器 / Search field controller
  final TextEditingController _searchController = TextEditingController();

  /// 搜索关键字 / Search keyword
  String _keyword = '';

  /// 是否全展开 / Whether everything is expanded
  bool _allExpanded = false;

  /// 已渲染节点计数（本帧）/ Rendered node counter (per build)
  int _renderedNodes = 0;

  /// 解析失败时保留的错误信息 / Error message retained when parsing fails
  Object? _parseError;

  /// 解析结果 / Parsed value
  Object? _root;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant InspectorJsonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded.clear();
      _parse();
    }
  }

  void _parse() {
    _parseError = null;
    _root = null;
    try {
      _root = jsonDecode(widget.text);
    } catch (e) {
      _parseError = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parseError != null) {
      // 不是合法 JSON：退回等宽纯文本，不丢内容。
      // Not valid JSON: fall back to monospaced plain text, losing nothing.
      return _buildPlainText(widget.text);
    }
    _renderedNodes = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolbar(),
        const SizedBox(height: 6),
        Flexible(
          child: SingleChildScrollView(
            child: _buildNode(
              path: r'$',
              keyLabel: null,
              value: _root,
              depth: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.data_object_rounded,
              size: 13,
              color: InspectorColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              'JSON',
              style: TextStyle(
                color: InspectorColors.textHint,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _toolbarButton('Expand all', _expandAll),
            const SizedBox(width: 4),
            _toolbarButton('Collapse all', _collapseAll),
          ],
        ),
        const SizedBox(height: 4),
        // 搜索：命中节点会被高亮，并自动全部展开以便定位。
        // Search: matching nodes are highlighted and everything auto-expands so
        // hits are reachable.
        SizedBox(
          height: 28,
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: InspectorColors.textPrimary, fontSize: 11),
            onChanged: (v) => setState(() {
              _keyword = v;
              if (v.isNotEmpty) _allExpanded = true;
            }),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              hintText: 'Search keys / values',
              hintStyle: TextStyle(
                color: InspectorColors.textHint,
                fontSize: 11,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 14,
                color: InspectorColors.textHint,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 26,
                minHeight: 26,
              ),
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
          ),
        ),
      ],
    );
  }

  Widget _toolbarButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(color: InspectorColors.info, fontSize: 10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _expandAll() => setState(() {
    _allExpanded = true;
    _expanded.clear();
  });

  void _collapseAll() => setState(() {
    _allExpanded = false;
    _expanded.clear();
    _keyword = '';
    _searchController.clear();
  });

  Widget _buildPlainText(String text) {
    return SelectableText(
      text,
      style: TextStyle(
        color: InspectorColors.textPrimary,
        fontSize: 11.5,
        fontFamily: 'monospace',
        height: 1.45,
      ),
    );
  }

  /// 是否为可展开的容器 / Whether the value is an expandable container
  bool _isBranch(Object? value) => value is Map || value is List;

  Widget _buildNode({
    required String path,
    required String? keyLabel,
    required Object? value,
    required int depth,
  }) {
    // 节点预算：超限时给出占位而不是继续展开整棵树。
    // Node budget: past the cap, render a placeholder instead of the subtree.
    _renderedNodes++;
    if (_renderedNodes > widget.maxNodes) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 12.0 + 4),
        child: Text(
          '… (truncated, ${widget.maxNodes}+ nodes)',
          style: TextStyle(
            color: InspectorColors.textHint,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (!_isBranch(value)) {
      return _buildLeaf(path: path, keyLabel: keyLabel, value: value);
    }

    final expanded = _allExpanded || (_expanded[path] ?? depth == 0);
    final Iterable<MapEntry<String, Object?>> entries;
    final int count;
    final bool isMap;
    if (value case final Map map) {
      isMap = true;
      count = map.length;
      entries = map.entries.map((e) => MapEntry(e.key.toString(), e.value));
    } else {
      final list = value as List;
      isMap = false;
      count = list.length;
      entries = list.asMap().entries.map(
        (e) => MapEntry('[${e.key}]', e.value),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() {
            _allExpanded = false;
            _expanded[path] = !(_expanded[path] ?? depth == 0);
          }),
          child: Padding(
            padding: EdgeInsets.only(left: depth * 12.0, top: 2, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 14,
                  color: InspectorColors.textHint,
                ),
                if (keyLabel != null) ...[
                  const SizedBox(width: 2),
                  _highlighted(keyLabel, InspectorColors.methodGet),
                  const SizedBox(width: 2),
                  Text(
                    ':',
                    style: TextStyle(
                      color: InspectorColors.textHint,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Text(
                  isMap ? '{$count}' : '[$count]',
                  style: TextStyle(
                    color: InspectorColors.textHint,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          ...entries.map(
            (e) => _buildNode(
              path: '$path.${e.key}',
              keyLabel: e.key,
              value: e.value,
              depth: depth + 1,
            ),
          ),
      ],
    );
  }

  Widget _buildLeaf({
    required String path,
    required String? keyLabel,
    required Object? value,
  }) {
    final color = switch (value) {
      null => InspectorColors.textHint,
      String() => InspectorColors.success,
      num() => InspectorColors.warning,
      bool() => InspectorColors.methodPut,
      _ => InspectorColors.textPrimary,
    };
    final display = switch (value) {
      null => 'null',
      String() => '"$value"',
      _ => value.toString(),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 12.0 * 1 + 14),
          if (keyLabel != null) ...[
            _highlighted(keyLabel, InspectorColors.methodGet),
            const SizedBox(width: 2),
            Text(
              ':',
              style: TextStyle(color: InspectorColors.textHint, fontSize: 11.5),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索命中时高亮关键字 / Highlight the search keyword on hits
  Widget _highlighted(String text, Color baseColor) {
    if (_keyword.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: baseColor,
          fontSize: 11.5,
          fontFamily: 'monospace',
        ),
      );
    }
    final lower = text.toLowerCase();
    final needle = _keyword.toLowerCase();
    final idx = lower.indexOf(needle);
    if (idx < 0) {
      return Text(
        text,
        style: TextStyle(
          color: baseColor,
          fontSize: 11.5,
          fontFamily: 'monospace',
        ),
      );
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, idx),
            style: TextStyle(
              color: baseColor,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
          ),
          TextSpan(
            text: text.substring(idx, idx + needle.length),
            style: TextStyle(
              color: InspectorColors.backgroundStart,
              backgroundColor: InspectorColors.accent,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
          ),
          TextSpan(
            text: text.substring(idx + needle.length),
            style: TextStyle(
              color: baseColor,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
