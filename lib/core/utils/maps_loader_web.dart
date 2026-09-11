import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> loadGoogleMapsScript(String apiKey) {
  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..async = true;
  script.onload = ((web.Event _) => completer.complete()).toJS;
  script.onerror = ((web.Event _) => completer.complete()).toJS;
  web.document.head!.append(script);
  return completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () {},
  );
}
