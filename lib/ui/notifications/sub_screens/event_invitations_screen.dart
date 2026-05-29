import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/gradient_top_bar.dart';
import '../../../domain/notification/notification_providers.dart';
import '../../../domain/notification/notification_model.dart';
import '../widgets/notification_tiles.dart';

class EventInvitationsScreen extends ConsumerStatefulWidget {
  const EventInvitationsScreen({super.key});

  @override
  ConsumerState<EventInvitationsScreen> createState() => _EventInvitationsScreenState();
}

class _EventInvitationsScreenState extends ConsumerState<EventInvitationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationControllerProvider)?.markAsReadByType([
        NotificationType.eventInvite,
        NotificationType.coHostInvite,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

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
                'Event Invitations',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: notificationsAsync.when(
              data: (notifications) {
                final invites = notifications.where((n) => 
                  n.type == NotificationType.eventInvite || 
                  n.type == NotificationType.coHostInvite
                ).toList();

                if (invites.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline_rounded,
                          color: Colors.white24,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No pending event invitations',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: invites.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final invite = invites[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent, // Let the tile handle its UI
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: NotificationTile(notification: invite),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB087F5)),
                ),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error loading invitations',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
