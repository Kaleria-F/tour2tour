import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PaymentReturnPage extends StatelessWidget {
  const PaymentReturnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1D),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB6A1FF).withOpacity(0.10),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB6A1FF).withOpacity(0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFFB6A1FF),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Оплата отправлена',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Вернитесь в приложение Тур2Тур. Статус подписки обновится автоматически на странице Pro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD7E37A),
                          foregroundColor: const Color(0xFF161616),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Открыть Тур2Тур',
                          style: TextStyle(
                            fontFamily: 'Geologica',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Если оплата уже завершена, просто вернитесь в приложение и снова откройте подписку.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geologica',
                        color: Colors.white.withOpacity(0.52),
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
