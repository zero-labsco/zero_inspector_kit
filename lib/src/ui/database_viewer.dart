import 'package:flutter/material.dart';
import '../models/database_info.dart';
import '../services/database_service.dart';

/// 数据库查看器
/// 显示应用中的所有数据库和表结构，支持查看表数据
class DatabaseViewer extends StatefulWidget {
  const DatabaseViewer({super.key});

  @override
  State<DatabaseViewer> createState() => _DatabaseViewerState();
}

class _DatabaseViewerState extends State<DatabaseViewer> {
  /// 所有数据库列表
  List<DatabaseInfo> _databases = [];

  /// 当前选中的数据库
  DatabaseInfo? _selectedDatabase;

  /// 当前选中的表
  TableInfo? _selectedTable;

  /// 表查询结果
  QueryResult? _tableData;

  /// 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatabases();
  }

  /// 加载数据库列表
  Future<void> _loadDatabases() async {
    setState(() => _isLoading = true);
    _databases = await DatabaseService.instance.getDatabases();
    setState(() => _isLoading = false);
  }

  /// 加载表数据
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

  /// 构建工具栏
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2d2d44))),
      ),
      child: Row(
        children: [
          if (_selectedTable != null)
            IconButton(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back, color: Colors.grey, size: 16),
            ),
          Text(
            _selectedTable != null
                ? '${_selectedDatabase?.name} / ${_selectedTable?.name}'
                : '${_databases.length} Databases',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadDatabases,
            icon: const Icon(Icons.refresh, color: Colors.grey, size: 16),
          ),
        ],
      ),
    );
  }

  /// 返回上一层
  void _goBack() {
    setState(() {
      _selectedTable = null;
      _tableData = null;
    });
  }

  /// 构建数据库列表
  Widget _buildDatabaseList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_databases.isEmpty) {
      return const Center(
        child: Text('No databases found', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _databases.length,
      itemBuilder: (context, index) => _buildDatabaseItem(_databases[index]),
    );
  }

  /// 构建单个数据库项
  Widget _buildDatabaseItem(DatabaseInfo database) {
    final isSelected = _selectedDatabase?.name == database.name;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2d2d44) : Colors.transparent,
      ),
      child: ExpansionTile(
        title: Text(
          database.name,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        children: database.tables.map((table) {
          return ListTile(
            title: Text(
              table.name,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: Text(
              '${table.rowCount} rows',
              style: const TextStyle(color: Colors.blueAccent, fontSize: 11),
            ),
            onTap: () {
              setState(() {
                _selectedDatabase = database;
                _selectedTable = table;
              });
              _loadTableData(database.path, table.name);
            },
          );
        }).toList(),
      ),
    );
  }

  /// 构建表数据视图
  Widget _buildTableData() {
    if (_isLoading || _selectedTable == null || _tableData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF2d2d44))),
      ),
      child: Column(
        children: [
          Text(
            _selectedTable!.name,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: _tableData!.columns.map((column) {
                    return DataColumn(
                      label: Text(
                        column,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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
        ],
      ),
    );
  }
}
