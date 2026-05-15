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
import 'package:bloom/ui/shared/widgets/event_weather_card.dart';
import 'package:bloom/domain/event/event_visibility.dart';
import 'package:bloom/domain/event/event_extra.dart';
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
  _EventInvitationScreenState createState() => _EventInvitationScreenState();
}

class _EventInvitationScreenState extends ConsumerState<EventInvitationScreen> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ValueNotifier<double> _sheetSize = ValueNotifier(0.55);
  bool _isDescriptionExpanded = false;

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
    final eventAsync = ref.watch(eventStreamProvider(widget.eventId));
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;

    return eventAsync.when(
      data: (event) {
        if (event == null) {
          return const Scaffold(
            body: Center(child: Text('Event not found', style: TextStyle(color: Colors.white))),
          );
        }

        final bool isHost = currentUser?.uid == event.metadata.hostId;

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
                                                      final hostProfile = ref.watch(userProfileFutureProvider(event.metadata.hostId)).value;
                                                      return HostInviteSection(
                                                        userProfile: hostProfile, 
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
              _buildTopAppBar(isHost),

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

  Widget _buildTopAppBar(bool isHost) {
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
                      () {
                        // Edit logic
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
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildTopButton(
                    const Icon(Icons.more_vert_rounded, color: Colors.black, size: 22),
                    () {
                      // Options logic
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

  Widget _buildStatusRow(Event event) {
    final status = event.computedStatus;
    final color = Color(event.statusColorValue);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (status == EventStatus.active && event.timing.isOngoing)
          _buildLiveIndicator(color)
        else
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          event.statusLabel,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveIndicator(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
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
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: _isDescriptionExpanded ? double.infinity : 200,
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    if (_isDescriptionExpanded) {
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
                ),
              ),
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
          ),
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

    final pattern = RegExp(
      r'(\*[^*]+?\*)|(![^!]+?!)',
      multiLine: true,
    );

    final List<TextSpan> children = [];
    int lastMatchEnd = 0;
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.5,
    );

    for (final match in pattern.allMatches(displayStr)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: displayStr.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchText = match.group(0)!;

      if (matchText.startsWith('*')) {
        // Bold: *text*
        children.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (matchText.startsWith('!')) {
        // Heading: !text!
        children.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 16.0,
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < displayStr.length) {
      children.add(TextSpan(
        text: displayStr.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: children);
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

    return Container(
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
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.map_outlined, color: Colors.white24, size: 40),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Text(
                      event.location!.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.location!.formattedAddress,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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
            _buildReminderOption(Icons.notifications_active, 'Nudge pending guests', () => Navigator.pop(context)),
            const SizedBox(height: 12),
            _buildReminderOption(Icons.campaign, 'Broadcast to attendees', () => Navigator.pop(context)),
            const SizedBox(height: 12),
            _buildReminderOption(Icons.schedule, 'Schedule auto-reminder', () => Navigator.pop(context)),
            const SizedBox(height: 24),
          ],
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
}
