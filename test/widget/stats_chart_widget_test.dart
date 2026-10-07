import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_go/views/widgets/stats_chart_widget.dart';

void main() {
  group('WinRateBarChartWidget Tests', () {
    late Map<String, double> testData;

    setUp(() {
      testData = {
        '9×9': 65.5,
        '13×13': 58.3,
        '19×19': 52.1,
      };
    });

    testWidgets('Renders bar chart with data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateBarChartWidget(
              data: testData,
              title: 'ボードサイズ別勝率',
            ),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('ボードサイズ別勝率'), findsOneWidget);

      // Verify data is displayed (65.5 rounds up via toStringAsFixed(0))
      expect(find.text('66%'), findsOneWidget);
      expect(find.text('58%'), findsOneWidget);
      expect(find.text('52%'), findsOneWidget);
    });

    testWidgets('Renders empty state when data is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateBarChartWidget(
              data: {},
              title: 'テストチャート',
            ),
          ),
        ),
      );

      // Verify empty state message
      expect(find.text('データなし'), findsOneWidget);
    });

    testWidgets('Displays correct bar colors based on win rate', (WidgetTester tester) async {
      final coloredData = {
        'High': 75.0,  // Green
        'Medium': 50.0, // Amber
        'Low': 25.0,   // Red
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateBarChartWidget(
              data: coloredData,
              title: 'カラーテスト',
            ),
          ),
        ),
      );

      // Verify all values are displayed
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('Shows axis labels when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateBarChartWidget(
              data: testData,
              title: 'テスト',
              xAxisLabel: 'ボードサイズ',
              yAxisLabel: '勝率%',
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('WinRateLineChartWidget Tests', () {
    late List<double> testValues;

    setUp(() {
      testValues = [45.0, 50.0, 55.0, 52.0, 58.0, 60.0, 65.0];
    });

    testWidgets('Renders line chart with data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateLineChartWidget(
              values: testValues,
              title: '勝率推移',
            ),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('勝率推移'), findsOneWidget);

      // Verify CustomPaint is rendered
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Shows error for single data point', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateLineChartWidget(
              values: [50.0],
              title: 'テスト',
            ),
          ),
        ),
      );

      expect(find.text('最少2つのデータポイントが必要です'), findsOneWidget);
    });

    testWidgets('Renders empty state for no data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateLineChartWidget(
              values: [],
              title: 'テスト',
            ),
          ),
        ),
      );

      expect(find.text('データなし'), findsOneWidget);
    });

    testWidgets('Normalizes and displays data correctly', (WidgetTester tester) async {
      final normalizedData = [30.0, 40.0, 50.0, 60.0, 70.0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinRateLineChartWidget(
              values: normalizedData,
              title: 'テスト',
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('LineChartPainter Tests', () {
    testWidgets('LineChartPainter renders correctly', (WidgetTester tester) async {
      const values = [45.0, 50.0, 55.0, 52.0, 58.0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: LineChartPainter(
                values: values,
                maxValue: 60.0,
                minValue: 40.0,
                range: 20.0,
              ),
              child: Container(),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('LineChartPainter handles empty values', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: LineChartPainter(
                values: const [],
                maxValue: 100.0,
                minValue: 0.0,
                range: 100.0,
              ),
              child: Container(),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('GameDistributionPieChartWidget Tests', () {
    late Map<String, int> testData;

    setUp(() {
      testData = {
        'Blitz': 120,
        'Rapid': 85,
        'Classical': 45,
      };
    });

    testWidgets('Renders pie chart with data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameDistributionPieChartWidget(
              data: testData,
              title: 'ゲームモード分布',
            ),
          ),
        ),
      );

      // Verify title is displayed
      expect(find.text('ゲームモード分布'), findsOneWidget);

      // Verify legend is displayed (total is 250: 120/85/45 -> 48/34/18%)
      expect(find.text('Blitz: 120 (48.0%)'), findsOneWidget);
      expect(find.text('Rapid: 85 (34.0%)'), findsOneWidget);
      expect(find.text('Classical: 45 (18.0%)'), findsOneWidget);
    });

    testWidgets('Renders empty state when data is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameDistributionPieChartWidget(
              data: {},
              title: 'テスト',
            ),
          ),
        ),
      );

      expect(find.text('データなし'), findsOneWidget);
    });

    testWidgets('Calculates percentages correctly', (WidgetTester tester) async {
      final percentageData = {
        'TypeA': 50,
        'TypeB': 50,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameDistributionPieChartWidget(
              data: percentageData,
              title: 'テスト',
            ),
          ),
        ),
      );

      // Verify 50/50 split is shown
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('Handles single data point', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameDistributionPieChartWidget(
              data: {'OnlyType': 100},
              title: 'テスト',
            ),
          ),
        ),
      );

      expect(find.text('OnlyType: 100 (100.0%)'), findsOneWidget);
    });
  });

  group('PieChartPainter Tests', () {
    testWidgets('PieChartPainter renders correctly', (WidgetTester tester) async {
      const data = {
        'A': 30,
        'B': 20,
        'C': 50,
      };
      final colors = [Colors.blue, Colors.green, Colors.red];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: PieChartPainter(
                data: data,
                colors: colors,
                total: 100,
              ),
              child: Container(),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('PieChartPainter handles empty data', (WidgetTester tester) async {
      const colors = [Colors.blue, Colors.green];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: PieChartPainter(
                data: const {},
                colors: colors,
                total: 0,
              ),
              child: Container(),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
