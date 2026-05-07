import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../auth/phone_input_formatter.dart';
import '../shared/travel_app_shell.dart';
import 'avatar_image.dart';
import 'avatar_processing.dart';
import 'profile_repo.dart';

class EditAccountPage extends StatefulWidget {
  final ProfileRepo profileRepo;

  const EditAccountPage({
    super.key,
    required this.profileRepo,
  });

  @override
  State<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  static const _primaryColor = Color(0xFFD7E37A);

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _emailCode = TextEditingController();

  UserMe? _me;
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _loading = true;
  bool _saving = false;
  bool _requestingCode = false;
  bool _confirmingCode = false;
  bool _emailCodeRequested = false;
  String? _pendingEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _emailCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await widget.profileRepo.getMe();
      if (!mounted) return;
      setState(() {
        _me = me;
        _name.text = me.displayName ?? '';
        _email.text = me.email ?? '';
        _phone.text = me.phone ?? '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    final processed = await compressAvatarBytes(bytes);
    if (processed == null) {
      if (!mounted) return;
      showAuthError(
        context,
        'Не удалось подготовить фото. Попробуйте другое изображение.',
      );
      return;
    }

    setState(() {
      _avatarBytes = processed.bytes;
      _avatarMimeType = processed.mimeType;
    });
  }

  String? _avatarPayload() {
    if (_avatarBytes != null) {
      final mime = _avatarMimeType ?? 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(_avatarBytes!)}';
    }
    return _me?.avatarUrl;
  }

  Future<void> _saveProfile() async {
    final displayName = _name.text.trim();
    if (displayName.isEmpty) {
      showAuthError(context, 'Введите имя.');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await widget.profileRepo.updateMe(
        displayName: displayName,
        phone: normalizePhoneForApi(_phone.text),
        avatarUrl: _avatarPayload(),
      );
      if (!mounted) return;
      setState(() => _me = updated);
      showAuthSuccess(context, 'Профиль сохранён.');
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Не удалось сохранить данные.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestEmailCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      showAuthError(context, 'Введите корректный email.');
      return;
    }

    setState(() => _requestingCode = true);
    try {
      await widget.profileRepo.requestEmailChange(email);
      if (!mounted) return;
      setState(() {
        _emailCodeRequested = true;
        _pendingEmail = email;
      });
      showAuthSuccess(context, 'Код отправлен на новую почту.');
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Не удалось отправить код.');
    } finally {
      if (mounted) setState(() => _requestingCode = false);
    }
  }

  Future<void> _confirmEmailCode() async {
    final pendingEmail = _pendingEmail;
    if (pendingEmail == null || _emailCode.text.trim().length != 6) {
      showAuthError(context, 'Введите шестизначный код.');
      return;
    }

    setState(() => _confirmingCode = true);
    try {
      final updated = await widget.profileRepo.confirmEmailChange(
        newEmail: pendingEmail,
        code: _emailCode.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _me = updated;
        _email.text = updated.email ?? pendingEmail;
        _emailCodeRequested = false;
        _pendingEmail = null;
        _emailCode.clear();
      });
      showAuthSuccess(context, 'Почта обновлена.');
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Не удалось подтвердить новую почту.');
    } finally {
      if (mounted) setState(() => _confirmingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? avatarProvider;
    if (_avatarBytes != null) {
      avatarProvider = MemoryImage(_avatarBytes!);
    } else if (_me?.avatarUrl?.isNotEmpty ?? false) {
      avatarProvider = buildAvatarImage(_me!.avatarUrl);
    }

    return TravelAppShell(
      title: 'Редактирование',
      subtitle: 'Имя, фото, почта и телефон',
      currentTab: TravelNavTab.profile,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD7E37A)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF2B2B2B),
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: Color(0xFFD7E37A),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _pickAvatar,
                          style: _outlinedButtonStyle(),
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Изменить фото'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _fieldCard(
                    children: [
                      _label('Имя'),
                      TextField(
                        controller: _name,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Введите имя'),
                      ),
                      const SizedBox(height: 14),
                      _label('Телефон'),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [RussianPhoneInputFormatter()],
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Введите телефон'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: _filledButtonStyle(),
                          child: Text(
                            _saving ? 'Сохраняем...' : 'Сохранить данные',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _fieldCard(
                    children: [
                      _label('Почта'),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Введите новый email'),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _requestingCode ? null : _requestEmailCode,
                          style: _outlinedButtonStyle(),
                          child: Text(
                            _requestingCode
                                ? 'Отправляем...'
                                : 'Отправить код на новую почту',
                          ),
                        ),
                      ),
                      if (_emailCodeRequested) ...[
                        const SizedBox(height: 14),
                        _label('Код из письма'),
                        TextField(
                          controller: _emailCode,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('Введите код'),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _confirmingCode ? null : _confirmEmailCode,
                            style: _filledButtonStyle(),
                            child: Text(
                              _confirmingCode
                                  ? 'Подтверждаем...'
                                  : 'Подтвердить новую почту',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _fieldCard({required List<Widget> children}) {
    return TravelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _label(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      filled: true,
      fillColor: const Color(0xFF1D1D1D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: _primaryColor),
      ),
    );
  }

  ButtonStyle _filledButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: const Color(0xFF171717),
      disabledBackgroundColor: _primaryColor.withOpacity(0.55),
      disabledForegroundColor: const Color(0xFF171717).withOpacity(0.72),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Geologica',
        fontWeight: FontWeight.w300,
        fontSize: 15,
      ),
      elevation: 0,
    );
  }

  ButtonStyle _outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _primaryColor,
      side: BorderSide(color: _primaryColor.withOpacity(0.42)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Geologica',
        fontWeight: FontWeight.w300,
        fontSize: 15,
      ),
    );
  }
}
