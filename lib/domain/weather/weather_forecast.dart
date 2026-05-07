import 'package:flutter/foundation.dart';

@immutable
class WeatherForecast {
  final int averageTemp;
  final int highTemp;
  final int lowTemp;
  final String conditionText;
  final String conditionCode;
  final bool isDistantFuture;

  const WeatherForecast({
    required this.averageTemp,
    required this.highTemp,
    required this.lowTemp,
    required this.conditionText,
    required this.conditionCode,
    this.isDistantFuture = false,
  });

  factory WeatherForecast.fromMap(Map<String, dynamic> map) {
    if (map['is_distant_future'] == true) {
      return const WeatherForecast(
        averageTemp: 0,
        highTemp: 0,
        lowTemp: 0,
        conditionText: '',
        conditionCode: '',
        isDistantFuture: true,
      );
    }

    return WeatherForecast(
      averageTemp: map['averageTemp'] as int,
      highTemp: map['highTemp'] as int,
      lowTemp: map['lowTemp'] as int,
      conditionText: map['conditionText'] as String,
      conditionCode: map['conditionCode'] as String,
      isDistantFuture: false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherForecast &&
          runtimeType == other.runtimeType &&
          averageTemp == other.averageTemp &&
          highTemp == other.highTemp &&
          lowTemp == other.lowTemp &&
          conditionText == other.conditionText &&
          conditionCode == other.conditionCode &&
          isDistantFuture == other.isDistantFuture;

  @override
  int get hashCode =>
      averageTemp.hashCode ^
      highTemp.hashCode ^
      lowTemp.hashCode ^
      conditionText.hashCode ^
      conditionCode.hashCode ^
      isDistantFuture.hashCode;
}
