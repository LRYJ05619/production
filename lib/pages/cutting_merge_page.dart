import 'package:flutter/material.dart';
import '../models/task_model.dart';

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
}

/// 工序合并数据模型
class ProcessMergeData {
  final String id;
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
  final double totalQuantity;    // 合并后总数量
  final double totalMeters;      // 合并后总米数

  ProcessMergeData({
    required this.id,
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

  factory ProcessMergeData.fromJson(Map<String, dynamic> json) {
    return ProcessMergeData(
      id: json['id']?.toString() ?? '',
      productType: json['product_type'] ?? '',
      material: json['material'] ?? '',
      model: json['model'] ?? '',
      length: (json['length'] ?? 0).toDouble(),
      shape: json['shape'] ?? '',
      groupType: json['group_type'] ?? '',
      spacing: (json['spacing'] ?? 0).toDouble(),
      connector: json['connector'] ?? '',
      mergeKey: json['merge_key'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((e) => ProcessTaskItem.fromJson(e))
          .toList() ?? [],
      totalQuantity: (json['total_quantity'] ?? 0).toDouble(),
      totalMeters: (json['total_meters'] ?? 0).toDouble(),
    );
  }
}

/// 任务明细项
class ProcessTaskItem {
  final String taskNo;
  final String orderNo;
  final String erpName;
  final String erpModel;
  final String shape;
  final String groupType;
  final double spacing;
  final String connector;
  final double quantity;       // 原始数量（米）
  final double processQty;     // 工序数量（根或米）

  ProcessTaskItem({
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

  factory ProcessTaskItem.fromJson(Map<String, dynamic> json) {
    return ProcessTaskItem(
      taskNo: json['task_no'] ?? '',
      orderNo: json['order_no'] ?? '',
      erpName: json['erp_name'] ?? '',
      erpModel: json['erp_model'] ?? '',
      shape: json['shape'] ?? '',
      groupType: json['group_type'] ?? '',
      spacing: (json['spacing'] ?? 0).toDouble(),
      connector: json['connector'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      processQty: (json['process_qty'] ?? 0).toDouble(),
    );
  }
}

/// 工序合并视图（作为主页的Tab）
class ProcessMergeView extends StatefulWidget {
  final UserInfo userInfo;

  const ProcessMergeView({
    super.key,
    required this.userInfo,
  });

  @override
  State<ProcessMergeView> createState() => ProcessMergeViewState();
}

class ProcessMergeViewState extends State<ProcessMergeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<ProcessMergeData>> _processData = {};
  bool _isLoading = true;
  String _selectedMaterial = '全部';
  String _selectedType = '全部';

  final List<String> _materialOptions = ['全部', '碳钢', '不锈钢'];
  final List<String> _typeOptions = ['全部', '预埋', '外置'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ProcessType.all.length, vsync: this);
    _loadDemoData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 刷新数据
  void refreshData() {
    _loadDemoData();
  }

  /// 加载演示数据
  void _loadDemoData() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _processData = _generateAllProcessData();
          _isLoading = false;
        });
      }
    });
  }

  /// 生成所有工序的演示数据
  Map<String, List<ProcessMergeData>> _generateAllProcessData() {
    return {
      'cutting': _generateCuttingData(),
      'bending': _generateBendingData(),
      'single_welding': _generateSingleWeldingData(),
      'group_welding': _generateGroupWeldingData(),
      'grinding': _generateGrindingData(),
    };
  }

  /// 断料数据：按 类型&材质&型号&长度 合并
  List<ProcessMergeData> _generateCuttingData() {
    return [
      ProcessMergeData(
        id: 'C1',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000,
        mergeKey: '预埋&碳钢&52/34&3000',
        totalQuantity: 45, totalMeters: 135,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-001', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-R6670', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 60, processQty: 20),
          ProcessTaskItem(taskNo: 'TASK-002', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-Z', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 45, processQty: 15),
          ProcessTaskItem(taskNo: 'TASK-003', orderNo: 'ST-CD-2025-002', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-3000-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 30, processQty: 10),
        ],
      ),
      ProcessMergeData(
        id: 'C2',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500,
        mergeKey: '预埋&碳钢&52/34&2500',
        totalQuantity: 72, totalMeters: 180,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-004', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-Z', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 75, processQty: 30),
          ProcessTaskItem(taskNo: 'TASK-005', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾三根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-Z（150-150）', shape: 'Z', groupType: '三', spacing: 150, connector: '圆钢', quantity: 55, processQty: 22),
          ProcessTaskItem(taskNo: 'TASK-006', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 50, processQty: 20),
        ],
      ),
      ProcessMergeData(
        id: 'C3',
        productType: '预埋', material: '不锈钢', model: '52/34', length: 2500,
        mergeKey: '预埋&不锈钢&52/34&2500',
        totalQuantity: 36, totalMeters: 90,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-007', orderNo: 'ST-CD-2025-001', erpName: '不锈钢弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-R6100 A4', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 40, processQty: 16),
          ProcessTaskItem(taskNo: 'TASK-008', orderNo: 'ST-CD-2025-001', erpName: '不锈钢直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-Z A4', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 50, processQty: 20),
        ],
      ),
      ProcessMergeData(
        id: 'C4',
        productType: '外置', material: '碳钢', model: '52/34', length: 2500,
        mergeKey: '外置&碳钢&52/34&2500',
        totalQuantity: 24, totalMeters: 60,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-009', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾三根成组外置槽道',
              erpModel: 'FPH 52/34-2500-Z（150-150）', shape: 'Z', groupType: '三', spacing: 150, connector: '扁钢', quantity: 60, processQty: 24),
        ],
      ),
    ];
  }

  /// 弯弧数据：按 类型&材质&型号&长度&直/弧 合并（只有弧形需要弯弧）
  List<ProcessMergeData> _generateBendingData() {
    return [
      ProcessMergeData(
        id: 'B1',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000, shape: 'R',
        mergeKey: '预埋&碳钢&52/34&3000&R',
        totalQuantity: 90, totalMeters: 90,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-001', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-R6670', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 60, processQty: 60),
          ProcessTaskItem(taskNo: 'TASK-003', orderNo: 'ST-CD-2025-002', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-3000-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 30, processQty: 30),
        ],
      ),
      ProcessMergeData(
        id: 'B2',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500, shape: 'R',
        mergeKey: '预埋&碳钢&52/34&2500&R',
        totalQuantity: 50, totalMeters: 50,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-006', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 50, processQty: 50),
        ],
      ),
      ProcessMergeData(
        id: 'B3',
        productType: '预埋', material: '不锈钢', model: '52/34', length: 2500, shape: 'R',
        mergeKey: '预埋&不锈钢&52/34&2500&R',
        totalQuantity: 40, totalMeters: 40,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-007', orderNo: 'ST-CD-2025-001', erpName: '不锈钢弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-R6100 A4', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 40, processQty: 40),
        ],
      ),
    ];
  }

  /// 单焊数据：按 类型&材质&型号&长度&直/弧 合并（只有单根需要单焊）
  List<ProcessMergeData> _generateSingleWeldingData() {
    return [
      ProcessMergeData(
        id: 'S1',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000, shape: 'R',
        mergeKey: '预埋&碳钢&52/34&3000&R',
        totalQuantity: 60, totalMeters: 60,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-001', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-R6670', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 60, processQty: 60),
        ],
      ),
      ProcessMergeData(
        id: 'S2',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000, shape: 'Z',
        mergeKey: '预埋&碳钢&52/34&3000&Z',
        totalQuantity: 45, totalMeters: 45,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-002', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-Z', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 45, processQty: 45),
        ],
      ),
      ProcessMergeData(
        id: 'S3',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500, shape: 'Z',
        mergeKey: '预埋&碳钢&52/34&2500&Z',
        totalQuantity: 75, totalMeters: 75,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-004', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-Z', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 75, processQty: 75),
        ],
      ),
      ProcessMergeData(
        id: 'S4',
        productType: '预埋', material: '不锈钢', model: '52/34', length: 2500, shape: 'R',
        mergeKey: '预埋&不锈钢&52/34&2500&R',
        totalQuantity: 40, totalMeters: 40,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-007', orderNo: 'ST-CD-2025-001', erpName: '不锈钢弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-R6100 A4', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 40, processQty: 40),
        ],
      ),
      ProcessMergeData(
        id: 'S5',
        productType: '预埋', material: '不锈钢', model: '52/34', length: 2500, shape: 'Z',
        mergeKey: '预埋&不锈钢&52/34&2500&Z',
        totalQuantity: 50, totalMeters: 50,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-008', orderNo: 'ST-CD-2025-001', erpName: '不锈钢直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-Z A4', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 50, processQty: 50),
        ],
      ),
    ];
  }

  /// 成组焊接数据：按 类型&材质&型号&长度&直/弧&单/双/三&间距&连接物体 合并
  List<ProcessMergeData> _generateGroupWeldingData() {
    return [
      ProcessMergeData(
        id: 'G1',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000,
        shape: 'R', groupType: '双', spacing: 400, connector: '圆钢',
        mergeKey: '预埋&碳钢&52/34&3000&R&双&400&圆钢',
        totalQuantity: 30, totalMeters: 30,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-003', orderNo: 'ST-CD-2025-002', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-3000-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 30, processQty: 30),
        ],
      ),
      ProcessMergeData(
        id: 'G2',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500,
        shape: 'Z', groupType: '三', spacing: 150, connector: '圆钢',
        mergeKey: '预埋&碳钢&52/34&2500&Z&三&150&圆钢',
        totalQuantity: 55, totalMeters: 55,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-005', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾三根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-Z（150-150）', shape: 'Z', groupType: '三', spacing: 150, connector: '圆钢', quantity: 55, processQty: 55),
        ],
      ),
      ProcessMergeData(
        id: 'G3',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500,
        shape: 'R', groupType: '双', spacing: 400, connector: '圆钢',
        mergeKey: '预埋&碳钢&52/34&2500&R&双&400&圆钢',
        totalQuantity: 50, totalMeters: 50,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-006', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 50, processQty: 50),
        ],
      ),
      ProcessMergeData(
        id: 'G4',
        productType: '外置', material: '碳钢', model: '52/34', length: 2500,
        shape: 'Z', groupType: '三', spacing: 150, connector: '扁钢',
        mergeKey: '外置&碳钢&52/34&2500&Z&三&150&扁钢',
        totalQuantity: 60, totalMeters: 60,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-009', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾三根成组外置槽道',
              erpModel: 'FPH 52/34-2500-Z（150-150）', shape: 'Z', groupType: '三', spacing: 150, connector: '扁钢', quantity: 60, processQty: 60),
        ],
      ),
    ];
  }

  /// 打磨数据：按 类型&材质&型号&长度&直/弧 合并
  List<ProcessMergeData> _generateGrindingData() {
    return [
      ProcessMergeData(
        id: 'P1',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000, shape: 'R',
        mergeKey: '预埋&碳钢&52/34&3000&R',
        totalQuantity: 90, totalMeters: 90,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-001', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-R6670', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 60, processQty: 60),
          ProcessTaskItem(taskNo: 'TASK-003', orderNo: 'ST-CD-2025-002', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-3000-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 30, processQty: 30),
        ],
      ),
      ProcessMergeData(
        id: 'P2',
        productType: '预埋', material: '碳钢', model: '52/34', length: 3000, shape: 'Z',
        mergeKey: '预埋&碳钢&52/34&3000&Z',
        totalQuantity: 45, totalMeters: 45,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-002', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-3000-Z', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 45, processQty: 45),
        ],
      ),
      ProcessMergeData(
        id: 'P3',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500, shape: 'Z',
        mergeKey: '预埋&碳钢&52/34&2500&Z',
        totalQuantity: 130, totalMeters: 130,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-004', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-Z', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 75, processQty: 75),
          ProcessTaskItem(taskNo: 'TASK-005', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾三根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-Z（150-150）', shape: 'Z', groupType: '三', spacing: 150, connector: '圆钢', quantity: 55, processQty: 55),
        ],
      ),
      ProcessMergeData(
        id: 'P4',
        productType: '预埋', material: '碳钢', model: '52/34', length: 2500, shape: 'R',
        mergeKey: '预埋&碳钢&52/34&2500&R',
        totalQuantity: 50, totalMeters: 50,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-006', orderNo: 'ST-CD-2025-001', erpName: '弧形燕尾双根成组预埋槽道',
              erpModel: 'FPH 52/34-2500-R6430（400）', shape: 'R', groupType: '双', spacing: 400, connector: '圆钢', quantity: 50, processQty: 50),
        ],
      ),
      ProcessMergeData(
        id: 'P5',
        productType: '预埋', material: '不锈钢', model: '52/34', length: 2500, shape: 'R',
        mergeKey: '预埋&不锈钢&52/34&2500&R',
        totalQuantity: 40, totalMeters: 40,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-007', orderNo: 'ST-CD-2025-001', erpName: '不锈钢弧形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-R6100 A4', shape: 'R', groupType: '单', spacing: 0, connector: '', quantity: 40, processQty: 40),
        ],
      ),
      ProcessMergeData(
        id: 'P6',
        productType: '预埋', material: '不锈钢', model: '52/34', length: 2500, shape: 'Z',
        mergeKey: '预埋&不锈钢&52/34&2500&Z',
        totalQuantity: 50, totalMeters: 50,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-008', orderNo: 'ST-CD-2025-001', erpName: '不锈钢直形燕尾预埋槽道',
              erpModel: 'FPH 52/34-2500-Z A4', shape: 'Z', groupType: '单', spacing: 0, connector: '', quantity: 50, processQty: 50),
        ],
      ),
      ProcessMergeData(
        id: 'P7',
        productType: '外置', material: '碳钢', model: '52/34', length: 2500, shape: 'Z',
        mergeKey: '外置&碳钢&52/34&2500&Z',
        totalQuantity: 60, totalMeters: 60,
        tasks: [
          ProcessTaskItem(taskNo: 'TASK-009', orderNo: 'ST-CD-2025-001', erpName: '直形燕尾三根成组外置槽道',
              erpModel: 'FPH 52/34-2500-Z（150-150）', shape: 'Z', groupType: '三', spacing: 150, connector: '扁钢', quantity: 60, processQty: 60),
        ],
      ),
    ];
  }

  /// 获取当前工序过滤后的数据
  List<ProcessMergeData> _getFilteredData(String processCode) {
    final data = _processData[processCode] ?? [];
    return data.where((item) {
      if (_selectedMaterial != '全部' && item.material != _selectedMaterial) return false;
      if (_selectedType != '全部' && item.productType != _selectedType) return false;
      return true;
    }).toList();
  }

  /// 计算汇总
  Map<String, double> _getSummary(String processCode) {
    final filtered = _getFilteredData(processCode);
    double totalQty = 0;
    double totalMeters = 0;
    int taskCount = 0;
    for (final item in filtered) {
      totalQty += item.totalQuantity;
      totalMeters += item.totalMeters;
      taskCount += item.tasks.length;
    }
    return {
      'groupCount': filtered.length.toDouble(),
      'totalQty': totalQty,
      'totalMeters': totalMeters,
      'taskCount': taskCount.toDouble(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工序Tab栏
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: ProcessType.all.map((p) => Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.icon, size: 18),
                  const SizedBox(width: 4),
                  Text(p.name),
                ],
              ),
            )).toList(),
          ),
        ),
        // 筛选栏
        _buildFilterBar(),
        // 内容区
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
            controller: _tabController,
            children: ProcessType.all.map((p) => _buildProcessContent(p)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildDropdown('材质', _selectedMaterial, _materialOptions,
                  (v) => setState(() => _selectedMaterial = v!))),
          const SizedBox(width: 12),
          Expanded(child: _buildDropdown('类型', _selectedType, _typeOptions,
                  (v) => setState(() => _selectedType = v!))),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _loadDemoData,
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildProcessContent(ProcessType process) {
    final filtered = _getFilteredData(process.code);
    final summary = _getSummary(process.code);

    return Column(
      children: [
        // 汇总栏
        _buildSummaryBar(process, summary),
        // 列表
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyView(process)
              : RefreshIndicator(
            onRefresh: () async => _loadDemoData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildMergeCard(filtered[index], process),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBar(ProcessType process, Map<String, double> summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: process.color.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('合并组数', '${summary['groupCount']!.toInt()}', '组', process.color),
          _buildSummaryItem('总数量', '${summary['totalQty']!.toInt()}', process.unit, process.color),
          _buildSummaryItem('任务数', '${summary['taskCount']!.toInt()}', '个', process.color),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 2),
            Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyView(ProcessType process) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(process.icon, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('暂无${process.name}数据', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('合并规则: ${process.mergeRule}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildMergeCard(ProcessMergeData data, ProcessType process) {
    final bool isGroupWelding = process.code == 'group_welding';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.material == '不锈钢' ? Colors.blue.shade50 : process.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                data.model,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: data.material == '不锈钢' ? Colors.blue.shade700 : process.color,
                ),
              ),
            ),
          ),
          title: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildTag(data.productType, Colors.purple),
              _buildTag(data.material, data.material == '不锈钢' ? Colors.blue : Colors.orange),
              _buildTag('${data.length.toInt()}mm', Colors.grey),
              if (data.shape.isNotEmpty)
                _buildTag(data.shape == 'R' ? '弧形' : '直形', data.shape == 'R' ? Colors.cyan : Colors.teal),
              if (isGroupWelding && data.groupType.isNotEmpty)
                _buildTag('${data.groupType}根', Colors.indigo),
              if (isGroupWelding && data.spacing > 0)
                _buildTag('间距${data.spacing.toInt()}', Colors.deepOrange),
              if (isGroupWelding && data.connector.isNotEmpty)
                _buildTag(data.connector, Colors.brown),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.inventory_2, size: 13, color: process.color),
                const SizedBox(width: 3),
                Text('${data.totalQuantity.toInt()} ${process.unit}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: process.color)),
                const SizedBox(width: 12),
                Icon(Icons.list_alt, size: 13, color: Colors.grey),
                const SizedBox(width: 3),
                Text('${data.tasks.length}个任务', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
    return Container(
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
                child: Text(task.taskNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
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
          Text(task.erpName, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(task.erpModel, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

/// 保留旧类名兼容，重定向到新组件
class CuttingMergePage extends StatelessWidget {
  final UserInfo userInfo;
  const CuttingMergePage({super.key, required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工序合并')),
      body: ProcessMergeView(userInfo: userInfo),
    );
  }
}