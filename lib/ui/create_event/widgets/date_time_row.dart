import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/event/create_event_state.dart';

class DateTimeRow extends ConsumerWidget {
  final VoidCallback onTap;

  const DateTimeRow({super.key, required this.onTap});

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, d MMM').format(date);
  }

  String _formatTime(DateTime date, bool isTbd) {
    if (isTbd) return 'TBD';
    final format = date.minute == 0 ? DateFormat('ha') : DateFormat('h:mma');
    return format.format(date).toLowerCase();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventProvider);
    final startDate = state.startDate;
    final endDate = state.endDate;

    bool isUnset = startDate == null;
    bool isSingleDay = startDate != null && (endDate == null || _isSameDay(startDate, endDate));
    bool isMultiDay = startDate != null && endDate != null && !_isSameDay(startDate, endDate);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContent(state, isUnset, isSingleDay, isMultiDay),
                ),
                if (isUnset) ...[
                  Text(
                    'Set a date',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    CreateEventState state,
    bool isUnset,
    bool isSingleDay,
    bool isMultiDay,
  ) {
    if (isUnset) {
      return const Text(
        'Date & Time',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (isSingleDay) {
      final startTimeStr = _formatTime(state.startDate!, state.startTimeTbd);
      final endTimeStr = state.endDate != null ? _formatTime(state.endDate!, state.endTimeTbd) : null;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDate(state.startDate!),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            endTimeStr != null ? '$startTimeStr - $endTimeStr' : startTimeStr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    // Multi-day
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${_formatDate(state.startDate!)} \u2022 ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: _formatTime(state.startDate!, state.startTimeTbd),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${_formatDate(state.endDate!)} \u2022 ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: _formatTime(state.endDate!, state.endTimeTbd),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
