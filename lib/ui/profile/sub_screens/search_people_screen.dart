import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/media/image_loader_helper.dart';
import '../../../data/connection_repository.dart';
import '../../../domain/auth/auth_providers.dart';
import '../../../domain/friendship/friendship_models.dart';
import '../../../domain/friendship/friendship_providers.dart';
import '../../shared/widgets/custom_text_fields.dart';
import '../../shared/widgets/gradient_top_bar.dart';

class SearchPeopleScreen extends ConsumerStatefulWidget {
  const SearchPeopleScreen({super.key});

  @override
  ConsumerState<SearchPeopleScreen> createState() => _SearchPeopleScreenState();
}

class _SearchPeopleScreenState extends ConsumerState<SearchPeopleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<String> _recentSearches = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _fetchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _recentSearches = prefs.getStringList('recent_searches_people') ?? [];
      });
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Avoid duplicates by removing existing value (ignoring case)
    _recentSearches.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    _recentSearches.insert(0, trimmed);

    // Limit search history list to 10 entries
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches_people', _recentSearches);
      setState(() {});
    } catch (e) {
      debugPrint('Error saving search query: $e');
    }
  }

  Future<void> _deleteSearchQuery(String query) async {
    _recentSearches.remove(query);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('recent_searches_people', _recentSearches);
      setState(() {});
    } catch (e) {
      debugPrint('Error deleting search query: $e');
    }
  }

  Future<void> _clearAllRecentSearches() async {
    _recentSearches.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches_people');
      setState(() {});
    } catch (e) {
      debugPrint('Error clearing all recent searches: $e');
    }
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUsers = true;
    });
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final currentUid = ref.read(firebaseAuthProvider).currentUser?.uid;
      final users = snap.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .where((user) => user['uid'] != currentUid)
          .toList();

      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users for search: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0E12),
      child: Stack(
        children: [
          // Background Gradient (100dp high, matches Messages screen)
          const GradientTopBar(
            height: 100,
            showDarkOverlay: false,
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Search people',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Search Bar Input (styled matching the guest list)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: RoundedTextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hintText: 'Search by name or username...',
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                              },
                              child: const Icon(Icons.clear, color: Colors.white54, size: 20),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _searchQuery.trim().isEmpty
                        ? _buildRecentSearchesList()
                        : _buildSearchResultsList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesList() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 56,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for people on Bloom',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent searches',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _clearAllRecentSearches,
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _searchController.text = query;
                          _searchController.selection = TextSelection.fromPosition(
                            TextPosition(offset: query.length),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          query,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _deleteSearchQuery(query),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    if (_isLoadingUsers) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0086D8),
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final filteredUsers = _allUsers.where((u) {
      final name = (u['name'] as String? ?? '').toLowerCase();
      final username = (u['username'] as String? ?? '').toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();

    if (filteredUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 56,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              Text(
                'No one found matching "$_searchQuery"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final user = filteredUsers[index];
        final uid = user['uid'] ?? user['id'] ?? '';
        return SearchUserRow(
          key: ValueKey<String>(uid),
          user: user,
          onTap: () {
            _saveSearchQuery(_searchQuery);
            context.push('/profile/$uid');
          },
          onAddFriendPressed: () {
            _saveSearchQuery(_searchQuery);
          },
        );
      },
    );
  }
}

class SearchUserRow extends ConsumerWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback onAddFriendPressed;

  const SearchUserRow({
    super.key,
    required this.user,
    required this.onTap,
    required this.onAddFriendPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = user['uid'] ?? user['id'] ?? '';
    final name = user['name'] as String? ?? 'Bloom User';
    final username = user['username'] as String? ?? '';
    final imageUrl = user['profile_image_url']?.toString() ?? user['avatar_url']?.toString();

    // Dynamically watch connection status
    final connectionStateAsync = ref.watch(connectionStateProvider(uid));
    final currentState = connectionStateAsync.value ?? FriendshipState.none;

    final isActionPending = currentState == FriendshipState.sentPending || currentState == FriendshipState.connected;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            buildAvatarImage(source: imageUrl, radius: 24),
            const SizedBox(width: 14),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    username.isNotEmpty ? '@$username' : 'bloom member',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: () async {
                  onAddFriendPressed();
                  final repo = ref.read(connectionRepositoryProvider);
                  if (uid.isEmpty) return;

                  switch (currentState) {
                    case FriendshipState.none:
                      try {
                        await repo.sendRequest(uid);
                      } catch (e) {
                        debugPrint('Error sending request: $e');
                      }
                      break;
                    case FriendshipState.sentPending:
                      try {
                        await repo.removeConnection(uid);
                      } catch (e) {
                        debugPrint('Error cancelling request: $e');
                      }
                      break;
                    case FriendshipState.receivedPending:
                      try {
                        await repo.acceptRequest(uid);
                        invalidateFriendshipCaches(ref, uid);
                      } catch (e) {
                        debugPrint('Error accepting request: $e');
                      }
                      break;
                    case FriendshipState.connected:
                      try {
                        await repo.removeConnection(uid);
                      } catch (e) {
                        debugPrint('Error unfriending user: $e');
                      }
                      break;
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActionPending ? const Color(0xFF25282D) : const Color(0xFF0086D8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: StadiumBorder(
                    side: isActionPending
                        ? BorderSide(color: Colors.white.withValues(alpha: 0.15))
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentState == FriendshipState.connected) ...[
                      const Icon(Icons.check, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      currentState == FriendshipState.sentPending
                          ? 'Requested'
                          : currentState == FriendshipState.receivedPending
                              ? 'Accept'
                              : currentState == FriendshipState.connected
                                  ? 'Friends'
                                  : 'Add friend',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
