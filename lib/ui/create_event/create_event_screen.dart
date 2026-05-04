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
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Coming soon...',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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
              // Vibrant Aurora Background (Refined for premium contrast)              // The Full Background Stack
              Positioned.fill(
                child: Stack(
                  children: [
                    // Base + Blurred Blobs (Cached via RepaintBoundary for extreme performance)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: Stack(
                          children: [
                            // Layer 1: Solid Base (Darkened for contrast)
                            Container(
                              color: const Color(0xFF0B0E12),
                            ),
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
                                      state.auroraColors[0].withValues(alpha: 0.6),
                                      state.auroraColors[0].withValues(alpha: 0.0),
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
                                      state.auroraColors[1].withValues(alpha: 0.6),
                                      state.auroraColors[1].withValues(alpha: 0.0),
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
                                      state.auroraColors[2].withValues(alpha: 0.6),
                                      state.auroraColors[2].withValues(alpha: 0.0),
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
                                      state.auroraColors[3].withValues(alpha: 0.6),
                                      state.auroraColors[3].withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // The Premium Blur Filter
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 110.0, sigmaY: 110.0),
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                            // Midnight Tint ("Sunglasses" for the bright mesh)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                                          color: Colors.white.withValues(alpha: 0.15),
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
                                  icon: Icons.public,
                                  title: 'Visibility',
                                  trailing: state.visibility,
                                  onTap: () =>
                                      _showSkeletonModal(context, 'Visibility'),
                                ),
                                _buildTappableRow(
                                  context: context,
                                  icon: Icons.groups,
                                  title: 'Available Spots',
                                  trailing:
                                      state.availableSpots?.toString() ??
                                      'Unlimited',
                                  onTap: () => _showSkeletonModal(
                                    context,
                                    'Available Spots',
                                  ),
                                ),
                                _buildTappableRow(
                                  context: context,
                                  title: 'Plus Ones',
                                  trailing: state.allowPlusOnes
                                      ? 'Allowed'
                                      : 'No plus ones',
                                  onTap: () =>
                                      _showSkeletonModal(context, 'Plus Ones'),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Event Details Section
                          EventSectionCard(
                            headerIcon: Icons.edit,
                            title: 'Event Details',
                            body: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${state.tags.length}/5',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.60,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      onTap: () =>
                                          _showSkeletonModal(context, 'Tags'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add,
                                              color: Colors.white.withValues(
                                                alpha: 0.70,
                                              ),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'add tag',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.70,
                                                ),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: state.description,
                                  onChanged: (val) => ref
                                      .read(createEventProvider.notifier)
                                      .updateDescription(val),
                                  minLines: 4,
                                  maxLines: 5,
                                  maxLength: 2000,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add event description...',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.60,
                                      ),
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(16),
                                    counterText: '',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    '${state.description.length} / 2 000',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.60,
                                      ),
                                      fontSize: 12,
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
                    Icon(
                      icon,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
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
