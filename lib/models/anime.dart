class Anime {
  final String id;
  final String name;
  final String? cover;
  final String? summary;
  final double? rating;

  Anime({required this.id, required this.name, this.cover, this.summary, this.rating});

  factory Anime.fromBangumi(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    final ratingMap = json['rating'] as Map<String, dynamic>?;
    return Anime(
      id: json['id']?.toString() ?? '',
      name: json['name_cn']?.isNotEmpty == true ? json['name_cn'] : (json['name'] ?? ''),
      cover: images?['large'] ?? images?['common'],
      summary: json['summary'],
      rating: (ratingMap?['score'] as num?)?.toDouble(),
    );
  }
}

class Episode {
  final String name;
  final String url;
  Episode({required this.name, required this.url});
}
