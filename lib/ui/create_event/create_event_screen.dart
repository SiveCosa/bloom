import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../domain/event/event_extra.dart';
import 'widgets/extra_field_modal.dart';
import 'widgets/location_selection_modal.dart';
import 'widgets/rsvp_deadline_modal.dart';
import 'widgets/rsvp_option_preview.dart';
import 'widgets/aurora_background.dart';
import 'widgets/host_invite_section.dart';
import '../../domain/event/event_location.dart';


class CreateEventScreen extends ConsumerWidget {
  const CreateEventScreen({super.key});

  void _showPosterSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AudienceModal(title: title),
    );
  }

  void _showPlusOnesSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlusOnesSelectionModal(),
    );
  }

  void _showTagSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TagSelectionModal(),
    );
  }

  void _showRSVPDeadlineSelection(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RSVPDeadlineModal(),
    );
  }

  void _showExtraFieldModal(
    BuildContext context,
    WidgetRef ref,
    ExtraType type, {
    EventExtra? existingExtra,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExtraFieldModal(
        initialType: type,
        initialExtra: existingExtra,
        onSave: (extra) {
          if (existingExtra != null) {
            ref.read(createEventProvider.notifier).updateExtra(extra);
          } else {
            ref.read(createEventProvider.notifier).addExtra(extra);
          }
        },
        onDelete: existingExtra != null
            ? () {
                ref
                    .read(createEventProvider.notifier)
                    .removeExtra(existingExtra.id);
              }
            : null,
      ),
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
              const Positioned.fill(child: AuroraBackground()),

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
                            onTap: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final result =
                                  await showModalBottomSheet<EventLocation>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        LocationSelectionModal(
                                      initialLocation: state.location,
                                    ),
                                  );
                              if (result != null) {
                                ref
                                    .read(createEventProvider.notifier)
                                    .updateLocation(result);
                              }
                            },
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
                                  if (!state.isLocationSet) ...[
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
                                      'Set the location',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ] else ...[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            state.location?.displayName ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            state.location?.formattedAddress ??
                                                '',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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

                          HostInviteSection(
                            showInviteFriends: false,
                            userProfile: userProfile,
                            onAddCoHost: () => _showSkeletonModal(context, 'Add Cohost'),
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
                                  icon: state.audience.visibility.outlinedIcon,
                                  title: state.audience.visibility.title,
                                  trailing: 'Set Visibility',
                                  onTap: () =>
                                      _showVisibilitySelection(context),
                                ),
                                const _AvailableSpotsRow(),
                                _buildTappableRow(
                                  context: context,
                                  icon: Icons.person_add_outlined,
                                  title: state.audience.maxPlusOnes > 0
                                      ? '+${state.audience.maxPlusOnes} allowed'
                                      : 'No plus ones',
                                  trailing: 'Plus ones',
                                  onTap: () => _showPlusOnesSelection(context),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Extras Section
                          EventSectionCard(
                            headerIcon: Icons.auto_awesome,
                            title: 'Extras',
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildPillButton(
                                      context,
                                      ref,
                                      'Link',
                                      ExtraType.link,
                                    ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.playlist,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Playlist',
                                        ExtraType.playlist,
                                      ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.dressCode,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Dress code',
                                        ExtraType.dressCode,
                                      ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.food,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Food',
                                        ExtraType.food,
                                      ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.drinks,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Drinks',
                                        ExtraType.drinks,
                                      ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.parking,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Parking',
                                        ExtraType.parking,
                                      ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.accommodation,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Accommodation',
                                        ExtraType.accommodation,
                                      ),
                                    if (!state.extras.any(
                                      (e) => e.type == ExtraType.giftRegistry,
                                    ))
                                      _buildPillButton(
                                        context,
                                        ref,
                                        'Gift Registry',
                                        ExtraType.giftRegistry,
                                      ),
                                  ],
                                ),
                                if (state.extras.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  const SizedBox(height: 16),
                                  ...state.extras.map(
                                    (extra) => _buildExtraItem(
                                      context,
                                      ref,
                                      extra,
                                      state.auroraColors,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          EventSectionCard(
                            headerIcon: Icons.edit_note_outlined,
                            title: 'Event Details',
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const SizedBox(height: 16),
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

                          // RSVP Options Section
                          EventSectionCard(
                            headerIcon: Icons.tune,
                            title: 'RSVP Options',
                            body: Column(
                              children: [
                                // RSVP Preview Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: state.audience.requireApproval
                                        ? Row(
                                            key: const ValueKey('approval'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_circle_outline,
                                                color: Colors.white.withValues(
                                                  alpha: 0.54,
                                                ),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Get on the list',
                                                style: TextStyle(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.54,
                                                  ),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            key: const ValueKey('standard'),
                                            children: [
                                              const RsvpOptionPreview(
                                                icon: Icons.check_circle_outline,
                                                label: 'Going',
                                              ),
                                              _buildVerticalDivider(),
                                              if (state.audience.allowMaybe) ...[
                                                const RsvpOptionPreview(
                                                  icon: Icons.help_outline,
                                                  label: 'Maybe',
                                                ),
                                                _buildVerticalDivider(),
                                              ],
                                              const RsvpOptionPreview(
                                                icon: Icons.cancel_outlined,
                                                label: 'Not Going',
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildToggleRow(
                                  'Require guest approval',
                                  state.audience.requireApproval,
                                  (val) {
                                    ref
                                        .read(createEventProvider.notifier)
                                        .setRequireApproval(val);
                                  },
                                ),
                                if (!state.audience.requireApproval)
                                  _buildToggleRow(
                                    "Guest can RSVP 'Maybe'",
                                    state.audience.allowMaybe,
                                    (val) {
                                      ref
                                          .read(createEventProvider.notifier)
                                          .setAllowMaybe(val);
                                    },
                                  ),
                                _buildTappableRow(
                                  context: context,
                                  icon: Icons.access_time,
                                  title: 'RSVP Deadline',
                                  trailing: state.audience.rsvpDeadline != null
                                      ? DateFormat('d MMM yyyy').format(state.audience.rsvpDeadline!)
                                      : 'Optional',
                                  onTap: () => _showRSVPDeadlineSelection(context),
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
    WidgetRef ref,
    String label,
    ExtraType type,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            onTap: () => _showExtraFieldModal(context, ref, type),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type.icon, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.1),
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
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  BloomToggle(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraItem(
    BuildContext context,
    WidgetRef ref,
    EventExtra extra,
    List<Color> auroraColors,
  ) {
    final bool isLink = extra.url != null && extra.url!.isNotEmpty;
    final Color textColor = isLink
        ? _getBestExtraColor(auroraColors)
        : Colors.white;

    return _ExtraItemTile(
      extra: extra,
      textColor: textColor,
      onEdit: () =>
          _showExtraFieldModal(context, ref, extra.type, existingExtra: extra),
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
      text: state.audience.capacity?.toString() ?? '',
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
    final availableSpots = state.audience.capacity;

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
              value: state.audience.waitlistEnabled,
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
              value: state.audience.waitlistEnabled,
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


class _ExtraItemTile extends StatefulWidget {
  final EventExtra extra;
  final Color textColor;
  final VoidCallback onEdit;

  const _ExtraItemTile({
    required this.extra,
    required this.textColor,
    required this.onEdit,
  });

  @override
  State<_ExtraItemTile> createState() => _ExtraItemTileState();
}

class _ExtraItemTileState extends State<_ExtraItemTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isLink =
        widget.extra.url != null && widget.extra.url!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              widget.extra.type.icon,
              color: Colors.white.withValues(alpha: 0.6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.extra.displayText,
                    maxLines: _isExpanded ? null : 1,
                    overflow: _isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 14,
                      fontWeight: isLink ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (isLink && _isExpanded) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final url = widget.extra.url!.trim();
                        final uri = Uri.parse(
                          url.startsWith('http') ? url : 'https://$url',
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
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.textColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.textColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: widget.textColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Open Link',
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onEdit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'edit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
