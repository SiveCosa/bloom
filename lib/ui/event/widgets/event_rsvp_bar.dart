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

    final double barHeight = requireApproval ? 50 : 75;
    final double borderRadiusVal = requireApproval ? 25 : 37.5;

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
              onTap: () {
                if (currentStatus == 'requested' || currentStatus == 'waitlisted') {
                  _handleRemoveRsvp(userId);
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
                  color: (currentStatus == 'requested' || currentStatus == 'waitlisted')
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      currentStatus == 'requested'
                          ? Icons.check_circle
                          : (isFull && !showWaitlist && !isAlreadyGoing) 
                              ? Icons.block 
                              : Icons.add_circle_outline,
                      color: (currentStatus == 'requested' || currentStatus == 'waitlisted')
                          ? Colors.black
                          : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentStatus == 'requested'
                          ? 'Requested'
                          : (isFull && !isAlreadyGoing)
                              ? (showWaitlist ? 'Join Waitlist' : 'Event Full')
                              : 'Get on List',
                      style: TextStyle(
                        color: (currentStatus == 'requested' || currentStatus == 'waitlisted')
                            ? const Color(0xFF4B5563)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final buttonWidth = (constraints.maxWidth - 2) / buttonCount;
                final leftOffset = displayIndex * (buttonWidth + 1);

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
                      width: buttonWidth,
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
                            icon: Icons.check_circle,
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
                            icon: currentStatus == 'going'
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
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
                            icon: currentStatus == 'maybe'
                                ? Icons.help
                                : Icons.help_outline,
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
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                'Bringing anyone?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can bring up to $maxPlusOnes guests.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(maxPlusOnes + 1, (index) {
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(index),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Center(
                        child: Text(
                          index == 0 ? 'Just\nMe' : '+$index',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        : Colors.white.withValues(alpha: 0.6),
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
                          : Colors.white.withValues(alpha: 0.6),
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
