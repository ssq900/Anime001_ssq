import 'package:dio/dio.dart';
import '../models/anime.dart';

class AniListService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://graphql.anilist.co',
    connectTimeout: const Duration(seconds: 15),
  ));

  Future<List<List<Anime>>> getCalendar() async {
    // 计算当前时间戳和 7 天后的时间戳
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nextWeek = now + 7 * 24 * 3600;

    const query = r'''
      query ($start: Int, $end: Int) {
        Page(page: 1, perPage: 100) {
          airingSchedules(airingAt_greater: $start, airingAt_lesser: $end, sort: TIME) {
            airingAt
            episode
            media {
              id
              title { native romaji }
              coverImage { large }
              averageScore
            }
          }
        }
      }
    ''';

    try {
      final response = await _dio.post('', data: {
        'query': query,
        'variables': {'start': now, 'end': nextWeek},
      });

      final list = response.data['data']['Page']['airingSchedules'] as List;
      final Map<int, List<Anime>> grouped = {};

      for (var item in list) {
        final media = item['media'];
        final airingAt = item['airingAt'] as int;
        // 转换为 DateTime 并获取星期几 (1=周一, 7=周日)
        final date = DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);
        final weekday = date.weekday;

        final anime = Anime(
          id: media['id'].toString(),
          name: media['title']['native'] ?? media['title']['romaji'] ?? '未知',
          cover: media['coverImage']?['large'],
          rating: (media['averageScore'] as num?)?.toDouble() != null 
              ? (media['averageScore'] as num).toDouble() / 10 
              : null, // AniList 是百分制，除以 10 适配你现有的 10 分制显示
        );

        grouped.putIfAbsent(weekday, () => []).add(anime);
      }

      // 按周一到周日排序返回
      final result = <List<Anime>>[];
      for (int i = 1; i <= 7; i++) {
        result.add(grouped[i] ?? []);
      }
      return result;
    } catch (e) {
      throw Exception('AniList 请求失败: $e');
    }
  }
}
