import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class ExtraWorkDetailPage extends StatefulWidget {
  final ExtraWorkData work;
  final UserInfo userInfo;

  const ExtraWorkDetailPage({
    super.key,
    required this.work,
    required this.userInfo,
  });

  @override
  State<ExtraWorkDetailPage> createState() => _ExtraWorkDetailPageState();
}

class _ExtraWorkDetailPageState extends State<ExtraWorkDetailPage> {
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;

  late TextEditingController _workHoursController;
  late TextEditingController _workSummaryController;
  late TextEditingController _approvalNoteController;

  UserRole get _role => widget.userInfo.userRole;
  ExtraWorkData get _work => widget.work;

  /// 判断当前用户是否可以操作
  bool get _canOperate {
    return _work.canOperate(widget.userInfo);
  }

  /// 员工是否需要填写报工表单
  bool get _needWorkerForm {
    return _work.workerId == widget.userInfo.id &&
        (_work.status == ApiTaskStatus.leaderReject ||
            _work.status == ApiTaskStatus.claimed);
  }

  @override
  void initState() {
    super.initState();
    _workHoursController = TextEditingController(
        text: _work.workHours > 0 ? '${_work.workHours}' : '');
    _workSummaryController = TextEditingController(text: _work.workSummary);
    _approvalNoteController = TextEditingController(text: _work.approvalNote);
  }

  @override
  void dispose() {
    _workHoursController.dispose();
    _workSummaryController.dispose();
    _approvalNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userInfo.realName)),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
          if (_canOperate) _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _work.statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('计划外',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _work.statusColor,
                borderRadius: BorderRadius.circular(4)),
            child: Text(_work.statusText,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(_work.displayWorkNo, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('任务信息'),
        _buildInfoRow('任 务 编 号:', _work.displayWorkNo),
        _buildInfoRow('工 作 内 容:', _work.displayWorkContent),
        _buildInfoRow('工 作 地 点:', _work.displayLocation),
        _buildInfoRow('工 作 说 明:', _work.displayWorkDescription),
        _buildInfoRow('计 划 工 时:', '${_work.displayPlanHours}小时'),
        _buildInfoRow('结 束 时 间:', _formatDateTime(_work.displayPlanFinishTime)),
        _buildInfoRow('操  作  者:', _work.workerName),
        if (_work.creatorName.isNotEmpty)
          _buildInfoRow('创  建  人:', _work.creatorName),
        if (_work.remark.isNotEmpty)
          _buildInfoRow('备      注:', _work.remark),
        ..._buildRoleContent(),
      ],
    );
  }

  List<Widget> _buildRoleContent() {
    switch (_role) {
      case UserRole.worker:
        return _buildWorkerContent();
      case UserRole.inspector:
      // 计划外工作不需要质检，质检员看到的是只读视图
        return _buildReadOnlyContent();
      case UserRole.leader:
        if (_work.workerId == widget.userInfo.id &&
            _work.status != ApiTaskStatus.pendingApproval &&
            _work.status != ApiTaskStatus.resubmit
        ) {
          return _buildWorkerContent();
        }
        return _buildLeaderContent();
    }
  }

  List<Widget> _buildWorkerContent() {
    // 已分配状态：显示领取提示
    if (_work.status == ApiTaskStatus.assigned) {
      return [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(child: Text('点击下方按钮领取任务后开始工作'))
          ]),
        ),
      ];
    }

    // 已领取、班长发回状态，显示报工表单
    if (_needWorkerForm) {
      return [
        const Divider(height: 32),
        _buildSectionTitle('完工报工'),
        _buildEditRowSuffix('实 际 工 时:', _workHoursController, '小时'),
        const SizedBox(height: 12),
        const Text('工作小结:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        _buildTextArea(_workSummaryController, '请输入工作小结...'),
        if (_work.rejectReason.isNotEmpty) ...[
          const Divider(height: 32),
          _buildSectionTitle('驳回原因', color: Colors.red),
          _buildRejectCard()
        ],
      ];
    }

    return _buildReadOnlyContent();
  }

  List<Widget> _buildReadOnlyContent() {
    return [
      const Divider(height: 32),
      _buildSectionTitle('报工数据'),
      _buildInfoRow('实 际 工 时:', '${_work.workHours}小时'),
      _buildInfoRow('工 作 小 结:', _work.workSummary),
    ];
  }

  List<Widget> _buildLeaderContent() {
    final widgets = <Widget>[];

    if (_work.status != ApiTaskStatus.claimed&&
        _work.status != ApiTaskStatus.assigned
    ) {
      widgets.addAll([
        const Divider(height: 32),
        _buildSectionTitle('员工报工'),
        _buildInfoRow('实 际 工 时:', '${_work.workHours}小时'),
        _buildInfoRow('工 作 小 结:', _work.workSummary),
      ]);
    }

    if (_work.status.canLeaderOperate) {
      widgets.addAll([
        const Divider(height: 32),
        _buildSectionTitle('审批'),
        const Text('审批备注:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        _buildTextArea(_approvalNoteController, '请输入审批备注...'),
      ]);
    }
    return widgets;
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2))
          ]),
      child: SafeArea(child: _buildButtons()),
    );
  }

  Widget _buildButtons() {
    if (_role == UserRole.worker) {
      if (_work.status == ApiTaskStatus.assigned) {
        return _buildSingleButton('领取任务', Colors.blue, _handleClaim);
      }
      return _buildSingleButton('提交报工', Colors.blue, _handleReport);
    }
    if (_role == UserRole.leader) {
      if (_work.workerId == widget.userInfo.id) {
        if (_work.status == ApiTaskStatus.assigned) {
          return _buildSingleButton('领取任务', Colors.blue, _handleClaim);
        }
        if (_work.status == ApiTaskStatus.claimed ||
            _work.status == ApiTaskStatus.leaderReject ||
            _work.status == ApiTaskStatus.qcReject) {
          return _buildSingleButton('提交报工', Colors.blue, _handleReport);
        }
      }
      return _buildTwoButtons(
          '返工修改', Colors.red, () => _showRejectDialog(),
          '同意提报', Colors.blue, () => _handleApprove(true));
    }
    return const SizedBox(height: 40);
  }

  Widget _buildSingleButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        child: _isSubmitting
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildTwoButtons(String text1, Color color1, VoidCallback onPressed1,
      String text2, Color color2, VoidCallback onPressed2) {
    return Row(
      children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _isSubmitting ? null : onPressed1,
                style: OutlinedButton.styleFrom(
                    foregroundColor: color1,
                    side: BorderSide(color: color1),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(text1, style: const TextStyle(fontSize: 16)))),
        const SizedBox(width: 16),
        Expanded(
            child: ElevatedButton(
                onPressed: _isSubmitting ? null : onPressed2,
                style: ElevatedButton.styleFrom(
                    backgroundColor: color2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isSubmitting
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Text(text2, style: const TextStyle(fontSize: 16)))),
      ],
    );
  }

  Future<void> _handleClaim() async {
    setState(() => _isSubmitting = true);
    final success = await _apiService.claimTask(_work.id);
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showResult(success, '领取成功', '领取失败');
      if (success) Navigator.pop(context, true);
    }
  }

  Future<void> _handleReport() async {
    final workHours = double.tryParse(_workHoursController.text) ?? 0;
    if (workHours <= 0) {
      _showError('请输入实际工时');
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await _apiService.submitReport(
      taskId: _work.id,
      completedQty: 1, // 计划外工作完成数量固定为1
      qualifiedQty: 1,
      workWasteQty: 0,
      materialWasteQty: 0,
      repairQty: 0,
      lossQty: 0,
      workHours: workHours,
    );
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showResult(success, '报工提交成功', '提交失败');
      if (success) Navigator.pop(context, true);
    }
  }

  Future<void> _handleApprove(bool approve) async {
    setState(() => _isSubmitting = true);
    final success = await _apiService.submitLeaderApproval(
        taskId: _work.id, pass: approve, note: _approvalNoteController.text);
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showResult(success, approve ? '已同意提报' : '已返工', '操作失败');
      if (success) Navigator.pop(context, true);
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('返工修改'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleApprove(false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认驳回', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResult(bool success, String successMsg, String failMsg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? successMsg : failMsg),
        backgroundColor: success ? Colors.green : Colors.red));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _buildSectionTitle(String title, {Color color = Colors.purple}) {
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black87))),
        Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 14)))
      ]),
    );
  }

  Widget _buildEditRowSuffix(
      String label, TextEditingController ctrl, String suffix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 14))),
        Expanded(
            child: Container(
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!)),
                child: TextField(
                    controller: ctrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true)))),
        const SizedBox(width: 8),
        Text(suffix)
      ]),
    );
  }

  Widget _buildTextArea(TextEditingController ctrl, String hint) {
    return Container(
        height: 100,
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!)),
        child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                hintText: hint)));
  }

  Widget _buildRejectCard() {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200)),
        child: Text(_work.rejectReason,
            style: TextStyle(color: Colors.red.shade700)));
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}