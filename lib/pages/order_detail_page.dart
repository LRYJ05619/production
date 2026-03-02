import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';

class OrderDetailPage extends StatefulWidget {
  final ApiTaskData task;
  final UserInfo userInfo;

  const OrderDetailPage({
    super.key,
    required this.task,
    required this.userInfo,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;

  late TextEditingController _qualifiedQtyController;
  late TextEditingController _workWasteQtyController;
  late TextEditingController _materialWasteQtyController;
  late TextEditingController _repairQtyController;
  late TextEditingController _lossQtyController;
  late TextEditingController _workHoursController;
  late TextEditingController _qcQualifiedQtyController;
  late TextEditingController _qcWasteQtyController;
  late TextEditingController _qcOpinionController;
  late TextEditingController _approvalNoteController;

  UserRole get _role => widget.userInfo.userRole;
  ApiTaskData get _task => widget.task;

  /// 判断当前用户是否可以操作（显示底部按钮）
  bool get _canOperate {
    return _task.canOperate(widget.userInfo);
  }

  /// 员工是否需要填写报工表单
  bool get _needWorkerForm {
    return _task.workerId == widget.userInfo.id &&
        (_task.status == ApiTaskStatus.leaderReject ||
            _task.status == ApiTaskStatus.qcReject ||
            _task.status == ApiTaskStatus.claimed);
  }

  /// 是否是槽道断料产品（仅断料工序需要单位转换：米↔根）
  bool get _isCaoDaoCutting {
    if (!_task.productName.contains('槽道')) return false;
    // 判断是否是断料工序
    final processName = _task.processName;
    final processCode = _task.plan?.processCode ?? '';
    return processName.contains('断料') || processCode == 'cutting';
  }

  /// 槽道单根长度（米），从规格型号解析
  /// 示例: "FPH 53/34-1900-Z（150）" → 1900mm → 1.9m
  double get _caoDaoLengthMeters {
    if (!_isCaoDaoCutting) return 0;
    String spec = _task.specModel;
    List<String> parts = spec.split('-');
    if (parts.length > 1) {
      // 第二段为长度(mm)，提取纯数字
      String lenStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
      double lengthMm = double.tryParse(lenStr) ?? 0;
      return lengthMm / 1000.0; // mm → m
    }
    return 0;
  }

  /// 是否非首道工序（需要校验转入数量）
  bool get _isNotFirstOper => _task.plan != null && !_task.plan!.isFirstOper;

  /// 转入数量（米）
  double get _transferInQty => _task.plan?.transferInQty ?? 0;

  /// 转入数量转换为根（槽道时）
  double get _transferInQtyDisplay {
    if (_isCaoDaoCutting && _caoDaoLengthMeters > 0) {
      return _transferInQty / _caoDaoLengthMeters;
    }
    return _transferInQty;
  }

  /// 显示单位
  String get _displayUnit {
    if (_isCaoDaoCutting) return '根';
    return _task.unit;
  }

  /// 将用户输入的数量（根）转为接口需要的数量（米）
  double _convertToApiQty(double inputQty) {
    if (_isCaoDaoCutting && _caoDaoLengthMeters > 0) {
      return inputQty * _caoDaoLengthMeters;
    }
    return inputQty;
  }

  /// 将接口数量（米）转为显示数量（根）
  double _convertToDisplayQty(double apiQty) {
    if (_isCaoDaoCutting && _caoDaoLengthMeters > 0) {
      return apiQty / _caoDaoLengthMeters;
    }
    return apiQty;
  }

  @override
  void initState() {
    super.initState();
    // 显示值：槽道产品转换为根
    final displayQualified = _convertToDisplayQty(_task.qualifiedQty);
    final displayWorkWaste = _convertToDisplayQty(_task.workWasteQty);
    final displayMaterialWaste = _convertToDisplayQty(_task.materialWasteQty);
    final displayRepair = _convertToDisplayQty(_task.repairQty);
    final displayLoss = _convertToDisplayQty(_task.lossQty);
    final displayQcQualified = _convertToDisplayQty(_task.qcQualifiedQty);
    final displayQcWaste = _convertToDisplayQty(_task.qcWasteQty);

    _qualifiedQtyController = TextEditingController(
        text: displayQualified > 0 ? '${displayQualified.toInt()}' : '');
    _workWasteQtyController = TextEditingController(
        text: displayWorkWaste > 0 ? '${displayWorkWaste.toInt()}' : '');
    _materialWasteQtyController = TextEditingController(
        text: displayMaterialWaste > 0
            ? '${displayMaterialWaste.toInt()}'
            : '');
    _repairQtyController = TextEditingController(
        text: displayRepair > 0 ? '${displayRepair.toInt()}' : '');
    _lossQtyController = TextEditingController(
        text: displayLoss > 0 ? '${displayLoss.toInt()}' : '');
    _workHoursController = TextEditingController(
        text: _task.workHours > 0 ? '${_task.workHours}' : '');
    _qcQualifiedQtyController = TextEditingController(
        text: displayQcQualified > 0 ? '${displayQcQualified.toInt()}' : '');
    _qcWasteQtyController = TextEditingController(
        text: displayQcWaste > 0 ? '${displayQcWaste.toInt()}' : '');
    _qcOpinionController = TextEditingController(text: _task.qcOpinion);
    _approvalNoteController = TextEditingController(text: _task.approvalNote);
  }

  @override
  void dispose() {
    _qualifiedQtyController.dispose();
    _workWasteQtyController.dispose();
    _materialWasteQtyController.dispose();
    _repairQtyController.dispose();
    _lossQtyController.dispose();
    _workHoursController.dispose();
    _qcQualifiedQtyController.dispose();
    _qcWasteQtyController.dispose();
    _qcOpinionController.dispose();
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
                  padding: const EdgeInsets.all(16), child: _buildContent())),
          if (_canOperate) _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _task.status.color.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _task.status.color,
                borderRadius: BorderRadius.circular(4)),
            child: Text(_task.status.text,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child:
              Text(_task.taskNo, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // 计划数量显示值（槽道转根）
    final displayAssignedQty = _convertToDisplayQty(_task.assignedQty.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('任务信息'),
        _buildInfoRow('订 单 编 号:', _task.orderNo),
        _buildInfoRow('产 品 编 码:', _task.productCode),
        _buildInfoRow('产 品 名 称:', _task.productName),
        _buildInfoRow('规 格 型 号:', _task.specModel),
        _buildInfoRow('工      序:', _task.processName),
        _buildInfoRow('计 划 数 量:',
            '${_isCaoDaoCutting ? displayAssignedQty.toInt() : _task.assignedQty.toInt()} $_displayUnit'),
        _buildInfoRow('计 划 工 时:', '${_task.planHours}小时'),
        _buildInfoRow('操  作  者:', _task.workerName),
        // 非首道工序时显示转入数量
        if (_isNotFirstOper)
          _buildInfoRow('转 入 数 量:',
              '${_isCaoDaoCutting ? _transferInQtyDisplay.toInt() : _transferInQty.toInt()} $_displayUnit'),
        ..._buildRoleContent(),
      ],
    );
  }

  List<Widget> _buildRoleContent() {
    switch (_role) {
      case UserRole.worker:
        return _buildWorkerContent();
      case UserRole.inspector:
        return _buildInspectorContent();
      case UserRole.leader:
        if (_task.workerId == widget.userInfo.id &&
            _task.status != ApiTaskStatus.pendingApproval &&
            _task.status != ApiTaskStatus.resubmit) {
          return _buildWorkerContent();
        }
        return _buildLeaderContent();
    }
  }

  List<Widget> _buildWorkerContent() {
    if (_task.status == ApiTaskStatus.assigned) {
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
            Expanded(
                child: Text('点击下方按钮领取任务后开始工作',
                    style: TextStyle(fontSize: 13)))
          ]),
        ),
      ];
    }

    if (_needWorkerForm) {
      return [
        const Divider(height: 32),
        _buildSectionTitle('完工报工'),
        // 非首道工序提示转入数量限制
        if (_isNotFirstOper) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.amber.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '非首道工序，提报总数量不能超过转入数量 '
                      '${_isCaoDaoCutting ? _transferInQtyDisplay.toInt() : _transferInQty.toInt()} $_displayUnit',
                  style: TextStyle(
                      fontSize: 12, color: Colors.amber.shade800),
                ),
              ),
            ]),
          ),
        ],
        _buildEditRow('完 成 数 量:', _qualifiedQtyController,
            suffix: _displayUnit),
        _buildEditRowSuffix('实 际 工 时:', _workHoursController, '小时'),
        _buildEditRow('工 废 数 量:', _workWasteQtyController,
            suffix: _displayUnit),
        _buildEditRow('料 废 数 量:', _materialWasteQtyController,
            suffix: _displayUnit),
        if (_task.rejectReason.isNotEmpty) ...[
          const Divider(height: 32),
          _buildSectionTitle('驳回原因', color: Colors.red),
          _buildRejectCard()
        ],
      ];
    }

    return [
      const Divider(height: 32),
      _buildSectionTitle('报工数据'),
      _buildInfoRow('完 成 数 量:',
          '${_convertToDisplayQty(_task.qualifiedQty).toInt()} $_displayUnit'),
      _buildInfoRow('实 际 工 时:', '${_task.workHours}小时'),
      _buildInfoRow('工 废 数 量:',
          '${_convertToDisplayQty(_task.workWasteQty).toInt()} $_displayUnit'),
      _buildInfoRow('料 废 数 量:',
          '${_convertToDisplayQty(_task.materialWasteQty).toInt()} $_displayUnit'),
    ];
  }

  List<Widget> _buildInspectorContent() {
    final widgets = <Widget>[
      const Divider(height: 32),
      _buildSectionTitle('员工报工'),
      _buildInfoRow('完 成 数 量:',
          '${_convertToDisplayQty(_task.qualifiedQty).toInt()} $_displayUnit'),
      _buildInfoRow('实 际 工 时:', '${_task.workHours}小时'),
      _buildInfoRow('工 废 数 量:',
          '${_convertToDisplayQty(_task.workWasteQty).toInt()} $_displayUnit'),
      _buildInfoRow('料 废 数 量:',
          '${_convertToDisplayQty(_task.materialWasteQty).toInt()} $_displayUnit'),
    ];

    if (_task.status.canQcOperate) {
      widgets.addAll([
        const Divider(height: 32),
        _buildSectionTitle('质检填报'),
        _buildEditRow('质检合格数:', _qcQualifiedQtyController,
            suffix: _displayUnit),
        _buildEditRow('质检废品数:', _qcWasteQtyController,
            suffix: _displayUnit),
        const SizedBox(height: 12),
        const Text('质检意见:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        _buildTextArea(_qcOpinionController, '请输入质检意见...'),
      ]);
    }
    return widgets;
  }

  List<Widget> _buildLeaderContent() {
    final widgets = <Widget>[];

    if (_task.status != ApiTaskStatus.claimed &&
        _task.status != ApiTaskStatus.assigned) {
      widgets.addAll([
        const Divider(height: 32),
        _buildSectionTitle('员工报工'),
        _buildInfoRow('完 成 数 量:',
            '${_convertToDisplayQty(_task.qualifiedQty).toInt()} $_displayUnit'),
        _buildInfoRow('实 际 工 时:', '${_task.workHours}小时'),
        _buildInfoRow('工 废 数 量:',
            '${_convertToDisplayQty(_task.workWasteQty).toInt()} $_displayUnit'),
        _buildInfoRow('料 废 数 量:',
            '${_convertToDisplayQty(_task.materialWasteQty).toInt()} $_displayUnit'),
      ]);
    }

    if (_task.status.canLeaderOperate) {
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
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
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
      if (_task.status == ApiTaskStatus.assigned) {
        return _buildSingleButton('领取任务', Colors.blue, _handleClaim);
      }
      return _buildSingleButton('提交报工', Colors.blue, _handleReport);
    }
    if (_role == UserRole.inspector) {
      return _buildTwoButtons('质检返工', Colors.red,
              () => _showRejectDialog('qc'), '质检通过', Colors.blue, () => _handleQc(true));
    }
    if (_role == UserRole.leader) {
      if (_task.workerId == widget.userInfo.id) {
        if (_task.status == ApiTaskStatus.assigned) {
          return _buildSingleButton('领取任务', Colors.blue, _handleClaim);
        }
        if (_task.status == ApiTaskStatus.claimed ||
            _task.status == ApiTaskStatus.leaderReject ||
            _task.status == ApiTaskStatus.qcReject) {
          return _buildSingleButton('提交报工', Colors.blue, _handleReport);
        }
      }
      return _buildTwoButtons(
          '返工修改',
          Colors.red,
              () => _showRejectDialog('leader'),
          '同意提报',
          Colors.blue,
              () => _handleApprove(true));
    }
    return const SizedBox(height: 40);
  }

  Widget _buildSingleButton(
      String text, Color color, VoidCallback onPressed) {
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
    final result = await _apiService.claimTask(_task.id);
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showApiResult(result, '领取成功');
      if (result.success) Navigator.pop(context, true);
    }
  }

  Future<void> _handleReport() async {
    if (_qualifiedQtyController.text.isEmpty) {
      _showError('请输入完成数量');
      return;
    }

    // 用户输入的是显示单位的数量（槽道为根，其他为原单位）
    final inputQualified =
        double.tryParse(_qualifiedQtyController.text) ?? 0;
    final inputWorkWaste =
        double.tryParse(_workWasteQtyController.text) ?? 0;
    final inputMaterialWaste =
        double.tryParse(_materialWasteQtyController.text) ?? 0;
    final inputRepair = double.tryParse(_repairQtyController.text) ?? 0;
    final inputLoss = double.tryParse(_lossQtyController.text) ?? 0;

    // 显示单位下的计划数量
    final displayAssigned =
    _convertToDisplayQty(_task.assignedQty.toDouble());

    if (inputQualified > (1.1 * displayAssigned) || inputQualified == 0) {
      _showError('完成数量异常，请重新填写');
      return;
    }

    // 非首道工序校验：提报总数量不能超过转入数量
    if (_isNotFirstOper) {
      final totalInput =
          inputQualified + inputWorkWaste + inputMaterialWaste;
      if (totalInput > _transferInQtyDisplay) {
        _showError(
            '提报总数量(${totalInput.toInt()})超过转入数量(${_transferInQtyDisplay.toInt()})，请检查');
        return;
      }
    }

    // 转换为接口需要的数量（槽道：根→米）
    final apiQualified = _convertToApiQty(inputQualified);
    final apiWorkWaste = _convertToApiQty(inputWorkWaste);
    final apiMaterialWaste = _convertToApiQty(inputMaterialWaste);
    final apiRepair = _convertToApiQty(inputRepair);
    final apiLoss = _convertToApiQty(inputLoss);
    final apiCompleted = apiQualified + apiWorkWaste + apiMaterialWaste;

    setState(() => _isSubmitting = true);
    final result = await _apiService.submitReport(
      taskId: _task.id,
      qualifiedQty: apiQualified,
      workWasteQty: apiWorkWaste,
      materialWasteQty: apiMaterialWaste,
      repairQty: apiRepair,
      lossQty: apiLoss,
      workHours: double.tryParse(_workHoursController.text) ?? 0,
      completedQty: apiCompleted,
    );
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showApiResult(result, '报工提交成功');
      if (result.success) Navigator.pop(context, true);
    }
  }

  Future<void> _handleQc(bool pass) async {
    if (pass) {
      if (_qcQualifiedQtyController.text.isEmpty) {
        _showError('请输入合格数量');
        return;
      }
      final inputQcQualified =
          double.tryParse(_qcQualifiedQtyController.text) ?? 0;
      final inputQcWaste =
          double.tryParse(_qcWasteQtyController.text) ?? 0;
      final displayQualified = _convertToDisplayQty(_task.qualifiedQty);
      if ((inputQcQualified + inputQcWaste) != displayQualified ||
          inputQcQualified == 0) {
        _showError('总数量与提报数量不符，请重新填写');
        return;
      }
    }

    // 转换为接口数量
    final apiQcQualified = _convertToApiQty(
        double.tryParse(_qcQualifiedQtyController.text) ?? 0);
    final apiQcWaste = _convertToApiQty(
        double.tryParse(_qcWasteQtyController.text) ?? 0);

    setState(() => _isSubmitting = true);
    final result = await _apiService.submitQcReview(
      taskId: _task.id,
      pass: pass,
      qcQualifiedQty: apiQcQualified,
      qcWasteQty: apiQcWaste,
      qcOpinion: _qcOpinionController.text,
    );
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showApiResult(result, pass ? '质检通过' : '已返工');
      if (result.success) Navigator.pop(context, true);
    }
  }

  Future<void> _handleApprove(bool approve) async {
    setState(() => _isSubmitting = true);
    final result = await _apiService.submitLeaderApproval(
        taskId: _task.id,
        pass: approve,
        note: _approvalNoteController.text);
    setState(() => _isSubmitting = false);
    if (mounted) {
      _showApiResult(result, approve ? '已同意提报' : '已返工');
      if (result.success) Navigator.pop(context, true);
    }
  }

  void _showRejectDialog(String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'qc' ? '质检返工' : '返工修改'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              type == 'qc' ? _handleQc(false) : _handleApprove(false);
            },
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认驳回',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 使用ApiResult显示结果，失败时显示服务器返回的具体错误信息
  void _showApiResult(ApiResult result, String successMsg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
        Text(result.success ? successMsg : (result.errorMessage ?? '操作失败')),
        backgroundColor: result.success ? Colors.green : Colors.red));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _buildSectionTitle(String title, {Color color = Colors.orange}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87))),
            Expanded(
                child: Text(value.isEmpty ? '-' : value,
                    style: const TextStyle(fontSize: 14)))
          ]),
    );
  }

  Widget _buildEditRow(String label, TextEditingController ctrl,
      {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
            width: 120,
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        isDense: true)))),
        if (suffix.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(suffix),
        ],
      ]),
    );
  }

  Widget _buildEditRowSuffix(
      String label, TextEditingController ctrl, String suffix) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
            width: 120,
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
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
        child: Text(_task.rejectReason,
            style: TextStyle(color: Colors.red.shade700)));
  }

  String _formatDateTime(DateTime? dt) => dt == null
      ? '-'
      : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}