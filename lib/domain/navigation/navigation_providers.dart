import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShellIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

/// Manages the active tab index for the MainShell
final mainShellIndexProvider = NotifierProvider<MainShellIndexNotifier, int>(() {
  return MainShellIndexNotifier();
});
