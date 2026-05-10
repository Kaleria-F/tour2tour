import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_ui.dart';
import '../auth/phone_input_formatter.dart';
import '../shared/travel_app_shell.dart';
import 'avatar_image.dart';
import 'avatar_processing.dart';
import 'profile_repo.dart';

class EditAccountPage extends StatefulWidget {
  const EditAccountPage({super.key, required this.profileRepo});

  final ProfileRepo profileRepo;

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
      _name.text = me.displayName ?? '';
      _email.text = me.email ?? '';
      _phone.text = me.phone ?? '';
      setState(() {
        _me = me;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAuthError(context, 'Не удалось загрузить профиль.');
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null) return;

    final processed = await compressAvatarBytes(file!.bytes!);
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
    if (_avatarBytes == null) return null;
    final mime = _avatarMimeType ?? 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(_avatarBytes!)}';
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
      setState(() {
        _me = updated;
        _name.text = updated.displayName ?? displayName;
        _email.text = updated.email ?? _email.text;
        _phone.text = updated.phone ?? _phone.text;
      });
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Не удалось сохранить данные.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestEmailCode() async {
    final newEmail = _email.text.trim();
    if (!newEmail.contains('@')) {
      showAuthError(context, 'Введите корректный email.');
      return;
    }

    setState(() => _requestingCode = true);
    try {
      await widget.profileRepo.requestEmailChange(newEmail);
      if (!mounted) return;
      setState(() {
        _emailCodeRequested = true;
        _pendingEmail = newEmail;
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
    final code = _emailCode.text.trim();
    final pendingEmail = _pendingEmail;
    if (code.length != 6) {
      showAuthError(context, 'Введите шестизначный код.');
      return;
    }
    if (pendingEmail == null || pendingEmail.isEmpty) {
      showAuthError(context, 'Сначала запросите код для новой почты.');
      return;
    }

    setState(() => _confirmingCode = true);
    try {
      final updated = await widget.profileRepo.confirmEmailChange(
        newEmail: pendingEmail,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _me = updated;
        _email.text = updated.email ?? _email.text;
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
    final avatarProvider = _avatarBytes != null
        ? MemoryImage(_avatarBytes!)
        : buildAvatarImage(_me?.avatarUrl);

    return TravelAppShell(
      title: 'Редактирование',
      subtitle: '',
      currentTab: TravelNavTab.profile,
      hideHeader: true,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.pop(false),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Редактирование',
                          style: TextStyle(
                            fontFamily: 'Geologica',
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: const Color(0xFF1A1A17),
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 44,
                                  color: Color(0xFF8E8E88),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickAvatar,
                          style: _outlinedButtonStyle(),
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 18,
                          ),
                          label: const Text('Изменить фото'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _fieldCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Имя'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _name,
                          style: _fieldTextStyle(),
                          decoration: _decoration('Введите имя'),
                        ),
                        const SizedBox(height: 16),
                        _label('Телефон'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [RussianPhoneInputFormatter()],
                          style: _fieldTextStyle(),
                          decoration: _decoration('Введите телефон'),
                        ),
                        const SizedBox(height: 18),
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
                  ),
                  const SizedBox(height: 14),
                  _fieldCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Почта'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: _fieldTextStyle(),
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
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCode,
                            keyboardType: TextInputType.number,
                            style: _fieldTextStyle(),
                            decoration: _decoration('Введите код'),
                          ),
                          if (_pendingEmail != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Код отправлен на $_pendingEmail',
                              style: const TextStyle(
                                fontFamily: 'Geologica',
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFFA8A89D),
                              ),
                            ),
                          ],
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
                  ),
                ],
              ),
            ),
    );
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Geologica',
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: Color(0xFFA8A89D),
      ),
    );
  }

  TextStyle _fieldTextStyle() {
    return const TextStyle(
      fontFamily: 'Geologica',
      fontSize: 16,
      fontWeight: FontWeight.w300,
      color: Colors.white,
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Geologica',
        fontSize: 15,
        fontWeight: FontWeight.w300,
        color: Color(0xFF8E8E88),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: _primaryColor, width: 1.4),
      ),
    );
  }

  ButtonStyle _filledButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: const Color(0xFF171712),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      textStyle: const TextStyle(
        fontFamily: 'Geologica',
        fontSize: 15,
        fontWeight: FontWeight.w300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      elevation: 0,
    );
  }

  ButtonStyle _outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _primaryColor,
      side: const BorderSide(color: _primaryColor, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      textStyle: const TextStyle(
        fontFamily: 'Geologica',
        fontSize: 14,
        fontWeight: FontWeight.w300,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
