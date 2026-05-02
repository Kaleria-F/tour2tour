import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_chrome.dart';
import '../auth/auth_ui.dart';
import '../auth/phone_input_formatter.dart';
import 'avatar_processing.dart';
import 'profile_repo.dart';

class CompleteProfilePage extends StatefulWidget {
  final ProfileRepo profileRepo;

  const CompleteProfilePage({
    super.key,
    required this.profileRepo,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
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

  String? _avatarDataUri() {
    if (_avatarBytes == null) return null;
    final mime = _avatarMimeType ?? 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(_avatarBytes!)}';
  }

  Future<void> _submit() async {
    final displayName = _name.text.trim();
    if (displayName.isEmpty) {
      showAuthError(context, 'Введите имя.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.profileRepo.updateMe(
        displayName: displayName,
        phone: normalizePhoneForApi(_phone.text),
        avatarUrl: _avatarDataUri(),
      );
      if (!mounted) return;
      context.go('/security-setup');
    } catch (_) {
      if (!mounted) return;
      showAuthError(context, 'Не удалось сохранить профиль.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      maxWidth: 560,
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 18),
      child: AuthGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrandMark(title: 'Typ2Typ'),
            const SizedBox(height: 22),
            const AuthHeadline(
              title: 'Профиль',
              fontSize: 34,
              fontWeight: FontWeight.w300,
              titleHeight: 0.92,
              description:
                  'Добавьте имя и, если хотите, аватарку. Это имя будет видно на главной странице и в профиле.',
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFF3A4438),
                      backgroundImage:
                          _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                      child: _avatarBytes == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: Color(0xFFD7E37A),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD7E37A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo_rounded,
                          size: 16,
                          color: Color(0xFF222715),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: AuthPillButton(
                label: _avatarBytes == null ? 'Добавить фото' : 'Сменить фото',
                icon: Icons.image_outlined,
                onPressed: _pickAvatar,
              ),
            ),
            const SizedBox(height: 18),
            const AuthHelperText(
              text:
                  'Фото автоматически уменьшается и сжимается перед сохранением, поэтому можно выбирать большие изображения.',
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _name,
              hintText: 'имя',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _phone,
              hintText: 'телефон',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              inputFormatters: [RussianPhoneInputFormatter()],
            ),
            const SizedBox(height: 12),
            const AuthHelperText(
              text:
                  'Телефон можно указать сразу или заполнить позже в настройках аккаунта.',
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: AuthOrganicButton(
                label: 'Сохранить',
                width: 176,
                loading: _saving,
                onTap: _saving ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
