import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/rule_engine.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  runApp(AnimeApp(storage: storage));
}

class AnimeApp extends StatefulWidget {
  final StorageService storage;
  const AnimeApp({super.key, required this.storage});

  @override
  State<AnimeApp> createState() => _AnimeAppState();
}

class _AnimeAppState extends State<AnimeApp> {
  ThemeMode _themeMode = ThemeMode.system;

  List<UnifiedRule> get _rules {
    return widget.storage.rules.map((json) {
      final type = json['type']?.toString();
      if (type == 'animeko') return UnifiedRule.fromAnimeko(json);
      return UnifiedRule.fromKazumi(json);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '看番',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomeScreen(
        onThemeChanged: (mode) => setState(() => _themeMode = mode),
        onOpenSearch: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SearchScreen(rules: _rules)),
          );
        },
        onOpenWatchlist: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WatchlistScreen(storage: widget.storage)),
          );
        },
      ),
    );
  }
}

class WatchlistScreen extends StatefulWidget {
  final StorageService storage;
  const WatchlistScreen({super.key, required this.storage});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  @override
  Widget build(BuildContext context) {
    final watch = widget.storage.watchList;
    final history = widget.storage.historyList;
    return Scaffold(
      appBar: AppBar(title: const Text('追番 & 历史')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('追番列表', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...watch.map((e) => ListTile(
                title: Text(e.value.toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () async {
                    await widget.storage.toggleWatch(e.key, e.value.toString());
                    setState(() {});
                  },
                ),
              )),
          if (watch.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('还没有追番')),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('观看历史', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...history.map((e) {
            final v = e.value as Map;
            return ListTile(
              title: Text(v['name']?.toString() ?? ''),
              subtitle: Text('${v['episode'] ?? ''}  ·  ${v['updatedAt'] ?? ''}'),
            );
          }),
          if (history.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('暂无历史')),
        ],
      ),
    );
  }
}
