import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/event/create_event_state.dart';
import '../../domain/event/event_visibility.dart';
import '../../domain/event/event_extra.dart';
import '../../domain/auth/auth_providers.dart';
import 'widgets/aurora_background.dart';
import 'widgets/host_invite_section.dart';
import '../shared/widgets/event_weather_card.dart';

class EventPreviewScreen extends ConsumerStatefulWidget {
  const EventPreviewScreen({super.key});

  @override
  ConsumerState<EventPreviewScreen> createState() => _EventPreviewScreenState();
}

class _EventPreviewScreenState extends ConsumerState<EventPreviewScreen> {
  bool _isPublishing = false;
  bool _isDescriptionExpanded = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ValueNotifier<double> _sheetSize = ValueNotifier(0.55);

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

  Future<void> _handlePublish() async {
    setState(() => _isPublishing = true);
    try {
      final success = await ref.read(createEventProvider.notifier).compileAndPublishEvent();
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event posted successfully!')),
          );
          context.go('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to post event. Please try again.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventProvider);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E12),
      body: Stack(
        children: [
          // 1. Poster Image + Glow (Reactive)
          ValueListenableBuilder<double>(
            valueListenable: _sheetSize,
            builder: (context, size, child) {
              final double screenHeight = MediaQuery.of(context).size.height;
              final double topBarHeight = MediaQuery.of(context).padding.top + 56;
              final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
              final double maxSheetSize = 0.9 - (10 / screenHeight);
              final double expandedProgress = ((size - 0.55) / (maxSheetSize - 0.55)).clamp(0.0, 1.0);
              final double posterOpacity = (1.0 - expandedProgress).clamp(0.0, 1.0);
              
              final double actualPosterHeight = MediaQuery.of(context).size.width / (state.visuals.aspectRatio > 0 ? state.visuals.aspectRatio : 1.0);
              final bool isSquare = (state.visuals.aspectRatio - 1.0).abs() < 0.1;
              final double sheetTopMinimized = screenHeight * (1.0 - 0.35);
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
                        0.35,
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
                                color: (state.auroraColors.isNotEmpty ? state.auroraColors[0] : const Color(0xFFAD83FE))
                                    .withValues(alpha: 0.45 * minimizedProgress * (1.0 - expandedProgress)),
                                blurRadius: 120,
                                spreadRadius: 40,
                              ),
                          ],
                        ),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: AspectRatio(
                            aspectRatio: state.visuals.aspectRatio,
                            child: state.customPosterBytes != null
                                ? Image.memory(
                                    state.customPosterBytes!,
                                    key: ValueKey(state.customPosterBytes),
                                    fit: BoxFit.cover,
                                  )
                                : (state.visuals.posterUrl != null || state.defaultPosterUrl != null)
                                    ? Image.network(
                                        state.visuals.posterUrl ?? state.defaultPosterUrl!,
                                        key: ValueKey(state.visuals.posterUrl ?? state.defaultPosterUrl),
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

          // 2. Draggable Scrollable Sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9 - (10 / MediaQuery.of(context).size.height),
            snap: true,
            snapSizes: [0.35, 0.55, 0.9 - (10 / MediaQuery.of(context).size.height)],
            builder: (context, scrollController) {
              final double screenHeight = MediaQuery.of(context).size.height;
              
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
                          final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
                          return Positioned(
                            top: -(MediaQuery.of(context).size.height * (1.0 - size)),
                            left: 0,
                            right: 0,
                            height: MediaQuery.of(context).size.height,
                            child: Opacity(
                              opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                              child: AuroraBackground(colors: state.auroraColors),
                            ),
                          );
                        },
                      ),
                      // Subtle Glass Overlay (Reactive)
                      ValueListenableBuilder<double>(
                        valueListenable: _sheetSize,
                        builder: (context, size, child) {
                          final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
                          return Positioned.fill(
                            child: Opacity(
                              opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                              child: Container(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          );
                        },
                      ),
                      // Sticky Gripper (Reactive)
                      ValueListenableBuilder<double>(
                        valueListenable: _sheetSize,
                        builder: (context, size, child) {
                          final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
                          final double maxSheetSize = 0.9 - (10 / screenHeight);
                          final double expandedProgress = ((size - 0.55) / (maxSheetSize - 0.55)).clamp(0.0, 1.0);
                          
                          return Positioned(
                            top: 10,
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
                                final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
                                return SizedBox(height: ui.lerpDouble(29, 79, minimizedProgress) ?? 29);
                              },
                            ),
                            
                            _buildVisibilityPill(state),
                            const SizedBox(height: 5),

                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Colors.white70],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  state.title.isEmpty ? 'Untitled Event' : state.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            _buildDateRow(state),
                            const SizedBox(height: 10),

                            if (state.location != null) ...[
                              _buildLocationRow(state),
                              const SizedBox(height: 20),
                            ],

                            // Non-essential content (Reactive)
                            ValueListenableBuilder<double>(
                              valueListenable: _sheetSize,
                              builder: (context, size, child) {
                                final double minimizedProgress = ((0.55 - size) / (0.55 - 0.35)).clamp(0.0, 1.0);
                                return AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                                  child: Visibility(
                                    visible: size > 0.4,
                                    child: Column(
                                      children: [
                                        if (state.description.isNotEmpty || state.tags.isNotEmpty || state.extras.isNotEmpty) ...[
                                          _buildDescriptionCard(state),
                                          const SizedBox(height: 16),
                                        ],
                                        HostInviteSection(
                                          showInviteFriends: true,
                                          userProfile: userProfile,
                                          onAddCoHost: () {},
                                        ),
                                        if (state.location != null) ...[
                                          EventWeatherCard(
                                            location: state.location,
                                            startDate: state.timing.startDate,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildMapCard(state),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                                  ),
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

          // 3. Top App Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isPublishing ? null : _handlePublish,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Post event',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Loading Overlay
          if (_isPublishing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),

          // 5. Bottom Gradient Grounding (Reactive)
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

          // 6. Floating RSVP Action Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 30, 
            child: _buildRSVPActionBar(state),
          ),
        ],
      ),
    );

  }

  Widget _buildDateRow(CreateEventState state) {
    final start = state.timing.startDate;
    final end = state.timing.endDate;
    final startTbd = state.timing.startTimeTbd;
    final endTbd = state.timing.endTimeTbd;

    if (start == null) return const SizedBox.shrink();

    String startStr = DateFormat('EEE, d MMM').format(start);
    if (!startTbd) {
      startStr += ' ${DateFormat('h a').format(start).toLowerCase()}';
    }

    String display = startStr;
    if (end != null) {
      String endStr = '';
      // If same day, only show time
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
        const Icon(Icons.event, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            display,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(CreateEventState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            state.location?.displayName ?? '',
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


  Widget _buildTagsSection(CreateEventState state) {
    final tags = state.tags;
    if (tags.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) => _buildTagChip(tag)).toList(),
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

  Widget _buildDescriptionCard(CreateEventState state) {
    return Container(
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
              if (state.tags.isNotEmpty) _buildTagsSection(state),
              if (state.description.isNotEmpty) ...[
                if (state.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSeparator(),
                  const SizedBox(height: 16),
                ],
                _buildExpandableDescription(state),
              ],
              if (state.extras.isNotEmpty) ...[
                if (state.tags.isNotEmpty || state.description.isNotEmpty) const SizedBox(height: 16),
                _buildSeparator(),
                const SizedBox(height: 16),
                ...(() {
                  final sortedExtras = [...state.extras]..sort((a, b) {
                    final aIsLink = a.url != null && a.url!.isNotEmpty;
                    final bIsLink = b.url != null && b.url!.isNotEmpty;
                    if (aIsLink && !bIsLink) return -1;
                    if (!aIsLink && bIsLink) return 1;
                    return 0;
                  });
                  return sortedExtras.map((extra) {
                    final bool isLink = extra.url != null && extra.url!.isNotEmpty;
                    final Color textColor = isLink ? _getBestExtraColor(state.auroraColors) : Colors.white;

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
                          children: [
                            Icon(
                              isLink ? Icons.link : extra.type.icon,
                              color: isLink ? textColor : Colors.white.withValues(alpha: 0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                extra.displayText,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: isLink ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isLink)
                              Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.4), size: 16),
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





  Widget _buildExpandableDescription(CreateEventState state) {
    final String text = state.description;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = _getFormattedDescriptionSpan(text);
        final tp = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);

        // Check if height exceeds 200dp
        final bool canExpand = tp.height > 200;

        return GestureDetector(
          onTap: canExpand ? () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded) : null,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canExpand && !_isDescriptionExpanded)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.transparent],
                        stops: [0.8, 1.0],
                      ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                    },
                    blendMode: BlendMode.dstIn,
                    child: Text.rich(
                      textSpan,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                )
              else
                Text.rich(textSpan),
              
              if (canExpand) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _isDescriptionExpanded ? 'Read less' : 'Read more',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: _isDescriptionExpanded ? 0.5 : 0.75,
                      ),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  TextSpan _getFormattedDescriptionSpan(String text) {
    final pattern = RegExp(
      r'(\*[^\s\*](?:.*?[^\s\*])?\*)|(![^\s!](?:.*?[^\s!])?!)',
      multiLine: true,
    );

    final List<TextSpan> children = [];
    int lastMatchEnd = 0;
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      height: 1.5,
    );

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchText = match.group(0)!;

      if (match.group(1) != null) {
        children.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
      } else if (match.group(2) != null) {
        children.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16.0,
            color: Colors.white,
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: children);
  }




  Widget _buildMapCard(CreateEventState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 2.1,
              child: Container(
                color: Colors.grey[800],
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
                    state.location?.displayName ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.location?.formattedAddress ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRSVPActionBar(CreateEventState state) {
    final allowMaybe = state.audience.allowMaybe;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(32.5),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: state.audience.requireApproval ? 50 : 65,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(state.audience.requireApproval ? 25 : 32.5),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: state.audience.requireApproval
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Get on the list',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _buildRSVPButton(Icons.check_circle_outline, 'Going'),
                    if (allowMaybe) ...[
                      _buildRSVPDivider(),
                      _buildRSVPButton(Icons.help_outline, 'Maybe'),
                    ],
                    _buildRSVPDivider(),
                    _buildRSVPButton(Icons.highlight_off, 'Decline'),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRSVPButton(IconData icon, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This is a preview. RSVP actions are disabled.')),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityPill(CreateEventState state) {
    final visibility = state.audience.visibility;
    String text = visibility.title;
    if (visibility == EventVisibility.public || visibility == EventVisibility.private) {
      text += ' event';
    }

    return Center(
      child: Container(
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
          ],
        ),
      ),
    );
  }

  Widget _buildRSVPDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Color _getBestExtraColor(List<Color> colors) {
    if (colors.isEmpty) return const Color(0xFF6C8EEF);

    // Find the color with the highest luminance that is bright enough
    Color best = colors.first;
    double maxLuminance = best.computeLuminance();

    for (final color in colors) {
      final lum = color.computeLuminance();
      if (lum > maxLuminance) {
        maxLuminance = lum;
        best = color;
      }
    }

    // If it's too dark (against our dark background), use brand blue or a default
    if (maxLuminance < 0.3) {
      return const Color(0xFF6C8EEF);
    }

    return best;
  }

}

