import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../shared/travel_app_shell.dart';
import 'profile_repo.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({
    super.key,
    required this.profileRepo,
  });

  final ProfileRepo profileRepo;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const _primaryColor = Color(0xFFD7E37A);

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail']?.toString();
        if (detail != null && detail.trim().isNotEmpty) return detail.trim();
      }
    }
    return 'Не удалось отправить сообщение. Попробуйте позже.';
  }

  void _showFeedback(String message) {
    final width = MediaQuery.of(context).size.width;
    final snackWidth = width > 462 ? 430.0 : width - 32;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: snackWidth,
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Geologica',
            color: Color(0xFF171717),
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await widget.profileRepo.sendSupportMessage(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      _showFeedback('Сообщение отправлено команде приложения');
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      _showFeedback(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.white.withOpacity(0.68),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: _primaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TravelAppShell(
      title: 'Поддержка',
      subtitle: 'Напишите команде приложения',
      currentTab: TravelNavTab.profile,
      headerAction: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        tooltip: 'Закрыть',
      ),
      body: SingleChildScrollView(
        child: TravelCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Связаться с командой приложения',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Опишите вопрос, ошибку или пожелание. Сообщение будет отправлено на почту команды приложения.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _subjectCtrl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Geologica',
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: _decoration('Тема обращения'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Введите тему обращения';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _messageCtrl,
                  minLines: 7,
                  maxLines: 9,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Geologica',
                    fontWeight: FontWeight.w300,
                  ),
                  decoration: _decoration('Ваше сообщение'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Напишите сообщение';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF171717),
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Отправляем...' : 'Отправить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: const Color(0xFF171717),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
