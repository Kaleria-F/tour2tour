import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'trips_repo.dart';

class CreateTripPage extends StatefulWidget {
  final TripsRepo tripsRepo;
  const CreateTripPage({super.key, required this.tripsRepo});

  @override
  State<CreateTripPage> createState() => _CreateTripPageState();
}

class _CreateTripPageState extends State<CreateTripPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime(2030);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? initialDate) : (_endDate ?? initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTrip() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите даты начала и окончания')),
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Дата начала не может быть позже даты окончания')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final trip = await widget.tripsRepo.createTrip(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (!mounted) return;
      if (trip != null) {
        final payload = <String, dynamic>{
          'id': trip.id,
          'title': trip.title,
          'start_date': trip.startDate,
          'end_date': trip.endDate,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Путешествие создано!')),
        );
        context.go('/trip-workspace', extra: payload);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при создании')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const _NightBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      _Logo(cs: cs),
                      const SizedBox(height: 18),
                      const Text(
                        'Создать путешествие',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Заполни ключевые параметры поездки',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Название',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _descriptionController,
                                minLines: 2,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Описание',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _pickDate(isStart: true),
                                      child: Text(_startDate == null
                                          ? 'Дата начала'
                                          : _startDate!.toLocal().toString().split(' ')[0]),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _pickDate(isStart: false),
                                      child: Text(_endDate == null
                                          ? 'Дата окончания'
                                          : _endDate!.toLocal().toString().split(' ')[0]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.primary.withOpacity(0.75)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _saving ? null : _saveTrip,
                            child: _saving
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    'Сохранить',
                                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
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
}

class _Logo extends StatelessWidget {
  final ColorScheme cs;
  const _Logo({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withOpacity(0.28)),
      ),
      child: Icon(Icons.luggage_rounded, color: cs.primary, size: 28),
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
      colors: [
        Color(0xFF0B1023),
        Color(0xFF090D1A),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    final vignette = RadialGradient(
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.55),
      ],
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
