import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class ApiService {
  // ==================== 服务器配置 ====================
  static String _serverIp = '61.181.91.2';
  static int _serverPort = 1680;
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
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));
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
      await _client.post(uri, headers: _headers).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('登出请求失败: $e');
    } finally {
      clearAuth();
    }
  }

  // ==================== 生产任务接口 ====================

  /// 获取任务列表
  Future<PaginatedResponse<ApiTaskData>> getTaskList({
    int page = 1,
    int pageSize = 10,
    int taskType = 1,
    FilterCriteria? filter,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'task_type': taskType.toString(),
      };

      if (filter != null) {
        if (filter.orderNo != null) queryParams['order_no'] = filter.orderNo!;
        if (filter.status != null) queryParams['status'] = filter.status.toString();
        if (filter.workerId != null) queryParams['worker_id'] = filter.workerId.toString();
        if (filter.startTime != null) queryParams['start_time'] = filter.startTime!;
        if (filter.endTime != null) queryParams['end_time'] = filter.endTime!;
        if (filter.teamId != null) queryParams['team_id'] = filter.teamId.toString();
      }

      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          final data = json['data'];
          final List<dynamic> dataList = data['data'] ?? [];
          final tasks = dataList.map((e) => ApiTaskData.fromListJson(e)).toList();
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
      final response = await _client.get(uri, headers: _headers)
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

  /// 领取任务
  Future<bool> claimTask(int taskId) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/claim');
      final response = await _client.post(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['code'] == 200;
      }
      return false;
    } catch (e) {
      print('领取任务失败: $e');
      return false;
    }
  }

  /// 完工报工
  Future<bool> submitReport({
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
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/report');
      final response = await _client.post(
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
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);
      return json['code'] == 200;
    } catch (e) {
      print('完工报工失败: $e');
      return false;
    }
  }

  /// 质检审核
  Future<bool> submitQcReview({
    required int taskId,
    required bool pass,
    double? qcQualifiedQty,
    double? qcWasteQty,
    String? qcOpinion,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/inspect');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'pass': pass,
          if (qcQualifiedQty != null) 'qc_qualified_qty': qcQualifiedQty,
          if (qcWasteQty != null) 'qc_waste_qty': qcWasteQty,
          if (qcOpinion != null && qcOpinion.isNotEmpty) 'qc_opinion': qcOpinion,
        }),
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);
      return json['code'] == 200;
    } catch (e) {
      print('质检审核失败: $e');
      return false;
    }
  }

  /// 班长审批
  Future<bool> submitLeaderApproval({
    required int taskId,
    required bool pass,
    String? note,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks/$taskId/approve');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'pass': pass,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      ).timeout(const Duration(seconds: 10));

      final json = jsonDecode(response.body);
      return json['code'] == 200;
    } catch (e) {
      print('班长审批失败: $e');
      return false;
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
        'task_type': '2',  // 计划外任务
      };

      if (filter != null) {
        if (filter.status != null) queryParams['status'] = filter.status.toString();
        if (filter.workerId != null) queryParams['worker_id'] = filter.workerId.toString();
        if (filter.startTime != null) queryParams['start_time'] = filter.startTime!;
        if (filter.endTime != null) queryParams['end_time'] = filter.endTime!;
        if (filter.teamId != null) queryParams['team_id'] = filter.teamId.toString();
      }

      final uri = Uri.parse('$baseUrl$apiPrefix/production/tasks').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200) {
          final data = json['data'];
          final List<dynamic> dataList = data['data'] ?? [];
          final works = dataList.map((e) => ExtraWorkData.fromListJson(e)).toList();
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
      final response = await _client.get(uri, headers: _headers)
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
      final response = await _client.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}