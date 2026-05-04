import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/event/create_event_state.dart';
import '../../domain/auth/auth_providers.dart';
import 'widgets/event_title_input.dart';
import 'widgets/poster_module.dart';
import 'widgets/date_time_row.dart';
import 'widgets/poster_selection_modal.dart';
import 'widgets/date_time_modal.dart';
import 'widgets/event_section_card.dart';
import 'widgets/bloom_toggle.dart';
import 'widgets/event_description_input.dart';
import 'widgets/visibility_selection_modal.dart';
import 'widgets/audience_modal.dart';
import 'widgets/plus_ones_selection_modal.dart';
import 'widgets/tag_selection_modal.dart';
import '../../domain/event/event_visibility.dart';

class CreateEventScreen extends ConsumerWidget {
  const CreateEventScreen({super.key});

  void _showPosterSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PosterSelectionModal(),
    );
  }

  void _showVisibilitySelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VisibilitySelectionModal(),
    );
  }

  void _showDateTimeSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => const DateTimeModal(),
    );
  }

  void _showSkeletonModal(BuildContext context, String title) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AudienceModal(title: title),
    );
  }

  void _showPlusOnesSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlusOnesSelectionModal(),
    );
  }

  void _showTagSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TagSelectionModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventProvider);
    final userProfile = ref.watch(currentUserProfileProvider).value;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(createEventProvider.notifier).reset();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E12),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              // The Full Background Stack
              const Positioned.fill(child: _AuroraBackground()),

              SafeArea(
                child: Column(
                  children: [
                    // Custom App Bar (Premium Pill Styling)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            // Back Button (Left)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  ref
                                      .read(createEventProvider.notifier)
                                      .reset();
                                  context.pop();
                                },
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
                            ),
                            // Centered Title
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Create Event',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Preview Button (Right)
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  context.push('/create-event/preview');
                                },
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Preview',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        children: [
                          const SizedBox(height: 10),

                          // Event Title Input
                          EventTitleInput(
                            initialValue: state.title,
                            onChanged: (val) => ref
                                .read(createEventProvider.notifier)
                                .updateTitle(val),
                          ),

                          const SizedBox(
                            height: 0,
                          ), //leave as sero please incase i want to chane the gap
                          // Poster Module
                          PosterModule(
                            onEditPoster: () => _showPosterSelection(context),
                          ),

                          const SizedBox(height: 10),

                          // Date & Time Row
                          DateTimeRow(
                            onTap: () => _showDateTimeSelection(context),
                          ),

                          const SizedBox(height: 10),

                          // Location Section
                          GestureDetector(
                            onTap: () =>
                                _showSkeletonModal(context, 'Location'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    state.isLocationSet
                                        ? (state.location ?? 'Set location')
                                        : 'Set location',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Hosted by Section
                          EventSectionCard(
                            headerIcon: Icons.workspace_premium,
                            title: 'Hosted by',
                            body: Row(
                              children: [
                                Column(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundImage:
                                              userProfile?['profile_image_url'] !=
                                                  null
                                              ? NetworkImage(
                                                  userProfile!['profile_image_url'],
                                                )
                                              : null,
                                          backgroundColor: Colors.white10,
                                          child:
                                              userProfile?['profile_image_url'] ==
                                                  null
                                              ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white54,
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE91E63),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.workspace_premium,
                                              color: Colors.white,
                                              size: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userProfile?['username'] ?? 'username',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                InkWell(
                                  onTap: () =>
                                      _showSkeletonModal(context, 'Add Cohost'),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.15,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            width: 1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Add Cohost',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Audience Section
                          EventSectionCard(
                            headerIcon: Icons.people,
                            title: 'Audience',
                            body: Column(
                              children: [
                                _buildTappableRow(
                                  context: context,
                                  icon: state.visibility.outlinedIcon,
                                  title: state.visibility.title,
                                  trailing: 'Set Visibility',
                                  onTap: () =>
                                      _showVisibilitySelection(context),
                                ),
                                const _AvailableSpotsRow(),
                                _buildTappableRow(
                                  context: context,
                                  icon: Icons.person_add_outlined,
                                  title: state.maxPlusOnes > 0
                                      ? '+${state.maxPlusOnes} allowed'
                                      : 'No plus ones',
                                  trailing: 'Plus ones',
                                  onTap: () => _showPlusOnesSelection(context),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Event Details Section
                          EventSectionCard(
                            headerIcon: Icons.edit_note_outlined,
                            title: 'Event Details',
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Event Tags',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...state.tags.map(
                                      (tag) => GestureDetector(
                                        onTap: () => ref
                                            .read(createEventProvider.notifier)
                                            .toggleTag(tag),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                            border: Border.all(
                                              color: Colors.white54,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tag,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (state.tags.length < 5)
                                      GestureDetector(
                                        onTap: () => _showTagSelection(context),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                              style: BorderStyle.solid,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.add,
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Add Tag',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                EventDescriptionInput(
                                  initialValue: state.description,
                                  onChanged: (val) => ref
                                      .read(createEventProvider.notifier)
                                      .updateDescription(val),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    '${state.description.length} / 2 000',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.40,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Extras Section
                          EventSectionCard(
                            headerIcon: Icons.auto_awesome,
                            title: 'Extras',
                            body: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildPillButton(context, '+ Link', 'Link'),
                                _buildPillButton(
                                  context,
                                  '+ Dress code',
                                  'Dress code',
                                ),
                                _buildPillButton(
                                  context,
                                  '+ Food situation',
                                  'Food situation',
                                ),
                                _buildPillButton(
                                  context,
                                  '+ Parking',
                                  'Parking',
                                ),
                                _buildPillButton(
                                  context,
                                  '+ Accommodation',
                                  'Accommodation',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // RSVP Options Section
                          EventSectionCard(
                            headerIcon: Icons.tune,
                            title: 'RSVP Options',
                            body: Column(
                              children: [
                                // Graphic Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildRSVPVisual(
                                        Icons.check_circle_outline,
                                        'Going',
                                      ),
                                      _buildRSVPVisual(
                                        Icons.help_outline,
                                        'Maybe',
                                      ),
                                      _buildRSVPVisual(
                                        Icons.cancel_outlined,
                                        'Not Going',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildToggleRow(
                                  'Require guest approval',
                                  state.requireApproval,
                                  (val) {
                                    ref
                                        .read(createEventProvider.notifier)
                                        .setRequireApproval(val);
                                  },
                                ),
                                _buildToggleRow(
                                  "Guest can RSVP 'Maybe'",
                                  state.allowMaybe,
                                  (val) {
                                    ref
                                        .read(createEventProvider.notifier)
                                        .setAllowMaybe(val);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildTappableRow(
                                  context: context,
                                  icon: Icons.access_time,
                                  title: 'RSVP Deadline',
                                  trailing: state.rsvpDeadline != null
                                      ? 'Set'
                                      : 'Optional',
                                  onTap: () => _showSkeletonModal(
                                    context,
                                    'RSVP Deadline',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTappableRow({
    required BuildContext context,
    IconData? icon,
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    trailing,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton(
    BuildContext context,
    String label,
    String modalTitle,
  ) {
    return InkWell(
      onTap: () => _showSkeletonModal(context, modalTitle),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRSVPVisual(IconData icon, String label) {
    return Opacity(
      opacity: 0.5,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              BloomToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableSpotsRow extends ConsumerStatefulWidget {
  const _AvailableSpotsRow();

  @override
  ConsumerState<_AvailableSpotsRow> createState() => _AvailableSpotsRowState();
}

class _AvailableSpotsRowState extends ConsumerState<_AvailableSpotsRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final state = ref.read(createEventProvider);
    _controller = TextEditingController(
      text: state.availableSpots?.toString() ?? '',
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    final spots = int.tryParse(text);
    ref.read(createEventProvider.notifier).updateSpots(spots);
    ref.read(createEventProvider.notifier).setEditingSpots(false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventProvider);
    final isEditing = state.isEditingSpots;
    final availableSpots = state.availableSpots;

    // Trigger focus if entering editing state
    if (isEditing && !_focusNode.hasFocus) {
      Future.microtask(() => _focusNode.requestFocus());
    }

    // "Visibility" style matching _buildTappableRow title
    const visibilityStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    final mutedStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.60),
      fontSize: 12,
      fontWeight: FontWeight.normal,
    );

    // State 2: Input/Editing State
    if (isEditing) {
      return _buildCard(
        isEditing: true,
        child: Row(
          children: [
            const Icon(Icons.groups_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('# ', style: visibilityStyle),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                style: visibilityStyle,
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            Text('Waitlist', style: mutedStyle),
            const SizedBox(width: 8),
            BloomToggle(
              value: state.isWaitlistEnabled,
              onChanged: (val) => ref
                  .read(createEventProvider.notifier)
                  .setWaitlistEnabled(val),
            ),
          ],
        ),
      );
    }

    // State 3: Confirmed/Saved State
    if (availableSpots != null) {
      return _buildCard(
        isEditing: false,
        onTap: () {
          ref.read(createEventProvider.notifier).setEditingSpots(true);
        },
        child: Row(
          children: [
            const Icon(Icons.groups_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('$availableSpots spots', style: visibilityStyle),
            const Spacer(),
            Text('Waitlist', style: mutedStyle),
            const SizedBox(width: 8),
            BloomToggle(
              value: state.isWaitlistEnabled,
              onChanged: (val) => ref
                  .read(createEventProvider.notifier)
                  .setWaitlistEnabled(val),
            ),
          ],
        ),
      );
    }

    // State 1: Empty/Unlimited State
    return _buildCard(
      isEditing: false,
      onTap: () {
        ref.read(createEventProvider.notifier).setEditingSpots(true);
      },
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text('Unlimited', style: visibilityStyle),
          const Spacer(),
          Text('Available spots', style: mutedStyle),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withValues(alpha: 0.4),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    VoidCallback? onTap,
    required bool isEditing,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isEditing ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraBackground extends ConsumerWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auroraColors = ref.watch(
      createEventProvider.select((state) => state.auroraColors),
    );

    return Stack(
      children: [
        // Base + Blurred Blobs (Cached via RepaintBoundary for extreme performance)
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                // Layer 1: Solid Base (Darkened for contrast)
                Container(color: const Color(0xFF0B0E12)),
                // Layer 2: Top Left Blob
                Positioned(
                  top: -200,
                  left: -200,
                  child: Container(
                    width: 1000,
                    height: 1000,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          auroraColors[0].withValues(alpha: 0.6),
                          auroraColors[0].withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Layer 3: Top Right Blob
                Positioned(
                  top: -200,
                  right: -200,
                  child: Container(
                    width: 1000,
                    height: 1000,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          auroraColors[1].withValues(alpha: 0.6),
                          auroraColors[1].withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Layer 4: Bottom Left Blob
                Positioned(
                  bottom: -200,
                  left: -200,
                  child: Container(
                    width: 1000,
                    height: 1000,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          auroraColors[2].withValues(alpha: 0.6),
                          auroraColors[2].withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Layer 5: Bottom Right Blob
                Positioned(
                  bottom: -200,
                  right: -200,
                  child: Container(
                    width: 1000,
                    height: 1000,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          auroraColors[3].withValues(alpha: 0.6),
                          auroraColors[3].withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // The Premium Blur Filter
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Midnight Tint ("Sunglasses" for the bright mesh)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.15)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
