# Custom Database Provider / 自定义数据库提供者

## Overview / 概述

Zero Inspector Kit supports extending database inspection beyond SQLite through the `DatabaseProvider` interface.

Zero Inspector Kit 通过 `DatabaseProvider` 接口支持扩展数据库检查功能到 SQLite 以外的数据库。

## DatabaseProvider Interface / 接口定义

```dart
abstract class DatabaseProvider {
  /// Provider name / 提供者名称
  String get name;

  /// Get list of databases / 获取数据库列表
  Future<List<DatabaseInfo>> getDatabases();

  /// Query table data / 查询表数据
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50});
}
```

## Data Models / 数据模型

### DatabaseInfo

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Database name / 数据库名称 |
| `path` | String | Database file path / 数据库文件路径 |
| `tables` | List\<TableInfo\> | List of tables / 表列表 |

### TableInfo

| Field | Type | Description |
|-------|------|-------------|
| `name` | String | Table name / 表名 |
| `rowCount` | int | Row count / 行数 |

### QueryResult

| Field | Type | Description |
|-------|------|-------------|
| `columns` | List\<String\> | Column names / 列名 |
| `rows` | List\<Map\<String, dynamic\>\> | Row data / 行数据 |

## Example: Custom Provider / 示例：自定义提供者

```dart
class MyCustomDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'CustomDB';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    // Return your custom databases / 返回你的自定义数据库列表
    return [
      DatabaseInfo(
        name: 'my_database',
        path: '/path/to/my_database',
        tables: [
          TableInfo(name: 'users', rowCount: 100),
          TableInfo(name: 'orders', rowCount: 500),
        ],
      ),
    ];
  }

  @override
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
  }) async {
    // Execute query and return results / 执行查询并返回结果
    return QueryResult(
      columns: ['id', 'name', 'value'],
      rows: [
        {'id': 1, 'name': 'item1', 'value': '100'},
        {'id': 2, 'name': 'item2', 'value': '200'},
      ],
    );
  }
}
```

## Register Provider / 注册提供者

```dart
// Register your custom provider / 注册自定义提供者
DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
```

## Built-in Provider / 内置提供者

The plugin includes `SqliteDatabaseProvider` which is auto-registered when `enableDatabaseScan` is `true` (default).

插件内置 `SqliteDatabaseProvider`，当 `enableDatabaseScan` 为 `true`（默认）时自动注册。

You can also register it manually:

也可以手动注册：

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```
