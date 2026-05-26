import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bloom/data/event/event_repository.dart';

class GuestListRow extends ConsumerWidget {
  final Map<String, dynamic> guest;
  final String? eventId;
  final bool isHost;
  final bool isEventFull;

  const GuestListRow({
    super.key,
    required this.guest,
    this.eventId,
    this.isHost = false,
    this.isEventFull = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = guest['uid'] as String? ?? '';
    final name = guest['name'] as String? ?? guest['username'] as String? ?? 'Unknown';
    final avatarUrl = guest['profile_image_url'] as String? ?? '';
    final subtitle = guest['computedSubtitle'] as String? ?? '';

    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (uid.isNotEmpty) {
                  context.push('/profile/$uid');
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, error, stackTrace) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const SizedBox(width: 16),
          if (isHost && (guest['status'] == 'requested' || guest['rsvp_status'] == 'requested')) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (uid.isNotEmpty && eventId != null) {
                    ref.read(eventRepositoryProvider).updateRSVP(eventId!, uid, isEventFull ? 'waitlisted' : 'going');
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (uid.isNotEmpty && eventId != null) {
                    ref.read(eventRepositoryProvider).removeRSVP(eventId!, uid);
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ),
          ] else ...[
            IconButton(
              onPressed: () {
                if (uid.isNotEmpty) {
                  final rawName = Uri.encodeComponent(name);
                  context.push('/messages/chat/$uid?name=$rawName');
                }
              },
              icon: SvgPicture.asset(
                'assets/icons/misc/message_fill.svg',
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                width: 24,
                height: 24,
              ),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
