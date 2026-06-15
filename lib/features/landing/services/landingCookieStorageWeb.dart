import 'dart:html' as html;

const _savedKey = 'lokka_cookie_choice_saved';
const _choiceKey = 'lokka_cookie_choice';

Future<bool> hasCookieChoice() async {
  try {
    return html.window.localStorage[_savedKey] == 'true';
  } catch (_) {
    return false;
  }
}

Future<void> saveCookieChoice(String choice) async {
  try {
    html.window.localStorage[_savedKey] = 'true';
    html.window.localStorage[_choiceKey] = choice;
  } catch (_) {}
}
