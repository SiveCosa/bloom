class EventLocation {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String displayName;
  final String? apartmentInfo;

  const EventLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.displayName,
    this.apartmentInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress,
      'displayName': displayName,
      if (apartmentInfo != null) 'apartmentInfo': apartmentInfo,
    };
  }

  factory EventLocation.fromMap(Map<String, dynamic> map) {
    return EventLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      formattedAddress: map['formattedAddress'] as String,
      displayName: map['displayName'] as String,
      apartmentInfo: map['apartmentInfo'] as String?,
    );
  }
}
