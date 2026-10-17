import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  late Box _watchBox;
  late Box _historyBox;
  late Box _ruleBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _watchBox = await Hive.openBox('watchlist');
    _historyBox = await Hive.openBox('history');
    _ruleBox = await Hive.openBox('rules');
  }

  bool isWatching(String id) => _watchBox.containsKey(id);
  Future<void> toggleWatch(String id, String name) async {
    if (_watchBox.containsKey(id)) {
      await _watchBox.delete(id);
    } else {
      await _watchBox.put(id, name);
    }
  }
  List<MapEntry> get watchList => _watchBox.toMap().entries.toList();

  Future<void> saveHistory(String id, String name, String episode, Duration position) async {
    await _historyBox.put(id, {
      'name': name,
      'episode': episode,
      'position': position.inMilliseconds,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
  Map? getHistory(String id) => _historyBox.get(id) as Map?;
  List<MapEntry> get historyList =>
      (_historyBox.toMap().entries.toList()..sort((a, b) {
        final aTime = (a.value as Map)['updatedAt'] ?? '';
        final bTime = (b.value as Map)['updatedAt'] ?? '';
        return bTime.compareTo(aTime);
      }));

  Future<void> saveRule(String key, Map<String, dynamic> rule) async {
    await _ruleBox.put(key, rule);
  }
  List<Map<String, dynamic>> get rules =>
      _ruleBox.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<void> deleteRule(String key) async => await _ruleBox.delete(key);
}
