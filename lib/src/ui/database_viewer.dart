import 'package:flutter/material.dart';
import '../models/database_info.dart';
import '../services/database_service.dart';
import 'theme/inspector_theme.dart';

/// 数据库查看器 / Database viewer
/// 显示应用中的所有数据库和表结构，支持查看表数据 / Display all databases and table structures in the app, support viewing table data
class DatabaseViewer extends StatefulWidget {
  const DatabaseViewer({super.key});

  @override
  State<DatabaseViewer> createState() => _DatabaseViewerState();
}

class _DatabaseViewerState extends State<DatabaseViewer> {
  /// 所有数据库列表 / All database list
  List<DatabaseInfo> _databases = [];

  /// 当前选中的数据库 / Currently selected database
  DatabaseInfo? _selectedDatabase;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 1, child: _buildDatabaseList()),
              if (_selectedTable != null && _tableData != null)
                Expanded(flex: 2, child: _buildTableData()),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建工具栏 / Build toolbar
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: Row(
        children: [
          if (_selectedTable != null)
            _buildIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: _goBack,
            ),
          _buildCountBadge(
            _selectedTable != null
                ? '${_selectedDatabase?.name} / ${_selectedTable?.name}'
                : '${_databases.length} Databases',
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

  /// 返回上一层 / Go back to previous level
  void _goBack() {
    setState(() {
      _selectedTable = null;
      _tableData = null;
    });
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

    if (_databases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No databases found',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: InspectorColors.border)),
      ),
      child: ListView.builder(
        itemCount: _databases.length,
        itemBuilder: (context, index) => _buildDatabaseItem(_databases[index]),
      ),
    );
  }

  /// 构建单个数据库项 / Build single database item
  Widget _buildDatabaseItem(DatabaseInfo database) {
    final isSelected = _selectedDatabase?.name == database.name;

    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        expansionTileTheme: ExpansionTileThemeData(
          iconColor: InspectorColors.accent,
          collapsedIconColor: InspectorColors.textSecondary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.only(bottom: 4),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? InspectorColors.selected : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: InspectorColors.divider, width: 0.5),
          ),
        ),
        child: ExpansionTile(
          title: Row(
            children: [
              Icon(
                Icons.storage_rounded,
                size: 18,
                color: isSelected
                    ? InspectorColors.accent
                    : InspectorColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  database.name,
                  style: TextStyle(
                    color: isSelected
                        ? InspectorColors.accent
                        : InspectorColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${database.tables.length} tables',
              style: TextStyle(
                color: InspectorColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          children: database.tables.map((table) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDatabase = database;
                    _selectedTable = table;
                  });
                  _loadTableData(database.path, table.name);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      Icon(
                        Icons.table_chart_rounded,
                        size: 16,
                        color: InspectorColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          table.name,
                          style: TextStyle(
                            color: InspectorColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
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
          }).toList(),
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
                  '${_tableData!.rows.length} rows',
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
              child: SingleChildScrollView(
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
                    rows: _tableData!.rows.map((row) {
                      return DataRow(
                        cells: _tableData!.columns.map((column) {
                          return DataCell(
                            Text(
                              row[column]?.toString() ?? '',
                              style: TextStyle(
                                color: InspectorColors.textPrimary,
                                fontSize: 11.5,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
