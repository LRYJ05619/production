import 'package:flutter/material.dart';

/// 统一解析API返回的时间字符串，确保转为本地时间
/// API返回带+08:00时区的时间，DateTime.tryParse会存为UTC，
/// 调用.toLocal()转回本地时间，保证.hour等属性正确
DateTime? parseLocalTime(dynamic timeStr) {
  if (timeStr == null || timeStr is! String || timeStr.isEmpty) return null;
  return DateTime.tryParse(timeStr)?.toLocal();
}

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

  static UserRole fromUsername(String username) {
    if (username.contains('班长')) return UserRole.leader;
    if (username.contains('质检')) return UserRole.inspector;
    return UserRole.worker;
  }
}

// ==================== 任务状态枚举（API状态码） ====================
enum ApiTaskStatus {
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
    );
  }

  Color get color {
    switch (this) {
      case ApiTaskStatus.assigned:
        return Colors.blue;
      case ApiTaskStatus.claimed:
        return Colors.orange;
      case ApiTaskStatus.pendingApproval:
        return Colors.cyan;
      case ApiTaskStatus.pendingQc:
        return Colors.greenAccent;
      case ApiTaskStatus.leaderReject:
      case ApiTaskStatus.qcReject:
        return Colors.red;
      case ApiTaskStatus.completed:
        return Colors.green;
      case ApiTaskStatus.resubmit:
        return Colors.purple;
    }
  }

  bool get canWorkerOperate {
    return this == ApiTaskStatus.assigned ||
        this == ApiTaskStatus.leaderReject ||
        this == ApiTaskStatus.claimed ||
        this == ApiTaskStatus.qcReject;
  }

  bool get canQcOperate {
    return this == ApiTaskStatus.pendingQc;
  }

  bool get canLeaderOperate {
    return this == ApiTaskStatus.pendingApproval || this == ApiTaskStatus.resubmit;
  }

  /// 是否已经过质检环节（质检提交后工废/料废才有意义，此时即使为0也要显示出来）
  bool get isQcDone {
    return this == ApiTaskStatus.pendingApproval ||
        this == ApiTaskStatus.leaderReject ||
        this == ApiTaskStatus.completed ||
        this == ApiTaskStatus.resubmit;
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
      expiresAt: parseLocalTime(json['expires_at']) ?? DateTime.now().add(const Duration(days: 1)),
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
  final double assignableQty;   // 可分配数量
  final double reportableQty;   // 可报工数量
  final double completedQty;
  final double totalWasteQty;
  final double progress;
  final double transferInQty;
  final bool isFirstOper;
  final bool freeReport;
  final String remark;
  final String connector;
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
    this.assignableQty = 0,
    this.reportableQty = 0,
    required this.completedQty,
    required this.totalWasteQty,
    required this.progress,
    required this.transferInQty,
    required this.isFirstOper,
    required this.freeReport,
    required this.remark,
    required this.connector,
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
      planStartTime: parseLocalTime(json['plan_start_time']),
      planEndTime: parseLocalTime(json['plan_end_time']),
      assignedQty: (json['assigned_qty'] ?? 0).toDouble(),
      assignableQty: (json['assignable_qty'] ?? 0).toDouble(),
      reportableQty: (json['reportable_qty'] ?? 0).toDouble(),
      completedQty: (json['completed_qty'] ?? 0).toDouble(),
      totalWasteQty: (json['total_waste_qty'] ?? 0).toDouble(),
      progress: (json['progress'] ?? 0).toDouble(),
      transferInQty: (json['transfer_in_qty'] ?? 0).toDouble(),
      isFirstOper: json['is_first_oper'] ?? false,
      freeReport: json['free_report'] ?? false,
      remark: json['remark'] ?? '',
      connector: json['connector'] ?? '',
      status: json['status'] ?? 0,
    );
  }
}

// ==================== 计划外工作信息模型 ====================
class ExtraWorkInfo {
  final int id;
  final String workNo;
  final String workContent;
  final String location;
  final String workDescription;
  final double planQty;
  final double planHours;
  final DateTime? planFinishTime;
  final double assignedHours;
  final int status;
  final int creatorId;
  final String creatorName;
  final String remark;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExtraWorkInfo({
    required this.id,
    required this.workNo,
    required this.workContent,
    required this.location,
    required this.workDescription,
    required this.planQty,
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
      planQty: (json['plan_qty'] ?? 0).toDouble(),
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      planFinishTime: parseLocalTime(json['plan_finish_time']),
      assignedHours: (json['assigned_hours'] ?? 0).toDouble(),
      status: json['status'] ?? 0,
      creatorId: json['creator_id'] ?? 0,
      creatorName: json['creator_name'] ?? '',
      remark: json['remark'] ?? '',
      createdAt: parseLocalTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseLocalTime(json['updated_at']) ?? DateTime.now(),
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

// ==================== 计划外工作任务数据模型 ====================
class ExtraWorkData {
  final int id;
  final String taskNo;
  final int taskType;
  final int workerId;
  final SimpleUserInfo? worker;
  final int teamId;
  final int? extraWorkId;
  final ExtraWorkInfo? extraWork;

  final double planQty;
  final double planHours;
  final double actualHours;
  final String workSummary;
  final String location;
  final String workContent;
  final String workDescription;
  final DateTime? planFinishTime;

  final double workHours;
  final double completedQty;

  final int? approverId;
  final SimpleUserInfo? approver;
  final DateTime? approvalTime;
  final String approvalNote;
  final String rejectReason;

  final ApiTaskStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? claimTime;

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
    required this.planQty,
    required this.planHours,
    required this.actualHours,
    required this.workSummary,
    required this.location,
    required this.workContent,
    required this.workDescription,
    this.planFinishTime,
    required this.workHours,
    required this.completedQty,
    this.approverId,
    this.approver,
    this.approvalTime,
    required this.approvalNote,
    required this.rejectReason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.claimTime,
    String? workerName,
  }) : _workerName = workerName;

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
      planQty: (json['plan_qty'] ?? 0).toDouble(),
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      actualHours: (json['actual_hours'] ?? 0).toDouble(),
      workSummary: json['work_summary'] ?? '',
      location: json['location'] ?? '',
      workContent: json['work_content'] ?? '',
      workDescription: json['work_description'] ?? '',
      planFinishTime: parseLocalTime(json['plan_finish_time']),
      workHours: (json['work_hours'] ?? 0).toDouble(),
      completedQty: (json['completed_qty'] ?? 0).toDouble(),
      approverId: json['approver_id'],
      approver: json['approver'] != null ? SimpleUserInfo.fromJson(json['approver']) : null,
      approvalTime: parseLocalTime(json['approval_time']),
      approvalNote: json['approval_note'] ?? '',
      rejectReason: json['reject_reason'] ?? '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      createdAt: parseLocalTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseLocalTime(json['updated_at']) ?? DateTime.now(),
      claimTime: parseLocalTime(json['claim_time']),
    );
  }

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
      planQty: (json['plan_qty'] ?? 0).toDouble(),
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      actualHours: 0,
      workSummary: json['work_summary'] ?? '',
      location: json['location'] ?? '',
      workContent: json['work_content'] ?? '',
      workDescription: json['work_description'] ?? '',
      planFinishTime: parseLocalTime(json['plan_finish_time']),
      workHours: 0,
      completedQty: (json['completed_qty'] ?? 0).toDouble(),
      approverId: null,
      approver: null,
      approvalTime: null,
      approvalNote: '',
      rejectReason: '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      createdAt: parseLocalTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseLocalTime(json['updated_at']) ?? DateTime.now(),
      claimTime: parseLocalTime(json['claim_time']),
      workerName: json['worker_name'],
    );
  }

  String get workerName => _workerName ?? worker?.realName ?? '';
  String get approverName => approver?.realName ?? '';

  String get displayWorkNo => extraWork?.workNo ?? taskNo;
  String get displayWorkContent => extraWork?.workContent ?? workContent;
  String get displayLocation => extraWork?.location ?? location;
  String get displayWorkDescription => extraWork?.workDescription ?? workDescription;
  double get displayPlanQty => extraWork?.planQty ?? planQty;
  double get displayPlanHours => extraWork?.planHours ?? planHours;
  DateTime? get displayPlanFinishTime => extraWork?.planFinishTime ?? planFinishTime;
  String get creatorName => extraWork?.creatorName ?? '';
  String get remark => extraWork?.remark ?? '';

  String get statusText => status.text;
  Color get statusColor => status.color;

  bool canOperate(UserInfo user) {
    switch (user.userRole) {
      case UserRole.worker:
        return workerId == user.id && status.canWorkerOperate;
      case UserRole.inspector:
        return false;
      case UserRole.leader:
        return status.canLeaderOperate ||
            (workerId == user.id && status.canWorkerOperate);
    }
  }
}

// ==================== 简单用户信息 ====================
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
  final double assignedQty;
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
  final bool freeReport;
  final String workType;
  final String timeType;
  final String deviceName;
  final double quota8h;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? claimTime;

  final String? _orderNo;
  final String? _productCode;
  final String? _productName;
  final String? _processCode;
  final String? _processName;
  final int? _planQty;
  final String? _workerName;
  final String? _specModel;
  final String? _remark;
  final String? _connector;

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
    required this.freeReport,
    required this.workType,
    required this.timeType,
    required this.deviceName,
    required this.quota8h,
    required this.createdAt,
    required this.updatedAt,
    this.claimTime,
    String? orderNo,
    String? productCode,
    String? productName,
    String? processCode,
    String? processName,
    int? planQty,
    String? workerName,
    String? specModel,
    String? remark,
    String? connector,
  }) : _orderNo = orderNo,
        _productCode = productCode,
        _productName = productName,
        _processCode = processCode,
        _processName = processName,
        _planQty = planQty,
        _workerName = workerName,
        _specModel = specModel,
        _remark = remark,
        _connector = connector;

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
      assignedQty: (json['assigned_qty'] ?? 0).toDouble(),
      planFinishTime: parseLocalTime(json['plan_finish_time']),
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
      qcTime: parseLocalTime(json['qc_time']),
      approverId: json['approver_id'],
      approver: json['approver'] != null ? SimpleUserInfo.fromJson(json['approver']) : null,
      approvalTime: parseLocalTime(json['approval_time']),
      approvalNote: json['approval_note'] ?? '',
      rejectReason: json['reject_reason'] ?? '',
      status: ApiTaskStatus.fromCode(json['status'] ?? 0),
      kingdeeNo: json['kingdee_no'] ?? '',
      reportStatus: json['report_status'] ?? 0,
      errorMsg: json['error_msg'] ?? '',
      reportTime: parseLocalTime(json['report_time']),
      isSettled: json['is_settled'] ?? false,
      freeReport: json['free_report'] ?? false,
      workType: json['work_type'] ?? '',
      timeType: json['time_type'] ?? '',
      deviceName: json['device_names'] ?? '',
      quota8h: (json['quota_8h'] ?? 0).toDouble(),
      createdAt: parseLocalTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseLocalTime(json['updated_at']) ?? DateTime.now(),
      claimTime: parseLocalTime(json['claim_time']),
      remark: json['remark'],
    );
  }

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
      // 以下字段列表接口可能返回也可能不返回，缺失时回退为0/空（卡片会自动隐藏空字段）
      planHours: (json['plan_hours'] ?? 0).toDouble(),
      actualHours: (json['actual_hours'] ?? 0).toDouble(),
      workSummary: '',
      planFinishTime: parseLocalTime(json['plan_finish_time']),
      completedQty: (json['completed_qty'] ?? 0).toDouble(),
      qualifiedQty: (json['qualified_qty'] ?? 0).toDouble(),
      workWasteQty: (json['work_waste_qty'] ?? 0).toDouble(),
      materialWasteQty: (json['material_waste_qty'] ?? 0).toDouble(),
      repairQty: 0,
      lossQty: 0,
      workHours: (json['work_hours'] ?? 0).toDouble(),
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
      freeReport: false,
      workType: json['work_type'] ?? '',
      timeType: json['time_type'] ?? '',
      deviceName: '',
      quota8h: 0,
      createdAt: parseLocalTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseLocalTime(json['updated_at']) ?? DateTime.now(),
      orderNo: json['order_no'],
      productCode: json['product_code'],
      productName: json['product_name'],
      processCode: json['process_code'],
      processName: json['process_name'],
      planQty: json['plan_qty']?.toInt(),
      assignedQty: json['assigned_qty']?.toDouble(),
      workerName: json['worker_name'],
      specModel: json['spec_model'],
      claimTime: parseLocalTime(json['claim_time']),
      remark: json['remark'],
      connector: json['connector'],
    );
  }

  String get orderNo => _orderNo ?? plan?.orderNo ?? '';
  String get productCode => _productCode ?? plan?.productCode ?? '';
  String get productName => _productName ?? plan?.productName ?? '';
  String get processCode => _processCode ?? plan?.processCode ?? '';
  String get processName => _processName ?? plan?.processName ?? '';
  int get planQty => _planQty ?? plan?.planQty ?? 0;
  String get specModel => _specModel ?? plan?.specModel ?? '';
  String get unit => plan?.unit ?? '个';
  String get remark => _remark ?? plan?.remark ?? '';
  String get connector => _connector ?? plan?.connector ?? '';

  /// 可分配数量 / 可报工数量（来自工序计划，仅任务详情接口返回）
  double get assignableQty => plan?.assignableQty ?? 0;
  double get reportableQty => plan?.reportableQty ?? 0;

  String get workerName => _workerName ?? worker?.realName ?? '';
  String get producerName => producer?.realName ?? '';
  String get qcUserName => qcUser?.realName ?? '';
  String get approverName => approver?.realName ?? '';

  bool get isExtraWork => taskType == 2;

  bool canOperate(UserInfo user) {
    switch (user.userRole) {
      case UserRole.worker:
        return workerId == user.id && status.canWorkerOperate;
      case UserRole.inspector:
        return status.canQcOperate;
      case UserRole.leader:
        return status.canLeaderOperate ||
            (workerId == user.id && status.canWorkerOperate);
    }
  }

  bool needWorkerForm(int userId) {
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

// ==================== 数量单位换算 ====================

/// 数量显示格式化：两位小数截断（不四舍五入），整数不带小数点
/// 只在最终展示时调用一次，中间的换算/累加一律用未取整的 double
num formatQtyNum(double v) {
  final double sign = v < 0 ? -1 : 1;
  final double t = (v.abs() * 100 + 1e-9).truncateToDouble() / 100 * sign;
  return t == t.roundToDouble() ? t.toInt() : t;
}

/// 两位小数截断，不四舍五入（提交接口前统一处理）
double truncateQty2(double qty) => (qty * 100 + 1e-9).truncateToDouble() / 100;

/// 槽道数量单位换算：API单位（外置=组、预埋=米） ↔ 显示单位（断料=根、其他=米）
///
/// 换算依赖 外置/预埋、是否断料、根系数、单根长度 四个属性，
/// 这些在合并分组内是一致的（外置/预埋已参与合并key）。
/// 统一放在这里，避免展示端和提交端各写一份导致两个方向不对称。
class QtyConverter {
  final bool isCutting;
  final bool isWaizhi;
  final int rootMultiplier; // 三根=3，双根=2，其他=1
  final double lengthMeters;

  const QtyConverter({
    required this.isCutting,
    required this.isWaizhi,
    this.rootMultiplier = 1,
    this.lengthMeters = 0,
  });

  /// 不做任何换算（锚栓/C型钢等非槽道产品）
  static const QtyConverter identity =
  QtyConverter(isCutting: false, isWaizhi: false);

  /// API单位 → 显示单位（刻意不取整：合计多个任务时必须先累加再统一格式化，
  /// 否则每单的小数份额会被逐个进位，把总数放大）
  double toDisplay(double apiQty) {
    if (isWaizhi && isCutting) {
      return apiQty * rootMultiplier;
    }
    if (isWaizhi && !isCutting && lengthMeters > 0) {
      return apiQty * rootMultiplier * lengthMeters;
    }
    if (!isWaizhi && isCutting && lengthMeters > 0) {
      return apiQty / lengthMeters;
    }
    return apiQty;
  }

  /// 显示单位 → API单位（与 toDisplay 严格互逆）
  double toApi(double displayQty) {
    if (isWaizhi && isCutting && rootMultiplier > 0) {
      return displayQty / rootMultiplier;
    }
    if (isWaizhi && !isCutting && rootMultiplier > 0 && lengthMeters > 0) {
      return displayQty / rootMultiplier / lengthMeters;
    }
    if (!isWaizhi && isCutting && lengthMeters > 0) {
      return displayQty * lengthMeters;
    }
    return displayQty;
  }

  /// API单位 → 显示单位并格式化（单个数值展示用）
  num toDisplayNum(double apiQty) => formatQtyNum(toDisplay(apiQty));
}

// ==================== 卡片信息字段 ====================

/// 卡片/审批页上的一个"标签: 值"信息项
/// fullWidth=true 的字段独占一行（如"计划完成时间"这类内容较长、半栏放不下的）
class InfoEntry {
  final String label;
  final String value;
  final bool fullWidth;

  const InfoEntry(this.label, this.value, {this.fullWidth = false});
}

// ==================== 槽道批次审批模型 ====================

/// 班长批次分配详情（/production/tasks/batch-approval-detail 返回）
///
/// tasks[] 的元素就是标准的任务对象（订单号等字段在其 plan 子对象里），
/// 因此直接复用 ApiTaskData.fromJson 解析，不再单独维护一套字段映射。
class BatchApprovalDetail {
  final String batchId;
  final double totalCompletedQty;
  final double totalWorkWasteQty;
  final double totalMaterialWasteQty;
  final double totalQualifiedQty;
  final List<ApiTaskData> tasks;

  BatchApprovalDetail({
    required this.batchId,
    required this.totalCompletedQty,
    required this.totalWorkWasteQty,
    required this.totalMaterialWasteQty,
    required this.totalQualifiedQty,
    required this.tasks,
  });

  factory BatchApprovalDetail.fromJson(Map<String, dynamic> json) {
    final tasks = (json['tasks'] as List? ?? [])
        .map((e) => ApiTaskData.fromJson(e as Map<String, dynamic>))
        .toList();

    /// 汇总字段优先用接口返回值；接口未返回（为0）时按 tasks 累加兜底，
    /// 避免因后端汇总字段缺失导致班长看到全 0 而无法分配
    double total(String key, double Function(ApiTaskData) pick) {
      final double v = (json[key] ?? 0).toDouble();
      if (v != 0) return v;
      return tasks.fold(0.0, (s, t) => s + pick(t));
    }

    return BatchApprovalDetail(
      batchId: json['batch_id'] ?? '',
      totalCompletedQty: total('total_completed_qty', (t) => t.completedQty),
      totalWorkWasteQty: total('total_work_waste_qty', (t) => t.workWasteQty),
      totalMaterialWasteQty:
      total('total_material_waste_qty', (t) => t.materialWasteQty),
      totalQualifiedQty: total('total_qualified_qty', (t) => t.qualifiedQty),
      tasks: tasks,
    );
  }
}

/// 班长提交 /production/tasks/leader-batch-approve 时，单个任务的分配数量
class LeaderBatchApproveItem {
  final int taskId;
  final double qualifiedQty;
  final double workWasteQty;
  final double materialWasteQty;

  LeaderBatchApproveItem({
    required this.taskId,
    required this.qualifiedQty,
    required this.workWasteQty,
    required this.materialWasteQty,
  });

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'qualified_qty': qualifiedQty,
    'work_waste_qty': workWasteQty,
    'material_waste_qty': materialWasteQty,
  };
}

/// leader-batch-approve 返回体里，同步金蝶失败的任务（code=206 部分失败时）
class LeaderBatchApproveFailedTask {
  final int taskId;
  final String taskNo;
  final String reason;

  LeaderBatchApproveFailedTask({
    required this.taskId,
    required this.taskNo,
    required this.reason,
  });

  factory LeaderBatchApproveFailedTask.fromJson(Map<String, dynamic> json) {
    return LeaderBatchApproveFailedTask(
      taskId: json['task_id'] ?? 0,
      taskNo: json['task_no'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}