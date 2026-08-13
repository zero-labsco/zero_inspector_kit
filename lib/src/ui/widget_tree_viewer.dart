import 'package:flutter/material.dart';

import '../models/widget_tree_node.dart';
import 'theme/inspector_theme.dart';
import 'widgets/inspector_state_views.dart';

/// Widget 检查器 / Widget inspector.
///
/// 以**面包屑导航**方式浏览 widget 树（类似文件管理器）：主列表只显示**当前
/// 层级**的节点，点击含子节点的项即下钻到它的下一层，顶部分层面包屑可一键
/// 跳回任意祖先层。叶子节点（无子节点）点击弹出底部抽屉查看详情。这种方式在
/// 移动端窄屏下无需横滑、不会溢出，层级关系依然清晰。检查器会自动排除自身
/// 浮层。
///
/// Browses the widget tree via **breadcrumb navigation** (like a file manager):
/// the main list shows only the **current level**; tapping an item with children
/// drills into its children, and the breadcrumb bar jumps back to any ancestor.
/// Tapping a leaf opens a bottom-sheet detail. No horizontal scrolling, no
/// overflow on narrow screens, while the hierarchy stays clear. The inspector's
/// own overlay is excluded automatically.
class WidgetTreeInspector extends StatefulWidget {
  const WidgetTreeInspector({super.key});

  @override
  State<WidgetTreeInspector> createState() => _WidgetTreeInspectorState();
}

/// 面包屑路径上的一段 / One segment in the breadcrumb path.
class _Crumb {
  const _Crumb(this.label, this.node);

  final String label;
  final WidgetTreeNode node;
}

class _WidgetTreeInspectorState extends State<WidgetTreeInspector> {
  WidgetTreeNode? _root;

  // 当前所在层的祖先链（从根到当前层父节点），用于面包屑。
  // Ancestor chain to the current level (root .. current parent), for breadcrumb.
  final List<_Crumb> _path = [];

  @override
  void initState() {
    super.initState();
    // Widget Inspector 默认开启，直接进入即快照树。首帧完成后刷新，
    // 避免 "visitChildElements() called during build"。
    // Widget Inspector is on by default, so we snapshot the tree right away
    // (after the first frame to avoid "visitChildElements() during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _root = buildWidgetTree();
      _path.clear();
    });
  }

  /// 当前层要展示的节点列表：根层显示 root 的子节点，否则显示 _path 末端的
  /// 子节点。Drill into a node: push it onto the path.
  List<WidgetTreeNode> get _currentChildren {
    if (_root == null) return const [];
    final parent = _path.isEmpty ? _root! : _path.last.node;
    return parent.children;
  }

  void _drillInto(WidgetTreeNode node) {
    if (node.childCount == 0) {
      _showDetails(node);
      return;
    }
    setState(() {
      _path.add(_Crumb(node.name, node));
    });
  }

  /// 跳回面包屑的第 [depth] 层（0 = 根层）。Navigate back to breadcrumb level.
  void _jumpTo(int depth) {
    setState(() {
      while (_path.length > depth) {
        _path.removeLast();
      }
    });
  }

  void _showDetails(WidgetTreeNode node) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: InspectorColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(InspectorDimensions.cardRadius),
        ),
      ),
      builder: (ctx) => _DetailSheet(node: node),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_root == null || (_root!.childCount == 0 && _root!.name == 'Root')) {
      return Column(
        children: [
          const Expanded(
            child: InspectorEmptyState(message: 'No widget tree available'),
          ),
          _buildToolbar(),
        ],
      );
    }

    final children = _currentChildren;

    return Column(
      children: [
        _BreadcrumbBar(
          crumbs: _path,
          rootLabel: _root!.name,
          onTapCrumb: _jumpTo,
          onTapRoot: () => _jumpTo(0),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          // 当前层列表：只有一层节点，宽度恒等于面板宽，无需横滑、不会溢出。
          // Current-level list: a single level of nodes, always panel-wide — no
          // horizontal scroll, no overflow.
          child: children.isEmpty
              ? const InspectorEmptyState(message: 'No children at this level')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: children.length,
                  itemBuilder: (ctx, i) {
                    final node = children[i];
                    return _LevelRow(node: node, onTap: () => _drillInto(node));
                  },
                ),
        ),
        _buildToolbar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Re-snapshot tree (not live; tap to refresh)',
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Snapshot only · not live · tap a node to drill in',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: InspectorColors.textHint),
            ),
          ),
          if (_path.isNotEmpty)
            TextButton(
              onPressed: () => _jumpTo(0),
              child: Text(
                'Up to root',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: InspectorColors.accent),
              ),
            ),
        ],
      ),
    );
  }
}

/// 面包屑导航条：Root > A > B，点击任意段跳回该层。
/// Breadcrumb bar: Root > A > B; tap any segment to jump back to that level.
class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.crumbs,
    required this.rootLabel,
    required this.onTapCrumb,
    required this.onTapRoot,
  });

  final List<_Crumb> crumbs;
  final String rootLabel;
  final ValueChanged<int> onTapCrumb;
  final VoidCallback onTapRoot;

  @override
  Widget build(BuildContext context) {
    final segments = <Widget>[_CrumbChip(label: rootLabel, onTap: onTapRoot)];
    for (var i = 0; i < crumbs.length; i++) {
      segments.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: InspectorColors.textHint,
          ),
        ),
      );
      segments.add(
        _CrumbChip(label: crumbs[i].label, onTap: () => onTapCrumb(i + 1)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(children: segments),
      ),
    );
  }
}

class _CrumbChip extends StatelessWidget {
  const _CrumbChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: InspectorColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: InspectorColors.accent),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// 当前层中的一行（节点）。整行宽度等于面板宽，点击下钻或看详情。
/// A row in the current level. Its width equals the panel width; tap to drill
/// in or view details.
class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.node, required this.onTap});

  final WidgetTreeNode node;
  final VoidCallback onTap;

  bool get hasChildren => node.childCount > 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: InspectorColors.border.withValues(alpha: 0.6),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                hasChildren ? Icons.folder_rounded : Icons.widgets_rounded,
                size: 16,
                color: hasChildren
                    ? InspectorColors.accent
                    : InspectorColors.textHint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  node.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: InspectorColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (node.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    node.key,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: InspectorColors.textHint,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  hasChildren ? '${node.childCount}' : 'leaf',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: InspectorColors.textHint,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                hasChildren
                    ? Icons.chevron_right_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: InspectorColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部抽屉中展示节点详情 / Node details shown in the bottom sheet.
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.node});

  final WidgetTreeNode node;

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Widget', node.name),
      ('Key', node.key.isEmpty ? '(none)' : node.key),
      ('Depth', '${node.depth}'),
      ('Children', '${node.childCount}'),
      ('Type', node.runtimeType.toString()),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: InspectorColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Widget details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: InspectorColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ...fields.map((f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${f.$1}:  ',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: InspectorColors.textHint,
                        ),
                      ),
                      TextSpan(
                        text: f.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: InspectorColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  softWrap: true,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
