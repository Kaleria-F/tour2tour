import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../documents/documents_repo.dart';
import '../trips/widgets/pdf_memory_preview.dart';

class SharedDocumentsPage extends StatefulWidget {
  final DocumentsRepo documentsRepo;
  const SharedDocumentsPage({super.key, required this.documentsRepo});

  @override
  State<SharedDocumentsPage> createState() => _SharedDocumentsPageState();
}

class _SharedDocumentsPageState extends State<SharedDocumentsPage> {
  List<TripDocument> _documents = const [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await widget.documentsRepo.listSharedDocuments();
      if (!mounted) return;
      setState(() => _documents = items);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить общие документы')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    if (f.bytes == null) return;
    final contentType = _resolveContentType(f.name);
    if (contentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Разрешены только PDF, JPG и PNG')),
      );
      return;
    }
    final customName = await _openNameDialog(f.name);
    if (customName == null) return;
    final targetName = _buildTargetFileName(customTitle: customName, originalFileName: f.name);
    setState(() => _uploading = true);
    try {
      await widget.documentsRepo.uploadSharedBytesDirect(
        fileName: targetName,
        bytes: f.bytes!,
        contentType: contentType,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ загружен')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки документа')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _rename(TripDocument doc) async {
    final name = await _openNameDialog(doc.fileName);
    if (name == null) return;
    final targetName = _buildTargetFileName(customTitle: name, originalFileName: doc.fileName);
    try {
      final updated = await widget.documentsRepo.renameSharedObject(
        objectKey: doc.objectKey,
        fileName: targetName,
      );
      if (!mounted) return;
      setState(() {
        _documents = _documents.map((e) => e.objectKey == updated.objectKey ? updated : e).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название обновлено')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось переименовать')),
      );
    }
  }

  Future<void> _delete(TripDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text('Документ "${doc.fileName}" будет удалён без возможности восстановления.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.documentsRepo.deleteSharedObject(doc.objectKey);
      if (!mounted) return;
      setState(() {
        _documents = _documents.where((e) => e.objectKey != doc.objectKey).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ удалён')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить документ')),
      );
    }
  }

  Future<void> _open(TripDocument doc) async {
    try {
      final url = await widget.documentsRepo.getDownloadUrl(doc.objectKey);
      final bytes = await widget.documentsRepo.fetchFileBytes(url);
      if (!mounted) return;
      final type = _resolvePreviewType(doc.fileName);
      if (type == null || bytes.isEmpty) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _PreviewDialog(title: doc.fileName, fileType: type, fileBytes: bytes),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть документ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Общие документы')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file_rounded),
                      label: const Text('Загрузить документ'),
                    ),
                  ),
                ),
                Expanded(
                  child: _documents.isEmpty
                      ? const Center(child: Text('Пока нет документов'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _documents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final doc = _documents[i];
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              tileColor: Colors.white.withOpacity(0.06),
                              title: Text(doc.fileName),
                              subtitle: Text(_fmtBytes(doc.sizeBytes)),
                              onTap: () => _open(doc),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Переименовать',
                                    onPressed: () => _rename(doc),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Удалить',
                                    onPressed: () => _delete(doc),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
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

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String? _resolveContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    return null;
  }

  String? _resolvePreviewType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) return 'image';
    return null;
  }

  String _fileNameWithoutExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx <= 0) return fileName;
    return fileName.substring(0, idx);
  }

  String _fileExtension(String fileName) {
    final idx = fileName.lastIndexOf('.');
    if (idx <= 0 || idx == fileName.length - 1) return '';
    return fileName.substring(idx);
  }

  String _buildTargetFileName({
    required String customTitle,
    required String originalFileName,
  }) {
    final clean = customTitle.trim();
    final ext = _fileExtension(originalFileName);
    if (ext.isEmpty) return clean;
    if (clean.toLowerCase().endsWith(ext.toLowerCase())) return clean;
    return '$clean$ext';
  }

  Future<String?> _openNameDialog(String sourceName) async {
    final c = TextEditingController(text: _fileNameWithoutExtension(sourceName));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Название документа'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final v = c.text.trim();
              if (v.isEmpty) return;
              Navigator.of(ctx).pop(v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    c.dispose();
    return result;
  }
}

class _PreviewDialog extends StatelessWidget {
  final String title;
  final String fileType;
  final Uint8List fileBytes;

  const _PreviewDialog({
    required this.title,
    required this.fileType,
    required this.fileBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 700,
        child: Column(
          children: [
            ListTile(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: fileType == 'pdf'
                  ? PdfMemoryPreview(bytes: fileBytes)
                  : InteractiveViewer(
                      child: Center(
                        child: Image.memory(fileBytes, fit: BoxFit.contain),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
