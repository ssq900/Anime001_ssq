import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:json_path/json_path.dart';

class UnifiedRule {
  final String name;
  final String baseUrl;
  final String type;
  final String? searchUrl;
  final String? searchList;
  final String? searchName;
  final String? searchLink;
  final String? episodeList;
  final String? episodeName;
  final String? episodeLink;
  final Map<String, dynamic>? selectorConfig;
  final String? searchMode;

  UnifiedRule({
    required this.name,
    required this.baseUrl,
    required this.type,
    this.searchUrl,
    this.searchList,
    this.searchName,
    this.searchLink,
    this.episodeList,
    this.episodeName,
    this.episodeLink,
    this.selectorConfig,
    this.searchMode,
  });

  factory UnifiedRule.fromKazumi(Map<String, dynamic> json) {
    return UnifiedRule(
      name: json['name'] ?? '未知规则',
      baseUrl: json['baseUrl'] ?? '',
      type: 'kazumi',
      searchUrl: json['searchURL'] ?? json['searchUrl'],
      searchList: json['searchList'],
      searchName: json['searchName'],
      searchLink: json['searchLink'],
      episodeList: json['chapterList'] ?? json['episodeList'],
      episodeName: json['chapterName'] ?? json['episodeName'],
      episodeLink: json['chapterLink'] ?? json['episodeLink'],
      searchMode: json['searchMode'] ?? 'xpath',
    );
  }

  factory UnifiedRule.fromAnimeko(Map<String, dynamic> json) {
    return UnifiedRule(
      name: json['name'] ?? 'Animeko 规则',
      baseUrl: json['baseUrl'] ?? '',
      type: 'animeko',
      searchUrl: json['searchUrl'],
      selectorConfig: json['selector'] is Map
          ? Map<String, dynamic>.from(json['selector'])
          : Map<String, dynamic>.from(json),
      searchMode: 'selector',
    );
  }
}

class SearchResult {
  final String name;
  final String link;
  SearchResult({required this.name, required this.link});
}

class EpisodeResult {
  final String name;
  final String url;
  EpisodeResult({required this.name, required this.url});
}

class RuleEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36'},
  ));

  Future<List<SearchResult>> search(UnifiedRule rule, String keyword) async {
    if (rule.type == 'kazumi') return _searchKazumi(rule, keyword);
    return _searchAnimeko(rule, keyword);
  }

  Future<List<EpisodeResult>> getEpisodes(UnifiedRule rule, String detailUrl) async {
    if (rule.type == 'kazumi') return _episodesKazumi(rule, detailUrl);
    return _episodesAnimeko(rule, detailUrl);
  }

  Future<List<SearchResult>> _searchKazumi(UnifiedRule rule, String keyword) async {
    final url = (rule.searchUrl ?? '').replaceAll('@keyword', Uri.encodeComponent(keyword));
    if (url.isEmpty) return [];
    final response = await _dio.get(_absolute(rule.baseUrl, url));
    final data = response.data;
    if (rule.searchMode == 'api' && data is Map) {
      return _jsonPathList(Map<String, dynamic>.from(data), rule.searchList, rule.searchName, rule.searchLink);
    }
    if (data is String) {
      final doc = html_parser.parse(data);
      return _xpathList(doc, rule.searchList, rule.searchName, rule.searchLink);
    }
    return [];
  }

  Future<List<EpisodeResult>> _episodesKazumi(UnifiedRule rule, String detailUrl) async {
    final response = await _dio.get(detailUrl);
    final data = response.data;
    if (data is Map) {
      return _jsonPathEpisodes(Map<String, dynamic>.from(data), rule.episodeList, rule.episodeName, rule.episodeLink);
    }
    if (data is String) {
      final doc = html_parser.parse(data);
      return _xpathEpisodes(doc, rule.episodeList, rule.episodeName, rule.episodeLink);
    }
    return [];
  }

  List<SearchResult> _xpathList(Document doc, String? listXPath, String? nameXPath, String? linkXPath) {
    if (listXPath == null) return [];
    final selector = _xpathToApproxCss(listXPath);
    final elements = doc.querySelectorAll(selector);
    final results = <SearchResult>[];
    for (final el in elements) {
      final name = _pickText(el, nameXPath);
      final href = _pickAttr(el, linkXPath, 'href');
      if (name.isNotEmpty && href.isNotEmpty) {
        results.add(SearchResult(name: name, link: _absolute('', href)));
      }
    }
    return results;
  }

  List<EpisodeResult> _xpathEpisodes(Document doc, String? listXPath, String? nameXPath, String? linkXPath) {
    return _xpathList(doc, listXPath, nameXPath, linkXPath)
        .map((e) => EpisodeResult(name: e.name, url: e.link))
        .toList();
  }

  List<SearchResult> _jsonPathList(Map<String, dynamic> data, String? listPath, String? namePath, String? linkPath) {
    if (listPath == null) return [];
    try {
      final matches = JsonPath(listPath).read(data).toList();
      final results = <SearchResult>[];
      for (final m in matches) {
        final item = m.value;
        if (item is Map) {
          final name = _jsonRead(item, namePath);
          final link = _jsonRead(item, linkPath);
          if (name != null && link != null) {
            results.add(SearchResult(name: name.toString(), link: link.toString()));
          }
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  List<EpisodeResult> _jsonPathEpisodes(Map<String, dynamic> data, String? listPath, String? namePath, String? linkPath) {
    return _jsonPathList(data, listPath, namePath, linkPath)
        .map((e) => EpisodeResult(name: e.name, url: e.link))
        .toList();
  }

  Future<List<SearchResult>> _searchAnimeko(UnifiedRule rule, String keyword) async {
    final config = rule.selectorConfig ?? {};
    final searchUrl = (config['searchUrl'] ?? rule.searchUrl ?? '')
        .replaceAll('@keyword', Uri.encodeComponent(keyword));
    if (searchUrl.isEmpty) return [];
    final response = await _dio.get(_absolute(rule.baseUrl, searchUrl));
    if (response.data is! String) return [];
    final doc = html_parser.parse(response.data);
    final subjectSelector = _deepGet(config, ['select', 'subject'])?.toString();
    if (subjectSelector == null) return [];
    return doc.querySelectorAll(subjectSelector).map((el) {
      final name = el.querySelector('a')?.text.trim() ?? el.text.trim();
      final href = el.querySelector('a')?.attributes['href'] ?? '';
      return SearchResult(name: name, link: _absolute(rule.baseUrl, href));
    }).where((e) => e.name.isNotEmpty && e.link.isNotEmpty).toList();
  }

  Future<List<EpisodeResult>> _episodesAnimeko(UnifiedRule rule, String detailUrl) async {
    final config = rule.selectorConfig ?? {};
    final response = await _dio.get(detailUrl);
    if (response.data is! String) return [];
    final doc = html_parser.parse(response.data);
    final episodeSelector = _deepGet(config, ['select', 'episode'])?.toString();
    if (episodeSelector == null) return [];
    return doc.querySelectorAll(episodeSelector).map((el) {
      final name = el.querySelector('a')?.text.trim() ?? el.text.trim();
      final href = el.querySelector('a')?.attributes['href'] ?? '';
      return EpisodeResult(name: name, url: _absolute(detailUrl, href));
    }).where((e) => e.name.isNotEmpty && e.url.isNotEmpty).toList();
  }

  String _absolute(String base, String url) {
    if (url.startsWith('http')) return url;
    if (base.isEmpty) return url;
    final uri = Uri.tryParse(base);
    if (uri == null) return url;
    return uri.resolve(url).toString();
  }

  String _pickText(Element el, String? path) {
    if (path == null || path.isEmpty) return el.text.trim();
    if (path.startsWith('@')) return el.attributes[path.substring(1)] ?? '';
    final child = el.querySelector(_xpathToApproxCss(path));
    return child?.text.trim() ?? el.text.trim();
  }

  String _pickAttr(Element el, String? path, String fallback) {
    if (path == null || path.isEmpty) return el.attributes[fallback] ?? '';
    if (path.startsWith('@')) return el.attributes[path.substring(1)] ?? '';
    final child = el.querySelector(_xpathToApproxCss(path));
    return child?.attributes[fallback] ?? el.attributes[fallback] ?? '';
  }

  String _xpathToApproxCss(String xpath) {
    var s = xpath.trim();
    if (s.startsWith('//')) s = s.substring(2);
    if (s.startsWith('/')) s = s.substring(1);
    s = s.replaceAll('//', ' ');
    s = s.replaceAll(RegExp(r'\[\d+\]'), '');
    s = s.replaceAll(RegExp(r'\[@[^\]]+\]'), '');
    return s.trim().isEmpty ? '*' : s.trim();
  }

  String? _jsonRead(Map map, String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      final matches = JsonPath(path).read(map).toList();
      return matches.isEmpty ? null : matches.first.value?.toString();
    } catch (_) {
      return null;
    }
  }

  dynamic _deepGet(Map map, List<String> keys) {
    dynamic current = map;
    for (final k in keys) {
      if (current is Map && current.containsKey(k)) {
        current = current[k];
      } else {
        return null;
      }
    }
    return current;
  }
}
