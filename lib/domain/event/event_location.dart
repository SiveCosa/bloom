import 'package:dart_geohash/dart_geohash.dart';

class EventLocation {
  final double latitude;
  final double longitude;
  final String geohash;
  final String formattedAddress;
  final String displayName;
  final String? apartmentInfo;

  const EventLocation({
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.formattedAddress,
    required this.displayName,
    this.apartmentInfo,
  });

  EventLocation copyWith({
    double? latitude,
    double? longitude,
    String? geohash,
    String? formattedAddress,
    String? displayName,
    String? apartmentInfo,
  }) {
    return EventLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      displayName: displayName ?? this.displayName,
      apartmentInfo: apartmentInfo ?? this.apartmentInfo,
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedGeohash = geohash.isNotEmpty
        ? geohash
        : (latitude != 0 || longitude != 0
              ? _encodeGeohash(longitude, latitude)
              : '');

    return {
      'latitude': latitude,
      'longitude': longitude,
      'geohash': resolvedGeohash,
      'formattedAddress': formattedAddress,
      'displayName': displayName,
      if (apartmentInfo != null) 'apartmentInfo': apartmentInfo,
    };
  }

  static String _encodeGeohash(double longitude, double latitude) {
    return GeoHasher().encode(longitude, latitude);
  }

  factory EventLocation.fromMap(Map<String, dynamic> map) {
    final lat = map['latitude'] ?? map['lat'];
    final lng = map['longitude'] ?? map['lng'];
    if (lat is! num || lng is! num) {
      throw const FormatException(
        'EventLocation requires numeric latitude/longitude',
      );
    }
    return EventLocation(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      geohash: map['geohash'] as String? ?? '',
      formattedAddress:
          map['formattedAddress'] as String? ??
          map['formatted_address'] as String? ??
          '',
      displayName:
          map['displayName'] as String? ?? map['display_name'] as String? ?? '',
      apartmentInfo:
          map['apartmentInfo'] as String? ?? map['apartment_info'] as String?,
    );
  }
}
