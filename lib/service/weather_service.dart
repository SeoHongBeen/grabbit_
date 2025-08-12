import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  static const String _apiKey = 'f0aee34af3322865b0dab4d2981464bd'; // 여기에 OpenWeatherMap API 키 입력
  static const String _weatherUrl = 'https://api.openweathermap.org/data/2.5/weather';
  static const String _uviUrl = 'https://api.openweathermap.org/data/2.5/uvi';

  static Future<Map<String, dynamic>> fetchWeather() async {
    try {
      //위치
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return {'temp': 0.0, 'weather': 'Unknown', 'uv': 0.0};
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final lat = position.latitude;
      final lon = position.longitude;

      //날씨
      final weatherRes = await http.get(Uri.parse(
          '$_weatherUrl?lat=$lat&lon=$lon&units=metric&lang=kr&appid=$_apiKey'));
      final weatherData = jsonDecode(weatherRes.body);

      final temp = weatherData['main']['temp'] ?? 0.0;
      final weatherMain = weatherData['weather'][0]['main'] ?? 'Unknown';

      //자외선
      final uvRes = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/onecall?lat=$lat&lon=$lon&exclude=hourly,daily,minutely,alerts&appid=$_apiKey'));
      final uvData = jsonDecode(uvRes.body);
      final uvIndex = uvData['current']['uvi'] ?? 0.0;

      return {
        'temp': temp,
        'weather': weatherMain,
        'uv': uvIndex,
      };
    } catch (e) {
      return {'temp': 0.0, 'weather': 'Unknown', 'uv': 0.0};
    }
  }
}
