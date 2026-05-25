import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/event/event_location.dart';
import '../../../domain/weather/weather_providers.dart';
import '../../../domain/weather/weather_forecast.dart';

class EventWeatherCard extends ConsumerStatefulWidget {
  final EventLocation? location;
  final DateTime? startDate;

  const EventWeatherCard({
    super.key,
    required this.location,
    required this.startDate,
  });

  @override
  ConsumerState<EventWeatherCard> createState() => _EventWeatherCardState();
}

class _EventWeatherCardState extends ConsumerState<EventWeatherCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.location == null || 
        widget.startDate == null || 
        widget.location?.latitude == null || 
        widget.location?.longitude == null) {
      return const SizedBox.shrink();
    }

    final weatherAsync = ref.watch(weatherForecastProvider(WeatherParams(
      latitude: widget.location!.latitude,
      longitude: widget.location!.longitude,
      startDate: widget.startDate!,
    )));

    return weatherAsync.when(
      data: (forecast) {
        if (forecast == null) return const SizedBox.shrink();
        return _buildCard(context, forecast);
      },
      loading: () => _buildShimmer(),
      error: (err, stack) {
        return _buildErrorState(err);
      },
    );
  }

  Widget _buildErrorState(dynamic err) {
    return GestureDetector(
      onTap: () => ref.invalidate(weatherForecastProvider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(15),
              width: double.infinity,
              color: Colors.black.withValues(alpha: 0.2),
              child: Column(
                children: [
                  const Text(
                    'Weather Failed to load',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to Reload',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, WeatherForecast forecast) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(15),
            color: Colors.black.withValues(alpha: 0.2),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (forecast.isDistantFuture)
                  _buildDistantFuture()
                else
                  _buildForecastBody(forecast),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Weather',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600, // semi-bold
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('d MMMM yyyy').format(widget.startDate!),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.w400, // regular
          ),
        ),
      ],
    );
  }

  Widget _buildForecastBody(WeatherForecast forecast) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Side: Icon & Temp
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _getWeatherIcon(forecast.conditionCode),
            const SizedBox(width: 16),
            Text(
              '${forecast.averageTemp}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w300, // Light weight for premium feel
                height: 1.0,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        // Right Side: Details
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getFriendlyCondition(forecast.conditionText),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'H: ${forecast.highTemp}°  L: ${forecast.lowTemp}°',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getFriendlyCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'Sunny';
      case 'clouds':
        return 'Cloudy';
      case 'rain':
        return 'Rainy';
      case 'drizzle':
        return 'Drizzling';
      case 'thunderstorm':
        return 'Stormy';
      case 'snow':
        return 'Snowy';
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
      case 'sand':
      case 'ash':
      case 'squall':
      case 'tornado':
        return 'Foggy';
      default:
        return condition;
    }
  }

  Widget _buildDistantFuture() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Detailed forecast available closer to the event date.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.54),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.03),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value.clamp(0.0, 1.0),
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getWeatherIcon(String code) {
    IconData iconData;
    Color iconColor;

    // Remove 'd' or 'n' from OWM icon code if present
    final baseCode = code.length >= 2 ? code.substring(0, 2) : '01';

    switch (baseCode) {
      case '01':
        iconData = Icons.wb_sunny_rounded;
        iconColor = const Color(0xFFFFB965);
        break;
      case '02':
        iconData = Icons.wb_cloudy_rounded;
        iconColor = Colors.white70;
        break;
      case '03':
      case '04':
        iconData = Icons.cloud_rounded;
        iconColor = Colors.white54;
        break;
      case '09':
      case '10':
        iconData = Icons.umbrella_rounded;
        iconColor = const Color(0xFFAD83FE);
        break;
      case '11':
        iconData = Icons.thunderstorm_rounded;
        iconColor = const Color(0xFFC151FD);
        break;
      case '13':
        iconData = Icons.ac_unit_rounded;
        iconColor = Colors.white;
        break;
      case '50':
        iconData = Icons.cloud_circle_rounded;
        iconColor = Colors.white38;
        break;
      default:
        iconData = Icons.wb_sunny_rounded;
        iconColor = const Color(0xFFFFB965);
    }

    return Icon(
      iconData,
      color: iconColor,
      size: 40,
    );
  }
}
