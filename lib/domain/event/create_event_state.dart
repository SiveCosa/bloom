import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateEventState {
  final String title;
  final String? posterUrl;
  final double posterAspectRatio; // 1.0 (Square) or 0.75 (Portrait 3:4)
  static const List<Color> defaultAuroraColors = [
    Color(0xFFFFB965),
    Color(0xFFF04A9F),
    Color(0xFFC151FD),
    Color(0xFFAD83FE),
    Color(0xFF261D82),
  ];

  final List<Color>? _auroraColors;
  List<Color> get auroraColors =>
      (_auroraColors == null || _auroraColors.isEmpty)
          ? defaultAuroraColors
          : _auroraColors;
  
  final DateTime startDate;
  final bool startTimeTbd;
  final DateTime? endDate;
  final bool endTimeTbd;
  final bool isLocationSet;
  final String? location;
  final String description;
  
  final List<String>? _tags;
  List<String> get tags => _tags ?? const [];
  
  final String visibility; // Public, Private, Followers
  final int? availableSpots; // null for unlimited
  final bool allowPlusOnes;
  final bool requireApproval;
  final bool allowMaybe;
  final DateTime? rsvpDeadline;

  CreateEventState({
    this.title = '',
    this.posterUrl,
    this.posterAspectRatio = 1.0,
    List<Color>? auroraColors,
    required this.startDate,
    this.startTimeTbd = true,
    this.endDate,
    this.endTimeTbd = true,
    this.isLocationSet = false,
    this.location,
    this.description = '',
    List<String>? tags,
    this.visibility = 'Public',
    this.availableSpots,
    this.allowPlusOnes = false,
    this.requireApproval = false,
    this.allowMaybe = true,
    this.rsvpDeadline,
  })  : _auroraColors = auroraColors,
        _tags = tags;

  CreateEventState copyWith({
    String? title,
    String? posterUrl,
    double? posterAspectRatio,
    List<Color>? auroraColors,
    DateTime? startDate,
    bool? startTimeTbd,
    DateTime? endDate,
    bool? endTimeTbd,
    bool? isLocationSet,
    String? location,
    String? description,
    List<String>? tags,
    String? visibility,
    int? availableSpots,
    bool? allowPlusOnes,
    bool? requireApproval,
    bool? allowMaybe,
    DateTime? rsvpDeadline,
  }) {
    return CreateEventState(
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      posterAspectRatio: posterAspectRatio ?? this.posterAspectRatio,
      auroraColors: auroraColors ?? this.auroraColors,
      startDate: startDate ?? this.startDate,
      startTimeTbd: startTimeTbd ?? this.startTimeTbd,
      endDate: endDate ?? this.endDate,
      endTimeTbd: endTimeTbd ?? this.endTimeTbd,
      isLocationSet: isLocationSet ?? this.isLocationSet,
      location: location ?? this.location,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      visibility: visibility ?? this.visibility,
      availableSpots: availableSpots ?? this.availableSpots,
      allowPlusOnes: allowPlusOnes ?? this.allowPlusOnes,
      requireApproval: requireApproval ?? this.requireApproval,
      allowMaybe: allowMaybe ?? this.allowMaybe,
      rsvpDeadline: rsvpDeadline ?? this.rsvpDeadline,
    );
  }
}

class CreateEventNotifier extends Notifier<CreateEventState> {
  @override
  CreateEventState build() {
    final now = DateTime.now();
    return CreateEventState(
      startDate: DateTime(now.year, now.month, now.day, 0, 0),
    );
  }

  void reset() {
    state = build();
  }

  void updateTitle(String title) => state = state.copyWith(title: title);
  
  void updatePoster(String url, Color color) {
    updatePosterWithColors(url, [color, color, color, color, color]);
  }

  void updatePosterWithColors(String url, List<Color> colors) {
    // Artificial boosting for aurora effect
    final boostedColors = colors.map((c) => _boostColor(c)).toList();
    
    // If the image extracts fewer than 5 colors, pad the rest using the premium default palette
    int defaultIndex = 0;
    while (boostedColors.length < 5) {
      boostedColors.add(CreateEventState.defaultAuroraColors[defaultIndex % 5]);
      defaultIndex++;
    }

    state = state.copyWith(
      posterUrl: url, 
      auroraColors: boostedColors.take(5).toList(),
    );
  }

  Color _boostColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Enforce minimum saturation (0.6) and lightness (0.4) for vibrancy
    return hsl
        .withSaturation((hsl.saturation).clamp(0.6, 1.0))
        .withLightness((hsl.lightness).clamp(0.4, 0.8))
        .toColor();
  }

  void toggleAspectRatio() {
    state = state.copyWith(
      posterAspectRatio: state.posterAspectRatio == 1.0 ? 0.75 : 1.0,
    );
  }

  void updateDominantColor(Color color) {
    updatePosterWithColors(state.posterUrl ?? '', [color, color, color, color, color]);
  }

  void updateStartDate(DateTime date) {
    state = state.copyWith(startDate: date);
  }

  void setStartTimeTbd(bool tbd) {
    state = state.copyWith(startTimeTbd: tbd);
  }

  void updateEndDate(DateTime? date) {
    state = state.copyWith(endDate: date);
  }

  void setEndTimeTbd(bool tbd) {
    state = state.copyWith(endTimeTbd: tbd);
  }

  void clearDates() {
    final now = DateTime.now();
    state = state.copyWith(
      startDate: DateTime(now.year, now.month, now.day, 0, 0),
      startTimeTbd: true,
      endDate: null,
      endTimeTbd: true,
    );
  }

  void updateDescription(String val) => state = state.copyWith(description: val);

  void updateTags(List<String> tags) => state = state.copyWith(tags: tags);

  void updateVisibility(String val) => state = state.copyWith(visibility: val);

  void updateSpots(int? spots) => state = state.copyWith(availableSpots: spots);

  void setAllowPlusOnes(bool val) => state = state.copyWith(allowPlusOnes: val);

  void setRequireApproval(bool val) => state = state.copyWith(requireApproval: val);

  void setAllowMaybe(bool val) => state = state.copyWith(allowMaybe: val);

  void updateRSVPDeadline(DateTime? date) => state = state.copyWith(rsvpDeadline: date);

  void updateLocation(String? loc) {
    state = state.copyWith(
      location: loc,
      isLocationSet: loc != null && loc.isNotEmpty,
    );
  }
}

final createEventProvider = NotifierProvider<CreateEventNotifier, CreateEventState>(() {
  return CreateEventNotifier();
});
