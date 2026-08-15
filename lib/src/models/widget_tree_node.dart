import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 一个被提取出来的 widget 视觉/布局属性（用于详情抽屉展示）。
/// A single extracted visual/layout property of a widget, shown in the detail
/// sheet. [color] is non-null only when the property is a [Color], in which
/// case the UI also renders a color swatch preview next to the value text.
class WidgetProperty {
  const WidgetProperty(this.name, this.value, [this.color]);

  final String name;
  final String value;
  final Color? color;
}

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
    required this.size,
    this.constraints,
    this.properties = const [],
  });

  /// 元素类型名（如 `MaterialApp`、`Container`）/ Element type name
  final String name;

  /// 元素 key 的文本描述，无 key 时为空 / Key description (empty if none)
  final String key;

  /// 树深度（根=0）/ Tree depth (root = 0)
  final int depth;

  /// 子节点 / Child nodes
  final List<WidgetTreeNode> children;

  /// 实际渲染尺寸（`RenderBox.size`），无渲染对象时为 `'—'`。
  /// Actual rendered size (`RenderBox.size`); `'—'` when no render object.
  final String size;

  /// 实际布局约束（`RenderBox.constraints`），非盒模型或无时为 null。
  /// Actual layout constraints (`RenderBox.constraints`); null when absent.
  final String? constraints;

  /// 提取出的视觉/布局属性（颜色、内边距、对齐等）。
  /// Extracted visual/layout properties (color, padding, alignment, ...).
  final List<WidgetProperty> properties;

  int get childCount => children.length;
}

/// 想展示的视觉/布局属性白名单（避免把 internal 诊断属性也塞进 UI）。
/// Allow-list of visual/layout diagnostic properties worth showing (keeps
/// internal/noisy diagnostics out of the UI).
const Set<String> _visualPropNames = {
  'color',
  'backgroundColor',
  'foregroundColor',
  'surfaceTintColor',
  'shadowColor',
  'iconColor',
  'focusColor',
  'hoverColor',
  'splashColor',
  'highlightColor',
  'decoration',
  'padding',
  'margin',
  'alignment',
  'width',
  'height',
  'border',
  'borderRadius',
  'borderSide',
  'textStyle',
  'fontSize',
  'fontWeight',
  'fontStyle',
  'letterSpacing',
  'wordSpacing',
  'iconSize',
  'elevation',
  'shape',
  'gap',
  'spacing',
  'mainAxisAlignment',
  'crossAxisAlignment',
  'mainAxisSize',
  'clipBehavior',
  'radius',
  // Container 把 color 包进 BoxDecoration，并以 'bg'/'fg' 暴露
  // Container wraps color into a BoxDecoration and exposes it as 'bg'/'fg'.
  'bg',
  'fg',
};

/// 从当前渲染树构建 Widget 树快照。
/// 从 `WidgetsBinding.instance.rootElement` 出发，自动**排除检查器自身子树**
/// （遇到 `InspectorPanel` 类型即停止向下递归），避免把浮层 UI 混进业务树。
/// 起点会先经过 [findTreeRoot] 跳过顶部没有 `RenderBox` 的 framework 外壳节点
/// （RootWidget → View → RawView → _RawViewInternal …），让业务树首屏即可看到
/// 真实渲染尺寸，而不是一路 `-`。
///
/// Builds a snapshot of the current widget tree from
/// `WidgetsBinding.instance.rootElement`, automatically **excluding the
/// inspector's own subtree** (stops descending at `InspectorPanel` elements).
/// The starting node is first passed through [findTreeRoot] to skip the top
/// framework shell nodes that have no `RenderBox`, so the business tree shows
/// real rendered sizes on the first screen instead of all `'—'`.
WidgetTreeNode buildWidgetTree() {
  final raw = WidgetsBinding.instance.rootElement;
  if (raw == null) {
    return const WidgetTreeNode(
      name: 'Root',
      key: '',
      depth: 0,
      children: [],
      size: '—',
    );
  }
  final root = findTreeRoot(raw);
  return WidgetTreeNode(
    name: _describe(root),
    key: _keyOf(root),
    depth: 0,
    size: _sizeOf(root),
    constraints: _constraintsOf(root),
    properties: _visualProperties(root),
    children: _childrenOf(root, 1),
  );
}

/// 跳过顶部"框架外壳"节点，找到第一个带有渲染对象（`RenderBox`）的业务根。
/// Flutter 的 `rootElement` 是 `RootWidget`，其下有一串 **没有** `RenderBox`
/// 的单子节点（如 `View` / `RawView` / `_RawViewInternal`），它们的尺寸永远是
/// `-`。这些节点对用户没有信息量，因此沿唯一子节点向下走，直到遇到首个带
/// `RenderBox` 的节点即作为业务树根。
/// 如果一路都没有渲染对象（极少见），则退回原始 root，避免死循环/返回 null。
///
/// Skips the top "framework shell" nodes to find the first business root that
/// actually has a `RenderBox`. Flutter's `rootElement` is `RootWidget`, below
/// which sits a chain of **childless-render** single-child nodes (`View`,
/// `RawView`, `_RawViewInternal`) whose size is always `'—'`. We walk down the
/// only child until the first node with a `RenderBox`, which becomes the
/// business-tree root. Falls back to the original root if none is found.
/// 顶部 framework 外壳节点的类型名（无信息量，应当跳过）。
/// 除了真正的渲染根（RootWidget/View/RawView/...），还包括 MaterialApp 之上
/// 的 `MediaQuery` 及其私有作用域——它们虽然有 RenderBox 且是公开名，但代表
/// 框架注入的环境（屏幕尺寸/主题/本地化），并非用户业务树。把它们一并跳过，
/// 业务根才会落到 `MaterialApp`/`MyApp` 之下的真实首屏节点（如 `Scaffold`/
/// `Column`），而不是停在 `MediaQuery`。
/// Type names of the top framework shell nodes (no useful info, skip them).
/// Besides the real render root (RootWidget/View/RawView/...), this also includes
/// `MediaQuery` and its private scope above `MaterialApp`: although they have a
/// RenderBox and a public name, they represent framework-injected environment
/// (screen size / theme / locale), not the user's business tree. Skipping them
/// makes the business root land on the real first-screen node under
/// `MaterialApp`/`MyApp` (e.g. `Scaffold`/`Column`) instead of stopping at
/// `MediaQuery`.
const _shellNames = <String>{
  'RootWidget',
  'View',
  'RawView',
  '_RawViewInternal',
  '_ViewScope',
  '_PipelineOwnerScope',
  'RenderObjectToWidgetElement',
  '_ReusableRenderView',
  'RenderView',
  'MediaQuery',
  '_MediaQueryScope',
};

Element findTreeRoot(Element root) {
  var cur = root;
  var guard = 0;
  // 沿唯一子节点向下，跳过 framework 外壳，直到遇到首个 **既带 RenderBox 又不是
  // 外壳** 的节点。外壳（`_ViewScope` / `_PipelineOwnerScope` 等）虽可能带
  // RenderBox，但代表框架而非用户业务树。框架内部节点类型名通常以 `_` 开头，
  // 业务根（如 `MaterialApp` / `MyApp`）则是公开名。
  // Walk down the only child, skipping framework shell nodes, until the first
  // node that is BOTH a RenderBox AND not a shell. Framework internals usually
  // have private (underscore-prefixed) type names; the business root (e.g.
  // `MaterialApp` / `MyApp`) is a public name.
  while (guard++ < 64) {
    final name = cur.widget.runtimeType.toString();
    final isShell = _shellNames.contains(name) || name.startsWith('_');
    final hasBox = cur.renderObject is RenderBox;
    if (hasBox && !isShell) break;
    Element? only;
    cur.visitChildElements((c) {
      only ??= c;
    });
    if (only == null) break;
    cur = only!;
  }
  return cur;
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
        size: _sizeOf(child),
        constraints: _constraintsOf(child),
        properties: _visualProperties(child),
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

/// 实际渲染尺寸（从 `RenderBox.size` 读取），无渲染对象时返回 `'—'`。
/// Actual rendered size from `RenderBox.size`; `'—'` when unavailable.
String _sizeOf(Element element) {
  final ro = element.renderObject;
  if (ro is RenderBox) {
    final s = ro.size;
    return '${_fmt(s.width)} × ${_fmt(s.height)}';
  }
  return '—';
}

/// 实际布局约束（从 `RenderBox.constraints` 读取），非盒模型时返回 null。
/// Actual layout constraints from `RenderBox.constraints`; null when absent.
String? _constraintsOf(Element element) {
  final ro = element.renderObject;
  if (ro is RenderBox) return ro.constraints.toString();
  return null;
}

/// 从 widget 的诊断属性中提取视觉/布局属性。
/// 注意要用 `element.widget.toDiagnosticsNode()` 而非 Element 自身的诊断——
/// 后者只暴露 key/widget 引用，widget 的 `color`/`width`/`padding` 等只有在
/// widget 的诊断节点里才会出现。Color 类型的属性保留原始描述文本，同时附带
/// [Color] 以便 UI 渲染**色块预览**；其余按白名单过滤后保留原始描述。
/// Extracts visual/layout properties from the **widget's** diagnostics. We must
/// use `element.widget.toDiagnosticsNode()` rather than the Element's own
/// diagnostics — the latter only exposes the key/widget reference; the widget's
/// `color`/`width`/`padding` etc. only surface on the widget's diagnostic node.
/// Color properties keep their original description text but also carry the
/// [Color] so the UI can render a **swatch preview**; the rest are kept verbatim
/// after allow-list filtering.
List<WidgetProperty> _visualProperties(Element element) {
  final out = <WidgetProperty>[];
  final diag = element.widget.toDiagnosticsNode();
  for (final p in diag.getProperties()) {
    final name = p.name;
    if (name == null || !_visualPropNames.contains(name)) continue;
    final desc = p.toDescription();
    if (desc.isEmpty) continue;
    final value = p.value;
    final color = _extractColor(value);
    out.add(WidgetProperty(name, desc, color));
  }
  return out;
}

/// 从诊断属性值里尽量抽取一个 [Color]，用于渲染色块预览。
/// 直接是 [Color] 时原样返回；是 [BoxDecoration]（Container 的 bg/fg）时取
/// 其 `.color`；是其它 [Diagnosticable]（如 [TextStyle]、[Border]、[BorderSide]
/// 等）时递归遍历其诊断属性，找到第一个 [Color]。找不到时返回 null。
/// Best-effort extraction of a [Color] from a diagnostic property value, used to
/// render the swatch preview. Returns the value itself when it is a [Color];
/// when it is a [BoxDecoration] (Container's bg/fg) returns its `.color`; when
/// it is any other [Diagnosticable] (e.g. [TextStyle], [Border], [BorderSide])
/// recurses into its own diagnostics and returns the first [Color] found.
Color? _extractColor(Object? value) {
  if (value is Color) return value;
  if (value is BoxDecoration && value.color != null) return value.color;
  if (value is Diagnosticable) return _extractColorFromDiagnosticable(value);
  return null;
}

/// 递归遍历一个 [Diagnosticable] 的诊断属性，返回找到的第一个 [Color]。
/// 这让 `textStyle`（Text 的 `color`）、`border`（边色）、`BoxDecoration` 等
/// 复合属性也能直接抽出色块，而不仅限顶层 `color`/`bg`/`fg`。
/// Recursively walks a [Diagnosticable]'s diagnostics and returns the first
/// [Color] found, so composite properties like `textStyle` (Text's `color`),
/// `border`, and `BoxDecoration` also yield a swatch, not just top-level
/// `color`/`bg`/`fg`.
Color? _extractColorFromDiagnosticable(Diagnosticable d) {
  for (final p in d.toDiagnosticsNode().getProperties()) {
    final v = p.value;
    if (v is Color) return v;
    // 只往"窄"诊断对象递归，避免无限/过深遍历（如 RenderObject、Element）。
    // Only recurse into "narrow" diagnostic objects to avoid deep/cyclic walks.
    if (v is Diagnosticable && v is! Element && v is! RenderObject) {
      final nested = _extractColorFromDiagnosticable(v);
      if (nested != null) return nested;
    }
  }
  return null;
}

String _fmt(double d) =>
    d.truncateToDouble() == d ? d.toInt().toString() : d.toStringAsFixed(1);
