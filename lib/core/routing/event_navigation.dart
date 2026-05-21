import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens event detail only when [eventId] is a non-empty Firestore document id.
void pushEventDetail(BuildContext context, String eventId) {
  final id = eventId.trim();
  if (id.isEmpty) return;
  context.push('/event/$id');
}