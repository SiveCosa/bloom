import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateEventState {
  final String title;
  final String? posterUrl;
  final Uint8List? customPosterBytes;
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
          : _auroraColors!;
  
  final DateTime? startDate;
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
  final bool isGeneratingPoster;

  CreateEventState({
    this.title = '',
    this.posterUrl,
    this.customPosterBytes,
    this.posterAspectRatio = 1.0,
    List<Color>? auroraColors,
    this.startDate,
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
    this.isGeneratingPoster = false,
  })  : _auroraColors = auroraColors,
        _tags = tags;

  CreateEventState copyWith({
    String? title,
    Object? posterUrl = _undefined,
    Object? customPosterBytes = _undefined,
    double? posterAspectRatio,
    Object? auroraColors = _undefined,
    Object? startDate = _undefined,
    bool? startTimeTbd,
    Object? endDate = _undefined,
    bool? endTimeTbd,
    bool? isLocationSet,
    Object? location = _undefined,
    String? description,
    Object? tags = _undefined,
    String? visibility,
    Object? availableSpots = _undefined,
    bool? allowPlusOnes,
    bool? requireApproval,
    bool? allowMaybe,
    Object? rsvpDeadline = _undefined,
    bool? isGeneratingPoster,
  }) {
    return CreateEventState(
      title: title ?? this.title,
      posterUrl: posterUrl == _undefined ? this.posterUrl : (posterUrl as String?),
      customPosterBytes: customPosterBytes == _undefined ? this.customPosterBytes : (customPosterBytes as Uint8List?),
      posterAspectRatio: posterAspectRatio ?? this.posterAspectRatio,
      auroraColors: auroraColors == _undefined ? this._auroraColors : (auroraColors as List<Color>?),
      startDate: startDate == _undefined ? this.startDate : (startDate as DateTime?),
      startTimeTbd: startTimeTbd ?? this.startTimeTbd,
      endDate: endDate == _undefined ? this.endDate : (endDate as DateTime?),
      endTimeTbd: endTimeTbd ?? this.endTimeTbd,
      isLocationSet: isLocationSet ?? this.isLocationSet,
      location: location == _undefined ? this.location : (location as String?),
      description: description ?? this.description,
      tags: tags == _undefined ? this._tags : (tags as List<String>?),
      visibility: visibility ?? this.visibility,
      availableSpots: availableSpots == _undefined ? this.availableSpots : (availableSpots as int?),
      allowPlusOnes: allowPlusOnes ?? this.allowPlusOnes,
      requireApproval: requireApproval ?? this.requireApproval,
      allowMaybe: allowMaybe ?? this.allowMaybe,
      rsvpDeadline: rsvpDeadline == _undefined ? this.rsvpDeadline : (rsvpDeadline as DateTime?),
      isGeneratingPoster: isGeneratingPoster ?? this.isGeneratingPoster,
    );
  }
}

const _undefined = Object();

class CreateEventNotifier extends Notifier<CreateEventState> {
  @override
  CreateEventState build() {
    return CreateEventState();
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
      customPosterBytes: null, // Clear custom bytes if choosing a premade poster
      auroraColors: boostedColors.take(5).toList(),
    );
  }

  void updateCustomPoster(Uint8List bytes, List<Color> colors) {
    final boostedColors = colors.map((c) => _boostColor(c)).toList();
    
    int defaultIndex = 0;
    while (boostedColors.length < 5) {
      boostedColors.add(CreateEventState.defaultAuroraColors[defaultIndex % 5]);
      defaultIndex++;
    }

    state = state.copyWith(
      posterUrl: null, // Clear URL if using custom bytes
      customPosterBytes: bytes,
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
    state = state.copyWith(
      startDate: null,
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

  void setGeneratingPoster(bool generating) {
    state = state.copyWith(isGeneratingPoster: generating);
  }
}

final createEventProvider = NotifierProvider<CreateEventNotifier, CreateEventState>(() {
  return CreateEventNotifier();
});
