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
                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.25)).clamp(0.0, 1.0);
                  final double expandedProgress = ((size - 0.55) / (0.9 - 0.55)).clamp(0.0, 1.0);
                  final double posterOpacity = (1.0 - expandedProgress).clamp(0.0, 1.0);
                  
                  final double actualPosterHeight = MediaQuery.of(context).size.width / (event.visuals.aspectRatio > 0 ? event.visuals.aspectRatio : 1.0);
                  final bool isSquare = (event.visuals.aspectRatio - 1.0).abs() < 0.1;
                  final double sheetTopMinimized = screenHeight * (1.0 - 0.25);
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
                            0.25,
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
                minChildSize: 0.25,
                maxChildSize: 0.9,
                snap: true,
                snapSizes: const [0.25, 0.55, 0.9],
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
                          // Sheet's Aurora Background (Reactive)
                          ValueListenableBuilder<double>(
                            valueListenable: _sheetSize,
                            builder: (context, size, child) {
                              final double minimizedProgress = ((0.55 - size) / (0.55 - 0.25)).clamp(0.0, 1.0);
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
                          // Subtle Glass Overlay (Reactive)
                          ValueListenableBuilder<double>(
                            valueListenable: _sheetSize,
                            builder: (context, size, child) {
                              final double minimizedProgress = ((0.55 - size) / (0.55 - 0.25)).clamp(0.0, 1.0);
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
                          // Sticky Gripper (Reactive)
                          ValueListenableBuilder<double>(
                            valueListenable: _sheetSize,
                            builder: (context, size, child) {
                              final double screenHeight = MediaQuery.of(context).size.height;
                              final double minimizedProgress = ((0.55 - size) / (0.55 - 0.25)).clamp(0.0, 1.0);
                              final double maxSheetSize = 0.9 - (10 / screenHeight);
                              final double expandedProgress = ((size - 0.55) / (maxSheetSize - 0.55)).clamp(0.0, 1.0);
                              
                                return Positioned(
                                  top: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Transform.rotate(
                                        angle: (ui.lerpDouble(0, -0.5, minimizedProgress) ?? 0) + 
                                               (ui.lerpDouble(0, 0.5, expandedProgress) ?? 0),
                                        child: Container(
                                          width: 20,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(2)),
                                          ),
                                        ),
                                      ),
                                      Transform.rotate(
                                        angle: (ui.lerpDouble(0, 0.5, minimizedProgress) ?? 0) + 
                                               (ui.lerpDouble(0, -0.5, expandedProgress) ?? 0),
                                        child: Container(
                                          width: 20,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                            children: [
                              // Dynamic gap (Reactive)
                              ValueListenableBuilder<double>(
                                valueListenable: _sheetSize,
                                builder: (context, size, child) {
                                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.25)).clamp(0.0, 1.0);
                                  return SizedBox(height: ui.lerpDouble(32, 72, minimizedProgress) ?? 32);
                                },
                              ),
                              _buildVisibilityPill(event),
                              const SizedBox(height: 12),
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
                              const SizedBox(height: 24),
                              
                              // Date & Location Rows (Fading)
                              ValueListenableBuilder<double>(
                                valueListenable: _sheetSize,
                                builder: (context, size, child) {
                                  // Fully opaque at 0.45, fully transparent at 0.3
                                  final opacity = ((size - 0.25) / 0.15).clamp(0.0, 1.0);
                                  if (opacity == 0) return const SizedBox.shrink();
                                  
                                  return Opacity(
                                    opacity: opacity,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                      _buildDateRow(event),
                                        const SizedBox(height: 16),
                                        _buildLocationRow(event),
                                        const SizedBox(height: 15),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Essential content (Visibility check based on size for performance)
                              ValueListenableBuilder<double>(
                                valueListenable: _sheetSize,
                                builder: (context, size, child) {
                                  if (size < 0.4) return const SizedBox.shrink();
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildWeatherCard(event),
                                      const SizedBox(height: 15),
                                      _buildDescriptionCard(event),
                                      const SizedBox(height: 32),
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
                                      const SizedBox(height: 32),
                                      _buildMapCard(event),
                                      const SizedBox(height: 120),
                                    ],
                                  );
                                },
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
                  final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
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

              // 7. Fixed RSVP Action Bar
              if (!isHost)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 30,
                  child: EventRsvpBar(eventId: widget.eventId),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTopButton(Icons.chevron_left, () => context.pop()),
              Row(
                children: [
                  _buildTopButton(Icons.ios_share_rounded, () {
                    // Share logic
                  }),
                  const SizedBox(width: 10),
                  _buildTopButton(Icons.more_horiz, () {
                    // Options
                  }),
                  if (isHost) ...[
                    const SizedBox(width: 10),
                    _buildTopButton(Icons.edit, () {
                      // Edit
                    }),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.black,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildVisibilityPill(Event event) {
    final visibility = event.audience.visibility;
    String text = visibility.title;
    if (visibility == EventVisibility.public || visibility == EventVisibility.private) {
      text += ' event';
    }

    return ValueListenableBuilder<double>(
      valueListenable: _sheetSize,
      builder: (context, size, child) {
        final double minimizedProgress = ((0.55 - size) / (0.55 - 0.25)).clamp(0.0, 1.0);
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: FittedBox(
                      child: Icon(visibility.outlinedIcon, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (minimizedProgress > 0.5) ...[
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: ((minimizedProgress - 0.5) / 0.5).clamp(0.0, 1.0),
                      child: const Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
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
      startStr += ' ${DateFormat('h a').format(start).toLowerCase()}';
    }

    String display = startStr;
    if (end != null) {
      String endStr = '';
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        if (!endTbd) {
          endStr = DateFormat('h a').format(end).toLowerCase();
        }
      } else {
        endStr = DateFormat('EEE, d MMM').format(end);
        if (!endTbd) {
          endStr += ' ${DateFormat('h a').format(end).toLowerCase()}';
        }
      }
      if (endStr.isNotEmpty) {
        display += ' \u2014 $endStr';
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        Text(
          display,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(Event event) {
    if (event.location == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            event.location!.displayName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
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
      padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTags) ...[
                Align(
                  alignment: Alignment.center,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: event.tags.map((tag) => _buildTagChip(tag)).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (hasTags) ...[
                _buildSeparator(),
                const SizedBox(height: 16),
              ],
              if (hasDesc) ...[
                _buildExpandableDescription(event.description),
                const SizedBox(height: 16),
              ],
              if (hasDesc) ...[
                _buildSeparator(),
                const SizedBox(height: 16),
              ],
              _buildAudienceInfo(event),
              if (hasExtras) ...[
                const SizedBox(height: 16),
                _buildSeparator(),
                const SizedBox(height: 16),
                ...(() {
                  final auroraColors = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
                  final sortedExtras = [...event.extras]..sort((a, b) {
                    final aIsLink = a.url != null && a.url!.isNotEmpty;
                    final bIsLink = b.url != null && b.url!.isNotEmpty;
                    if (aIsLink && !bIsLink) return -1;
                    if (!aIsLink && bIsLink) return 1;
                    return 0;
                  });
                  return sortedExtras.map((extra) {
                    final bool isLink = extra.url != null && extra.url!.isNotEmpty;
                    final Color textColor = isLink ? _getBestExtraColor(auroraColors) : Colors.white;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
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
                            const SizedBox(width: 12),
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
                    );
                  });
                })(),
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
    bool isLong = text.length > 200;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) {
                if (!isLong || _isDescriptionExpanded) return const LinearGradient(colors: [Colors.white, Colors.white]).createShader(bounds);
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                  stops: const [0.7, 1.0],
                ).createShader(bounds);
              },
              child: RichText(
                text: _getFormattedDescriptionSpan(text, _isDescriptionExpanded && isLong ? null : 200),
              ),
            ),
            if (isLong)
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _isDescriptionExpanded ? 'Show less' : 'Read more',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAudienceInfo(Event event) {
    final List<Widget> items = [];

    // RSVP Deadline
    if (event.audience.rsvpDeadline != null) {
      items.add(
        _buildAudienceRow(
          icon: Icons.hourglass_bottom_rounded,
          text: 'RSVP by ${DateFormat('d MMMM yyyy').format(event.audience.rsvpDeadline!)}',
        ),
      );
    }

    // Capacity / Spots
    final String spotsText = event.audience.capacity != null
        ? '${event.audience.capacity! - event.liveCounts.going}/${event.audience.capacity} spots availible'
        : 'Unlimited spots availible';
    items.add(
      _buildAudienceRow(
        icon: Icons.groups_rounded,
        text: spotsText,
      ),
    );

    // Plus Ones
    final bool allowsPlusOnes = event.audience.maxPlusOnes > 0;
    items.add(
      _buildAudienceRow(
        customIcon: allowsPlusOnes
            ? Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+${event.audience.maxPlusOnes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
        icon: allowsPlusOnes ? null : Icons.person_off_rounded,
        text: allowsPlusOnes ? '+${event.audience.maxPlusOnes} Allowed' : 'No plus ones allowed',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: item,
      )).toList(),
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
        const SizedBox(width: 12),
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

    return TextSpan(
      children: [
        TextSpan(
          text: displayStr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
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
                padding: const EdgeInsets.all(16),
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
}
