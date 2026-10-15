import 'dart:js_interop';
import 'dart:typed_data';

@JS('serenoSaveReport')
external JSPromise<JSAny?> _saveReport(
  JSUint8Array bytes,
  JSString name,
  JSString mimeType,
);

Future<void> saveDesktopReport(Uint8List bytes, String name, String mimeType) =>
    _saveReport(bytes.toJS, name.toJS, mimeType.toJS).toDart;
