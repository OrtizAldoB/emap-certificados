import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../repositories/dashboard_repository.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DashboardDatos? _datos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _datos = DashboardRepository().resumen();
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DASHBOARD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Resumen general del sistema', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          if (datos == null)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCards(datos),
                    const SizedBox(height: 20),
                    _buildCharts(datos),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCards(DashboardDatos d) {
    final cards = <(String, int, IconData, Color)>[
      ('TRABAJADORES', d.trabajadores, Icons.people_outline, AppTheme.primary),
      ('DOCUMENTOS', d.documentos, Icons.description_outlined, const Color(0xFF1565C0)),
      ('PROCESADOS', d.procesados, Icons.check_circle_outline, const Color(0xFF2E7D32)),
      ('PENDIENTES', d.pendientes, Icons.pending_actions, const Color(0xFFEF6C00)),
      ('CERTIFICADOS', d.certificados, Icons.badge_outlined, const Color(0xFF6A1B9A)),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final perRow = width > 1100 ? 5 : (width > 800 ? 3 : 2);
      final itemW = (width - (perRow - 1) * 12) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(
          width: itemW,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.$3, color: c.$4, size: 30),
                  const SizedBox(height: 8),
                  Text('${c.$2}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text(c.$1, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        )).toList(),
      );
    });
  }

  Widget _buildCharts(DashboardDatos d) {
    final ganado = DashboardRepository().totalGanadoPorAnio(d.movimientos);
    final aportes = DashboardRepository().totalAportesPorAnio(d.movimientos);
    final dias = DashboardRepository().diasPorAnio(d.movimientos);
    final docMes = DashboardRepository().documentosPorMes();

    final anios = ganado.keys.toList()..sort();
    final hasData = anios.isNotEmpty || docMes.isNotEmpty;

    return hasData
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _chartCard('Total ganado y aportes por año', _barChart(anios, ganado, aportes))),
              const SizedBox(width: 12),
              Expanded(child: _chartCard('Días trabajados por año', _barChartDias(anios, dias))),
            ],
          )
        : const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aún no hay movimientos registrados para mostrar gráficos.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
  }

  Widget _chartCard(String title, Widget chart) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(height: 220, child: chart),
            ],
          ),
        ),
      );

  Widget _barChart(List<int> anios, Map<int, double> ganado, Map<int, double> aportes) {
    return BarChart(BarChartData(
      barGroups: anios.map((a) => BarChartGroupData(x: a, barRods: [
        BarChartRodData(toY: ganado[a] ?? 0, color: AppTheme.primary, width: 8),
        BarChartRodData(toY: aportes[a] ?? 0, color: const Color(0xFFEF6C00), width: 8),
      ])).toList(),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt()}')),
        ),
      ),
    ));
  }

  Widget _barChartDias(List<int> anios, Map<int, int> dias) {
    return BarChart(BarChartData(
      barGroups: anios.map((a) => BarChartGroupData(x: a, barRods: [
        BarChartRodData(toY: (dias[a] ?? 0).toDouble(), color: const Color(0xFF1565C0), width: 12),
      ])).toList(),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text('${v.toInt()}')),
        ),
      ),
    ));
  }
}
