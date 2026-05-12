import 'checkout_redirect_stub.dart'
    if (dart.library.html) 'checkout_redirect_web.dart' as impl;

Future<bool> openCheckoutRedirect(String url) => impl.openCheckoutRedirect(url);
