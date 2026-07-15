import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/network_request.dart';
import '../services/inspector_service.dart';

/// 网络请求查看器
/// 显示所有捕获的网络请求，支持查看详细信息
class NetworkViewer extends StatefulWidget {
  const NetworkViewer({super.key});

  @override
  State<NetworkViewer> createState() => _NetworkViewerState();
}

class _NetworkViewerState extends State<NetworkViewer> {
  /// 当前选中的请求
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
                    child: ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) => _buildRequestItem(requests[index]),
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
                '${InspectorService.instance.networkRequests.length} Requests',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => InspectorService.instance.clearNetworkRequests(),
                icon: const Icon(Icons.delete, color: Colors.grey, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个请求项
  Widget _buildRequestItem(NetworkRequest request) {
    final isSelected = _selectedRequest?.id == request.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedRequest = request),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2d2d44) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _getStatusColor(request.status),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMethodColor(request.method),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request.method,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.url,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  request.durationText,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            if (request.statusCode != null)
              Text(
                'Status: ${request.statusCode}',
                style: TextStyle(color: _getStatusColor(request.status), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建请求详情面板
  Widget _buildRequestDetail(NetworkRequest request) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF2d2d44))),
      ),
      child: ListView(
        children: [
          const Text(
            'Request',
            style: TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDetailSection('Method', request.method),
          _buildDetailSection('URL', request.url),
          if (request.headers != null)
            _buildDetailSection('Headers', _formatJson(request.headers)),
          if (request.body != null)
            _buildDetailSection('Body', _formatJson(request.body)),
          const SizedBox(height: 16),
          const Text(
            'Response',
            style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildDetailSection('Status', request.statusCode?.toString() ?? '-'),
          _buildDetailSection('Duration', request.durationText),
          if (request.responseBody != null)
            _buildDetailSection('Body', _formatJson(request.responseBody)),
        ],
      ),
    );
  }

  /// 构建详情分段
  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF16213e),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Monaco'),
            overflow: TextOverflow.visible,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 根据状态码获取颜色
  Color _getStatusColor(int status) {
    if (status >= 200 && status < 300) return Colors.greenAccent;
    if (status >= 300 && status < 400) return Colors.yellowAccent;
    if (status >= 400 && status < 500) return Colors.orangeAccent;
    if (status >= 500) return Colors.redAccent;
    return Colors.grey;
  }

  /// 根据HTTP方法获取颜色
  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.greenAccent;
      case 'POST':
        return Colors.blueAccent;
      case 'PUT':
        return Colors.yellowAccent;
      case 'DELETE':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  /// 格式化JSON数据
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