import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
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
    if (code.contains('单焊')) return all.firstWhere((e) => e.code == 'single_welding');
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

  /// 是否是断料工序（优先使用processName匹配）
  bool get isCutting =>
      processName.contains('断料') ||
          processCode.contains('断料') ||
          processCode == 'cutting';

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
  final ApiTaskStatus status;
  final DateTime? claimTime;

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

  /// 自动计算实际工时（提报时间 - 开始时间）
  double calcWorkHours() {
    if (claimTime == null) return 0;
    final minutes = DateTime.now().difference(claimTime!).inMinutes;
    return double.parse((minutes / 60.0).toStringAsFixed(1));
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
      connector: task.remark.isNotEmpty ? task.remark : (parsedInfo['connector'] ?? ''),
      quantity: (task.planQty).toDouble(),
      processQty: (task.assignedQty).toDouble(),
      length: parsedInfo['length'] ?? 0.0,
      status: task.status,
      claimTime: task.claimTime,
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
  bool _isFirstLoad = true;  // 仅首次加载显示loading，后续无痕刷新

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
    // 仅首次加载显示loading动画，后续刷新无痕更新数据
    if (_isFirstLoad) {
      setState(() => _isLoading = true);
    }

    try {
      // 班长：不限workerId，看全组；员工：只看自己
      // 日期筛选由api_service默认处理（三天内）
      final FilterCriteria filter;
      if (_isLeader) {
        filter = FilterCriteria();
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
        'claim_time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'remark': '钢管',
      },
      // #2 A组：同 #1（预埋/外置不影响合并key）
      {
        'id': 90002, 'task_no': 'MOCK_GW_002', 'order_no': 'ORD_MOCK_002',
        'product_name': '直形燕尾双根成组外置槽道', 'spec_model': 'FPH 52/34-2500-Z (150)',
        'process_code': '成组焊接', 'process_name': '槽道成组焊接',
        'worker_name': widget.userInfo.realName, 'worker_id': widget.userInfo.id,
        'plan_qty': 300, 'assigned_qty': 300, 'status': 2, 'unit': '米',
        'claim_time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), 'remark': '钢管',
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
      final String groupType = parsedInfo['groupType'] ?? '';
      final double spacing = parsedInfo['spacing'] ?? 0.0;
      // 连接物体来自API的remark字段
      final String connector = task.remark.isNotEmpty ? task.remark : (parsedInfo['connector'] ?? '');

      // 按mergeRule动态构建合并key
      final String key = _buildMergeKey(normalizedProcess, processType, {
        'specType': specType,
        'material': material,
        'length': length,
        'shape': shape,
        'groupType': groupType,
        'spacing': spacing,
        'connector': connector,
      });

      debugPrint('[合并] 任务${task.taskNo}: processName=$processName → $normalizedProcess, '
          'specType=$specType, length=$length, shape=$shape, groupType=$groupType, '
          'connector=$connector, spec=${task.specModel} → key=$key');

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

  /// 根据工序的mergeRule动态构建合并key
  /// 类型&型号 = specType（如"FPH 52/34"，整体不可拆分）
  /// 断料: 类型&材质&型号&长度
  /// 弯弧/单焊/打磨: 类型&材质&型号&长度&直/弧
  /// 成组焊接: 类型&材质&型号&长度&直/弧&单/双/三&间距&连接物体
  String _buildMergeKey(String processCode, ProcessType processType, Map<String, dynamic> info) {
    final parts = <String>[processCode];

    // 所有工序共有：类型(含型号)&材质&长度
    parts.add(info['specType'] as String);
    parts.add(info['material'] as String);
    parts.add((info['length'] as double).toString());

    // 弯弧/单焊/打磨/成组焊接额外需要：直/弧
    if (processType.mergeRule.contains('直/弧')) {
      parts.add(info['shape'] as String);
    }

    // 成组焊接额外需要：单/双/三&间距&连接物体
    if (processType.mergeRule.contains('单/双/三')) {
      parts.add(info['groupType'] as String);
      parts.add((info['spacing'] as double).toString());
      parts.add(info['connector'] as String);
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
  ///   "FPH 52/34-2500-Z （150-150）"  → 52/34, 2500mm, 直形, 三根间距150
  ///   "FPH 53/34-1900-R6670"          → 53/34, 1900mm, 弧形R6670
  ///   "FPH 52/34-2500-Z-A4"           → 52/34, 2500mm, 直形, 不锈钢
  Map<String, dynamic> _parseTaskInfo(ApiTaskData task) {
    String spec = task.specModel;
    String name = task.productName;

    String material = '碳钢';
    double length = 0;
    String shape = 'Z';
    String specType = '';   // 类型&型号整体，如 "FPH 52/34"
    String groupType = '';
    double spacing = 0;

    // 1. 统一中文括号为英文括号
    String normalizedSpec = spec
        .replaceAll('（', '(')
        .replaceAll('）', ')');

    // 2. 先提取括号中的间距信息（成组槽道）
    final bracketMatch = RegExp(r'\(([^)]+)\)').firstMatch(normalizedSpec);
    if (bracketMatch != null) {
      String bracketContent = bracketMatch.group(1) ?? '';
      List<String> spacings = bracketContent.split('-');
      if (spacings.length >= 2) {
        // 两个数字 = 三根成组
        groupType = '三根';
        spacing = double.tryParse(spacings[0].trim()) ?? 0;
      } else if (spacings.length == 1 && spacings[0].trim().isNotEmpty) {
        // 一个数字 = 双根成组
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

    // 5. 第一部分：类型&型号整体（如 "FPH 52/34"，不可拆分）
    if (parts.isNotEmpty) {
      specType = parts[0].trim();
    }

    // 6. 第二部分：长度(mm)
    if (parts.length > 1) {
      String lenStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
      length = double.tryParse(lenStr) ?? 0;
    }

    // 7. 第三部分：形状 Z=直形，R+数字=弧形（整体如"R6100"参与合并）
    if (parts.length > 2) {
      String shapePart = parts[2].trim().toUpperCase();
      // 去掉A4后缀（不锈钢标记可能跟在形状后）
      shapePart = shapePart.replaceAll(RegExp(r'\s*A4$'), '');
      if (shapePart.startsWith('R')) {
        shape = shapePart;  // 保留完整值如 "R6100"
      } else {
        shape = 'Z';
      }
    }

    debugPrint('[解析] spec="$spec" → specType=$specType, length=$length, shape=$shape, '
        'material=$material, group=$groupType, spacing=$spacing');

    return {
      'specType': specType,
      'material': material,
      'length': length,
      'shape': shape,
      'groupType': groupType,
      'spacing': spacing,
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

  /// 按合并规则组成格式化型号字符串
  String _buildMergedSpec(ProcessMergeData data, ProcessType process) {
    // 基础：型号-长度
    final parts = <String>[data.model, '${data.length.toInt()}'];

    // 弯弧/单焊/打磨/组焊：追加形状
    if (process.mergeRule.contains('直/弧')) {
      parts.add(data.shape);
    }

    String spec = parts.join('-');

    // 组焊：追加间距括号
    if (process.mergeRule.contains('单/双/三') && data.groupType.isNotEmpty) {
      if (data.groupType == '三根') {
        spec += ' (${data.spacing.toInt()}-${data.spacing.toInt()})';
      } else {
        spec += ' (${data.spacing.toInt()})';
      }
    }

    // 组焊：追加连接物体
    if (process.mergeRule.contains('连接物体') && data.connector.isNotEmpty) {
      spec += ' ${data.connector}';
    }

    // 不锈钢追加A4
    if (data.material == '不锈钢') {
      spec += ' A4';
    }

    return spec;
  }

  Widget _buildMergeCard(ProcessMergeData data, ProcessType process) {
    final bool isCutting = data.isCutting;
    final String displayUnit = process.getDisplayUnit(isCutting);
    final int displayTotalQty = isCutting ? data.totalPieces.round() : data.totalQuantity.toInt();
    final int taskCount = data.tasks.length;

    // 格式化型号
    final String mergedSpec = _buildMergedSpec(data, process);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          // 左侧工序图标框
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
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: process.color),
                ),
              ],
            ),
          ),
          // 格式化型号（允许换行完整显示）
          title: Text(
            mergedSpec,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          // 第二行：材质 + 合计 + 任务数
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _buildTag(data.material, data.material == '不锈钢' ? Colors.indigo : Colors.brown),
                const SizedBox(width: 8),
                Text('合计: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  '$displayTotalQty',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                ),
                Text(' $displayUnit', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(width: 8),
                Text('$taskCount个', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...data.tasks.map((task) => _buildTaskItem(task, process, data.isCutting)),
            // 合并提报按钮（仅当有可提报任务时显示）
            if (data.tasks.any((t) => _isReportable(t.status)))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showBatchReportDialog(data, process),
                    icon: const Icon(Icons.send, size: 16),
                    label: Text('合并提报 (${data.tasks.where((t) => _isReportable(t.status)).length}个可提报)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: process.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：产品名称（独占一行，避免过长换行）
              Text(
                task.erpName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[800]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // 第二行：规格型号（独占一行）
              Text(
                task.erpModel,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // 第三行：状态标签 + 数量
              Row(
                children: [
                  // 状态标签
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: task.status.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      task.status.text,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: task.status.color),
                    ),
                  ),
                  const Spacer(),
                  // 数量
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: process.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$displayQty $displayUnit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: process.color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 判断任务状态是否支持提报（已领取、班长发回、质检发回）
  bool _isReportable(ApiTaskStatus status) {
    return status == ApiTaskStatus.claimed ||
        status == ApiTaskStatus.leaderReject ||
        status == ApiTaskStatus.qcReject;
  }

  /// 合并提报对话框 —— 用户自行填写每个任务的数量
  void _showBatchReportDialog(ProcessMergeData data, ProcessType process) {
    final bool isCutting = data.isCutting;
    final String displayUnit = process.getDisplayUnit(isCutting);

    // 仅筛选可提报的任务
    final reportableTasks = data.tasks.where((t) => _isReportable(t.status)).toList();
    if (reportableTasks.isEmpty) {
      AppToast.info(context, '当前没有可提报的任务');
      return;
    }

    // 为每个任务创建输入控制器：[qualified, workWaste, materialWaste]
    final Map<int, List<TextEditingController>> controllers = {};
    for (var task in reportableTasks) {
      controllers[task.id] = [
        TextEditingController(), // 合格数量
        TextEditingController(), // 工废数量
        TextEditingController(), // 料废数量
      ];
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('合并提报 - ${process.name}', style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_buildMergedSpec(data, process),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                Text('共${reportableTasks.length}个可提报任务，请分别填写数量',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 12),
                // 每个任务一组输入
                ...reportableTasks.map((task) {
                  final ctrls = controllers[task.id]!;
                  final int displayQty = task.getDisplayQty(isCutting).round();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 任务标题：产品名 + 派工数量
                        Row(
                          children: [
                            Expanded(
                              child: Text(task.erpName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text('派工: $displayQty $displayUnit',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 数量输入行
                        Row(
                          children: [
                            _buildCompactField('合格', ctrls[0], displayUnit),
                            const SizedBox(width: 6),
                            _buildCompactField('工废', ctrls[1], displayUnit),
                            const SizedBox(width: 6),
                            _buildCompactField('料废', ctrls[2], displayUnit),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              // 收集每个任务的数据
              final taskInputs = <int, List<double>>{};
              for (var task in reportableTasks) {
                final ctrls = controllers[task.id]!;
                taskInputs[task.id] = [
                  double.tryParse(ctrls[0].text) ?? 0,
                  double.tryParse(ctrls[1].text) ?? 0,
                  double.tryParse(ctrls[2].text) ?? 0,
                ];
              }
              Navigator.pop(ctx);
              _submitBatchReport(data, process, reportableTasks, taskInputs);
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
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

  /// 执行合并提报：用户自行填写的数量，逐任务提交
  Future<void> _submitBatchReport(
      ProcessMergeData data,
      ProcessType process,
      List<ProcessTaskItem> reportableTasks,
      Map<int, List<double>> taskInputs,
      ) async {
    final bool isCutting = data.isCutting;

    // 单位转换：断料工序用户输入根数，需转为米
    double toApi(double displayQty) {
      if (isCutting && data.lengthMeters > 0) {
        return displayQty * data.lengthMeters;
      }
      return displayQty;
    }

    final List<Map<String, dynamic>> items = [];

    // 计算总工时：提报时间 - 最早的开始时间，精确到小时保留一位小数
    DateTime? earliestStart;
    for (var task in reportableTasks) {
      if (task.claimTime != null) {
        if (earliestStart == null || task.claimTime!.isBefore(earliestStart)) {
          earliestStart = task.claimTime;
        }
      }
    }
    final double totalWorkHours = earliestStart != null
        ? double.parse((DateTime.now().difference(earliestStart).inMinutes / 60.0).toStringAsFixed(1))
        : 0;

    // 收集有效任务（有填写数量的）及其派工量
    final validTasks = <ProcessTaskItem>[];
    final validInputs = <List<double>>[];
    for (var task in reportableTasks) {
      final input = taskInputs[task.id];
      if (input == null) continue;
      if (input[0] <= 0 && input[1] <= 0 && input[2] <= 0) continue;
      validTasks.add(task);
      validInputs.add(input);
    }

    if (validTasks.isEmpty) {
      AppToast.error(context, '请至少填写一个任务的合格数量');
      return;
    }

    // 按派工数量等比分配工时，保证总和精确相等
    final double totalAssigned = validTasks.fold(0.0, (sum, t) => sum + t.processQty);
    double allocatedHours = 0;

    for (int i = 0; i < validTasks.length; i++) {
      final task = validTasks[i];
      final input = validInputs[i];

      final double qualified = input[0];
      final double workWaste = input[1];
      final double materialWaste = input[2];

      final double apiQualified = toApi(qualified);
      final double apiWorkWaste = toApi(workWaste);
      final double apiMaterialWaste = toApi(materialWaste);
      final double apiCompleted = apiQualified + apiWorkWaste + apiMaterialWaste;

      // 最后一个任务用减法确保总和精确
      double taskHours;
      if (i == validTasks.length - 1) {
        taskHours = double.parse((totalWorkHours - allocatedHours).toStringAsFixed(1));
      } else {
        final double ratio = totalAssigned > 0 ? task.processQty / totalAssigned : 1.0 / validTasks.length;
        taskHours = double.parse((totalWorkHours * ratio).toStringAsFixed(1));
        allocatedHours += taskHours;
      }

      items.add({
        'task_id': task.id,
        'completed_qty': double.parse(apiCompleted.toStringAsFixed(2)),
        'qualified_qty': double.parse(apiQualified.toStringAsFixed(2)),
        'work_waste_qty': double.parse(apiWorkWaste.toStringAsFixed(2)),
        'material_waste_qty': double.parse(apiMaterialWaste.toStringAsFixed(2)),
        'repair_qty': 0,
        'loss_qty': 0,
        'work_hours': taskHours,
      });
    }

    final result = await _apiService.batchReport(items);
    if (!mounted) return;

    final int code = result['code'] ?? 500;
    final String message = result['message'] ?? '提交失败';

    if (code == 200) {
      AppToast.success(context, message);
    } else if (code == 206) {
      // 部分成功，显示详情
      final List<dynamic> resultData = result['data'] ?? [];
      final failedCount = resultData.where((d) => d['success'] != true).length;
      AppToast.warning(context, '$message（$failedCount个失败）');
    } else {
      AppToast.error(context, message);
    }

    _loadData(); // 刷新数据
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