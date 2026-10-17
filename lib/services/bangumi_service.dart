import 'package:dio/dio.dart';
import '../models/anime.dart';

class BangumiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://bgmapi.anibt.net',
    headers: {'User-Agent': 'AnimeApp/1.0 (https://github.com/yourname/anime_app)'},
  ));

  Future<List<List<Anime>>> getCalendar() async {
    final response = await _dio.get('/calendar');
    final data = response.data as List;
    return data.map((day) {
      final items = (day['items'] as List? ?? []);
      return items.map((e) => Anime.fromBangumi(Map<String, dynamic>.from(e))).toList();
    }).toList();
  }

  Future<double?> getRating(String subjectId) async {
    try {
      final response = await _dio.get('/v0/subjects/$subjectId');
      final rating = response.data['rating'];
      return (rating?['score'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }
}
