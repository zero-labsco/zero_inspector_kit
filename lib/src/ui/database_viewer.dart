import 'package:flutter/material.dart';
import '../models/database_info.dart';
import '../services/database_service.dart';
import 'theme/inspector_theme.dart';
import 'widgets/widgets.dart';

/// 数据库查看器 / Database viewer
/// 显示应用中的所有数据库和表结构，支持搜索和查看表数据 / Display all databases and table structures in the app, support search and viewing table data
class DatabaseViewer extends StatefulWidget {
  const DatabaseViewer({super.key});

  @override
  State<DatabaseViewer> createState() => _DatabaseViewerState();
}

class _DatabaseViewerState extends State<DatabaseViewer> {
  /// 所有数据库列表 / All database list
  List<DatabaseInfo> _databases = [];

  /// 全局搜索关键词（数据库列表视图）/ Global search keyword (database list view)
  String _globalSearchKeyword = '';

  /// 全局搜索控制器 / Global search controller
  final TextEditingController _globalSearchController = TextEditingController();

  /// 数据库内搜索关键词（数据库详情视图）/ In-database search keyword (database detail view)
  String _dbSearchKeyword = '';

  /// 数据库内搜索控制器 / In-database search controller
  final TextEditingController _dbSearchController = TextEditingController();

  /// 当前进入的数据库（null 显示数据库列表）/ Currently entered database
  DatabaseInfo? _currentDatabase;

  /// 当前选中的表 / Currently selected table
  TableInfo? _selectedTable;

  /// 表查询结果 / Table query result
  QueryResult? _tableData;

  /// 每页行数 / Page size
  static const int _pageSize = 50;

  /// 当前页（从 0 开始）/ Current page (0-based)
  int _currentPage = 0;

  /// 排序列名（null 表示不排序）/ Order-by column (null = no order)
  String? _orderBy;

  /// 是否降序 / Descending order
  bool _desc = false;

  /// 是否正在加载 / Whether loading
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    _dbSearchController.dispose();
    super.dispose();
  }

  /// 加载数据库列表 / Load database list
  Future<void> _loadDatabases() async {
    setState(() => _isLoading = true);
    _databases = await DatabaseService.instance.getDatabases();
    setState(() => _isLoading = false);
  }

  /// 加载表数据 / Load table data
  /// [orderBy]/[desc]/[keyword] 可选，支持排序与单元格级关键字过滤（服务端执行，分页准确）。
  /// [orderBy]/[desc]/[keyword] are optional for sorting and cell-level keyword filtering (server-side, pagination-safe).
  Future<void> _loadTableData(
    String dbPath,
    String tableName, {
    String? orderBy,
    bool? desc,
    String? keyword,
  }) async {
    setState(() => _isLoading = true);
    _tableData = await DatabaseService.instance.queryTable(
      dbPath,
      tableName,
      limit: _pageSize,
      offset: _currentPage * _pageSize,
      orderBy: orderBy ?? _orderBy,
      desc: desc ?? _desc,
      whereKeyword:
          keyword ?? (_dbSearchKeyword.isEmpty ? null : _dbSearchKeyword),
    );
    setState(() => _isLoading = false);
  }

  /// 全局搜索过滤数据库（搜索数据库名和表名）/ Global search filter databases
  List<DatabaseInfo> _filterDatabasesGlobal(List<DatabaseInfo> dbs) {
    if (_globalSearchKeyword.isEmpty) return dbs;
    final keyword = _globalSearchKeyword.toLowerCase();
    return dbs.where((db) {
      if (db.name.toLowerCase().contains(keyword)) return true;
      return db.tables.any(
        (table) => table.name.toLowerCase().contains(keyword),
      );
    }).toList();
  }

  /// 数据库内搜索过滤表（搜索表名）/ In-database search filter tables
  List<TableInfo> _filterTablesInDb(List<TableInfo> tables) {
    if (_dbSearchKeyword.isEmpty) return tables;
    final keyword = _dbSearchKeyword.toLowerCase();
    return tables
        .where((table) => table.name.toLowerCase().contains(keyword))
        .toList();
  }

  /// 进入数据库视图 / Enter database view
  void _enterDatabase(DatabaseInfo db) {
    setState(() {
      _currentDatabase = db;
      _selectedTable = null;
      _tableData = null;
      _dbSearchKeyword = '';
      _dbSearchController.clear();
      _currentPage = 0;
      _orderBy = null;
      _desc = false;
    });
  }

  /// 返回数据库列表 / Go back to database list
  void _goBackToList() {
    setState(() {
      _currentDatabase = null;
      _selectedTable = null;
      _tableData = null;
    });
  }

  /// 切换某列的排序（再次点击同一列则反转方向）/ Toggle sort on a column (re-click flips direction)
  void _toggleSort(String column) {
    setState(() {
      if (_orderBy == column) {
        _desc = !_desc;
      } else {
        _orderBy = column;
        _desc = false;
      }
      _currentPage = 0;
    });
    if (_selectedTable != null && _currentDatabase != null) {
      _loadTableData(
        _currentDatabase!.path,
        _selectedTable!.name,
        orderBy: _orderBy,
        desc: _desc,
      );
    }
  }

  /// 跳转到指定页（越界则忽略）/ Go to a specific page (ignored if out of range)
  void _goToPage(int page) {
    final total = _tableData?.total ?? 0;
    final lastPage = total <= 0 ? 0 : ((total - 1) / _pageSize).floor();
    if (page < 0 || page > lastPage) return;
    setState(() => _currentPage = page);
    if (_selectedTable != null && _currentDatabase != null) {
      _loadTableData(_currentDatabase!.path, _selectedTable!.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDatabase != null) {
      return _buildDatabaseDetailView();
    }
    return _buildDatabaseListView();
  }

  /// 构建数据库列表视图 / Build database list view
  Widget _buildDatabaseListView() {
    return Column(
      children: [
        _buildListToolbar(),
        _buildGlobalSearchBar(),
        Expanded(child: _buildDatabaseList()),
      ],
    );
  }

  /// 构建数据库详情视图 / Build database detail view
  Widget _buildDatabaseDetailView() {
    return Column(
      children: [
        _buildDetailToolbar(),
        _buildDbSearchBar(),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildTableList()),
              if (_selectedTable != null && _tableData != null)
                Expanded(flex: 2, child: _buildTableData()),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建列表工具栏 / Build list toolbar
  Widget _buildListToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: Row(
        children: [
          InspectorCountBadge(
            '${_filterDatabasesGlobal(_databases).length} Databases',
          ),
          const Spacer(),
          InspectorIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onTap: _loadDatabases,
          ),
        ],
      ),
    );
  }

  /// 构建详情工具栏 / Build detail toolbar
  Widget _buildDetailToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: Row(
        children: [
          InspectorIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: _goBackToList,
          ),
          InspectorCountBadge(
            _selectedTable != null
                ? '${_currentDatabase?.name} / ${_selectedTable?.name}'
                : '${_currentDatabase?.name}',
          ),
          const Spacer(),
          InspectorIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onTap: () {
              if (_selectedTable != null && _currentDatabase != null) {
                _loadTableData(_currentDatabase!.path, _selectedTable!.name);
              }
            },
          ),
        ],
      ),
    );
  }

  /// 构建全局搜索栏 / Build global search bar
  Widget _buildGlobalSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InspectorSearchField(
        controller: _globalSearchController,
        hint: 'Search database, table...',
        onClear: () {
          _globalSearchController.clear();
          setState(() => _globalSearchKeyword = '');
        },
      ),
    );
  }

  /// 构建数据库内搜索栏 / Build in-database search bar
  Widget _buildDbSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InspectorSearchField(
        controller: _dbSearchController,
        hint: 'Search table, data...',
        onClear: () {
          _dbSearchController.clear();
          setState(() {
            _dbSearchKeyword = '';
            _currentPage = 0;
          });
          if (_selectedTable != null && _currentDatabase != null) {
            _loadTableData(
              _currentDatabase!.path,
              _selectedTable!.name,
              keyword: null,
            );
          }
        },
      ),
    );
  }

  /// 构建数据库列表 / Build database list
  Widget _buildDatabaseList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: InspectorColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    final filteredDbs = _filterDatabasesGlobal(_databases);

    if (filteredDbs.isEmpty) {
      return InspectorEmptyState(
        message:
            _globalSearchKeyword.isEmpty
                ? 'No databases found'
                : 'No matching databases',
        icon: Icons.storage_rounded,
      );
    }

    return ListView.builder(
      itemCount: filteredDbs.length,
      itemBuilder: (context, index) => _buildDatabaseItem(filteredDbs[index]),
    );
  }

  /// 构建单个数据库项 / Build single database item
  Widget _buildDatabaseItem(DatabaseInfo database) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _enterDatabase(database),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: InspectorColors.accent, width: 3),
              bottom: BorderSide(color: InspectorColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: InspectorColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  size: 20,
                  color: InspectorColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      database.name,
                      style: TextStyle(
                        color: InspectorColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${database.tables.length} tables',
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: InspectorColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建表列表 / Build table list
  Widget _buildTableList() {
    if (_currentDatabase == null) return const SizedBox.shrink();

    final tables = _filterTablesInDb(_currentDatabase!.tables);

    if (tables.isEmpty) {
      return InspectorEmptyState(
        message: _dbSearchKeyword.isEmpty ? 'No tables' : 'No matching tables',
        icon: Icons.table_chart_rounded,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: InspectorColors.border)),
      ),
      child: ListView.builder(
        itemCount: tables.length,
        itemBuilder: (context, index) => _buildTableItem(tables[index]),
      ),
    );
  }

  /// 构建单个表项 / Build single table item
  Widget _buildTableItem(TableInfo table) {
    final isSelected = _selectedTable?.name == table.name;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedTable = table);
          if (_currentDatabase != null) {
            _loadTableData(_currentDatabase!.path, table.name);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? InspectorColors.selected : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? InspectorColors.accent : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: InspectorColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                size: 16,
                color: isSelected
                    ? InspectorColors.accent
                    : InspectorColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  table.name,
                  style: TextStyle(
                    color: isSelected
                        ? InspectorColors.accent
                        : table.error != null
                        ? Colors.red
                        : InspectorColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (table.error != null)
                Icon(Icons.error_outline, size: 14, color: Colors.red)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: InspectorColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${table.rowCount}',
                    style: TextStyle(
                      color: InspectorColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建表数据视图 / Build table data view
  Widget _buildTableData() {
    if (_isLoading || _selectedTable == null || _tableData == null) {
      return Center(
        child: CircularProgressIndicator(
          color: InspectorColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    // 查询失败：渲染错误态 + 重试按钮，而不是伪装成空列表。
    // Query failed: render an error state with retry, not a fake empty list.
    if (_tableData!.hasError) {
      return InspectorErrorState(
        title: '查询失败',
        detail: _tableData!.error,
        onRetry: () {
          if (_currentDatabase != null && _selectedTable != null) {
            _loadTableData(_currentDatabase!.path, _selectedTable!.name);
          }
        },
      );
    }

    final total = _tableData!.total;
    final lastPage = total <= 0 ? 0 : ((total - 1) / _pageSize).floor();

    return Container(
      padding: const EdgeInsets.all(14),
      color: InspectorColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.table_chart_rounded,
                size: 18,
                color: InspectorColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedTable!.name,
                style: TextStyle(
                  color: InspectorColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: InspectorColors.border,
                  borderRadius: BorderRadius.circular(
                    InspectorDimensions.smallRadius,
                  ),
                ),
                child: Text(
                  '${_tableData!.rows.length} / $total rows',
                  style: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: InspectorColors.card,
                borderRadius: BorderRadius.circular(
                  InspectorDimensions.cardRadius,
                ),
                border: Border.all(color: InspectorColors.border, width: 0.5),
              ),
              child: _buildDataTable(_tableData!.rows),
            ),
          ),
          const SizedBox(height: 8),
          _buildPaginationBar(lastPage),
        ],
      ),
    );
  }

  /// 构建分页栏 / Build pagination bar
  Widget _buildPaginationBar(int lastPage) {
    final total = _tableData?.total ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InspectorIconButton(
          icon: Icons.first_page_rounded,
          tooltip: 'First page',
          enabled: _currentPage > 0,
          onTap: () => _goToPage(0),
        ),
        InspectorIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous',
          enabled: _currentPage > 0,
          onTap: () => _goToPage(_currentPage - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Page ${_currentPage + 1} / ${lastPage + 1}'
            '${total > 0 ? '  ($total total)' : ''}',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        InspectorIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next',
          enabled: _currentPage < lastPage,
          onTap: () => _goToPage(_currentPage + 1),
        ),
        InspectorIconButton(
          icon: Icons.last_page_rounded,
          tooltip: 'Last page',
          enabled: _currentPage < lastPage,
          onTap: () => _goToPage(lastPage),
        ),
      ],
    );
  }

  /// 构建数据表 / Build data table
  Widget _buildDataTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return InspectorEmptyState(
        message: _dbSearchKeyword.isEmpty ? 'No data' : 'No matching rows',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            InspectorColors.surface.withValues(alpha: 0.5),
          ),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          dividerThickness: 0.5,
          columnSpacing: 24,
          horizontalMargin: 12,
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 32,
          columns: _tableData!.columns.map((column) {
            final isSorted = _orderBy == column;
            return DataColumn(
              onSort: (_, _) => _toggleSort(column),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    column,
                    style: TextStyle(
                      color: InspectorColors.accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isSorted)
                    Icon(
                      _desc ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      size: 14,
                      color: InspectorColors.accent,
                    ),
                ],
              ),
            );
          }).toList(),
          rows: rows.map((row) {
            return DataRow(
              cells: _tableData!.columns.map((column) {
                return DataCell(
                  Text(
                    row[column]?.toString() ?? '',
                    style: TextStyle(
                      color: _highlightMatch(row[column]?.toString() ?? '')
                          ? InspectorColors.accent
                          : InspectorColors.textPrimary,
                      fontSize: 11.5,
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 检查是否匹配搜索关键词（用于高亮判断）/ Check if matches search keyword
  bool _highlightMatch(String text) {
    if (_dbSearchKeyword.isEmpty) return false;
    return text.toLowerCase().contains(_dbSearchKeyword.toLowerCase());
  }
}
