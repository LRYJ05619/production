import 'package:flutter/material.dart';

// ==================== 用户角色枚举 ====================
enum UserRole {
  worker,    // 员工：填报实际数据
  inspector, // 质检：质检审核
  leader,    // 班长：最终审批
}

extension UserRoleExtension on UserRole {
  String get text {
    switch (this) {
      case UserRole.worker:
        return '员工';
      case UserRole.inspector:
        return '质检';
      case UserRole.leader:
        return '班长';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.leader:
        return Colors.red;
      case UserRole.inspector:
        return Colors.blue;
      case UserRole.worker:
        return Colors.green;
    }
  }

  /// 从API的role字符串转换
  static UserRole fromApiRole(String role) {
    switch (role) {
      case 'super_admin':
      case 'admin':
      case 'team_leader':
        return UserRole.leader;
      case 'inspector':
        return UserRole.inspector;
      case 'worker':
      default:
        return UserRole.worker;
    }
  }

  /// 从用户名判断角色（备用）
  static UserRole fromUsername(String username) {
    if (username.contains('班长')) return UserRole.leader;
    if (username.contains('质检')) return UserRole.inspector;
    return UserRole.worker;
  }
}

// ==================== 任务状态枚举（API状态码） ====================
enum ApiTaskStatus {
  //unassigned(0, '待分配'),
  assigned(1, '已分配'),
  claimed(2, '已领取'),
  pendingApproval(3, '待审批'),
  leaderReject(4, '班长发回'),
  pendingQc(5, '待质检'),
  qcReject(6, '质检发回'),
  completed(7, '已完成'),
  resubmit(8, '再次提交');

  final int code;
  final String text;
  const ApiTaskStatus(this.code, this.text);

  static ApiTaskStatus fromCode(int code) {
    return ApiTaskStatus.values.firstWhere(
          (s) => s.code == code,
      //orElse: () => ApiTaskStatus.unassigned,
    );
  }

  Color get color {
    switch (this) {
      //case ApiTaskStatus.unassigned:
      //  return Colors.grey;
      case ApiTaskStatus.assigned:
        return Colors.blue;
      case ApiTaskStatus.claimed:
        return Colors.orange;
      case ApiTaskStatus.pendingApproval:
      case ApiTaskStatus.pendingQc:
        return Colors.amber;
      case ApiTaskStatus.leaderReject:
      case ApiTaskStatus.qcReject:
        return Colors.red;
      case ApiTaskStatus.completed:
        return Colors.green;
      case ApiTaskStatus.resubmit:
        return Colors.purple;
    }
  }

  /// 是否可以被员工操作
  bool get canWorkerOperate {
    return this == ApiTaskStatus.assigned ||
        this == ApiTaskStatus.leaderReject ||
        this == ApiTaskStatus.claimed ||
        this == ApiTaskStatus.qcReject;
  }

  /// 是否可以被质检操作
  bool get canQcOperate {
    return this == ApiTaskStatus.pendingQc;
  }

  /// 是否可以被班长操作
  bool get canLeaderOperate {
    return this == ApiTaskStatus.pendingApproval || this == ApiTaskStatus.resubmit;
  }
}

// ==================== 登录响应模型 ====================
class LoginResponse {
  final String token;
  final UserInfo user;
  final DateTime expiresAt;

  LoginResponse({
    required this.token,
    required this.user,
    required this.expiresAt,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] ?? '',
      user: UserInfo.fromJson(json['user'] ?? {}),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now().add(const Duration(days: 1)),
    );
  }
}

// ==================== 用户信息模型 ====================
class UserInfo {
  final int id;
  final String username;
  final String realName;
  final String role;
  final int teamId;
  final String teamName;
  final int status;

  UserInfo({
    required this.id,
    required this.username,
    required this.realName,
    required this.role,
    required this.teamId,
    required this.teamName,
    required this.status,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      realName: json['real_name'] ?? '',
      role: json['role'] ?? 'worker',
      teamId: json['team_id'] ?? 0,
      teamName: json['team_name'] ?? '',
      status: json['status'] ?? 0,
    );
  }

  UserRole get userRole => UserRoleExtension.fromApiRole(role);
}

// ==================== 生产计划信息模型 ====================
class PlanInfo {
  final int id;
  final String orderNo;
  final int orderLineNo;
  final String productCode;
  final String productName;
  final String specModel;
  final String productType;
  final String processSeq;
  final String processCode;
  final String processName;
  final String isOutsource;
  final int planQty;
  final String unit;
  final DateTime? planStartTime;
  final DateTime? planEndTime;
  final double assignedQty;
  final double completedQty;
  final double progress;
  final double transferInQty;
  final bool isFirstOper;
  final int status;

  PlanInfo({
    required this.id,
    required this.orderNo,
    required this.orderLineNo,
    required this.productCode,
    required this.productName,
    required this.specModel,
    required this.productType,
    required this.processSeq,
    required this.processCode,
    required this.processName,
    required this.isOutsource,
    required this.planQty,
    required this.unit,
    this.planStartTime,
    this.planEndTime,
    required this.assignedQty,
    required this.completedQty,
    required this.progress,
    required this.transferInQty,
    required this.isFirstOper,
    required this.status,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      orderLineNo: json['order_line_no'] ?? 0,
      productCode: json['product_code'] ?? '',
      productName: json['product_name'] ?? '',
      specModel: json['spec_model'] ?? '',
      productType: json['product_type'] ?? '',
      processSeq: json['process_seq'] ?? 0,
      processCode: json['process_code'] ?? '',
      processName: json['process_name'] ?? '',
      isOutsource: json['is_outsource'] ?? 'N',
      planQty: (json['plan_qty'] ?? 0).toInt(),
      unit: json['unit'] ?? '个',
      planStartTime: json['plan_start_time'] != null
          ? DateTime.tryParse(json['plan_start_time'])
          : null,
      planEndTime: json['plan_end_time'] != null
          ? DateTime.tryParse(json['plan_end_time'])
          : null,
      assignedQty: (json['assigned_qty'] ?? 0).toDouble(),
      completedQty: (json['completed_qty'] ?? 0).toDouble(),
      progress: (json['progress'] ?? 0).toDouble(),
      transferInQty: (json['transfer_in_qty'] ?? 0).toDouble(),
      isFirstOper: json['is_first_oper'] ?? false,
      status: json['status'] ?? 0,
    );
  }
}

// ==================== 计划外工作信息模型（来自extra_work关联对象） ====================
class ExtraWorkInfo {
  final int id;
  final String workNo;           // 编号，格式EW...
  final String workContent;      // 工作内容
  final String location;         // 工作地点
  final String workDescription;  // 工作说明
  final double planHours;        // 计划总工时
  final DateTime? planFinishTime; // 要求完成时间
  final double assignedHours;    // 已分配工时
  final int status;              // 状态：0-待分配,1-已分配,4-待审批,5-已完成
  final int creatorId;           // 创建人ID
  final String creatorName;      // 创建人姓名
  final String remark;           // 备注信息
  final DateTime createdAt;
  final DateTime updatedAt;

  ExtraWorkInfo({
    required this.id,
    required this.workNo,
    required this.workContent,
    required this.location,
    required this.workDescription,
    required this.planHours,
    this.planFinishTime,
    required this.assignedHours,
    required this.status,
    required this.creatorId,
    required this.creatorName,
    required this.remark,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExtraWorkInfo.fromJson(Map<String, dynamic> json) {
    return ExtraWorkInfo(
      id: json['id'] ?? 0,
      workNo: json['work_no'] ?? '',
      workContent: json['work_content'] ?? '',
      location: json['location'] ?? '',
      workDescription: json['work_description'] ?? '',
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      planFinishTime: json['plan_finish_time'] != null
          ? DateTime.tryParse(json['plan_finish_time'])
          : null,
      assignedHours: (json['assigned_hours'] ?? 0).toDouble(),
      status: json['status'] ?? 0,
      creatorId: json['creator_id'] ?? 0,
      creatorName: json['creator_name'] ?? '',
      remark: json['remark'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get statusText {
    switch (status) {
      case 0: return '待分配';
      case 1: return '已分配';
      case 4: return '待审批';
      case 5: return '已完成';
      default: return '未知';
    }
  }

  Color get statusColor {
    switch (status) {
      case 0: return Colors.grey;
      case 1: return Colors.blue;
      case 4: return Colors.amber;
      case 5: return Colors.green;
      default: return Colors.grey;
    }
  }
}

// ==================== 计划外工作任务数据模型（完整的task数据） ====================
class ExtraWorkData {
  // 任务基本信息
  final int id;
  final String taskNo;
  final int taskType;  // 固定为2
  final int workerId;
  final SimpleUserInfo? worker;
  final int teamId;
  final int? extraWorkId;
  final ExtraWorkInfo? extraWork;  // 关联的计划外工作信息

  // 任务字段（计划外工作直接存储在task上）
  final double planHours;
  final double actualHours;
  final String workSummary;
  final String location;
  final String workContent;
  final String workDescription;
  final DateTime? planFinishTime;

  // 报工数据
  final double workHours;

  // 审批信息
  final int? approverId;
  final SimpleUserInfo? approver;
  final DateTime? approvalTime;
  final String approvalNote;
  final String rejectReason;

  // 状态
  final ApiTaskStatus status;

  // 时间戳
  final DateTime createdAt;
  final DateTime updatedAt;

  // 列表数据直接提供的字段
  final String? _workerName;

  ExtraWorkData({
    required this.id,
    required this.taskNo,
    required this.taskType,
    required this.workerId,
    this.worker,
    required this.teamId,
    this.extraWorkId,
    this.extraWork,
    required this.planHours,
    required this.actualHours,
    required this.workSummary,
    required this.location,
    required this.workContent,
    required this.workDescription,
    this.planFinishTime,
    required this.workHours,
    this.approverId,
    this.approver,
    this.approvalTime,
    required this.approvalNote,
    required this.rejectReason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    String? workerName,
  }) : _workerName = workerName;

  /// 从详情接口创建（包含extra_work关联对象）
  factory ExtraWorkData.fromJson(Map<String, dynamic> json) {
    return ExtraWorkData(
      id: json['id'] ?? 0,
      taskNo: json['task_no'] ?? '',
      taskType: json['task_type'] ?? 2,
      workerId: json['worker_id'] ?? 0,
      worker: json['worker'] != null ? SimpleUserInfo.fromJson(json['worker']) : null,
      teamId: json['team_id'] ?? 0,
      extraWorkId: json['extra_work_id'],
      extraWork: json['extra_work'] != null ? ExtraWorkInfo.fromJson(json['extra_work']) : null,
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      actualHours: (json['actual_hours'] ?? 0).toDouble(),
      workSummary: json['work_summary'] ?? '',
      location: json['location'] ?? '',
      workContent: json['work_content'] ?? '',
      workDescription: json['work_description'] ?? '',
      planFinishTime: json['plan_finish_time'] != null
          ? DateTime.tryParse(json['plan_finish_time'])
          : null,
      workHours: (json['work_hours'] ?? 0).toDouble(),
      approverId: json['approver_id'],
      approver: json['approver'] != null ? SimpleUserInfo.fromJson(json['approver']) : null,
      approvalTime: json['approval_time'] != null
          ? DateTime.tryParse(json['approval_time'])
          : null,
      approvalNote: json['approval_note'] ?? '',
      rejectReason: json['reject_reason'] ?? '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// 从列表接口创建（简化数据）
  factory ExtraWorkData.fromListJson(Map<String, dynamic> json) {
    return ExtraWorkData(
      id: json['id'] ?? 0,
      taskNo: json['task_no'] ?? '',
      taskType: json['task_type'] ?? 2,
      workerId: json['worker_id'] ?? 0,
      worker: null,
      teamId: json['team_id'] ?? 0,
      extraWorkId: json['extra_work_id'],
      extraWork: null,
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      actualHours: 0,
      workSummary: json['work_summary'] ?? '',
      location: json['location'] ?? '',
      workContent: json['work_content'] ?? '',
      workDescription: json['work_description'] ?? '',
      planFinishTime: json['plan_finish_time'] != null
          ? DateTime.tryParse(json['plan_finish_time'])
          : null,
      workHours: 0,
      approverId: null,
      approver: null,
      approvalTime: null,
      approvalNote: '',
      rejectReason: '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      workerName: json['worker_name'],
    );
  }

  // 便捷getter
  String get workerName => _workerName ?? worker?.realName ?? '';
  String get approverName => approver?.realName ?? '';

  // 优先从extraWork获取，否则从task本身获取
  String get displayWorkNo => extraWork?.workNo ?? taskNo;
  String get displayWorkContent => extraWork?.workContent ?? workContent;
  String get displayLocation => extraWork?.location ?? location;
  String get displayWorkDescription => extraWork?.workDescription ?? workDescription;
  double get displayPlanHours => extraWork?.planHours ?? planHours;
  DateTime? get displayPlanFinishTime => extraWork?.planFinishTime ?? planFinishTime;
  String get creatorName => extraWork?.creatorName ?? '';
  String get remark => extraWork?.remark ?? '';

  String get statusText => status.text;
  Color get statusColor => status.color;

  /// 判断指定用户是否可以操作此任务
  /// 判断指定用户是否可以操作此任务
  bool canOperate(UserInfo user) {
    switch (user.userRole) {
      case UserRole.worker:
      // 员工：任务分配给自己，且状态允许
        return workerId == user.id && status.canWorkerOperate;
      case UserRole.inspector:
      // 质检：状态为待质检
        return false;
      case UserRole.leader:
      // 班长：状态为待审批或执行人为自己
        return status.canLeaderOperate ||
            (workerId == user.id && status.canWorkerOperate);
    }
  }
}

// ==================== 简单用户信息（关联查询用） ====================
class SimpleUserInfo {
  final int id;
  final String username;
  final String realName;

  SimpleUserInfo({
    required this.id,
    required this.username,
    required this.realName,
  });

  factory SimpleUserInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SimpleUserInfo(id: 0, username: '', realName: '');
    }
    return SimpleUserInfo(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      realName: json['real_name'] ?? '',
    );
  }
}

// ==================== API任务数据模型 ====================
class ApiTaskData {
  final int id;
  final String taskNo;
  final int taskType;
  final int planId;
  final PlanInfo? plan;
  final int workerId;
  final SimpleUserInfo? worker;
  final int teamId;
  final int? extraWorkId;
  final double planHours;
  final double actualHours;
  final String workSummary;
  final int? producerId;
  final SimpleUserInfo? producer;
  final int assignedQty;
  final DateTime? planFinishTime;
  final double completedQty;
  final double qualifiedQty;
  final double workWasteQty;
  final double materialWasteQty;
  final double repairQty;
  final double lossQty;
  final double workHours;
  final int? qcUserId;
  final SimpleUserInfo? qcUser;
  final double qcQualifiedQty;
  final double qcWasteQty;
  final String qcOpinion;
  final DateTime? qcTime;
  final int? approverId;
  final SimpleUserInfo? approver;
  final DateTime? approvalTime;
  final String approvalNote;
  final String rejectReason;
  final ApiTaskStatus status;
  final String kingdeeNo;
  final int reportStatus;
  final String errorMsg;
  final DateTime? reportTime;
  final bool isSettled;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 列表数据直接提供的字段（不通过plan获取）
  final String? _orderNo;
  final String? _productCode;
  final String? _productName;
  final String? _processCode;
  final String? _processName;
  final int? _planQty;
  final String? _workerName;

  ApiTaskData({
    required this.id,
    required this.taskNo,
    required this.taskType,
    required this.planId,
    this.plan,
    required this.workerId,
    this.worker,
    required this.teamId,
    this.extraWorkId,
    required this.planHours,
    required this.actualHours,
    required this.workSummary,
    this.producerId,
    this.producer,
    required this.assignedQty,
    this.planFinishTime,
    required this.completedQty,
    required this.qualifiedQty,
    required this.workWasteQty,
    required this.materialWasteQty,
    required this.repairQty,
    required this.lossQty,
    required this.workHours,
    this.qcUserId,
    this.qcUser,
    required this.qcQualifiedQty,
    required this.qcWasteQty,
    required this.qcOpinion,
    this.qcTime,
    this.approverId,
    this.approver,
    this.approvalTime,
    required this.approvalNote,
    required this.rejectReason,
    required this.status,
    required this.kingdeeNo,
    required this.reportStatus,
    required this.errorMsg,
    this.reportTime,
    required this.isSettled,
    required this.createdAt,
    required this.updatedAt,
    String? orderNo,
    String? productCode,
    String? productName,
    String? processCode,
    String? processName,
    int? planQty,
    String? workerName,
  }) : _orderNo = orderNo,
        _productCode = productCode,
        _productName = productName,
        _processCode = processCode,
        _processName = processName,
        _planQty = planQty,
        _workerName = workerName;

  /// 从详情接口创建
  factory ApiTaskData.fromJson(Map<String, dynamic> json) {
    return ApiTaskData(
      id: json['id'] ?? 0,
      taskNo: json['task_no'] ?? '',
      taskType: json['task_type'] ?? 1,
      planId: json['plan_id'] ?? 0,
      plan: json['plan'] != null ? PlanInfo.fromJson(json['plan']) : null,
      workerId: json['worker_id'] ?? 0,
      worker: json['worker'] != null ? SimpleUserInfo.fromJson(json['worker']) : null,
      teamId: json['team_id'] ?? 0,
      extraWorkId: json['extra_work_id'],
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      actualHours: (json['actual_hours'] ?? 0).toDouble(),
      workSummary: json['work_summary'] ?? '',
      producerId: json['producer_id'],
      producer: json['producer'] != null ? SimpleUserInfo.fromJson(json['producer']) : null,
      assignedQty: (json['assigned_qty'] ?? 0).toInt(),
      planFinishTime: json['plan_finish_time'] != null
          ? DateTime.tryParse(json['plan_finish_time'])
          : null,
      completedQty: (json['completed_qty'] ?? 0).toDouble(),
      qualifiedQty: (json['qualified_qty'] ?? 0).toDouble(),
      workWasteQty: (json['work_waste_qty'] ?? 0).toDouble(),
      materialWasteQty: (json['material_waste_qty'] ?? 0).toDouble(),
      repairQty: (json['repair_qty'] ?? 0).toDouble(),
      lossQty: (json['loss_qty'] ?? 0).toDouble(),
      workHours: (json['work_hours'] ?? 0).toDouble(),
      qcUserId: json['qc_user_id'],
      qcUser: json['qc_user'] != null ? SimpleUserInfo.fromJson(json['qc_user']) : null,
      qcQualifiedQty: (json['qc_qualified_qty'] ?? 0).toDouble(),
      qcWasteQty: (json['qc_waste_qty'] ?? 0).toDouble(),
      qcOpinion: json['qc_opinion'] ?? '',
      qcTime: json['qc_time'] != null ? DateTime.tryParse(json['qc_time']) : null,
      approverId: json['approver_id'],
      approver: json['approver'] != null ? SimpleUserInfo.fromJson(json['approver']) : null,
      approvalTime: json['approval_time'] != null
          ? DateTime.tryParse(json['approval_time'])
          : null,
      approvalNote: json['approval_note'] ?? '',
      rejectReason: json['reject_reason'] ?? '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      kingdeeNo: json['kingdee_no'] ?? '',
      reportStatus: json['report_status'] ?? 0,
      errorMsg: json['error_msg'] ?? '',
      reportTime: json['report_time'] != null ? DateTime.tryParse(json['report_time']) : null,
      isSettled: json['is_settled'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// 从列表接口创建（简化数据）
  factory ApiTaskData.fromListJson(Map<String, dynamic> json) {
    return ApiTaskData(
      id: json['id'] ?? 0,
      taskNo: json['task_no'] ?? '',
      taskType: json['task_type'] ?? 1,
      planId: 0,
      plan: null,
      workerId: json['worker_id'] ?? 0,
      worker: null,
      teamId: 0,
      planHours: 0,
      actualHours: 0,
      workSummary: '',
      completedQty: 0,
      qualifiedQty: 0,
      workWasteQty: 0,
      materialWasteQty: 0,
      repairQty: 0,
      lossQty: 0,
      workHours: 0,
      qcQualifiedQty: 0,
      qcWasteQty: 0,
      qcOpinion: '',
      approvalNote: '',
      rejectReason: '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      kingdeeNo: '',
      reportStatus: 0,
      errorMsg: '',
      isSettled: false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      // 列表直接提供的字段
      orderNo: json['order_no'],
      productCode: json['product_code'],
      productName: json['product_name'],
      processCode: json['process_code'],
      processName: json['process_name'],
      planQty: json['plan_qty']?.toInt(),
      assignedQty: json['assigned_qty']?.toInt(),
      workerName: json['worker_name'],
    );
  }

  // 便捷getter - 优先从列表数据获取，否则从plan获取
  String get orderNo => _orderNo ?? plan?.orderNo ?? '';
  String get productCode => _productCode ?? plan?.productCode ?? '';
  String get productName => _productName ?? plan?.productName ?? '';
  String get processCode => _processCode ?? plan?.processCode ?? '';
  String get processName => _processName ?? plan?.processName ?? '';
  int get planQty => _planQty ?? plan?.planQty ?? 0;
  String get specModel => plan?.specModel ?? '';
  String get unit => plan?.unit ?? '个';

  // 便捷getter - 从关联用户获取
  String get workerName => _workerName ?? worker?.realName ?? '';
  String get producerName => producer?.realName ?? '';
  String get qcUserName => qcUser?.realName ?? '';
  String get approverName => approver?.realName ?? '';

  /// 是否是计划外任务
  bool get isExtraWork => taskType == 2;

  /// 判断指定用户是否可以操作此任务
  bool canOperate(UserInfo user) {
    switch (user.userRole) {
      case UserRole.worker:
      // 员工：任务分配给自己，且状态允许
        return workerId == user.id && status.canWorkerOperate;
      case UserRole.inspector:
      // 质检：状态为待质检
        return status.canQcOperate;
      case UserRole.leader:
      // 班长：状态为待审批或执行人为自己
        return status.canLeaderOperate ||
            (workerId == user.id && status.canWorkerOperate);
    }
  }

  /// 判断员工是否需要填写报工表单
  bool needWorkerForm(int userId) {
    // 已领取、班长发回、质检发回状态，且是自己的任务
    return workerId == userId &&
        (status == ApiTaskStatus.claimed ||
            status == ApiTaskStatus.leaderReject ||
            status == ApiTaskStatus.qcReject);
  }
}

// ==================== 分页响应模型 ====================
class PaginatedResponse<T> {
  final List<T> data;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  PaginatedResponse({
    required this.data,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });
}

// ==================== 筛选条件模型 ====================
class FilterCriteria {
  final String? orderNo;
  final int? status;
  final int? workerId;
  final String? startTime;
  final String? endTime;
  final int? teamId;

  FilterCriteria({
    this.orderNo,
    this.status,
    this.workerId,
    this.startTime,
    this.endTime,
    this.teamId,
  });

  bool get hasFilter =>
      orderNo != null ||
          status != null ||
          workerId != null ||
          startTime != null ||
          endTime != null ||
          teamId != null;

  FilterCriteria copyWith({
    String? orderNo,
    int? status,
    int? workerId,
    String? startTime,
    String? endTime,
    int? teamId,
    bool clearOrderNo = false,
    bool clearStatus = false,
    bool clearWorkerId = false,
    bool clearStartTime = false,
    bool clearEndTime = false,
    bool clearTeamId = false,
  }) {
    return FilterCriteria(
      orderNo: clearOrderNo ? null : (orderNo ?? this.orderNo),
      status: clearStatus ? null : (status ?? this.status),
      workerId: clearWorkerId ? null : (workerId ?? this.workerId),
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      teamId: clearTeamId ? null : (teamId ?? this.teamId),
    );
  }
}