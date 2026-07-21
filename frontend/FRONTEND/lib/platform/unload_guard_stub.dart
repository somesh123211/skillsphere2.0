// Non-web fallback: browser tab-close warnings only apply on the web (see
// unload_guard.dart's conditional export for the web implementation).
class UnloadGuard {
  static void enable({Function()? onLeft}) {}
  static void disable() {}
}
