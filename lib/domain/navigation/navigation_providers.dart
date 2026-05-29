import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShellIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

/// Manages the active tab index for the MainShell
final mainShellIndexProvider = NotifierProvider<MainShellIndexNotifier, int>(
  () {
    return MainShellIndexNotifier();
  },
);

class HomeTabTapNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Tracks taps on the active Home tab to trigger page refresh
final homeTabTapProvider = NotifierProvider<HomeTabTapNotifier, int>(() {
  return HomeTabTapNotifier();
});

class DiscoverTabTapNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Tracks taps on the active Discover tab to trigger page refresh
final discoverTabTapProvider = NotifierProvider<DiscoverTabTapNotifier, int>(
  () {
    return DiscoverTabTapNotifier();
  },
);
