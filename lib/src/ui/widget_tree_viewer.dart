import 'package:flutter/material.dart';

import '../models/widget_tree_node.dart';
import 'theme/inspector_theme.dart';
import 'widgets/inspector_state_views.dart';

/// Widget 检查器 / Widget inspector.
///
/// 列表式浏览：顶部面包屑 + 当前层级子节点列表（可下钻 / 返回上层）。点击节点
/// 行右侧的 ℹ 按钮，**在同视图下方的详情区**就地显示该节点的详情（实际渲染尺寸、
/// 约束与视觉/布局属性及颜色色块预览）——列表保持不动，底部空白区被利用起来，
/// 不再弹底部抽屉。详情区固定展示"当前选中节点"，点不同节点即切换，点列表中的
/// 子节点下钻时也随之更新。检查器会自动排除自身浮层。
///
/// List-style browser: a breadcrumb plus the current level's child list (drill
/// down / back up). Tapping the ℹ button on a row shows that node's details in
/// an **inline detail panel below the list** (rendered size, constraints,
/// visual/layout properties and a color swatch) — the list stays put and the
/// previously empty bottom area is now used, no bottom sheet. The detail panel
/// always shows the currently selected node; drilling into a child updates it.
/// The inspector's own overlay is excluded automatically.
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
  final _listCtrl = ScrollController();
  final _crumbCtrl = ScrollController();

  WidgetTreeNode? _root;

  /// 当前所查看层级的祖先链（根到父），用于面包屑 / 下钻返回。
  /// Ancestor chain (root .. parent), for breadcrumb / drill-back.
  final List<_Crumb> _path = [];

  /// 当前选中的、在底部详情区展示的节点。/ The node shown in the detail panel.
  WidgetTreeNode? _selected;

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
    _listCtrl.dispose();
    _crumbCtrl.dispose();
    super.dispose();
  }

  /// 切换层级后，把树列表快速定位回顶部（无论用户是否手动滑过）。
  /// Snap the tree list back to the top after a level change (whether or not the
  /// user had manually scrolled).
  void _scrollListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listCtrl.hasClients) {
        _listCtrl.jumpTo(_listCtrl.position.minScrollExtent);
      }
    });
  }

  /// 层级变化后，把顶部面包屑横向滚动到最右（当前段始终可见）。
  /// After a level change, scroll the top breadcrumb horizontally to the far
  /// right so the current segment stays visible.
  void _scrollCrumbToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_crumbCtrl.hasClients) {
        _crumbCtrl.jumpTo(_crumbCtrl.position.maxScrollExtent);
      }
    });
  }

  void _refresh() {
    setState(() {
      _root = buildWidgetTree();
      _path.clear();
      // 默认就让底部详情区展示当前（根）节点，不需要用户手动点开 info。
      // Show the current (root) node in the detail panel by default, so the user
      // doesn't have to tap info manually.
      _selected = _root;
    });
  }

  /// 当前所在层的子节点：根层显示 root 的子节点，否则显示 _path 末端的子节点。
  /// The children of the level currently shown: root's children, or the
  /// children of the element at the end of _path.
  List<WidgetTreeNode> get _currentChildren {
    if (_root == null) return const [];
    final parent = _path.isEmpty ? _root! : _path.last.node;
    return parent.children;
  }

  /// 点节点行 → 下钻进入该节点的子层级列表。
  /// Tap a node row → drill into that node's child-level list.
  void _drillInto(WidgetTreeNode node) {
    setState(() {
      _path.add(_Crumb(node.name, node));
      _selected = node;
    });
    _scrollListToTop();
    _scrollCrumbToEnd();
  }

  /// 详情区里点子节点：进入该子节点详情（仍展示在底部详情区，列表同步下钻）。
  /// 面包屑点 Root → 回到根层级（清空路径）。
  /// Breadcrumb "Root" → jump back to the root level (clear the path).
  void _popToRoot() {
    setState(() {
      _path.clear();
      _selected = _root;
    });
    _scrollListToTop();
    _scrollCrumbToEnd();
  }

  /// 面包屑点第 i 段 → 跳到该段对应的层级（截断路径到该段，而非只回退一层）。
  /// Breadcrumb segment i → jump to that level (truncate the path up to it),
  /// rather than only stepping one level up. This is what lets a crumb take
  /// you to the node it represents instead of merely returning one level.
  void _jumpToCrumb(int index) {
    setState(() {
      // index 是 crumbs 列表里的下标（0-based），跳到该段即保留 0..index。
      while (_path.length > index + 1) {
        _path.removeLast();
      }
      final node = _path.isEmpty ? _root! : _path.last.node;
      _selected = node;
    });
    _scrollListToTop();
    _scrollCrumbToEnd();
  }

  @override
  Widget build(BuildContext context) {
    if (_root == null || (_root!.childCount == 0 && _root!.name == 'Root')) {
      return Column(
        children: [
          const Expanded(
            child: InspectorEmptyState(message: 'No widget tree available'),
          ),
        ],
      );
    }

    final children = _currentChildren;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BreadcrumbBar(
                crumbs: _path,
                rootLabel: _root!.name,
                currentIndex: _path.length,
                onTapRoot: _popToRoot,
                onTapCrumb: _jumpToCrumb,
                controller: _crumbCtrl,
              ),
            ),
            // 刷新按钮置于顶部右侧，仅一个按钮，无需文字提示。
            // Refresh button sits at the top-right; just the button, no caption.
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Re-snapshot tree',
              onPressed: _refresh,
            ),
          ],
        ),
        const Divider(height: 1, thickness: 1),
        // 上方：当前层级子节点列表（可下钻）。
        // Top: the current level's child list (drill down).
        Expanded(
          flex: 3,
          child: ListView.builder(
            controller: _listCtrl,
            padding: const EdgeInsets.symmetric(vertical: 4),
            // 列表只展示当前节点的"子节点"，当前节点本身已由顶部面包屑选中标识，
            // 无需在列表里重复出现。
            // The list shows only the current node's children; the current node
            // itself is already marked by the top breadcrumb, so it is not
            // repeated here.
            itemCount: children.length,
            itemBuilder: (ctx, i) {
              final node = children[i];
              // 子节点整行点击即下钻并选中（默认下方就有详情，无需 ℹ 按钮）。
              // Tapping a child drills into and selects it (detail shows by
              // default, no info button needed).
              return _LevelRow(node: node, onTap: () => _drillInto(node));
            },
          ),
        ),
        const Divider(height: 1, thickness: 1),
        // 下方：当前选中节点的详情区（利用底部空白，非抽屉）。
        // Bottom: details of the selected node (uses the empty area, no sheet).
        Expanded(flex: 2, child: _NodeDetail(node: _selected!)),
      ],
    );
  }
}

/// 列表中的一行 / One row in the list.
class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.node, required this.onTap});

  final WidgetTreeNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.childCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
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
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: InspectorColors.textHint,
            ),
            if (hasChildren)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${node.childCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: InspectorColors.textHint,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 节点详情内容（内联在 view 底部，非底部抽屉）。可点子节点继续查看。
/// Node detail content, shown inline at the bottom of the view (not a sheet).
/// Tapping a child continues inspecting it.
///
/// 滚动定位：切换节点时强制快速回到顶部（无论用户是否手动滑过）；同一节点内
/// 用户手动滑动则不打扰。This auto-scrolls to the top on node change, but never
/// fights the user while they scroll within the same node.
class _NodeDetail extends StatefulWidget {
  const _NodeDetail({required this.node});

  final WidgetTreeNode node;

  @override
  State<_NodeDetail> createState() => _NodeDetailState();
}

class _NodeDetailState extends State<_NodeDetail> {
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant _NodeDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅当"切换到了另一个节点"才快速定位回顶部；同一节点内手动滚动不触发。
    // 用 post-frame 回调：didUpdateWidget 时新内容尚未布局完成，直接 jumpTo
    // 可能落到旧的滚动范围而失效，必须等这一帧布局结束后再跳。
    // Only jump to top when the selected node actually changes; manual scroll
    // within the same node is left untouched. Use a post-frame callback: at
    // didUpdateWidget time the new content isn't laid out yet, so a direct
    // jumpTo would target the stale scroll range and do nothing.
    if (oldWidget.node != widget.node) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) {
          _ctrl.jumpTo(_ctrl.position.minScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final fields = [
      ('Widget', node.name),
      ('Key', node.key.isEmpty ? '(none)' : node.key),
      ('Depth', '${node.depth}'),
      ('Children', '${node.childCount}'),
      ('Size', node.size),
      if (node.constraints != null) ('Constraints', node.constraints!),
    ];

    return SingleChildScrollView(
      controller: _ctrl,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...fields.map((f) => _FieldRow(f.$1, f.$2)),
          if (node.properties.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SectionLabel('Visual / layout'),
            const SizedBox(height: 4),
            ...node.properties.map((p) => _PropertyRow(p)),
          ],
          if (node.children.isNotEmpty) ...[const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

/// 一行结构字段：标签 + 值（长值自动换行，不溢出）。
/// One structural field row: label + value (long values wrap, never overflow).
class _FieldRow extends StatelessWidget {
  const _FieldRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label:  ',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: InspectorColors.textHint),
            ),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: InspectorColors.textPrimary,
              ),
            ),
          ],
        ),
        softWrap: true,
      ),
    );
  }
}

/// 分区小标题 / A small section subtitle.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: InspectorColors.accent,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// 一行视觉/布局属性：标签 + 值；颜色类属性额外渲染**色块预览**。
/// One visual/layout property row: label + value; color properties also render
/// a **swatch preview**.
class _PropertyRow extends StatelessWidget {
  const _PropertyRow(this.property);

  final WidgetProperty property;

  @override
  Widget build(BuildContext context) {
    final isColor = property.color != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              property.name,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: InspectorColors.textHint),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (isColor)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: property.color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: InspectorColors.border, width: 1),
                ),
              ),
            ),
          Expanded(
            child: Text(
              property.value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: InspectorColors.textPrimary,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// 面包屑导航条：Root > A > B，点击段跳到对应层级。
/// Breadcrumb bar: Root > A > B; tap a segment to jump to that level.
class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.crumbs,
    required this.rootLabel,
    required this.currentIndex,
    required this.onTapRoot,
    required this.onTapCrumb,
    required this.controller,
  });

  final List<_Crumb> crumbs;
  final String rootLabel;
  final int currentIndex;
  final VoidCallback onTapRoot;
  final void Function(int) onTapCrumb;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final segments = <Widget>[];
    // Root 高亮当且仅当它就是当前所在层级（_path 为空）。
    // Root is highlighted only when it IS the current level (_path is empty).
    final rootIsCurrent = currentIndex == 0;
    segments.add(
      InkWell(
        onTap: onTapRoot,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            rootLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: rootIsCurrent
                  ? InspectorColors.accent
                  : InspectorColors.textHint,
              fontWeight: rootIsCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < crumbs.length; i++) {
      // 当前所在层级（最后一段 crumb）高亮紫色，其余灰。这样紫色选中会跟随
      // 当前打开的节点移动，而不是永远停在顶部 Root。
      // The current level (last crumb) is highlighted; others stay grey, so the
      // purple "current" indicator follows the node you've opened, not Root.
      final isCurrent = currentIndex == i + 1;
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
        InkWell(
          onTap: () => onTapCrumb(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              crumbs[i].label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isCurrent
                    ? InspectorColors.accent
                    : InspectorColors.textHint,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: segments),
    );
  }
}
