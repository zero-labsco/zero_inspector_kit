import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/inspector_service.dart';

/// 日志查看器
/// 显示所有捕获的日志，支持按级别过滤
class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  /// 当前过滤的日志级别
  LogLevel? _filterLevel;

  /// 所有日志级别
  final List<LogLevel> _levels = LogLevel.values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildFilterBar(),
        Expanded(
          child: ListenableBuilder(
            listenable: InspectorService.instance,
            builder: (context, child) {
              final logs = InspectorService.instance.logEntries;
              final filteredLogs = _filterLevel != null
                  ? logs.where((e) => e.level == _filterLevel).toList()
                  : logs;

              return ListView.builder(
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) => _buildLogItem(filteredLogs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建工具栏
  Widget _buildToolbar() {
    return ListenableBuilder(
      listenable: InspectorService.instance,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF2d2d44))),
          ),
          child: Row(
            children: [
              Text(
                '${InspectorService.instance.logEntries.length} Logs',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => InspectorService.instance.clearLogs(),
                icon: const Icon(Icons.delete, color: Colors.grey, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建过滤栏
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2d2d44))),
      ),
      child: Row(
        children: [
          const Text('Filter: ', style: TextStyle(color: Colors.grey, fontSize: 11)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(null, 'All'),
                  ..._levels.map((level) => _buildFilterChip(level, _getLevelText(level))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取日志级别缩写文本
  String _getLevelText(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  /// 构建过滤标签
  Widget _buildFilterChip(LogLevel? level, String label) {
    final isSelected = _filterLevel == level;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey)),
        backgroundColor: isSelected ? Colors.blueAccent : const Color(0xFF2d2d44),
        onPressed: () => setState(() => _filterLevel = level),
      ),
    );
  }

  /// 构建单个日志项
  Widget _buildLogItem(LogEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2d2d44))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _getLevelColor(entry.level),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    entry.levelText,
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.timestampText,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              if (entry.tag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2d2d44),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.tag!,
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.message,
            style: TextStyle(color: _getLevelTextColor(entry.level), fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 根据日志级别获取背景颜色
  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return Colors.grey;
      case LogLevel.debug:
        return Colors.blueAccent;
      case LogLevel.info:
        return Colors.greenAccent;
      case LogLevel.warning:
        return Colors.yellowAccent;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }

  /// 根据日志级别获取文本颜色
  Color _getLevelTextColor(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return Colors.redAccent;
      case LogLevel.warning:
        return Colors.yellowAccent;
      default:
        return Colors.white;
    }
  }
}