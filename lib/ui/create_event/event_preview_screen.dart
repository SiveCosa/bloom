import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/event/create_event_state.dart';
import '../../domain/event/event_visibility.dart';
import '../../domain/event/event_extra.dart';
import '../../domain/event/event.dart';
import '../../domain/auth/auth_providers.dart';
import 'widgets/aurora_background.dart';
import 'widgets/host_invite_section.dart';
import '../shared/widgets/event_weather_card.dart';
import '../event/widgets/guest_list_card.dart';

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
      await ref.read(createEventProvider.notifier).compileAndPublishEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event posted successfully!')),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
              final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
              final double maxSheetSize = 0.88 - (10 / screenHeight);
              final double expandedProgress = ((size - 0.55) / (maxSheetSize - 0.55)).clamp(0.0, 1.0);
              final double posterOpacity = (1.0 - expandedProgress).clamp(0.0, 1.0);
              
              final double actualPosterHeight = MediaQuery.of(context).size.width / (state.visuals.aspectRatio > 0 ? state.visuals.aspectRatio : 1.0);
              final bool isSquare = (state.visuals.aspectRatio - 1.0).abs() < 0.1;
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
            minChildSize: 0.28,
            maxChildSize: 0.88 - (10 / MediaQuery.of(context).size.height),
            snap: true,
            snapSizes: [0.28, 0.55, 0.88 - (10 / MediaQuery.of(context).size.height)],
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
                            final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
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
                            // Fixed Transparent Header with Rotating Chevron Gripper
                            SizedBox(
                              height: 25,
                              width: double.infinity,
                              child: Center(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _sheetSize,
                                  builder: (context, size, child) {
                                    final double minimizedProgress = ((0.55 - size) / (0.55 - 0.28)).clamp(0.0, 1.0);
                                    final double maxSheetSize = 0.88 - (10 / screenHeight);
                                    final double expandedProgress = ((size - 0.55) / (maxSheetSize - 0.55)).clamp(0.0, 1.0);
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 0),
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
                                    );
                                  },
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
                                          
                                          _buildVisibilityPill(state),
                                          const SizedBox(height: 16),
                                          
                                          ShaderMask(
                                            shaderCallback: (bounds) => ui.Gradient.linear(
                                              Offset.zero,
                                              Offset(bounds.width, 0),
                                              [Colors.white, Colors.white.withValues(alpha: 0.7)],
                                            ),
                                            child: Text(
                                              state.title.isEmpty ? 'Untitled Event' : state.title,
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
                                                  _buildDateRow(state),
                                                  if (state.location != null) ...[
                                                    const SizedBox(height: 10),
                                                    Opacity(
                                                      opacity: (1.0 - minimizedProgress).clamp(0.0, 1.0),
                                                      child: _buildLocationRow(state),
                                                    ),
                                                  ],
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
                                        
                                        final mockEvent = _getMockEvent(state, userProfile);
                                        
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 15),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (state.description.isNotEmpty || state.tags.isNotEmpty || state.extras.isNotEmpty) ...[
                                                _buildDescriptionCard(state),
                                                const SizedBox(height: 16),
                                              ],
                                              GuestListCard(
                                                event: mockEvent,
                                                onInvitePressed: () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('This is a preview. Share action is disabled.')),
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 16),
                                              HostInviteSection(
                                                userProfile: userProfile,
                                                coHosts: state.coHosts,
                                                onAddCoHost: () {},
                                                showInviteFriends: false,
                                              ),
                                              if (state.location != null) ...[
                                                const SizedBox(height: 16),
                                                EventWeatherCard(
                                                  location: state.location,
                                                  startDate: state.timing.startDate,
                                                ),
                                                const SizedBox(height: 16),
                                                _buildMapCard(mockEvent),
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

          // 3. Top App Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopButton(
                    const Icon(Icons.close, color: Colors.black, size: 22),
                    () => context.pop(),
                  ),
                  GestureDetector(
                    onTap: _isPublishing ? null : _handlePublish,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Post event',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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
      startStr += ' ${DateFormat('ha').format(start).toLowerCase()}';
    }

    String display = startStr;
    if (end != null) {
      String endStr = '';
      // If same day, only show time
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

  Widget _buildLocationRow(CreateEventState state) {
    if (state.location == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            state.location!.displayName,
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


  Widget _buildTagsSection(CreateEventState state) {
    final tags = state.tags;
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
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
    final bool hasTags = state.tags.isNotEmpty;
    final bool hasDesc = state.description.isNotEmpty;
    final bool hasExtras = state.extras.isNotEmpty;

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
                  _buildTagsSection(state),
                  const SizedBox(height: 25),
                  _buildSeparator(),
                  const SizedBox(height: 25),
                ],
                
                _buildLogisticsSection(state),
                
                if (hasExtras) ...[
                  const SizedBox(height: 25),
                  ...(() {
                    final sortedExtras = [...state.extras]..sort((a, b) {
                      final aIsLink = a.url != null && a.url!.isNotEmpty;
                      final bIsLink = b.url != null && b.url!.isNotEmpty;
                      if (aIsLink && !bIsLink) return -1;
                      if (!aIsLink && bIsLink) return 1;
                      return 0;
                    });
                    
                    return List.generate(sortedExtras.length, (index) {
                      final extra = sortedExtras[index];
                      final bool isLink = extra.url != null && extra.url!.isNotEmpty;
                      final Color textColor = isLink ? _getBestExtraColor(state.auroraColors) : Colors.white;
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
                  _buildExpandableDescription(state),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }





  Widget _buildExpandableDescription(CreateEventState state) {
    final String text = state.description;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: _getFormattedDescriptionSpan(text),
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
                              _getFormattedDescriptionSpan(text),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          )
                        : Text.rich(
                            _getFormattedDescriptionSpan(text),
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

  Widget _buildLogisticsSection(CreateEventState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // RSVP Deadline
        if (state.audience.rsvpDeadline != null) ...[
          _buildLogisticsRow(
            icon: Icons.hourglass_bottom_rounded,
            text: 'RSVP by ${DateFormat('d MMMM yyyy').format(state.audience.rsvpDeadline!)}',
          ),
          const SizedBox(height: 25),
        ],

        // Capacity / Spots
        _buildLogisticsRow(
          icon: Icons.groups_rounded,
          text: state.audience.capacity != null
              ? '${state.audience.capacity} spots available'
              : 'Unlimited spots available',
        ),
        const SizedBox(height: 25),

        // Plus Ones
        _buildLogisticsRow(
          icon: Icons.person_add_rounded,
          text: state.audience.maxPlusOnes > 0 ? '+${state.audience.maxPlusOnes} guests allowed' : 'No plus ones allowed',
        ),
      ],
    );
  }

  Widget _buildLogisticsRow({IconData? icon, Widget? customIcon, required String text}) {
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

  TextSpan _getFormattedDescriptionSpan(String text) {
    final List<String> lines = text.split('\n');
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




  Widget _buildMapCard(Event event) {
    if (event.location == null) return const SizedBox.shrink();
    final themeColor = event.visuals.auroraColors.isNotEmpty
        ? _parseHexColor(event.visuals.auroraColors[0])
        : const Color(0xFFAD83FE);

    return _PulsingMapCard(
      event: event,
      themeColor: themeColor,
      onLaunchMap: (lat, lng, label) async {
        final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
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

  Event _getMockEvent(CreateEventState state, Map<String, dynamic>? userProfile) {
    return Event(
      id: 'preview',
      title: state.title.isEmpty ? 'Untitled Event' : state.title,
      description: state.description,
      tags: state.tags,
      visuals: EventVisuals(
        aspectRatio: state.visuals.aspectRatio,
        auroraColors: state.auroraColors.map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}').toList(),
        posterUrl: state.visuals.posterUrl ?? state.defaultPosterUrl,
      ),
      timing: state.timing,
      location: state.location,
      audience: state.audience,
      extras: state.extras,
      rsvpReminders: state.rsvpReminders,
      liveCounts: const EventLiveCounts(going: 0, maybe: 0, interested: 0),
      previewGuests: const [],
      metadata: EventMetadata(
        hostId: userProfile?['uid'] as String? ?? 'preview_host',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: EventStatus.active,
      ),
      coHostIds: state.coHosts.map((e) => e['uid'] as String? ?? '').where((id) => id.isNotEmpty).toList(),
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

