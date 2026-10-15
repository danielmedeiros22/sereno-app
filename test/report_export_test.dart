import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sereno_app/features/reports/report_export.dart';
import 'package:sereno_app/features/reports/report_export_dialog.dart';
import 'package:sereno_app/features/transactions/data/transaction_model.dart';
import 'package:sereno_app/features/transactions/presentation/providers/summary_period.dart';
import 'package:sereno_app/features/transactions/presentation/providers/transaction_provider.dart';

ReportExportSnapshot snapshot(List<TransactionModel> records,
        {String? space = 'home'}) =>
    ReportExportSnapshot.capture(
        records: records,
        period: SummaryPeriod(SummaryPeriodType.month, DateTime(2026, 10, 14)),
        spaceId: space,
        spaceNames: {'home': 'Casa', 'personal': 'Pessoal'},
        generatedAt: DateTime(2026, 10, 14, 20, 30),
        syncNote: 'Dados disponíveis neste dispositivo.');
TransactionModel record(double amount,
        {String? description, String space = 'home'}) =>
    TransactionModel(
        type: 'expense',
        amount: amount,
        category: 'Alimentação',
        categoryIcon: '🧑🏽‍🍳',
        date: DateTime(2026, 10, 14),
        description: description,
        spaceId: space,
        spaceName: space == 'home' ? 'Casa' : 'Pessoal');

class FakeFiles extends ReportFileService {
  Completer<PreparedReport>? pending;
  bool failPrepare = false, failSave = false;
  int writes = 0;
  @override
  Future<PreparedReport> prepare(
      ReportExportSnapshot value, ReportExportFormat format) async {
    if (failPrepare) throw StateError('generation');
    if (pending != null) return pending!.future;
    return PreparedReport(
        Uint8List.fromList([1]), value.fileName(format), 'text/csv');
  }

  @override
  Future<void> save(PreparedReport file, Rect origin) async {
    if (failSave) throw StateError('share');
    expect(origin.width, greaterThan(0));
    writes++;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  test(
      'export captures the same period and space and does not follow later edits',
      () {
    final records = [
      record(0.1),
      record(0.2),
      record(100, space: 'personal'),
      TransactionModel(
          type: 'income',
          amount: 50,
          category: 'Salário',
          date: DateTime(2026, 9, 30),
          spaceId: 'home')
    ];
    final captured = snapshot(records);
    records.clear();
    expect(captured.records, hasLength(2));
    expect(captured.report.expense, 30);
    expect(captured.spaceLabel, 'Casa');
    expect(captured.fileName(ReportExportFormat.csv),
        'sereno-relatorio-20261001-20261031-home.csv');
    expect(() => captured.records.clear(), throwsUnsupportedError);
  });
  test(
      'CSV preserves Unicode, quotes, line breaks and neutralizes formula text',
      () {
    final csv = utf8.decode(buildReportCsv(snapshot([
      record(12.34, description: '  =HYPERLINK("x")\nsegunda;linha'),
    ])));
    expect(buildReportCsv(snapshot([])).take(3), [0xef, 0xbb, 0xbf]);
    expect(csv, contains('"\'  =HYPERLINK(""x"")\nsegunda;linha"'));
    expect(csv, contains('🧑🏽‍🍳'));
    expect(csv, contains('"12,34"'));
    expect(csv, contains('"-12,34"'));
    expect(csv, contains('"Resumo"'));
    expect(csv.endsWith('\r\n'), true);
    expect(csv, isNot(contains('"\'-12,34"')));
  });
  test('empty CSV still contains headers, scope and zero totals', () {
    final csv = utf8.decode(buildReportCsv(snapshot([], space: null)));
    expect(csv, contains('Todos os espaços'));
    expect(csv, contains('"Saldo"'));
    expect(csv.split('\r\n').length, 5);
    expect(csv, isNot(contains('"Lançamento"')));
  });

  test('PDF handles multiple pages, Portuguese, emoji and long descriptions',
      () async {
    final records = List.generate(
        100,
        (i) => TransactionModel(
            type: i % 4 == 0 ? 'income' : 'expense',
            amount: i + 0.25,
            category: i % 4 == 0 ? 'Salário' : 'Alimentação 🧑🏽‍🍳',
            date: DateTime(2026, 10, 1 + i % 28),
            spaceId: 'home',
            spaceName: 'Casa',
            description:
                'Descrição com acentos: ação, refeição; "aspas". ${'Texto longo ' * 35}'));
    final pdf = await buildReportPdf(snapshot(records));
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
    expect(pdf.length, greaterThan(1000));
    if (const bool.fromEnvironment('SERENO_PDF_VISUAL')) {
      final file = File('_backup_prototipo_20261008/report-export-sample.pdf');
      await file.writeAsBytes(pdf);
      await File('_backup_prototipo_20261008/report-export-sample.csv')
          .writeAsBytes(buildReportCsv(snapshot(records)));
    }
  });
  test('empty PDF can be generated', () async {
    expect((await buildReportPdf(snapshot([]))).length, greaterThan(1000));
  });

  testWidgets(
      'file is not shared automatically; explicit action and retry are supported',
      (tester) async {
    final service = FakeFiles();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          transactionOwnerProvider.overrideWithValue('account'),
          reportFileServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ReportExportDialog(
                    snapshot: snapshot([]),
                    format: ReportExportFormat.csv,
                    owner: 'account')))));
    await tester.pumpAndSettle();
    expect(service.writes, 0);
    service.failSave = true;
    await tester.tap(find.text('Salvar ou compartilhar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível salvar ou compartilhar'),
        findsOneWidget);
    service.failSave = false;
    await tester.tap(find.text('Salvar ou compartilhar'));
    await tester.pumpAndSettle();
    expect(service.writes, 1);
  });
  testWidgets(
      'account change during generation hides old scope and prevents sharing',
      (tester) async {
    final service = FakeFiles()..pending = Completer<PreparedReport>();
    final owner = StateProvider<String?>((ref) => 'a');
    final container = ProviderContainer(overrides: [
      transactionOwnerProvider.overrideWith((ref) => ref.watch(owner)),
      reportFileServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(
                body: ReportExportDialog(
                    snapshot: snapshot([record(50)]),
                    format: ReportExportFormat.pdf,
                    owner: 'a')))));
    await tester.pump();
    container.read(owner.notifier).state = 'b';
    service.pending!.complete(
        PreparedReport(Uint8List(1), 'sample.pdf', 'application/pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A conta mudou'), findsOneWidget);
    expect(find.text('Casa'), findsNothing);
    expect(find.text('Salvar ou compartilhar'), findsNothing);
    expect(service.writes, 0);
  });

  testWidgets('generation failure can be retried without sharing automatically',
      (tester) async {
    final service = FakeFiles()..failPrepare = true;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          transactionOwnerProvider.overrideWithValue(null),
          reportFileServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ReportExportDialog(
                    snapshot: snapshot([]),
                    format: ReportExportFormat.pdf,
                    owner: null)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível gerar'), findsOneWidget);
    expect(find.text('Salvar ou compartilhar'), findsNothing);
    service.failPrepare = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar ou compartilhar'), findsOneWidget);
    expect(service.writes, 0);
  });
}
