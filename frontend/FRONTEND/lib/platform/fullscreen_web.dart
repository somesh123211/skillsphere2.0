import 'dart:html' as html;

void requestFullscreen() {
  html.document.documentElement?.requestFullscreen();
}

void exitFullscreen() {
  if (html.document.fullscreenElement != null) {
    html.document.exitFullscreen();
  }
}
