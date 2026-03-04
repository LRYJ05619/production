import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import 'order_detail_page.dart';

/// 工序定义
class ProcessType {
  final String code;
  final String name;
  final String unit;
  final String mergeRule;
  final IconData icon;
  final Color color;

  const ProcessType({
    required this.code,
    required this.name,
    required this.unit,
    required this.mergeRule,
    required this.icon,
    required this.color,
  });

  /// 获取显示单位（仅断料工序显示"根"）
  String getDisplayUnit(bool isCutting) {
    if (isCutting) return '根';
    return unit;
  }

  static const List<ProcessType> all = [
    ProcessType(
      code: 'cutting',
      name: '断料',
      unit: '米',
      mergeRule: '类型&材质&型号&长度',
      icon: Icons.content_cut,
      color: Colors.orange,
    ),
    ProcessType(
      code: 'bending',
      name: '弯弧',
      unit: '米',
      mergeRule: '类型&材质&型号&长度&直/弧',
      icon: Icons.rotate_right,
      color: Colors.blue,
    ),
    ProcessType(
      code: 'single_welding',
      name: '单焊',
      unit: '米',
      mergeRule: '类型&材质&型号&长度&直/弧',
      icon: Icons.flash_on,
      color: Colors.red,
    ),
    ProcessType(
      code: 'group_welding',
      name: '组焊',
      unit: '米',
      mergeRule: '类型&材质&型号&长度&直/弧&单/双/三&间距&连接物体',
      icon: Icons.group_work,
      color: Colors.purple,
    ),
    ProcessType(
      code: 'grinding',
      name: '打磨',
      unit: '米',
      mergeRule: '类型&材质&型号&长度&直/弧',
      icon: Icons.auto_fix_high,
      color: Colors.teal,
    ),
  ];

  /// 匹配工序，未知工序返回null
  static ProcessType? tryFromCode(String code) {
    // 先精确匹配英文code
    for (var p in all) {
      if (p.code == code) return p;
    }
    // 再匹配中文名称（API可能返回中文process_code）
    if (code.contains('断料')) return all.firstWhere((e) => e.code == 'cutting');
    if (code.contains('弯弧')) return all.firstWhere((e) => e.code == 'bending');
    if (code.contains('成组') || code.contains('组焊')) return all.firstWhere((e) => e.code == 'group_welding');
    if (code.contains('单焊') || code.contains('焊接')) return all.firstWhere((e) => e.code == 'single_welding');
    if (code.contains('打磨')) return all.firstWhere((e) => e.code == 'grinding');
    return null;
  }

  /// 兼容旧调用，未知工序默认返回断料
  static ProcessType fromCode(String code) {
    return tryFromCode(code) ?? all.first;
  }

  /// 是否为已知的5种合并工序
  static bool isKnownProcess(String code) {
    return tryFromCode(code) != null;
  }
}

/// 工序合并数据模型
class ProcessMergeData {
  final String id;
  final String processCode;
  final String processName;
  final String productType;
  final String material;
  final String model;
  final double length;           // mm
  final String shape;
  final String groupType;
  final double spacing;
  final String connector;
  final String mergeKey;
  final List<ProcessTaskItem> tasks;
  final double totalQuantity;    // API原始值（米）
  final double totalMeters;

  ProcessMergeData({
    required this.id,
    required this.processCode,
    required this.processName,
    required this.productType,
    required this.material,
    required this.model,
    required this.length,
    this.shape = '',
    this.groupType = '',
    this.spacing = 0,
    this.connector = '',
    required this.mergeKey,
    required this.tasks,
    required this.totalQuantity,
    required this.totalMeters,
  });

  double get lengthMeters => length / 1000.0;

  /// 是否是断料工序（兼容API返回英文code或中文名称）
  bool get isCutting =>
      processCode == 'cutting' ||
          processCode.contains('断料') ||
          processName.contains('断料');

  /// 总数量转换为根（仅断料工序）
  double get totalPieces {
    if (isCutting && lengthMeters > 0) {
      return totalQuantity / lengthMeters;
    }
    return totalQuantity;
  }
}

/// 任务明细项
class ProcessTaskItem {
  final int id;
  final String taskNo;
  final String orderNo;
  final String erpName;
  final String erpModel;
  final String shape;
  final String groupType;
  final double spacing;
  final String connector;
  final double quantity;
  final double processQty;    // API原始值（米）
  final double length;        // mm

  ProcessTaskItem({
    required this.id,
    required this.taskNo,
    required this.orderNo,
    required this.erpName,
    required this.erpModel,
    required this.shape,
    required this.groupType,
    required this.spacing,
    required this.connector,
    required this.quantity,
    required this.processQty,
    required this.length,
  });

  double get lengthMeters => length / 1000.0;

  double get processQtyPieces {
    if (lengthMeters > 0) {
      return processQty / lengthMeters;
    }
    return processQty;
  }

  /// 获取显示数量（仅断料工序转换为根）
  double getDisplayQty(bool isCutting) {
    if (isCutting && lengthMeters > 0) {
      return processQty / lengthMeters;
    }
    return processQty;
  }

  factory ProcessTaskItem.fromApiTask(ApiTaskData task, Map<String, dynamic> parsedInfo) {
    return ProcessTaskItem(
      id: task.id,
      taskNo: task.taskNo,
      orderNo: task.orderNo,
      erpName: task.productName,
      erpModel: task.specModel,
      shape: parsedInfo['shape'] ?? '',
      groupType: parsedInfo['groupType'] ?? '',
      spacing: parsedInfo['spacing'] ?? 0.0,
      connector: parsedInfo['connector'] ?? '',
      quantity: (task.planQty).toDouble(),
      processQty: (task.assignedQty).toDouble(),
      length: parsedInfo['length'] ?? 0.0,
    );
  }
}

/// 工序合并视图（任务清单）——班长可见全组、自己的置顶
class ProcessMergeView extends StatefulWidget {
  final UserInfo userInfo;

  const ProcessMergeView({
    super.key,
    required this.userInfo,
  });

  @override
  State<ProcessMergeView> createState() => ProcessMergeViewState();
}

class ProcessMergeViewState extends State<ProcessMergeView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;

  // 按worker分组的合并数据：key=workerName, value=该worker的合并结果
  Map<String, List<ProcessMergeData>> _workerGroupedData = {};
  // 排序后的worker名称（班长自己在最前）
  List<String> _sortedWorkerNames = [];

  bool get _isLeader => widget.userInfo.userRole == UserRole.leader;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refreshData() {
    _loadData();
  }

  /// 从API加载数据，按worker分组再按工序合并
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 班长：不限workerId，看全组；员工：只看自己
      final FilterCriteria filter;
      if (_isLeader) {
        filter = FilterCriteria(); // 班长看所有
      } else {
        filter = FilterCriteria(workerId: widget.userInfo.id);
      }

      final response = await _apiService.getTaskList(
        page: 1,
        pageSize: 200,
        filter: filter,
      );

      // 过滤出名称包含"槽道"的任务
      final List<ApiTaskData> tasks = response.data
          .where((t) => t.productName.contains('槽道'))
          .toList();

      // 第一步：按worker分组
      final Map<String, List<ApiTaskData>> tasksByWorker = {};
      for (var task in tasks) {
        final workerName = task.workerName.isEmpty ? '未分配' : task.workerName;
        tasksByWorker.putIfAbsent(workerName, () => []).add(task);
      }

      // 第二步：对每个worker的任务做工序合并
      final Map<String, List<ProcessMergeData>> grouped = {};
      for (var entry in tasksByWorker.entries) {
        grouped[entry.key] = _buildMergeGroups(entry.value);
      }

      // 第三步：排序，班长自己在最前
      final sortedNames = grouped.keys.toList();
      final leaderName = widget.userInfo.realName;
      sortedNames.sort((a, b) {
        if (a == leaderName) return -1;
        if (b == leaderName) return 1;
        return a.compareTo(b);
      });

      if (mounted) {
        setState(() {
          _workerGroupedData = grouped;
          _sortedWorkerNames = sortedNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _workerGroupedData = {};
          _sortedWorkerNames = [];
          _isLoading = false;
        });
      }
    }
  }

  /// 将一组任务按工序属性合并
  List<ProcessMergeData> _buildMergeGroups(List<ApiTaskData> tasks) {
    final Map<String, ProcessMergeData> groups = {};

    for (var task in tasks) {
      final String processCode = task.processCode.isNotEmpty ? task.processCode : task.processName;

      // 跳过非5种已知工序的任务
      if (!ProcessType.isKnownProcess(processCode) && !ProcessType.isKnownProcess(task.processName)) continue;

      final parsedInfo = _parseTaskInfo(task);
      final String processName = task.processName;
      final String material = parsedInfo['material'];
      final String model = parsedInfo['model'];
      final double length = parsedInfo['length'];
      final String shape = parsedInfo['shape'];
      final String productType = parsedInfo['type'];

      final String key = '$processCode|$material|$model|$length|$shape|$productType';

      final taskItem = ProcessTaskItem.fromApiTask(task, parsedInfo);

      if (groups.containsKey(key)) {
        groups[key]!.tasks.add(taskItem);
      } else {
        groups[key] = ProcessMergeData(
          id: key,
          processCode: processCode,
          processName: processName,
          productType: productType,
          material: material,
          model: model,
          length: length,
          shape: shape,
          groupType: parsedInfo['groupType'] ?? '',
          spacing: parsedInfo['spacing'] ?? 0.0,
          connector: parsedInfo['connector'] ?? '',
          mergeKey: key,
          tasks: [taskItem],
          totalQuantity: 0,
          totalMeters: 0,
        );
      }
    }

    // 计算总数
    return groups.values.map((group) {
      double totalQty = 0;
      for (var t in group.tasks) {
        totalQty += t.processQty;
      }
      return ProcessMergeData(
        id: group.id,
        processCode: group.processCode,
        processName: group.processName,
        productType: group.productType,
        material: group.material,
        model: group.model,
        length: group.length,
        shape: group.shape,
        groupType: group.groupType,
        spacing: group.spacing,
        connector: group.connector,
        mergeKey: group.mergeKey,
        tasks: group.tasks,
        totalQuantity: totalQty,
        totalMeters: 0,
      );
    }).toList();
  }

  /// 解析任务规格字符串
  /// 示例: "FPH 53/34-1900-Z（150）" 或 "FPH 52/34-3000-R6670"
  Map<String, dynamic> _parseTaskInfo(ApiTaskData task) {
    String spec = task.specModel;
    String name = task.productName;

    String material = '碳钢';
    String model = '';
    double length = 0;
    String shape = 'Z';
    String type = '预埋';

    if (name.contains('外置')) type = '外置';

    if (name.contains('不锈钢') || spec.toUpperCase().contains('304') || spec.toUpperCase().contains('316')) {
      material = '不锈钢';
    }

    // 统一中文括号为英文括号
    String normalizedSpec = spec
        .replaceAll('（', '(')
        .replaceAll('）', ')');

    List<String> parts = normalizedSpec.split('-');

    // 提取型号（xx/xx 格式）
    if (parts.isNotEmpty) {
      String part0 = parts[0];
      RegExp modelReg = RegExp(r'(\d+/\d+)');
      Match? match = modelReg.firstMatch(part0);
      if (match != null) {
        model = match.group(1) ?? '';
      } else {
        List<String> subParts = part0.trim().split(' ');
        model = subParts.last;
      }
    }

    // 提取长度(mm)
    if (parts.length > 1) {
      String lenStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
      length = double.tryParse(lenStr) ?? 0;
    }

    // 提取形状
    if (parts.length > 2) {
      String shapePart = parts[2].replaceAll(RegExp(r'[（(].*?[）)]'), '').trim().toUpperCase();
      if (shapePart.startsWith('R')) {
        shape = 'R';
      } else {
        shape = 'Z';
      }
    }

    return {
      'material': material,
      'model': model,
      'length': length,
      'shape': shape,
      'type': type,
      'groupType': '',
      'spacing': 0.0,
      'connector': '',
    };
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 检查是否有数据
    final bool isEmpty = _workerGroupedData.isEmpty ||
        _workerGroupedData.values.every((list) => list.isEmpty);

    if (isEmpty) {
      return _buildEmptyView();
    }

    // 构建分组列表
    final List<Widget> items = [];

    for (final workerName in _sortedWorkerNames) {
      final mergeGroups = _workerGroupedData[workerName]!;
      if (mergeGroups.isEmpty) continue;

      final bool isMe = workerName == widget.userInfo.realName;

      // 计算该worker的总任务数
      int taskCount = 0;
      for (var g in mergeGroups) {
        taskCount += g.tasks.length;
      }

      // 如果是班长视图(有多人)，显示worker分组头
      if (_isLeader || _sortedWorkerNames.length > 1) {
        items.add(_buildWorkerHeader(workerName, taskCount, isMe: isMe));
      }

      // 该worker的合并卡片
      for (final data in mergeGroups) {
        final process = ProcessType.fromCode(data.processName);
        items.add(_buildMergeCard(data, process));
      }
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: items,
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('暂无槽道任务数据', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新')),
        ],
      ),
    );
  }

  /// worker分组头（类似生产任务的分组头，班长自己高亮）
  Widget _buildWorkerHeader(String workerName, int taskCount, {bool isMe = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.orange.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: isMe ? Border.all(color: Colors.orange.shade200) : null,
      ),
      child: Row(
        children: [
          Icon(isMe ? Icons.star : Icons.person, size: 18,
              color: isMe ? Colors.orange : Colors.grey),
          const SizedBox(width: 8),
          Text(
            isMe ? '$workerName（我）' : workerName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isMe ? Colors.orange.shade800 : null,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isMe ? Colors.orange : Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$taskCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeCard(ProcessMergeData data, ProcessType process) {
    final bool isGroupWelding = process.code == 'group_welding';
    final bool isArc = data.shape == 'R';
    final String shapeText = isArc ? '弧形' : '直形';
    final Color shapeColor = isArc ? Colors.cyan : Colors.teal;

    final bool isCutting = data.isCutting;
    final String displayUnit = process.getDisplayUnit(isCutting);
    final int displayTotalQty = isCutting ? data.totalPieces.round() : data.totalQuantity.toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: process.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: process.color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(process.icon, size: 20, color: process.color),
                const SizedBox(height: 2),
                Text(
                  process.name.length > 2 ? process.name.substring(0, 2) : process.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: process.color,
                  ),
                ),
              ],
            ),
          ),
          title: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${data.material} ${data.model} ${data.length.toInt()}mm',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              _buildTag(shapeText, shapeColor),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildTag(data.productType, Colors.purple),
                if (isGroupWelding && data.groupType.isNotEmpty)
                  _buildTag('${data.groupType}根', Colors.indigo),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('合计: ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      Text(
                          '$displayTotalQty',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                      Text(displayUnit, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...data.tasks.map((task) => _buildTaskItem(task, process, data.isCutting)),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildTaskItem(ProcessTaskItem task, ProcessType process, bool isCutting) {
    final String displayUnit = process.getDisplayUnit(isCutting);
    final int displayQty = task.getDisplayQty(isCutting).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToTaskDetail(task.id),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                            task.taskNo,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.blue),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: process.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '$displayQty $displayUnit',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: process.color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(task.erpName, style: TextStyle(fontSize: 11, color: Colors.grey[800])),
              const SizedBox(height: 2),
              Text(task.erpModel, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToTaskDetail(int taskId) async {
    final taskDetail = await _apiService.getTaskDetail(taskId);

    if (!mounted) return;

    if (taskDetail != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailPage(task: taskDetail, userInfo: widget.userInfo),
        ),
      );
      if (result == true) {
        _loadData();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('获取任务详情失败'), backgroundColor: Colors.red),
      );
    }
  }
}

/// 兼容旧类名
class CuttingMergePage extends StatelessWidget {
  final UserInfo userInfo;
  const CuttingMergePage({super.key, required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('任务清单')),
      body: ProcessMergeView(userInfo: userInfo),
    );
  }
}