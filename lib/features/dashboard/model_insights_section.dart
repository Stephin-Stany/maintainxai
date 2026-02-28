import 'dart:convert';
import 'dart:io' show Platform;

// import 'package:fl_chart/fl_chart.dart'; // unused: removed to silence analyzer
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ModelInsightsSection extends StatefulWidget {
  const ModelInsightsSection({super.key});

  @override
  State<ModelInsightsSection> createState() => _ModelInsightsSectionState();
}

class _ModelInsightsSectionState extends State<ModelInsightsSection> {
  late Future<Map<String, dynamic>> _dataFuture;
  String _selectedScenario = 'balanced';
  double _selectedThreshold = 0.130;

  // Color constants
  static const Color _bgColor = Color(0xFF0F0F0F);
  static const Color _cardColor = Color(0xFF1A1A1A);
  static const Color _borderColor = Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final base = _detectApiBase();
    try {
      final insightsResp = await http.get(Uri.parse('$base/model-insights')).timeout(const Duration(seconds: 6));
      final econResp = await http.get(Uri.parse('$base/economic-impact')).timeout(const Duration(seconds: 6));
      final threshResp = await http.get(Uri.parse('$base/threshold-optimization')).timeout(const Duration(seconds: 6));
      final riskResp = await http.get(Uri.parse('$base/risk-distribution')).timeout(const Duration(seconds: 6));

      if (insightsResp.statusCode != 200) throw Exception('Model insights failed');
      if (econResp.statusCode != 200) throw Exception('Economic impact failed');
      if (threshResp.statusCode != 200) throw Exception('Threshold optimization failed');
      if (riskResp.statusCode != 200) throw Exception('Risk distribution failed');

      return {
        'insights': json.decode(insightsResp.body),
        'economic': json.decode(econResp.body),
        'thresholds': json.decode(threshResp.body),
        'risk': json.decode(riskResp.body),
      };
    } catch (e, st) {
      // ignore: avoid_print
      print('ModelInsights fetch error: $e\n$st');
      rethrow;
    }
  }

  String _detectApiBase() {
    // prefer backend on port 8000 (dev instance).
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      if (Platform.isIOS) return 'http://127.0.0.1:8000';
      if (Platform.isWindows) return 'http://127.0.0.1:8000';
      if (Platform.isLinux) return 'http://127.0.0.1:8000';
      if (Platform.isMacOS) return 'http://127.0.0.1:8000';
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  String _formatCurrency(int value) {
    // Indian numbering system: 10,00,000 instead of 1,000,000
    final str = value.toString();
    if (str.length <= 3) return str;
    
    final reversed = str.split('').reversed.toList();
    final result = <String>[];
    
    for (int i = 0; i < reversed.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) {
        result.add(',');
      }
      result.add(reversed[i]);
    }
    
    return result.reversed.join('');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Failed to load model insights', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(err, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => setState(() => _dataFuture = _loadData()), child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final insights = data['insights'] ?? {};
        final metrics = insights['metrics'] ?? {};
        final features = insights['feature_importance'] ?? [];
        final econData = data['economic'] ?? {};
        final threshData = data['thresholds'] ?? {};
        final riskData = data['risk'] ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === HEADER ===
              Text(
                'Model Intelligence Dashboard',
                style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('LightGBM Predictive Maintenance Model Performance Analysis', style: TextStyle(color: Colors.white54, fontSize: 15)),
              const SizedBox(height: 48),

              // === 1. GLOBAL MODEL PERFORMANCE METRICS ===
              _buildSectionHeader('1. Global Model Performance Metrics', 'Overall health and discrimination ability of the trained model'),
              const SizedBox(height: 20),
              _buildMetricsGrid(metrics),
              const SizedBox(height: 48),

              // === 2. FEATURE IMPORTANCE ===
              _buildSectionHeader('2. Feature Importance (Failure Drivers)', 'Key sensor inputs that most influence model failure predictions'),
              const SizedBox(height: 20),
              _buildFeatureImportanceChart(features),
              const SizedBox(height: 48),

              // === 3. THRESHOLD OPTIMIZATION ===
              _buildSectionHeader('3. Interactive Threshold Optimization', 'Adjust decision threshold to balance precision vs. recall for your operational needs'),
              const SizedBox(height: 20),
              _buildThresholdSection(threshData),
              const SizedBox(height: 48),

              // === 4. ECONOMIC IMPACT ===
              _buildSectionHeader('4. Economic Impact & ROI Analysis', 'Financial consequences of model predictions across different cost scenarios'),
              const SizedBox(height: 20),
              _buildEconomicImpactSection(econData),
              const SizedBox(height: 48),

              // === 5. RISK DISTRIBUTION ===
              _buildSectionHeader('5. Risk Distribution Overview', 'Current fleet health status based on failure probability analysis'),
              const SizedBox(height: 20),
              _buildRiskDistributionSection(riskData),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }

  Widget _buildMetricsGrid(Map metrics) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 1.6,
      children: [
        _buildMetricCard('ROC-AUC', (metrics['roc_auc'] != null) ? (metrics['roc_auc'] as num).toStringAsFixed(4) : '—', const Color(0xFF007AFF), Icons.analytics_outlined),
        _buildMetricCard('Precision', (metrics['precision'] != null) ? '${((metrics['precision'] as num) * 100).toStringAsFixed(1)}%' : '—', const Color(0xFF34C759), Icons.gps_fixed),
        _buildMetricCard('Recall', (metrics['recall'] != null) ? '${((metrics['recall'] as num) * 100).toStringAsFixed(1)}%' : '—', const Color(0xFFFF9500), Icons.radar),
        _buildMetricCard('F1-Score', (metrics['f1_score'] != null) ? (metrics['f1_score'] as num).toStringAsFixed(4) : '—', const Color(0xFFAF52DE), Icons.balance),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              Icon(icon, color: color.withOpacity(0.5), size: 18),
            ],
          ),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(width: 40, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildFeatureImportanceChart(List features) {
    if (features.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14)),
        child: const Text('No feature data available', style: TextStyle(color: Colors.white54)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.align_horizontal_left, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 12),
              Text('TOP FAILURE DRIVERS', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 32),
          ...features.take(6).map((f) {
            final pct = (f['gain_pct'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(f['feature'].toString().split('(').first, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      color: Colors.blueAccent.withOpacity(0.8),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildThresholdSection(Map threshData) {
    final thresholds = (threshData['thresholds'] as List?)?.cast<Map>() ?? [];
    if (thresholds.isEmpty) {
      return const Text('No threshold data available', style: TextStyle(color: Colors.white54));
    }

    Map? selectedData;
    double minDiff = double.infinity;
    for (final t in thresholds) {
      final thresh = (t['threshold'] as num?)?.toDouble() ?? 0.0;
      final diff = (thresh - _selectedThreshold).abs();
      if (diff < minDiff) {
        minDiff = diff;
        selectedData = t;
      }
    }

    final precision = ((selectedData?['precision'] as num?)?.toDouble() ?? 0.0);
    final recall = ((selectedData?['recall'] as num?)?.toDouble() ?? 0.0);
    final f1 = ((selectedData?['f1'] as num?)?.toDouble() ?? 0.0);
    final falseAlarms = (selectedData?['false_alarms'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 12),
              const Text('DECISION THRESHOLD TUNING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_selectedThreshold.toStringAsFixed(3), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 40),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: Colors.blueAccent.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _selectedThreshold,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              onChanged: (val) => setState(() => _selectedThreshold = val),
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildMiniImpactCard('PRECISION', '${(precision * 100).toStringAsFixed(1)}%', Colors.greenAccent),
              _buildMiniImpactCard('RECALL', '${(recall * 100).toStringAsFixed(1)}%', Colors.orangeAccent),
              _buildMiniImpactCard('F1-SCORE', f1.toStringAsFixed(4), Colors.purpleAccent),
              _buildMiniImpactCard('FALSE ALARMS', '$falseAlarms', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniImpactCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEconomicImpactSection(Map econData) {
    final scenarios = ['conservative', 'balanced', 'aggressive'];
    final scenarioLabels = {'conservative': 'Conservative', 'balanced': 'Balanced', 'aggressive': 'Aggressive'};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF161618), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Scenario:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: scenarios.map((scenario) {
              final isSelected = _selectedScenario == scenario;
              return GestureDetector(
                onTap: () => setState(() => _selectedScenario = scenario),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Colors.blueAccent.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    scenarioLabels[scenario]!,
                    style: TextStyle(
                      color: isSelected ? Colors.blueAccent : Colors.white54,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          _buildEconomicCard(_selectedScenario, econData),
          const SizedBox(height: 20),
          _buildInfoBox(
            'Conservative: Highest precision, fewest false alarms. Balanced: Optimize F1-score for best overall performance. '
            'Aggressive: Maximize recall to catch all failures despite increased maintenance costs.',
          ),
        ],
      ),
    );
  }

  Widget _buildEconomicCard(String scenario, Map econData) {
    final data = econData[scenario] as Map?;
    if (data == null) return const Text('Invalid scenario', style: TextStyle(color: Colors.white54));

    final savings = data['savings'] as num?;
    final desc = data['description'] as String?;
    final formattedSavings = savings != null ? '₹${_formatCurrency(savings.toInt())}' : '—';
    final color = scenario == 'conservative' ? Colors.blue : (scenario == 'balanced' ? Colors.green : Colors.red);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Annual Savings (${scenario.toUpperCase()})', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 12),
          Text(formattedSavings, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 28)),
          const SizedBox(height: 8),
          Text(desc ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRiskDistributionSection(Map riskData) {
    final highRisk = riskData['high_risk'] as Map? ?? {};
    final medRisk = riskData['medium_risk'] as Map? ?? {};
    final lowRisk = riskData['low_risk'] as Map? ?? {};

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildRiskCard(
              'High Risk',
              ((highRisk['percentage'] as num?)?.toStringAsFixed(1) ?? '—') + '%',
              '${highRisk['count'] ?? 0} machines',
              Colors.red,
              highRisk['description'] as String? ?? '',
            ),
            _buildRiskCard(
              'Medium Risk',
              ((medRisk['percentage'] as num?)?.toStringAsFixed(1) ?? '—') + '%',
              '${medRisk['count'] ?? 0} machines',
              Colors.orange,
              medRisk['description'] as String? ?? '',
            ),
            _buildRiskCard(
              'Low Risk',
              ((lowRisk['percentage'] as num?)?.toStringAsFixed(1) ?? '—') + '%',
              '${lowRisk['count'] ?? 0} machines',
              Colors.green,
              lowRisk['description'] as String? ?? '',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildInfoBox(
          'Fleet Status: High-risk machines need immediate inspection. Medium-risk machines should be scheduled for maintenance soon. '
          'Low-risk machines are operating normally. Regular monitoring recommended for all categories.',
        ),
      ],
    );
  }

  Widget _buildRiskCard(String label, String pct, String count, Color color, String desc) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          Text(pct, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
          Text(count, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 16),
          Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 10.0, top: 2.0),
            child: Icon(Icons.info_outline, color: Colors.blue, size: 18),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
