import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/image_loader_helper.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../shared/widgets/container_placeholder.dart';

class AddChatFriendTile extends ConsumerWidget {
  const AddChatFriendTile({
    super.key,
    required this.friendUid,
    required this.onTap,
  });

  final String friendUid;
  final void Function(String displayName) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider(friendUid));

    final displayName = profileAsync.when(
      data: (profile) {
        final name = profile?['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
        final username = profile?['username']?.toString().trim();
        if (username != null && username.isNotEmpty) return username;
        return 'Bloom User';
      },
      loading: () => 'Bloom User',
      error: (_, _) => 'Bloom User',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(displayName),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              profileAsync.when(
                data: (profile) {
                  final avatarUrl =
                      profile?['profile_image_url']?.toString() ??
                      profile?['avatarUrl']?.toString() ??
                      profile?['avatar_url']?.toString();
                  return buildAvatarImage(source: avatarUrl, radius: 25);
                },
                loading: () => const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFF1A1D24),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white24,
                    ),
                  ),
                ),
                error: (_, _) => const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFF1A1D24),
                  child: Icon(Icons.person, color: Colors.white24, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    profileAsync.when(
                      data: (profile) {
                        final username = profile?['username']
                            ?.toString()
                            .trim();
                        return Text(
                          username != null && username.isNotEmpty
                              ? username.replaceAll('@', '')
                              : 'bloom member',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                      loading: () =>
                          const ContainerPlaceholder(width: 100, height: 12),
                      error: (_, _) => Text(
                        'bloom member',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
