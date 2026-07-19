import 'package:flutter/material.dart';

/// 检查器主题颜色配置 / Inspector theme color configuration
///
/// 集中管理所有 UI 颜色，方便统一调整 / Centralized management of all UI colors for easy adjustment
class InspectorColors {
  InspectorColors._();

  // ===== 背景色 / Background colors =====

  /// 主背景渐变起始色 / Main background gradient start color
  static const Color backgroundStart = Color(0xFF1e1e2e);

  /// 主背景渐变结束色 / Main background gradient end color
  static const Color backgroundEnd = Color(0xFF1a1b26);

  /// 工具栏/面板背景色 / Toolbar/panel background color
  static const Color surface = Color(0xFF16161e);

  /// 卡片/列表项背景色 / Card/list item background color
  static const Color card = Color(0xFF1e1e2e);

  /// 选中项背景色 / Selected item background color
  static const Color selected = Color(0x337c3aed);

  // ===== 边框色 / Border colors =====

  /// 主边框色 / Primary border color
  static const Color border = Color(0xFF3b3b4f);

  /// 分隔线色 / Divider color
  static const Color divider = Color(0xFF2a2a3a);

  // ===== 主题色 / Theme colors =====

  /// 主题紫色 / Theme purple
  static const Color primary = Color(0xFF7c3aed);

  /// 主题蓝色 / Theme blue
  static const Color secondary = Color(0xFF2563eb);

  /// 紫色辅助色 / Purple accent color
  static const Color accent = Color(0xFFa78bfa);

  // ===== 文本色 / Text colors =====

  /// 主文本色 / Primary text color
  static const Color textPrimary = Colors.white;

  /// 次要文本色 / Secondary text color
  static const Color textSecondary = Colors.grey;

  // ===== 状态色 / Status colors =====

  /// 成功色 / Success color
  static const Color success = Color(0xFF34d399);

  /// 警告色 / Warning color
  static const Color warning = Color(0xFFfbbf24);

  /// 错误色 / Error color
  static const Color error = Color(0xFFf87171);

  /// 信息色 / Info color
  static const Color info = Color(0xFF60a5fa);

  // ===== 状态码颜色 / Status code colors =====

  /// 2xx 成功状态码颜色 / 2xx success status color
  static const Color statusSuccess = Color(0xFF34d399);

  /// 3xx 重定向状态码颜色 / 3xx redirect status color
  static const Color statusRedirect = Color(0xFFfbbf24);

  /// 4xx 客户端错误状态码颜色 / 4xx client error status color
  static const Color statusClientError = Color(0xFFfb923c);

  /// 5xx 服务器错误状态码颜色 / 5xx server error status color
  static const Color statusServerError = Color(0xFFf87171);

  // ===== HTTP 方法颜色 / HTTP method colors =====

  /// GET 方法颜色 / GET method color
  static const Color methodGet = Color(0xFF34d399);

  /// POST 方法颜色 / POST method color
  static const Color methodPost = Color(0xFF60a5fa);

  /// PUT 方法颜色 / PUT method color
  static const Color methodPut = Color(0xFFfbbf24);

  /// DELETE 方法颜色 / DELETE method color
  static const Color methodDelete = Color(0xFFf87171);

  /// PATCH 方法颜色 / PATCH method color
  static const Color methodPatch = Color(0xFFa78bfa);

  // ===== 日志级别颜色 / Log level colors =====

  /// Verbose 级别颜色 / Verbose level color
  static const Color logVerbose = Colors.grey;

  /// Debug 级别颜色 / Debug level color
  static const Color logDebug = Color(0xFF60a5fa);

  /// Info 级别颜色 / Info level color
  static const Color logInfo = Color(0xFF34d399);

  /// Warning 级别颜色 / Warning level color
  static const Color logWarning = Color(0xFFfbbf24);

  /// Error 级别颜色 / Error level color
  static const Color logError = Color(0xFFf87171);

  /// Error 级别文本颜色 / Error level text color
  static const Color logErrorText = Color(0xFFfca5a5);

  /// Warning 级别文本颜色 / Warning level text color
  static const Color logWarningText = Color(0xFFfcd34d);

  // ===== 路由操作颜色 / Route action colors =====

  /// push 操作颜色 / push action color
  static const Color routePush = Color(0xFF34d399);

  /// pop 操作颜色 / pop action color
  static const Color routePop = Color(0xFFf87171);

  /// pushReplacement 操作颜色 / pushReplacement action color
  static const Color routeReplace = Color(0xFFfbbf24);
}

/// 检查器主题渐变 / Inspector theme gradients
class InspectorGradients {
  InspectorGradients._();

  /// 主背景渐变 / Main background gradient
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [InspectorColors.backgroundStart, InspectorColors.backgroundEnd],
  );

  /// 主题渐变（紫到蓝）/ Primary gradient (purple to blue)
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [InspectorColors.primary, InspectorColors.secondary],
  );

  /// 头部渐变 / Header gradient
  static const LinearGradient header = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0x4D7c3aed),
      Color(0x332563eb),
      Colors.transparent,
    ],
  );

  /// 标签指示器渐变 / Tab indicator gradient
  static const LinearGradient tabIndicator = LinearGradient(
    colors: [InspectorColors.primary, InspectorColors.secondary],
  );
}

/// 检查器主题尺寸 / Inspector theme dimensions
class InspectorDimensions {
  InspectorDimensions._();

  /// 悬浮按钮尺寸 / Floating button size
  static const double floatingButtonSize = 52;

  /// 悬浮按钮图标尺寸 / Floating button icon size
  static const double floatingButtonIconSize = 24;

  /// 面板圆角 / Panel border radius
  static const double panelRadius = 20;

  /// 卡片圆角 / Card border radius
  static const double cardRadius = 8;

  /// 小圆角 / Small border radius
  static const double smallRadius = 6;

  /// 标签圆角 / Chip border radius
  static const double chipRadius = 8;
}
