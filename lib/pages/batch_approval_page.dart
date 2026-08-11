import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/task_widgets.dart';

/// 班长批次分配审批页：把槽道合并批次的完成数量拆分到各个生产订单
/// 展示内容 = 报工界面的全部字段 + 每个报工型号对应的订单分配明细
class BatchApprovalPage extends StatefulWidget {
  final List<int> taskIds;

  /// 报工型号（由合并卡片传入）
  final String reportSpec;

  /// 工序名称
  final String processName;

  /// 显示单位（根/米）
  final String unit;

  /// 接口单位 ↔ 显示单位 换算器（接口返回的是米/组，页面上展示和填写的是根/米）
  final QtyConverter converter;

  /// 报工界面的信息字段（员工/计划数量/计划工时/... ）
  final List<InfoEntry> infoEntries;

  const BatchApprovalPage({
    super.key,
    required this.taskIds,
    this.reportSpec = '',
    this.processName = '',
    this.unit = '',
    this.converter = QtyConverter.identity,
    this.infoEntries = const [],
  });

  @override
  State<BatchApprovalPage> createState() => _BatchApprovalPageState();
}

class _BatchApprovalPageState extends State<BatchApprovalPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  BatchApprovalDetail? _detail;

  final Map<int, TextEditingController> _qualifiedCtrls = {};
  final Map<int, TextEditingController> _workWasteCtrls = {};
  final Map<int, TextEditingController> _materialWasteCtrls = {};
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    for (final c in _qualifiedCtrls.values) {
      c.dispose();
    }
    for (final c in _workWasteCtrls.values) {
      c.dispose();
    }
    for (final c in _materialWasteCtrls.values) {
      c.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final detail = await _apiService.getBatchApprovalDetail(taskIds: widget.taskIds);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
      _qualifiedCtrls.clear();
      _workWasteCtrls.clear();
      _materialWasteCtrls.clear();
      if (detail != null) {
        for (final t in detail.tasks) {
          // 监听输入变化，实时更新"已分配/待分配"提示
          _qualifiedCtrls[t.id] = TextEditingController()..addListener(_onAllocChanged);
          _workWasteCtrls[t.id] = TextEditingController()..addListener(_onAllocChanged);
          _materialWasteCtrls[t.id] = TextEditingController()..addListener(_onAllocChanged);
        }
      }
    });
  }

  void _onAllocChanged() {
    if (mounted) setState(() {});
  }

  double _sumControllers(Map<int, TextEditingController> ctrls) {
    double total = 0;
    for (final c in ctrls.values) {
      total += double.tryParse(c.text) ?? 0;
    }
    return total;
  }

  double _parse(TextEditingController? c) => double.tryParse(c?.text ?? '') ?? 0;

  /// 单个订单本次分配合计
  double _taskAllocated(int taskId) =>
      _parse(_qualifiedCtrls[taskId]) +
          _parse(_workWasteCtrls[taskId]) +
          _parse(_materialWasteCtrls[taskId]);

  /// 全批次已分配合计
  double get _allocatedTotal =>
      _sumControllers(_qualifiedCtrls) +
          _sumControllers(_workWasteCtrls) +
          _sumControllers(_materialWasteCtrls);

  /// 去掉浮点尾数的显示（2 而不是 2.0）
  String _fmt(double v) => formatQtyNum(v).toString();

  /// 接口单位 → 显示单位
  double _toDisplay(double apiQty) => widget.converter.toDisplay(apiQty);

  /// 批次总完成数量（显示单位）——班长分配填的是显示单位，校验也要在同一口径下比
  double get _batchTotalDisplay => _toDisplay(_detail?.totalCompletedQty ?? 0);

  Future<void> _submit(bool pass) async {
    final detail = _detail;
    if (detail == null) return;

    if (pass) {
      final double allocatedTotal = _allocatedTotal;
      final double batchTotal = _batchTotalDisplay;
      if ((allocatedTotal - batchTotal).abs() > 0.01) {
        AppToast.error(context,
            '分配总量 ${_fmt(allocatedTotal)} 与批次总量 ${_fmt(batchTotal)} 不符，请重新填写');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // 班长填的是显示单位（根/米），提交前换算回接口单位（米/组）
    double toApi(TextEditingController? c) =>
        truncateQty2(widget.converter.toApi(_parse(c)));

    final items = detail.tasks
        .map((t) => LeaderBatchApproveItem(
      taskId: t.id,
      qualifiedQty: toApi(_qualifiedCtrls[t.id]),
      workWasteQty: toApi(_workWasteCtrls[t.id]),
      materialWasteQty: toApi(_materialWasteCtrls[t.id]),
    ))
        .toList();

    final result = await _apiService.leaderBatchApprove(
      pass: pass,
      note: _noteCtrl.text,
      items: items,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final int code = result['code'] ?? 500;
    final String message = result['message'] ?? (pass ? '审批失败' : '驳回失败');

    if (code == 200) {
      AppToast.success(context, message);
      Navigator.pop(context, true);
    } else if (code == 206) {
      final data = result['data'] as Map<String, dynamic>? ?? {};
      final failedTasks = (data['failed_tasks'] as List? ?? [])
          .map((e) => LeaderBatchApproveFailedTask.fromJson(e as Map<String, dynamic>))
          .toList();
      _showPartialFailureDialog(message, failedTasks);
    } else {
      AppToast.error(context, message);
    }
  }

  void _showPartialFailureDialog(String message, List<LeaderBatchApproveFailedTask> failedTasks) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('部分金蝶同步失败'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 8),
                ...failedTasks.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${f.taskNo}: ${f.reason}',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('批次分配审批')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('获取批次详情失败'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
          ],
        ),
      )
          : _buildContent(),
      bottomNavigationBar: _detail == null ? null : _buildBottomButtons(),
    );
  }

  Widget _buildContent() {
    final detail = _detail!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ===== 报工型号 + 报工界面的全部字段 =====
        _buildReportInfoCard(),
        const SizedBox(height: 12),
        // ===== 批次汇总 + 分配进度 =====
        _buildBatchSummaryCard(detail),
        const SizedBox(height: 12),
        Text('按生产订单分配', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...detail.tasks.map(_buildTaskAllocationCard),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: '审批备注', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  /// 报工型号/工序名称/员工/计划数量/计划工时/计划完成时间/计工方式/工时类型/完成数量...
  Widget _buildReportInfoCard() {
    if (widget.reportSpec.isEmpty && widget.infoEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.reportSpec.isNotEmpty)
              Text(widget.reportSpec,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            if (widget.processName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.processName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ],
            if (widget.infoEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              buildInfoLayout(widget.infoEntries),
            ],
          ],
        ),
      ),
    );
  }

  /// 批次汇总 + 实时分配进度（避免班长凑完数字提交才发现对不上）
  /// 接口返回的是接口单位（米/组），展示前统一换算成显示单位（根/米）
  Widget _buildBatchSummaryCard(BatchApprovalDetail detail) {
    final double allocated = _allocatedTotal;
    final double remaining = _batchTotalDisplay - allocated;
    final bool matched = remaining.abs() <= 0.01;
    final String unit = widget.unit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('批次汇总', style: Theme.of(context).textTheme.titleMedium),
            if (detail.batchId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('批次号: ${detail.batchId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _buildSummaryItem(
                    '完成数量', _toDisplay(detail.totalCompletedQty), unit, Colors.blue),
                _buildSummaryItem(
                    '合格数量', _toDisplay(detail.totalQualifiedQty), unit, Colors.green),
                _buildSummaryItem(
                    '工废数量', _toDisplay(detail.totalWorkWasteQty), unit, Colors.orange),
                _buildSummaryItem('料废数量',
                    _toDisplay(detail.totalMaterialWasteQty), unit, Colors.red),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(matched ? Icons.check_circle : Icons.info_outline,
                    size: 16, color: matched ? Colors.green : Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    matched
                        ? '已分配 ${_fmt(allocated)} $unit，与批次总量一致'
                        : '已分配 ${_fmt(allocated)} $unit，还需分配 ${_fmt(remaining)} $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: matched ? Colors.green : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, String unit, Color color) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '$label: ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        TextSpan(
          text: '${_fmt(value)} $unit',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }

  /// 单个生产订单的分配卡片：订单单号 + 完整型号 + 可报工/本次分配数量 + 合格/工废/料废填写项
  /// 接口返回的数量都是接口单位，展示前统一换算
  Widget _buildTaskAllocationCard(ApiTaskData t) {
    final double allocated = _taskAllocated(t.id);
    final bool overReportable =
        t.reportableQty > 0 && allocated - _toDisplay(t.reportableQty) > 0.01;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '生产订单单号: ${t.orderNo.isNotEmpty ? t.orderNo : '-'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              t.specModel.isNotEmpty ? t.specModel : t.productName,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 6),
            buildInfoLayout([
              InfoEntry('可报工数量', _qtyText(t.reportableQty)),
              InfoEntry('本次分配数量', _qtyText(t.assignedQty)),
            ]),
            if (overReportable) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('填写数量已超过可报工数量',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAllocField('合格', _qualifiedCtrls[t.id]!),
                const SizedBox(width: 6),
                _buildAllocField('工废', _workWasteCtrls[t.id]!),
                const SizedBox(width: 6),
                _buildAllocField('料废', _materialWasteCtrls[t.id]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 接口单位数量 → 带单位的显示文本
  String _qtyText(double apiQty) => '${_fmt(_toDisplay(apiQty))} ${widget.unit}';

  Widget _buildAllocField(String label, TextEditingController ctrl) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
              hintText: '0',
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 槽道流程不需要班长驳回（接口的 pass 参数保留，这里固定传 true），
  /// 因此底部只有一个整宽的确认按钮，不会再出现按钮文字换行
  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () => _submit(true),
            child: _isSubmitting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('确认分配并审批通过', style: TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
