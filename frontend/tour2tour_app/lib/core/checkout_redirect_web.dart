import 'dart:html' as html;

Future<bool> openCheckoutRedirect(String url) async {
  html.window.location.assign(url);
  return true;
}
