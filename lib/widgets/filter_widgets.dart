import 'package:flutter/material.dart';
import '../models/task_model.dart';

// ==================== 筛选按钮 ====================
class FilterButton extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onPressed;

  const FilterButton({
    super.key,
    required this.hasFilter,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: onPressed,
          tooltip: '筛选',
        ),
        if (hasFilter)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== 活动筛选条件栏 ====================
class ActiveFiltersBar extends StatelessWidget {
  final FilterCriteria filter;
  final VoidCallback onClear;

  const ActiveFiltersBar({
    super.key,
    required this.filter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filter.orderNo != null) {
      chips.add(_buildChip('订单: ${filter.orderNo}'));
    }
    if (filter.status != null) {
      chips.add(_buildChip('状态: ${ApiTaskStatus.fromCode(filter.status!).text}'));
    }
    if (filter.startTime != null) {
      chips.add(_buildChip('开始: ${filter.startTime}'));
    }
    if (filter.endTime != null) {
      chips.add(_buildChip('结束: ${filter.endTime}'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                '清除',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
      ),
    );
  }
}

// ==================== 筛选对话框 ====================
class FilterDialog extends StatefulWidget {
  final FilterCriteria initialFilter;
  final Function(FilterCriteria) onApply;

  const FilterDialog({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late TextEditingController _orderNoController;
  int? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _orderNoController = TextEditingController(text: widget.initialFilter.orderNo);
    _selectedStatus = widget.initialFilter.status;

    if (widget.initialFilter.startTime != null) {
      _startDate = DateTime.tryParse(widget.initialFilter.startTime!);
    }
    if (widget.initialFilter.endTime != null) {
      _endDate = DateTime.tryParse(widget.initialFilter.endTime!);
    }
  }

  @override
  void dispose() {
    _orderNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '筛选条件',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 订单编号
            const Text('订单编号', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _orderNoController,
              decoration: InputDecoration(
                hintText: '请输入订单编号',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // 任务状态
            const Text('任务状态', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(null, '全部'),
                ...ApiTaskStatus.values.map((status) => _buildStatusChip(status.code, status.text)),
              ],
            ),
            const SizedBox(height: 16),

            // 时间范围
            const Text('时间范围', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateButton('开始日期', _startDate, (date) {
                    setState(() => _startDate = date);
                  }),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至'),
                ),
                Expanded(
                  child: _buildDateButton('结束日期', _endDate, (date) {
                    setState(() => _endDate = date);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _orderNoController.clear();
                        _selectedStatus = null;
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('重置'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final filter = FilterCriteria(
                        orderNo: _orderNoController.text.isEmpty ? null : _orderNoController.text,
                        status: _selectedStatus,
                        startTime: _startDate != null
                            ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')} 00:00:00'
                            : null,
                        endTime: _endDate != null
                            ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')} 23:59:59'
                            : null,
                      );
                      widget.onApply(filter);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int? status, String label) {
    final isSelected = _selectedStatus == status;
    final color = status != null ? ApiTaskStatus.fromCode(status).color : Colors.grey;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatus = status);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? color : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton(String hint, DateTime? date, Function(DateTime?) onSelected) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        onSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade600),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null
                    ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                    : hint,
                style: TextStyle(
                  color: date != null ? Colors.black : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}