import 'package:flutter/material.dart';
import '../models/database_info.dart';
import '../services/database_service.dart';
import 'theme/inspector_theme.dart';

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
  Future<void> _loadTableData(String dbPath, String tableName) async {
    setState(() => _isLoading = true);
    _tableData = await DatabaseService.instance.queryTable(dbPath, tableName);
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

  /// 过滤表数据行（搜索所有列内容）/ Filter table data rows
  List<Map<String, dynamic>> _filterTableRows(QueryResult data) {
    if (_dbSearchKeyword.isEmpty) return data.rows;
    final keyword = _dbSearchKeyword.toLowerCase();
    return data.rows.where((row) {
      for (final col in data.columns) {
        final value = row[col]?.toString().toLowerCase() ?? '';
        if (value.contains(keyword)) return true;
      }
      return false;
    }).toList();
  }

  /// 进入数据库视图 / Enter database view
  void _enterDatabase(DatabaseInfo db) {
    setState(() {
      _currentDatabase = db;
      _selectedTable = null;
      _tableData = null;
      _dbSearchKeyword = '';
      _dbSearchController.clear();
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
          _buildCountBadge(
            '${_filterDatabasesGlobal(_databases).length} Databases',
          ),
          const Spacer(),
          _buildIconButton(
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
          _buildIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: _goBackToList,
          ),
          _buildCountBadge(
            _selectedTable != null
                ? '${_currentDatabase?.name} / ${_selectedTable?.name}'
                : '${_currentDatabase?.name}',
          ),
          const Spacer(),
          _buildIconButton(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: TextField(
        controller: _globalSearchController,
        onChanged: (value) => setState(() => _globalSearchKeyword = value),
        style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search database, table...',
          hintStyle: TextStyle(color: InspectorColors.textHint, fontSize: 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: InspectorColors.textSecondary,
          ),
          suffixIcon: _globalSearchKeyword.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _globalSearchController.clear();
                    setState(() => _globalSearchKeyword = '');
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

  /// 构建数据库内搜索栏 / Build in-database search bar
  Widget _buildDbSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: TextField(
        controller: _dbSearchController,
        onChanged: (value) => setState(() => _dbSearchKeyword = value),
        style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Search table, data...',
          hintStyle: TextStyle(color: InspectorColors.textHint, fontSize: 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: InspectorColors.textSecondary,
          ),
          suffixIcon: _dbSearchKeyword.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _dbSearchController.clear();
                    setState(() => _dbSearchKeyword = '');
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
              child: Icon(icon, color: InspectorColors.textSecondary, size: 18),
            ),
          ),
        ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storage_rounded,
                size: 36,
                color: InspectorColors.textHint,
              ),
              const SizedBox(height: 12),
              Text(
                _globalSearchKeyword.isEmpty
                    ? 'No databases found'
                    : 'No matching databases',
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _dbSearchKeyword.isEmpty ? 'No tables' : 'No matching tables',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
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
                        : InspectorColors.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

    final filteredRows = _filterTableRows(_tableData!);

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
                  '${filteredRows.length} rows',
                  style: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_dbSearchKeyword.isNotEmpty &&
                  filteredRows.length != _tableData!.rows.length) ...[
                const SizedBox(width: 6),
                Text(
                  'of ${_tableData!.rows.length}',
                  style: TextStyle(
                    color: InspectorColors.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
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
              child: _buildDataTable(filteredRows),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建数据表 / Build data table
  Widget _buildDataTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          _dbSearchKeyword.isEmpty ? 'No data' : 'No matching rows',
          style: TextStyle(color: InspectorColors.textSecondary, fontSize: 12),
        ),
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
            return DataColumn(
              label: Text(
                column,
                style: TextStyle(
                  color: InspectorColors.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
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
