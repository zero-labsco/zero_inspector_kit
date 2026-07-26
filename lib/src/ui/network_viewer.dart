import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/network_request.dart';
import '../models/interceptor_rule.dart';
import '../services/inspector_service.dart';
import 'theme/inspector_theme.dart';

/// 网络请求查看器 / Network request viewer
/// 显示所有捕获的网络请求，支持搜索和查看详细信息 / Display all captured network requests, support search and viewing details
class NetworkViewer extends StatefulWidget {
  const NetworkViewer({super.key});

  @override
  State<NetworkViewer> createState() => _NetworkViewerState();
}

class _NetworkViewerState extends State<NetworkViewer> {
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  NetworkRequest? _selectedRequest;
  RequestInterceptorRule? _editingRule;
  bool _showInterceptorPanel = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildSearchBar(),
        Expanded(
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: InspectorService.instance,
                builder: (context, child) {
                  if (_selectedRequest != null) {
                    return _buildRequestDetail(_selectedRequest!);
                  }
                  return _buildRequestList();
                },
              ),
              if (_showInterceptorPanel &&
                  _editingRule != null &&
                  _selectedRequest != null)
                _InterceptorRulePanel(
                  request: _selectedRequest!,
                  rule: _editingRule!,
                  onUpdate: _updateEditingRule,
                  onSave: _saveRule,
                  onDelete: _deleteRule,
                ),
            ],
          ),
        ),
      ],
    );
  }

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
              if (_selectedRequest != null)
                _buildIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () {
                    setState(() {
                      _selectedRequest = null;
                      _showInterceptorPanel = false;
                    });
                  },
                ),
              _buildCountBadge(
                '${InspectorService.instance.networkRequests.length}',
              ),
              const SizedBox(width: 8),
              Text(
                _selectedRequest != null ? 'Request Detail' : 'Requests',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_selectedRequest != null)
                _buildIconButton(
                  icon: Icons.edit_note_rounded,
                  tooltip: 'Interceptor',
                  onTap: () => _showInterceptorEditor(),
                  color: InspectorColors.accent,
                ),
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

  Widget _buildSearchBar() {
    if (_selectedRequest != null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchKeyword = value),
        style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search URL, method...',
          hintStyle: TextStyle(color: InspectorColors.textHint, fontSize: 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: InspectorColors.textSecondary,
          ),
          suffixIcon: _searchKeyword.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchKeyword = '');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: InspectorColors.textSecondary,
                  ),
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          filled: true,
          fillColor: InspectorColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              InspectorDimensions.smallRadius,
            ),
            borderSide: BorderSide(color: InspectorColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              InspectorDimensions.smallRadius,
            ),
            borderSide: BorderSide(color: InspectorColors.border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              InspectorDimensions.smallRadius,
            ),
            borderSide: BorderSide(color: InspectorColors.accent, width: 1),
          ),
        ),
      ),
    );
  }

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

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                color: color ?? InspectorColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<NetworkRequest> _filterRequests(List<NetworkRequest> requests) {
    if (_searchKeyword.isEmpty) return requests;
    final keyword = _searchKeyword.toLowerCase();
    return requests.where((req) {
      return req.url.toLowerCase().contains(keyword) ||
          req.method.toLowerCase().contains(keyword);
    }).toList();
  }

  Widget _buildRequestList() {
    final requests = _filterRequests(InspectorService.instance.networkRequests);

    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.http_rounded,
                size: 36,
                color: InspectorColors.textHint,
              ),
              const SizedBox(height: 12),
              Text(
                _searchKeyword.isEmpty
                    ? 'No requests yet'
                    : 'No matching requests',
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestItem(requests[index]),
    );
  }

  Widget _buildRequestItem(NetworkRequest request) {
    final hasRule =
        InspectorService.instance.findMatchingRule(
          request.url,
          request.method,
        ) !=
        null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedRequest = request),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
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
                  if (hasRule)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 14,
                        color: InspectorColors.accent,
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

  String _getHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return '';
    }
  }

  Widget _buildRequestDetail(NetworkRequest request) {
    final hasRule =
        InspectorService.instance.findMatchingRule(
          request.url,
          request.method,
        ) !=
        null;

    return Container(
      padding: const EdgeInsets.all(14),
      color: InspectorColors.surface,
      child: ListView(
        children: [
          if (hasRule)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: InspectorColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  InspectorDimensions.smallRadius,
                ),
                border: Border.all(color: InspectorColors.accent, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: InspectorColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Interceptor enabled for this request',
                    style: TextStyle(
                      color: InspectorColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showInterceptorEditor(),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: InspectorColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  Color _getStatusColor(int status) {
    if (status >= 200 && status < 300) return InspectorColors.statusSuccess;
    if (status >= 300 && status < 400) return InspectorColors.statusRedirect;
    if (status >= 400 && status < 500) return InspectorColors.statusClientError;
    if (status >= 500) return InspectorColors.statusServerError;
    return InspectorColors.textSecondary;
  }

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

  String _formatJson(dynamic data) {
    if (data == null) return 'null';
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  void _showInterceptorEditor() {
    final request = _selectedRequest!;
    final existingRule = InspectorService.instance.findMatchingRule(
      request.url,
      request.method,
    );

    setState(() {
      _editingRule =
          existingRule ??
          RequestInterceptorRule(
            id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
            name: 'Rule for ${request.method} ${_getHost(request.url)}',
            urlPattern: request.url,
            method: request.method,
            enabled: true,
            useRegex: false,
          );
      _showInterceptorPanel = true;
    });
  }

  void _saveRule() {
    if (_editingRule != null) {
      InspectorService.instance.addInterceptorRule(_editingRule!);
      setState(() {
        _showInterceptorPanel = false;
        _editingRule = null;
      });
    }
  }

  void _deleteRule() {
    if (_editingRule != null) {
      InspectorService.instance.removeInterceptorRule(_editingRule!.id);
      setState(() {
        _showInterceptorPanel = false;
        _editingRule = null;
      });
    }
  }

  void _updateEditingRule(RequestInterceptorRule rule) {
    setState(() {
      _editingRule = rule;
    });
  }
}

/// 拦截规则编辑面板 / Interceptor rule editor panel
class _InterceptorRulePanel extends StatelessWidget {
  final NetworkRequest request;
  final RequestInterceptorRule rule;
  final void Function(RequestInterceptorRule) onUpdate;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _InterceptorRulePanel({
    required this.request,
    required this.rule,
    required this.onUpdate,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_rounded,
            size: 18,
            color: InspectorColors.accent,
          ),
          const SizedBox(width: 8),
          Text(
            'Edit Interceptor Rule',
            style: TextStyle(
              color: InspectorColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (rule.id.isNotEmpty &&
              InspectorService.instance.interceptorRules.any(
                (r) => r.id == rule.id,
              ))
            TextButton(
              onPressed: onDelete,
              child: Text(
                'Delete',
                style: TextStyle(
                  color: InspectorColors.statusClientError,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRuleNameField(),
        const SizedBox(height: 16),
        _buildMatchingSection(),
        const SizedBox(height: 20),
        _buildRequestModifySection(),
        const SizedBox(height: 20),
        _buildResponseModifySection(),
      ],
    );
  }

  Widget _buildRuleNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rule Name',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: rule.name),
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: InspectorColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                InspectorDimensions.smallRadius,
              ),
              borderSide: BorderSide(color: InspectorColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                InspectorDimensions.smallRadius,
              ),
              borderSide: BorderSide(color: InspectorColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                InspectorDimensions.smallRadius,
              ),
              borderSide: BorderSide(color: InspectorColors.accent, width: 1),
            ),
          ),
          onChanged: (value) => onUpdate(rule.copyWith(name: value)),
        ),
      ],
    );
  }

  Widget _buildMatchingSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, size: 16, color: InspectorColors.info),
              const SizedBox(width: 6),
              Text(
                'Request Matching',
                style: TextStyle(
                  color: InspectorColors.info,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: rule.enabled,
                onChanged: (value) => onUpdate(rule.copyWith(enabled: value)),
                activeThumbColor: InspectorColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                rule.enabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color: rule.enabled
                      ? InspectorColors.statusSuccess
                      : InspectorColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildUrlPatternField(),
          const SizedBox(height: 10),
          _buildMethodField(),
          const SizedBox(height: 10),
          _buildRegexToggle(),
        ],
      ),
    );
  }

  Widget _buildUrlPatternField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'URL Pattern',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: TextEditingController(text: rule.urlPattern),
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: InspectorColors.accent, width: 1),
            ),
          ),
          onChanged: (value) => onUpdate(rule.copyWith(urlPattern: value)),
        ),
      ],
    );
  }

  Widget _buildMethodField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HTTP Method',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: rule.method.isNotEmpty ? rule.method : null,
          items: [
            const DropdownMenuItem(value: '', child: Text('Any')),
            const DropdownMenuItem(value: 'GET', child: Text('GET')),
            const DropdownMenuItem(value: 'POST', child: Text('POST')),
            const DropdownMenuItem(value: 'PUT', child: Text('PUT')),
            const DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
            const DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
            const DropdownMenuItem(value: 'HEAD', child: Text('HEAD')),
          ],
          onChanged: (value) => onUpdate(rule.copyWith(method: value ?? '')),
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: InspectorColors.accent, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegexToggle() {
    return Row(
      children: [
        Checkbox(
          value: rule.useRegex,
          onChanged: (value) =>
              onUpdate(rule.copyWith(useRegex: value ?? false)),
          activeColor: InspectorColors.accent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Text(
          'Use Regex',
          style: TextStyle(color: InspectorColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildRequestModifySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: InspectorColors.info,
              ),
              const SizedBox(width: 6),
              Text(
                'Modify Request',
                style: TextStyle(
                  color: InspectorColors.info,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequestBodyField(),
        ],
      ),
    );
  }

  Widget _buildRequestBodyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Request Body',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 120,
          child: TextField(
            maxLines: null,
            expands: true,
            controller: TextEditingController(
              text: rule.requestBody != null
                  ? (rule.requestBody is String
                        ? rule.requestBody
                        : const JsonEncoder.withIndent(
                            '  ',
                          ).convert(rule.requestBody))
                  : (request.body != null
                        ? (request.body is String
                              ? request.body
                              : const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(request.body))
                        : ''),
            ),
            style: TextStyle(
              color: InspectorColors.textPrimary,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: InspectorColors.accent, width: 1),
              ),
            ),
            onChanged: (value) {
              dynamic parsedBody;
              try {
                parsedBody = jsonDecode(value);
              } catch (_) {
                parsedBody = value;
              }
              onUpdate(rule.copyWith(requestBody: parsedBody));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResponseModifySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: InspectorColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                'Modify Response',
                style: TextStyle(
                  color: InspectorColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildResponseStatusCodeField(),
          const SizedBox(height: 10),
          _buildResponseBodyField(),
        ],
      ),
    );
  }

  Widget _buildResponseStatusCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Code',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(
            text:
                rule.responseStatusCode?.toString() ??
                request.statusCode?.toString() ??
                '',
          ),
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Leave empty to use original',
            hintStyle: TextStyle(color: InspectorColors.textHint, fontSize: 11),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: InspectorColors.accent, width: 1),
            ),
          ),
          onChanged: (value) {
            final code = int.tryParse(value);
            onUpdate(rule.copyWith(responseStatusCode: code));
          },
        ),
      ],
    );
  }

  Widget _buildResponseBodyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Response Body',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 150,
          child: TextField(
            maxLines: null,
            expands: true,
            controller: TextEditingController(
              text: rule.responseBody != null
                  ? (rule.responseBody is String
                        ? rule.responseBody
                        : const JsonEncoder.withIndent(
                            '  ',
                          ).convert(rule.responseBody))
                  : (request.responseBody != null
                        ? (request.responseBody is String
                              ? request.responseBody
                              : const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(request.responseBody))
                        : ''),
            ),
            style: TextStyle(
              color: InspectorColors.textPrimary,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Leave empty to use original',
              hintStyle: TextStyle(
                color: InspectorColors.textHint,
                fontSize: 11,
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: InspectorColors.accent, width: 1),
              ),
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                onUpdate(rule.copyWith(responseBody: null));
                return;
              }
              dynamic parsedBody;
              try {
                parsedBody = jsonDecode(value);
              } catch (_) {
                parsedBody = value;
              }
              onUpdate(rule.copyWith(responseBody: parsedBody));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: InspectorColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: InspectorColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    InspectorDimensions.smallRadius,
                  ),
                ),
              ),
              child: Text(
                'Save Rule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
