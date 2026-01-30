import 'package:flutter/material.dart';
import '../models/task_model.dart';

class OrderCompletePage extends StatelessWidget {
  final ApiTaskData task;
  final UserInfo userInfo;

  const OrderCompletePage({
    super.key,
    required this.task,
    required this.userInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userInfo.realName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBar(),
            const SizedBox(height: 16),

            _buildSectionTitle('任务信息'),
            _buildInfoRow('任 务 单 号:', task.taskNo),
            _buildInfoRow('订 单 编 号:', task.orderNo),
            _buildInfoRow('产 品 编 码:', task.productCode),
            _buildInfoRow('产 品 名 称:', task.productName),
            _buildInfoRow('工      序:', task.processName),
            _buildInfoRow('计 划 数 量:', '${task.assignedQty.toInt()}'),
            _buildInfoRow('计 划 工 时:', '${task.planHours}小时'),

            const Divider(height: 32),

            _buildSectionTitle('生产信息'),
            _buildInfoRow('操  作  者:', task.workerName),
            _buildInfoRow('完 成 数 量:', '${task.completedQty.toInt()}'),
            _buildInfoRow('自 检 合 格:', '${task.qualifiedQty.toInt()}'),
            _buildInfoRow('工 废 数 量:', '${task.workWasteQty.toInt()}'),
            _buildInfoRow('料 废 数 量:', '${task.materialWasteQty.toInt()}'),
            _buildInfoRow('返 修 数 量:', '${task.repairQty.toInt()}'),
            _buildInfoRow('损 耗 数 量:', '${task.lossQty.toInt()}'),
            _buildInfoRow('实 际 工 时:', '${task.workHours}小时'),
            if (task.workSummary.isNotEmpty)
              _buildInfoRow('工 作 摘 要:', task.workSummary),

            const Divider(height: 32),

            _buildSectionTitle('质检信息'),
            _buildInfoRow('质  检  员:', task.qcUserName),
            _buildInfoRow('质 检 合 格:', '${task.qcQualifiedQty.toInt()}'),
            _buildInfoRow('质 检 废 品:', '${task.qcWasteQty.toInt()}'),
            _buildInfoRow('质 检 意 见:', task.qcOpinion),
            _buildInfoRow('质 检 时 间:', _formatDateTime(task.qcTime)),

            const Divider(height: 32),

            _buildSectionTitle('审批信息'),
            _buildInfoRow('审  批  人:', task.approverName),
            _buildInfoRow('审 批 备 注:', task.approvalNote),
            _buildInfoRow('审 批 时 间:', _formatDateTime(task.approvalTime)),

            const Divider(height: 32),

            _buildSectionTitle('系统信息', color: Colors.grey),
            _buildInfoRow('创 建 时 间:', _formatDateTime(task.createdAt)),
            _buildInfoRow('更 新 时 间:', _formatDateTime(task.updatedAt)),
            if (task.kingdeeNo.isNotEmpty)
              _buildInfoRow('金 蝶 单 号:', task.kingdeeNo),
            _buildInfoRow('报 工 状 态:', _getReportStatusText(task.reportStatus)),
            _buildInfoRow('结 算 状 态:', task.isSettled ? '已结算' : '未结算'),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: task.status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: task.status.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: task.status.color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              task.status.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          Text(
            _formatDateTime(task.updatedAt),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color color = Colors.orange}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getReportStatusText(int status) {
    switch (status) {
      case 0:
        return '未报工';
      case 1:
        return '已报工';
      case 2:
        return '报工失败';
      default:
        return '未知';
    }
  }
}