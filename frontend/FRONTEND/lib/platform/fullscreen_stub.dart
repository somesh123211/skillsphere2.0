// Non-web fallback: fullscreen only makes sense in a browser tab, so this
// is a no-op on mobile/desktop builds (see fullscreen.dart for the
// conditional export that picks fullscreen_web.dart on the web).
void requestFullscreen() {}

void exitFullscreen() {}
