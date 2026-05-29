import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/chat_navigation.dart';
import '../../domain/chat/chat_providers.dart';
import '../shared/widgets/bloom_icon_button.dart';
import '../shared/widgets/gradient_top_bar.dart';
import 'widgets/conversation_tile.dart';

class MessagesListScreen extends ConsumerWidget {
  const MessagesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsListProvider);

    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Messages',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: BloomIconButton(
                    iconPath: 'assets/icons/misc/add_chat_fill.svg',
                    onTap: () async {
                      await context.push('/messages/add');
                      ref.read(conversationsListProvider.notifier).reload();
                    },
                  ),
                ),
              ],
            ),
            body: conversationsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF0086D8)),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.toString(),
                    style: const TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (conversations) {
                if (conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/nav/inbox_line.svg',
                            width: 48,
                            height: 48,
                            colorFilter: const ColorFilter.mode(
                              Colors.white24,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Messages',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start a conversation with a friend',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(conversationsListProvider.notifier).reload(),
                  color: const Color(0xFF0086D8),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final uid = conversationPeerUid(conversation);
                      final name = conversationPeerName(conversation);

                      return ConversationTile(
                        conversation: conversation,
                        onTap: () {
                          if (uid.isEmpty) return;
                          openChat(context, uid: uid, username: name);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}