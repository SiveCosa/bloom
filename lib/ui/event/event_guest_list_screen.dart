import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/event/event.dart';
import '../../../domain/event/event_providers.dart';
import '../../../domain/event/event_guest_providers.dart';
import '../../../domain/auth/auth_providers.dart';
import '../create_event/widgets/aurora_background.dart';
import '../shared/widgets/custom_text_fields.dart';
import 'widgets/guest_list_row.dart';

Color _parseHexColor(String hexColor) {
  hexColor = hexColor.replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor';
  }
  return Color(int.parse(hexColor, radix: 16));
}

String _tabToRsvpStatus(String tabName) {
  switch (tabName.toLowerCase()) {
    case 'waitlist':
      return 'waitlisted';
    case 'requests':
    case 'requested':
      return 'requested';
    default:
      return tabName.toLowerCase();
  }
}

bool _tabMatchesInitial(String tab, String initialTab) {
  final tabLower = tab.toLowerCase();
  final initialLower = initialTab.toLowerCase();
  if (tabLower == initialLower) return true;
  if (tabLower == 'requests' && initialLower == 'requested') return true;
  return false;
}

class EventGuestListScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String? initialTab;

  const EventGuestListScreen({
    super.key,
    required this.eventId,
    this.initialTab,
  });

  @override
  ConsumerState<EventGuestListScreen> createState() =>
      _EventGuestListScreenState();
}

class _EventGuestListScreenState extends ConsumerState<EventGuestListScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _tabs = [];
  Event? _lastEvent;

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<String> _buildTabs(Event event, {required bool isHostOrCoHost}) {
    List<String> tabs = ['Going'];

    if (event.audience.requireApproval) {
      tabs.add('Requests');
    } else if (event.audience.allowMaybe) {
      tabs.add('Maybe');
    }

    if (isHostOrCoHost && event.audience.waitlistEnabled) {
      tabs.add('Waitlist');
    }

    tabs.add('Interested');

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventStreamProvider(widget.eventId));

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Event not found',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
        final isHostOrCoHost =
            userId != null &&
            (event.metadata.hostId == userId ||
                event.coHostIds.contains(userId));
        final newTabs = _buildTabs(event, isHostOrCoHost: isHostOrCoHost);

        bool tabsChanged = false;
        if (_tabs.length != newTabs.length) {
          tabsChanged = true;
        } else {
          for (int i = 0; i < _tabs.length; i++) {
            if (_tabs[i] != newTabs[i]) {
              tabsChanged = true;
              break;
            }
          }
        }

        if (tabsChanged || _lastEvent?.id != event.id) {
          _tabs = newTabs;
          _lastEvent = event;
          _tabController?.dispose();

          int initialIndex = 0;
          if (widget.initialTab != null) {
            final idx = _tabs.indexWhere(
              (t) => _tabMatchesInitial(t, widget.initialTab!),
            );
            if (idx != -1) {
              initialIndex = idx;
            }
          }

          _tabController = TabController(
            length: _tabs.length,
            vsync: this,
            initialIndex: initialIndex,
          );
        }

        final guestsAsync = ref.watch(eventGuestFilterProvider(event.id));
        final guests = guestsAsync.value ?? [];

        int getCountForTab(String tabName) {
          final targetStatus = _tabToRsvpStatus(tabName);
          return guests.where((g) {
            final status =
                (g['status'] as String? ?? g['rsvp_status'] as String? ?? '')
                    .toLowerCase();
            return status == targetStatus;
          }).length;
        }

        final palette = event.visuals.auroraColors
            .map((c) => _parseHexColor(c))
            .toList();

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              AuroraBackground(
                colors: palette.isNotEmpty
                    ? palette
                    : const [Color(0xFFAD83FE), Color(0xFF6C35DE)],
              ),
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white.withValues(alpha: 0.05),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.07),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onPressed: () => context.pop(),
                                    ),
                                    const Text(
                                      'Guestlist',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 48),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 4.0,
                                ),
                                child: RoundedTextField(
                                  controller: _searchController,
                                  hintText: 'Search guests...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.toLowerCase();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 4),
                              Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
                                      .copyWith(
                                        surfaceContainerHighest:
                                            Colors.transparent,
                                      ),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  isScrollable: false,
                                  overlayColor: WidgetStateProperty.all(
                                    Colors.transparent,
                                  ),
                                  splashFactory: NoSplash.splashFactory,
                                  indicator: const UnderlineTabIndicator(
                                    borderSide: BorderSide(
                                      color: Colors.white,
                                      width: 2.0,
                                    ),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white.withValues(
                                    alpha: 0.6,
                                  ),
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  dividerColor: Colors.transparent,
                                  tabAlignment: TabAlignment.fill,
                                  padding: EdgeInsets.zero,
                                  indicatorPadding: EdgeInsets.zero,
                                  labelPadding: EdgeInsets.zero,
                                  tabs: _tabs.map((tab) {
                                    final tabLower = tab.toLowerCase();
                                    if (tabLower == 'going' ||
                                        tabLower == 'maybe' ||
                                        tabLower == 'requests' ||
                                        tabLower == 'waitlist') {
                                      final count = getCountForTab(tab);
                                      if (count > 0) {
                                        return Tab(
                                          height: 36,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$count',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(tab),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                    return Tab(height: 36, text: tab);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SafeArea(
                          top: false,
                          child: TabBarView(
                            controller: _tabController,
                            children: _tabs
                                .map(
                                  (tab) => _GuestListTabView(
                                    event: event,
                                    tabName: tab,
                                    searchQuery: _searchQuery,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _GuestListTabView extends ConsumerWidget {
  final Event event;
  final String tabName;
  final String searchQuery;

  const _GuestListTabView({
    required this.event,
    required this.tabName,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestsAsync = ref.watch(eventGuestFilterProvider(event.id));
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isHost =
        userId != null &&
        (event.metadata.hostId == userId || event.coHostIds.contains(userId));

    return guestsAsync.when(
      data: (guests) {
        final targetStatus = _tabToRsvpStatus(tabName);

        final filteredGuests = guests.where((g) {
          final status =
              (g['status'] as String? ?? g['rsvp_status'] as String? ?? '')
                  .toLowerCase();
          if (status != targetStatus) return false;

          if (searchQuery.isEmpty) return true;

          final name = (g['name'] as String? ?? '').toLowerCase();
          final username = (g['username'] as String? ?? '').toLowerCase();
          return name.contains(searchQuery) || username.contains(searchQuery);
        }).toList();

        if (filteredGuests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'No one here yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
          itemCount: filteredGuests.length,
          itemBuilder: (context, index) {
            return GuestListRow(
              guest: filteredGuests[index],
              eventId: event.id,
              isHost: isHost,
              isEventFull: event.isFull,
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (err, stack) => Center(
        child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
