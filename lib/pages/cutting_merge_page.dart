import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/task_widgets.dart';
import 'order_detail_page.dart';
import 'batch_approval_page.dart';

/// 报工型号的可选组成字段
enum SpecField {
  shape,      // 直/弧（字母 Z/R）
  arcDegree,  // 弧度（完整数值，如 R6340，也可能是 Z）
  groupType,  // 单/双/三根
  spacing,    // 间距（配合groupType显示为(150)/(150-150)括号）
  connector,  // 连接物体
}

/// 工序定义
/// mergeExtra：参与合并分组key的额外字段（类型&材质&型号&长度这4项所有工序都固定参与，不需要在此列出）
/// displayExtra：参与"报工型号"展示字符串的额外字段
/// 8种工序的规则（对应需求表格）：
///   断料/弯弧          直/弧
///   单焊              直/弧 + 单/双/三
///   成组焊接/打磨/清渣  直/弧 + 单/双/三 + 间距 + 连接物体
///   调型/包装          弧度(R6340完整值) + 单/双/三 + 间距 + 连接物体
/// 注意：直/弧只区分 Z/R 两类（R6430 与 R6500 可合并）；弧度按完整数值区分（R6430 与 R6500 不合并）
class ProcessType {
  final String code;
  final String name;
  final String unit;
  final List<SpecField> mergeExtra;
  final List<SpecField> displayExtra;
  final IconData icon;
  final Color color;

  const ProcessType({
    required this.code,
    required this.name,
    required this.unit,
    required this.mergeExtra,
    required this.displayExtra,
    required this.icon,
    required this.color,
  });

  bool mergeHas(SpecField f) => mergeExtra.contains(f);
  bool displayHas(SpecField f) => displayExtra.contains(f);

  /// 获取显示单位（仅断料工序显示"根"）
  String getDisplayUnit(bool isCutting) {
    if (isCutting) return '根';
    return unit;
  }

  static const List<SpecField> _shapeGroupSpacingConnector = [
    SpecField.shape,
    SpecField.groupType,
    SpecField.spacing,
    SpecField.connector,
  ];

  static const List<SpecField> _arcGroupSpacingConnector = [
    SpecField.arcDegree,
    SpecField.groupType,
    SpecField.spacing,
    SpecField.connector,
  ];

  static const List<ProcessType> all = [
    ProcessType(
      code: 'cutting',
      name: '断料',
      unit: '米',
      mergeExtra: [SpecField.shape],
      displayExtra: [SpecField.shape],
      icon: Icons.content_cut,
      color: Colors.orange,
    ),
    ProcessType(
      code: 'bending',
      name: '弯弧',
      unit: '米',
      mergeExtra: [SpecField.shape],
      displayExtra: [SpecField.shape],
      icon: Icons.rotate_right,
      color: Colors.blue,
    ),
    ProcessType(
      code: 'single_welding',
      name: '单焊',
      unit: '米',
      mergeExtra: [SpecField.shape, SpecField.groupType],
      displayExtra: [SpecField.shape, SpecField.groupType],
      icon: Icons.flash_on,
      color: Colors.red,
    ),
    ProcessType(
      code: 'group_welding',
      name: '组焊',
      unit: '米',
      mergeExtra: _shapeGroupSpacingConnector,
      displayExtra: _shapeGroupSpacingConnector,
      icon: Icons.group_work,
      color: Colors.purple,
    ),
    ProcessType(
      code: 'grinding',
      name: '打磨',
      unit: '米',
      mergeExtra: _shapeGroupSpacingConnector,
      displayExtra: _shapeGroupSpacingConnector,
      icon: Icons.auto_fix_high,
      color: Colors.teal,
    ),
    ProcessType(
      code: 'reshaping',
      name: '调型',
      unit: '米',
      mergeExtra: _arcGroupSpacingConnector,
      displayExtra: _arcGroupSpacingConnector,
      icon: Icons.architecture,
      color: Colors.indigo,
    ),
    ProcessType(
      code: 'deslagging',
      name: '清渣',
      unit: '米',
      mergeExtra: _shapeGroupSpacingConnector,
      displayExtra: _shapeGroupSpacingConnector,
      icon: Icons.cleaning_services,
      color: Colors.brown,
    ),
    ProcessType(
      code: 'packing',
      name: '包装',
      unit: '米',
      mergeExtra: _arcGroupSpacingConnector,
      displayExtra: _arcGroupSpacingConnector,
      icon: Icons.inventory_2,
      color: Colors.cyan,
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
    if (code.contains('单焊')) return all.firstWhere((e) => e.code == 'single_welding');
    if (code.contains('打磨')) return all.firstWhere((e) => e.code == 'grinding');
    if (code.contains('调型')) return all.firstWhere((e) => e.code == 'reshaping');
    if (code.contains('清渣')) return all.firstWhere((e) => e.code == 'deslagging');
    if (code.contains('包装')) return all.firstWhere((e) => e.code == 'packing');
    return null;
  }

  /// 兼容旧调用，未知工序默认返回断料
  static ProcessType fromCode(String code) {
    return tryFromCode(code) ?? all.first;
  }

  /// 是否为已知的8种合并工序
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
  final String arcDegree;
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
    this.arcDegree = '',
    this.groupType = '',
    this.spacing = 0,
    this.connector = '',
    required this.mergeKey,
    required this.tasks,
    required this.totalQuantity,
    required this.totalMeters,
  });

  double get lengthMeters => length / 1000.0;

  /// 直/弧的字母表示：直→Z，弧→R（报工型号里按例子用字母，不用中文）
  String get shapeLetter => shape == '弧' ? 'R' : 'Z';

  /// 单/双/三根的简写：双根→双，三根→三（报工型号里按例子只取首字）
  String get groupTypeShort =>
      groupType.isEmpty ? '' : groupType.replaceAll('根', '');

  /// 是否是断料工序（优先使用processName匹配）
  bool get isCutting =>
      processName.contains('断料') ||
          processCode.contains('断料') ||
          processCode == 'cutting';

  /// 是否为外置槽道（外置/预埋已参与合并key，同组内必定一致）
  bool get isWaizhi => tasks.isNotEmpty && tasks.first.isWaizhi;

  /// 外置/预埋文字标签
  String get placementLabel => isWaizhi ? '外置' : '预埋';

  /// 组内是否已有任务过了质检环节（用于决定工废/料废是否固定展示）
  bool get isQcDone => tasks.any((t) => t.status.isQcDone);

  /// 本组的单位换算器（组内外置/预埋、规格一致，可整组共用）
  QtyConverter get converter => QtyConverter(
    isCutting: isCutting,
    isWaizhi: isWaizhi,
    rootMultiplier: rootMultiplier,
    lengthMeters: lengthMeters,
  );

  /// 根系数：三根→3，双根→2，其他→1
  int get rootMultiplier {
    if (groupType == '三根') return 3;
    if (groupType == '双根') return 2;
    return 1;
  }

  /// 计划数量合计（显示单位）
  num get totalPieces => _sumDisplay((t) => t.processQty);

  /// 完成数量合计（显示单位）
  num get completedPieces => _sumDisplay((t) => t.completedQty);

  /// 工废数量合计（显示单位）
  num get workWastePieces => _sumDisplay((t) => t.workWasteQty);

  /// 料废数量合计（显示单位）
  num get materialWastePieces => _sumDisplay((t) => t.materialWasteQty);

  /// 按每个任务分别做单位换算后求和
  ///
  /// 注意：换算过程中不能逐个取整。一个总量被后端拆分到多个订单后，
  /// 每单的份额常常是小数（如 1根=3米 拆成两单各 1.5米 → 各 0.5根），
  /// 逐个四舍五入会把 0.5+0.5 放大成 1+1=2。必须先累加原始值，最后统一格式化一次。
  num _sumDisplay(double Function(ProcessTaskItem) pick) {
    double total = 0;
    for (var t in tasks) {
      total += t.apiToDisplay(pick(t), isCutting);
    }
    return formatQtyNum(total);
  }

  /// 员工（组内任务同属一个worker分组，取第一个即可）
  String get workerName => tasks.isNotEmpty ? tasks.first.workerName : '';

  /// 计划工时合计
  double get totalPlanHours {
    double total = 0;
    for (var t in tasks) {
      total += t.planHours;
    }
    return double.parse(total.toStringAsFixed(1));
  }

  /// 计工方式（同组任务通常一致，取第一个）
  String get workType => tasks.isNotEmpty ? tasks.first.workType : '';

  /// 工时类型（同组任务通常一致，取第一个）
  String get timeType => tasks.isNotEmpty ? tasks.first.timeType : '';

  /// 计划完成时间（取组内最晚的一个）
  DateTime? get planFinishTime {
    DateTime? latest;
    for (var t in tasks) {
      if (t.planFinishTime != null &&
          (latest == null || t.planFinishTime!.isAfter(latest))) {
        latest = t.planFinishTime;
      }
    }
    return latest;
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
  final ApiTaskStatus status;
  final DateTime? claimTime;
  final String workerName;
  final double planHours;
  final String workType;
  final String timeType;
  final DateTime? planFinishTime;
  final double completedQty;      // API原始值
  final double workWasteQty;      // API原始值
  final double materialWasteQty;  // API原始值

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
    required this.status,
    this.claimTime,
    this.workerName = '',
    this.planHours = 0,
    this.workType = '',
    this.timeType = '',
    this.planFinishTime,
    this.completedQty = 0,
    this.workWasteQty = 0,
    this.materialWasteQty = 0,
  });

  double get lengthMeters => length / 1000.0;

  /// 是否为外置槽道
  bool get isWaizhi => erpName.contains('外置');

  /// 根系数：三根→3，双根→2，其他→1
  int get rootMultiplier {
    if (groupType == '三根') return 3;
    if (groupType == '双根') return 2;
    return 1;
  }

  double get processQtyPieces {
    if (lengthMeters > 0) {
      return processQty / lengthMeters;
    }
    return processQty;
  }

  /// 本任务的单位换算器（用任务自己的外置/预埋口径）
  QtyConverter converter(bool isCutting) => QtyConverter(
    isCutting: isCutting,
    isWaizhi: isWaizhi,
    rootMultiplier: rootMultiplier,
    lengthMeters: lengthMeters,
  );

  /// API单位 → 显示单位（未取整，供累加用）
  double apiToDisplay(double apiQty, bool isCutting) =>
      converter(isCutting).toDisplay(apiQty);

  /// 单个任务的数量显示值（已格式化）
  num displayQtyOf(double apiQty, bool isCutting) =>
      converter(isCutting).toDisplayNum(apiQty);

  /// 获取派工数量的显示值
  num getDisplayQty(bool isCutting) => displayQtyOf(processQty, isCutting);

  /// 自动计算实际工时（提报时间 - 领取时间）
  /// 如果12点前领取、13点后报工，扣除1小时午休
  double calcWorkHours() {
    if (claimTime == null) return 0;
    final now = DateTime.now();
    double hours = now.difference(claimTime!).inMinutes / 60.0;
    // 午休扣除
    if (claimTime!.hour < 12 && now.hour >= 13) {
      hours -= 1.0;
    }
    if (hours < 0) hours = 0;
    return double.parse(hours.toStringAsFixed(1));
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
      connector: task.connector,
      quantity: (task.planQty).toDouble(),
      processQty: (task.assignedQty).toDouble(),
      length: parsedInfo['length'] ?? 0.0,
      status: task.status,
      claimTime: task.claimTime,
      workerName: task.workerName,
      planHours: task.planHours,
      workType: task.workType,
      timeType: task.timeType,
      completedQty: task.completedQty,
      workWasteQty: task.workWasteQty,
      materialWasteQty: task.materialWasteQty,
      planFinishTime: task.planFinishTime,
    );
  }
}

/// 工序合并视图（任务清单）——班长可见全组、自己的置顶
class ProcessMergeView extends StatefulWidget {
  final UserInfo userInfo;
  final FilterCriteria filter;

  const ProcessMergeView({
    super.key,
    required this.userInfo,
    required this.filter,
  });

  @override
  State<ProcessMergeView> createState() => ProcessMergeViewState();
}

class ProcessMergeViewState extends State<ProcessMergeView> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isFirstLoad = true;  // 仅首次加载显示loading，后续无痕刷新

  // 按worker分组的合并数据：key=workerName, value=该worker的合并结果
  Map<String, List<ProcessMergeData>> _workerGroupedData = {};
  // 排序后的worker名称（班长自己在最前）
  List<String> _sortedWorkerNames = [];

  bool get _isLeader => widget.userInfo.userRole == UserRole.leader;
  bool get _isInspector => widget.userInfo.userRole == UserRole.inspector;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(ProcessMergeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _loadData();
    }
  }

  void refreshData() {
    _loadData();
  }

  /// 从API加载数据，按worker分组再按工序合并
  Future<void> _loadData() async {
    // 仅首次加载显示loading动画，后续刷新无痕更新数据
    if (_isFirstLoad) {
      setState(() => _isLoading = true);
    }

    try {
      // 班长：不限workerId，看全组；员工：只看自己
      // 日期筛选由api_service默认处理（三天内）
      final FilterCriteria filter;
      if (_isLeader) {
        filter = widget.filter;
      } else {
        filter = widget.filter.copyWith(workerId: widget.userInfo.id);
      }

      final response = await _apiService.getTaskList(
        page: 1,
        pageSize: 200,
        productType: 'channel',
        filter: filter,
      );

      final List<ApiTaskData> tasks = response.data;

      // ========== MOCK 数据开关（测试完成后设为 false） ==========
      const bool enableMock = false;
      if (enableMock) {
        tasks.addAll(_generateMockGroupWeldingTasks());
      }
      // ========== MOCK END ==========

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
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        setState(() {
          _workerGroupedData = {};
          _sortedWorkerNames = [];
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  /// ========== MOCK：生成组焊测试数据（测试完成后将enableMock改为false）==========
  List<ApiTaskData> _generateMockGroupWeldingTasks() {
    final mockJsonList = [
      // #1 A组：碳钢 52/34 2500mm 直形 双根 间距150
      {
        'id': 90001, 'task_no': 'MOCK_GW_001', 'order_no': 'ORD_MOCK_001',
        'product_name': '直形燕尾双根成组预埋槽道', 'spec_model': 'FPH 52/34-2500-Z (150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 500, 'assigned_qty': 500, 'status': 2, 'unit': '米',
        'claim_time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'connector': '钢管',
      },
      // #2 独立分组：规格与 #1 相同，但为外置（外置/预埋参与合并key，不与预埋合并）
      {
        'id': 90002, 'task_no': 'MOCK_GW_002', 'order_no': 'ORD_MOCK_002',
        'product_name': '直形燕尾双根成组外置槽道', 'spec_model': 'FPH 52/34-2500-Z (150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 300, 'assigned_qty': 300, 'status': 2, 'unit': '米',
        'claim_time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'connector': '钢管',
      },
      // #3 B组：三根（groupType不同）
      {
        'id': 90003, 'task_no': 'MOCK_GW_003', 'order_no': 'ORD_MOCK_003',
        'product_name': '直形燕尾三根成组预埋槽道', 'spec_model': 'FPH 52/34-2500-Z (150-150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 400, 'assigned_qty': 400, 'status': 2, 'unit': '米',
      },
      // #4 C组：间距200（spacing不同）
      {
        'id': 90004, 'task_no': 'MOCK_GW_004', 'order_no': 'ORD_MOCK_004',
        'product_name': '直形燕尾双根成组预埋槽道', 'spec_model': 'FPH 52/34-2500-Z (200)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 250, 'assigned_qty': 250, 'status': 2, 'unit': '米',
      },
      // #5 D组：弧形R6100（shape不同）
      {
        'id': 90005, 'task_no': 'MOCK_GW_005', 'order_no': 'ORD_MOCK_005',
        'product_name': '弧形燕尾双根成组预埋槽道', 'spec_model': 'FPH 52/34-2500-R6100 (150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 350, 'assigned_qty': 350, 'status': 2, 'unit': '米',
      },
      // #6 E组：长度3000（length不同）
      {
        'id': 90006, 'task_no': 'MOCK_GW_006', 'order_no': 'ORD_MOCK_006',
        'product_name': '直形燕尾双根成组预埋槽道', 'spec_model': 'FPH 52/34-3000-Z (150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 600, 'assigned_qty': 600, 'status': 2, 'unit': '米',
      },
      // #7 F组：不锈钢A4（material不同）
      {
        'id': 90007, 'task_no': 'MOCK_GW_007', 'order_no': 'ORD_MOCK_007',
        'product_name': '直形燕尾双根成组预埋槽道', 'spec_model': 'FPH 52/34-2500-Z (150) A4',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 200, 'assigned_qty': 200, 'status': 2, 'unit': '米',
      },
      // #8 D组：和#5合并（同弧形R6100/双根/间距150）
      {
        'id': 90008, 'task_no': 'MOCK_GW_008', 'order_no': 'ORD_MOCK_008',
        'product_name': '弧形燕尾双根成组预埋槽道', 'spec_model': 'FPH 52/34-2500-R6100 (150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 450, 'assigned_qty': 450, 'status': 2, 'unit': '米',
      },
    ];
    return mockJsonList.map((json) => ApiTaskData.fromListJson(json)).toList();
  }

  /// 将一组任务按工序属性合并
  List<ProcessMergeData> _buildMergeGroups(List<ApiTaskData> tasks) {
    final Map<String, ProcessMergeData> groups = {};

    for (var task in tasks) {
      final String processName = task.processName.isNotEmpty ? task.processName : task.processCode;

      // 匹配为已知工序，跳过未知工序
      final ProcessType? processType = ProcessType.tryFromCode(processName);
      if (processType == null) continue;

      // 使用标准化的英文code作为key的工序部分，避免中文变体导致无法合并
      final String normalizedProcess = processType.code;

      final parsedInfo = _parseTaskInfo(task);
      final String specType = parsedInfo['specType'] ?? '';
      final String material = parsedInfo['material'];
      final double length = parsedInfo['length'];
      final String shape = parsedInfo['shape'];
      final String arcDegree = parsedInfo['arcDegree'] ?? '';
      final String groupType = parsedInfo['groupType'] ?? '';
      final double spacing = parsedInfo['spacing'] ?? 0.0;
      // 连接物体来自任务/工序计划的connector字段
      final String connector = task.connector;
      // 外置/预埋按产品名称区分（如"弧形燕尾双根外置槽道" vs "弧形燕尾预埋槽道"）
      // 两者的数量口径不同（外置按"组"、预埋按"米"），必须参与合并key，否则
      // 同组内混着两种口径，提报时无法用同一个换算公式
      final bool isWaizhi = task.productName.contains('外置');

      // 按工序的mergeExtra动态构建合并key
      final String key = _buildMergeKey(normalizedProcess, processType, isWaizhi, {
        'specType': specType,
        'material': material,
        'length': length,
        'shape': shape,
        'arcDegree': arcDegree,
        'groupType': groupType,
        'spacing': spacing,
        'connector': connector,
      });

      debugPrint('[合并] 任务${task.taskNo}: processName=$processName → $normalizedProcess, '
          'specType=$specType, length=$length, shape=$shape, arcDegree=$arcDegree, groupType=$groupType, '
          'connector=$connector, 外置=$isWaizhi, spec=${task.specModel} → key=$key');

      final taskItem = ProcessTaskItem.fromApiTask(task, parsedInfo);

      if (groups.containsKey(key)) {
        groups[key]!.tasks.add(taskItem);
      } else {
        groups[key] = ProcessMergeData(
          id: key,
          processCode: normalizedProcess,
          processName: processType.name,
          productType: specType,
          material: material,
          model: specType,
          length: length,
          shape: shape,
          arcDegree: arcDegree,
          groupType: groupType,
          spacing: spacing,
          connector: connector,
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
        totalQty = (totalQty * 10 + t.processQty * 10) / 10;
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
        arcDegree: group.arcDegree,
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

  /// 根据工序的mergeExtra动态构建合并key
  /// 类型&型号 = specType（如"FPH 52/34"，整体不可拆分）
  /// 所有工序共有：类型&材质&长度&外置预埋；额外字段见 ProcessType.mergeExtra（断料含直/弧，调型/包装用弧度替代直/弧）
  String _buildMergeKey(String processCode, ProcessType processType, bool isWaizhi,
      Map<String, dynamic> info) {
    final parts = <String>[processCode];

    // 所有工序共有：类型(含型号)&材质&长度&外置/预埋
    parts.add(info['specType'] as String);
    parts.add(info['material'] as String);
    parts.add((info['length'] as double).toString());
    parts.add(isWaizhi ? '外置' : '预埋');

    for (final field in processType.mergeExtra) {
      switch (field) {
        case SpecField.shape:
          parts.add(info['shape'] as String);
          break;
        case SpecField.arcDegree:
          parts.add(info['arcDegree'] as String);
          break;
        case SpecField.groupType:
          parts.add(info['groupType'] as String);
          break;
        case SpecField.spacing:
          parts.add((info['spacing'] as double).toString());
          break;
        case SpecField.connector:
          parts.add(info['connector'] as String);
          break;
      }
    }

    return parts.join('|');
  }

  /// 解析任务规格字符串
  /// 规则：
  ///   FPH 52/34  - 第一部分：类型，52/34为型号
  ///   2500       - 第二部分：长度(mm)
  ///   Z 或 R6500 - 第三部分：Z=直形，R+数字=弧形（数字为弧度半径）
  ///   (150)      - 括号中：成组间距，一个数字=双根，两个数字(150-150)=三根
  ///   A4         - 末尾有A4=不锈钢，无则碳钢
  /// 示例:
  ///   "FPH 52/34-2500-Z （150-150）"                          → 52/34, 2500mm, 直形, 三根间距150
  ///   "FPH 53/34-1900-R6670"                                  → 53/34, 1900mm, 弧形R6670
  ///   "FPH 52/34-2500-Z-A4"                                   → 52/34, 2500mm, 直形, 不锈钢
  ///   "FPH 52/34-1500（320折角153度)+（670.8折角117度）+509.2-Z(400）" → 52/34, 1500mm, 直形, 双根间距400
  Map<String, dynamic> _parseTaskInfo(ApiTaskData task) {
    String spec = task.specModel;

    String material = '碳钢';
    double length = 0;
    String shape = '直';
    String arcDegree = '';  // 弧度：Z 或 R+数字（如 R6340），供调型/包装工序使用
    String specType = '';   // 类型&型号整体，如 "FPH 52/34"
    String groupType = '';
    double spacing = 0;

    // 1. 统一中文括号为英文括号
    String normalizedSpec = spec
        .replaceAll('（', '(')
        .replaceAll('）', ')');

    if (normalizedSpec.contains('折角')) {
      // 多段折角格式: "FPH 52/34-1500(320折角153度)+(670.8折角117度)+509.2-Z(400)"
      // 先移除含"折角"的括号段，留下形状和间距部分
      final String withoutBend = normalizedSpec
          .replaceAll(RegExp(r'\([^)]*折角[^)]*\)'), '');
      // withoutBend 示例: "FPH 52/34-1500+509.2-Z(400)"

      // A4 检测
      if (withoutBend.toUpperCase().contains('A4')) material = '不锈钢';

      // specType：第一个 '-' 之前
      final int firstDash = withoutBend.indexOf('-');
      if (firstDash > 0) {
        specType = withoutBend.substring(0, firstDash).trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAllMapped(RegExp(r'([A-Za-z])(\d)'), (m) => '${m[1]} ${m[2]}');
      }

      // 总长度：第一个 '-' 后紧跟的数字（忽略后续 +段 拼接）
      final lenMatch = RegExp(r'-(\d+(?:\.\d+)?)').firstMatch(withoutBend);
      if (lenMatch != null) length = double.tryParse(lenMatch.group(1)!) ?? 0;

      // 形状：去掉间距括号后按 '-' 分割取第三部分
      final String specForShape = withoutBend
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .trim();
      // specForShape 示例: "FPH 52/34-1500+509.2-Z"
      final List<String> shapeParts = specForShape.split('-');
      if (shapeParts.length > 2) {
        final String shapePart = shapeParts[2].trim().toUpperCase()
            .replaceAll(RegExp(r'\s*A4$'), '');
        shape = shapePart.startsWith('R') ? '弧' : '直';
        arcDegree = shapePart;
      }

      // 间距：withoutBend 中最后一个括号内容
      final spacingMatches = RegExp(r'\(([^)]+)\)').allMatches(withoutBend);
      if (spacingMatches.isNotEmpty) {
        final String bracketContent = spacingMatches.last.group(1)!;
        final List<String> spacingParts = bracketContent.split('-');
        if (spacingParts.length >= 2) {
          groupType = '三根';
          spacing = double.tryParse(spacingParts[0].trim()) ?? 0;
        } else if (spacingParts[0].trim().isNotEmpty) {
          groupType = '双根';
          spacing = double.tryParse(spacingParts[0].trim()) ?? 0;
        }
      }
    } else {
      // 标准格式: "FPH 52/34-2500-Z (150)"

      // 2. 先提取括号中的间距信息（成组槽道）
      final bracketMatch = RegExp(r'\(([^)]+)\)').firstMatch(normalizedSpec);
      if (bracketMatch != null) {
        String bracketContent = bracketMatch.group(1) ?? '';
        List<String> spacings = bracketContent.split('-');
        if (spacings.length >= 2) {
          groupType = '三根';
          spacing = double.tryParse(spacings[0].trim()) ?? 0;
        } else if (spacings.length == 1 && spacings[0].trim().isNotEmpty) {
          groupType = '双根';
          spacing = double.tryParse(spacings[0].trim()) ?? 0;
        }
      }

      // 3. 去掉括号部分，再按 - 分割（避免括号内的-干扰分割）
      String specWithoutBrackets = normalizedSpec
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .trim();

      // 4. 检测A4（不锈钢）
      if (specWithoutBrackets.toUpperCase().contains('A4')) {
        material = '不锈钢';
      }

      List<String> parts = specWithoutBrackets.split('-');

      // 5. 第一部分：类型&型号整体（如 "FPH 52/34"，规范化空格避免"FPH52/34"与"FPH 52/34"不同）
      if (parts.isNotEmpty) {
        specType = parts[0].trim().replaceAll(RegExp(r'\s+'), ' ');
        specType = specType.replaceAllMapped(RegExp(r'([A-Za-z])(\d)'), (m) => '${m[1]} ${m[2]}');
      }

      // 6. 第二部分：长度(mm)
      if (parts.length > 1) {
        String lenStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
        length = double.tryParse(lenStr) ?? 0;
      }

      // 7. 第三部分：形状 Z=直形，R+数字=弧形，只区分直/弧；弧度(arcDegree)保留完整值（Z 或 R6340）
      if (parts.length > 2) {
        String shapePart = parts[2].trim().toUpperCase();
        shapePart = shapePart.replaceAll(RegExp(r'\s*A4$'), '');
        if (shapePart.startsWith('R')) {
          shape = '弧';
        } else {
          shape = '直';
        }
        arcDegree = shapePart;
      }
    }

    debugPrint('[解析] spec="$spec" → specType=$specType, length=$length, shape=$shape, arcDegree=$arcDegree, '
        'material=$material, group=$groupType, spacing=$spacing');

    return {
      'specType': specType,
      'material': material,
      'length': length,
      'shape': shape,
      'arcDegree': arcDegree,
      'groupType': groupType,
      'spacing': spacing,
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
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        children: items,
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('暂无槽道任务数据', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('刷新')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// worker分组头（类似生产任务的分组头，班长自己高亮）
  Widget _buildWorkerHeader(String workerName, int taskCount, {bool isMe = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isMe ? Colors.orange.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: isMe ? Border.all(color: Colors.orange.shade200) : null,
      ),
      child: Row(
        children: [
          Icon(isMe ? Icons.star : Icons.person, size: 15,
              color: isMe ? Colors.orange : Colors.grey),
          const SizedBox(width: 6),
          Text(
            isMe ? '$workerName（我）' : workerName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
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

  /// 按工序的displayExtra组成格式化型号字符串
  String _buildMergedSpec(ProcessMergeData data, ProcessType process) {
    // 基础：型号-长度
    final parts = <String>[data.model, '${data.length.toInt()}'];

    // 直/弧：按例子用字母 Z/R（8种工序都展示，包括断料）
    if (process.displayHas(SpecField.shape)) {
      parts.add(data.shapeLetter);
    }
    // 弧度（调型/包装用完整数值替代直/弧，如 R6340；直形时为 Z）
    if (process.displayHas(SpecField.arcDegree)) {
      parts.add(data.arcDegree.isNotEmpty ? data.arcDegree : data.shapeLetter);
    }
    // 单/双/三根：若不带间距（单焊），以"双/三"形式追加
    final bool showSpacing = process.displayHas(SpecField.spacing);
    if (process.displayHas(SpecField.groupType) && !showSpacing && data.groupTypeShort.isNotEmpty) {
      parts.add(data.groupTypeShort);
    }

    String spec = parts.join('-');

    // 间距：追加括号，双根(150)，三根(150-150)
    if (showSpacing && data.groupType.isNotEmpty) {
      if (data.groupType == '三根') {
        spec += ' (${data.spacing.toInt()}-${data.spacing.toInt()})';
      } else {
        spec += ' (${data.spacing.toInt()})';
      }
    }

    // 连接物体
    if (process.displayHas(SpecField.connector) && data.connector.isNotEmpty) {
      spec += ' ${data.connector}';
    }

    // 不锈钢追加A4
    if (data.material == '不锈钢') {
      spec += ' A4';
    }

    return spec;
  }

  /// 该分组内当前用户是否可以以"工人"身份操作（领取/报工）
  /// 员工：始终可以；班长：仅当分组属于自己时；质检：不可以
  bool _canActAsWorker(ProcessMergeData data) {
    if (_isInspector) return false;
    if (_isLeader) return data.workerName == widget.userInfo.realName;
    return true;
  }

  Widget _buildMergeCard(ProcessMergeData data, ProcessType process) {
    final bool canActAsWorker = _canActAsWorker(data);
    final List<ProcessTaskItem> claimableTasks = canActAsWorker
        ? data.tasks.where((t) => t.status == ApiTaskStatus.assigned).toList()
        : const [];
    final List<ProcessTaskItem> reportableTasks = canActAsWorker
        ? data.tasks.where((t) => _isReportable(t.status)).toList()
        : const [];
    final List<ProcessTaskItem> qcTasks = _isInspector
        ? data.tasks.where((t) => t.status == ApiTaskStatus.pendingQc).toList()
        : const [];
    // 班长待审批批次（质检已通过/再次提交，等待班长拆分分配到各订单）
    final List<ProcessTaskItem> approvalTasks = _isLeader
        ? data.tasks
        .where((t) =>
    t.status == ApiTaskStatus.pendingApproval || t.status == ApiTaskStatus.resubmit)
        .toList()
        : const [];

    final List<Widget> actions = _buildActionButtons(
      data, process, claimableTasks, reportableTasks, qcTasks, approvalTasks,
    );

    // 外框颜色与状态绑定（与锚栓/C型钢的TaskCard保持一致）
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: _groupStatusColor(data), width: 2),
    );

    // 班长：保留可展开看订单明细、点进详情；工人/质检：纯卡片内联操作
    if (_isLeader) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1.5,
        shape: cardShape,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            title: _buildCardHeader(data, process),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildInfoGrid(data, process),
            ),
            children: [
              const Divider(height: 1),
              const SizedBox(height: 6),
              ...data.tasks.map((task) => _buildTaskItem(task, process, data.isCutting)),
              ...actions,
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shape: cardShape,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(data, process),
            const SizedBox(height: 6),
            _buildInfoGrid(data, process),
            ...actions,
          ],
        ),
      ),
    );
  }

  /// 卡片头部：放大的工序图标框 + 报工型号/状态 + 材质/预埋外置标签
  Widget _buildCardHeader(ProcessMergeData data, ProcessType process) {
    return buildTaskCardHeader(
      spec: _buildMergedSpec(data, process),
      processName: process.name,
      processIcon: process.icon,
      processColor: process.color,
      statusText: _groupStatusText(data),
      statusColor: _groupStatusColor(data),
      tags: [
        _buildTag(data.material,
            data.material == '不锈钢' ? Colors.indigo : Colors.brown),
        _buildTag(data.placementLabel,
            data.isWaizhi ? Colors.deepOrange : Colors.green.shade700),
      ],
    );
  }

  /// 分组状态：全组同状态时用该状态，否则为"多状态"
  ApiTaskStatus? _groupSingleStatus(ProcessMergeData data) {
    final statuses = data.tasks.map((t) => t.status).toSet();
    return statuses.length == 1 ? statuses.first : null;
  }

  String _groupStatusText(ProcessMergeData data) {
    final s = _groupSingleStatus(data);
    if (s != null) return s.text;
    return '多状态(${data.tasks.map((t) => t.status).toSet().length})';
  }

  Color _groupStatusColor(ProcessMergeData data) =>
      _groupSingleStatus(data)?.color ?? Colors.blueGrey;

  /// 卡片信息字段：员工/计划数量/计划工时/计工方式/工时类型/计划完成时间
  /// 完成数量在报工后出现，工废/料废在质检后出现（对应表格里各界面的递增字段要求）
  /// 班长审批页复用同一份字段定义，保证两处展示一致
  List<InfoEntry> buildInfoEntries(ProcessMergeData data, ProcessType process) {
    final String unit = process.getDisplayUnit(data.isCutting);
    final entries = <InfoEntry>[];

    // 员工/计划数量/计划工时/计划完成时间/计工方式/工时类型 是表格要求的必显字段，
    // 即使接口没返回也保留占位，避免"字段整行消失"看起来像漏做
    entries.add(InfoEntry('员工', data.workerName.isNotEmpty ? data.workerName : '-'));
    // 外置/预埋已参与合并key，同组内口径一致，直接显示合计
    entries.add(InfoEntry('计划数量', '${data.totalPieces} $unit'));
    entries.add(
        InfoEntry('计划工时', data.totalPlanHours > 0 ? '${data.totalPlanHours}h' : '-'));
    entries.add(InfoEntry('计工方式', data.workType.isNotEmpty ? data.workType : '-'));
    entries.add(InfoEntry('工时类型', data.timeType.isNotEmpty ? data.timeType : '-'));
    // 完成数量/工废/料废随流程递进出现。
    // 质检通过后三者固定显示（即使为0），一来班长分配时能看到质检结果，
    // 二来保证半栏字段总数为偶数，工废/料废正好成对落在同一行
    final bool showWaste = data.isQcDone;
    if (showWaste || data.completedPieces > 0) {
      entries.add(InfoEntry('完成数量', '${data.completedPieces} $unit'));
    }
    if (showWaste || data.workWastePieces > 0) {
      entries.add(InfoEntry('工废数量', '${data.workWastePieces} $unit'));
    }
    if (showWaste || data.materialWastePieces > 0) {
      entries.add(InfoEntry('料废数量', '${data.materialWastePieces} $unit'));
    }
    // 计划完成时间标签长、值也长，半栏放不下，独占一行且排在所有成对字段之后
    entries.add(InfoEntry(
      '计划完成时间',
      data.planFinishTime != null ? _formatDate(data.planFinishTime!) : '-',
      fullWidth: true,
    ));
    return entries;
  }

  Widget _buildInfoGrid(ProcessMergeData data, ProcessType process) =>
      buildInfoLayout(buildInfoEntries(data, process));

  /// 卡片底部操作按钮（按角色和任务状态显示）
  List<Widget> _buildActionButtons(
      ProcessMergeData data,
      ProcessType process,
      List<ProcessTaskItem> claimableTasks,
      List<ProcessTaskItem> reportableTasks,
      List<ProcessTaskItem> qcTasks,
      List<ProcessTaskItem> approvalTasks,
      ) {
    // 多个按钮并排一行平分宽度，标签带数量并在空间不足时自动缩放
    return buildCardActionRow([
      // 领取任务（内联领取，不跳转详情页）
      if (claimableTasks.isNotEmpty)
        buildCardActionButton(
          onPressed: () => _claimGroup(claimableTasks),
          icon: Icons.check_circle_outline,
          label: '领取(${claimableTasks.length})',
          color: process.color,
          outlined: true,
        ),
      // 合并提报（只填一个总完成数量）
      if (reportableTasks.isNotEmpty)
        buildCardActionButton(
          onPressed: () => _showTotalReportDialog(data, process, reportableTasks),
          icon: Icons.send,
          label: '合并提报(${reportableTasks.length})',
          color: process.color,
        ),
      // 批量质检（填整批总工废/总料废）
      if (qcTasks.isNotEmpty)
        buildCardActionButton(
          onPressed: () => _showQcBatchDialog(data, process, qcTasks),
          icon: Icons.fact_check_outlined,
          label: '批量质检(${qcTasks.length})',
          color: Colors.blue,
        ),
      // 班长批次分配（拆分到各生产订单）
      if (approvalTasks.isNotEmpty)
        buildCardActionButton(
          onPressed: () => _openBatchApproval(data, process, approvalTasks),
          icon: Icons.call_split,
          label: '批次分配(${approvalTasks.length})',
          color: Colors.deepPurple,
        ),
    ]);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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


  /// 班长展开后的订单明细行：具体型号 + 订单数量 + 工人提报数 + 状态，点击进入任务详情
  Widget _buildTaskItem(ProcessTaskItem task, ProcessType process, bool isCutting) {
    final String displayUnit = process.getDisplayUnit(isCutting);
    final num orderQty = task.getDisplayQty(isCutting);
    final num reportedQty = task.displayQtyOf(task.completedQty, isCutting);
    final num wasteQty =
    task.displayQtyOf(task.workWasteQty + task.materialWasteQty, isCutting);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToTaskDetail(task.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：具体型号 + 状态标签
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.erpModel.isNotEmpty ? task.erpModel : task.erpName,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildTag(task.status.text, task.status.color),
                ],
              ),
              const SizedBox(height: 3),
              // 第二行：订单数量 + 工人提报总数 + 废品总数
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  _buildQtyLabel('订单数量', '$orderQty $displayUnit', process.color),
                  if (reportedQty > 0)
                    _buildQtyLabel('工人提报总数', '$reportedQty $displayUnit', Colors.blue),
                  if (wasteQty > 0)
                    _buildQtyLabel('废品总数', '$wasteQty $displayUnit', Colors.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 明细行里的"标签: 数值"小组件
  Widget _buildQtyLabel(String label, String value, Color color) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: '$label: ',
            style: TextStyle(fontSize: 11, height: 1.2, color: Colors.grey[600])),
        TextSpan(
          text: value,
          style: TextStyle(
              fontSize: 12, height: 1.2, fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }

  /// 判断任务状态是否支持提报（已领取、班长发回、质检发回）
  bool _isReportable(ApiTaskStatus status) {
    return status == ApiTaskStatus.claimed ||
        status == ApiTaskStatus.leaderReject ||
        status == ApiTaskStatus.qcReject;
  }

  /// 分组级别的显示单位 → API单位转换（组内外置/预埋、规格一致，整组共用一个换算器）
  double _groupDisplayToApi(ProcessMergeData data, double displayQty) =>
      truncateQty2(data.converter.toApi(displayQty));

  /// 领取任务：对分组内所有可领取任务逐个调用领取接口
  Future<void> _claimGroup(List<ProcessTaskItem> claimableTasks) async {
    int successCount = 0;
    for (final task in claimableTasks) {
      final result = await _apiService.claimTask(task.id);
      if (result.success) successCount++;
    }
    if (!mounted) return;
    if (successCount == claimableTasks.length) {
      AppToast.success(context, '领取成功 ($successCount个)');
    } else if (successCount > 0) {
      AppToast.warning(context, '部分领取成功 ($successCount/${claimableTasks.length})');
    } else {
      AppToast.error(context, '领取失败');
    }
    _loadData();
  }

  /// 合并提报对话框 —— 只需填写一个总完成数量
  void _showTotalReportDialog(
      ProcessMergeData data, ProcessType process, List<ProcessTaskItem> reportableTasks) {
    final String displayUnit = process.getDisplayUnit(data.isCutting);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('合并提报 - ${process.name}', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_buildMergedSpec(data, process),
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            Text('共${reportableTasks.length}个任务合并提报',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '完成数量',
                suffixText: displayUnit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final double qty = double.tryParse(controller.text) ?? 0;
              if (qty < 0) {
                AppToast.error(context, '请输入完成数量');
                return;
              }
              Navigator.pop(ctx);
              _submitTotalReport(data, reportableTasks, qty);
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  /// 提交合并批次报工（工人只填一个总完成数量）
  Future<void> _submitTotalReport(
      ProcessMergeData data, List<ProcessTaskItem> reportableTasks, double displayQty) async {
    final double apiQty = _groupDisplayToApi(data, displayQty);

    final result = await _apiService.channelBatchReport(
      taskIds: reportableTasks.map((t) => t.id).toList(),
      totalCompletedQty: apiQty,
    );
    if (!mounted) return;

    final int code = result['code'] ?? 500;
    final String message = (result['data'] is Map ? result['data']['message'] : null) ??
        result['message'] ??
        '提交失败';

    if (code == 200) {
      AppToast.success(context, message);
    } else {
      AppToast.error(context, message);
    }
    _loadData();
  }

  /// 紧凑输入框（对话框内使用）
  Widget _buildCompactField(String label, TextEditingController ctrl, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: const OutlineInputBorder(),
              hintText: '0',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 批量质检对话框 —— 填写整批总工废/总料废后提交
  /// 槽道流程不需要质检驳回（接口的 pass 参数保留，这里固定传 true）
  void _showQcBatchDialog(
      ProcessMergeData data, ProcessType process, List<ProcessTaskItem> qcTasks) {
    final String displayUnit = process.getDisplayUnit(data.isCutting);
    final workWasteCtrl = TextEditingController();
    final materialWasteCtrl = TextEditingController();
    final opinionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('批量质检 - ${process.name}', style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_buildMergedSpec(data, process),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                Text('共${qcTasks.length}个任务待质检',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildCompactField('工废', workWasteCtrl, displayUnit),
                    const SizedBox(width: 6),
                    _buildCompactField('料废', materialWasteCtrl, displayUnit),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: opinionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '质检意见',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitBatchInspect(data, qcTasks, workWasteCtrl.text,
                  materialWasteCtrl.text, opinionCtrl.text, true);
            },
            child: const Text('提交质检'),
          ),
        ],
      ),
    );
  }

  /// 提交批量质检（总工废/总料废 + 通过/驳回）
  Future<void> _submitBatchInspect(
      ProcessMergeData data,
      List<ProcessTaskItem> qcTasks,
      String workWasteText,
      String materialWasteText,
      String opinion,
      bool pass,
      ) async {
    final double workWaste = _groupDisplayToApi(data, double.tryParse(workWasteText) ?? 0);
    final double materialWaste =
    _groupDisplayToApi(data, double.tryParse(materialWasteText) ?? 0);

    final result = await _apiService.batchInspect(
      taskIds: qcTasks.map((t) => t.id).toList(),
      totalWorkWasteQty: workWaste,
      totalMaterialWasteQty: materialWaste,
      pass: pass,
      qcOpinion: opinion,
    );
    if (!mounted) return;

    final int code = result['code'] ?? 500;
    final String message = (result['data'] is Map ? result['data']['message'] : null) ??
        result['message'] ??
        (pass ? '质检提交失败' : '驳回失败');

    if (code == 200) {
      AppToast.success(context, message);
    } else {
      AppToast.error(context, message);
    }
    _loadData();
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
      AppToast.error(context, '获取任务详情失败');
    }
  }

  /// 打开批次分配审批页（班长把批次拆分到各生产订单）
  /// 同时把卡片上的报工型号/工序名称/信息字段带过去，满足"班长审核界面 = 报工界面内容 + 订单分配字段"
  Future<void> _openBatchApproval(
      ProcessMergeData data, ProcessType process, List<ProcessTaskItem> approvalTasks) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BatchApprovalPage(
          taskIds: approvalTasks.map((t) => t.id).toList(),
          reportSpec: _buildMergedSpec(data, process),
          processName: data.processName,
          unit: process.getDisplayUnit(data.isCutting),
          converter: data.converter,
          infoEntries: buildInfoEntries(data, process),
        ),
      ),
    );
    if (result == true) {
      _loadData();
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
      appBar: AppBar(title: const Text('槽道任务')),
      body: ProcessMergeView(userInfo: userInfo, filter: FilterCriteria()),
    );
  }
}