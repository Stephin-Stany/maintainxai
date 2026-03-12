// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/machine_model.dart'; 
import 'model_insights_section.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? overviewData;
  bool isLoading = true;
  Map<String, dynamic>? maintenanceData;
  bool isMaintenanceLoading = true;
  bool isSendingRequest = false; 

  final formatter = NumberFormat.compact(locale: 'en_IN');
  Machine? selectedMachine;
  bool _viewingHistory = false;
  bool _viewingModelInsights = false;

  Map<String, List<Machine>> _categorizedMachines = {};

  Future<void> _loadCategorizedMachines() async {
    final uri = Uri.parse('http://127.0.0.1:8000/machines');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(resp.body);
      setState(() {
        _categorizedMachines = {
          'high': (data['high'] as List).map((e) => Machine.fromJson(e)).toList(),
          'medium': (data['medium'] as List).map((e) => Machine.fromJson(e)).toList(),
          'low': (data['low'] as List).map((e) => Machine.fromJson(e)).toList(),
        };
      });
    }
  }

  Future<void> _fetchMachineInsights(int id) async {
    final uri = Uri.parse('http://127.0.0.1:8000/predict/$id');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(resp.body);
      setState(() {
        if (selectedMachine != null && selectedMachine!.id == id) {
          double? toDouble(dynamic v) {
            if (v == null) return null;
            if (v is num) return v.toDouble();
            return double.tryParse(v.toString());
          }

          selectedMachine = selectedMachine!.copyWith(
            failureProbability: toDouble(data['probability'] ?? data['prob'] ?? data['failureProbability']),
            airTemp: toDouble(data['airTemp'] ?? data['Air temperature [K]']),
            processTemp: toDouble(data['processTemp'] ?? data['Process temperature [K]']),
            rpm: toDouble(data['rpm'] ?? data['Rotational speed [rpm]']),
            torque: toDouble(data['torque'] ?? data['Torque [Nm]']),
            toolWear: toDouble(data['toolWear'] ?? data['Tool wear [min]']),
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadOverview();
    loadMaintenance();
    _loadCategorizedMachines();
  }

  void loadOverview() async {
    try {
      final data = await ApiService.getOverview();
      setState(() {
        overviewData = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading overview: $e");
    }
  }

  void loadMaintenance() async {
    try {
      final data = await ApiService.getMaintenance();
      setState(() {
        maintenanceData = data;
        isMaintenanceLoading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _viewingHistory
                ? _buildMaintenanceHistoryView()
                : (_viewingModelInsights
                    ? const ModelInsightsSection()
                    : (selectedMachine == null
                        ? _buildFactoryOverview()
                        : _buildMachineDetail(selectedMachine!))),
          ),
        ],
      ),
    );
  }

  // --- SIDEBAR ---
  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 8),
                const Text(
                  "MaintainX AI",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // NEW: Logout Button
                IconButton(
                  onPressed: () {
                    // Redirect to login page
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  icon: const Icon(Icons.logout, color: Colors.white38, size: 18),
                  tooltip: "Log Out",
                ),
              ],
            ),
          ),
          _sidebarTile("Factory Overview", Icons.grid_view_rounded, isSelected: selectedMachine == null && !_viewingHistory && !_viewingModelInsights, onTap: () {
            setState(() { selectedMachine = null; _viewingHistory = false; _viewingModelInsights = false; });
          }),
          const SizedBox(height: 8),
          _sidebarTile("Maintenance & ROI", Icons.history_edu_rounded, isSelected: _viewingHistory, onTap: () {
            setState(() { _viewingHistory = true; selectedMachine = null; _viewingModelInsights = false; });
          }),
          const SizedBox(height: 8),
          _sidebarTile("Model Insights", Icons.insights_rounded, isSelected: _viewingModelInsights, onTap: () {
            setState(() { _viewingModelInsights = true; selectedMachine = null; _viewingHistory = false; });
          }),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(alignment: Alignment.centerLeft, child: Text("VIRTUAL MACHINES", style: TextStyle(color: Colors.white24, fontSize: 11, letterSpacing: 1.5))),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildVirtualMachineList()),
          const Divider(color: Colors.white10, height: 1),
          const ListTile(
            leading: CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white54)),
            title: Text("Admin Tech", style: TextStyle(color: Colors.white70, fontSize: 14)),
            subtitle: Text("ID: 4429-01", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildVirtualMachineList() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (_categorizedMachines['high']?.isNotEmpty ?? false) _buildCategoryHeader("HIGH RISK (≥13%)", Colors.redAccent),
        ...(_categorizedMachines['high'] ?? []).map((m) => _sidebarMachineTile(m)),
        if (_categorizedMachines['medium']?.isNotEmpty ?? false) _buildCategoryHeader("ADVISORY (5-13%)", Colors.orangeAccent),
        ...(_categorizedMachines['medium'] ?? []).map((m) => _sidebarMachineTile(m)),
        if (_categorizedMachines['low']?.isNotEmpty ?? false) _buildCategoryHeader("STABLE (<5%)", Colors.greenAccent),
        ...(_categorizedMachines['low'] ?? []).map((m) => _sidebarMachineTile(m)),
      ],
    );
  }

  Widget _sidebarMachineTile(Machine m) {
    bool isSelected = selectedMachine?.id == m.id;
    return ListTile(
      onTap: () {
        setState(() { selectedMachine = m; _viewingHistory = false; _viewingModelInsights = false; });
        _fetchMachineInsights(m.id);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(Icons.circle, color: m.statusColor, size: 10),
      title: Text(m.name, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      subtitle: Text(m.type, style: const TextStyle(color: Colors.white24, fontSize: 12)),
      trailing: Text("${(m.failureProbability * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white24, fontSize: 12)),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.03),
    );
  }

  Widget _buildMachineDetail(Machine machine) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailHeader(machine),
          const SizedBox(height: 30),
          _buildMachinePredictiveDetail(machine),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(Machine machine) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(machine.name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("MODEL: LightGBM-v2 • SERIAL: ${machine.id}", style: const TextStyle(color: Colors.white38)),
          ],
        ),
        _buildActionButtons(machine.statusColor),
      ],
    );
  }

  Widget _buildActionButtons(Color machineColor) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: () async {
            if (selectedMachine != null) {
              await ApiService.downloadLogs(selectedMachine!.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Exporting logs for ${selectedMachine!.name}..."),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }, 
          child: const Text("Export Logs", style: TextStyle(color: Colors.white70))
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isSendingRequest ? null : () async {
            setState(() => isSendingRequest = true);
            bool success = await ApiService.sendServiceRequest(selectedMachine!.id);
            setState(() => isSendingRequest = false);
            
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? "Service Request Sent to emmanuelmarkose.14@gmail.com" : "Failed to send request. Check backend."),
                backgroundColor: success ? Colors.green : Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: machineColor.withOpacity(0.2), 
            foregroundColor: machineColor,
          ),
          child: isSendingRequest 
            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text("Service Request"),
        ),
      ],
    );
  }

  Widget _buildMachinePredictiveDetail(Machine machine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPredictionGauge(machine.failureProbability, machine),
            const SizedBox(width: 40),
            Expanded(child: _buildPredictiveAlertCard(machine)),
          ],
        ),
        const SizedBox(height: 24),
        _buildGaugeInputs(machine),
        const SizedBox(height: 40),
        const Text("DIAGNOSTIC TELEMETRY", style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          childAspectRatio: 2.5,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _sensorTile("Power Load", machine.powerEstimate.toStringAsFixed(0), Icons.bolt),
            _sensorTile("Temp Delta", "${machine.tempDifference.toStringAsFixed(1)} K", Icons.thermostat),
            _sensorTile("Tool Wear", "${machine.toolWear} min", Icons.build_circle),
            _sensorTile("Speed", "${machine.rpm} RPM", Icons.speed),
            _sensorTile("Torque", "${machine.torque} Nm", Icons.settings_input_component),
            _sensorTile("Process Temp", "${machine.processTemp} K", Icons.device_thermostat),
          ],
        ),
      ],
    );
  }

  Widget _buildFactoryOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Production Insights", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("Factory Performance & Capacity Analysis", style: TextStyle(color: Colors.white38)),
                ],
              ),
              _buildSyncIndicator(),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildOverviewStatCard("Total Output", formatter.format(overviewData?["total_output"] ?? 0), Icons.precision_manufacturing, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildOverviewStatCard("Savings", "₹${formatter.format(overviewData?["total_savings"] ?? 0)}", Icons.currency_rupee, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildOverviewStatCard("Downtime Prevented", "${overviewData?["prevented_downtime"] ?? 0} hrs", Icons.timer, Colors.orange)),
            ],
          ),
          const SizedBox(height: 32),
          _buildOEESection(),
          const SizedBox(height: 32),
          _buildCapacityChartSection(),
          const SizedBox(height: 32),
          _buildLiveSystemLogs(),
        ],
      ),
    );
  }

  Widget _buildOEESection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("OVERALL EQUIPMENT EFFECTIVENESS (OEE)", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOEEGauge("Availability", (overviewData?["oee"]?["availability"] ?? 94) / 100, Colors.greenAccent),
              _buildOEEGauge("Performance", (overviewData?["oee"]?["performance"] ?? 88) / 100, Colors.blueAccent),
              _buildOEEGauge("Quality", (overviewData?["oee"]?["quality"] ?? 96) / 100, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityChartSection() {
    if (overviewData == null) return const SizedBox();
    List weekly = overviewData?["weekly_production"] ?? [];
    List<double> rawValues = weekly.map((item) => (item["Rotational speed [rpm]"] as num).toDouble()).toList();
    double maxRaw = rawValues.isNotEmpty ? rawValues.reduce((a, b) => a > b ? a : b) : 1;
    List<double> normalizedValues = rawValues.map((val) => (val / maxRaw) * 20).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("WEEKLY PRODUCTION CAPACITY", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              Text("Target: 15k Units", style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 25,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueAccent.withOpacity(0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'Batch ${group.x}\n${rod.toY.toStringAsFixed(1)}k Units',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text("Production Batches", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    axisNameSize: 25,
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text('B${value.toInt()}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text("Output (k Units)", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    axisNameSize: 25,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}k', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(normalizedValues.length, (index) => _makeBarGroup(index, normalizedValues[index], normalizedValues[index] < 8 ? Colors.orangeAccent : Colors.blueAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceHistoryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Maintenance & ROI Tracker", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text("Financial impact of predictive interventions", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 40),
          Row(
            children: [
              _buildROICard("Net Savings", "₹${formatter.format(maintenanceData?["total_savings"] ?? 0)}", "+AI Optimized", Colors.greenAccent),
              _buildROICard("Failures Prevented", "${maintenanceData?["failures_prevented"] ?? 0}", "Model Accuracy Alerts", Colors.blueAccent),
              _buildROICard("MTBF Improvement", "${maintenanceData?["mtbf_improvement"] ?? 0} hrs", "Mean Time Between Failures", Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Savings Trend (Cumulative)", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  SizedBox(height: 250, child: _buildSavingsLineChart()),
                ]),
              )),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildInterventionList()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionList() {
    final events = [
      {"m": "CNC-01", "date": "Oct 12", "saved": "₹3,48,600", "type": "Critical Tool Wear"},
      {"m": "Lathe-04", "date": "Oct 10", "saved": "₹1,49,400", "type": "Overstrain Warning"},
      {"m": "Drill-02", "date": "Oct 05", "saved": "₹74,700", "type": "Routine Optimization"},
    ];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent AI Interventions", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...events.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['m']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(e['type']!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(e['saved']!, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  Text(e['date']!, style: const TextStyle(color: Colors.white24, fontSize: 11)),
                ])
              ],
            ),
          )),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: color, width: 22, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 20, color: Colors.white.withOpacity(0.05)))]);
  }

  Widget _sidebarTile(String title, IconData icon, {required bool isSelected, required VoidCallback onTap}) {
    return ListTile(onTap: onTap, leading: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white24), title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white24, fontSize: 14)));
  }

  Widget _buildCategoryHeader(String label, Color color) {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)));
  }

  Widget _sensorTile(String label, String value, IconData icon) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Row(children: [Icon(icon, color: Colors.blueAccent, size: 20), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.white24, fontSize: 12))])]));
  }

  Widget _buildOEEGauge(String label, double val, Color color) {
    return Column(children: [Stack(alignment: Alignment.center, children: [SizedBox(height: 100, width: 100, child: CircularProgressIndicator(value: val, strokeWidth: 10, color: color, backgroundColor: Colors.white10, strokeCap: StrokeCap.round)), Text("${(val * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]), const SizedBox(height: 16), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))]);
  }

  Widget _buildOverviewStatCard(String label, String value, IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 28), const SizedBox(height: 20), Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13))]));
  }

  Widget _buildROICard(String label, String value, String sub, Color color) {
    return Expanded(child: Container(margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)), const SizedBox(height: 12), Text(sub, style: const TextStyle(color: Colors.white24, fontSize: 11))])));
  }

  Widget _buildSyncIndicator() {
    return InkWell(
      onTap: () async {
        final statusData = await ApiService.getSyncStatus();
        loadOverview();
        if (!mounted) return;
        bool isSynced = statusData['status'] == 'synced';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSynced 
              ? "System fully operational. All models and telemetry synced." 
              : "Sync Alert: ${statusData['issues'].join(', ')}"),
            backgroundColor: isSynced ? Colors.green : Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, color: Colors.greenAccent, size: 14),
            SizedBox(width: 8),
            Text("SYSTEM SYNCED", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionGauge(double probability, Machine machine) {
    return Column(mainAxisSize: MainAxisSize.min, children: [const Text("Failure Probability", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Stack(alignment: Alignment.center, children: [SizedBox(height: 120, width: 120, child: CircularProgressIndicator(value: probability, strokeWidth: 12, color: probability > 0.13 ? Colors.redAccent : (probability > 0.05 ? Colors.orangeAccent : Colors.greenAccent), backgroundColor: Colors.white10, strokeCap: StrokeCap.round)), Text("${(probability * 100).toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])]);
  }

  Widget _buildPredictiveAlertCard(Machine machine) {
    String msg = machine.failureProbability >= 0.13 ? '⚠️ HIGH RISK - Inspect within 24h.' : (machine.failureProbability >= 0.05 ? '🟠 ADVISORY - Monitor soon.' : '✅ STABLE - Operating normally.');
    return Container(height: 130, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)), child: Center(child: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center)));
  }

  Widget _buildGaugeInputs(Machine machine) {
    return Wrap(alignment: WrapAlignment.center, spacing: 20, runSpacing: 12, children: [_sensorTile("Air Temp", "${(machine.airTemp - 273.15).toStringAsFixed(1)}°C", Icons.thermostat), _sensorTile("Process Temp", "${(machine.processTemp - 273.15).toStringAsFixed(1)}°C", Icons.device_thermostat), _sensorTile("RPM", machine.rpm.toStringAsFixed(0), Icons.speed), _sensorTile("Torque", machine.torque.toStringAsFixed(1), Icons.settings_input_component)]);
  }

  Widget _buildSavingsLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            axisNameWidget: const Text("Production Timeline (Days)", style: TextStyle(color: Colors.white38, fontSize: 11)),
            axisNameSize: 25,
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text('D${value.toInt()}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text("Cumulative Savings (₹)", style: TextStyle(color: Colors.white38, fontSize: 11)),
            axisNameSize: 25,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}k', style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.greenAccent.withOpacity(0.8),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [FlSpot(0, 10), FlSpot(1, 15), FlSpot(2, 12), FlSpot(3, 25), FlSpot(4, 30), FlSpot(5, 42)],
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.greenAccent.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSystemLogs() {
    final List<Map<String, String>> logs = [
      {"time": "10:55", "msg": "M-001: Tool Wear threshold breach.", "type": "critical"},
      {"time": "10:48", "msg": "M-002: Temp Delta rising (12.4°C).", "type": "warning"},
      {"time": "10:30", "msg": "Daily model optimization sync complete.", "type": "info"},
      {"time": "10:15", "msg": "M-003: Operational sync successful.", "type": "info"},
      {"time": "09:00", "msg": "Shift handover: Tech Admin signed in.", "type": "info"},
    ];

    return Container(
      height: 365,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Live System Logs", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, i) {
                Color logColor = logs[i]['type'] == 'critical' 
                    ? Colors.redAccent 
                    : (logs[i]['type'] == 'warning' ? Colors.orangeAccent : Colors.blueAccent);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text(logs[i]['time']!, style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15),
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: logColor, shape: BoxShape.circle)),
                      const SizedBox(width: 15),
                      Expanded(child: Text(logs[i]['msg']!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}