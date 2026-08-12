import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/widgets.dart';
import 'pages.dart';

const String kAppVersion = 'v1.0.3';

class MainPage extends StatefulWidget {
  final UserInfo userInfo;

  const MainPage({
    super.key,
    required this.userInfo,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  // 槽道任务、生产任务和历史记录使用独立筛选
  FilterCriteria _channelFilter = FilterCriteria();
  FilterCriteria _taskFilter = FilterCriteria();
  FilterCriteria _historyFilter = FilterCriteria();
  Timer? _refreshTimer;

  final GlobalKey<_TaskListViewState> _taskListKey = GlobalKey();
  final GlobalKey<_ExtraWorkListViewState> _extraWorkKey = GlobalKey();
  final GlobalKey<_HistoryListViewState> _historyKey = GlobalKey();
  final GlobalKey<ProcessMergeViewState> _processMergeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshCurrentTab();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        _processMergeKey.currentState?.refreshData();
        break;
      case 1:
        _taskListKey.currentState?._refreshTasks();
        break;
      case 2:
        _extraWorkKey.currentState?._refreshWorks();
        break;
      case 3:
        _historyKey.currentState?._refreshTasks();
        break;
    }
  }

  /// 获取当前页签对应的筛选
  FilterCriteria get _currentFilter {
    if (_selectedIndex == 0) return _channelFilter;
    if (_selectedIndex == 1) return _taskFilter;
    if (_selectedIndex == 3) return _historyFilter;
    return FilterCriteria();
  }

  void _onFilterChanged(FilterCriteria filter) {
    setState(() {
      if (_selectedIndex == 0) {
        _channelFilter = filter;
      } else if (_selectedIndex == 1) {
        _taskFilter = filter;
      } else if (_selectedIndex == 3) {
        _historyFilter = filter;
      }
    });
  }

  void _clearCurrentFilter() {
    setState(() {
      if (_selectedIndex == 0) {
        _channelFilter = FilterCriteria();
      } else if (_selectedIndex == 1) {
        _taskFilter = FilterCriteria();
      } else if (_selectedIndex == 3) {
        _historyFilter = FilterCriteria();
      }
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterDialog(
        initialFilter: _currentFilter,
        onApply: _onFilterChanged,
      ),
    );
  }

  /// 切换页签时自动刷新
  void _onTabChanged(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    // 延迟一帧确保State已切换，再刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCurrentTab();
    });
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateService.checkForUpdate(kAppVersion);
    if (info != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: !info.forceUpdate,
        builder: (_) => UpdateDialog(info: info),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('退出', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearAuth();
      await ApiService().logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.userInfo.realName),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.userInfo.userRole.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.userInfo.userRole.text,
                style: TextStyle(fontSize: 11, color: widget.userInfo.userRole.color),
              ),
            ),
            const Spacer(),
            Text(kAppVersion, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
        actions: [
          if (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 3)
            FilterButton(hasFilter: _currentFilter.hasFilter, onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: '退出登录'),
        ],
      ),
      body: Column(
        children: [
          if (_currentFilter.hasFilter && (_selectedIndex == 0 || _selectedIndex == 1 || _selectedIndex == 3))
            ActiveFiltersBar(
              filter: _currentFilter,
              onClear: _clearCurrentFilter,
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ProcessMergeView(
                  key: _processMergeKey,
                  userInfo: widget.userInfo,
                  filter: _channelFilter,
                ),
                TaskListView(
                  key: _taskListKey,
                  userInfo: widget.userInfo,
                  filter: _taskFilter,
                ),
                ExtraWorkListView(
                  key: _extraWorkKey,
                  userInfo: widget.userInfo,
                ),
                HistoryListView(
                  key: _historyKey,
                  userInfo: widget.userInfo,
                  filter: _historyFilter,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '槽道任务'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: '锚栓/C型钢'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: '其他任务'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '历史记录'),
        ],
      ),
    );
  }
}

// ==================== 自动更新对话框 ====================

enum _UpdatePhase { idle, downloading, done, failed }

class UpdateDialog extends StatefulWidget {
  final AppVersionInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  double _progress = 0;
  String? _apkPath;
  bool _cancelled = false;

  Future<void> _startDownload() async {
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
      _cancelled = false;
    });

    final path = await UpdateService.downloadApk(
      version: widget.info.version,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      isCancelled: () => _cancelled,
    );

    if (!mounted) return;
    if (path != null) {
      setState(() {
        _phase = _UpdatePhase.done;
        _apkPath = path;
      });
    } else if (!_cancelled) {
      setState(() => _phase = _UpdatePhase.failed);
    }
  }

  void _cancel() {
    _cancelled = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final force = widget.info.forceUpdate;
    return PopScope(
      canPop: !force && _phase != _UpdatePhase.downloading,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('发现新版本 ${widget.info.version}', style: const TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.info.releaseNote.isNotEmpty) ...[
              const Text('更新内容', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(widget.info.releaseNote, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],
            if (_phase == _UpdatePhase.downloading) ...[
              Row(
                children: [
                  const Text('正在下载...', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text('${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: _progress, minHeight: 6,
                  borderRadius: BorderRadius.circular(3)),
            ],
            if (_phase == _UpdatePhase.failed)
              const Text('下载失败，请检查网络后重试', style: TextStyle(color: Colors.red, fontSize: 13)),
            if (force)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('此版本为强制更新，请完成更新后继续使用',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
          ],
        ),
        actions: [
          if (!force && _phase == _UpdatePhase.idle)
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('稍后再说')),
          if (_phase == _UpdatePhase.idle || _phase == _UpdatePhase.failed)
            ElevatedButton(onPressed: _startDownload, child: const Text('立即更新')),
          if (_phase == _UpdatePhase.downloading && !force)
            TextButton(onPressed: _cancel, child: const Text('取消')),
          if (_phase == _UpdatePhase.done)
            ElevatedButton(
              onPressed: () async {
                if (_apkPath != null) await UpdateService.installApk(_apkPath!);
              },
              child: const Text('立即安装'),
            ),
        ],
      ),
    );
  }
}

// ==================== 生产任务列表视图（按执行人分组，班长自己置顶） ====================
class TaskListView extends StatefulWidget {
  final UserInfo userInfo;
  final FilterCriteria filter;

  const TaskListView({
    super.key,
    required this.userInfo,
    required this.filter,
  });

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<ApiTaskData> _tasks = [];
  Map<String, List<ApiTaskData>> _groupedTasks = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // 锚栓、C型钢两个product_type分别独立分页，任一还有更多即视为整体hasMore
  int _anchorPage = 1;
  int _csteelPage = 1;
  bool _anchorHasMore = true;
  bool _csteelHasMore = true;

  bool get _isLeader => widget.userInfo.userRole == UserRole.leader;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TaskListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _refreshTasks();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTasks();
    }
  }

  FilterCriteria _buildFilter() {
    FilterCriteria filter = widget.filter;
    if (widget.userInfo.userRole == UserRole.worker) {
      filter = filter.copyWith(workerId: widget.userInfo.id);
    }
    // 日期筛选由 api_service 默认处理（三天内）
    return filter;
  }

  void _groupTasksByWorker() {
    _groupedTasks.clear();
    for (final task in _tasks) {
      final workerName = task.workerName.isEmpty ? '未分配' : task.workerName;
      _groupedTasks.putIfAbsent(workerName, () => []).add(task);
    }
  }

  /// 获取排序后的worker名称列表，班长自己的置顶
  List<String> _getSortedWorkerNames() {
    final workerNames = _groupedTasks.keys.toList();
    if (_isLeader) {
      final leaderName = widget.userInfo.realName;
      workerNames.sort((a, b) {
        if (a == leaderName) return -1;
        if (b == leaderName) return 1;
        return a.compareTo(b);
      });
    }
    return workerNames;
  }

  /// 首次加载/刷新：锚栓、C型钢各取第1页并合并
  Future<PaginatedResponse<ApiTaskData>> _fetchAnchor(int page) => _apiService.getTaskList(
    page: page, pageSize: 50, productType: 'anchor', filter: _buildFilter(),
  );

  Future<PaginatedResponse<ApiTaskData>> _fetchCsteel(int page) => _apiService.getTaskList(
    page: page, pageSize: 50, productType: 'csteel', filter: _buildFilter(),
  );

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _anchorPage = 1;
      _csteelPage = 1;
      _anchorHasMore = true;
      _csteelHasMore = true;
    });

    final results = await Future.wait([_fetchAnchor(1), _fetchCsteel(1)]);
    final anchorResp = results[0];
    final csteelResp = results[1];

    setState(() {
      _tasks = [...anchorResp.data, ...csteelResp.data];
      _groupTasksByWorker();
      _anchorHasMore = anchorResp.hasMore;
      _csteelHasMore = csteelResp.hasMore;
      _hasMore = _anchorHasMore || _csteelHasMore;
      _isLoading = false;
    });
  }

  Future<void> _refreshTasks() async {
    final results = await Future.wait([_fetchAnchor(1), _fetchCsteel(1)]);
    final anchorResp = results[0];
    final csteelResp = results[1];

    if (mounted) {
      setState(() {
        _anchorPage = 1;
        _csteelPage = 1;
        _tasks = [...anchorResp.data, ...csteelResp.data];
        _groupTasksByWorker();
        _anchorHasMore = anchorResp.hasMore;
        _csteelHasMore = csteelResp.hasMore;
        _hasMore = _anchorHasMore || _csteelHasMore;
      });
    }
  }

  Future<void> _loadMoreTasks() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final anchorFuture = _anchorHasMore ? _fetchAnchor(_anchorPage + 1) : null;
    final csteelFuture = _csteelHasMore ? _fetchCsteel(_csteelPage + 1) : null;
    final anchorResp = anchorFuture != null ? await anchorFuture : null;
    final csteelResp = csteelFuture != null ? await csteelFuture : null;

    setState(() {
      if (anchorResp != null) {
        _tasks.addAll(anchorResp.data);
        _anchorPage++;
        _anchorHasMore = anchorResp.hasMore;
      }
      if (csteelResp != null) {
        _tasks.addAll(csteelResp.data);
        _csteelPage++;
        _csteelHasMore = csteelResp.hasMore;
      }
      _groupTasksByWorker();
      _hasMore = _anchorHasMore || _csteelHasMore;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return _buildEmptyView();
    }

    // 构建分组列表，班长自己的任务置顶
    final List<Widget> items = [];
    final workerNames = _getSortedWorkerNames();

    for (int i = 0; i < workerNames.length; i++) {
      final workerName = workerNames[i];
      final tasks = _groupedTasks[workerName]!;
      final bool isMe = _isLeader && workerName == widget.userInfo.realName;

      items.add(_buildGroupHeader(workerName, tasks.length, isMe: isMe));

      for (final task in tasks) {
        items.add(_buildTaskCard(task));
      }
    }

    if (_hasMore) {
      items.add(const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
    }

    return RefreshIndicator(
      onRefresh: _refreshTasks,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        children: items,
      ),
    );
  }

  /// 按角色和任务状态决定卡片上可用的内联操作
  /// 工人/质检：卡片上直接领取/报工/质检，不再跳转详情页
  /// 班长：保留点击进入详情
  Widget _buildTaskCard(ApiTaskData task) {
    final UserRole role = widget.userInfo.userRole;
    final bool isMine = task.workerId == widget.userInfo.id;
    // 班长对自己的任务同样可以走工人流程
    final bool canActAsWorker =
        role == UserRole.worker || (role == UserRole.leader && isMine);

    return TaskCard(
      task: task,
      onTap: role == UserRole.leader ? () => _navigateToDetail(task) : null,
      onClaim: canActAsWorker && task.status == ApiTaskStatus.assigned
          ? () => _claimTask(task)
          : null,
      onReport: canActAsWorker && _isReportable(task.status)
          ? () => _showReportDialog(task)
          : null,
      onQc: role == UserRole.inspector && task.status == ApiTaskStatus.pendingQc
          ? () => _showQcDialog(task)
          : null,
      onApprove: role == UserRole.leader && task.status.canLeaderOperate
          ? () => _showApproveDialog(task)
          : null,
    );
  }

  /// 可报工状态：已领取、班长发回、质检发回
  bool _isReportable(ApiTaskStatus status) =>
      status == ApiTaskStatus.claimed ||
          status == ApiTaskStatus.leaderReject ||
          status == ApiTaskStatus.qcReject;

  /// 自动计算实际工时（提报时间 - 领取时间，12点前领取且13点后报工扣除1小时午休）
  double _calcWorkHours(DateTime? claimTime) {
    if (claimTime == null) return 0;
    final now = DateTime.now();
    double hours = now.difference(claimTime).inMinutes / 60.0;
    if (claimTime.hour < 12 && now.hour >= 13) hours -= 1.0;
    if (hours < 0) hours = 0;
    return double.parse(hours.toStringAsFixed(1));
  }

  /// 两位小数截断，不四舍五入
  double _truncate2(double qty) => (qty * 100 + 1e-9).truncateToDouble() / 100;

  Future<void> _claimTask(ApiTaskData task) async {
    final result = await _apiService.claimTask(task.id);
    if (!mounted) return;
    if (result.success) {
      AppToast.success(context, '领取成功');
    } else {
      AppToast.error(context, result.errorMessage ?? '领取失败');
    }
    _refreshTasks();
  }

  /// 报工：只填完成数量（与槽道保持一致，废品由质检填报）
  void _showReportDialog(ApiTaskData task) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('报工', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.specModel.isNotEmpty ? task.specModel : task.productName,
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            Text('计划数量: ${task.assignedQty} ${task.unit}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '完成数量',
                suffixText: task.unit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(controller.text) ?? 0;
              if (qty < 0) {
                AppToast.error(context, '请输入完成数量');
                return;
              }
              Navigator.pop(ctx);
              _submitReport(task, qty);
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(ApiTaskData task, double completedQty) async {
    final double qty = _truncate2(completedQty);
    final result = await _apiService.submitReport(
      taskId: task.id,
      completedQty: qty,
      // 工人只报完成数量：废品由质检填报、合格数量由班长最终决定，
      // 接口必填的其余数量一律传0
      qualifiedQty: 0,
      workWasteQty: 0,
      materialWasteQty: 0,
      repairQty: 0,
      lossQty: 0,
      // 工时由领取时间自动算出，不需要工人填写
      workHours: _calcWorkHours(task.claimTime),
    );
    if (!mounted) return;
    if (result.success) {
      AppToast.success(context, '报工成功');
    } else {
      AppToast.error(context, result.errorMessage ?? '报工失败');
    }
    _refreshTasks();
  }

  /// 质检：只填工废/料废数量，合格数量由班长审批时最终决定
  /// 不提供驳回（接口的 pass 参数保留，这里固定传 true）
  void _showQcDialog(ApiTaskData task) {
    final workWasteCtrl = TextEditingController();
    final materialWasteCtrl = TextEditingController();
    final opinionCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('质检', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.specModel.isNotEmpty ? task.specModel : task.productName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text('工人提报完成数量: ${task.completedQty} ${task.unit}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: workWasteCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '工废数量',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: materialWasteCtrl,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '料废数量',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
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
        actions: buildDialogActionRow([
          buildDialogButton(
            onPressed: () => Navigator.pop(ctx),
            label: '取消',
          ),
          buildDialogButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitQc(task, workWasteCtrl.text, materialWasteCtrl.text,
                  opinionCtrl.text);
            },
            label: '提交质检',
            filled: true,
          ),
        ]),
      ),
    );
  }

  Future<void> _submitQc(ApiTaskData task, String workWasteText,
      String materialWasteText, String opinion) async {
    final double workWaste = _truncate2(double.tryParse(workWasteText) ?? 0);
    final double materialWaste =
    _truncate2(double.tryParse(materialWasteText) ?? 0);

    if (workWaste + materialWaste > task.completedQty) {
      AppToast.error(context, '工废+料废超过完成数量，请重新填写');
      return;
    }

    // 质检只提交废品数量，合格数量留给班长审批时决定
    final result = await _apiService.submitQcReview(
      taskId: task.id,
      pass: true,
      qcWorkWasteQty: workWaste,
      qcMaterialWasteQty: materialWaste,
      qcOpinion: opinion,
    );
    if (!mounted) return;
    if (result.success) {
      AppToast.success(context, '质检提交成功');
    } else {
      AppToast.error(context, result.errorMessage ?? '提交失败');
    }
    _refreshTasks();
  }

  /// 班长审批：可改写最终的合格/工废/料废数量后提交
  /// 不提供驳回（接口的 pass 参数保留，这里固定传 true）
  void _showApproveDialog(ApiTaskData task) {
    final noteCtrl = TextEditingController();
    // 预填质检结果，班长可直接改写
    final double defaultWorkWaste = task.workWasteQty;
    final double defaultMaterialWaste = task.materialWasteQty;
    final double defaultQualified =
    _truncate2(task.completedQty - defaultWorkWaste - defaultMaterialWaste);

    final qualifiedCtrl =
    TextEditingController(text: _fmtQty(defaultQualified < 0 ? 0 : defaultQualified));
    final workWasteCtrl = TextEditingController(text: _fmtQty(defaultWorkWaste));
    final materialWasteCtrl = TextEditingController(text: _fmtQty(defaultMaterialWaste));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('审批', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.specModel.isNotEmpty ? task.specModel : task.productName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text('工人提报完成数量: ${_fmtQty(task.completedQty)} ${task.unit}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // 班长可改写最终数量
              Row(
                children: [
                  _buildQtyField('合格', qualifiedCtrl),
                  const SizedBox(width: 6),
                  _buildQtyField('工废', workWasteCtrl),
                  const SizedBox(width: 6),
                  _buildQtyField('料废', materialWasteCtrl),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '审批意见',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: buildDialogActionRow([
          buildDialogButton(
            onPressed: () => Navigator.pop(ctx),
            label: '取消',
          ),
          buildDialogButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitApproval(task, noteCtrl.text, qualifiedCtrl.text,
                  workWasteCtrl.text, materialWasteCtrl.text);
            },
            label: '同意提报',
            filled: true,
          ),
        ]),
      ),
    );
  }

  /// 数量输入框（对话框内三列并排）
  Widget _buildQtyField(String label, TextEditingController ctrl) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ),
      ),
    );
  }

  /// 去掉浮点尾数（500 而不是 500.0）
  String _fmtQty(double v) => formatQtyNum(v).toString();

  Future<void> _submitApproval(ApiTaskData task, String note, String qualifiedText,
      String workWasteText, String materialWasteText) async {
    final double qualified = _truncate2(double.tryParse(qualifiedText) ?? 0);
    final double workWaste = _truncate2(double.tryParse(workWasteText) ?? 0);
    final double materialWaste = _truncate2(double.tryParse(materialWasteText) ?? 0);

    if (qualified + workWaste + materialWaste > task.completedQty) {
      AppToast.error(context, '合格+工废+料废超过完成数量，请重新填写');
      return;
    }

    final result = await _apiService.submitLeaderApproval(
      taskId: task.id,
      pass: true,
      note: note,
      qualifiedQty: qualified,
      workWasteQty: workWaste,
      materialWasteQty: materialWaste,
    );
    if (!mounted) return;
    if (result.success) {
      AppToast.success(context, '审批通过');
    } else {
      AppToast.error(context, result.errorMessage ?? '审批失败');
    }
    _refreshTasks();
  }

  Widget _buildGroupHeader(String workerName, int count, {bool isMe = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
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
          Text(isMe ? '$workerName（我）' : workerName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isMe ? Colors.orange.shade800 : null,
              )),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _refreshTasks,
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
                  Text('暂无任务', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _refreshTasks, icon: const Icon(Icons.refresh), label: const Text('刷新')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetail(ApiTaskData task) async {
    final detail = await _apiService.getTaskDetail(task.id);

    if (detail != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OrderDetailPage(task: detail, userInfo: widget.userInfo)),
      );

      if (result == true) {
        _refreshTasks();
      }
    } else if (mounted) {
      AppToast.error(context, '获取任务详情失败');
    }
  }
}

// ==================== 计划外工作列表视图 ====================
class ExtraWorkListView extends StatefulWidget {
  final UserInfo userInfo;

  const ExtraWorkListView({
    super.key,
    required this.userInfo,
  });

  @override
  State<ExtraWorkListView> createState() => _ExtraWorkListViewState();
}

class _ExtraWorkListViewState extends State<ExtraWorkListView> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<ExtraWorkData> _works = [];
  Map<String, List<ExtraWorkData>> _groupedWorks = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWorks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreWorks();
    }
  }

  void _groupWorksByWorker() {
    _groupedWorks.clear();
    for (final work in _works) {
      final workerName = work.workerName.isEmpty ? '未分配' : work.workerName;
      _groupedWorks.putIfAbsent(workerName, () => []).add(work);
    }
  }

  Future<void> _loadWorks() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final response = await _apiService.getExtraWorkList(page: 1, pageSize: 50);

    setState(() {
      _works = response.data;
      _groupWorksByWorker();
      _hasMore = response.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _refreshWorks() async {
    _currentPage = 1;
    final response = await _apiService.getExtraWorkList(page: 1, pageSize: 50);

    if (mounted) {
      setState(() {
        _works = response.data;
        _groupWorksByWorker();
        _hasMore = response.hasMore;
      });
    }
  }

  Future<void> _loadMoreWorks() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final response = await _apiService.getExtraWorkList(page: _currentPage + 1, pageSize: 50);

    setState(() {
      _works.addAll(response.data);
      _groupWorksByWorker();
      _currentPage++;
      _hasMore = response.hasMore;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_works.isEmpty) {
      return _buildEmptyView();
    }

    final List<Widget> items = [];
    final workerNames = _groupedWorks.keys.toList();

    for (int i = 0; i < workerNames.length; i++) {
      final workerName = workerNames[i];
      final works = _groupedWorks[workerName]!;

      items.add(_buildGroupHeader(workerName, works.length));

      for (final work in works) {
        items.add(ExtraWorkCard(work: work, onTap: () => _navigateToDetail(work)));
      }
    }

    if (_hasMore) {
      items.add(const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
    }

    return RefreshIndicator(
      onRefresh: _refreshWorks,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: items,
      ),
    );
  }

  Widget _buildGroupHeader(String workerName, int count) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 18, color: Colors.purple),
          const SizedBox(width: 8),
          Text(workerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _refreshWorks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无计划外工作', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _refreshWorks, icon: const Icon(Icons.refresh), label: const Text('刷新')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetail(ExtraWorkData work) async {
    final detail = await _apiService.getExtraWorkDetail(work.id);

    if (detail != null && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ExtraWorkDetailPage(work: detail, userInfo: widget.userInfo)),
      );

      if (result == true) {
        _refreshWorks();
      }
    } else if (mounted) {
      AppToast.error(context, '获取详情失败');
    }
  }
}

// ==================== 历史记录视图 ====================
class HistoryListView extends StatefulWidget {
  final UserInfo userInfo;
  final FilterCriteria filter;

  const HistoryListView({
    super.key,
    required this.userInfo,
    required this.filter,
  });

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _HistoryListViewState extends State<HistoryListView> with AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<ApiTaskData> _tasks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HistoryListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _refreshTasks();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTasks();
    }
  }

  FilterCriteria _buildFilter() {
    FilterCriteria filter = widget.filter.copyWith(status: ApiTaskStatus.completed.code);
    if (widget.userInfo.userRole == UserRole.worker) {
      filter = filter.copyWith(workerId: widget.userInfo.id);
    }
    return filter;
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final response = await _apiService.getTaskList(page: 1, pageSize: 10, filter: _buildFilter());

    setState(() {
      _tasks = response.data;
      _hasMore = response.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _refreshTasks() async {
    _currentPage = 1;
    final response = await _apiService.getTaskList(page: 1, pageSize: 10, filter: _buildFilter());

    if (mounted) {
      setState(() {
        _tasks = response.data;
        _hasMore = response.hasMore;
      });
    }
  }

  Future<void> _loadMoreTasks() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final response = await _apiService.getTaskList(page: _currentPage + 1, pageSize: 10, filter: _buildFilter());

    setState(() {
      _tasks.addAll(response.data);
      _currentPage++;
      _hasMore = response.hasMore;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _refreshTasks,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _tasks.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final task = _tasks[index];
          return TaskCard(task: task, onTap: () => _navigateToDetail(task));
        },
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _refreshTasks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('暂无历史记录', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _refreshTasks, icon: const Icon(Icons.refresh), label: const Text('刷新')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDetail(ApiTaskData task) async {
    final detail = await _apiService.getTaskDetail(task.id);

    if (detail != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => OrderCompletePage(task: detail, userInfo: widget.userInfo)),
      );
    }
  }
}