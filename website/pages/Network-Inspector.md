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

## WebSocket & gRPC Capture / WebSocket 与 gRPC 抓取

> **Available since v1.7.0** (opt-in, off by default)
>
> **v1.7.0 起可用**（可选开启，默认关闭）

HTTP/HTTPS traffic is captured automatically, but the `HttpOverrides` interceptor does **not** cover streaming protocols like **WebSocket** and **gRPC**. For those, enable the opt-in capture so frames and calls show up as `WS` / `gRPC` rows in the Network tab.

HTTP/HTTPS 流量会自动捕获，但 `HttpOverrides` 拦截器**无法覆盖** WebSocket、gRPC 这类流式协议。针对它们需开启可选的抓取，开启后收发帧/调用会以 `WS` / `gRPC` 行的形式出现在 Network 标签页。

### Enable / 开启方式

- Toggle the **WS** switch in the Network tab toolbar, or / 在 Network 标签页工具栏点击 **WS** 开关，或
- Set it programmatically: / 通过代码开启：

```dart
// on / 开启
WsInspectorService.instance.enable();
// off / 关闭
WsInspectorService.instance.disable();
```

Capture is **off by default** and only records while enabled — apps that don't use these protocols pay nothing.

抓取**默认关闭**，且只在开启时记录；不使用这类协议的应用零开销。

### Two Usage Modes / 两种使用方式

**1. Transparent wrapper — `InspectorWebSocket`**

Replace `WebSocket.connect` with `InspectorWebSocket.connect`. Frames are auto-recorded (`→` out, `←` in) when capture is on; when off it passes through with zero overhead.

将 `WebSocket.connect` 替换为 `InspectorWebSocket.connect`。开启抓取时会自动记录收发帧（`→` 出站、`←` 入站）；关闭时零开销透传。

```dart
final ws = await InspectorWebSocket.connect('wss://echo.websocket.events');
ws.listen((msg) => print('received: $msg'));
ws.add('hello'); // recorded as an outgoing frame / 记录为出站帧
```

**2. Manual hook — `recordCall`**

For stacks not transparently interceptable by `dart:io` (gRPC, `web_socket_channel`, custom protocols), call `recordCall` to log a request/response pair. No-ops when capture is disabled.

对于无法被 `dart:io` 透明拦截的栈（gRPC、`web_socket_channel`、自定义协议），调用 `recordCall` 记录一次请求/响应。关闭抓取时为空操作。

```dart
WsInspectorService.instance.recordCall(
  name: 'user.UserService/GetUser',
  request: '{ "id": 1 }',
  response: '{ "name": "Ada" }',
  protocol: 'gRPC', // appears in the method column / 显示在 method 列
);
```

### What You See / 查看方式

- Network tab lists a `WS` (or `gRPC`) entry per connection/call / Network 标签页按连接/调用列出 `WS`（或 `gRPC`）记录
- Open the detail view to see the frame log (outgoing `→` / incoming `←`), accumulated in the response body / 进入详情页查看帧日志（出站 `→` / 入站 `←`），累积显示在响应体中
- A `[connection closed]` marker is appended when the socket closes / 连接关闭后会追加 `[connection closed]` 标记

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

### Batch Operations / 批量操作

> **Available since v1.3.0**
>
> **v1.3.0 起可用**

The request list supports a selection mode for operating on multiple requests at once.

请求列表支持选择模式，可一次性操作多条请求。

- Tap the **selection icon** in the toolbar to enter selection mode / 点击工具栏的**选择图标**进入选择模式
- Check/uncheck items; a top batch bar shows **Select all** / **Cancel** / 勾选/取消勾选；顶部批量条提供**全选** / **取消**
- **Batch "Copy as cURL"**: copies all selected requests as cURL commands / **批量「Copy as cURL」**：将所有选中请求复制为 cURL 命令
- **Batch delete**: removes selected requests from the list / **批量删除**：从列表中移除选中请求

### Export & Sensitive-field Masking / 导出与敏感字段遮蔽

> **Available since v1.3.0**
>
> **v1.3.0 起可用**

The toolbar includes an **eye toggle** that controls whether sensitive headers are masked on export.

工具栏包含**眼睛开关**，控制导出时是否遮蔽敏感请求头。

- **Default: off (fully visible)** — cURL / JSON / HAR reflect the real request verbatim / **默认关闭（完整可见）**：cURL / JSON / HAR 原样反映真实请求
- **On**: `toCurl` / `netToJson` / `netToHar` / `copyNet` / `exportNetToFile` mask these headers / **开启后**：以下请求头被遮蔽：
  - `Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization`, `X-Auth-Token`, `X-CSRF-Token`, `X-XSRF-Token`
- The detail page "Copy as cURL" / "Copy as JSON" follow the same toggle / 详情页「Copy as cURL」「Copy as JSON」跟随同一开关
- When masking is active, the snackbar notes **(sensitive hidden)** / 遮蔽开启时，snackbar 提示 **(sensitive hidden)**

> Tip: keep masking **on** before pasting cURL/JSON into terminals, chat, or issue trackers to avoid leaking credentials.
>
> 提示：将 cURL/JSON 粘贴到终端、聊天或 issue 前，建议开启遮蔽，避免凭据泄露。

### Copy as cURL / 复制为 cURL

> **Available since v1.3.0**
>
> **v1.3.0 起可用**

From the request detail view, tap **Copy as cURL** to copy the request as a ready-to-run cURL command (method, URL, headers, body). Respects the sensitive-field masking toggle above.

在请求详情页点击 **Copy as cURL**，即可将请求复制为可直接运行的 cURL 命令（方法、URL、请求头、请求体），并遵循上方的敏感字段遮蔽开关。

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

## Request Interceptor / 请求拦截修改

> **Available since v1.0.7** (response fields locked to read-only since v1.0.8)
>
> **v1.0.7 起可用**（v1.0.8 起响应字段锁定为只读）

The inspector supports intercepting and modifying network requests via rules. This is useful for testing different request parameters without modifying app code.

检查器支持通过规则拦截并修改网络请求，适合在不修改应用代码的情况下测试不同的请求参数。

### Workflow / 工作流程

1. Send a request normally (it will be captured in the Network panel) / 正常发送请求（会被捕获到 Network 面板）
2. Open the request detail and tap the Interceptor icon / 打开请求详情，点击拦截器图标
3. Configure the modification rule (URL pattern, HTTP method, request modifications) / 配置修改规则（URL 模式、HTTP 方法、请求修改）
4. Save the rule — subsequent matching requests will use the modified parameters / 保存规则——后续匹配的请求将使用修改后的参数

### Supported Modifications / 支持的修改

| Field | Editable | Notes |
|-------|----------|-------|
| **Request Body** | ✅ | Only for requests with body (POST, PUT, PATCH, etc.) / 仅适用于有 body 的请求 |
| **Request Headers** | ✅ | Add / modify / remove headers / 新增 / 修改 / 删除请求头 |
| URL | ❌ | Grayed out, read-only / 灰色不可编辑 |
| Response Status Code | ❌ | Read-only since v1.0.8 / v1.0.8 起只读 |
| Response Body | ❌ | Read-only since v1.0.8 / v1.0.8 起只读 |

> The interception edit panel only allows modifying the **request body** and **request headers**. Response fields (status code, response body) are grayed out and uneditable.
>
> 拦截编辑面板仅允许修改**请求体**和**请求头**。响应字段（状态码、响应体）灰色不可编辑。

### Rule Matching / 规则匹配

- **URL pattern matching**: exact match or regex / URL 模式匹配：精确匹配或正则匹配
- **HTTP method filtering**: GET, POST, PUT, DELETE, PATCH, HEAD, or Any / HTTP 方法过滤

### Why GET Requests Cannot Be Modified / 为什么 GET 请求不能修改

- The interceptor currently supports modifying request body and headers only / 拦截器目前仅支持修改请求体和请求头
- GET requests don't have a request body / GET 请求没有请求体
- Modifying GET request parameters would require URL modification / 修改 GET 请求参数需要修改 URL
- URL modification may cause unexpected issues with request routing and parameter encoding / 修改 URL 可能导致请求路由和参数编码的意外问题

> GET request detail pages do not display interception edit buttons, making them unmodifiable.
>
> GET 请求详情页不显示拦截编辑按钮，因此无法修改。

### Master Toggle / 拦截总开关

- The interception master toggle is displayed **only on the Network list page**, not in the detail page / 拦截总开关**只显示在 Network 列表页**，不在详情页
- Rules are only applied when modification mode is enabled / 规则仅在启用修改模式时生效
- When no rules are configured or rules are disabled, all requests are sent normally without any modification / 未配置规则或禁用规则时，所有请求正常发送，不做任何修改

### Rule Management / 规则管理

The network panel includes an interceptor rule editor where you can:

网络面板包含拦截规则编辑器，可以：

- Create / edit / delete rules / 创建 / 编辑 / 删除规则
- Enable / disable individual rules / 启用 / 禁用单条规则
- View rule status indicators in the request list / 在请求列表中查看规则状态标识
