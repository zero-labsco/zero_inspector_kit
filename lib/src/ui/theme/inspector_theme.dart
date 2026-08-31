import 'package:flutter/material.dart';

/// 检查器主题颜色配置 / Inspector theme color configuration
///
/// 设计方向：仪表盘级 / Terminal-grade。
/// 中性石墨灰打底 + 单一 Teal 信号色强调，去掉渐变与彩色光晕，
/// 靠 1px 边框组织信息，贴近专业开发者工具而非 AI 套壳审美。
/// Design direction: dashboard / terminal-grade. Neutral graphite base + a
/// single Teal signal accent, no gradients or colored glows; structure comes
/// from 1px borders, closer to a pro dev tool than an AI-template look.
class InspectorColors {
  InspectorColors._();

  // ===== 背景色 / Background colors =====

  /// 主背景（最底层 scrim）/ Main background (deepest scrim)
  static const Color backgroundStart = Color(0xFF0E1116);

  /// 主背景（收尾）/ Main background (tail)
  static const Color backgroundEnd = Color(0xFF0B0D11);

  /// 工具栏/面板背景色 / Toolbar/panel background color
  static const Color surface = Color(0xFF15181E);

  /// 卡片/列表项背景色 / Card/list item background color
  static const Color card = Color(0xFF1C2027);

  /// 选中项背景色（Teal 16% 透明，不再用紫）/ Selected item background (teal 16%)
  static const Color selected = Color(0x291FB8A6);

  // ===== 边框色 / Border colors =====

  /// 主边框色 / Primary border color
  static const Color border = Color(0xFF2A3038);

  /// 分隔线色 / Divider color
  static const Color divider = Color(0xFF20262E);

  // ===== 主题色 / Theme colors =====

  /// 主题 Teal 信号色 / Theme Teal signal accent
  static const Color primary = Color(0xFF1FB8A6);

  /// Teal 高亮（仅用于 hover/高亮，非渐变）/ Teal highlight (hover only)
  static const Color secondary = Color(0xFF7FE3D6);

  /// 强调色（与 primary 同） / Accent (same as primary)
  static const Color accent = Color(0xFF1FB8A6);

  // ===== 文本色 / Text colors =====

  /// 主文本色（柔白，非纯白）/ Primary text (soft white, not pure white)
  static const Color textPrimary = Color(0xFFE8EBF0);

  /// 次要文本色 / Secondary text color
  static const Color textSecondary = Color(0xFF9AA3B0);

  /// 提示文本色 / Hint text color
  static const Color textHint = Color(0xFF5E6773);

  // ===== 状态色 / Status colors =====

  /// 成功色 / Success color
  static const Color success = Color(0xFF5FD38B);

  /// 警告色 / Warning color
  static const Color warning = Color(0xFFF0B429);

  /// 错误色 / Error color
  static const Color error = Color(0xFFF06A6A);

  /// 信息色 / Info color
  static const Color info = Color(0xFF5AA9F0);

  // ===== 状态码颜色 / Status code colors =====

  /// 2xx 成功状态码颜色 / 2xx success status color
  static const Color statusSuccess = Color(0xFF5FD38B);

  /// 3xx 重定向状态码颜色 / 3xx redirect status color
  static const Color statusRedirect = Color(0xFFF0B429);

  /// 4xx 客户端错误状态码颜色 / 4xx client error status color
  static const Color statusClientError = Color(0xFFF0883E);

  /// 5xx 服务器错误状态码颜色 / 5xx server error status color
  static const Color statusServerError = Color(0xFFF06A6A);

  // ===== HTTP 方法颜色 / HTTP method colors =====

  /// GET 方法颜色 / GET method color
  static const Color methodGet = Color(0xFF5FD38B);

  /// POST 方法颜色 / POST method color
  static const Color methodPost = Color(0xFF5AA9F0);

  /// PUT 方法颜色 / PUT method color
  static const Color methodPut = Color(0xFFF0B429);

  /// DELETE 方法颜色 / DELETE method color
  static const Color methodDelete = Color(0xFFF06A6A);

  /// PATCH 方法颜色（仅作小标签，不用作品牌）/ PATCH method color (label only)
  static const Color methodPatch = Color(0xFFB08BDB);

  // ===== 日志级别颜色 / Log level colors =====

  /// Verbose 级别颜色 / Verbose level color
  static const Color logVerbose = Color(0xFF7A8492);

  /// Debug 级别颜色 / Debug level color
  static const Color logDebug = Color(0xFF5AA9F0);

  /// Info 级别颜色 / Info level color
  static const Color logInfo = Color(0xFF5FD38B);

  /// Warning 级别颜色 / Warning level color
  static const Color logWarning = Color(0xFFF0B429);

  /// Error 级别颜色 / Error level color
  static const Color logError = Color(0xFFF06A6A);

  /// Error 级别文本颜色 / Error level text color
  static const Color logErrorText = Color(0xFFF2A0A0);

  /// Warning 级别文本颜色 / Warning level text color
  static const Color logWarningText = Color(0xFFF4D35E);

  // ===== 路由操作颜色 / Route action colors =====

  /// push 操作颜色 / push action color
  static const Color routePush = Color(0xFF5FD38B);

  /// pop 操作颜色 / pop action color
  static const Color routePop = Color(0xFFF06A6A);

  /// pushReplacement 操作颜色 / pushReplacement action color
  static const Color routeReplace = Color(0xFFF0B429);
}

/// 检查器主题尺寸 / Inspector theme dimensions
class InspectorDimensions {
  InspectorDimensions._();

  /// 悬浮按钮尺寸 / Floating button size
  static const double floatingButtonSize = 52;

  /// 悬浮按钮图标尺寸 / Floating button icon size
  static const double floatingButtonIconSize = 24;

  /// 面板圆角（收紧，工具感）/ Panel border radius (tighter, tool-like)
  static const double panelRadius = 12;

  /// 卡片圆角 / Card border radius
  static const double cardRadius = 6;

  /// 小圆角 / Small border radius
  static const double smallRadius = 6;

  /// 标签圆角 / Chip border radius
  static const double chipRadius = 6;
}
