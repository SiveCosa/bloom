import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/domain/event/event_providers.dart';
import 'package:bloom/ui/create_event/widgets/aurora_background.dart';

class HostGuestlistScreen extends ConsumerStatefulWidget {
  final String eventId;
  final List<Color> palette;

  const HostGuestlistScreen({
    super.key,
    required this.eventId,
    required this.palette,
  });

  @override
  ConsumerState<HostGuestlistScreen> createState() => _HostGuestlistScreenState();
}

class _HostGuestlistScreenState extends ConsumerState<HostGuestlistScreen> {
  String _searchQuery = '';
  String _activeFilter = 'Going';
  bool _isAscending = true;

  @override
  Widget build(BuildContext context) {
    final guestsAsync = ref.watch(eventGuestsProvider(widget.eventId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background matches the invitation
          AuroraBackground(colors: widget.palette),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildControls(),
                Expanded(
                  child: guestsAsync.when(
                    data: (guests) => _buildGuestList(guests),
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error loading guests', 
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => context.pop(),
          ),
          const Text(
            'Guestlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 48), // Balancing space
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search guests...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _isAscending = !_isAscending),
                      child: Container(
                        height: 45,
                        width: 45,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _isAscending ? Icons.sort_by_alpha : Icons.sort_by_alpha_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['Going', 'Maybe', 'Not Going', 'Interested'].map((filter) {
                      final isActive = _activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeFilter = filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isActive ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestList(List<Map<String, dynamic>> guests) {
    final statusMap = {
      'Going': 'going',
      'Maybe': 'maybe',
      'Not Going': 'not_going',
      'Interested': 'interested',
    };

    final targetStatus = statusMap[_activeFilter] ?? 'going';

    final filtered = guests.where((g) {
      final status = g['status'] as String? ?? '';
      final name = g['name'] as String? ?? 'Guest';
      final matchesFilter = status == targetStatus;
      final matchesSearch = name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      final nameA = a['name'] as String? ?? '';
      final nameB = b['name'] as String? ?? '';
      return _isAscending ? nameA.compareTo(nameB) : nameB.compareTo(nameA);
    });

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.2), size: 64),
            const SizedBox(height: 16),
            Text(
              'No one here yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final guest = filtered[index];
        final String name = guest['name'] ?? 'Unknown Guest';
        final String? avatar = guest['profile_image_url'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: avatar != null
                      ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                      : null,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: avatar == null
                    ? const Icon(Icons.person, color: Colors.white, size: 24)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeFilter,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.2)),
            ],
          ),
        );
      },
    );
  }
}
