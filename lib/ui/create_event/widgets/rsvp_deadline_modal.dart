import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';

class RSVPDeadlineModal extends ConsumerWidget {
  const RSVPDeadlineModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createEventProvider);
    final notifier = ref.read(createEventProvider.notifier);

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'RSVP Deadline',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.event_available, color: Colors.white),
            title: const Text('Deadline Date', style: TextStyle(color: Colors.white)),
            trailing: Text(
              state.rsvpDeadline != null 
                  ? '${state.rsvpDeadline!.day}/${state.rsvpDeadline!.month}/${state.rsvpDeadline!.year}' 
                  : 'Select Date',
              style: const TextStyle(color: Colors.white70),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: state.rsvpDeadline ?? state.startDate.subtract(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: state.startDate,
              );
              if (date != null) notifier.updateRSVPDeadline(date);
            },
          ),
          const Divider(color: Colors.white12),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.redAccent),
            title: const Text('No Deadline', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              notifier.updateRSVPDeadline(null);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
