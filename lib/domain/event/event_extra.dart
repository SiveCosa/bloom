import 'package:flutter/material.dart';

enum ExtraType {
  link,
  playlist,
  dressCode,
  food,
  drinks,
  parking,
  accommodation,
  giftRegistry,
}

extension ExtraTypeExtension on ExtraType {
  IconData get icon {
    switch (this) {
      case ExtraType.link:
        return Icons.link;
      case ExtraType.dressCode:
        return Icons.checkroom;
      case ExtraType.food:
        return Icons.restaurant;
      case ExtraType.parking:
        return Icons.directions_car;
      case ExtraType.accommodation:
        return Icons.hotel;
      case ExtraType.giftRegistry:
        return Icons.card_giftcard;
      case ExtraType.drinks:
        return Icons.local_bar;
      case ExtraType.playlist:
        return Icons.music_note;
    }
  }

  String get displayHint {
    switch (this) {
      case ExtraType.link:
        return "Link text";
      case ExtraType.dressCode:
        return "Casual, Black tie, etc.";
      case ExtraType.food:
        return "Bring & Braai, bring own snacks, etc.";
      case ExtraType.drinks:
        return "BYOB, Open Bar, etc.";
      case ExtraType.playlist:
        return "Spotify, Apple Music, etc.";
      case ExtraType.parking:
        return "Parking Instructions";
      case ExtraType.accommodation:
        return "Accommodation details";
      case ExtraType.giftRegistry:
        return "My Gift Registry";
    }
  }

  bool get isLinkRequired {
    return this == ExtraType.link;
  }
}

class EventExtra {
  final String id;
  final ExtraType type;
  final String displayText;
  final String? url;

  EventExtra({
    required this.id,
    required this.type,
    required this.displayText,
    this.url,
  });

  EventExtra copyWith({
    String? id,
    ExtraType? type,
    String? displayText,
    String? url,
  }) {
    return EventExtra(
      id: id ?? this.id,
      type: type ?? this.type,
      displayText: displayText ?? this.displayText,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'displayText': displayText,
      if (url != null) 'url': url,
    };
  }

  factory EventExtra.fromMap(Map<String, dynamic> map) {
    return EventExtra(
      id: map['id'] as String? ?? '',
      type: ExtraType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ExtraType.link,
      ),
      displayText: map['displayText'] as String? ?? map['display_text'] as String? ?? '',
      url: map['url'] as String?,
    );
  }
}
