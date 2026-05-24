import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                  return const Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: Colors.white54),
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