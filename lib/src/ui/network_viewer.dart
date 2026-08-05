import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/network_request.dart';
import '../models/interceptor_rule.dart';
import '../services/inspector_service.dart';
import '../services/export_service.dart';
import '../utils/formatters.dart';
import 'theme/inspector_theme.dart';
import 'widgets/widgets.dart';

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
  // 只保存选中请求的 id，每次从服务持有的实时列表中解析。
  // 这样当请求对象被更新（如响应体到达 / copyWith 替换）时，
  // 详情页自动显示最新数据，避免持有过期引用导致的 UI 卡在旧状态。
  // Only keep the selected request's id and resolve it from the live list each
  // time. This keeps the detail view in sync when the request is replaced via
  // copyWith (e.g. response body arrives), avoiding a stale reference.
  String? _selectedRequestId;
  RequestInterceptorRule? _editingRule;
  bool _showInterceptorPanel = false;

  /// 导出时是否遮蔽敏感请求头（Authorization/Cookie 等）。默认开启。
  /// Whether to mask sensitive headers (Authorization/Cookie/...) on export.
  /// Enabled by default for safety.
  bool _maskSensitive = true;

  /// 批量选择模式 / Batch selection mode
  bool _selectionMode = false;

  /// 已选中的请求 id 集合 / Selected request ids
  final Set<String> _selectedIds = {};

  /// 从实时列表中解析当前选中的请求；找不到（已被淘汰）时返回 null。
  /// Resolves the selected request from the live list; null if evicted.
  NetworkRequest? get _selectedRequest {
    if (_selectedRequestId == null) return null;
    final list = InspectorService.instance.networkRequests;
    for (final r in list) {
      if (r.id == _selectedRequestId) return r;
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showInterceptorEditor() {
    final request = _selectedRequest;
    if (request == null) return;
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

  void _saveRule(RequestInterceptorRule rule) {
    InspectorService.instance.addInterceptorRule(rule);
    setState(() {
      _showInterceptorPanel = false;
      _editingRule = null;
    });
  }

  void _deleteRule(String ruleId) {
    InspectorService.instance.removeInterceptorRule(ruleId);
    setState(() {
      _showInterceptorPanel = false;
      _editingRule = null;
    });
  }

  void _closePanel() {
    setState(() {
      _showInterceptorPanel = false;
      _editingRule = null;
    });
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
                InterceptorRulePanel(
                  request: _selectedRequest!,
                  initialRule: _editingRule!,
                  onSave: _saveRule,
                  onDelete: _deleteRule,
                  onClose: _closePanel,
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
        final interceptorOn = InspectorService.instance.isInterceptorEnabled;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            border: Border(bottom: BorderSide(color: InspectorColors.border)),
          ),
          child: Row(
            children: [
              if (_selectedRequest != null)
                InspectorIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () {
                    setState(() {
                      _selectedRequestId = null;
                      _showInterceptorPanel = false;
                    });
                  },
                ),
              InspectorCountBadge(
                '${InspectorService.instance.networkRequests.length}',
              ),
              const SizedBox(width: 6),
              Text(
                _selectedRequest != null ? 'Request Detail' : 'Requests',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // 列表页：敏感字段遮蔽开关 + 批量选择入口
              // List page: sensitive-field mask toggle + batch-select entry
              if (_selectedRequest == null) ...[
                InspectorIconButton(
                  icon: _maskSensitive
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  tooltip: _maskSensitive
                      ? 'Sensitive hidden'
                      : 'Sensitive visible',
                  color: _maskSensitive ? InspectorColors.error : null,
                  onTap: () => setState(() => _maskSensitive = !_maskSensitive),
                ),
                InspectorIconButton(
                  icon: Icons.checklist_rounded,
                  tooltip: _selectionMode ? 'Exit selection' : 'Select',
                  color: _selectionMode ? InspectorColors.accent : null,
                  onTap: () => setState(() {
                    _selectionMode = !_selectionMode;
                    if (!_selectionMode) _selectedIds.clear();
                  }),
                ),
              ],
              // 拦截总开关 / Interceptor master switch（仅列表页显示）
              if (_selectedRequest == null)
                _buildInterceptorSwitch(interceptorOn),
              if (_selectedRequest != null &&
                  interceptorOn &&
                  _selectedRequest!.method.toUpperCase() != 'GET')
                InspectorIconButton(
                  icon: Icons.edit_note_rounded,
                  tooltip: 'Interceptor',
                  onTap: () => _showInterceptorEditor(),
                  color: InspectorColors.accent,
                ),
              if (_selectedRequest != null)
                InspectorIconButton(
                  icon: Icons.terminal_rounded,
                  tooltip: 'Copy as cURL',
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ExportService.instance.copy(
                      ExportService.instance.toCurl(
                        _selectedRequest!,
                        maskSensitive: _maskSensitive,
                      ),
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            _maskSensitive
                                ? 'Copied as cURL (sensitive hidden)'
                                : 'Copied as cURL',
                          ),
                        ),
                      );
                    }
                  },
                ),
              InspectorIconButton(
                icon: Icons.content_copy_rounded,
                tooltip: 'Copy as JSON',
                onTap: () async {
                  final requests = InspectorService.instance.networkRequests;
                  if (requests.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(context);
                  await ExportService.instance.copyNet(
                    requests,
                    maskSensitive: _maskSensitive,
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied ${requests.length} requests as JSON'
                          '${_maskSensitive ? ' (sensitive hidden)' : ''}',
                        ),
                      ),
                    );
                  }
                },
              ),
              if (_selectionMode)
                InspectorIconButton(
                  icon: Icons.copy_all_rounded,
                  tooltip: 'Copy selected as cURL',
                  onTap: () => _copySelectedCurl(context),
                ),
              InspectorIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: _selectionMode ? 'Delete selected' : 'Clear all',
                onTap: () {
                  if (_selectionMode) {
                    _deleteSelected();
                  } else {
                    InspectorService.instance.clearNetworkRequests();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建拦截总开关 / Build interceptor master switch
  /// 盾牌图标 + Intercept 字样，点击切换 / Shield icon + Intercept text, tap to toggle
  Widget _buildInterceptorSwitch(bool enabled) {
    return Tooltip(
      message: enabled ? 'Interceptor: ON' : 'Interceptor: OFF',
      child: GestureDetector(
        onTap: () {
          InspectorService.instance.isInterceptorEnabled = !enabled;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: enabled
                ? InspectorColors.accent.withValues(alpha: 0.15)
                : InspectorColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? InspectorColors.accent : InspectorColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled ? Icons.shield_rounded : Icons.shield_outlined,
                size: 14,
                color: enabled
                    ? InspectorColors.accent
                    : InspectorColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Intercept',
                style: TextStyle(
                  color: enabled
                      ? InspectorColors.accent
                      : InspectorColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    if (_selectedRequest != null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InspectorSearchField(
        controller: _searchController,
        hint: 'Search URL, method...',
        onClear: () {
          _searchController.clear();
          setState(() => _searchKeyword = '');
        },
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
      return InspectorEmptyState(
        message: _searchKeyword.isEmpty
            ? 'No requests yet'
            : 'No matching requests',
      );
    }

    return Column(
      children: [
        if (_selectionMode) _buildBatchBar(requests),
        Expanded(
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) => _buildRequestItem(requests[index]),
          ),
        ),
      ],
    );
  }

  /// 批量操作条 / Batch action bar
  Widget _buildBatchBar(List<NetworkRequest> requests) {
    final allSelected =
        requests.isNotEmpty &&
        requests.every((r) => _selectedIds.contains(r.id));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: InspectorColors.primary.withValues(alpha: 0.12),
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => setState(() {
              if (allSelected) {
                _selectedIds.clear();
              } else {
                _selectedIds.addAll(requests.map((r) => r.id));
              }
            }),
            child: Text(
              allSelected ? 'Deselect all' : 'Select all',
              style: TextStyle(color: InspectorColors.accent, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedIds.length} selected',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _copySelectedCurl(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final list = InspectorService.instance.networkRequests;
    final selected = list.where((r) => _selectedIds.contains(r.id)).toList();
    if (selected.isEmpty) return;
    final curl = selected
        .map(
          (r) =>
              ExportService.instance.toCurl(r, maskSensitive: _maskSensitive),
        )
        .join('\n\n');
    ExportService.instance.copy(curl);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${selected.length} cURL'
          '${_maskSensitive ? ' (sensitive hidden)' : ''}',
        ),
      ),
    );
  }

  void _deleteSelected() {
    final list = InspectorService.instance.networkRequests;
    final toRemove = list.where((r) => _selectedIds.contains(r.id)).toList();
    for (final r in toRemove) {
      InspectorService.instance.removeNetworkRequest(r.id);
    }
    setState(() => _selectedIds.clear());
  }

  Widget _buildRequestItem(NetworkRequest request) {
    final hasRule =
        InspectorService.instance.findMatchingRule(
          request.url,
          request.method,
        ) !=
        null;
    final selected = _selectedIds.contains(request.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          if (_selectionMode) {
            if (selected) {
              _selectedIds.remove(request.id);
            } else {
              _selectedIds.add(request.id);
            }
          } else {
            _selectedRequestId = request.id;
          }
        }),
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
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: selected
                            ? InspectorColors.accent
                            : InspectorColors.textHint,
                      ),
                    ),
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
    final interceptorOn = InspectorService.instance.isInterceptorEnabled;

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
                  Expanded(
                    child: Text(
                      'Interceptor rule active',
                      style: TextStyle(
                        color: InspectorColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
          if (!interceptorOn)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: InspectorColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  InspectorDimensions.smallRadius,
                ),
                border: Border.all(
                  color: InspectorColors.textSecondary,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 14,
                    color: InspectorColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Interceptor is OFF. Enable it from the request list to modify requests.',
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 11,
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

  String _formatJson(dynamic data) => InspectorFormatters.formatJson(data);
}

/// 拦截规则编辑面板 / Interceptor rule editor panel
/// StatefulWidget 管理内部 controllers 避免焦点丢失
/// StatefulWidget manages internal controllers to prevent focus loss
class InterceptorRulePanel extends StatefulWidget {
  final NetworkRequest request;
  final RequestInterceptorRule initialRule;
  final void Function(RequestInterceptorRule) onSave;
  final void Function(String) onDelete;
  final VoidCallback onClose;

  const InterceptorRulePanel({
    super.key,
    required this.request,
    required this.initialRule,
    required this.onSave,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<InterceptorRulePanel> createState() => _InterceptorRulePanelState();
}

class _InterceptorRulePanelState extends State<InterceptorRulePanel> {
  late RequestInterceptorRule _rule;
  late TextEditingController _nameController;
  late TextEditingController _urlPatternController;
  late TextEditingController _requestBodyController;
  late TextEditingController _responseStatusCodeController;
  late TextEditingController _responseBodyController;

  @override
  void initState() {
    super.initState();
    _rule = widget.initialRule;

    _nameController = TextEditingController(text: _rule.name);
    _urlPatternController = TextEditingController(text: _rule.urlPattern);
    _requestBodyController = TextEditingController(
      text: _formatBody(_rule.requestBody ?? widget.request.body),
    );
    _responseStatusCodeController = TextEditingController(
      text:
          _rule.responseStatusCode?.toString() ??
          widget.request.statusCode?.toString() ??
          '',
    );
    _responseBodyController = TextEditingController(
      text: _formatBody(_rule.responseBody ?? widget.request.responseBody),
    );
  }

  String _formatBody(dynamic body) {
    if (body == null) return '';
    return InspectorFormatters.formatJson(body);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlPatternController.dispose();
    _requestBodyController.dispose();
    _responseStatusCodeController.dispose();
    _responseBodyController.dispose();
    super.dispose();
  }

  void _updateRule(RequestInterceptorRule newRule) {
    setState(() {
      _rule = newRule;
    });
  }

  dynamic _parseBody(String value) {
    if (value.isEmpty) return null;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

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
    final isExisting = InspectorService.instance.interceptorRules.any(
      (r) => r.id == _rule.id,
    );
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
          if (isExisting)
            TextButton(
              onPressed: () => widget.onDelete(_rule.id),
              child: Text(
                'Delete',
                style: TextStyle(
                  color: InspectorColors.statusClientError,
                  fontSize: 12,
                ),
              ),
            ),
          TextButton(
            onPressed: widget.onClose,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: InspectorColors.textSecondary,
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
          controller: _nameController,
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 13),
          decoration: _buildInputDecoration(),
          onChanged: (value) => _updateRule(_rule.copyWith(name: value)),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: InspectorColors.card,
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
                value: _rule.enabled,
                onChanged: (value) =>
                    _updateRule(_rule.copyWith(enabled: value)),
                activeThumbColor: InspectorColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                _rule.enabled ? 'Enabled' : 'Disabled',
                style: TextStyle(
                  color: _rule.enabled
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
          'URL Pattern (for matching)',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: _urlPatternController,
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
          decoration: _buildInputDecoration(),
          onChanged: (value) => _updateRule(_rule.copyWith(urlPattern: value)),
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
          initialValue: _rule.method.isNotEmpty ? _rule.method : null,
          items: const [
            DropdownMenuItem(value: '', child: Text('Any')),
            DropdownMenuItem(value: 'GET', child: Text('GET')),
            DropdownMenuItem(value: 'POST', child: Text('POST')),
            DropdownMenuItem(value: 'PUT', child: Text('PUT')),
            DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
            DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
            DropdownMenuItem(value: 'HEAD', child: Text('HEAD')),
          ],
          onChanged: (value) =>
              _updateRule(_rule.copyWith(method: value ?? '')),
          style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
          decoration: _buildInputDecoration(),
        ),
      ],
    );
  }

  Widget _buildRegexToggle() {
    return Row(
      children: [
        Checkbox(
          value: _rule.useRegex,
          onChanged: (value) =>
              _updateRule(_rule.copyWith(useRegex: value ?? false)),
          fillColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? InspectorColors.accent
                : null,
          ),
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
          // 请求URL（置灰不可编辑）/ Request URL (disabled)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request URL',
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: TextEditingController(text: widget.request.url),
                readOnly: true,
                enabled: false,
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: InspectorColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: InspectorColors.border,
                      width: 1,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: InspectorColors.border,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 请求体 / Request body
          Column(
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
                  controller: _requestBodyController,
                  maxLines: null,
                  expands: true,
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
                      borderSide: BorderSide(
                        color: InspectorColors.border,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: InspectorColors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: InspectorColors.accent,
                        width: 1,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    _updateRule(_rule.copyWith(requestBody: _parseBody(value)));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
                'Response',
                style: TextStyle(
                  color: InspectorColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 状态码 / Status code
          Column(
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
                controller: _responseStatusCodeController,
                enabled: false,
                readOnly: true,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: InspectorColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: InspectorColors.border,
                      width: 1,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: InspectorColors.border,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 响应体 / Response body
          Column(
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
                  controller: _responseBodyController,
                  enabled: false,
                  readOnly: true,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: InspectorColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: InspectorColors.border,
                        width: 1,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: InspectorColors.border,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
              onPressed: () => widget.onSave(_rule),
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
