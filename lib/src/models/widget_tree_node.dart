import 'package:flutter/widgets.dart';

/// Widget 树节点模型 / Widget tree node model.
///
/// 由 [buildWidgetTree] 从 Flutter 的 Element 树构建，供 Widget 检查器展示。
/// Built by [buildWidgetTree] from Flutter's Element tree for the Widget
/// inspector.
class WidgetTreeNode {
  const WidgetTreeNode({
    required this.name,
    required this.key,
    required this.depth,
    required this.children,
  });

  /// 元素类型名（如 `MaterialApp`、`Container`）/ Element type name
  final String name;

  /// 元素 key 的文本描述，无 key 时为空 / Key description (empty if none)
  final String key;

  /// 树深度（根=0）/ Tree depth (root = 0)
  final int depth;

  /// 子节点 / Child nodes
  final List<WidgetTreeNode> children;

  int get childCount => children.length;
}

/// 从当前渲染树构建 Widget 树快照。
/// 从 `WidgetsBinding.instance.renderViewElement` 出发，自动**排除检查器自身子树**
/// （遇到 `InspectorPanel` 类型即停止向下递归），避免把浮层 UI 混进业务树。
///
/// Builds a snapshot of the current widget tree from
/// `WidgetsBinding.instance.renderViewElement`, automatically **excluding the
/// inspector's own subtree** (stops descending at `InspectorPanel` elements).
WidgetTreeNode buildWidgetTree() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) {
    return const WidgetTreeNode(name: 'Root', key: '', depth: 0, children: []);
  }
  return WidgetTreeNode(
    name: _describe(root),
    key: _keyOf(root),
    depth: 0,
    children: _childrenOf(root, 1),
  );
}

List<WidgetTreeNode> _childrenOf(Element element, int depth) {
  final nodes = <WidgetTreeNode>[];
  element.visitChildElements((child) {
    // 排除检查器自身子树，保持业务树干净。
    // 用 runtimeType 名比较而非直接依赖 UI 文件，避免 models 反向依赖 ui。
    // Skip the inspector's own subtree (by type name, not a direct import,
    // to avoid a models -> ui dependency).
    if (child.widget.runtimeType.toString() == 'InspectorPanel') return;
    nodes.add(
      WidgetTreeNode(
        name: _describe(child),
        key: _keyOf(child),
        depth: depth,
        children: _childrenOf(child, depth + 1),
      ),
    );
  });
  return nodes;
}

String _describe(Element element) => element.widget.runtimeType.toString();

String _keyOf(Element element) {
  final k = element.widget.key;
  if (k == null) return '';
  if (k is ValueKey) return 'key=${k.value}';
  if (k is GlobalKey) return 'globalKey';
  return k.toString();
}
