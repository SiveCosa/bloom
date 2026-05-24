import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void openChat(
  BuildContext context, {
  required String uid,
  required String username,
}) {
  final encodedName = Uri.encodeComponent(username);
  context.push('/messages/chat/$uid?name=$encodedName');
}
