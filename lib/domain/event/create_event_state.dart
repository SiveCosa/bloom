import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../data/event/event_repository.dart';
import '../auth/auth_providers.dart';
import 'event.dart';
import 'event_visibility.dart';
import 'event_extra.dart';
import 'event_location.dart';

class CreateEventState {
  final String title;
  final String description;
  final List<String> tags;
  final EventVisuals visuals;
  final EventTiming timing;
  final EventLocation? location;
  final EventAudience audience;
  final List<EventExtra> extras;
  final List<String> rsvpReminders;

  // UI-only or transient state
  final Uint8List? customPosterBytes;
  final bool isGeneratingPoster;
  final bool isEditingSpots;
  final List<Color> auroraColors; // For UI rendering
  final String? defaultPosterUrl;
  final String? editingEventId;
  final List<Map<String, dynamic>> coHosts;

  static const String fallbackPosterUrl =
      'https://firebasestorage.googleapis.com/v0/b/bloom-e98c2.firebasestorage.app/o/posters%2Fdefault%2Fdefault_poster.webp?alt=media&token=56f3fc10-9054-4467-a1b9-a98240939a99';

  static const List<Color> defaultAuroraColors = [
    Color(0xFFFFB965),
    Color(0xFFF04A9F),
    Color(0xFFC151FD),
    Color(0xFFAD83FE),
    Color(0xFF261D82),
  ];

  CreateEventState({
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.visuals = const EventVisuals(aspectRatio: 1.0, auroraColors: []),
    this.timing = const EventTiming(),
    this.location,
    this.audience = const EventAudience(visibility: EventVisibility.public),
    this.extras = const [],
    this.rsvpReminders = const [],
    this.customPosterBytes,
    this.isGeneratingPoster = false,
    this.isEditingSpots = false,
    this.auroraColors = defaultAuroraColors,
    this.defaultPosterUrl = fallbackPosterUrl,
    this.editingEventId,
    this.coHosts = const [],
  });

  CreateEventState copyWith({
    String? title,
    String? description,
    List<String>? tags,
    EventVisuals? visuals,
    EventTiming? timing,
    Object? location = _undefined,
    EventAudience? audience,
    List<EventExtra>? extras,
    List<String>? rsvpReminders,
    Object? customPosterBytes = _undefined,
    bool? isGeneratingPoster,
    bool? isEditingSpots,
    List<Color>? auroraColors,
    Object? defaultPosterUrl = _undefined,
    Object? editingEventId = _undefined,
    List<Map<String, dynamic>>? coHosts,
  }) {
    return CreateEventState(
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      visuals: visuals ?? this.visuals,
      timing: timing ?? this.timing,
      location: location == _undefined
          ? this.location
          : (location as EventLocation?),
      audience: audience ?? this.audience,
      extras: extras ?? this.extras,
      rsvpReminders: rsvpReminders ?? this.rsvpReminders,
      customPosterBytes: customPosterBytes == _undefined
          ? this.customPosterBytes
          : (customPosterBytes as Uint8List?),
      isGeneratingPoster: isGeneratingPoster ?? this.isGeneratingPoster,
      isEditingSpots: isEditingSpots ?? this.isEditingSpots,
      auroraColors: auroraColors ?? this.auroraColors,
      defaultPosterUrl: defaultPosterUrl == _undefined
          ? this.defaultPosterUrl
          : (defaultPosterUrl as String?),
      editingEventId: editingEventId == _undefined
          ? this.editingEventId
          : (editingEventId as String?),
      coHosts: coHosts ?? this.coHosts,
    );
  }

  bool get isLocationSet => location != null;
}

const _undefined = Object();

class CreateEventNotifier extends Notifier<CreateEventState> {
  @override
  CreateEventState build() {
    _fetchDefaultPoster();
    return CreateEventState();
  }

  Future<void> _fetchDefaultPoster() async {
    String? url;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posters')
          .doc('default')
          .get();
      if (snap.exists) {
        url = snap.data()?['url'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching default poster: $e');
    }

    url ??= CreateEventState.fallbackPosterUrl;

    // Guard against race conditions when editing an event with a custom poster
    if (state.editingEventId != null) {
      state = state.copyWith(defaultPosterUrl: url);
      return;
    }

    state = state.copyWith(defaultPosterUrl: url);

    // Extract colors for the default poster to set the initial aurora background
    try {
      final imageProvider = NetworkImage(url);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
      ).timeout(const Duration(seconds: 5));

      final colors = <Color>[];
      if (paletteGenerator.vibrantColor != null) {
        colors.add(paletteGenerator.vibrantColor!.color);
      }
      if (paletteGenerator.lightVibrantColor != null) {
        colors.add(paletteGenerator.lightVibrantColor!.color);
      }
      if (paletteGenerator.darkVibrantColor != null) {
        colors.add(paletteGenerator.darkVibrantColor!.color);
      }
      if (paletteGenerator.mutedColor != null) {
        colors.add(paletteGenerator.mutedColor!.color);
      }
      if (paletteGenerator.dominantColor != null) {
        colors.add(paletteGenerator.dominantColor!.color);
      }

      // Recheck before applying color/poster updates in case an event was loaded for editing during palette generation
      if (state.editingEventId != null) {
        return;
      }

      if (colors.isNotEmpty) {
        updatePosterWithColors(url, colors);
      }
    } catch (e) {
      debugPrint('Error extracting colors for default poster: $e');
    }
  }

  void reset() {
    state = CreateEventState();
    _fetchDefaultPoster();
  }

  void updateTitle(String title) => state = state.copyWith(title: title);
  void updateDescription(String description) =>
      state = state.copyWith(description: description);

  void updatePosterWithColors(String url, List<Color> colors) {
    final boostedColors = colors.map((c) => _boostColor(c)).toList();
    while (boostedColors.length < 5) {
      boostedColors.add(
        CreateEventState.defaultAuroraColors[boostedColors.length],
      );
    }

    state = state.copyWith(
      visuals: state.visuals.copyWith(
        posterUrl: url,
        auroraColors: boostedColors
            .take(5)
            .map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
            .toList(),
      ),
      customPosterBytes: null,
      auroraColors: boostedColors.take(5).toList(),
    );
  }

  void updateCustomPoster(Uint8List bytes, List<Color> colors) {
    final boostedColors = colors.map((c) => _boostColor(c)).toList();
    while (boostedColors.length < 5) {
      boostedColors.add(
        CreateEventState.defaultAuroraColors[boostedColors.length],
      );
    }

    state = state.copyWith(
      visuals: state.visuals.copyWith(
        posterUrl: null,
        auroraColors: boostedColors
            .take(5)
            .map((c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}')
            .toList(),
      ),
      customPosterBytes: bytes,
      auroraColors: boostedColors.take(5).toList(),
    );
  }

  Color _boostColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation).clamp(0.6, 1.0))
        .withLightness((hsl.lightness).clamp(0.4, 0.8))
        .toColor();
  }

  void updateDominantColor(Color color) {
    updatePosterWithColors(state.visuals.posterUrl ?? '', [
      color,
      color,
      color,
      color,
      color,
    ]);
  }

  void toggleAspectRatio() {
    state = state.copyWith(
      visuals: state.visuals.copyWith(
        aspectRatio: state.visuals.aspectRatio == 1.0 ? 0.75 : 1.0,
      ),
    );
  }

  void updateStartDate(DateTime date) {
    state = state.copyWith(timing: state.timing.copyWith(startDate: date));
  }

  void setStartTimeTbd(bool tbd) {
    state = state.copyWith(timing: state.timing.copyWith(startTimeTbd: tbd));
  }

  void updateEndDate(DateTime? date) {
    state = state.copyWith(timing: state.timing.copyWith(endDate: date));
  }

  void setEndTimeTbd(bool tbd) {
    state = state.copyWith(timing: state.timing.copyWith(endTimeTbd: tbd));
  }

  void clearDates() {
    state = state.copyWith(timing: const EventTiming());
  }

  void toggleTag(String tag) {
    final currentTags = List<String>.from(state.tags);
    if (currentTags.contains(tag)) {
      currentTags.remove(tag);
    } else if (currentTags.length < 5) {
      currentTags.add(tag);
    }
    state = state.copyWith(tags: currentTags);
  }

  void updateTags(List<String> tags) {
    if (tags.length <= 5) {
      state = state.copyWith(tags: tags);
    }
  }

  void clearTags() => state = state.copyWith(tags: []);

  void updateVisibility(EventVisibility val) {
    state = state.copyWith(audience: state.audience.copyWith(visibility: val));
  }

  void updateSpots(int? spots) {
    state = state.copyWith(audience: state.audience.copyWith(capacity: spots));
  }

  void setEditingSpots(bool editing) =>
      state = state.copyWith(isEditingSpots: editing);

  void setWaitlistEnabled(bool enabled) {
    state = state.copyWith(
      audience: state.audience.copyWith(waitlistEnabled: enabled),
    );
  }

  void setMaxPlusOnes(int val) {
    // Clamped between 0 and 5 as per requirement
    final clampedVal = val.clamp(0, 5);
    state = state.copyWith(
      audience: state.audience.copyWith(maxPlusOnes: clampedVal),
    );
  }

  void setRequireApproval(bool val) {
    state = state.copyWith(
      audience: state.audience.copyWith(requireApproval: val),
    );
  }

  void setAllowMaybe(bool val) {
    state = state.copyWith(audience: state.audience.copyWith(allowMaybe: val));
  }

  void updateRSVPDeadline(DateTime? date) {
    state = state.copyWith(
      audience: state.audience.copyWith(rsvpDeadline: date),
    );
  }

  void updateLocation(EventLocation? loc) {
    state = state.copyWith(location: loc);
  }

  void setGeneratingPoster(bool generating) {
    state = state.copyWith(isGeneratingPoster: generating);
  }

  void addExtra(EventExtra extra) {
    state = state.copyWith(extras: [...state.extras, extra]);
  }

  void updateExtra(EventExtra extra) {
    state = state.copyWith(
      extras: state.extras.map((e) => e.id == extra.id ? extra : e).toList(),
    );
  }

  void removeExtra(String id) {
    state = state.copyWith(
      extras: state.extras.where((e) => e.id != id).toList(),
    );
  }

  void toggleRSVPReminder(String reminder) {
    final currentReminders = List<String>.from(state.rsvpReminders);
    if (currentReminders.contains(reminder)) {
      currentReminders.remove(reminder);
    } else {
      currentReminders.add(reminder);
    }
    state = state.copyWith(rsvpReminders: currentReminders);
  }

  void updateRSVPReminders(List<String> reminders) {
    state = state.copyWith(rsvpReminders: reminders);
  }

  void clearRSVPDeadline() {
    state = state.copyWith(
      audience: state.audience.copyWith(rsvpDeadline: null),
      rsvpReminders: [],
    );
  }

  void loadEventForEditing(Event event, Map<String, dynamic>? hostProfile, List<Map<String, dynamic>> resolvedCoHosts) {
    final parsedColors = event.visuals.auroraColors.map((c) => _parseHexColor(c)).toList();
    state = CreateEventState(
      title: event.title,
      description: event.description,
      tags: event.tags,
      visuals: event.visuals,
      timing: event.timing,
      location: event.location,
      audience: event.audience,
      extras: event.extras,
      rsvpReminders: event.rsvpReminders,
      auroraColors: parsedColors.isEmpty ? CreateEventState.defaultAuroraColors : parsedColors,
      defaultPosterUrl: event.visuals.posterUrl ?? CreateEventState.fallbackPosterUrl,
      editingEventId: event.id,
      coHosts: resolvedCoHosts,
    );
  }

  Color _parseHexColor(String hex) {
    var cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.parse(cleanHex, radix: 16));
  }

  void addCoHost(Map<String, dynamic> user) {
    final uid = user['uid'] as String? ?? user['id'] as String?;
    if (uid == null) return;
    if (state.coHosts.any((host) => (host['uid'] ?? host['id']) == uid)) return;
    state = state.copyWith(coHosts: [...state.coHosts, user]);
  }

  void removeCoHost(String uid) {
    state = state.copyWith(
      coHosts: state.coHosts.where((host) => (host['uid'] ?? host['id']) != uid).toList(),
    );
  }

  void updateCoHosts(List<Map<String, dynamic>> coHosts) {
    state = state.copyWith(coHosts: coHosts);
  }

  Future<void> compileAndPublishEvent() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    final hostId = user?.uid;
    
    if (hostId == null) {
      throw 'You must be signed in to post an event.';
    }
    
    final repo = ref.read(eventRepositoryProvider);

    try {
      final isEditing = state.editingEventId != null;
      final eventId = isEditing 
          ? state.editingEventId! 
          : FirebaseFirestore.instance.collection('events').doc().id;

      String? finalPosterUrl =
          state.visuals.posterUrl ?? state.defaultPosterUrl;

      // 2. Upload custom poster if present
      if (state.customPosterBytes != null) {
        finalPosterUrl = await repo.uploadPoster(
          eventId,
          state.customPosterBytes!,
        );
      }

      // 3. Compile final event data
      EventLiveCounts liveCounts = const EventLiveCounts();
      List<String> previewGuests = const [];
      DateTime createdAt = DateTime.now();
      EventStatus status = EventStatus.active;
      String actualHostId = hostId;

      if (isEditing) {
        // Fetch existing event to preserve operational parameters (Immutability Guard)
        final existingEvent = await repo.getEvent(eventId);
        if (existingEvent != null) {
          liveCounts = existingEvent.liveCounts;
          previewGuests = existingEvent.previewGuests;
          createdAt = existingEvent.metadata.createdAt;
          status = existingEvent.metadata.status;
          actualHostId = existingEvent.metadata.hostId;
        }
      }

      final coHostIdsList = state.coHosts
          .map((h) => (h['uid'] ?? h['id'] ?? '') as String)
          .where((id) => id.isNotEmpty)
          .toList();

      final event = Event(
        id: eventId,
        title: state.title.trim().isEmpty ? 'Untitled Event' : state.title.trim(),
        description: state.description,
        tags: state.tags,
        visuals: state.visuals.copyWith(posterUrl: finalPosterUrl),
        timing: state.timing,
        location: state.location,
        audience: state.audience,
        extras: state.extras,
        rsvpReminders: state.rsvpReminders,
        liveCounts: liveCounts,
        previewGuests: previewGuests,
        metadata: EventMetadata(
          hostId: actualHostId,
          createdAt: createdAt,
          updatedAt: DateTime.now(),
          status: status,
        ),
        coHostIds: coHostIdsList,
      );

      // 4. Save to repository
      if (isEditing) {
        await repo.updateEvent(event);
        debugPrint('Event updated successfully with ID: $eventId');
      } else {
        await repo.createEvent(event);
        debugPrint('Event published successfully with ID: $eventId');
      }
      reset(); // Reset state to default after successful creation
    } catch (e) {
      debugPrint('Error publishing event: $e');
      throw 'Failed to post event. Please try again.';
    }
  }
}

final createEventProvider =
    NotifierProvider<CreateEventNotifier, CreateEventState>(() {
      return CreateEventNotifier();
    });
