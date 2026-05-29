import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/event/create_event_state.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../../core/media/image_loader_helper.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/bloom_modal_shell.dart';
import '../../shared/widgets/bloom_selection_tile.dart';

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

    return BloomModalShell(
      title: 'Add Co-Hosts',
      height: MediaQuery.of(context).size.height * 0.75,
      leftActionText: 'Clear',
      onLeftActionPressed: _handleClear,
      rightActionText: 'Save',
      onRightActionPressed: _handleSave,
      child: Column(
        children: [
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

                    return BloomSelectionTile(
                      leading: Container(
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
                      title: nickname.isNotEmpty ? nickname : username.replaceAll('@', ''),
                      subtitle: nickname.isNotEmpty ? username.replaceAll('@', '') : '',
                      isSelected: isSelected,
                      useSolidCheck: true,
                      verticalPadding: 10,
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
