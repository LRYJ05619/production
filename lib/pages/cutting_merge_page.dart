import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import 'order_detail_page.dart';

/// 工序定义
class ProcessType {
  final String code;          // 工序代码
  final String name;          // 工序名称
  final String unit;          // 单位
  final String mergeRule;     // 合并规则描述
  final IconData icon;        // 图标
  final Color color;          // 主题色

  const ProcessType({
    required this.code,
    required this.name,
    required this.unit,
    required this.mergeRule,
    required this.icon,
    required this.color,
  });

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
      name: '成组焊接',
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

  static ProcessType fromCode(String code) {
    return all.firstWhere(
          (e) => e.code == code,
      orElse: () {
        if (code.contains('welding')) return all.firstWhere((e) => e.code == 'group_welding');
        return all.first;
      },
    );
  }
}

/// 工序合并数据模型
class ProcessMergeData {
  final String id;
  final String processCode;      // 工序代码(API原始值)
  final String processName;      // 工序名称(用于判断断料)
  final String productType;      // 类型：预埋/外置
  final String material;         // 材质：碳钢/不锈钢
  final String model;            // 型号：52/34
  final double length;           // 长度(mm)
  final String shape;            // 直/弧
  final String groupType;        // 单/双/三
  final double spacing;          // 间距
  final String connector;        // 连接物体
  final String mergeKey;         // 合并键
  final List<ProcessTaskItem> tasks;  // 包含的任务列表
  final double totalQuantity;    // 合并后总数量（米，API原始值）
  final double totalMeters;      // 合并后总米数

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

  /// 单根长度（米）
  double get lengthMeters => length / 1000.0;

  /// 是否是断料工序（兼容API返回processCode或processName）
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
  final int id;               // 任务ID
  final String taskNo;
  final String orderNo;
  final String erpName;
  final String erpModel;
  final String shape;
  final String groupType;
  final double spacing;
  final String connector;
  final double quantity;       // 计划数量（API原始值，米）
  final double processQty;    // 分配数量（API原始值，米）
  final double length;        // 单根长度(mm)，用于转换

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

  /// 单根长度（米）
  double get lengthMeters => length / 1000.0;

  /// 分配数量转换为根
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

  /// 从真实 API 数据构建
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

/// 工序合并视图（任务清单）
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
  List<ProcessMergeData> _processData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refreshData() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final filter = FilterCriteria(workerId: widget.userInfo.id);
      final response = await _apiService.getTaskList(
        page: 1,
        pageSize: 100,
        filter: filter,
      );

      final List<ApiTaskData> tasks = response.data
          .where((t) => t.productName.contains('槽道'))
          .toList();

      final Map<String, ProcessMergeData> groups = {};

      for (var task in tasks) {
        final parsedInfo = _parseTaskInfo(task);

        final String processCode = task.processCode.isNotEmpty ? task.processCode : 'unknown';
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

      final List<ProcessMergeData> resultList = groups.values.map((group) {
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

      if (mounted) {
        setState(() {
          _processData = resultList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _processData = [];
          _isLoading = false;
        });
      }
    }
  }

  /// 解析任务规格字符串
  /// 示例输入: "FPH 53/34-1900-Z（150）" 或 "FPH 52/34-3000-R6670"
  Map<String, dynamic> _parseTaskInfo(ApiTaskData task) {
    String spec = task.specModel;
    String name = task.productName;

    String material = '碳钢';
    String model = '';
    double length = 0;
    String shape = 'Z'; // 默认直形
    String type = '预埋';

    // 1. 判断类型
    if (name.contains('外置')) type = '外置';

    // 2. 判断材质
    if (name.contains('不锈钢') || spec.toUpperCase().contains('304') || spec.toUpperCase().contains('316')) {
      material = '不锈钢';
    }

    // 3. 解析规格字符串
    // 先统一替换中文括号为英文括号
    String normalizedSpec = spec
        .replaceAll('（', '(')
        .replaceAll('）', ')');

    // 按 '-' 分割，例如 "FPH 53/34-1900-Z(150)" → ["FPH 53/34", "1900", "Z(150)"]
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

    // 提取长度（第二段，纯数字部分，单位mm）
    if (parts.length > 1) {
      String lenStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
      length = double.tryParse(lenStr) ?? 0;
    }

    // 提取形状（第三段开头字母，去掉括号内容）
    if (parts.length > 2) {
      // 去掉括号及其内容，例如 "Z(150)" → "Z", "R6670" → "R6670"
      String shapePart = parts[2].replaceAll(RegExp(r'[（(].*?[）)]'), '').trim().toUpperCase();
      if (shapePart.startsWith('R')) {
        shape = 'R'; // 弧形
      } else {
        shape = 'Z'; // 直形（包括Z开头和其他情况）
      }
    }

    return {
      'material': material,
      'model': model,
      'length': length,  // 单位mm
      'shape': shape,
      'type': type,
      'groupType': '',
      'spacing': 0.0,
      'connector': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_processData.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _processData.length,
        itemBuilder: (context, index) {
          final data = _processData[index];
          final process = ProcessType.fromCode(data.processCode);
          return _buildMergeCard(data, process);
        },
      ),
    );
  }

  Widget _buildMergeCard(ProcessMergeData data, ProcessType process) {
    final bool isGroupWelding = process.code == 'group_welding';
    final bool isArc = data.shape == 'R';
    final String shapeText = isArc ? '弧形' : '直形';
    final Color shapeColor = isArc ? Colors.cyan : Colors.teal;

    // 使用转换后的根数显示（仅断料工序转换）
    final bool isCutting = data.isCutting;
    final String displayUnit = isCutting ? '根' : process.unit;
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
    // 仅断料工序转换为根
    final String displayUnit = isCutting ? '根' : process.unit;
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
      // 提交成功后刷新列表
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