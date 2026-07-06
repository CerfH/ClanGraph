import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../controllers/family_controller.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';

class StatsDashboard extends StatefulWidget {
  final FamilyController controller;
  const StatsDashboard({super.key, required this.controller});

  @override
  State<StatsDashboard> createState() => _StatsDashboardState();
}

class _StatsDashboardState extends State<StatsDashboard> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  List<GiftRecord> get _allGifts =>
      widget.controller.allPeople.expand((p) => p.giftHistory).toList();

  List<GiftRecord> get _yearGifts =>
      _allGifts.where((g) => g.date.year == _selectedYear).toList();

  List<int> get _availableYears {
    final years = _allGifts.map((g) => g.date.year).toSet().toList()..sort();
    if (years.isEmpty) years.add(DateTime.now().year);
    return years.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final gifts = _yearGifts;
    final total = gifts.fold<double>(0, (s, g) => s + g.amount);
    final count = gifts.length;
    final avg = count > 0 ? total / count : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.deepSpaceGrey,
      appBar: AppBar(
        title: const Text('数据统计'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _yearSelector(),
        ],
      ),
      body: gifts.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCards(total, count, avg),
                const SizedBox(height: 24),
                _sectionTitle('按事件类型'),
                const SizedBox(height: 12),
                _eventChart(gifts),
                const SizedBox(height: 24),
                _sectionTitle('送礼排行'),
                const SizedBox(height: 12),
                _personChart(gifts),
                const SizedBox(height: 24),
                _sectionTitle('月度趋势'),
                const SizedBox(height: 12),
                _monthlyChart(gifts),
                const SizedBox(height: 24),
                _sectionTitle('最近记录'),
                const SizedBox(height: 12),
                ..._recentRecords(gifts),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ─── Year Selector ─────────────────────────────────────────

  Widget _yearSelector() {
    return PopupMenuButton<int>(
      icon: Text(
        '$_selectedYear ▼',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      color: AppTheme.surfaceGrey,
      onSelected: (year) => setState(() => _selectedYear = year),
      itemBuilder: (_) => _availableYears
          .map((y) => PopupMenuItem<int>(
                value: y,
                child: Text(
                  '$y',
                  style: TextStyle(
                    color: y == _selectedYear ? AppTheme.electricBlue : Colors.white,
                  ),
                ),
              ))
          .toList(),
    );
  }

  // ─── Empty State ────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            '$_selectedYear 年暂无礼金记录',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '添加礼金记录后这里将展示统计图表',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Summary Cards ──────────────────────────────────────────

  Widget _summaryCards(double total, int count, double avg) {
    return Row(
      children: [
        _card('总支出', '¥${total.toInt()}', Icons.payments_outlined),
        const SizedBox(width: 12),
        _card('总笔数', '$count 笔', Icons.receipt_long_outlined),
        const SizedBox(width: 12),
        _card('笔均', '¥${avg.toInt()}', Icons.auto_graph_outlined),
      ],
    );
  }

  Widget _card(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.electricBlue, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ─── Event Type Chart ───────────────────────────────────────

  Widget _eventChart(List<GiftRecord> gifts) {
    final byEvent = <String, double>{};
    for (final g in gifts) {
      byEvent[g.event] = (byEvent[g.event] ?? 0) + g.amount;
    }
    final entries = byEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: entries.length * 44.0,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          barGroups: entries.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  color: AppTheme.electricBlue,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 70,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: [
                        Text(entries[i].key,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                        Text('¥${entries[i].value.toInt()}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: entries.isEmpty ? 100 : entries.first.value * 1.3,
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ─── Person Chart ───────────────────────────────────────────

  Widget _personChart(List<GiftRecord> gifts) {
    final byPerson = <String, double>{};
    for (final g in gifts) {
      // Find which person this gift belongs to
      final person =
          widget.controller.allPeople.where((p) => p.giftHistory.contains(g)).firstOrNull;
      final label = person?.name ?? '未知';
      byPerson[label] = (byPerson[label] ?? 0) + g.amount;
    }
    final entries = byPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(8).toList();

    if (top.isEmpty) {
      return const Text('暂无数据', style: TextStyle(color: Colors.white38));
    }

    return SizedBox(
      height: top.length * 44.0,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          barGroups: top.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.value,
                  color: AppTheme.electricBlue,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 70,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= top.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: [
                        Text(top[i].key,
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                        Text('¥${top[i].value.toInt()}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: top.first.value * 1.3,
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ─── Monthly Trend ──────────────────────────────────────────

  Widget _monthlyChart(List<GiftRecord> gifts) {
    final monthly = List.filled(12, 0.0);
    for (final g in gifts) {
      monthly[g.date.month - 1] += g.amount;
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          barGroups: List.generate(12, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: monthly[i],
                  color: monthly[i] > 0 ? AppTheme.electricBlue : Colors.white12,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const months = [
                    '1月', '2月', '3月', '4月', '5月', '6月',
                    '7月', '8月', '9月', '10月', '11月', '12月'
                  ];
                  final i = value.toInt();
                  if (i < 0 || i >= 12) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(months[i],
                        style: const TextStyle(color: Colors.white54, fontSize: 9)),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          maxY: monthly.reduce((a, b) => a > b ? a : b) * 1.4,
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ─── Recent Records ─────────────────────────────────────────

  List<Widget> _recentRecords(List<GiftRecord> gifts) {
    final sorted = List<GiftRecord>.from(gifts)..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.take(10).toList();

    return recent.map((r) {
      final person = widget.controller.allPeople
          .where((p) => p.giftHistory.any((g) => g.id == r.id))
          .firstOrNull;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGrey.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.electricBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.card_giftcard,
                  color: AppTheme.electricBlue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${person?.name ?? '未知'} · ${r.event}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '¥${r.amount.toInt()}',
              style: const TextStyle(
                color: AppTheme.electricBlue,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ─── Helpers ────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.electricBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
