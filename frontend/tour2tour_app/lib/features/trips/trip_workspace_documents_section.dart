part of 'trip_workspace_page.dart';

extension _TripWorkspaceDocumentsSection on _TripWorkspacePageState {
  Widget _buildDocumentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showSharedDocumentsInTrip) ...[
            Row(
              children: [
                IconButton(
                  onPressed: _closeSharedDocumentsFolder,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Общие документы',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (!_showSharedDocumentsInTrip)
            SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _uploadingDocument ? null : _pickAndUploadDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD7E37A),
                foregroundColor: const Color(0xFF161616),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: _uploadingDocument
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: const Text('Загрузить документ'),
            ),
          ),
          if (!_showSharedDocumentsInTrip) const SizedBox(height: 12),
          Expanded(
            child: _showSharedDocumentsInTrip
                ? _buildSharedDocumentsInsideTrip()
                : _documentsLoading
                ? const Center(child: CircularProgressIndicator())
                : _documents.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет документов',
                      style: TextStyle(color: Colors.white.withOpacity(0.85)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _documents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final doc = _documents[i];
                      final isFolder = doc.itemType == 'folder';
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isFolder
                              ? _openSharedDocumentsFolder
                              : () => _openDocumentPreview(doc),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (isFolder)
                                  const Icon(Icons.folder_shared_rounded, color: Colors.white),
                                if (isFolder) const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isFolder
                                            ? 'Файлов: ${doc.sharedCount ?? 0}'
                                            : _fmtBytes(doc.sizeBytes),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isFolder)
                                  IconButton(
                                    tooltip: 'Переименовать',
                                    onPressed: () => _renameDocument(doc),
                                    icon: const Icon(Icons.edit_rounded, color: Colors.white),
                                  ),
                                if (!isFolder)
                                  IconButton(
                                    tooltip: 'Удалить',
                                    onPressed: () => _deleteDocument(doc),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedDocumentsInsideTrip() {
    if (_sharedDocumentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sharedDocuments.isEmpty) {
      return Center(
        child: Text(
          'Папка пустая',
          style: TextStyle(color: Colors.white.withOpacity(0.85)),
        ),
      );
    }
    return ListView.separated(
      itemCount: _sharedDocuments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final doc = _sharedDocuments[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openDocumentPreview(doc),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _fmtBytes(doc.sizeBytes),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime value) {
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
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
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png'))
      return 'image';
    return null;
  }

  String _buildTargetFileName({
    required String customTitle,
    required String originalFileName,
  }) {
    final clean = customTitle.trim();
    final ext = _fileExtension(originalFileName);
    if (ext.isEmpty) return clean;

    if (clean.toLowerCase().endsWith(ext.toLowerCase())) {
      return clean;
    }
    return '$clean$ext';
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
}


