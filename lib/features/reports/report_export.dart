import 'dart:convert';
import 'dart:ui' as ui;
import 'package:characters/characters.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../transactions/data/transaction_model.dart';
import '../transactions/presentation/providers/summary_period.dart';
import 'report_data.dart';

enum ReportExportFormat { pdf, csv }

class ReportExportSnapshot {
  ReportExportSnapshot._(this.records, this.report, this.spaceLabel,
      this.spaceNames, this.generatedAt, this.syncNote, this.spaceId);
  final List<TransactionModel> records;
  final ReportData report;
  final String spaceLabel;
  final Map<String, String> spaceNames;
  final DateTime generatedAt;
  final String syncNote;
  final String? spaceId;

  factory ReportExportSnapshot.capture(
      {required List<TransactionModel> records,
      required SummaryPeriod period,
      required String? spaceId,
      required Map<String, String> spaceNames,
      required DateTime generatedAt,
      required String syncNote}) {
    final selected = records
        .where((tx) =>
            period.contains(tx.date) &&
            (spaceId == null || tx.spaceId == spaceId) &&
            (tx.isIncome || tx.isExpense))
        .toList()
      ..sort((a, b) {
        final date = a.date.compareTo(b.date);
        return date == 0 ? a.id.compareTo(b.id) : date;
      });
    final names = <String, String>{...spaceNames};
    for (final tx in selected) {
      names.putIfAbsent(tx.spaceId, () => tx.spaceName);
    }
    return ReportExportSnapshot._(
        List.unmodifiable(selected),
        ReportData.fromRecords(selected, period),
        spaceId == null
            ? 'Todos os espaços'
            : names[spaceId] ?? 'Espaço selecionado',
        Map.unmodifiable(names),
        generatedAt,
        syncNote,
        spaceId);
  }

  String fileName(ReportExportFormat format) {
    final start = DateFormat('yyyyMMdd').format(report.period.start);
    final end = DateFormat('yyyyMMdd').format(DateTime(
        report.period.endExclusive.year,
        report.period.endExclusive.month,
        report.period.endExclusive.day - 1));
    final scope = (spaceId ?? 'todos')
        .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '')
        .characters
        .take(40)
        .toString();
    return 'sereno-relatorio-$start-$end-$scope.${format.name}';
  }
}

String _money(int cents) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(cents / 100);
String _short(String text, [int max = 180]) => text.characters.length <= max
    ? text
    : '${text.characters.take(max).toString()}…';

// Quote every cell and neutralize spreadsheet formulas in user-entered text.
String _csvText(String value) {
  final first = value.trimLeft();
  final safe = first.startsWith(RegExp(r'[=+@\-]')) ||
          value.startsWith(RegExp(r'[\t\r\n]'))
      ? "'$value"
      : value;
  return _csvQuote(safe);
}

String _csvQuote(String value) => '"${value.replaceAll('"', '""')}"';

Future<void>? _emojiFontReady;
bool _hasEmoji(String text) => text.runes.any((r) =>
    (r >= 0x1f000 && r <= 0x1faff) ||
    (r >= 0x2300 && r <= 0x27ff) ||
    (r >= 0x2b00 && r <= 0x2bff) ||
    r == 0x20e3);

Future<Map<String, pw.MemoryImage>> _emojiImages(Iterable<String> texts) async {
  final clusters =
      texts.expand((text) => text.characters).where(_hasEmoji).toSet();
  if (clusters.isEmpty) return {};
  _emojiFontReady ??= (FontLoader('SerenoExportEmoji')
        ..addFont(rootBundle.load('assets/fonts/NotoEmoji.ttf')))
      .load();
  await _emojiFontReady;
  final result = <String, pw.MemoryImage>{};
  for (final cluster in clusters) {
    final painter = painting.TextPainter(
        textDirection: ui.TextDirection.ltr,
        text: painting.TextSpan(
            text: cluster,
            style: const painting.TextStyle(
                fontFamily: 'SerenoExportEmoji',
                fontSize: 80,
                color: ui.Color(0xff111827))))
      ..layout();
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(painter.width.ceil().clamp(1, 1000),
        painter.height.ceil().clamp(1, 1000));
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null) {
      result[cluster] = pw.MemoryImage(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    }
    image.dispose();
    picture.dispose();
    painter.dispose();
  }
  return result;
}

pw.Widget _pdfText(String text, Map<String, pw.MemoryImage> images,
    {pw.TextStyle? style}) {
  if (!text.characters.any(images.containsKey)) {
    return pw.Text(text, style: style);
  }
  final children = <pw.InlineSpan>[];
  var plain = '';
  for (final cluster in text.characters) {
    final image = images[cluster];
    if (image == null) {
      plain += cluster;
      continue;
    }
    if (plain.isNotEmpty) {
      children.add(pw.TextSpan(text: plain));
      plain = '';
    }
    children.add(
        pw.WidgetSpan(child: pw.Image(image, height: style?.fontSize ?? 10)));
  }
  if (plain.isNotEmpty) children.add(pw.TextSpan(text: plain));
  return pw.RichText(text: pw.TextSpan(style: style, children: children));
}

Uint8List buildReportCsv(ReportExportSnapshot snapshot) {
  final rows = <List<String>>[
    [
      'Registro',
      'Período',
      'Filtro de espaço',
      'Gerado em',
      'Sincronização',
      'Data',
      'Tipo',
      'Categoria',
      'Emoji',
      'Espaço do lançamento',
      'Descrição',
      'Valor (BRL)'
    ],
  ];
  final metadata = [
    snapshot.report.period.label,
    snapshot.spaceLabel,
    DateFormat('dd/MM/yyyy HH:mm').format(snapshot.generatedAt),
    snapshot.syncNote
  ];
  for (final tx in snapshot.records) {
    rows.add([
      'Lançamento',
      ...metadata,
      DateFormat('dd/MM/yyyy HH:mm').format(tx.date.toLocal()),
      tx.isIncome ? 'Entrada' : 'Saída',
      tx.category,
      tx.categoryIcon ?? '',
      snapshot.spaceNames[tx.spaceId] ?? tx.spaceName,
      tx.description ?? '',
      ((tx.amount * 100).round() / 100).toStringAsFixed(2).replaceAll('.', ',')
    ]);
  }
  for (final total in {
    'Entradas': snapshot.report.income,
    'Saídas': snapshot.report.expense,
    'Saldo': snapshot.report.income - snapshot.report.expense
  }.entries) {
    rows.add([
      'Resumo',
      ...metadata,
      '',
      total.key,
      '',
      '',
      '',
      '',
      (total.value / 100).toStringAsFixed(2).replaceAll('.', ',')
    ]);
  }
  return Uint8List.fromList(utf8.encode(
      '\uFEFF${rows.map((row) => row.asMap().entries.map((cell) => cell.key == 11 ? _csvQuote(cell.value) : _csvText(cell.value)).join(';')).join('\r\n')}\r\n'));
}

Future<Uint8List> buildReportPdf(ReportExportSnapshot snapshot) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
  final emoji =
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoEmoji.ttf'));
  final images = await _emojiImages([
    snapshot.spaceLabel,
    ...snapshot.report.categories.map((cat) => _short(cat.name, 60)),
    for (final tx in snapshot.records) ...[
      _short(tx.category, 60),
      _short(snapshot.spaceNames[tx.spaceId] ?? tx.spaceName, 60),
      _short(tx.description ?? '', 180)
    ],
  ]);
  final document = pw.Document(
      title: 'Sereno - Relatório financeiro',
      author: 'Sereno',
      creator: 'Sereno',
      theme: pw.ThemeData.withFont(
          base: regular, bold: bold, fontFallback: [emoji]));
  const blue = PdfColor.fromInt(0xff2563eb);
  const green = PdfColor.fromInt(0xff0f766e);
  const orange = PdfColor.fromInt(0xffc2410c);
  final data = snapshot.report;
  pw.Widget title(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Text(text,
          style: const pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold, color: blue)));
  pw.Widget total(String label, int value, PdfColor color) => pw.Expanded(
      child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          margin: const pw.EdgeInsets.only(right: 8),
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xfff1f5f9)),
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 6),
                pw.Text(_money(value),
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
              ])));
  document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      maxPages: 10000,
      footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Sereno | Dados disponíveis na geração',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
                pw.Text('${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8)),
              ])),
      build: (_) => [
            pw.Text('SERENO',
                style: const pw.TextStyle(
                    fontSize: 24, color: blue, fontWeight: pw.FontWeight.bold)),
            pw.Text('Relatório financeiro',
                style: const pw.TextStyle(fontSize: 17)),
            pw.SizedBox(height: 14),
            pw.Text('Período: ${data.period.label}'),
            _pdfText('Espaço: ${snapshot.spaceLabel}', images),
            pw.Text(
                'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(snapshot.generatedAt)}'),
            pw.Text(snapshot.syncNote,
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            pw.Row(children: [
              total('Entradas', data.income, green),
              total('Saídas', data.expense, orange),
              total('Saldo', data.income - data.expense, blue)
            ]),
            pw.SizedBox(height: 8),
            pw.Text('${data.count} lançamentos no período',
                style: const pw.TextStyle(fontSize: 9)),
            title('Gastos por categoria'),
            if (data.categories.isEmpty) pw.Text('Nenhuma saída no período.'),
            for (final cat in data.categories)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfText(
                            '${_short(cat.name, 60)} - ${_money(cat.cents)} (${NumberFormat('0.#', 'pt_BR').format(data.expense == 0 ? 0 : cat.cents * 100 / data.expense)}%)',
                            images,
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 3),
                        pw.LayoutBuilder(
                            builder: (context, constraints) => pw.Align(
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Container(
                                    height: 5,
                                    width: (constraints!.maxWidth) *
                                        (data.expense == 0
                                            ? 0
                                            : cat.cents / data.expense),
                                    color: orange))),
                      ])),
            title(data.period.type == SummaryPeriodType.day
                ? 'Gastos por hora'
                : 'Gastos por dia'),
            pw.Wrap(spacing: 8, runSpacing: 6, children: [
              for (var i = 0; i < data.buckets.length; i++)
                if (data.buckets[i] != 0)
                  pw.Text(
                      '${data.period.type == SummaryPeriodType.day ? '${i}h' : DateFormat('dd/MM').format(DateTime(data.period.start.year, data.period.start.month, data.period.start.day + i))}: ${_money(data.buckets[i])}',
                      style: const pw.TextStyle(fontSize: 9)),
              if (data.expense == 0) pw.Text('Nenhuma saída no período.'),
            ]),
            title('Lançamentos'),
            pw.Text('Descrições resumidas. O CSV contém o texto completo.',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            if (snapshot.records.isEmpty)
              pw.Text('Nenhum lançamento no período.'),
            if (snapshot.records.isNotEmpty)
              pw.TableHelper.fromTextArray(
                  headers: [
                    'Data',
                    'Tipo',
                    'Categoria',
                    'Espaço',
                    'Descrição',
                    'Valor'
                  ],
                  data: [
                    for (final tx in snapshot.records)
                      [
                        DateFormat('dd/MM/yyyy').format(tx.date.toLocal()),
                        tx.isIncome ? 'Entrada' : 'Saída',
                        _pdfText(_short(tx.category, 60), images,
                            style: const pw.TextStyle(fontSize: 8)),
                        _pdfText(
                            _short(
                                snapshot.spaceNames[tx.spaceId] ?? tx.spaceName,
                                60),
                            images,
                            style: const pw.TextStyle(fontSize: 8)),
                        _pdfText(_short(tx.description ?? '', 180), images,
                            style: const pw.TextStyle(fontSize: 8)),
                        _money((tx.amount * 100).round())
                      ]
                  ],
                  headerStyle: const pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8,
                      color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: blue),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellPadding: const pw.EdgeInsets.all(5),
                  border: null,
                  oddRowDecoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xfff1f5f9)),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(59),
                    1: const pw.FixedColumnWidth(40),
                    2: const pw.FlexColumnWidth(1.1),
                    3: const pw.FlexColumnWidth(0.9),
                    4: const pw.FlexColumnWidth(1.7),
                    5: const pw.FixedColumnWidth(72)
                  },
                  cellAlignments: {5: pw.Alignment.centerRight}),
          ]));
  return document.save();
}
