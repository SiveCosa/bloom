import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/event_navigation.dart';
import '../../core/routing/chat_navigation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/auth/auth_providers.dart';
import '../../domain/friendship/friendship_models.dart';
import '../../domain/friendship/friendship_providers.dart';
import '../../domain/event/event_providers.dart';
import '../../data/connection_repository.dart';
import '../../core/media/image_loader_helper.dart';
import '../shared/widgets/gradient_top_bar.dart';
import '../widgets/scheduled_event_card.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicProfileScreen> createState() =>
      _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  static const Color _scaffoldColor = Color(0xFF0B0E12);

  static const double _cutoffBelowUsername = 10;
  bool _isBioExpanded = false;

  /// Bottom edge of the username bar (safe area + toolbar).
  double _usernameBarBottom(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight;

  /// Content is fully clipped above this line (bar bottom + 10dp).
  double _contentCutoff(BuildContext context) =>
      _usernameBarBottom(context) + _cutoffBelowUsername;

  Widget _fadeScrollContent(BuildContext context, Widget child) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final cutoffPx = _contentCutoff(context);
        const fadeHeightPx = 6.0;
        final cutoff = (cutoffPx / bounds.height).clamp(0.0, 1.0);
        final fadeEnd = ((cutoffPx + fadeHeightPx) / bounds.height).clamp(
          cutoff,
          1.0,
        );
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.transparent, Colors.black],
          stops: [0.0, cutoff, fadeEnd],
        ).createShader(bounds);
      },
      child: child,
    );
  }

  Widget _buildTransparentAppBar(BuildContext context, String username) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  Widget build(BuildContext context) {
    final profileUserId = widget.userId;
    final profileAsync = ref.watch(userProfileStreamProvider(profileUserId));
    final connectionState =
        ref.watch(connectionStateProvider(profileUserId)).value ??
        FriendshipState.none;
    final upcomingEventsAsync = ref.watch(
      publicProfileUpcomingEventsProvider(profileUserId),
    );
    final friendsListAsync = ref.watch(userFriendsProvider(profileUserId));
    final contentCutoff = _contentCutoff(context);

    final appBarUsername = profileAsync.when(
      data: (doc) => (doc?['username']?.toString() ?? '—').replaceAll('@', ''),
      loading: () => '',
      error: (error, stackTrace) => '',
    );

    return Scaffold(
      backgroundColor: _scaffoldColor,
      body: Stack(
        children: [
          const GradientTopBar(height: 120, showDarkOverlay: false),
          _fadeScrollContent(
            context,
            profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF0086D8)),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              data: (doc) {
                if (doc == null) {
                  return const Center(
                    child: Text(
                      'User not found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final name = doc['name']?.toString() ?? 'Anonymous';
                final bio = doc['bio']?.toString() ?? 'No bio yet.';
                final imageUrl = doc['profile_image_url']?.toString();

                final counts = doc['counts'] as Map<String, dynamic>?;
                final friendsCount =
                    (friendsListAsync.value?.length ?? counts?['friends'] ?? 0)
                        .toString();
                final hostedCount = ref
                    .watch(publicProfileHostedCountProvider(profileUserId))
                    .toString();
                final joinedCount = ref
                    .watch(publicProfileJoinedCountProvider(profileUserId))
                    .toString();

                final socialLinks =
                    doc['social_links'] as Map<String, dynamic>?;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: contentCutoff)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            Center(
                              child: Column(
                                children: [
                                  buildAvatarImage(
                                    source: imageUrl,
                                    radius: 58,
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),

                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    'Friends made',
                                    friendsCount,
                                    () {
                                      context.push(
                                        '/profile/$profileUserId/friends',
                                        extra: name,
                                      );
                                    },
                                  ),
                                ),
                                _buildDivider(),
                                Expanded(
                                  child: _buildStatItem(
                                    'Hosted events',
                                    hostedCount,
                                    () {
                                      context.push(
                                        '/profile/$profileUserId/hosted',
                                        extra: name,
                                      );
                                    },
                                  ),
                                ),
                                _buildDivider(),
                                Expanded(
                                  child: _buildStatItem(
                                    'Joined events',
                                    joinedCount,
                                    () {
                                      context.push(
                                        '/profile/$profileUserId/joined',
                                        extra: name,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (socialLinks != null &&
                                socialLinks.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              _buildSocialLinksRow(socialLinks),
                              const SizedBox(height: 10),
                              _buildBioText(bio),
                            ] else ...[
                              const SizedBox(height: 20),
                              _buildBioText(bio),
                            ],

                            const SizedBox(height: 25),

                            _buildConnectionActionBar(
                              context,
                              ref,
                              connectionState,
                              displayName: name,
                            ),
                            const SizedBox(height: 30),

                            Text(
                              "$name's Schedule",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                    ),

                    upcomingEventsAsync.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF0086D8),
                            ),
                          ),
                        ),
                      ),
                      error: (e, _) => SliverToBoxAdapter(
                        child: Center(
                          child: Text(
                            'Error loading events: $e',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      data: (events) {
                        if (events.isEmpty) {
                          return const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                  'No upcoming joining events yet.',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                            ),
                          );
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final event = events[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: ScheduledEventCard(
                                  event: event,
                                  isHost:
                                      event.hostId == profileUserId ||
                                      event.coHostIds.contains(profileUserId),
                                  onTap: () =>
                                      pushEventDetail(context, event.id),
                                ),
                              );
                            }, childCount: events.length),
                          ),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  ],
                );
              },
            ),
          ),
          _buildTransparentAppBar(context, appBarUsername),
        ],
      ),
    );
  }

  Widget _buildSocialLinksRow(Map<String, dynamic> links) {
    final instagram = links['instagram']?.toString() ?? '';
    final x = links['x']?.toString() ?? '';
    final snapchat = links['snapchat']?.toString() ?? '';

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 12,
        runSpacing: 8,
        children: [
          if (instagram.isNotEmpty)
            _buildSocialLink('instagram', instagram, false),
          if (x.isNotEmpty) _buildSocialLink('x', x, instagram.isNotEmpty),
          if (snapchat.isNotEmpty)
            _buildSocialLink(
              'snapchat',
              snapchat,
              instagram.isNotEmpty || x.isNotEmpty,
            ),
        ],
      ),
    );
  }

  Widget _buildSocialLink(String platform, String handle, bool hasPrevious) {
    String assetName = platform;

    return GestureDetector(
      onTap: () {
        if (handle.isEmpty) return;
        String url;
        switch (assetName) {
          case 'instagram':
            url = 'https://www.instagram.com/$handle/';
            break;
          case 'x':
            url = 'https://x.com/$handle';
            break;
          case 'snapchat':
            url = 'https://www.snapchat.com/add/$handle';
            break;
          default:
            return;
        }
        _launchUrl(url);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assetName.isNotEmpty)
            SvgPicture.asset(
              'assets/icons/profile/${assetName}_icon.svg',
              width: 15,
              height: 15,
              colorFilter: const ColorFilter.mode(
                Colors.white70,
                BlendMode.srcIn,
              ),
            )
          else
            const Icon(Icons.link, size: 14, color: Colors.white10),
          const SizedBox(width: 4),
          Text(
            handle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildBioText(String bio) {
    if (bio.isEmpty) {
      return const SizedBox(
        width: double.infinity,
        child: Text(
          'No bio yet.',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Colors.white24,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isBioExpanded = !_isBioExpanded;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const style = TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            );
            const moreStyle = TextStyle(
              color: Colors.blue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            );

            final textPainter = TextPainter(
              text: TextSpan(text: bio, style: style),
              maxLines: 3,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            if (!textPainter.didExceedMaxLines) {
              return Text(bio, style: style);
            }

            if (_isBioExpanded) {
              return Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: bio, style: style),
                    const TextSpan(text: ' ...less', style: moreStyle),
                  ],
                ),
              );
            }

            int start = 0;
            int end = bio.length;
            int cutOff = end;

            while (start <= end) {
              int mid = (start + end) ~/ 2;
              final tp = TextPainter(
                text: TextSpan(
                  text: '${bio.substring(0, mid)} ...more',
                  style: style,
                ),
                maxLines: 3,
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: constraints.maxWidth);

              if (tp.didExceedMaxLines) {
                end = mid - 1;
              } else {
                cutOff = mid;
                start = mid + 1;
              }
            }

            return Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: bio.substring(0, cutOff), style: style),
                  const TextSpan(text: ' ...more', style: moreStyle),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: Colors.white12);
  }

  Widget _buildConnectionActionBar(
    BuildContext context,
    WidgetRef ref,
    FriendshipState state, {
    required String displayName,
  }) {
    final showDecline = state == FriendshipState.receivedPending;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: _buildBaseButton(
              label: showDecline ? 'Decline' : 'Message',
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              textColor: Colors.white,
              onTap: () {
                if (showDecline) {
                  ref
                      .read(connectionRepositoryProvider)
                      .removeConnection(widget.userId);
                  ref.invalidate(recommendedFriendsProvider);
                } else {
                  openChat(context, uid: widget.userId, username: displayName);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildReactiveConnectionButton(context, ref, state)),
        ],
      ),
    );
  }

  Widget _buildReactiveConnectionButton(
    BuildContext context,
    WidgetRef ref,
    FriendshipState state,
  ) {
    switch (state) {
      case FriendshipState.none:
        return _buildBaseButton(
          label: 'Add Friend',
          backgroundColor: const Color(0xFF0086D8),
          textColor: Colors.white,
          onTap: () =>
              ref.read(connectionRepositoryProvider).sendRequest(widget.userId),
        );
      case FriendshipState.sentPending:
        return _buildBaseButton(
          label: 'Requested',
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          textColor: Colors.white54,
          trailingIcon: Icons.close,
          onTap: () {
            ref
                .read(connectionRepositoryProvider)
                .removeConnection(widget.userId);
            ref.invalidate(recommendedFriendsProvider);
          },
        );
      case FriendshipState.receivedPending:
        return _buildBaseButton(
          label: 'Accept Request',
          backgroundColor: const Color(0xFF0086D8),
          textColor: Colors.white,
          onTap: () async {
            try {
              await ref
                  .read(connectionRepositoryProvider)
                  .acceptRequest(widget.userId);
              invalidateFriendshipCaches(ref, widget.userId);
            } catch (_) {}
          },
        );
      case FriendshipState.connected:
        return _buildBaseButton(
          label: 'Friends',
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          textColor: Colors.white,
          trailingIcon: Icons.keyboard_arrow_down,
          onTap: () => _showManageFriendModal(context, ref),
        );
    }
  }

  Widget _buildBaseButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
    IconData? trailingIcon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 4),
              Icon(trailingIcon, color: textColor, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  void _showManageFriendModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191B1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.redAccent),
              title: const Text(
                'Remove Friend',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(connectionRepositoryProvider)
                    .removeConnection(widget.userId);
                ref.invalidate(recommendedFriendsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
