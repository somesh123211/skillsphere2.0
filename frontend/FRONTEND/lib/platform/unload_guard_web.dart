import 'dart:async';
import 'dart:html' as html;

class UnloadGuard {
  static StreamSubscription<html.Event>? _sub;
  static StreamSubscription<html.Event>? _blurSub;
  static StreamSubscription<html.Event>? _visSub;

  static void enable({Function()? onLeft}) {
    if (_sub == null) {
      _sub = html.window.onBeforeUnload.listen((event) {
        final e = event as html.BeforeUnloadEvent;
        e.returnValue = '';
      });
    }
    if (_visSub == null && onLeft != null) {
      _visSub = html.document.onVisibilityChange.listen((_) {
        if (html.document.visibilityState == 'hidden') {
          onLeft();
        }
      });
    }
  }

  static void disable() {
    _sub?.cancel();
    _sub = null;
    _blurSub?.cancel();
    _blurSub = null;
    _visSub?.cancel();
    _visSub = null;
  }
}
