/// Desktop window always-on-top behavior.
enum AlwaysOnTopMode {
  off,
  on,
  whenPlaying;

  String get id => name;

  static AlwaysOnTopMode fromId(String? id) {
    return AlwaysOnTopMode.values.firstWhere((m) => m.id == id, orElse: () => AlwaysOnTopMode.off);
  }
}
