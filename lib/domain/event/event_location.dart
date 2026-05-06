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
    return {
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'formattedAddress': formattedAddress,
      'displayName': displayName,
      if (apartmentInfo != null) 'apartmentInfo': apartmentInfo,
    };
  }

  factory EventLocation.fromMap(Map<String, dynamic> map) {
    return EventLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      geohash: map['geohash'] as String? ?? '',
      formattedAddress: map['formattedAddress'] as String,
      displayName: map['displayName'] as String,
      apartmentInfo: map['apartmentInfo'] as String?,
    );
  }
}
