import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_ui.dart';
import '../profile/profile_repo.dart';
import 'admin_repo.dart';

class AdminPage extends StatefulWidget {
  final AdminRepo repo;
  final ProfileRepo profileRepo;

  const AdminPage({
    super.key,
    required this.repo,
    required this.profileRepo,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  UserMe? _me;
  bool _loading = true;
  List<AdminPlace> _places = const [];
  List<AdminPlaceCandidate> _candidates = const [];
  List<AdminImportJob> _importJobs = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.profileRepo.getMe(),
        widget.repo.listPlaces(),
        widget.repo.listCandidates(),
        widget.repo.listImportJobs(),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0] as UserMe;
        _places = results[1] as List<AdminPlace>;
        _candidates = results[2] as List<AdminPlaceCandidate>;
        _importJobs = results[3] as List<AdminImportJob>;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlaceDialog([AdminPlace? place]) async {
    final nameCtrl = TextEditingController(text: place?.name ?? '');
    final cityCtrl = TextEditingController(text: place?.city ?? '');
    final addressCtrl = TextEditingController(text: place?.address ?? '');
    final categoryCtrl = TextEditingController(text: place?.category ?? 'place');
    final subtypeCtrl = TextEditingController(text: place?.subcategory ?? 'museum');
    final sourceCtrl = TextEditingController(text: place?.source ?? 'manual');
    final descriptionCtrl = TextEditingController(text: place?.description ?? '');
    final priceCtrl = TextEditingController(text: place?.priceLevel ?? 'middle');
    final tagsCtrl = TextEditingController(
      text: place == null ? '{"history": 5, "culture": 4}' : jsonEncode(place.tags),
    );
    List<CitySuggestion> citySuggestions = const [];
    int cityRequestId = 0;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadCitySuggestions(String value) async {
              final query = value.trim();
              if (query.length < 2) {
                setDialogState(() => citySuggestions = const []);
                return;
              }

              final requestId = ++cityRequestId;
              try {
                final items = await widget.repo.suggestCities(query);
                if (!context.mounted || requestId != cityRequestId) return;
                setDialogState(() => citySuggestions = items);
              } catch (_) {
                if (!context.mounted || requestId != cityRequestId) return;
                setDialogState(() => citySuggestions = const []);
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF171126),
              title: Text(
                place == null ? 'Новое место' : 'Редактировать место',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _adminField(nameCtrl, 'Название'),
                      Autocomplete<CitySuggestion>(
                        displayStringForOption: (option) => option.city,
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.trim().toLowerCase();
                          if (query.length < 2) {
                            return const Iterable<CitySuggestion>.empty();
                          }
                          return citySuggestions.where((item) {
                            return item.city.toLowerCase().contains(query) ||
                                item.displayName.toLowerCase().contains(query);
                          });
                        },
                        onSelected: (option) {
                          cityCtrl.value = TextEditingValue(
                            text: option.city,
                            selection: TextSelection.collapsed(offset: option.city.length),
                          );
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          if (controller.text != cityCtrl.text) {
                            controller.value = cityCtrl.value;
                          }
                          return _adminField(
                            controller,
                            'Город / населенный пункт',
                            focusNode: focusNode,
                            onChanged: (value) {
                              cityCtrl.value = controller.value;
                              loadCitySuggestions(value);
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final items = options.toList();
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 240),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shrinkWrap: true,
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final option = items[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(option.city),
                                      subtitle: Text(option.displayName),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      _adminField(addressCtrl, 'Адрес'),
                      _adminField(categoryCtrl, 'Категория'),
                      _adminField(subtypeCtrl, 'Подкатегория'),
                      _adminField(sourceCtrl, 'Источник'),
                      _adminField(priceCtrl, 'Уровень цены'),
                      _adminField(descriptionCtrl, 'Описание', maxLines: 4),
                      _adminField(tagsCtrl, 'Теги JSON', maxLines: 4),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final payload = {
                        'name': nameCtrl.text.trim(),
                        'city': cityCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'category': categoryCtrl.text.trim(),
                        'subcategory': subtypeCtrl.text.trim(),
                        'source': sourceCtrl.text.trim(),
                        'description': descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
                        'price_level': priceCtrl.text.trim().isEmpty ? null : priceCtrl.text.trim(),
                        'status': place?.status ?? 'approved',
                        'tags': Map<String, dynamic>.from(jsonDecode(tagsCtrl.text.trim()) as Map),
                      };
                      if (place == null) {
                        await widget.repo.createPlace(payload);
                      } else {
                        await widget.repo.updatePlace(place.id, payload);
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      showAuthError(context, 'Не удалось сохранить место: $e');
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deletePlace(AdminPlace place) async {
    await widget.repo.deletePlace(place.id);
    if (!mounted) return;
    await _load();
  }

  Future<void> _decideCandidate(AdminPlaceCandidate candidate, String status) async {
    await widget.repo.decideCandidate(id: candidate.id, status: status);
    if (!mounted) return;
    await _load();
  }

  Future<void> _openImportDialog() async {
    final sourceCtrl = TextEditingController(text: 'csv');
    final kindCtrl = TextEditingController(text: 'places');
    String? fileName;
    List<int>? fileBytes;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171126),
          title: const Text('Создать import job', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _adminField(sourceCtrl, 'Источник'),
                _adminField(kindCtrl, 'Тип'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const ['csv'],
                        withData: true,
                      );
                      final file = picked?.files.single;
                      if (file?.bytes == null) return;
                      fileName = file!.name;
                      fileBytes = file.bytes!;
                      if (context.mounted) {
                        showAuthSuccess(context, 'Файл выбран: $fileName');
                      }
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(fileName == null ? 'Выбрать CSV' : fileName!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (fileBytes == null || fileName == null) {
                    showAuthError(context, 'Сначала выберите CSV файл');
                    return;
                  }
                  await widget.repo.uploadCsvImport(
                    source: sourceCtrl.text.trim(),
                    kind: kindCtrl.text.trim(),
                    fileName: fileName!,
                    bytes: fileBytes!,
                    createdBy: _me?.email ?? _me?.phone ?? 'admin',
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                } catch (e) {
                  showAuthError(context, 'Не удалось создать import job: $e');
                }
              },
              child: const Text('Создать'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = _me?.role == 'admin';

    return Scaffold(
      body: Stack(
        children: [
          const _NightBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Админка рекомендаций',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => context.go('/profile'),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('В профиль'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (!isAdmin)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Доступ запрещен. Требуется роль администратора.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicatorColor: cs.primary,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white60,
                                  tabs: const [
                                    Tab(text: 'Места'),
                                    Tab(text: 'Кандидаты'),
                                    Tab(text: 'Импорты'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    _buildPlacesTab(),
                                    _buildCandidatesTab(),
                                    _buildImportsTab(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesTab() {
    return _glassCard(
      child: Column(
        children: [
          Row(
            children: [
              const Text('Каталог мест', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openPlaceDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить место'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _places.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final place = _places[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          _pill(place.city),
                          const SizedBox(width: 8),
                          _pill(place.category),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        place.address ?? 'Без адреса',
                        style: TextStyle(color: Colors.white.withOpacity(0.78)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill(place.priceLevel ?? 'price?'),
                          _pill(place.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _openPlaceDialog(place),
                            child: const Text('Редактировать'),
                          ),
                          OutlinedButton(
                            onPressed: () => _deletePlace(place),
                            child: const Text('Удалить'),
                          ),
                        ],
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

  Widget _buildCandidatesTab() {
    return _glassCard(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Кандидаты на модерацию', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _candidates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final candidate = _candidates[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              candidate.payload['name']?.toString() ?? 'Без названия',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          _pill(candidate.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        jsonEncode(candidate.payload),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.78)),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: () => _decideCandidate(candidate, 'approved'),
                            child: const Text('Одобрить'),
                          ),
                          OutlinedButton(
                            onPressed: () => _decideCandidate(candidate, 'rejected'),
                            child: const Text('Отклонить'),
                          ),
                        ],
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

  Widget _buildImportsTab() {
    return _glassCard(
      child: Column(
        children: [
          Row(
            children: [
              const Text('Импорты', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openImportDialog,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Новый import job'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: _importJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final job = _importJobs[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job.fileName ?? 'Без файла', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '${job.source} В· ${job.kind}',
                              style: TextStyle(color: Colors.white.withOpacity(0.78)),
                            ),
                            if (job.stats.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Всего: ${job.stats['rows_total'] ?? 0} В· Создано: ${job.stats['candidates_created'] ?? 0} В· Ошибок: ${job.stats['rows_failed'] ?? 0}',
                                style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _pill(job.status),
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

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 12),
      ),
    );
  }

  Widget _adminField(TextEditingController controller, String label, {int maxLines = 1, FocusNode? focusNode, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _NightBackground extends StatelessWidget {
  const _NightBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1023), Color(0xFF090D1A)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}


