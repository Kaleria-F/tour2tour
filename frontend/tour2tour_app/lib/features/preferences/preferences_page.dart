import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repo.dart';
import 'preferences_repo.dart';

enum QuestionType { multiSelect, singleSelect, ratingList }

class SurveyOption {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const SurveyOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class SurveyQuestion {
  final String id;
  final String title;
  final String subtitle;
  final QuestionType type;
  final List<SurveyOption> options;
  final int minSelections;

  const SurveyQuestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.options,
    this.minSelections = 1,
  });
}

class PreferencesPage extends StatefulWidget {
  final PreferencesRepo repo;
  final AuthRepo auth;
  final bool fromRecommendations;

  const PreferencesPage({
    super.key,
    required this.repo,
    required this.auth,
    this.fromRecommendations = false,
  });

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final PageController _controller = PageController();

  final List<SurveyQuestion> _questions = const [
    SurveyQuestion(
      id: 'interests',
      title: 'Что вам интересно в путешествии?',
      subtitle: 'Выберите минимум 3 направления.',
      type: QuestionType.multiSelect,
      minSelections: 3,
      options: [
        SurveyOption(id: 'history', label: 'История', icon: Icons.account_balance, color: Colors.amber),
        SurveyOption(id: 'culture', label: 'Культура', icon: Icons.theater_comedy, color: Colors.pinkAccent),
        SurveyOption(id: 'museums', label: 'Музеи', icon: Icons.museum, color: Colors.deepPurpleAccent),
        SurveyOption(id: 'architecture', label: 'Архитектура', icon: Icons.location_city, color: Colors.lightBlueAccent),
        SurveyOption(id: 'nature', label: 'Природа', icon: Icons.park, color: Colors.greenAccent),
        SurveyOption(id: 'gastronomy', label: 'Гастрономия', icon: Icons.restaurant, color: Colors.orangeAccent),
        SurveyOption(id: 'active', label: 'Активный отдых', icon: Icons.hiking, color: Colors.tealAccent),
        SurveyOption(id: 'shopping', label: 'Шопинг', icon: Icons.shopping_bag, color: Colors.cyanAccent),
        SurveyOption(id: 'photo', label: 'Фото-локации', icon: Icons.photo_camera, color: Colors.yellowAccent),
        SurveyOption(id: 'nightlife', label: 'Ночная жизнь', icon: Icons.nightlife, color: Colors.redAccent),
        SurveyOption(id: 'hidden', label: 'Необычные места', icon: Icons.explore, color: Colors.limeAccent),
        SurveyOption(id: 'family', label: 'Семейный отдых', icon: Icons.family_restroom, color: Colors.blueAccent),
      ],
    ),
    SurveyQuestion(
      id: 'trip_format',
      title: 'Какой формат отдыха вам ближе?',
      subtitle: 'Можно выбрать несколько вариантов.',
      type: QuestionType.multiSelect,
      options: [
        SurveyOption(id: 'calm', label: 'Спокойный', icon: Icons.spa, color: Colors.greenAccent),
        SurveyOption(id: 'active_format', label: 'Активный', icon: Icons.directions_run, color: Colors.orangeAccent),
        SurveyOption(id: 'intense', label: 'Насыщенный', icon: Icons.bolt, color: Colors.amberAccent),
        SurveyOption(id: 'romantic', label: 'Романтический', icon: Icons.favorite, color: Colors.pinkAccent),
        SurveyOption(id: 'friends', label: 'С друзьями', icon: Icons.groups, color: Colors.lightBlueAccent),
        SurveyOption(id: 'solo', label: 'Соло', icon: Icons.person, color: Colors.deepPurpleAccent),
      ],
    ),
    SurveyQuestion(
      id: 'travel_mode',
      title: 'С кем вы чаще путешествуете?',
      subtitle: 'Это влияет на фильтрацию рекомендаций.',
      type: QuestionType.singleSelect,
      options: [
        SurveyOption(id: 'solo', label: 'Один/одна', icon: Icons.person, color: Colors.blueAccent),
        SurveyOption(id: 'couple', label: 'С партнером', icon: Icons.favorite, color: Colors.pinkAccent),
        SurveyOption(id: 'friends', label: 'С друзьями', icon: Icons.groups, color: Colors.tealAccent),
        SurveyOption(id: 'family', label: 'С семьей', icon: Icons.family_restroom, color: Colors.greenAccent),
      ],
    ),
    SurveyQuestion(
      id: 'budget',
      title: 'Какой бюджет поездки вам ближе?',
      subtitle: 'Это поможет ранжировать места по стоимости.',
      type: QuestionType.singleSelect,
      options: [
        SurveyOption(id: 'economy', label: 'Эконом', icon: Icons.savings, color: Colors.greenAccent),
        SurveyOption(id: 'middle', label: 'Средний', icon: Icons.account_balance_wallet, color: Colors.orangeAccent),
        SurveyOption(id: 'comfort', label: 'Комфорт', icon: Icons.workspace_premium, color: Colors.amberAccent),
        SurveyOption(id: 'premium', label: 'Премиум', icon: Icons.diamond, color: Colors.pinkAccent),
      ],
    ),
    SurveyQuestion(
      id: 'pace',
      title: 'Какой темп поездки вам комфортен?',
      subtitle: 'Темп влияет на количество и тип рекомендаций в день.',
      type: QuestionType.singleSelect,
      options: [
        SurveyOption(id: 'slow', label: '1-2 места в день', icon: Icons.self_improvement, color: Colors.greenAccent),
        SurveyOption(id: 'medium', label: '3-5 мест в день', icon: Icons.tour, color: Colors.orangeAccent),
        SurveyOption(id: 'intense', label: 'Максимально насыщенно', icon: Icons.flash_on, color: Colors.redAccent),
      ],
    ),
  ];

  int _step = 0;
  bool _saving = false;
  bool _loading = true;

  final Map<String, Set<String>> _multiAnswers = {
    'interests': {},
    'trip_format': {},
  };
  final Map<String, String> _singleAnswers = {};
  final Map<String, int> _ratings = {
    'history': 3,
    'culture': 3,
    'museums': 3,
    'architecture': 3,
    'nature': 3,
    'gastronomy': 3,
    'active': 3,
    'shopping': 3,
    'photo': 3,
    'nightlife': 3,
    'hidden': 3,
    'family': 3,
    'local': 3,
    'calm': 3,
  };

  SurveyQuestion get _current => _questions[_step];
  double get _progress => (_step + 1) / _questions.length;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final profile = await widget.repo.getSurveyProfile();
      _multiAnswers['interests'] = profile.interests.toSet();
      _multiAnswers['trip_format'] = profile.tripFormats.toSet();
      if (profile.budget != null) {
        _singleAnswers['budget'] = profile.budget!;
      }
      if (profile.travelMode != null) {
        _singleAnswers['travel_mode'] = profile.travelMode!;
      }
      if (profile.pace != null) {
        _singleAnswers['pace'] = profile.pace!;
      }
      for (final entry in profile.interestWeights.entries) {
        _ratings[entry.key] = entry.value;
      }
    } catch (_) {
      // keep defaults
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _isStepValid(SurveyQuestion question) {
    switch (question.type) {
      case QuestionType.multiSelect:
        final selected = _multiAnswers[question.id] ?? <String>{};
        return selected.length >= question.minSelections;
      case QuestionType.singleSelect:
        return _singleAnswers[question.id] != null;
      case QuestionType.ratingList:
        return true;
    }
  }

  void _toggleMulti(String qid, String optionId) {
    final set = _multiAnswers.putIfAbsent(qid, () => <String>{});
    set.contains(optionId) ? set.remove(optionId) : set.add(optionId);
    setState(() {});
  }

  void _setSingle(String qid, String optionId) {
    _singleAnswers[qid] = optionId;
    setState(() {});
  }

  Future<void> _skipSurvey() async {
    setState(() => _saving = true);
    try {
      await widget.repo.setSurveyProfile(
        SurveyProfile(
          interests: const [],
          tripFormats: const [],
          budget: null,
          travelMode: null,
          pace: null,
          interestWeights: const {},
          skipped: true,
          hasCompleted: false,
        ),
      );
      if (!mounted) return;
      if (widget.fromRecommendations) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSurvey() async {
    setState(() => _saving = true);
    try {
      final selectedInterests = (_multiAnswers['interests'] ?? {}).toList();
      final filteredWeights = <String, int>{};
      for (final interest in selectedInterests) {
        filteredWeights[interest] = _ratings[interest] ?? 3;
      }
      final profile = SurveyProfile(
        interests: selectedInterests,
        tripFormats: (_multiAnswers['trip_format'] ?? {}).toList(),
        budget: _singleAnswers['budget'],
        travelMode: _singleAnswers['travel_mode'],
        pace: _singleAnswers['pace'],
        interestWeights: filteredWeights,
        skipped: false,
        hasCompleted: true,
      );
      await widget.repo.setSurveyProfile(profile);
      if (!mounted) return;
      if (widget.fromRecommendations) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (!_isStepValid(_current)) return;
    if (_step < _questions.length - 1) {
      setState(() => _step++);
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }
    _saveSurvey();
  }

  void _prev() {
    if (_step == 0) return;
    setState(() => _step--);
    _controller.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _isStepValid(_current);

    return Scaffold(
      backgroundColor: const Color(0xFF170B2C),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_step > 0)
                          GestureDetector(
                            onTap: _prev,
                            child: Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                            ),
                          )
                        else
                          const SizedBox(width: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD86B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: _saving ? null : _skipSurvey,
                          child: const Text('Пропустить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _current.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _current.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final q = _questions[index];
                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildQuestion(q),
                                  if (index == _questions.length - 1) ...[
                                    const SizedBox(height: 10),
                                    _buildRatingsCard(forceShow: true),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (canContinue && !_saving) ? _next : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canContinue ? Colors.white : Colors.white24,
                          foregroundColor: Colors.black,
                          disabledForegroundColor: Colors.white54,
                          disabledBackgroundColor: Colors.white24,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _step == _questions.length - 1 ? 'Завершить' : 'Продолжить',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: canContinue ? Colors.black : Colors.white70,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuestion(SurveyQuestion q) {
    switch (q.type) {
      case QuestionType.multiSelect:
        final selected = _multiAnswers[q.id] ?? <String>{};
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: q.options.map((option) {
            final isSelected = selected.contains(option.id);
            return _SelectableChip(
              label: option.label,
              icon: option.icon,
              iconColor: option.color,
              selected: isSelected,
              trailingIcon: isSelected ? Icons.check : Icons.add,
              onTap: () => _toggleMulti(q.id, option.id),
            );
          }).toList(),
        );
      case QuestionType.singleSelect:
        final selectedId = _singleAnswers[q.id];
        return Column(
          children: q.options.map((option) {
            final isSelected = selectedId == option.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SingleChoiceCard(
                label: option.label,
                icon: option.icon,
                iconColor: option.color,
                selected: isSelected,
                onTap: () => _setSingle(q.id, option.id),
              ),
            );
          }).toList(),
        );
      case QuestionType.ratingList:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRatingsCard({bool forceShow = false}) {
    final selectedInterests = _multiAnswers['interests'] ?? <String>{};
    final interestQuestion = _questions.firstWhere((q) => q.id == 'interests');
    final ratingItems = interestQuestion.options
        .where((option) => selectedInterests.contains(option.id))
        .map((option) => MapEntry(option.id, option.label))
        .toList();
    if (!forceShow && _step != _questions.length - 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF24133F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сила интересов (1-5)',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (ratingItems.isEmpty)
            Text(
              'Сначала выберите интересы на первом шаге.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
          ...ratingItems.map((item) {
            final key = item.key;
            final value = _ratings[key] ?? 3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.value}: $value/5',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (index) {
                      final score = index + 1;
                      final selected = score <= value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: index < 4 ? 6 : 0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _ratings[key] = score),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 30,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFFFD86B)
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFFFD86B)
                                      : Colors.white.withOpacity(0.16),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: TextStyle(
                                    color: selected ? Colors.black : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final IconData trailingIcon;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF24133F),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFFFFD86B) : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                trailingIcon,
                size: 18,
                color: selected ? Colors.black : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleChoiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _SingleChoiceCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFF24133F),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? const Color(0xFFFFD86B) : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.black : Colors.white54,
              ),
            ],
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
    return CustomPaint(
      painter: _NightPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _NightPainter extends CustomPainter {
  final _rng = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0B1023), Color(0xFF090D1A)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final vignette = RadialGradient(
      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
      stops: const [0.55, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = vignette.createShader(rect));

    final starPaint = Paint()..color = Colors.white.withOpacity(0.55);
    final starPaintDim = Paint()..color = Colors.white.withOpacity(0.22);
    final count = (size.width * size.height / 6500).clamp(70, 170).toInt();
    for (var i = 0; i < count; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height * 0.6;
      final r = _rng.nextDouble() * 1.35 + 0.2;
      canvas.drawCircle(Offset(x, y), r, (i % 3 == 0) ? starPaint : starPaintDim);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
