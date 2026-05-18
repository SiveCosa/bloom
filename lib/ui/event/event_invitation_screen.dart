import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bloom/domain/event/event.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/domain/auth/auth_providers.dart';
import 'package:bloom/ui/create_event/widgets/aurora_background.dart';
import 'package:bloom/ui/shared/widgets/event_weather_card.dart';
import 'package:bloom/domain/event/event_visibility.dart';
import 'package:bloom/domain/event/event_extra.dart';
import 'package:bloom/domain/event/create_event_state.dart';
import 'package:bloom/data/firebase_provider.dart' show firestoreProvider;
import 'package:bloom/data/event/event_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/event_rsvp_bar.dart';
import 'widgets/guest_list_card.dart';
import 'widgets/host_control_bar.dart';
import 'host_guestlist_screen.dart';
import '../create_event/widgets/host_invite_section.dart';

class EventInvitationScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventInvitationScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventInvitationScreen> createState() => _EventInvitationScreenState();
}

class _EventInvitationScreenState extends ConsumerState<EventInvitationScreen> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ValueNotifier<double> _sheetSize = ValueNotifier(0.55);
  bool _isDescriptionExpanded = false;
  bool _isDeleting = false;

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

    final eventAsync = ref.watch(eventStreamProvider(widget.eventId));
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return const Scaffold(
            body: Center(child: Text('Event not found', style: TextStyle(color: Colors.white))),
          );
        }

        final bool isHost = currentUser?.uid == event.metadata.hostId || event.coHostIds.contains(currentUser?.uid);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E12),
          body: Stack(
            children: [
              // 2. Poster Image + Glow (Reactive)
              ValueListenableBuilder<double>(
                valueListenable: _sheetSize,
                builder: (context, size, child) {
                  final double screenHeight = MediaQuery.of(context).size.height;
                  final double topBarHeight = MediaQuery.of(context).padding.top + 56;
                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                  final double expandedProgress = ((size - 0.55) / (0.88 - 0.55)).clamp(0.0, 1.0);
                  final double posterOpacity = (1.0 - expandedProgress).clamp(0.0, 1.0);
                  
                  final double actualPosterHeight = MediaQuery.of(context).size.width / (event.visuals.aspectRatio > 0 ? event.visuals.aspectRatio : 1.0);
                  final bool isSquare = (event.visuals.aspectRatio - 1.0).abs() < 0.1;
                  final double sheetTopMinimized = screenHeight * (1.0 - 0.28);
                  final double availableSpaceMinimized = sheetTopMinimized - topBarHeight;
                  
                  final double targetTop = isSquare 
                    ? topBarHeight + (availableSpaceMinimized - actualPosterHeight) / 2
                    : topBarHeight;

                  final double posterTop = ui.lerpDouble(0, targetTop, minimizedProgress) ?? 0;

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
                                    color: (event.visuals.auroraColors.isNotEmpty 
                                            ? _parseHexColor(event.visuals.auroraColors[0]) 
                                            : const Color(0xFFAD83FE))
                                        .withValues(alpha: 0.45 * minimizedProgress * (1.0 - expandedProgress)),
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        child: Stack(
                          children: [
                            // 1. Aurora Background (Reactive)
                            ValueListenableBuilder<double>(
                              valueListenable: _sheetSize,
                              builder: (context, size, child) {
                                final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                                return Positioned(
                                  top: -(MediaQuery.of(context).size.height * (1.0 - size)),
                                  left: 0,
                                  right: 0,
                                  height: MediaQuery.of(context).size.height,
                                  child: Opacity(
                                    opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                                    child: AuroraBackground(
                                      colors: event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // 2. Subtle Glass Overlay (Reactive)
                            ValueListenableBuilder<double>(
                              valueListenable: _sheetSize,
                              builder: (context, size, child) {
                                final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                                return Positioned.fill(
                                  child: Opacity(
                                    opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                                    child: Container(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            Column(
                              children: [
                                // Fixed Transparent Header with Gripper
                                SizedBox(
                                  height: 25,
                                  width: double.infinity,
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(2),
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
                                          padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                                          child: Column(
                                            children: [
                                              // Dynamic gap (Reactive)
                                              ValueListenableBuilder<double>(
                                                valueListenable: _sheetSize,
                                                builder: (context, size, child) {
                                                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                                                  return SizedBox(height: ui.lerpDouble(12, 40, minimizedProgress) ?? 12);
                                                },
                                              ),
                                              _buildVisibilityPill(event),
                                              const SizedBox(height: 16),
                                              // Event Title
                                              ShaderMask(
                                                shaderCallback: (bounds) => ui.Gradient.linear(
                                                  Offset.zero,
                                                  Offset(bounds.width, 0),
                                                  [Colors.white, Colors.white.withValues(alpha: 0.7)],
                                                ),
                                                child: Text(
                                                  event.title,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.1,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 25),
                                              
                                              // Date & Location Rows (Fading)
                                              ValueListenableBuilder<double>(
                                                valueListenable: _sheetSize,
                                                builder: (context, size, child) {
                                                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                                                  return Column(
                                                    children: [
                                                      _buildDateRow(event),
                                                      const SizedBox(height: 10),
                                                      Opacity(
                                                        opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                                                        child: _buildLocationRow(event),
                                                      ),
                                                      const SizedBox(height: 25),
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
                                          builder: (context, size, child) {
                                            if (size < 0.4) return const SizedBox.shrink();
                                            
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 15),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (event.description.isNotEmpty || event.tags.isNotEmpty || event.extras.isNotEmpty) ...[
                                                    _buildDescriptionCard(event),
                                                    const SizedBox(height: 16),
                                                  ],
                                                  _buildGuestList(event),
                                                  const SizedBox(height: 16),
                                                   Consumer(
                                                     builder: (context, ref, child) {
                                                       final hostProfile = ref.watch(userProfileStreamProvider(event.metadata.hostId)).value;
                                                       final List<Map<String, dynamic>> resolvedCoHosts = [];
                                                       for (final coHostId in event.coHostIds) {
                                                         final coHostProfileAsync = ref.watch(userProfileStreamProvider(coHostId));
                                                         final coHostProfile = coHostProfileAsync.value;
                                                         if (coHostProfile != null) {
                                                           resolvedCoHosts.add({
                                                             'uid': coHostId,
                                                             ...coHostProfile,
                                                           });
                                                         }
                                                       }
                                                       return HostInviteSection(
                                                         userProfile: hostProfile, 
                                                         coHosts: resolvedCoHosts,
                                                         onAddCoHost: () {},
                                                         showInviteFriends: false,
                                                       );
                                                     },
                                                   ),
                                                  if (event.location != null) ...[
                                                    const SizedBox(height: 16),
                                                    _buildWeatherCard(event),
                                                    const SizedBox(height: 16),
                                                    _buildMapCard(event),
                                                  ],
                                                  const SizedBox(height: 120),
                                                ],
                                              ),
                                            );
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
                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
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
                    // Calculate opacity: fade out as it approaches min size (0.35)
                    // For hosts, hide when minimized. For guests, we keep it visible for now unless specified.
                    final double opacity = isHost ? ((size - 0.28) / (0.45 - 0.28)).clamp(0.0, 1.0) : 1.0;
                    
                    if (opacity <= 0 && isHost) return const SizedBox.shrink();

                    return Opacity(
                      opacity: opacity,
                      child: IgnorePointer(
                        ignoring: opacity < 0.5,
                        child: isHost 
                          ? HostControlBar(
                              event: event,
                              onGoingPressed: () {
                                final palette = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => HostGuestlistScreen(
                                      eventId: event.id,
                                      palette: palette,
                                    ),
                                  ),
                                );
                              },
                              onRemindersPressed: () => _showRemindersModal(context, event),
                            )
                          : EventRsvpBar(eventId: widget.eventId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0B0E12),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFF0B0E12),
        body: Stack(
          children: [
            // Blurred background
            Positioned.fill(
              child: AuroraBackground(colors: const [Color(0xFF2D2D2D), Color(0xFF1A1A1A)]),
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
                    const Icon(Icons.error_outline, color: Colors.white70, size: 64),
                    const SizedBox(height: 24),
                    const Text(
                      'This event is no longer available',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'It may have been cancelled or moved. Check back later!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                      const Icon(Icons.mode_edit_outline, color: Colors.black, size: 22),
                      () async {
                        // Edit logic
                        final router = GoRouter.of(context);
                        final hostId = event.metadata.hostId;
                        final hostProfile = await ref.read(userProfileFutureProvider(hostId).future);
                        final List<Map<String, dynamic>> resolvedCoHosts = [];
                        for (final coHostId in event.coHostIds) {
                          final profile = await ref.read(userProfileFutureProvider(coHostId).future);
                          if (profile != null) {
                            resolvedCoHosts.add({
                              'uid': coHostId,
                              ...profile,
                            });
                          }
                        }
                        ref.read(createEventProvider.notifier).loadEventForEditing(event, hostProfile, resolvedCoHosts);
                        router.push('/create-event');
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                  _buildTopButton(
                    Transform.flip(
                      flipX: true,
                      child: const Icon(Icons.reply_rounded, color: Colors.black, size: 22),
                    ),
                    () {
                      // Share logic
                      Share.share('Check out ${event.title} on Bloom!');
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildTopButton(
                    const Icon(Icons.more_vert_rounded, color: Colors.black, size: 22),
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
    if (visibility == EventVisibility.public || visibility == EventVisibility.private) {
      text += ' event';
    }
    
    if (timeStatus.isNotEmpty) {
      text += ' • $timeStatus';
    }

    final accentColor = Color(event.statusColorValue);
    final useAccent = timeStatus.isNotEmpty && status != EventStatus.active; // For Cancelled/Ended
    final isSpecial = isLive || useAccent;

    return ValueListenableBuilder<double>(
      valueListenable: _sheetSize,
      builder: (context, size, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSpecial ? accentColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSpecial ? accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08), 
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
                      child: Icon(visibility.outlinedIcon, color: isSpecial ? accentColor : Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyle(
                      color: isSpecial ? accentColor : Colors.white.withValues(alpha: 0.9),
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
      },
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
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
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
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                      children: event.tags.map((tag) => _buildTagChip(tag)).toList(),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildSeparator(),
                  const SizedBox(height: 25),
                ],
                
                _buildAudienceInfo(event),
                
                if (hasExtras) ...[
                  const SizedBox(height: 25),
                  ...(() {
                    final auroraColors = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
                    final sortedExtras = [...event.extras]..sort((a, b) {
                      final aIsLink = a.url != null && a.url!.isNotEmpty;
                      final bIsLink = b.url != null && b.url!.isNotEmpty;
                      if (aIsLink && !bIsLink) return -1;
                      if (!aIsLink && bIsLink) return 1;
                      return 0;
                    });
                    
                    return List.generate(sortedExtras.length, (index) {
                      final extra = sortedExtras[index];
                      final bool isLink = extra.url != null && extra.url!.isNotEmpty;
                      final Color textColor = isLink ? _getBestExtraColor(auroraColors) : Colors.white;
                      final bool isLast = index == sortedExtras.length - 1;
  
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: isLink ? () async {
                              final url = extra.url!.trim();
                              final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
                              try {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                                }
                              } catch (e) {
                                debugPrint('Error launching $uri: $e');
                              }
                            } : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  isLink ? Icons.link : extra.type.icon,
                                  color: isLink ? textColor : Colors.white.withValues(alpha: 0.6),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    extra.displayText,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                      fontWeight: isLink ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isLink) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.4), size: 16),
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
                  ? () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded)
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
                                return const LinearGradient(colors: [Colors.white, Colors.white]).createShader(bounds);
                              }
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.white, Colors.white.withValues(alpha: 0)],
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

  Widget _buildAudienceInfo(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RSVP Deadline
        if (event.audience.rsvpDeadline != null) ...[
          _buildAudienceRow(
            icon: Icons.hourglass_bottom_rounded,
            text: 'RSVP by ${DateFormat('d MMMM yyyy').format(event.audience.rsvpDeadline!)}',
          ),
          const SizedBox(height: 25),
        ],

        // Capacity / Spots
        _buildAudienceRow(
          icon: Icons.groups_rounded,
          text: event.audience.capacity != null
              ? '${event.audience.capacity! - event.liveCounts.going}/${event.audience.capacity} spots available'
              : 'Unlimited spots available',
        ),
        const SizedBox(height: 25),

        // Plus Ones
        _buildAudienceRow(
          icon: Icons.person_add_rounded,
          text: event.audience.maxPlusOnes > 0 ? '+${event.audience.maxPlusOnes} guests allowed' : 'No plus ones allowed',
        ),
      ],
    );
  }

  Widget _buildAudienceRow({IconData? icon, Widget? customIcon, required String text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: customIcon ?? Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.6),
            size: 18,
          ),
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

    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.5,
    );

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
          lineChildren.add(TextSpan(
            text: lineText.substring(lastMatchEnd, match.start),
            style: baseStyle,
          ));
        }

        final matchText = match.group(0)!;

        if (matchText.startsWith('*')) {
          lineChildren.add(TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ));
        } else if (matchText.startsWith('!')) {
          lineChildren.add(TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 16.0,
            ),
          ));
        }

        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < lineText.length) {
        lineChildren.add(TextSpan(
          text: lineText.substring(lastMatchEnd),
          style: baseStyle,
        ));
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
    return GuestListCard(
      event: event,
      onInvitePressed: () {
        Share.share('Check out ${event.title} on Bloom!');
      },
    );
  }


  Widget _buildMapCard(Event event) {
    if (event.location == null) return const SizedBox.shrink();
    final themeColor = event.visuals.auroraColors.isNotEmpty
        ? _parseHexColor(event.visuals.auroraColors[0])
        : const Color(0xFFAD83FE);

    return _PulsingMapCard(
      event: event,
      themeColor: themeColor,
      onLaunchMap: _launchMap,
    );
  }

  Future<void> _launchMap(double lat, double lng, String label) async {
    final String appleUri = 'maps://?q=$lat,$lng';
    final String googleUri = 'geo:$lat,$lng?q=$lat,$lng';
    final String fallbackUri = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    try {
      if (await canLaunchUrl(Uri.parse(appleUri))) {
        await launchUrl(Uri.parse(appleUri));
      } else if (await canLaunchUrl(Uri.parse(googleUri))) {
        await launchUrl(Uri.parse(googleUri));
      } else {
        await launchUrl(Uri.parse(fallbackUri), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching map: $e');
      await launchUrl(Uri.parse(fallbackUri), mode: LaunchMode.externalApplication);
    }
  }

  void _showRemindersModal(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15191D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
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
            const Text(
              'Event Reminders',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Nudge guests who haven\'t RSVP\'d yet or send a broadcast to all "Going" guests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildReminderOption(Icons.notifications_active, 'Nudge pending guests', () {
              Navigator.pop(context);
              _showNudgeModal(context, event);
            }),
            const SizedBox(height: 12),
            _buildReminderOption(Icons.campaign, 'Broadcast to attendees', () {
              Navigator.pop(context);
              _showBroadcastModal(context, event);
            }),
            const SizedBox(height: 12),
            _buildReminderOption(Icons.schedule, 'Schedule auto-reminder', () {
              Navigator.pop(context);
              _showAutoReminderModal(context, event);
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showNudgeModal(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15191D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Consumer(
            builder: (context, ref, child) {
              final guestsAsync = ref.watch(eventGuestsProvider(event.id));
              return guestsAsync.when(
                data: (guests) {
                  final pendingGuests = guests.where((g) {
                    final status = g['status'] as String? ?? 'invited';
                    return status != 'going' && status != 'declined' && status != 'not_going';
                  }).toList();

                  return _NudgeGuestsSheet(
                    pendingGuests: pendingGuests,
                    scrollController: scrollController,
                    onNudge: (selectedUids) {
                      Navigator.pop(context);
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
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Successfully nudged ${selectedUids.length} guest${selectedUids.length == 1 ? '' : 's'}!',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBroadcastModal(BuildContext context, Event event) {
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15191D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
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
              const Text(
                'Broadcast to Attendees',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Send a message to all guests who are "Going".',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 250,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Type your update here...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFAD83FE)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final message = controller.text.trim();
                  if (message.isNotEmpty) {
                    Navigator.pop(context);
                    final firestore = ref.read(firestoreProvider);
                    await firestore
                        .collection('events')
                        .doc(event.id)
                        .collection('broadcasts')
                        .add({
                      'message': message,
                      'sentAt': FieldValue.serverTimestamp(),
                      'senderId': ref.read(firebaseAuthProvider).currentUser?.uid,
                    });
                    
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
                                )
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.campaign, color: Colors.greenAccent),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Broadcast successfully sent!',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAD83FE),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Send Broadcast', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAutoReminderModal(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15191D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: _AutoReminderSelectorSheet(
          event: event,
          onSave: (selectedReminders) async {
            Navigator.pop(context);
            await ref.read(eventRepositoryProvider).updateRSVPReminders(event.id, selectedReminders);
            
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
                        )
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.greenAccent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Automated reminders updated successfully!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  void _showOptionsModal(BuildContext context, Event event, bool isHost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15191D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
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
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            if (isHost) ...[
              _buildReminderOption(
                Icons.mode_edit_outline,
                'Edit Event',
                () async {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  final hostId = event.metadata.hostId;
                  final hostProfile = await ref.read(userProfileFutureProvider(hostId).future);
                  final List<Map<String, dynamic>> resolvedCoHosts = [];
                  for (final coHostId in event.coHostIds) {
                    final profile = await ref.read(userProfileFutureProvider(coHostId).future);
                    if (profile != null) {
                      resolvedCoHosts.add(profile);
                    }
                  }
                  ref.read(createEventProvider.notifier).loadEventForEditing(event, hostProfile, resolvedCoHosts);
                  router.push('/create-event');
                },
              ),
              const SizedBox(height: 12),
              _buildReminderOption(
                Icons.cancel_outlined,
                'Cancel Event',
                () async {
                  Navigator.pop(context);
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF15191D),
                      title: const Text('Cancel Event', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to cancel this event? This will notify your guests.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('No', style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Yes, Cancel', style: TextStyle(color: Colors.redAccent)),
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
                    await ref.read(eventRepositoryProvider).updateEvent(cancelledEvent);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Event has been cancelled.')),
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
                  Navigator.pop(context);
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF15191D),
                      title: const Text('Delete Event', style: TextStyle(color: Colors.white)),
                      content: const Text('Are you sure you want to permanently delete this event? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() {
                      _isDeleting = true;
                    });
                    await ref.read(eventRepositoryProvider).deleteEvent(event);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Event has been permanently deleted.')),
                      );
                      context.go('/');
                    }
                  }
                },
              ),
            ] else ...[
              _buildReminderOption(
                Icons.reply_rounded,
                'Share Event',
                () {
                  Navigator.pop(context);
                  Share.share('Check out ${event.title} on Bloom!');
                },
              ),
              const SizedBox(height: 12),
              _buildReminderOption(
                Icons.report_gmailerrorred_rounded,
                'Report Event',
                () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you for reporting. Our safety team will review this event.')),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildReminderOption(
                Icons.exit_to_app_rounded,
                'Leave Event',
                () async {
                  Navigator.pop(context);
                  final currentUser = ref.read(firebaseAuthProvider).currentUser;
                  if (currentUser != null) {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF15191D),
                        title: const Text('Leave Event', style: TextStyle(color: Colors.white)),
                        content: const Text('Are you sure you want to leave this event? Your RSVP status will be updated to Declined.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(eventRepositoryProvider).updateRSVP(event.id, currentUser.uid, 'declined');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You have left the event.')),
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
}

class _PulsingMapCard extends StatefulWidget {
  final Event event;
  final Color themeColor;
  final Future<void> Function(double lat, double lng, String label) onLaunchMap;

  const _PulsingMapCard({
    required this.event,
    required this.themeColor,
    required this.onLaunchMap,
  });

  @override
  State<_PulsingMapCard> createState() => _PulsingMapCardState();
}

class _PulsingMapCardState extends State<_PulsingMapCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Uint8List? _mapImageBytes;
  bool _isLoadingMap = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _fetchStaticMap();
  }

  @override
  void didUpdateWidget(covariant _PulsingMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.location?.latitude != widget.event.location?.latitude ||
        oldWidget.event.location?.longitude != widget.event.location?.longitude ||
        oldWidget.themeColor != widget.themeColor) {
      _fetchStaticMap();
    }
  }

  Future<void> _fetchStaticMap() async {
    final location = widget.event.location;
    if (location == null) return;

    if (!mounted) return;
    setState(() {
      _isLoadingMap = true;
    });

    try {
      final hexColor = widget.themeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

      final result = await FirebaseFunctions.instanceFor(region: 'africa-south1')
          .httpsCallable('googleMapsProxy')
          .call({
        'endpoint': 'staticmap',
        'params': {
          'center': '${location.latitude},${location.longitude}',
          'zoom': 15,
          'size': '600x300',
          'scale': 2,
          'color': hexColor,
        },
      });

      if (!mounted) return;

      final data = result.data as Map<String, dynamic>;
      if (data['status'] == 'OK' && data['image'] != null) {
        final decodedBytes = base64Decode(data['image']);
        setState(() {
          _mapImageBytes = decodedBytes;
          _isLoadingMap = false;
        });
      } else {
        debugPrint('Google Maps Proxy Static Map error: ${data['status']}');
        setState(() {
          _isLoadingMap = false;
        });
      }
    } catch (e) {
      debugPrint('Exception fetching static map: $e');
      if (mounted) {
        setState(() {
          _isLoadingMap = false;
        });
      }
    }
  }

  Widget _buildMapBackground() {
    if (_isLoadingMap) {
      return const _MapShimmer();
    }

    if (_mapImageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _mapImageBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MapGridPainter(
            pulseValue: _controller.value,
            themeColor: widget.themeColor,
          ),
          child: Container(),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.event.location == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => widget.onLaunchMap(
        widget.event.location!.latitude,
        widget.event.location!.longitude,
        widget.event.location!.displayName,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 2.1,
                  child: Container(
                    color: const Color(0xFF0F1113),
                    child: Stack(
                      children: [
                        // Static Map Background / Shimmer / Fallback Custom Paint Grid
                        Positioned.fill(
                          child: _buildMapBackground(),
                        ),

                        // Tap overlay button / premium tooltip
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.navigation_outlined, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Navigate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 20),
                  child: Column(
                    children: [
                      Text(
                        widget.event.location!.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.event.location!.formattedAddress,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final double pulseValue;
  final Color themeColor;

  _MapGridPainter({required this.pulseValue, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw dark background grid lines (orthogonal)
    paint.color = Colors.white.withValues(alpha: 0.05);
    const double gridSize = 25.0;
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw some stylized neon roads/streets
    paint.strokeWidth = 2.0;
    paint.color = themeColor.withValues(alpha: 0.12);
    
    // Main horizontal road crossing center
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    // Main vertical road crossing center
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
    
    // Some diagonal roads
    paint.strokeWidth = 1.0;
    paint.color = themeColor.withValues(alpha: 0.06);
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);

    // Draw concentric radar-like circles around the event center
    paint.style = PaintingStyle.stroke;
    for (int r = 1; r <= 3; r++) {
      final double radius = r * 45.0;
      paint.color = themeColor.withValues(alpha: 0.08 / r);
      canvas.drawCircle(center, radius, paint);
    }

    // Pulse Circle: expanding out
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = themeColor.withValues(alpha: (0.45 * (1.0 - pulseValue)))
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 15.0 + (pulseValue * 65.0), pulsePaint);

    final pulseFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = themeColor.withValues(alpha: (0.12 * (1.0 - pulseValue)));
    canvas.drawCircle(center, 15.0 + (pulseValue * 65.0), pulseFillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MapShimmer extends StatefulWidget {
  const _MapShimmer();

  @override
  State<_MapShimmer> createState() => _MapShimmerState();
}

class _MapShimmerState extends State<_MapShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF15181B),
                Color.lerp(const Color(0xFF15181B), const Color(0xFF25292E), _shimmerController.value)!,
                const Color(0xFF15181B),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Opacity(
              opacity: 0.5,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NudgeGuestsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> pendingGuests;
  final ScrollController scrollController;
  final Function(List<String>) onNudge;

  const _NudgeGuestsSheet({
    required this.pendingGuests,
    required this.scrollController,
    required this.onNudge,
  });

  @override
  State<_NudgeGuestsSheet> createState() => _NudgeGuestsSheetState();
}

class _NudgeGuestsSheetState extends State<_NudgeGuestsSheet> {
  final Set<String> _selectedUids = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    for (final guest in widget.pendingGuests) {
      final uid = guest['uid'] as String?;
      if (uid != null) {
        _selectedUids.add(uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGuests = widget.pendingGuests.where((guest) {
      final displayName = (guest['displayName'] as String? ?? '').toLowerCase();
      final email = (guest['email'] as String? ?? '').toLowerCase();
      return displayName.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nudge Pending Guests',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Remind guests who have not responded to RSVP.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search guests...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4)),
              fillColor: Colors.white.withValues(alpha: 0.05),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFAD83FE)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredGuests.isEmpty
                ? Center(
                    child: Text(
                      'No pending guests found',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: filteredGuests.length,
                    itemBuilder: (context, index) {
                      final guest = filteredGuests[index];
                      final uid = guest['uid'] as String? ?? '';
                      final displayName = guest['displayName'] as String? ?? 'Guest';
                      final isSelected = _selectedUids.contains(uid);

                      return CheckboxListTile(
                        title: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 15)),
                        subtitle: Text(guest['email'] as String? ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                        value: isSelected,
                        activeColor: const Color(0xFFAD83FE),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUids.add(uid);
                            } else {
                              _selectedUids.remove(uid);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selectedUids.isEmpty
                ? null
                : () => widget.onNudge(_selectedUids.toList()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAD83FE),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              'Send Nudge (${_selectedUids.length})',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _AutoReminderSelectorSheet extends StatefulWidget {
  final Event event;
  final Function(List<String>) onSave;

  const _AutoReminderSelectorSheet({
    required this.event,
    required this.onSave,
  });

  @override
  State<_AutoReminderSelectorSheet> createState() => _AutoReminderSelectorSheetState();
}

class _AutoReminderSelectorSheetState extends State<_AutoReminderSelectorSheet> {
  final List<String> _allOptions = [
    '1 hour before',
    '24 hours before',
    '48 hours before',
    '3 days before',
  ];
  final Set<String> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _selectedOptions.addAll(widget.event.rsvpReminders);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const Text(
          'Schedule Auto-Reminder',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select when automated RSVP reminders should be sent out.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._allOptions.map((option) {
          final isSelected = _selectedOptions.contains(option);
          return CheckboxListTile(
            title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            value: isSelected,
            activeColor: const Color(0xFFAD83FE),
            checkColor: Colors.white,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedOptions.add(option);
                } else {
                  _selectedOptions.remove(option);
                }
              });
            },
          );
        }),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => widget.onSave(_selectedOptions.toList()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFAD83FE),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
