import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/bloom_button.dart';
import 'stacked_posters.dart';

class CreateEventCTA extends StatelessWidget {
  const CreateEventCTA({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Create an event',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 0),
        const StackedPosters(),
        const SizedBox(height: 5),
        BloomButton(
          text: 'Create event',
          width: null,
          height: 35,
          backgroundColor: Colors.white,
          textColor: Colors.black,
          borderRadius: 50,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          horizontalPadding: 13,
          prefixIcon: const Icon(Icons.add, color: Colors.black, size: 18),
          onPressed: () => context.push('/create-event'),
        ),
      ],
    );
  }
}
