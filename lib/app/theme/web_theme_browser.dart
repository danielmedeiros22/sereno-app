import 'dart:js_interop';

@JS('serenoSetTheme')
external void _setTheme(JSBoolean dark);

void updateWebTheme(bool dark) => _setTheme(dark.toJS);
