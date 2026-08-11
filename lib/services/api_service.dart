import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

/// API调用结果，携带错误信息
class ApiResult {
  final bool success;
  final String? errorMessage;

  ApiResult({required this.success, this.errorMessage});

  /// 从HTTP响应解析结果
  /// 400 → 显示 message 字段
  /// 500 → 显示 data 字段
  factory ApiResult.fromResponse(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      final code = json['code'];
      if (code == 200) {
        return ApiResult(success: true);
      }
      // 400: 优先显示data.details，否则显示message
      if (code == 400) {
        final data = json['data'];
        if (data is Map && data['details'] != null && data['details'].toString().isNotEmpty) {
          return ApiResult(success: false, errorMessage: data['details'].toString());
        }
        return ApiResult(
            success: false, errorMessage: json['message'] ?? '参数错误');
      }
      // 500: 显示data字段
      if (code == 500) {
        final data = json['data'];
        final msg = (data is String && data.isNotEmpty)
            ? data
            : (json['message'] ?? '服务器错误');
        return ApiResult(success: false, errorMessage: msg);
      }
      // 其他错误码
      return ApiResult(
          success: false,
          errorMessage: json['message'] ?? '操作失败(code:$code)');
    } catch (e) {
      return ApiResult(success: false, errorMessage: '响应解析失败');
    }
  }
}

class ApiService {
  // ==================== 服务器配置 ====================
  static String _serverIp = '61.181.91.2';
  static int _serverPort = 1680;
  // static String _serverIp = '192.168.1.6';
  // static int _serverPort = 8080;
  static String? _token;
  static UserInfo? _currentUser;

  static String get baseUrl => 'http://$_serverIp:$_serverPort';
  static const String apiPrefix = '/api/v1';

  /// 设置服务器地址
  static void setServer(String ip, {int port = 8080}) {
    _serverIp = ip;
    _serverPort = port;
  }

  static String getServerUrl() => baseUrl;
  static String getServerIp() => _serverIp;
  static int getServerPort() => _serverPort;

  /// Token管理
  static void setToken(String token) => _token = token;
  static String? getToken() => _token;
  static void setCurrentUser(UserInfo user) => _currentUser = user;
  static UserInfo? get currentUser => _currentUser;

  static void clearAuth() {
    _token = null;
    _currentUser = null;
  }

  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  /// 带Token的请求头
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ==================== 认证接口 ====================

  /// 用户登录
  Future<LoginResponse?> login(String username, String password) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/auth/login');
      final response = await _client
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          final loginResp = LoginResponse.fromJson(json['data']);
          _token = loginResp.token;
          _currentUser = loginResp.user;
          return loginResp;
        }
      }
      return null;
    } catch (e) {
      print('登录失败: $e');
      return null;
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/auth/logout');
      await _client
          .post(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('登出请求失败: $e');
    } finally {
      clearAuth();
    }
  }

  // ==================== 生产任务接口 ====================

  /// 获取任务列表
  /// productType: 产品类型筛选（兼容别名：anchor/锚栓、channel/槽道、csteel/C型钢），不传则不筛选
  Future<PaginatedResponse<ApiTaskData>> getTaskList({
    int page = 1,
    int pageSize = 10,
    int taskType = 1,
    String? productType,
    FilterCriteria? filter,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'task_type': taskType.toString(),
        if (productType != null && productType.isNotEmpty) 'product_type': productType,
      };

      if (filter != null) {
        if (filter.orderNo != null) queryParams['order_no'] = filter.orderNo!;
        if (filter.status != null)
          queryParams['status'] = filter.status.toString();
        if (filter.workerId != null)
          queryParams['worker_id'] = filter.workerId.toString();
        if (filter.startTime != null)
          queryParams['start_time'] = filter.startTime!;
        if (filter.endTime != null) queryParams['end_time'] = filter.endTime!;
        if (filter.teamId != null)
          queryParams['team_id'] = filter.teamId.toString();
      }

      // 默认筛选三天内任务（未手动指定时间范围时）
      if (!queryParams.containsKey('start_time')) {
        final now = DateTime.now();
        final threeDaysAgo = now.subtract(const Duration(days: 3));
        String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        queryParams['start_time'] = '${fmt(threeDaysAgo)} 00:00:00';
        queryParams['end_time'] = '${fmt(now)} 23:59:59';
      }

      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks')
          .replace(queryParameters: queryParams);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          final data = json['data'];
          final List<dynamic> dataList = data['data'] ?? [];
          final tasks =
          dataList.map((e) => ApiTaskData.fromListJson(e)).toList();
          final total = data['total'] ?? tasks.length;

          return PaginatedResponse(
            data: tasks,
            page: page,
            pageSize: pageSize,
            total: total,
            hasMore: (page * pageSize) < total,
          );
        }
      }
      throw Exception('获取任务列表失败: ${response.statusCode}');
    } catch (e) {
      print('获取任务失败: $e');
      return PaginatedResponse(
        data: [],
        page: page,
        pageSize: pageSize,
        total: 0,
        hasMore: false,
      );
    }
  }

  /// 获取任务详情
  Future<ApiTaskData?> getTaskDetail(int taskId) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          return ApiTaskData.fromJson(json['data']);
        }
      }
      return null;
    } catch (e) {
      print('获取任务详情失败: $e');
      return null;
    }
  }

  /// 领取任务（返回ApiResult）
  Future<ApiResult> claimTask(int taskId) async {
    try {
      final uri =
      Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/claim');
      final response = await _client
          .post(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      return ApiResult.fromResponse(response);
    } catch (e) {
      print('领取任务失败: $e');
      return ApiResult(success: false, errorMessage: '网络异常: $e');
    }
  }

  /// 完工报工（返回ApiResult）
  Future<ApiResult> submitReport({
    required int taskId,
    required double completedQty,
    required double qualifiedQty,
    required double workWasteQty,
    required double materialWasteQty,
    required double repairQty,
    required double lossQty,
    required double workHours,
    List<String>? photos,
  }) async {
    try {
      final uri =
      Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/report');
      final response = await _client
          .post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'completed_qty': completedQty,
          'qualified_qty': qualifiedQty,
          'work_waste_qty': workWasteQty,
          'material_waste_qty': materialWasteQty,
          'repair_qty': repairQty,
          'loss_qty': lossQty,
          'work_hours': workHours,
          if (photos != null && photos.isNotEmpty) 'photos': photos,
        }),
      )
          .timeout(const Duration(seconds: 10));

      return ApiResult.fromResponse(response);
    } catch (e) {
      print('完工报工失败: $e');
      return ApiResult(success: false, errorMessage: '网络异常: $e');
    }
  }

  /// 批量报工（合并提报）
  /// items: [{task_id, completed_qty, qualified_qty, work_waste_qty, material_waste_qty, repair_qty, loss_qty, work_hours}]
  /// 返回: {code: 200/206/400, message, data: [{task_id, success, message}]}
  Future<Map<String, dynamic>> batchReport(List<Map<String, dynamic>> items) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/batch-report');
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode({'items': items}))
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body);
      return json;
    } catch (e) {
      print('批量报工失败: $e');
      return {'code': 500, 'message': '网络异常: $e', 'data': []};
    }
  }

  /// 槽道合并批次报工（工人只填一个总完成数量）
  /// 返回: {code: 200, message, data: {message, batch_id}}
  Future<Map<String, dynamic>> channelBatchReport({
    required List<int> taskIds,
    required double totalCompletedQty,
    String? remark,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/channel-batch-report');
      final response = await _client
          .post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'task_ids': taskIds,
          'total_completed_qty': totalCompletedQty,
          if (remark != null && remark.isNotEmpty) 'remark': remark,
        }),
      )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      print('槽道批次报工失败: $e');
      return {'code': 500, 'message': '网络异常: $e', 'data': null};
    }
  }

  /// 质检批量质检（对整批填总工废/总料废，通过或驳回）
  Future<Map<String, dynamic>> batchInspect({
    String? batchId,
    List<int>? taskIds,
    double? totalWorkWasteQty,
    double? totalMaterialWasteQty,
    required bool pass,
    String? qcOpinion,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/batch-inspect');
      final response = await _client
          .post(
        uri,
        headers: _headers,
        body: jsonEncode({
          if (batchId != null && batchId.isNotEmpty) 'batch_id': batchId,
          if (taskIds != null && taskIds.isNotEmpty) 'task_ids': taskIds,
          if (totalWorkWasteQty != null) 'total_work_waste_qty': totalWorkWasteQty,
          if (totalMaterialWasteQty != null) 'total_material_waste_qty': totalMaterialWasteQty,
          'pass': pass,
          if (qcOpinion != null && qcOpinion.isNotEmpty) 'qc_opinion': qcOpinion,
        }),
      )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      print('批量质检失败: $e');
      return {'code': 500, 'message': '网络异常: $e', 'data': null};
    }
  }

  /// 班长获取待审批批次汇总与卡片明细
  Future<BatchApprovalDetail?> getBatchApprovalDetail({
    String? batchId,
    List<int>? taskIds,
  }) async {
    try {
      final queryParams = <String, String>{
        if (batchId != null && batchId.isNotEmpty) 'batch_id': batchId,
        if (taskIds != null && taskIds.isNotEmpty) 'task_ids': taskIds.join(','),
      };
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/batch-approval-detail')
          .replace(queryParameters: queryParams);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['data'] != null) {
          return BatchApprovalDetail.fromJson(json['data']);
        }
      }
      return null;
    } catch (e) {
      print('获取批次审批详情失败: $e');
      return null;
    }
  }

  /// 班长终审拆分分配与推送金蝶
  /// 返回: {code: 200/206, message, data: {success_count, failed_count, failed_task_ids, failed_tasks}}
  Future<Map<String, dynamic>> leaderBatchApprove({
    required bool pass,
    String? note,
    required List<LeaderBatchApproveItem> items,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/leader-batch-approve');
      final response = await _client
          .post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'pass': pass,
          if (note != null && note.isNotEmpty) 'note': note,
          'items': items.map((e) => e.toJson()).toList(),
        }),
      )
          .timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      print('班长批次审批失败: $e');
      return {'code': 500, 'message': '网络异常: $e', 'data': null};
    }
  }

  /// 质检审核（返回ApiResult）
  Future<ApiResult> submitQcReview({
    required int taskId,
    required bool pass,
    double? qcQualifiedQty,
    double? qcWorkWasteQty,
    double? qcMaterialWasteQty,
    String? qcOpinion,
  }) async {
    try {
      final uri =
      Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/inspect');
      final response = await _client
          .post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'pass': pass,
          if (qcQualifiedQty != null) 'qc_qualified_qty': qcQualifiedQty,
          if (qcWorkWasteQty != null) 'work_waste_qty': qcWorkWasteQty,
          if (qcMaterialWasteQty != null) 'material_waste_qty': qcMaterialWasteQty,
          if (qcOpinion != null && qcOpinion.isNotEmpty)
            'qc_opinion': qcOpinion,
        }),
      )
          .timeout(const Duration(seconds: 10));

      return ApiResult.fromResponse(response);
    } catch (e) {
      print('质检审核失败: $e');
      return ApiResult(success: false, errorMessage: '网络异常: $e');
    }
  }

  /// 班长审批（返回ApiResult）
  /// qualifiedQty/workWasteQty/materialWasteQty 为班长决定的最终数量，
  /// 不传则沿用工人提报和质检的结果
  Future<ApiResult> submitLeaderApproval({
    required int taskId,
    required bool pass,
    String? note,
    double? qualifiedQty,
    double? workWasteQty,
    double? materialWasteQty,
  }) async {
    try {
      final uri =
      Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/approve');
      final response = await _client
          .post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'pass': pass,
          if (note != null && note.isNotEmpty) 'note': note,
          if (qualifiedQty != null) 'qualified_qty': qualifiedQty,
          if (workWasteQty != null) 'work_waste_qty': workWasteQty,
          if (materialWasteQty != null) 'material_waste_qty': materialWasteQty,
        }),
      )
          .timeout(const Duration(seconds: 10));

      return ApiResult.fromResponse(response);
    } catch (e) {
      print('班长审批失败: $e');
      return ApiResult(success: false, errorMessage: '网络异常: $e');
    }
  }

  // ==================== 计划外工作接口 ====================

  /// 获取计划外工作列表（使用task接口，taskType=2）
  Future<PaginatedResponse<ExtraWorkData>> getExtraWorkList({
    int page = 1,
    int pageSize = 10,
    FilterCriteria? filter,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'task_type': '2', // 计划外任务
      };

      if (filter != null) {
        if (filter.status != null)
          queryParams['status'] = filter.status.toString();
        if (filter.workerId != null)
          queryParams['worker_id'] = filter.workerId.toString();
        if (filter.startTime != null)
          queryParams['start_time'] = filter.startTime!;
        if (filter.endTime != null) queryParams['end_time'] = filter.endTime!;
        if (filter.teamId != null)
          queryParams['team_id'] = filter.teamId.toString();
      }

      // 默认筛选三天内任务（未手动指定时间范围时）
      if (!queryParams.containsKey('start_time')) {
        final now = DateTime.now();
        final threeDaysAgo = now.subtract(const Duration(days: 3));
        String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        queryParams['start_time'] = '${fmt(threeDaysAgo)} 00:00:00';
        queryParams['end_time'] = '${fmt(now)} 23:59:59';
      }

      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks')
          .replace(queryParameters: queryParams);
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          final data = json['data'];
          final List<dynamic> dataList = data['data'] ?? [];
          final works =
          dataList.map((e) => ExtraWorkData.fromListJson(e)).toList();
          final total = data['total'] ?? works.length;

          return PaginatedResponse(
            data: works,
            page: page,
            pageSize: pageSize,
            total: total,
            hasMore: (page * pageSize) < total,
          );
        }
      }
      throw Exception('获取计划外工作列表失败');
    } catch (e) {
      print('获取计划外工作失败: $e');
      return PaginatedResponse(
        data: [],
        page: page,
        pageSize: pageSize,
        total: 0,
        hasMore: false,
      );
    }
  }

  /// 获取计划外工作详情
  Future<ExtraWorkData?> getExtraWorkDetail(int id) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/$id');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          return ExtraWorkData.fromJson(json['data']);
        }
      }
      return null;
    } catch (e) {
      print('获取计划外工作详情失败: $e');
      return null;
    }
  }

  // ==================== 工具方法 ====================

  /// 测试服务器连接
  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response =
      await _client.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}