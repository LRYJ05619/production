import 'package:flutter/material.dart';
import '../models/task_model.dart';

// ==================== 信息字段网格 ====================

/// 把"标签: 值"字段排成两列；fullWidth 的字段独占一行。
/// 用显式配对成行（而不是 Wrap）以避免整行字段前后出现半行空隙。
/// 槽道合并卡片与班长批次审批页共用，保证两处排版一致。
Widget buildInfoLayout(List<InfoEntry> entries) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // 尽量保持双列，只有极窄时才退化为单列（单列会让卡片高度翻倍）
      final bool singleColumn = constraints.maxWidth < 260;
      final double halfWidth =
      singleColumn ? constraints.maxWidth : (constraints.maxWidth - 6) / 2;

      final rows = <Widget>[];
      final pending = <InfoEntry>[];

      void flushPending() {
        if (pending.isEmpty) return;
        rows.add(Row(
          children: [
            for (int i = 0; i < pending.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              SizedBox(width: halfWidth, child: _buildInfoItem(pending[i])),
            ],
          ],
        ));
        pending.clear();
      }

      for (final e in entries) {
        if (e.fullWidth || singleColumn) {
          flushPending();
          rows.add(SizedBox(
              width: constraints.maxWidth, child: _buildInfoItem(e)));
        } else {
          pending.add(e);
          if (pending.length == 2) flushPending();
        }
      }
      flushPending();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            rows[i],
          ],
        ],
      );
    },
  );
}

Widget _buildInfoItem(InfoEntry e) {
  return Row(
    children: [
      Text('${e.label}: ',
          style: TextStyle(fontSize: 11, height: 1.25, color: Colors.grey[600])),
      Expanded(
        child: Text(
          e.value,
          style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

// ==================== 卡片操作按钮 ====================

/// 卡片底部的一个操作按钮
/// 文字用 FittedBox 缩放，保证多个按钮并排时长标签也不会溢出
Widget buildCardActionButton({
  required VoidCallback onPressed,
  required IconData icon,
  required String label,
  required Color color,
  bool outlined = false,
}) {
  final child = Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 15),
      const SizedBox(width: 4),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
      ),
    ],
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 4);

  if (outlined) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: padding,
        shape: shape,
      ),
      child: child,
    );
  }
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: padding,
      shape: shape,
    ),
    child: child,
  );
}

/// 把若干操作按钮并排放在同一行、平分宽度（按钮为空时不占位）
List<Widget> buildCardActionRow(List<Widget> buttons) {
  if (buttons.isEmpty) return const [];
  return [
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 34,
        child: Row(
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ),
    ),
  ];
}

/// 对话框底部按钮：强制排在同一行并平分宽度
/// AlertDialog 默认的 OverflowBar 在按钮较多/文字较长时会竖排，把弹窗拉得很长
List<Widget> buildDialogActionRow(List<Widget> buttons) {
  if (buttons.isEmpty) return const [];
  return [
    Row(
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: buttons[i]),
        ],
      ],
    ),
  ];
}

/// 对话框内的一个按钮，文字空间不足时自动缩放
Widget buildDialogButton({
  required VoidCallback onPressed,
  required String label,
  Color? color,
  bool filled = false,
}) {
  final text = FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(label, maxLines: 1),
  );
  if (filled) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: text,
    );
  }
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: text,
  );
}

// ==================== 卡片通用头部 ====================

/// 小标签（材质/预埋外置/状态等）
Widget buildSmallTag(String text, Color color) {
  if (text.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

/// 卡片头部：左侧放大的工序图标框（方便扫视工序）+ 右侧 报工型号/状态/标签
/// 槽道合并卡片与锚栓/C型钢任务卡片共用，保证两处展示一致
Widget buildTaskCardHeader({
  required String spec,
  required String processName,
  required IconData processIcon,
  required Color processColor,
  required String statusText,
  required Color statusColor,
  List<Widget> tags = const [],
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 放大的工序图标框
      Container(
        width: 54,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: processColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: processColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(processIcon, size: 20, color: processColor),
            const SizedBox(height: 2),
            // Flexible 让文字在固定高度的盒子内收缩省略，避免系统字体放大时溢出
            Flexible(
              child: Text(
                processName.isNotEmpty ? processName : '-',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    color: processColor),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 报工型号 + 状态
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    spec.isNotEmpty ? spec : '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                  ),
                ),
                const SizedBox(width: 6),
                buildSmallTag(statusText, statusColor),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: tags,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

// ==================== 生产任务卡片 ====================
class TaskCard extends StatelessWidget {
  final ApiTaskData task;

  /// 点击进入详情（仅班长传入；工人/质检为null，卡片不可点）
  final VoidCallback? onTap;

  /// 卡片内联操作，由调用方按角色和状态决定是否传入
  final VoidCallback? onClaim;
  final VoidCallback? onReport;
  final VoidCallback? onQc;
  final VoidCallback? onApprove;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onClaim,
    this.onReport,
    this.onQc,
    this.onApprove,
  });

  /// 与槽道卡片一致的信息字段
  List<InfoEntry> _infoEntries() {
    final String unit = task.unit;
    final entries = <InfoEntry>[
      InfoEntry('员工', task.workerName.isNotEmpty ? task.workerName : '-'),
      InfoEntry('计划数量', '${_fmt(task.assignedQty)} $unit'),
      InfoEntry('计划工时', task.planHours > 0 ? '${task.planHours}h' : '-'),
      InfoEntry('计工方式', task.workType.isNotEmpty ? task.workType : '-'),
      InfoEntry('工时类型', task.timeType.isNotEmpty ? task.timeType : '-'),
    ];
    // 完成数量/工废/料废随流程递进出现。
    // 质检通过后三者固定显示（即使为0），一来班长审批时能看到质检结果，
    // 二来保证半栏字段总数为偶数，工废/料废正好成对落在同一行
    final bool showWaste = task.status.isQcDone;
    if (showWaste || task.completedQty > 0) {
      entries.add(InfoEntry('完成数量', '${_fmt(task.completedQty)} $unit'));
    }
    if (showWaste || task.workWasteQty > 0) {
      entries.add(InfoEntry('工废数量', '${_fmt(task.workWasteQty)} $unit'));
    }
    if (showWaste || task.materialWasteQty > 0) {
      entries.add(InfoEntry('料废数量', '${_fmt(task.materialWasteQty)} $unit'));
    }
    // 计划完成时间标签长、值也长，半栏放不下，独占一行且排在所有成对字段之后
    entries.add(InfoEntry(
      '计划完成时间',
      task.planFinishTime != null ? _formatDate(task.planFinishTime!) : '-',
      fullWidth: true,
    ));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
    task.isExtraWork ? Colors.purple.shade200 : task.status.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      // 外框颜色与状态绑定
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildTaskCardHeader(
                spec: task.specModel.isNotEmpty ? task.specModel : task.productName,
                processName: task.processName,
                processIcon: task.isExtraWork ? Icons.work_outline : Icons.settings,
                processColor: task.isExtraWork ? Colors.purple : Colors.blueGrey,
                statusText: task.status.text,
                statusColor: task.status.color,
                tags: [
                  if (task.isExtraWork) buildSmallTag('计划外', Colors.purple),
                ],
              ),
              const SizedBox(height: 6),
              buildInfoLayout(_infoEntries()),
              ..._buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片内联操作按钮（领取/报工/质检/审批），多个按钮并排一行平分宽度
  List<Widget> _buildActions() {
    final buttons = <Widget>[
      if (onClaim != null)
        buildCardActionButton(
          onPressed: onClaim!,
          icon: Icons.check_circle_outline,
          label: '领取任务',
          color: Colors.blueGrey,
          outlined: true,
        ),
      if (onReport != null)
        buildCardActionButton(
          onPressed: onReport!,
          icon: Icons.send,
          label: '报工',
          color: Colors.blueGrey,
        ),
      if (onQc != null)
        buildCardActionButton(
          onPressed: onQc!,
          icon: Icons.fact_check_outlined,
          label: '质检',
          color: Colors.blue,
        ),
      if (onApprove != null)
        buildCardActionButton(
          onPressed: onApprove!,
          icon: Icons.approval_outlined,
          label: '审批',
          color: Colors.deepPurple,
        ),
    ];
    return buildCardActionRow(buttons);
  }

  /// 去掉浮点尾数（500 而不是 500.0）
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ==================== 计划外工作卡片 ====================
class ExtraWorkCard extends StatelessWidget {
  final ExtraWorkData work;
  final VoidCallback? onTap;

  const ExtraWorkCard({
    super.key,
    required this.work,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade300, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：类型标签 + 状态 + 编号
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '计划外',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: work.statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        work.statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        work.taskNo,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 12),

                // 工作内容
                Text(
                  work.workContent,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  work.workDescription,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // 分配时间
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      '分配时间: ${_formatDateTime(work.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 详细信息
                Row(
                  children: [
                    _buildInfoItem(Icons.location_on, work.location),
                    const SizedBox(width: 16),
                    _buildInfoItem(Icons.timer, '${work.planHours}小时'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildInfoItem(Icons.person, work.workerName),
                    const SizedBox(width: 16),
                    _buildInfoItem(Icons.schedule, _formatDateTimeNullable(work.planFinishTime)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text.isEmpty ? '-' : text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTimeNullable(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}