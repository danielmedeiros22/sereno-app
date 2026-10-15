import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../transactions/presentation/providers/transaction_provider.dart';
import 'report_export.dart';
import 'report_file_save.dart';

bool get _desktopWeb =>
    kIsWeb &&
    defaultTargetPlatform != TargetPlatform.android &&
    defaultTargetPlatform != TargetPlatform.iOS;

class PreparedReport {
  const PreparedReport(this.bytes, this.name, this.mimeType);
  final Uint8List bytes;
  final String name, mimeType;
}

class ReportFileService {
  Future<PreparedReport> prepare(
    ReportExportSnapshot snapshot,
    ReportExportFormat format,
  ) async => PreparedReport(
    format == ReportExportFormat.pdf
        ? await buildReportPdf(snapshot)
        : buildReportCsv(snapshot),
    snapshot.fileName(format),
    format == ReportExportFormat.pdf ? 'application/pdf' : 'text/csv',
  );
  Future<void> save(PreparedReport file, Rect origin) async {
    if (_desktopWeb) {
      await saveDesktopReport(file.bytes, file.name, file.mimeType);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(file.bytes, mimeType: file.mimeType)],
        fileNameOverrides: [file.name],
        sharePositionOrigin: origin,
        downloadFallbackEnabled: true,
      ),
    );
  }
}

final reportFileServiceProvider = Provider<ReportFileService>(
  (ref) => ReportFileService(),
);

class ReportExportDialog extends ConsumerStatefulWidget {
  const ReportExportDialog({
    super.key,
    required this.snapshot,
    required this.format,
    required this.owner,
  });
  final ReportExportSnapshot snapshot;
  final ReportExportFormat format;
  final String? owner;
  @override
  ConsumerState<ReportExportDialog> createState() => _ReportExportDialogState();
}

class _ReportExportDialogState extends ConsumerState<ReportExportDialog> {
  PreparedReport? _file;
  String? _error;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _error = null;
      _file = null;
    });
    try {
      final file = await ref
          .read(reportFileServiceProvider)
          .prepare(widget.snapshot, widget.format);
      if (mounted) setState(() => _file = file);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível gerar o arquivo. Tente novamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final changed = ref.watch(transactionOwnerProvider) != widget.owner;
    return AlertDialog(
      title: Text('Exportar ${widget.format.name.toUpperCase()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!changed) ...[
              Text(widget.snapshot.report.period.label),
              Text(widget.snapshot.spaceLabel),
              Text('${widget.snapshot.report.count} lançamentos'),
              const SizedBox(height: 12),
            ],
            if (changed)
              const Text('A conta mudou. Feche e gere um novo relatório.')
            else if (_error != null)
              Text(_error!)
            else if (_file == null)
              const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Preparando arquivo…'),
                ],
              )
            else
              Text(
                _desktopWeb
                    ? 'Arquivo pronto. Escolha onde salvar. Se o navegador não oferecer essa opção, será usada a pasta de downloads configurada. Os dados refletem o momento da geração.'
                    : 'Arquivo pronto. Salve ou escolha um aplicativo para compartilhar. Os dados refletem o momento da geração.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        if (_error != null && !changed)
          TextButton(
            onPressed: _prepare,
            child: const Text('Tentar novamente'),
          ),
        if (_file != null && !changed)
          Builder(
            builder: (buttonContext) => FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (ref.read(transactionOwnerProvider) != widget.owner) {
                        return;
                      }
                      final box =
                          buttonContext.findRenderObject()! as RenderBox;
                      final origin = box.localToGlobal(Offset.zero) & box.size;
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(reportFileServiceProvider)
                            .save(_file!, origin);
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _error =
                                'Não foi possível salvar ou compartilhar. Tente novamente.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              child: Text(
                _saving
                    ? 'Abrindo…'
                    : _desktopWeb
                    ? 'Salvar como'
                    : 'Salvar ou compartilhar',
              ),
            ),
          ),
      ],
    );
  }
}
