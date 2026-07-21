# Network Inspector / 网络检查器

## Overview / 概述

The Network Inspector automatically captures all HTTP requests made via the **http package** and **Dio**, with zero configuration needed.

网络检查器自动捕获所有通过 **http 包** 和 **Dio** 发送的 HTTP 请求，无需任何配置。

## How It Works / 工作原理

The inspector uses Flutter's `HttpOverrides` to intercept all HTTP traffic at the `dart:io` level. This means:

检查器通过 Flutter 的 `HttpOverrides` 在 `dart:io` 层面拦截所有 HTTP 流量。这意味着：

- **http package**: Auto-captured ✅ / 自动捕获 ✅
- **Dio**: Auto-captured (uses IOHttpClientAdapter → HttpClient) ✅ / 自动捕获 ✅
- No manual interceptor setup needed / 无需手动添加拦截器

## Captured Information / 捕获的信息

| Field | Description |
|-------|-------------|
| Method | GET, POST, PUT, DELETE, PATCH |
| URL | Full request URL |
| Status Code | HTTP response status code |
| Duration | Request duration |
| Request Headers | All request headers |
| Request Body | Request payload (JSON formatted) |
| Response Body | Response payload (JSON formatted) |
| Host | Parsed from URL |

## UI Features / UI 功能

### Request List / 请求列表
- Color-coded by HTTP method / 按 HTTP 方法着色
- Status code badge / 状态码徽章
- Duration display / 耗时显示
- Left border color indicates status / 左侧边框颜色表示状态

### Request Detail / 请求详情
- Click a request to enter detail view / 点击请求进入详情视图
- Back button to return to list / 返回按钮返回列表
- Request and response sections / 请求和响应分段显示
- JSON formatted body / JSON 格式化显示

### Search / 搜索
- Fuzzy search by URL or method / 按 URL 或方法模糊搜索
- Search bar hidden in detail view / 详情视图隐藏搜索栏

## Status Code Colors / 状态码颜色

| Range | Color | Description |
|-------|-------|-------------|
| 2xx | Green | Success / 成功 |
| 3xx | Blue | Redirect / 重定向 |
| 4xx | Orange | Client error / 客户端错误 |
| 5xx | Red | Server error / 服务器错误 |

## HTTP Method Colors / HTTP 方法颜色

| Method | Color |
|--------|-------|
| GET | Blue / 蓝色 |
| POST | Green / 绿色 |
| PUT | Orange / 橙色 |
| DELETE | Red / 红色 |
| PATCH | Purple / 紫色 |

## Usage Example / 使用示例

```dart
// http package - auto-captured / http 包 - 自动捕获
final response = await http.get(
  Uri.parse('https://api.example.com/data'),
);

// Dio - auto-captured / Dio - 自动捕获
final response = await dio.post(
  'https://api.example.com/data',
  data: {'key': 'value'},
);
```

No additional setup required! All requests will appear in the Network tab.

无需额外配置！所有请求都会出现在 Network 标签页中。
