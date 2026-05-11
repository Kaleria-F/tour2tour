import '../../api/api_client.dart';

class ProCheckoutSession {
  final String paymentId;
  final String status;
  final String confirmationUrl;
  final String amountValue;
  final String currency;
  final bool? isTest;

  ProCheckoutSession({
    required this.paymentId,
    required this.status,
    required this.confirmationUrl,
    required this.amountValue,
    required this.currency,
    required this.isTest,
  });

  factory ProCheckoutSession.fromJson(Map<String, dynamic> json) {
    return ProCheckoutSession(
      paymentId: (json['payment_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      confirmationUrl: (json['confirmation_url'] ?? '').toString(),
      amountValue: (json['amount_value'] ?? '').toString(),
      currency: (json['currency'] ?? 'RUB').toString(),
      isTest: json['is_test'] as bool?,
    );
  }
}

class PaymentStatus {
  final String paymentId;
  final String status;
  final bool paid;
  final bool isPremiumActivated;

  PaymentStatus({
    required this.paymentId,
    required this.status,
    required this.paid,
    required this.isPremiumActivated,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      paymentId: (json['payment_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      paid: (json['paid'] ?? false) as bool,
      isPremiumActivated: (json['is_premium_activated'] ?? false) as bool,
    );
  }
}

class PaymentsRepo {
  final ApiClient api;

  PaymentsRepo(this.api);

  Future<ProCheckoutSession> createProCheckout({
    String? returnUrl,
    String? source,
  }) async {
    final res = await api.dio.post(
      '/payments/pro/checkout',
      data: {
        if (returnUrl != null && returnUrl.trim().isNotEmpty)
          'return_url': returnUrl.trim(),
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
      },
    );
    return ProCheckoutSession.fromJson(res.data as Map<String, dynamic>);
  }

  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    final res = await api.dio.get('/payments/pro/$paymentId');
    return PaymentStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
