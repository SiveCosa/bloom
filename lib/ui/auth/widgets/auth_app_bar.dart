import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/auth/auth_providers.dart';

enum AuthAppBarAction { back, cancel, skip }

class AuthAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final AuthAppBarAction? leftAction;
  final AuthAppBarAction? rightAction;
  final VoidCallback? onBack;
  final VoidCallback? onCancel;
  final VoidCallback? onSkip;

  const AuthAppBar({
    super.key,
    this.leftAction,
    this.rightAction,
    this.onBack,
    this.onCancel,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: leftAction != null
          ? _buildAction(context, ref, leftAction!)
          : null,
      leadingWidth: 80,
      actions: rightAction != null
          ? [_buildAction(context, ref, rightAction!)]
          : [],
    );
  }

  Widget _buildAction(
    BuildContext context,
    WidgetRef ref,
    AuthAppBarAction action,
  ) {
    late final String text;
    late final VoidCallback onTap;

    switch (action) {
      case AuthAppBarAction.back:
        text = 'Back';
        onTap = onBack ?? () => context.pop();
        break;
      case AuthAppBarAction.cancel:
        text = 'Cancel';
        onTap =
            onCancel ??
            () async {
              await ref
                  .read(authControllerProvider.notifier)
                  .rollbackRegistration();
              if (context.mounted) {
                context.go('/auth/signup');
              }
            };
        break;
      case AuthAppBarAction.skip:
        text = 'Skip';
        onTap = onSkip ?? () {};
        break;
    }

    return TextButton(
      onPressed: onTap,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
