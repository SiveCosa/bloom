import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'weather_forecast.dart';

class WeatherParams {
  final double latitude;
  final double longitude;
  final DateTime startDate;

  WeatherParams({
    required this.latitude,
    required this.longitude,
    required this.startDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherParams &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          startDate == other.startDate;

  @override
  int get hashCode =>
      latitude.hashCode ^ longitude.hashCode ^ startDate.hashCode;
}

final weatherForecastProvider =
    FutureProvider.family<WeatherForecast?, WeatherParams>((ref, params) async {
  try {
    final functions = FirebaseFunctions.instanceFor(region: 'africa-south1');
    final callable = functions.httpsCallable('weatherProxy');
    
    final response = await callable.call({
      'lat': params.latitude,
      'lon': params.longitude,
      'timestamp': params.startDate.millisecondsSinceEpoch ~/ 1000,
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    return WeatherForecast.fromMap(data);
  } catch (e) {
    debugPrint('Error fetching weather forecast: $e');
    return null;
  }
});
