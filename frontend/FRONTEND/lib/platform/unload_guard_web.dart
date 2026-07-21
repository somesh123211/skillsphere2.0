import 'dart:async';
import 'dart:html' as html;

// Shows the browser's native "leave site?" confirmation when a student
// tries to close the tab/refresh/navigate away while a quiz is active -
// the "1st warning" before they actually leave. Modern browsers show their
// own fixed wording regardless of what's set here; setting returnValue is
// what triggers that native dialog at all.
class UnloadGuard {
  static StreamSubscription<html.Event>? _sub;

  static void enable() {
    if (_sub != null) return;
    _sub = html.window.onBeforeUnload.listen((event) {
      final e = event as html.BeforeUnloadEvent;
      e.returnValue = '';
    });
  }

  static void disable() {
    _sub?.cancel();
    _sub = null;
  }
}
