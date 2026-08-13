# Database Viewer / 数据库查看器

## Overview / 概述

The Database Viewer inspects SQLite databases in your app with a two-level navigation system.

数据库查看器通过双层导航系统检查应用中的 SQLite 数据库。

## Auto-Scan / 自动扫描

The inspector automatically scans the following directories for `.db` and `.sqlite` files:

检查器自动扫描以下目录中的 `.db` 和 `.sqlite` 文件：

- `getApplicationDocumentsDirectory()` / 应用文档目录
- `getDatabasesPath()` / 数据库目录

## Two-Level Navigation / 双层导航

### Level 1: Database List (Global) / 第一层：数据库列表（全局）

- Shows all discovered databases / 显示所有发现的数据库
- Each database shows name and table count / 每个数据库显示名称和表数量
- **Global search**: Search database names and table names / **全局搜索**：搜索数据库名和表名

### Level 2: Database Detail / 第二层：数据库详情

- Click a database to enter its detail view / 点击数据库进入详情视图
- Left panel: table list with row counts / 左侧面板：表列表（含行数）
- Right panel: table data in DataTable format / 右侧面板：DataTable 格式的表数据
- Back button to return to database list / 返回按钮返回数据库列表
- **In-database search**: Search table names AND all column data / **数据库内搜索**：搜索表名和所有列数据

## Search / 搜索

| Level | Search Scope |
|-------|-------------|
| Global (database list) | Database names, table names / 数据库名、表名 |
| In-database | Table names, all column values in all tables / 表名、所有表的所有列值 |

### Search Highlights / 搜索高亮

When searching within a database, matching cell values are highlighted in accent color.

在数据库内搜索时，匹配的单元格值以强调色高亮显示。

## UI Features / UI 功能

- Color-coded table icons / 带颜色的表图标
- Row count badges for each table / 每个表的行数徽章
- Selected table highlighted / 选中表高亮
- Horizontal and vertical scrollable data table / 水平和垂直可滚动的数据表
- Row count display (filtered / total) when searching / 搜索时显示行数（过滤/总数）

## Custom Database Provider / 自定义数据库提供者

For non-SQLite databases, see [Custom Database Provider](Custom-Database-Provider).

对于非 SQLite 数据库，请参阅 [自定义数据库提供者](Custom-Database-Provider)。
