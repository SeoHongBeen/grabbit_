import 'package:flutter/material.dart';
import 'package:grabbit_project/service/weather_service.dart';

class WeatherHeader extends StatefulWidget {
  const WeatherHeader({super.key});

  @override
  State<WeatherHeader> createState() => _WeatherHeaderState();
}

class _WeatherHeaderState extends State<WeatherHeader> {
  double? temperature;
  String? weather;
  double? uv;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final data = await WeatherService.fetchWeather();
    setState(() {
      temperature = data['temp'];
      weather = data['weather'];
      uv = data['uv'];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (temperature == null || weather == null || uv == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🌡️ 온도: ${temperature!.toStringAsFixed(1)}°C',
              style: Theme.of(context).textTheme.titleMedium),
          Text('🌥️ 날씨: $weather',
              style: Theme.of(context).textTheme.titleMedium),
          Text('🔆 자외선 지수: ${uv!.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
