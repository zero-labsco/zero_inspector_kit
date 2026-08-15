import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/widget_tree_node.dart';
import 'package:zero_inspector_kit/src/ui/inspector_panel.dart';

/// Widget 检查器单元测试 / Widget inspector unit tests.
///
/// 验证 buildWidgetTree 能采集业务树、正确排除 InspectorPanel 子树，
/// 并保持深度递增。在 testWidgets 上下文里真实挂载一棵 widget 树。
/// Verifies buildWidgetTree captures the business tree, excludes the
/// InspectorPanel subtree, keeps depth increasing, and extracts size/color.
void main() {
  testWidgets(
    'buildWidgetTree captures business widgets and excludes InspectorPanel / 采集业务树并排除检查器自身',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('hi', key: ValueKey('leaf')),
                const InspectorPanel(onClose: _noop),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tree = buildWidgetTree();

      // 根之下应能看到 MaterialApp（业务树起点）
      // The business tree root should be reachable below the root.
      final names = _collectNames(tree);
      expect(names, contains('MaterialApp'));
      expect(names, contains('Scaffold'));
      expect(names, contains('Column'));
      expect(names, contains('Text'));

      // InspectorPanel 不应出现在树中
      // InspectorPanel must not appear in the tree.
      expect(names, isNot(contains('InspectorPanel')));
    },
  );

  testWidgets('depth increases by exactly 1 per level / 深度每层 +1', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: const Center(child: Text('x'))),
      ),
    );
    await tester.pumpAndSettle();
    final tree = buildWidgetTree();
    // 校验任意节点的 children depth 等于父 depth + 1。
    var ok = true;
    void walk(WidgetTreeNode n) {
      for (final c in n.children) {
        if (c.depth != n.depth + 1) ok = false;
        walk(c);
      }
    }

    walk(tree);
    expect(ok, isTrue);
  });

  testWidgets('captures rendered size and color property / 采集尺寸与颜色', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            // 固定尺寸，便于断言渲染尺寸
            // Fixed size so the rendered size is deterministic.
            width: 120,
            height: 80,
            color: const Color(0xFFFF0000),
            child: const Text('x'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tree = buildWidgetTree();

    final container = _findFirst(tree, 'Container');
    expect(container, isNotNull, reason: 'Container should be in the tree');

    // 渲染尺寸应反映真实的 120 × 80
    // Rendered size should reflect the real 120 × 80.
    expect(container!.size, '120 × 80');

    // 视觉属性中应能提取出颜色（Container 以 'bg' 暴露，值为 Color），
    // 且携带 Color 用于色块预览。
    // A color swatch should be extractable (Container exposes it as 'bg' whose
    // value is a Color) and the Color must be carried for the swatch.
    final colored = container.properties.where((p) => p.color != null);
    expect(
      colored,
      isNotEmpty,
      reason: 'a color swatch property should be extracted',
    );
    expect(colored.first.color, isA<Color>());
    expect(colored.first.value, contains('Color'));
  });

  testWidgets('findTreeRoot skips shell, root shows real size / 跳过外壳，根显示真实尺寸', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: const Text('x'))));
    await tester.pumpAndSettle();
    final tree = buildWidgetTree();
    // 业务树根已跳过外壳，尺寸不应再是占位符 '—'，且不应是私有外壳节点。
    // The business root skips the shell: its size is real (not '—') and it is
    // not a private framework shell node.
    expect(tree.size, isNot('—'));
    expect(tree.name.startsWith('_'), isFalse);
  });

  testWidgets('findTreeRoot descends to first RenderBox / 下探到首个渲染框', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: const Text('x'))));
    await tester.pumpAndSettle();
    final raw = WidgetsBinding.instance.rootElement!;
    final businessRoot = findTreeRoot(raw);
    // 结果必须是带 RenderBox 的节点（业务根），而非顶部外壳（RenderView）。
    // The result must be a node with a RenderBox (the business root), not the
    // top shell (RenderView).
    expect(businessRoot.renderObject, isA<RenderBox>());
    // 且它应当是公开的业务节点，而非私有外壳。
    // And it should be a public business node, not a private shell.
    expect(businessRoot.widget.runtimeType.toString().startsWith('_'), isFalse);
  });

  testWidgets('colored widget and textStyle color are extracted / 颜色与文本色都被提取', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColoredBox(
            color: const Color(0xFF34C759),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: const Text(
                'x',
                style: TextStyle(color: Color(0xFFFFFFFF)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final tree = buildWidgetTree();

    // ColoredBox 的 color（绿色）应被抽出。
    // ColoredBox's color (green) should be extracted.
    final coloredBox = _findFirst(tree, 'ColoredBox');
    expect(coloredBox, isNotNull);
    expect(
      coloredBox!.properties.where((p) => p.color != null),
      isNotEmpty,
      reason: 'ColoredBox should yield a color swatch',
    );

    // 带 TextStyle(color) 的 Text 也应从 textStyle 复合属性里抽到颜色。
    // A Text with TextStyle(color) should also surface a color via textStyle.
    final text = _findFirst(tree, 'Text');
    expect(text, isNotNull);
    expect(
      text!.properties.where((p) => p.color != null),
      isNotEmpty,
      reason: 'Text with TextStyle.color should yield a color swatch',
    );
  });
}

/// 按 widget 运行时类型名（首部匹配）在整棵树里找到第一个节点。
/// Finds the first node whose runtime type name starts with [name] anywhere in
/// the tree (depth-first).
WidgetTreeNode? _findFirst(WidgetTreeNode node, String name) {
  if (node.name.startsWith(name)) return node;
  for (final c in node.children) {
    final found = _findFirst(c, name);
    if (found != null) return found;
  }
  return null;
}

List<String> _collectNames(WidgetTreeNode node) {
  final out = [node.name];
  for (final c in node.children) {
    out.addAll(_collectNames(c));
  }
  return out;
}

void _noop() {}
