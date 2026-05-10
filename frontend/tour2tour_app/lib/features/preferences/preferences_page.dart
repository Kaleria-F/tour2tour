import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repo.dart';
import '../shared/travel_app_shell.dart';
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
  final int? tripId;

  const PreferencesPage({
    super.key,
    required this.repo,
    required this.auth,
    this.fromRecommendations = false,
    this.tripId,
  });

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  final PageController _controller = PageController();

  final List<SurveyQuestion> _questions = const [
    SurveyQuestion(
      id: 'interests',
      title: 'Что вам интересно в путешествиях?',
      subtitle: 'Выберите минимум 3 направления, чтобы рекомендации стали точнее.',
      type: QuestionType.multiSelect,
      minSelections: 3,
      options: [
        SurveyOption(id: 'history', label: 'История', icon: Icons.account_balance, color: Colors.amber),
        SurveyOption(id: 'culture', label: 'Культура', icon: Icons.theater_comedy, color: Colors.pinkAccent),
        SurveyOption(id: 'museums', label: 'Музеи', icon: Icons.museum, color: Colors.deepPurpleAccent),
        SurveyOption(id: 'architecture', label: 'Архитектура', icon: Icons.location_city, color: Colors.lightBlueAccent),
        SurveyOption(id: 'nature', label: 'Природа', icon: Icons.park, color: Colors.greenAccent),
        SurveyOption(id: 'food', label: 'Еда', icon: Icons.restaurant, color: Colors.orangeAccent),
        SurveyOption(id: 'active', label: 'Активный отдых', icon: Icons.hiking, color: Colors.tealAccent),
        SurveyOption(id: 'shopping', label: 'Шопинг', icon: Icons.shopping_bag, color: Colors.cyanAccent),
        SurveyOption(id: 'photo', label: 'Фотолокации', icon: Icons.photo_camera, color: Colors.yellowAccent),
        SurveyOption(id: 'nightlife', label: 'Ночная жизнь', icon: Icons.nightlife, color: Colors.redAccent),
        SurveyOption(id: 'hidden', label: 'Необычные места', icon: Icons.explore, color: Colors.limeAccent),
        SurveyOption(id: 'family', label: 'Семейный отдых', icon: Icons.family_restroom, color: Colors.blueAccent),
      ],
    ),
    SurveyQuestion(
      id: 'trip_format',
      title: 'Какой формат отдыха вам ближе?',
      subtitle: 'Можно выбрать несколько сценариев поездки.',
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
      title: 'С кем вы обычно путешествуете?',
      subtitle: 'Это влияет на подбор мест и темп маршрута.',
      type: QuestionType.singleSelect,
      options: [
        SurveyOption(id: 'solo', label: 'Один / одна', icon: Icons.person, color: Colors.blueAccent),
        SurveyOption(id: 'couple', label: 'С партнером', icon: Icons.favorite, color: Colors.pinkAccent),
        SurveyOption(id: 'friends', label: 'С друзьями', icon: Icons.groups, color: Colors.tealAccent),
        SurveyOption(id: 'family', label: 'С семьей', icon: Icons.family_restroom, color: Colors.greenAccent),
      ],
    ),
    SurveyQuestion(
      id: 'budget',
      title: 'Какой бюджет поездки вам ближе?',
      subtitle: 'Используем это, чтобы ранжировать рекомендации по стоимости.',
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
      subtitle: 'Темп влияет на количество мест и плотность маршрута.',
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
    'food': 3,
    'active': 3,
    'shopping': 3,
    'photo': 3,
    'nightlife': 3,
    'hidden': 3,
    'family': 3,
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
      final profile = await widget.repo.getSurveyProfile(tripId: widget.tripId);
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
        setState(() => _loading = false);
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
        tripId: widget.tripId,
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
      await widget.repo.setSurveyProfile(profile, tripId: widget.tripId);
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
    final isCompact = MediaQuery.of(context).size.width < 390;

    return Scaffold(
      body: Stack(
        children: [
          const _PreferencesBackground(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD7E37A),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 430),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                                child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Предпочтения',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Настройте подборки под свой стиль поездок.',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.66),
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _CircleIconButton(
                                  icon: Icons.close_rounded,
                                  onTap: () => context.go('/profile'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (_step > 0) ...[
                                  _CircleIconButton(
                                    icon: Icons.arrow_back_ios_new_rounded,
                                    onTap: _prev,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progress,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD7E37A),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TravelCapsuleButton(
                                  label: 'Пропустить',
                                  onTap: _saving ? () {} : _skipSurvey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TravelCard(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _current.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      height: 1.02,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _current.subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.68),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 52,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: List.generate(_questions.length, (index) {
                                        final selected = index == _step;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            right: index == _questions.length - 1 ? 0 : 8,
                                          ),
                                          child: TravelCapsuleButton(
                                            label: 'Шаг ${index + 1}',
                                            active: selected,
                                            onTap: () {},
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 340,
                                    child: PageView.builder(
                                      controller: _controller,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _questions.length,
                                      itemBuilder: (context, index) {
                                        final q = _questions[index];
                                        return SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildQuestion(q),
                                              if (index == _questions.length - 1) ...[
                                                const SizedBox(height: 14),
                                                _buildRatingsCard(forceShow: true),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: (canContinue && !_saving) ? _next : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canContinue
                                      ? const Color(0xFFD7E37A)
                                      : Colors.white.withOpacity(0.14),
                                  foregroundColor: const Color(0xFF151515),
                                  disabledForegroundColor: Colors.white54,
                                  disabledBackgroundColor:
                                      Colors.white.withOpacity(0.14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _step == _questions.length - 1
                                              ? 'Сохранить'
                                              : 'Продолжить',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: canContinue
                                                ? const Color(0xFF151515)
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TravelBottomNavBar(
                              currentTab: TravelNavTab.taste,
                            ),
                                  ],
                                ),
                              ),
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
              trailingIcon: isSelected ? Icons.check_rounded : Icons.add_rounded,
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
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сила интересов',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Оцените выбранные интересы по шкале от 1 до 5.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.64),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (ratingItems.isEmpty)
            Text(
              'Сначала выберите интересы на первом шаге.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
              ),
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 13,
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
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _ratings[key] = score),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              height: 34,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFD7E37A)
                                    : const Color(0xFF1D1D1D),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '$score',
                                  style: TextStyle(
                                    color: selected
                                        ? const Color(0xFF151515)
                                        : Colors.white70,
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
  const _SelectableChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.trailingIcon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final IconData trailingIcon;
  final VoidCallback onTap;

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
            color: selected ? const Color(0xFFD7E37A) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF151515) : iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF151515) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                trailingIcon,
                size: 18,
                color: selected ? const Color(0xFF151515) : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleChoiceCard extends StatelessWidget {
  const _SingleChoiceCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

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
            color: selected ? const Color(0xFFD7E37A) : const Color(0xFF262626),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF151515) : iconColor,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF151515) : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? const Color(0xFF151515) : Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _PreferencesBackground extends StatelessWidget {
  const _PreferencesBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151515), Color(0xFF0E0E0E)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD7E37A).withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF60712D).withOpacity(0.12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
