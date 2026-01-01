import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/entry_provider.dart';
import '../models/entry_model.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool showSales = true;
  bool showExp = true;
  bool showProfit = true;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EntryProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterChips(provider),
          const SizedBox(height: 20),
          _buildKPICards(provider),
          const SizedBox(height: 24),
          _buildSectionTitle("Daily Trends"),
          _buildChartToggles(),
          _buildLineChart(provider.entries),
          const SizedBox(height: 24),
          _buildSectionTitle("Sales vs Expenditure"),
          _buildBarChart(provider.entries),
          const SizedBox(height: 24),
          _buildSectionTitle("Profit Stack"),
          _buildStackedChart(provider.entries),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterChips(EntryProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DateFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.name.toUpperCase()),
              selected: provider.currentFilter == filter,
              onSelected: (selected) {
                if (filter == DateFilter.custom) {
                  _selectCustomDateRange(context, provider);
                } else {
                  provider.setFilter(filter);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectCustomDateRange(BuildContext context, EntryProvider provider) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      provider.setFilter(DateFilter.custom, customRange: range);
    }
  }

  Widget _buildKPICards(EntryProvider provider) {
    final today = provider.todayEntry;
    final trend = provider.profitTrend;

    return Column(
      children: [
        Row(
          children: [
            _kpiCard("Today Sales", today?.sales ?? 0, Colors.blue, Icons.payments),
            const SizedBox(width: 12),
            _kpiCard("Today Exp", today?.expenditure ?? 0, Colors.orange, Icons.shopping_cart),
          ],
        ),
        const SizedBox(height: 12),
        _kpiCard(
          "Today Profit",
          today?.profit ?? 0,
          Colors.green,
          Icons.trending_up,
          isFullWidth: true,
          subtitle: "${trend.toStringAsFixed(1)}% vs yesterday",
          trendIcon: trend >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
          trendColor: trend >= 0 ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _kpiCard(String title, double value, Color color, IconData icon,
      {bool isFullWidth = false, String? subtitle, IconData? trendIcon, Color? trendColor}) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text("₹${value.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 14),
                const SizedBox(width: 4),
                Text(subtitle, style: TextStyle(color: trendColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ]
        ],
      ),
    );

    return isFullWidth ? content : Expanded(child: content);
  }

  Widget _buildChartToggles() {
    return Row(
      children: [
        _toggleIcon(Icons.circle, Colors.blue, "Sales", showSales, (v) => setState(() => showSales = v)),
        _toggleIcon(Icons.circle, Colors.orange, "Exp", showExp, (v) => setState(() => showExp = v)),
        _toggleIcon(Icons.circle, Colors.green, "Profit", showProfit, (v) => setState(() => showProfit = v)),
      ],
    );
  }

  Widget _toggleIcon(IconData icon, Color color, String label, bool active, Function(bool) onTap) {
    return GestureDetector(
      onTap: () => onTap(!active),
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: active ? color : Colors.grey, size: 12),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: active ? null : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<Entry> entries) {
    if (entries.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No data")));
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: _buildTitlesData(),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (showSales) _lineData(entries, (e) => e.sales, Colors.blue),
            if (showExp) _lineData(entries, (e) => e.expenditure, Colors.orange),
            if (showProfit) _lineData(entries, (e) => e.profit, Colors.green),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.blueGrey.withOpacity(0.8),
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem("₹${s.y}", const TextStyle(color: Colors.white));
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _lineData(List<Entry> entries, double Function(Entry) getY, Color color) {
    return LineChartBarData(
      spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), getY(e.value))).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildBarChart(List<Entry> entries) {
    if (entries.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No data")));
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: BarChart(
        BarChartData(
          titlesData: _buildTitlesData(),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(toY: e.value.sales, color: Colors.blue, width: 8),
                BarChartRodData(toY: e.value.expenditure, color: Colors.orange, width: 8),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStackedChart(List<Entry> entries) {
    if (entries.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No data")));
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, top: 16),
      child: BarChart(
        BarChartData(
          titlesData: _buildTitlesData(),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.sales,
                  rodStackItems: [
                    BarChartRodStackItem(0, e.value.expenditure, Colors.orange),
                    BarChartRodStackItem(e.value.expenditure, e.value.sales, Colors.green),
                  ],
                  width: 15,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                DateFormat('dd').format(DateTime.now().subtract(Duration(days: 7 - value.toInt()))),
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }
}
