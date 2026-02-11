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
      unit: '根',
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
    // 简单映射，如果没有精确匹配，尝试模糊匹配
    return all.firstWhere(
          (e) => e.code == code,
      orElse: () {
        if (code.contains('welding')) return all.firstWhere((e) => e.code == 'group_welding');
        return all.first; // 默认为断料或第一个
      },
    );
  }
}

/// 工序合并数据模型
class ProcessMergeData {
  final String id;
  final String processCode;      // 工序代码
  final String productType;      // 类型：预埋/外置
  final String material;         // 材质：碳钢/不锈钢
  final String model;            // 型号：52/34
  final double length;           // 长度
  final String shape;            // 直/弧（弯弧、单焊、成组焊接、打磨用）
  final String groupType;        // 单/双/三（成组焊接用）
  final double spacing;          // 间距（成组焊接用）
  final String connector;        // 连接物体（成组焊接用）
  final String mergeKey;         // 合并键
  final List<ProcessTaskItem> tasks;  // 包含的任务列表
  final double totalQuantity;    // 合并后总数量 (对应 assignedQty 之和)
  final double totalMeters;      // 合并后总米数 (暂未实际计算，可保留)

  ProcessMergeData({
    required this.id,
    required this.processCode,
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
}

/// 任务明细项
class ProcessTaskItem {
  final int id;               // 任务ID (用于跳转)
  final String taskNo;
  final String orderNo;
  final String erpName;
  final String erpModel;
  final String shape;
  final String groupType;
  final double spacing;
  final String connector;
  final double quantity;       // 计划数量
  final double processQty;     // 分配数量

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
  });

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

  /// 刷新数据
  void refreshData() {
    _loadData();
  }

  /// 从 API 加载数据并分组
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 获取任务列表 (获取足够多的数据以进行聚合，分页可根据需求调整)
      // 这里假设获取当前用户的任务或者所有任务，根据业务逻辑调整
      // 如果是"任务清单"通常指当前用户的待办，这里传入 workerId
      final filter = FilterCriteria(workerId: widget.userInfo.id);
      final response = await _apiService.getTaskList(
        page: 1,
        pageSize: 100, // 获取较多数据以展示合并效果
        filter: filter,
      );

      // 过滤出名称包含"槽道"的任务
      final List<ApiTaskData> tasks = response.data
          .where((t) => t.productName.contains('槽道'))
          .toList();

      final Map<String, ProcessMergeData> groups = {};

      for (var task in tasks) {
        // 1. 解析规格型号信息
        final parsedInfo = _parseTaskInfo(task);

        // 2. 生成合并 Key
        // Key 规则: 工序 + 材质 + 型号 + 长度 + 形状 + (成组属性)
        final String processCode = task.processCode.isNotEmpty ? task.processCode : 'unknown';
        final String material = parsedInfo['material'];
        final String model = parsedInfo['model'];
        final double length = parsedInfo['length'];
        final String shape = parsedInfo['shape'];
        final String productType = parsedInfo['type'];

        final String key = '$processCode|$material|$model|$length|$shape|$productType';

        // 3. 构建任务项
        final taskItem = ProcessTaskItem.fromApiTask(task, parsedInfo);

        // 4. 聚合数据
        if (groups.containsKey(key)) {
          final existing = groups[key]!;
          existing.tasks.add(taskItem);
          // 重新计算总数 (ProcessMergeData 是 final 的，这里采用替换方式或需改为可变)
          // 为简单起见，我们暂存数据结构，最后统一构建 List<ProcessMergeData>
        } else {
          groups[key] = ProcessMergeData(
            id: key, // 临时 ID
            processCode: processCode,
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
            totalQuantity: 0, // 稍后计算
            totalMeters: 0,
          );
        }
      }

      // 5. 整理最终列表并计算总和
      final List<ProcessMergeData> resultList = groups.values.map((group) {
        double totalQty = 0;
        for (var t in group.tasks) {
          totalQty += t.processQty; // 使用分配数量汇总
        }
        return ProcessMergeData(
          id: group.id,
          processCode: group.processCode,
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
          totalMeters: 0, // 暂不计算总米数
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
  /// 示例输入: FPH 52/34-3000-R6670
  Map<String, dynamic> _parseTaskInfo(ApiTaskData task) {
    String spec = task.specModel;
    String name = task.productName;

    // 默认值
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

    // 3. 解析规格字符串 (简单分割逻辑)
    // 假设格式: 前缀 型号-长度-形状...
    // 例: "FPH 52/34-3000-R6670" 或 "FPH 52/34-2500-Z"
    List<String> parts = spec.split('-');

    if (parts.isNotEmpty) {
      // 尝试提取型号 (包含数字和斜杠的部分)
      // part[0] 可能是 "FPH 52/34"
      String part0 = parts[0];
      RegExp modelReg = RegExp(r'(\d+/\d+)');
      Match? match = modelReg.firstMatch(part0);
      if (match != null) {
        model = match.group(1) ?? '';
      } else {
        // 如果找不到 xx/xx 格式，尝试直接取最后一段空格后的内容
        List<String> subParts = part0.trim().split(' ');
        model = subParts.last;
      }
    }

    if (parts.length > 1) {
      // 长度通常在第二段
      String lenStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
      length = double.tryParse(lenStr) ?? 0;
    }

    if (parts.length > 2) {
      // 形状在第三段
      String shapePart = parts[2].trim().toUpperCase();
      if (shapePart.startsWith('R')) {
        shape = 'R'; // 弧形
      } else if (shapePart.startsWith('Z')) {
        shape = 'Z'; // 直形
      }
    } else {
      // 如果没有第三段，根据名称或全文猜测
      if (spec.toUpperCase().contains('R') && !spec.toUpperCase().contains('Z')) shape = 'R';
    }

    return {
      'material': material,
      'model': model,
      'length': length,
      'shape': shape,
      'type': type,
      // 这里的 groupType, spacing, connector 逻辑较复杂，需根据实际 spec 格式扩展
      // 暂时给默认空值
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
                label: const Text('刷新')
            ),
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
    // 形状显示
    final bool isArc = data.shape == 'R';
    final String shapeText = isArc ? '弧形' : '直形';
    final Color shapeColor = isArc ? Colors.cyan : Colors.teal;

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
                // 合计数量显示
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
                          '${data.totalQuantity.toInt()}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])
                      ),
                      Text(process.unit, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...data.tasks.map((task) => _buildTaskItem(task, process)),
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

  Widget _buildTaskItem(ProcessTaskItem task, ProcessType process) {
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.blue),
                      ],
                    ),
                  ),
                  // 单个任务的数量
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: process.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${task.processQty.toInt()} ${process.unit}',
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
    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在获取任务详情...'), duration: Duration(milliseconds: 500)),
    );

    // 调用API获取详情
    final taskDetail = await _apiService.getTaskDetail(taskId);

    if (!mounted) return;

    if (taskDetail != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailPage(task: taskDetail, userInfo: widget.userInfo),
        ),
      );
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