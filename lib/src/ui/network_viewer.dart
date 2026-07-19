import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/network_request.dart';
import '../services/inspector_service.dart';
import 'theme/inspector_theme.dart';

/// 网络请求查看器 / Network request viewer
/// 显示所有捕获的网络请求，支持查看详细信息 / Display all captured network requests, support viewing detailed information
class NetworkViewer extends StatefulWidget {
  const NetworkViewer({super.key});

  @override
  State<NetworkViewer> createState() => _NetworkViewerState();
}

class _NetworkViewerState extends State<NetworkViewer> {
  /// 当前选中的请求 / Currently selected request
  NetworkRequest? _selectedRequest;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: ListenableBuilder(
            listenable: InspectorService.instance,
            builder: (context, child) {
              final requests = InspectorService.instance.networkRequests;

              return Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: InspectorColors.border),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) =>
                            _buildRequestItem(requests[index]),
                      ),
                    ),
                  ),
                  if (_selectedRequest != null)
                    Expanded(
                      flex: 1,
                      child: _buildRequestDetail(_selectedRequest!),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建工具栏 / Build toolbar
  Widget _buildToolbar() {
    return ListenableBuilder(
      listenable: InspectorService.instance,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            border: Border(bottom: BorderSide(color: InspectorColors.border)),
          ),
          child: Row(
            children: [
              _buildCountBadge(
                '${InspectorService.instance.networkRequests.length}',
              ),
              const SizedBox(width: 8),
              Text(
                'Requests',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Clear',
                onTap: () => InspectorService.instance.clearNetworkRequests(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建计数胶囊徽章 / Build count pill badge
  Widget _buildCountBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: InspectorColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(InspectorDimensions.smallRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: InspectorColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建图标按钮 / Build icon button
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: InspectorColors.textSecondary, size: 18),
          ),
        ),
      ),
    );
  }

  /// 构建单个请求项 / Build single request item
  Widget _buildRequestItem(NetworkRequest request) {
    final isSelected = _selectedRequest?.id == request.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedRequest = request),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? InspectorColors.selected : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _getStatusColor(request.status),
                width: 3,
              ),
              bottom: BorderSide(color: InspectorColors.divider, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getMethodColor(
                        request.method,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      request.method,
                      style: TextStyle(
                        color: _getMethodColor(request.method),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.url,
                      style: TextStyle(
                        color: InspectorColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    request.durationText,
                    style: TextStyle(
                      color: InspectorColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (request.statusCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          request.status,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${request.statusCode}',
                        style: TextStyle(
                          color: _getStatusColor(request.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _getHost(request.url),
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取URL的主机名 / Get hostname from URL
  String _getHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return '';
    }
  }

  /// 构建请求详情面板 / Build request detail panel
  Widget _buildRequestDetail(NetworkRequest request) {
    return Container(
      padding: const EdgeInsets.all(14),
      color: InspectorColors.surface,
      child: ListView(
        children: [
          _buildSectionTitle(
            'Request',
            Icons.arrow_upward_rounded,
            InspectorColors.info,
          ),
          const SizedBox(height: 10),
          _buildDetailSection('Method', request.method),
          _buildDetailSection('URL', request.url),
          if (request.headers != null)
            _buildDetailSection('Headers', _formatJson(request.headers)),
          if (request.body != null)
            _buildDetailSection('Body', _formatJson(request.body)),
          const SizedBox(height: 20),
          _buildSectionTitle(
            'Response',
            Icons.arrow_downward_rounded,
            InspectorColors.success,
          ),
          const SizedBox(height: 10),
          _buildDetailSection('Status', request.statusCode?.toString() ?? '-'),
          _buildDetailSection('Duration', request.durationText),
          if (request.responseBody != null)
            _buildDetailSection('Body', _formatJson(request.responseBody)),
        ],
      ),
    );
  }

  /// 构建分段标题 / Build section title
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 构建详情分段 / Build detail section
  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: InspectorColors.card,
              borderRadius: BorderRadius.circular(
                InspectorDimensions.cardRadius,
              ),
              border: Border.all(color: InspectorColors.border, width: 0.5),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: InspectorColors.textPrimary,
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

  /// 根据状态码获取颜色 / Get color by status code
  Color _getStatusColor(int status) {
    if (status >= 200 && status < 300) return InspectorColors.statusSuccess;
    if (status >= 300 && status < 400) return InspectorColors.statusRedirect;
    if (status >= 400 && status < 500) return InspectorColors.statusClientError;
    if (status >= 500) return InspectorColors.statusServerError;
    return InspectorColors.textSecondary;
  }

  /// 根据HTTP方法获取颜色 / Get color by HTTP method
  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return InspectorColors.methodGet;
      case 'POST':
        return InspectorColors.methodPost;
      case 'PUT':
        return InspectorColors.methodPut;
      case 'DELETE':
        return InspectorColors.methodDelete;
      case 'PATCH':
        return InspectorColors.methodPatch;
      default:
        return InspectorColors.textSecondary;
    }
  }

  /// 格式化JSON数据 / Format JSON data
  String _formatJson(dynamic data) {
    if (data == null) return 'null';
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
