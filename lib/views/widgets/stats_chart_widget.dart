import 'package:flutter/material.dart';
import 'package:komovia_go/config/theme.dart';

/// Widget for displaying bar chart (win rate by level/board size)
class WinRateBarChartWidget extends StatelessWidget {
  final Map<String, double> data;
  final String title;
  final String xAxisLabel;
  final String yAxisLabel;

  const WinRateBarChartWidget({
    Key? key,
    required this.data,
    required this.title,
    this.xAxisLabel = '',
    this.yAxisLabel = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('データなし',
            style: TextStyle(color: AppColors.washiDim)),
      );
    }

    final maxValue = data.values.isEmpty ? 100.0 : 100.0;

    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.washi,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: data.length * 60.0,
                height: 200,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.entries.map((entry) {
                      return _buildBarColumn(
                        label: entry.key,
                        value: entry.value,
                        maxValue: maxValue,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarColumn({
    required String label,
    required double value,
    required double maxValue,
  }) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    final barColor = value >= 60
        ? AppColors.wakatake
        : value >= 40
            ? AppColors.kin
            : AppColors.shuLight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 150 * percentage,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${value.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.washi,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 50,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.washiDim, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Widget for displaying line chart (win rate progression)
class WinRateLineChartWidget extends StatelessWidget {
  final List<double> values;
  final String title;
  final int daysBack;

  const WinRateLineChartWidget({
    Key? key,
    required this.values,
    required this.title,
    this.daysBack = 7,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Center(
        child: Text('データなし',
            style: TextStyle(color: AppColors.washiDim)),
      );
    }

    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.washi,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: _buildLineChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (values.length < 2) {
      return Center(
        child: Text('最少2つのデータポイントが必要です',
            style: TextStyle(color: AppColors.washiDim)),
      );
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = (maxValue - minValue).clamp(1.0, double.infinity);

    return CustomPaint(
      painter: LineChartPainter(
        values: values,
        maxValue: maxValue,
        minValue: minValue,
        range: range,
      ),
      child: Container(),
    );
  }
}

/// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final double minValue;
  final double range;

  LineChartPainter({
    required this.values,
    required this.maxValue,
    required this.minValue,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.kin
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = AppColors.kin
      ..strokeWidth = 4;

    final gridPaint = Paint()
      ..color = AppColors.sumiCard.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Calculate points
    final points = <Offset>[];
    final xStep = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = xStep * i;
      final normalizedValue = (values[i] - minValue) / range;
      final y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    // Draw line
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    // Draw points
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }

    // Draw value labels
    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < values.length; i++) {
      final x = (size.width / (values.length - 1)) * i;
      final label = '${values[i].toStringAsFixed(0)}%';

      textPaint.text = TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.washiDim,
          fontSize: 10,
        ),
      );

      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(x - textPaint.width / 2, size.height + 8),
      );
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

/// Widget for displaying pie chart (game mode distribution)
class GameDistributionPieChartWidget extends StatelessWidget {
  final Map<String, int> data;
  final String title;

  const GameDistributionPieChartWidget({
    Key? key,
    required this.data,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('データなし',
            style: TextStyle(color: AppColors.washiDim)),
      );
    }

    final total = data.values.fold<int>(0, (sum, val) => sum + val);
    final colors = [
      AppColors.aiLight,
      AppColors.kin,
      AppColors.wakatake,
      AppColors.fuji,
      Colors.pink[600]!,
    ];

    return Card(
      color: AppColors.sumiSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.washi,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Pie chart
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 150,
                    child: CustomPaint(
                      painter: PieChartPainter(
                        data: data,
                        colors: colors,
                        total: total,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Legend
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final mode = entry.value.key;
                      final count = entry.value.value;
                      final percentage = (count / total * 100).toStringAsFixed(1);
                      final color = colors[index % colors.length];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$mode: $count ($percentage%)',
                                style: TextStyle(
                                  color: AppColors.washiDim,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for pie chart
class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;
  final int total;

  PieChartPainter({
    required this.data,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;

    var startAngle = -3.14159 / 2; // Start from top

    data.entries.toList().asMap().entries.forEach((entry) {
      final index = entry.key;
      final count = entry.value.value;
      final sliceAngle = (count / total) * 3.14159 * 2;
      final color = colors[index % colors.length];

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );

      startAngle += sliceAngle;
    });

    // Draw center circle (donut effect)
    final centerPaint = Paint()
      ..color = AppColors.sumiSurface
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
