import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bloom/domain/event/event.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/domain/auth/auth_providers.dart';
import 'package:bloom/ui/create_event/widgets/aurora_background.dart';
import 'package:bloom/ui/shared/widgets/bloom_loading_indicator.dart';
import 'package:bloom/ui/shared/widgets/event_weather_card.dart';
import 'package:bloom/domain/event/event_visibility.dart';
import 'package:bloom/domain/event/event_extra.dart';
import 'package:bloom/domain/event/create_event_state.dart';
import 'package:bloom/data/firebase_provider.dart' show firestoreProvider;
import 'package:bloom/data/event/event_repository.dart';

import 'widgets/event_rsvp_bar.dart';
import 'widgets/guest_list_card.dart';
import 'widgets/host_control_bar.dart';
import 'widgets/invite_friends_sheet.dart';
import '../create_event/widgets/host_invite_section.dart';
import 'package:bloom/ui/create_event/widgets/rsvp_option_preview.dart';
import '../shared/widgets/event_map_card.dart';
import 'package:bloom/domain/notification/notification_model.dart';

class EventInvitationScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventInvitationScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventInvitationScreen> createState() =>
      _EventInvitationScreenState();
}

class _EventInvitationScreenState extends ConsumerState<EventInvitationScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _sheetSize = ValueNotifier(0.55);
  bool _isDescriptionExpanded = false;
  bool _isDeleting = false;
  bool _hasDeleted = false;
  bool _deleteDenied = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      if (_sheetController.isAttached) {
        _sheetSize.value = _sheetController.size;
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _sheetSize.dispose();
    super.dispose();
  }

  Color _parseHexColor(String hex) {
    String hexStr = hex.replaceFirst('#', '');
    if (hexStr.length == 6) {
      hexStr = 'FF$hexStr';
    } else if (hexStr.length == 8 && hexStr.startsWith('0x')) {
      hexStr = hexStr.substring(2);
    }
    try {
      return Color(int.parse(hexStr, radix: 16));
    } catch (e) {
      return const Color(0xFFAD83FE); // Fallback to a brand-aligned purple
    }
  }

  Widget _buildMessageScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String buttonText = 'Return Home',
    Color? buttonColor,
    VoidCallback? onButtonPressed,
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Spacer(),
              Icon(icon, color: iconColor, size: 80),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onButtonPressed ?? () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor ?? const Color(0xFFAD83FE),
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0E12),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFAD83FE)),
              ),
              SizedBox(height: 16),
              Text(
                'Deleting event...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_deleteDenied) {
      return _buildMessageScreen(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.orangeAccent,
        title: 'OOPS!',
        subtitle: 'You cant delete this event, you are just a cohost.',
      );
    }

    if (_hasDeleted) {
      return _buildMessageScreen(
        icon: Icons.delete_forever_rounded,
        iconColor: Colors.white70,
        title: 'Event Deleted',
        buttonText: 'Back',
        buttonColor: Colors.blue,
        onButtonPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      );
    }

    final eventAsync = ref.watch(eventStreamProvider(widget.eventId));
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return _buildMessageScreen(
            icon: Icons.delete_forever_rounded,
            iconColor: Colors.white70,
            title: 'Event Deleted',
            buttonText: 'Back',
            buttonColor: Colors.blue,
            onButtonPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          );
        }

        final bool isHost =
            currentUser?.uid == event.metadata.hostId ||
            event.coHostIds.contains(currentUser?.uid);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E12),
          body: ValueListenableBuilder<double>(
            valueListenable: _sheetSize,
            builder: (context, sheetSize, child) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (sheetSize <= 0.32 && _sheetController.isAttached) {
                    _sheetController.animateTo(
                      0.55,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
                onVerticalDragEnd: (details) {
                  if (sheetSize <= 0.32 &&
                      _sheetController.isAttached &&
                      (details.primaryVelocity ?? 0) < -200) {
                    _sheetController.animateTo(
                      0.55,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
                child: child!,
              );
            },
            child: Stack(
              children: [
                // 2. Poster Image + Glow (Reactive)
                ValueListenableBuilder<double>(
                  valueListenable: _sheetSize,
                  builder: (context, size, child) {
                    final double screenHeight = MediaQuery.of(
                      context,
                    ).size.height;
                    final double topBarHeight =
                        MediaQuery.of(context).padding.top + 56;
                    final double minimizedProgress =
                        ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                    final double expandedProgress =
                        ((size - 0.55) / (0.88 - 0.55)).clamp(0.0, 1.0);
                    final double posterOpacity = (1.0 - expandedProgress).clamp(
                      0.0,
                      1.0,
                    );

                    final double actualPosterHeight =
                        MediaQuery.of(context).size.width /
                        (event.visuals.aspectRatio > 0
                            ? event.visuals.aspectRatio
                            : 1.0);
                    final bool isSquare =
                        (event.visuals.aspectRatio - 1.0).abs() < 0.1;
                    final double sheetTopMinimized =
                        screenHeight * (1.0 - 0.28);
                    final double availableSpaceMinimized =
                        sheetTopMinimized - topBarHeight;

                    final double statusBarHeight = MediaQuery.of(
                      context,
                    ).padding.top;
                    final double targetTop = isSquare
                        ? topBarHeight +
                              (availableSpaceMinimized - actualPosterHeight) / 2
                        : topBarHeight;

                    final double posterTop =
                        ui.lerpDouble(
                          statusBarHeight,
                          targetTop,
                          minimizedProgress,
                        ) ??
                        statusBarHeight;

                    return Positioned(
                      top: posterTop,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_sheetController.isAttached) {
                            _sheetController.animateTo(
                              0.28,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOutCubic,
                            );
                          }
                        },
                        child: Opacity(
                          opacity: posterOpacity,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  if (minimizedProgress > 0)
                                    BoxShadow(
                                      color:
                                          (event.visuals.auroraColors.isNotEmpty
                                                  ? _parseHexColor(
                                                      event
                                                          .visuals
                                                          .auroraColors[0],
                                                    )
                                                  : const Color(0xFFAD83FE))
                                              .withValues(
                                                alpha:
                                                    0.45 *
                                                    minimizedProgress *
                                                    (1.0 - expandedProgress),
                                              ),
                                      blurRadius: 120,
                                      spreadRadius: 40,
                                    ),
                                ],
                              ),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: AspectRatio(
                                  aspectRatio: event.visuals.aspectRatio,
                                  child: event.visuals.posterUrl != null
                                      ? Image.network(
                                          event.visuals.posterUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (context, child, progress) {
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    Container(
                                                      color: Colors.grey[900],
                                                    ),
                                                    const Center(
                                                      child:
                                                          BloomLoadingIndicator(
                                                            size: 36,
                                                          ),
                                                    ),
                                                  ],
                                                );
                                              },
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey[900],
                                                  ),
                                        )
                                      : Container(color: Colors.grey[900]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 4. Draggable Scrollable Sheet
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.55,
                  minChildSize: 0.28,
                  maxChildSize: 0.88,
                  snap: true,
                  snapSizes: const [0.28, 0.55, 0.88],
                  builder: (context, scrollController) {
                    return GestureDetector(
                      onTap: () {
                        if (_sheetSize.value < 0.45) {
                          _sheetController.animateTo(
                            0.55,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        }
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                          child: Stack(
                            children: [
                              // 1. Aurora Background (Reactive)
                              ValueListenableBuilder<double>(
                                valueListenable: _sheetSize,
                                child: AuroraBackground(
                                  colors: event.visuals.auroraColors
                                      .map((c) => _parseHexColor(c))
                                      .toList(),
                                ),
                                builder: (context, size, childWidget) {
                                  final double minimizedProgress =
                                      ((0.55 - size) / (0.55 - 0.28)).clamp(
                                        0.0,
                                        1.0,
                                      );
                                  final double opacity =
                                      (1.0 - minimizedProgress).clamp(0.0, 1.0);
                                  return Stack(
                                    children: [
                                      Positioned(
                                        top:
                                            -(MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                (1.0 - size)),
                                        left: 0,
                                        right: 0,
                                        height: MediaQuery.of(
                                          context,
                                        ).size.height,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: childWidget,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: opacity,
                                          child: Container(
                                            color: Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              Column(
                                children: [
                                  SizedBox(
                                    height: 25,
                                    width: double.infinity,
                                    child: Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: CustomScrollView(
                                      controller: scrollController,
                                      physics: const BouncingScrollPhysics(),
                                      slivers: [
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              15,
                                              0,
                                              15,
                                              0,
                                            ),
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 12),
                                                _buildVisibilityPill(event),
                                                const SizedBox(height: 16),
                                                // Event Title
                                                ShaderMask(
                                                  shaderCallback: (bounds) =>
                                                      ui.Gradient.linear(
                                                        Offset.zero,
                                                        Offset(bounds.width, 0),
                                                        [
                                                          Colors.white,
                                                          Colors.white
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                        ],
                                                      ),
                                                  child: Text(
                                                    event.title,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 32,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      height: 1.1,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 25),

                                                ValueListenableBuilder<double>(
                                                  valueListenable: _sheetSize,
                                                  builder: (context, size, child) {
                                                    final double
                                                    minimizedProgress =
                                                        ((0.55 - size) /
                                                                (0.55 - 0.28))
                                                            .clamp(0.0, 1.0);
                                                    return Column(
                                                      children: [
                                                        _buildDateRow(event),
                                                        if (event.location !=
                                                            null) ...[
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          Opacity(
                                                            opacity:
                                                                (1.0 -
                                                                        minimizedProgress)
                                                                    .clamp(
                                                                      0.0,
                                                                      1.0,
                                                                    ),
                                                            child:
                                                                _buildLocationRow(
                                                                  event,
                                                                ),
                                                          ),
                                                        ],
                                                        const SizedBox(
                                                          height: 25,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SliverToBoxAdapter(
                                          child: ValueListenableBuilder<double>(
                                            valueListenable: _sheetSize,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 15,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildDescriptionCard(event),
                                                  const SizedBox(height: 16),
                                                  _buildGuestList(event),
                                                  const SizedBox(height: 16),
                                                  Consumer(
                                                    builder: (context, ref, child) {
                                                      final hostProfile = ref
                                                          .watch(
                                                            userProfileStreamProvider(
                                                              event
                                                                  .metadata
                                                                  .hostId,
                                                            ),
                                                          )
                                                          .value;
                                                      final List<
                                                        Map<String, dynamic>
                                                      >
                                                      resolvedCoHosts = [];
                                                      for (final coHostId
                                                          in event.coHostIds) {
                                                        final coHostProfileAsync =
                                                            ref.watch(
                                                              userProfileStreamProvider(
                                                                coHostId,
                                                              ),
                                                            );
                                                        final coHostProfile =
                                                            coHostProfileAsync
                                                                .value;
                                                        if (coHostProfile !=
                                                            null) {
                                                          resolvedCoHosts.add({
                                                            'uid': coHostId,
                                                            ...coHostProfile,
                                                          });
                                                        }
                                                      }
                                                      return HostPreviewWidget(
                                                        userProfile:
                                                            hostProfile,
                                                        coHosts:
                                                            resolvedCoHosts,
                                                      );
                                                    },
                                                  ),
                                                  if (event.location !=
                                                      null) ...[
                                                    const SizedBox(height: 16),
                                                    _buildWeatherCard(event),
                                                    const SizedBox(height: 16),
                                                    Builder(
                                                      builder: (context) {
                                                        final parsedColors = event
                                                            .visuals
                                                            .auroraColors
                                                            .map((c) {
                                                              var hexString = c
                                                                  .replaceAll(
                                                                    '#',
                                                                    '',
                                                                  );
                                                              if (hexString.length == 6) {
                                                                hexString = 'FF$hexString';
                                                              }
                                                              return Color(
                                                                int.parse(
                                                                  hexString,
                                                                  radix: 16,
                                                                ),
                                                              );
                                                            })
                                                            .toList();
                                                        return EventMapCard(
                                                          event: event,
                                                          themeColor:
                                                              parsedColors
                                                                  .isNotEmpty
                                                              ? parsedColors
                                                                    .first
                                                              : Colors.blue,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                  if (isHost) ...[
                                                    const SizedBox(height: 16),
                                                    _buildRsvpOptionPreview(
                                                      event,
                                                    ),
                                                  ],
                                                  const SizedBox(height: 120),
                                                ],
                                              ),
                                            ),
                                            builder: (context, size, childWidget) {
                                              if (size < 0.4) {
                                                return const SizedBox.shrink();
                                              }
                                              return childWidget!;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 5. Contextual Top App Bar
                _buildTopAppBar(isHost, event),

                // 6. Bottom Gradient Grounding (Reactive)
                ValueListenableBuilder<double>(
                  valueListenable: _sheetSize,
                  builder: (context, size, child) {
                    final double minimizedProgress =
                        ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 150,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // 7. Fixed Action Bar (RSVP or Host Controls)
                Positioned(
                  left: 15,
                  right: 15,
                  bottom: 30,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _sheetSize,
                    builder: (context, size, child) {
                      final double opacity = ((size - 0.28) / (0.45 - 0.28))
                          .clamp(0.0, 1.0);

                      if (opacity <= 0) return const SizedBox.shrink();

                      return Opacity(
                        opacity: opacity,
                        child: IgnorePointer(
                          ignoring: opacity < 0.5,
                          child: isHost
                              ? HostControlBar(
                                  event: event,
                                  onGoingPressed: (tab) {
                                    context.push(
                                      '/event/${event.id}/guests${tab != null ? '?tab=$tab' : ''}',
                                    );
                                  },
                                  onInvitePressed: () =>
                                      _showInviteFriendsSheet(context, event),
                                  onNudgePressed: () =>
                                      _nudgeAllPendingGuests(context, event),
                                )
                              : EventRsvpBar(eventId: widget.eventId),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0B0E12),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFF0B0E12),
        body: Stack(
          children: [
            Positioned.fill(
              child: AuroraBackground(
                colors: const [Color(0xFF2D2D2D), Color(0xFF1A1A1A)],
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white70,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'This event is no longer available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'It may have been cancelled or moved. Check back later!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(bool isHost, Event event) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTopButton(
                const Icon(Icons.close, color: Colors.black, size: 22),
                () => context.pop(),
              ),
              Row(
                children: [
                  if (isHost) ...[
                    _buildTopButton(
                      const Icon(
                        Icons.mode_edit_outline,
                        color: Colors.black,
                        size: 22,
                      ),
                      () async {
                        // Edit logic
                        final router = GoRouter.of(context);
                        final hostId = event.metadata.hostId;
                        final hostProfile = await ref.read(
                          userProfileFutureProvider(hostId).future,
                        );
                        final List<Map<String, dynamic>> resolvedCoHosts = [];
                        for (final coHostId in event.coHostIds) {
                          final profile = await ref.read(
                            userProfileFutureProvider(coHostId).future,
                          );
                          if (profile != null) {
                            resolvedCoHosts.add({'uid': coHostId, ...profile});
                          }
                        }
                        ref
                            .read(createEventProvider.notifier)
                            .loadEventForEditing(
                              event,
                              hostProfile,
                              resolvedCoHosts,
                            );
                        router.push('/create-event');
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (!isHost) ...[
                    _AppBarInterestedButton(eventId: event.id),
                    const SizedBox(width: 10),
                  ],
                  _buildTopButton(
                    Transform.flip(
                      flipX: true,
                      child: const Icon(
                        Icons.reply_rounded,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                    () {
                      _showInviteFriendsSheet(context, event);
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildTopButton(
                    const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                    () {
                      // Options logic
                      _showOptionsModal(context, event, isHost);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(Widget child, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildVisibilityPill(Event event) {
    final visibility = event.audience.visibility;
    final timeStatus = _getTimeStatusText(event);
    final status = event.computedStatus;
    final isLive = status == EventStatus.active && event.timing.isOngoing;

    String text = visibility.title;
    if (visibility == EventVisibility.public ||
        visibility == EventVisibility.private) {
      text += ' event';
    }

    if (timeStatus.isNotEmpty) {
      text += ' • $timeStatus';
    }

    final accentColor = Color(event.statusColorValue);
    final useAccent =
        timeStatus.isNotEmpty &&
        status != EventStatus.active; // For Cancelled/Ended
    final isSpecial = isLive || useAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSpecial
                ? accentColor.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSpecial
                  ? accentColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: FittedBox(
                  child: Icon(
                    visibility.filledIconData,
                    color: isSpecial ? accentColor : Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isSpecial
                      ? accentColor
                      : Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTimeStatusText(Event event) {
    if (event.metadata.status == EventStatus.cancelled) return 'Cancelled';
    if (event.timing.isPast) return 'Ended';

    final now = DateTime.now();
    if (event.timing.isOngoing) return 'Live now';

    final start = event.timing.startDate;
    if (start != null && event.timing.isUpcoming) {
      final diff = start.difference(now);
      if (diff.inHours < 24) {
        if (diff.inHours >= 1) {
          return 'Starts in ${diff.inHours}h';
        } else if (diff.inMinutes >= 1) {
          return 'Starts in ${diff.inMinutes}m';
        } else {
          return 'Starting now';
        }
      }
    }
    return '';
  }

  Widget _buildDateRow(Event event) {
    final start = event.timing.startDate;
    final end = event.timing.endDate;
    final startTbd = event.timing.startTimeTbd;
    final endTbd = event.timing.endTimeTbd;

    if (start == null) return const SizedBox.shrink();

    String startStr = DateFormat('EEE, d MMM').format(start);
    if (!startTbd) {
      startStr += ' ${DateFormat('ha').format(start).toLowerCase()}';
    }

    String display = startStr;
    if (end != null) {
      String endStr = '';
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        if (!endTbd) {
          endStr = DateFormat('ha').format(end).toLowerCase();
        }
      } else {
        endStr = DateFormat('EEE, d MMM').format(end);
        if (!endTbd) {
          endStr += ' ${DateFormat('ha').format(end).toLowerCase()}';
        }
      }
      if (endStr.isNotEmpty) {
        display += ' \u2014 $endStr';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                display,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(Event event) {
    if (event.location == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            event.location!.displayName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(Event event) {
    final bool hasTags = event.tags.isNotEmpty;
    final bool hasDesc = event.description.isNotEmpty;
    final bool hasExtras = event.extras.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTags) ...[
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: event.tags
                        .map((tag) => _buildTagChip(tag))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 25),
                _buildSeparator(),
                const SizedBox(height: 25),
              ],

              _buildLogisticsSection(event),

              if (hasExtras) ...[
                const SizedBox(height: 25),
                ...(() {
                  final auroraColors = event.visuals.auroraColors
                      .map((c) => _parseHexColor(c))
                      .toList();
                  final sortedExtras = [...event.extras]
                    ..sort((a, b) {
                      final aIsLink = a.url != null && a.url!.isNotEmpty;
                      final bIsLink = b.url != null && b.url!.isNotEmpty;
                      if (aIsLink && !bIsLink) return -1;
                      if (!aIsLink && bIsLink) return 1;
                      return 0;
                    });

                  return List.generate(sortedExtras.length, (index) {
                    final extra = sortedExtras[index];
                    final bool isLink =
                        extra.url != null && extra.url!.isNotEmpty;
                    final Color textColor = isLink
                        ? _getBestExtraColor(auroraColors)
                        : Colors.white;
                    final bool isLast = index == sortedExtras.length - 1;

                    return Column(
                      children: [
                        GestureDetector(
                          onTap: isLink
                              ? () async {
                                  final url = extra.url!.trim();
                                  final uri = Uri.parse(
                                    url.startsWith('http')
                                        ? url
                                        : 'https://$url',
                                  );
                                  try {
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.platformDefault,
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Error launching $uri: $e');
                                  }
                                }
                              : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(
                                isLink ? Icons.link : extra.type.icon,
                                color: isLink
                                    ? textColor
                                    : Colors.white.withValues(alpha: 0.6),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  extra.displayText,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: isLink
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isLink) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: textColor.withValues(alpha: 0.4),
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isLast) const SizedBox(height: 25),
                      ],
                    );
                  });
                })(),
              ],

              if (hasDesc) ...[
                const SizedBox(height: 25),
                _buildSeparator(),
                const SizedBox(height: 25),
                _buildExpandableDescription(event.description),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      height: 1,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Color _getBestExtraColor(List<Color> colors) {
    if (colors.isEmpty) return const Color(0xFF6C8EEF);
    Color best = colors.first;
    double maxLuminance = best.computeLuminance();
    for (final color in colors) {
      final lum = color.computeLuminance();
      if (lum > maxLuminance) {
        maxLuminance = lum;
        best = color;
      }
    }
    if (maxLuminance < 0.3) return const Color(0xFF6C8EEF);
    return best;
  }

  Widget _buildExpandableDescription(String text) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: _getFormattedDescriptionSpan(text, null),
          textDirection: ui.TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: constraints.maxWidth);

        final bool needsExpansion = textPainter.height > 200;

        return StatefulBuilder(
          builder: (context, setState) {
            final bool isExpanded = _isDescriptionExpanded || !needsExpansion;

            return GestureDetector(
              onTap: needsExpansion
                  ? () => setState(
                      () => _isDescriptionExpanded = !_isDescriptionExpanded,
                    )
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: isExpanded ? double.infinity : 200,
                    ),
                    child: needsExpansion
                        ? ShaderMask(
                            shaderCallback: (bounds) {
                              if (isExpanded) {
                                return const LinearGradient(
                                  colors: [Colors.white, Colors.white],
                                ).createShader(bounds);
                              }
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: const [0.7, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Text.rich(
                              _getFormattedDescriptionSpan(text, null),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          )
                        : Text.rich(
                            _getFormattedDescriptionSpan(text, null),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                  ),
                  if (needsExpansion) ...[
                    const SizedBox(height: 25),
                    Center(
                      child: Text(
                        _isDescriptionExpanded ? 'Show less' : 'Read more',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogisticsSection(Event event) {
    int totalSpotsTaken = event.liveCounts.going;
    final guestsAsync = ref.watch(eventGuestsProvider(event.id));
    if (guestsAsync.hasValue) {
      final guestsData = guestsAsync.value ?? [];
      int actualGoing = 0;
      for (final g in guestsData) {
        if (g['status'] == 'going' || g['rsvp_status'] == 'going') {
          actualGoing += 1 + ((g['plusOnesCount'] as num?)?.toInt() ?? 0);
        }
      }
      totalSpotsTaken = actualGoing;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.audience.rsvpDeadline != null) ...[
          _buildAudienceRow(
            icon: Icons.hourglass_bottom_rounded,
            text:
                'RSVP by ${DateFormat('d MMMM yyyy').format(event.audience.rsvpDeadline!)}',
          ),
          const SizedBox(height: 25),
        ],
        _buildAudienceRow(
          icon: Icons.groups_rounded,
          text: event.audience.capacity != null
              ? '${(event.audience.capacity! - totalSpotsTaken).clamp(0, event.audience.capacity!)}/${event.audience.capacity} spots available'
              : 'Unlimited spots available',
        ),
        const SizedBox(height: 25),
        _buildAudienceRow(
          icon: Icons.person_add_rounded,
          text: event.audience.maxPlusOnes > 0
              ? '+${event.audience.maxPlusOnes} guests allowed'
              : 'No plus ones allowed',
        ),
      ],
    );
  }

  Widget _buildAudienceRow({
    IconData? icon,
    Widget? customIcon,
    required String text,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child:
              customIcon ??
              Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  TextSpan _getFormattedDescriptionSpan(String text, int? maxLength) {
    String displayStr = (maxLength != null && text.length > maxLength)
        ? text.substring(0, maxLength)
        : text;

    final List<String> lines = displayStr.split('\n');
    final List<InlineSpan> lineSpans = [];

    const baseStyle = TextStyle(color: Colors.white, fontSize: 14, height: 1.5);

    // Matches inline bold (*bold*) and inline heading (!heading!)
    final pattern = RegExp(
      r'(\*[^\s\*](?:[^*]*?[^\s\*])?\*)|(![^\s!](?:[^!]*?[^\s!])?!)',
    );

    for (int i = 0; i < lines.length; i++) {
      String lineText = lines[i];

      // Check if it is a list item
      final trimmedLine = lineText.trimLeft();
      if (trimmedLine.startsWith('* ')) {
        final indentCount = lineText.length - trimmedLine.length;
        final indent = ' ' * indentCount;
        lineText = '$indent•  ${trimmedLine.substring(2)}';
      } else if (trimmedLine.startsWith('- ')) {
        final indentCount = lineText.length - trimmedLine.length;
        final indent = ' ' * indentCount;
        lineText = '$indent•  ${trimmedLine.substring(2)}';
      }

      final List<TextSpan> lineChildren = [];
      int lastMatchEnd = 0;

      for (final match in pattern.allMatches(lineText)) {
        if (match.start > lastMatchEnd) {
          lineChildren.add(
            TextSpan(
              text: lineText.substring(lastMatchEnd, match.start),
              style: baseStyle,
            ),
          );
        }

        final matchText = match.group(0)!;

        if (matchText.startsWith('*')) {
          lineChildren.add(
            TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        } else if (matchText.startsWith('!')) {
          lineChildren.add(
            TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 16.0,
              ),
            ),
          );
        }

        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < lineText.length) {
        lineChildren.add(
          TextSpan(text: lineText.substring(lastMatchEnd), style: baseStyle),
        );
      }

      lineSpans.add(TextSpan(children: lineChildren));

      if (i < lines.length - 1) {
        lineSpans.add(const TextSpan(text: '\n', style: baseStyle));
      }
    }

    return TextSpan(children: lineSpans);
  }

  Widget _buildWeatherCard(Event event) {
    if (event.location == null) return const SizedBox.shrink();
    return EventWeatherCard(
      location: event.location,
      startDate: event.timing.startDate,
    );
  }

  Widget _buildGuestList(Event event) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        context.push('/event/${event.id}/guests');
      },
      child: GuestListCard(
        event: event,
        onInvitePressed: () => _showInviteFriendsSheet(context, event),
      ),
    );
  }

  void _showInviteFriendsSheet(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: InviteFriendsSheet(event: event),
        ),
      ),
    );
  }

  Future<void> _nudgeAllPendingGuests(BuildContext context, Event event) async {
    final guestsAsync = ref.read(eventGuestsProvider(event.id));
    final guests = guestsAsync.value;
    if (guests == null) return;

    final pendingGuests = guests.where((g) {
      final status = g['status'] as String? ?? 'invited';
      return status != 'going' &&
          status != 'declined' &&
          status != 'not_going';
    }).toList();

    final selectedUids = pendingGuests.map((g) => g['uid'] as String?).whereType<String>().toList();

    if (selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending guests to nudge.')),
      );
      return;
    }

    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser == null) return;

    final currentUserProfile = await ref.read(userProfileFutureProvider(currentUser.uid).future);
    final firestore = ref.read(firestoreProvider);
    final batch = firestore.batch();

    String message = "Nudge nudge. Don't forget to RSVP to ${event.title}";
    if (event.audience.rsvpDeadline != null) {
      final deadlineStr = DateFormat('MMM d, h:mm a').format(event.audience.rsvpDeadline!);
      message += " by $deadlineStr";
    } else {
      message += "!";
    }

    for (final uid in selectedUids) {
      final docRef = firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc();
      final notification = AppNotification(
        id: docRef.id,
        type: NotificationType.eventNudge,
        createdAt: DateTime.now(),
        actorId: currentUser.uid,
        actorUsername: currentUserProfile?['name'] ?? currentUser.displayName ?? 'A host',
        actorAvatarUrl: currentUserProfile?['profile_image_url'],
        targetId: event.id,
        targetName: event.title,
        targetImageUrl: event.visuals.posterUrl,
        message: message,
      );
      batch.set(docRef, notification.toFirestore());
    }

    try {
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3B4E), Color(0xFF1F2937)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All pending guests have been nudged',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending nudges: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending nudges: $e')),
        );
      }
    }
  }

  void _showOptionsModal(BuildContext context, Event event, bool isHost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15191D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isHost ? 'Host Options' : 'Event Options',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            if (isHost) ...[
              _buildReminderOption(
                Icons.mode_edit_outline,
                'Edit Event',
                () async {
                  final router = GoRouter.of(context);
                  Navigator.pop(modalContext);
                  final hostId = event.metadata.hostId;
                  final hostProfile = await ref.read(
                    userProfileFutureProvider(hostId).future,
                  );
                  final List<Map<String, dynamic>> resolvedCoHosts = [];
                  for (final coHostId in event.coHostIds) {
                    final profile = await ref.read(
                      userProfileFutureProvider(coHostId).future,
                    );
                    if (profile != null) {
                      resolvedCoHosts.add(profile);
                    }
                  }
                  ref
                      .read(createEventProvider.notifier)
                      .loadEventForEditing(event, hostProfile, resolvedCoHosts);
                  router.push('/create-event');
                },
              ),
              const SizedBox(height: 12),
              _buildReminderOption(
                Icons.cancel_outlined,
                'Cancel Event',
                () async {
                  Navigator.pop(modalContext);
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(0xFF15191D),
                      title: const Text(
                        'Cancel Event',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Are you sure you want to cancel this event? This will notify your guests.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text(
                            'No',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text(
                            'Yes, Cancel',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final cancelledEvent = event.copyWith(
                      metadata: event.metadata.copyWith(
                        status: EventStatus.cancelled,
                        updatedAt: DateTime.now(),
                      ),
                    );
                    await ref
                        .read(eventRepositoryProvider)
                        .updateEvent(cancelledEvent);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event has been cancelled.'),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildReminderOption(
                Icons.delete_outline_rounded,
                'Delete Event',
                () async {
                  Navigator.pop(modalContext);
                  final currentUser = ref
                      .read(firebaseAuthProvider)
                      .currentUser;
                  if (event.metadata.hostId != currentUser?.uid) {
                    setState(() {
                      _deleteDenied = true;
                    });
                    return;
                  }

                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: const Color(0xFF15191D),
                      title: const Text(
                        'Delete Event',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Are you sure you want to permanently delete this event? This action cannot be undone.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() {
                      _isDeleting = true;
                    });
                    try {
                      await ref
                          .read(eventRepositoryProvider)
                          .deleteEvent(event);
                      if (context.mounted) {
                        setState(() {
                          _isDeleting = false;
                          _hasDeleted = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Event has been permanently deleted.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setState(() {
                          _isDeleting = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting event: $e')),
                        );
                      }
                    }
                  }
                },
              ),
            ] else ...[
              _buildReminderOption(Icons.reply_rounded, 'Share Event', () {
                Navigator.pop(modalContext);
                Share.share('Check out ${event.title} on Bloom!');
              }),
              const SizedBox(height: 12),
              _buildReminderOption(
                Icons.exit_to_app_rounded,
                'Leave Event',
                () async {
                  Navigator.pop(modalContext);
                  final currentUser = ref
                      .read(firebaseAuthProvider)
                      .currentUser;
                  if (currentUser != null) {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (leaveDialogContext) => AlertDialog(
                        backgroundColor: const Color(0xFF15191D),
                        title: const Text(
                          'Leave Event',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Are you sure you want to leave this event?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(leaveDialogContext, false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(leaveDialogContext, true),
                            child: const Text(
                              'Leave',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref
                          .read(eventRepositoryProvider)
                          .updateRSVP(event.id, currentUser.uid, 'declined');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You have left the event.'),
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRsvpOptionPreview(Event event) {
    final requireApproval = event.audience.requireApproval;
    final allowMaybe = event.audience.allowMaybe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            'RSVP SETTING',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          height: 75,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(37.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: requireApproval
              ? const Row(
                  children: [
                    RsvpOptionPreview(
                      icon: Icons.add_circle_outline,
                      label: 'Get on the list',
                    ),
                  ],
                )
              : Row(
                  children: [
                    const RsvpOptionPreview(
                      icon: Icons.check_circle_outline,
                      label: 'Going',
                    ),
                    _buildVerticalDivider(),
                    if (allowMaybe) ...[
                      const RsvpOptionPreview(
                        icon: Icons.help_outline,
                        label: 'Maybe',
                      ),
                      _buildVerticalDivider(),
                    ],
                    const RsvpOptionPreview(
                      icon: Icons.cancel_outlined,
                      label: 'Decline',
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

Widget _buildReminderOption(IconData icon, String title, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withValues(alpha: 0.2),
            size: 20,
          ),
        ],
      ),
    ),
  );
}

class _AppBarInterestedButton extends ConsumerStatefulWidget {
  final String eventId;

  const _AppBarInterestedButton({required this.eventId});

  @override
  ConsumerState<_AppBarInterestedButton> createState() =>
      _AppBarInterestedButtonState();
}

class _AppBarInterestedButtonState
    extends ConsumerState<_AppBarInterestedButton> {
  @override
  Widget build(BuildContext context) {
    final rsvpStatus = ref.watch(userEventRsvpProvider(widget.eventId)).value;
    final isGoing = rsvpStatus == 'going';
    final isInterested = rsvpStatus == 'interested';

    final fullEvent = ref.watch(eventStreamProvider(widget.eventId)).value;
    final baseCount = fullEvent?.liveCounts.interested ?? 0;

    int displayCount = baseCount;
    final optMap = ref.watch(optimisticInterestedCountProvider);
    final optData = optMap[widget.eventId];
    if (optData != null && DateTime.now().isBefore(optData.expiresAt)) {
      displayCount = optData.count;
    }

    if (displayCount < 0) displayCount = 0;

    return GestureDetector(
      onTap: isGoing
          ? null
          : () {
              final newInterested = !isInterested;
              final newCount = newInterested
                  ? displayCount + 1
                  : displayCount - 1;
              ref
                  .read(optimisticInterestedCountProvider.notifier)
                  .updateCount(
                    widget.eventId,
                    OptimisticCount(
                      newCount < 0 ? 0 : newCount,
                      DateTime.now().add(const Duration(seconds: 5)),
                    ),
                  );

              final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
              if (userId != null) {
                if (newInterested) {
                  ref
                      .read(eventRepositoryProvider)
                      .updateRSVP(widget.eventId, userId, 'interested');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Marked Interested',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: Color(0xFF333333),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.fromLTRB(16, 0, 16, 80),
                    ),
                  );
                } else {
                  ref
                      .read(eventRepositoryProvider)
                      .removeRSVP(widget.eventId, userId);
                }
              }
            },
      child: Container(
        height: 40,
        width: displayCount > 0 ? null : 40,
        padding: displayCount > 0
            ? const EdgeInsets.symmetric(horizontal: 12)
            : EdgeInsets.zero,
        alignment: displayCount > 0 ? null : Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isInterested ? Icons.star : Icons.star_border,
              size: 22,
              color: isGoing ? Colors.black26 : Colors.black,
            ),
            if (displayCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$displayCount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isGoing ? Colors.black26 : Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
