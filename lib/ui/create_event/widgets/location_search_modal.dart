import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';

class LocationSearchModal extends ConsumerStatefulWidget {
  const LocationSearchModal({super.key});

  @override
  ConsumerState<LocationSearchModal> createState() => _LocationSearchModalState();
}

class _LocationSearchModalState extends ConsumerState<LocationSearchModal> {
  final List<String> _suggestions = [
    'Central Park, NY', 'Silicon Valley, CA', 'The White House, DC', 'Golden Gate Bridge, SF', 'Times Square, NY'
  ];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(createEventProvider.notifier);

    final filtered = _suggestions
        .where((s) => s.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
            'Set Location',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (val) => setState(() => _query = val),
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search address or place...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                notifier.updateLocation(val);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final loc = filtered[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Colors.white54),
                  title: Text(loc, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    notifier.updateLocation(loc);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
