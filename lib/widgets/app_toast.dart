import 'dart:async';
import 'package:flutter/material.dart';

/// 顶部弹出提示框工具类
/// 使用方式：
///   AppToast.success(context, '操作成功');
///   AppToast.error(context, '操作失败');
///   AppToast.info(context, '提示信息');
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// 成功提示（绿色）
  static void success(BuildContext context, String message) {
    _show(context, message, Colors.green.shade600, Icons.check_circle_rounded);
  }

  /// 错误提示（红色）
  static void error(BuildContext context, String message) {
    _show(context, message, Colors.red.shade600, Icons.error_rounded);
  }

  /// 普通信息提示（蓝色）
  static void info(BuildContext context, String message) {
    _show(context, message, Colors.blue.shade600, Icons.info_rounded);
  }

  /// 警告提示（橙色）
  static void warning(BuildContext context, String message) {
    _show(context, message, Colors.orange.shade700, Icons.warning_rounded);
  }

  /// 根据ApiResult自动选择成功/失败样式
  static void fromResult(BuildContext context, dynamic result, String successMsg) {
    if (result.success == true) {
      success(context, successMsg);
    } else {
      error(context, result.errorMessage ?? '操作失败');
    }
  }

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    // 移除已有的提示
    _dismiss();

    final overlay = Overlay.of(context);

    final animController = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 300),
    );

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animController, curve: Curves.easeOutCubic));

    final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeOut),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        color: color,
        icon: icon,
        slideAnim: slideAnim,
        fadeAnim: fadeAnim,
        onDismiss: () => _dismissEntry(entry, animController),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
    animController.forward();

    // 自动消失
    _dismissTimer = Timer(const Duration(seconds: 2), () {
      _dismissEntry(entry, animController);
    });
  }

  static void _dismissEntry(OverlayEntry entry, AnimationController controller) {
    if (!controller.isDismissed) {
      controller.reverse().then((_) {
        if (entry.mounted) {
          entry.remove();
        }
        controller.dispose();
      });
    }
    if (_currentEntry == entry) {
      _currentEntry = null;
    }
  }

  static void _dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }
    _currentEntry = null;
  }
}

class _ToastOverlay extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final Animation<Offset> slideAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onDismiss;

  const _ToastOverlay({
    required this.message,
    required this.color,
    required this.icon,
    required this.slideAnim,
    required this.fadeAnim,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: slideAnim,
        child: FadeTransition(
          opacity: fadeAnim,
          child: GestureDetector(
            onTap: onDismiss,
            onVerticalDragEnd: (_) => onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDismiss,
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}