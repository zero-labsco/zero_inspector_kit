import 'package:flutter/material.dart';

import '../models/error_record.dart';
import '../services/error_service.dart';
import '../services/export_service.dart';
import 'theme/inspector_theme.dart';
import 'widgets/widgets.dart';
import 'inspector_toast.dart';

/// 异常聚合查看器 / Error aggregation viewer
///
/// 把 [ErrorService] 聚合后的异常按类型/堆栈去重展示：显示出现次数、首末次时间，
/// 点击展开完整堆栈。这是开发者控制台的核心能力——一眼看出"同一处崩溃反复出现"。
/// Shows [ErrorService] aggregated errors deduped by type/stack: count, first/last
/// seen, and an expandable full stack. Surfaces "the same crash repeating" at a glance.
class ErrorViewer extends StatefulWidget {
  const ErrorViewer({super.key});

  @override
  State<ErrorViewer> createState() => _ErrorViewerState();
}

class _ErrorViewerState extends State<ErrorViewer> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchKeyword = '';
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<ErrorRecord> _filterErrors(List<ErrorRecord> all) {
    if (_searchKeyword.isEmpty) return all;
    final kw = _searchKeyword.toLowerCase();
    return all
        .where(
          (e) =>
              e.type.toLowerCase().contains(kw) ||
              e.message.toLowerCase().contains(kw),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: ListenableBuilder(
            listenable: ErrorService.instance,
            builder: (context, child) {
              final errors = _filterErrors(
                ErrorService.instance.errors.toList(),
              );
              if (errors.isEmpty) {
                return const InspectorEmptyState(
                  icon: Icons.error_outline_rounded,
                  message: 'No errors captured',
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: errors.length,
                itemBuilder: (ctx, i) => _buildErrorItem(errors[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final count = ErrorService.instance.errorCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: InspectorColors.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchKeyword = v),
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search errors',
                  hintStyle: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: InspectorColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InspectorCountBadge('$count'),
          const SizedBox(width: 8),
          InspectorIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Clear',
            onTap: () => ErrorService.instance.clear(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorItem(ErrorRecord e) {
    final isExpanded = _expanded.contains(e.id);
    final recurred = e.count > 1;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InspectorColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(e.id);
              } else {
                _expanded.add(e.id);
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: InspectorColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.type,
                        style: TextStyle(
                          color: InspectorColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (recurred)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: InspectorColors.error.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '×${e.count}',
                          style: TextStyle(
                            color: InspectorColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: InspectorColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e.message,
                  style: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: InspectorColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'first ${_formatTime(e.firstSeen)}',
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.update_rounded,
                      size: 12,
                      color: InspectorColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'last ${_formatTime(e.lastSeen)}',
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    InspectorIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: 'Copy stack',
                      onTap: () => _copyStack(e),
                    ),
                  ],
                ),
                if (isExpanded && e.sampleStack != null)
                  _buildStack(e.sampleStack!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStack(String stack) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: InspectorColors.border, width: 1),
      ),
      width: double.infinity,
      child: SelectableText(
        stack,
        style: TextStyle(
          color: InspectorColors.textSecondary,
          fontSize: 11,
          fontFamily: 'monospace',
          height: 1.45,
        ),
      ),
    );
  }

  Future<void> _copyStack(ErrorRecord e) async {
    final messenger = Overlay.of(context, rootOverlay: true);
    final text = e.sampleStack ?? e.message;
    await ExportService.instance.copyText('${e.type}\n${e.message}\n\n$text');
    if (mounted) InspectorToast.showOn(messenger, 'Stack copied');
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
