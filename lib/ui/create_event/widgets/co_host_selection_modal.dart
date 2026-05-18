import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../shared/widgets/custom_text_fields.dart';

class CoHostSelectionModal extends ConsumerStatefulWidget {
  const CoHostSelectionModal({super.key});

  @override
  ConsumerState<CoHostSelectionModal> createState() => _CoHostSelectionModalState();
}

class _CoHostSelectionModalState extends ConsumerState<CoHostSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  late List<Map<String, dynamic>> _selectedCoHosts;

  @override
  void initState() {
    super.initState();
    _selectedCoHosts = List<Map<String, dynamic>>.from(ref.read(createEventProvider).coHosts);
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSave() {
    ref.read(createEventProvider.notifier).updateCoHosts(_selectedCoHosts);
    Navigator.pop(context);
  }

  void _handleClear() {
    setState(() {
      _selectedCoHosts.clear();
    });
    ref.read(createEventProvider.notifier).updateCoHosts(_selectedCoHosts);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsMadeProvider);

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF191B1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header with Save and Clear
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _handleClear,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Text(
                  'Add Co-Hosts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _handleSave,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF6C8EEF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Search Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: RoundedTextField(
              controller: _searchController,
              hintText: 'Search friends by name or username...',
              onChanged: (val) {
                setState(() {
                  _searchText = val.trim().toLowerCase();
                });
              },
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // User search list
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error loading friends',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              data: (friendsList) {
                if (friendsList.isEmpty) {
                  return Center(
                    child: Text(
                      'No friends found to add as co-hosts',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }

                // Resolve all friend profiles reactively
                final List<Map<String, dynamic>> resolvedFriends = [];
                for (final friend in friendsList) {
                  final uid = friend['uid'] as String;
                  final profileAsync = ref.watch(userProfileStreamProvider(uid));
                  final profile = profileAsync.value;
                  if (profile != null) {
                    resolvedFriends.add({
                      'uid': uid,
                      ...profile,
                    });
                  }
                }

                // Filter by search text
                final filteredFriends = resolvedFriends.where((profile) {
                  final username = (profile['username'] as String? ?? '').toLowerCase();
                  final nickname = (profile['nickname'] as String? ?? '').toLowerCase();
                  return username.contains(_searchText) || nickname.contains(_searchText);
                }).toList();

                final bool isAllLoaded = resolvedFriends.length == friendsList.length;

                if (filteredFriends.isEmpty) {
                  return Center(
                    child: isAllLoaded
                        ? Text(
                            'No matching friends',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  );
                }

                // Sort: Selected co-hosts at the top, then alphabetically
                filteredFriends.sort((a, b) {
                  final aSelected = _selectedCoHosts.any(
                    (host) => (host['uid'] ?? host['id']) == a['uid'],
                  );
                  final bSelected = _selectedCoHosts.any(
                    (host) => (host['uid'] ?? host['id']) == b['uid'],
                  );

                  if (aSelected && !bSelected) return -1;
                  if (!aSelected && bSelected) return 1;

                  final aName = (a['nickname'] as String? ?? a['username'] as String? ?? '').toLowerCase();
                  final bName = (b['nickname'] as String? ?? b['username'] as String? ?? '').toLowerCase();
                  return aName.compareTo(bName);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredFriends.length,
                  itemBuilder: (context, index) {
                    final user = filteredFriends[index];
                    final uid = user['uid'] as String;
                    final username = user['username'] as String? ?? 'username';
                    final nickname = user['nickname'] as String? ?? '';
                    final profileImageUrl = user['profile_image_url'] as String?;

                    final isSelected = _selectedCoHosts.any(
                      (host) => (host['uid'] ?? host['id']) == uid,
                    );

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCoHosts.removeWhere(
                              (host) => (host['uid'] ?? host['id']) == uid,
                            );
                          } else {
                            _selectedCoHosts.add(user);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: buildAvatarImage(
                                source: profileImageUrl,
                                radius: 25,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nickname.isNotEmpty ? nickname : username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (nickname.isNotEmpty)
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                color: isSelected ? Colors.white : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.black,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

