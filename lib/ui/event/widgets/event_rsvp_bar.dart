import 'package:bloom/domain/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/event_providers.dart';
import '../../../data/event/event_repository.dart';
import '../../../domain/auth/auth_providers.dart';

class EventRsvpBar extends ConsumerStatefulWidget {
  final String eventId;

  const EventRsvpBar({super.key, required this.eventId});

  @override
  ConsumerState<EventRsvpBar> createState() => _EventRsvpBarState();
}

class _EventRsvpBarState extends ConsumerState<EventRsvpBar> {
  int? _lastNonNullActiveIndex;
  bool _hasActiveSelection = false;
  bool _shouldAnimate = false;
  bool _isInitialized = false;

  int? _getIndexForStatus(String? status, {required bool allowMaybe}) {
    if (status == 'going' || status == 'waitlisted') {
      return 0;
    }
    if (status == 'maybe' && allowMaybe) {
      return 1;
    }
    if (status == 'declined') {
      return allowMaybe ? 2 : 1;
    }
    return null;
  }

  void _initializeIfNeeded(String? initialStatus, bool allowMaybe) {
    if (_isInitialized) return;
    _isInitialized = true;
    final initialIndex = _getIndexForStatus(initialStatus, allowMaybe: allowMaybe);
    if (initialIndex != null) {
      _hasActiveSelection = true;
      _lastNonNullActiveIndex = initialIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes to handle animation transition toggles
    ref.listen<AsyncValue<String?>>(userEventRsvpProvider(widget.eventId), (prevVal, nextVal) {
      final prevStatus = prevVal?.value;
      final nextStatus = nextVal.value;

      final allowMaybe =
          ref.read(eventStreamProvider(widget.eventId)).value?.audience.allowMaybe ?? true;
      final prevIndex = _getIndexForStatus(prevStatus, allowMaybe: allowMaybe);
      final nextIndex = _getIndexForStatus(nextStatus, allowMaybe: allowMaybe);

      setState(() {
        if (nextIndex != null) {
          _hasActiveSelection = true;
          if (prevIndex != null && prevIndex != nextIndex) {
            _shouldAnimate = true;
          } else {
            _shouldAnimate = false;
          }
          _lastNonNullActiveIndex = nextIndex;
        } else {
          _hasActiveSelection = false;
          _shouldAnimate = false;
        }
      });
    });

    final eventAsync = ref.watch(eventStreamProvider(widget.eventId));
    final rsvpStatusAsync = ref.watch(userEventRsvpProvider(widget.eventId));
    final userId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return eventAsync.when(
      data: (event) {
        if (event == null) return const SizedBox.shrink();
        return rsvpStatusAsync.when(
          data: (status) {
            _initializeIfNeeded(status, event.audience.allowMaybe);
            return _buildBar(context, userId, status, event);
          },
          loading: () => _buildLoadingBar(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildLoadingBar(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Color _parseHexColor(String hex) {
    String hexStr = hex.replaceFirst('#', '');
    if (hexStr.length == 6) hexStr = 'FF$hexStr';
    try {
      return Color(int.parse(hexStr, radix: 16));
    } catch (e) {
      return const Color(0xFFAD83FE);
    }
  }

  Widget _buildBar(
    BuildContext context,
    String? userId,
    String? currentStatus,
    Event event,
  ) {
    final bool isFull = event.isFull;
    final bool showWaitlist = event.shouldShowWaitlist;
    final bool isAlreadyGoing = currentStatus == 'going';
    final bool isAlreadyWaitlisted = currentStatus == 'waitlisted';
    final requireApproval = event.audience.requireApproval;
    final allowMaybe = event.audience.allowMaybe;
    final isPastDeadline = event.audience.rsvpDeadline != null && DateTime.now().isAfter(event.audience.rsvpDeadline!);

    final colors = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
    
    List<Color> gradientColors;
    if (colors.length >= 2) {
      gradientColors = [colors[0], colors[1]];
    } else if (colors.length == 1) {
      gradientColors = [colors[0], colors[0].withValues(alpha: 0.8)];
    } else {
      gradientColors = [const Color(0xFF6366f1), const Color(0xFFa855f7)];
    }

    final double barHeight = 75;
    final double borderRadiusVal = 37.5;

    final activeIndex = _getIndexForStatus(currentStatus, allowMaybe: allowMaybe);
    final displayIndex = _lastNonNullActiveIndex ?? 0;
    final buttonCount = allowMaybe ? 3 : 2;

    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadiusVal),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isPastDeadline
          ? const Center(
              child: Text(
                'RSVP period has ended',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : requireApproval
          ? GestureDetector(
              onTap: () async {
                if (currentStatus == 'requested' || currentStatus == 'waitlisted' || currentStatus == 'going') {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF15191D),
                      title: const Text('Remove RSVP?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: const Text(
                        'If you remove your RSVP, you will need to request to get on the list again.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    _handleRemoveRsvp(userId);
                  }
                } else if (isFull && !isAlreadyGoing) {
                  if (showWaitlist) {
                    _handleRsvp(userId, 'waitlisted', event: event);
                  }
                } else {
                  _handleRsvp(userId, 'requested', event: event);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: (currentStatus == 'requested' || currentStatus == 'waitlisted' || currentStatus == 'going')
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(34),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      (currentStatus == 'requested' || currentStatus == 'waitlisted' || currentStatus == 'going')
                          ? Icons.check_circle
                          : (isFull && !showWaitlist && !isAlreadyGoing) 
                              ? Icons.block 
                              : Icons.add_circle_outline,
                      color: (currentStatus == 'requested' || currentStatus == 'waitlisted' || currentStatus == 'going')
                          ? Colors.black
                          : Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStatus == 'going'
                          ? 'Going'
                          : currentStatus == 'requested'
                              ? 'Requested'
                              : currentStatus == 'waitlisted'
                                  ? 'Waitlisted'
                                  : (isFull && !isAlreadyGoing)
                                      ? (showWaitlist ? 'Join Waitlist' : 'Event Full')
                                      : 'Get on List',
                      style: TextStyle(
                        color: (currentStatus == 'requested' || currentStatus == 'waitlisted' || currentStatus == 'going')
                            ? const Color(0xFF4B5563)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final totalDividerWidth = (buttonCount - 1).toDouble();
                final actualMaxWidth = (constraints.maxWidth.isInfinite || constraints.maxWidth.isNaN) 
                    ? MediaQuery.of(context).size.width - 30.0 
                    : constraints.maxWidth;
                final safeMaxWidth = actualMaxWidth < 0 ? 0.0 : actualMaxWidth;
                final buttonWidth = (safeMaxWidth - totalDividerWidth) / buttonCount;
                final safeButtonWidth = (buttonWidth.isInfinite || buttonWidth.isNaN || buttonWidth < 0) 
                    ? 0.0 
                    : buttonWidth;
                
                final maxLeft = safeMaxWidth - safeButtonWidth;
                double leftOffset = displayIndex * (safeButtonWidth + 1.0);
                if (leftOffset.isNaN || leftOffset.isInfinite) leftOffset = 0.0;
                if (!maxLeft.isNaN && !maxLeft.isInfinite && leftOffset > maxLeft) leftOffset = maxLeft;
                if (leftOffset < 0) leftOffset = 0.0;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: _shouldAnimate
                          ? const Duration(milliseconds: 250)
                          : Duration.zero,
                      curve: Curves.easeInOutCubic,
                      left: leftOffset,
                      top: 0,
                      bottom: 0,
                      width: safeButtonWidth,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hasActiveSelection ? 1.0 : 0.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(34),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isAlreadyGoing)
                          _RsvpButton(
                            label: 'Going',
                            icon: Icons.check_circle_outline,
                            isSelected: activeIndex == 0,
                            onPressed: () => _handleRemoveRsvp(userId),
                          )
                        else if (isAlreadyWaitlisted)
                          _RsvpButton(
                            label: 'Waitlisted',
                            icon: Icons.access_time_filled_rounded,
                            isSelected: activeIndex == 0,
                            onPressed: () => _handleRemoveRsvp(userId),
                          )
                        else if (isFull)
                          _RsvpButton(
                            label: showWaitlist ? 'Waitlist' : 'Event Full',
                            icon: showWaitlist ? Icons.access_time_rounded : Icons.block,
                            isSelected: activeIndex == 0,
                            isDisabled: !showWaitlist,
                            onPressed: showWaitlist 
                                ? () => _handleRsvp(userId, 'waitlisted', event: event)
                                : () {},
                          )
                        else
                          _RsvpButton(
                            label: 'Going',
                            icon: Icons.check_circle_outline,
                            isSelected: activeIndex == 0,
                            onPressed: () {
                              if (currentStatus == 'going') {
                                _handleRemoveRsvp(userId);
                              } else {
                                _handleRsvp(userId, 'going', event: event);
                              }
                            },
                          ),
                        if (allowMaybe) ...[
                          _buildRSVPDivider(),
                          _RsvpButton(
                            label: 'Maybe',
                            icon: Icons.help_outline,
                            isSelected: activeIndex == 1,
                            isDisabled: isFull &&
                                !isAlreadyGoing &&
                                !isAlreadyWaitlisted &&
                                currentStatus != 'maybe',
                            onPressed: () {
                              if (currentStatus == 'maybe') {
                                _handleRemoveRsvp(userId);
                              } else {
                                _handleRsvp(userId, 'maybe', event: event);
                              }
                            },
                          ),
                        ],
                        _buildRSVPDivider(),
                        _RsvpButton(
                          label: 'Decline',
                          icon: currentStatus == 'declined'
                              ? Icons.highlight_off_rounded
                              : Icons.highlight_off,
                          isSelected: activeIndex == (allowMaybe ? 2 : 1),
                          onPressed: () {
                            if (currentStatus == 'declined') {
                              _handleRemoveRsvp(userId);
                            } else {
                              _handleRsvp(userId, 'declined', event: event);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildRSVPDivider() {
    return Center(
      child: Container(
        width: 1,
        height: 30,
        color: Colors.white.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
    );
  }

  Future<int?> _showPlusOnesSelector(BuildContext context, int maxPlusOnes) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Bringing anyone?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'You can bring up to $maxPlusOnes guests.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: List.generate(maxPlusOnes + 1, (index) {
                  final title = index == 0 ? 'Just Me' : '+$index';
                  final subtitle = index == 0 
                      ? "I won't be bringing anyone" 
                      : (index == 1 ? "I'll be bringing +1 person" : "I'll be bringing +$index people");
                  
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                index == 0 ? '0' : '+$index',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRsvp(String? userId, String status, {Event? event}) async {
    if (userId == null) return;
    
    int plusOnes = 0;
    if ((status == 'going' || status == 'requested') && event != null && event.audience.maxPlusOnes > 0) {
      final selectedPlusOnes = await _showPlusOnesSelector(context, event.audience.maxPlusOnes);
      if (selectedPlusOnes == null) return; // Cancelled
      plusOnes = selectedPlusOnes;
    }
    
    await ref.read(eventRepositoryProvider).updateRSVP(widget.eventId, userId, status, plusOnesCount: plusOnes);
  }

  Future<void> _handleRemoveRsvp(String? userId) async {
    if (userId == null) return;
    await ref.read(eventRepositoryProvider).removeRSVP(widget.eventId, userId);
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onPressed;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isDisabled = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isDisabled 
                    ? Colors.white.withValues(alpha: 0.2)
                    : isSelected
                        ? Colors.black
                        : Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDisabled 
                      ? Colors.white.withValues(alpha: 0.2)
                      : isSelected
                          ? const Color(0xFF4B5563)
                          : Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
