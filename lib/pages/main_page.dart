import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/widgets.dart';
import 'pages.dart';

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
  // 生产任务和历史记录使用独立筛选
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
    if (_selectedIndex == 1) return _taskFilter;
    if (_selectedIndex == 3) return _historyFilter;
    return FilterCriteria();
  }

  void _onFilterChanged(FilterCriteria filter) {
    setState(() {
      if (_selectedIndex == 1) {
        _taskFilter = filter;
      } else if (_selectedIndex == 3) {
        _historyFilter = filter;
      }
    });
  }

  void _clearCurrentFilter() {
    setState(() {
      if (_selectedIndex == 1) {
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
            Text('v0.9.18', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
        actions: [
          if (_selectedIndex == 1 || _selectedIndex == 3)
            FilterButton(hasFilter: _currentFilter.hasFilter, onPressed: _showFilterDialog),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: '退出登录'),
        ],
      ),
      body: Column(
        children: [
          if (_currentFilter.hasFilter && (_selectedIndex == 1 || _selectedIndex == 3))
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
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '任务清单'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: '生产任务'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: '其他任务'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '历史记录'),
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
  int _currentPage = 1;

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

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });

    final response = await _apiService.getTaskList(page: 1, pageSize: 50, filter: _buildFilter());

    setState(() {
      _tasks = response.data;
      _groupTasksByWorker();
      _hasMore = response.hasMore;
      _isLoading = false;
    });
  }

  Future<void> _refreshTasks() async {
    _currentPage = 1;
    final response = await _apiService.getTaskList(page: 1, pageSize: 50, filter: _buildFilter());

    if (mounted) {
      setState(() {
        _tasks = response.data;
        _groupTasksByWorker();
        _hasMore = response.hasMore;
      });
    }
  }

  Future<void> _loadMoreTasks() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final response = await _apiService.getTaskList(page: _currentPage + 1, pageSize: 50, filter: _buildFilter());

    setState(() {
      _tasks.addAll(response.data);
      _groupTasksByWorker();
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

    // 构建分组列表，班长自己的任务置顶
    final List<Widget> items = [];
    final workerNames = _getSortedWorkerNames();

    for (int i = 0; i < workerNames.length; i++) {
      final workerName = workerNames[i];
      final tasks = _groupedTasks[workerName]!;
      final bool isMe = _isLeader && workerName == widget.userInfo.realName;

      items.add(_buildGroupHeader(workerName, tasks.length, isMe: isMe));

      for (final task in tasks) {
        items.add(TaskCard(task: task, onTap: () => _navigateToDetail(task)));
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
        padding: const EdgeInsets.all(16),
        children: items,
      ),
    );
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