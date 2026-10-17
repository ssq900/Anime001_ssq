import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../services/bangumi_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenWatchlist;
  const HomeScreen({super.key, required this.onThemeChanged, required this.onOpenSearch, required this.onOpenWatchlist});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = BangumiService();
  List<List<Anime>>? _calendar;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.getCalendar();
      setState(() { _calendar = data; _loading = false; });
    } catch (e) {
      setState(() { _error = '加载排期失败：$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('看番'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: widget.onOpenSearch),
          IconButton(icon: const Icon(Icons.bookmark), onPressed: widget.onOpenWatchlist),
          PopupMenuButton<ThemeMode>(
            icon: const Icon(Icons.brightness_6),
            onSelected: widget.onThemeChanged,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              PopupMenuItem(value: ThemeMode.light, child: Text('浅色')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('夜间')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('重试')),
        ],
      ));
    }
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return ListView.builder(
      itemCount: _calendar!.length,
      itemBuilder: (_, i) {
        final list = _calendar![i];
        return ExpansionTile(
          title: Text(days.length > i ? days[i] : '第 ${i + 1} 天'),
          children: list.map((a) => ListTile(
            leading: a.cover != null
                ? SizedBox(width: 40, height: 56, child: Image.network(a.cover!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)))
                : const Icon(Icons.image),
            title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: a.rating != null ? Text('Bangumi ${a.rating!.toStringAsFixed(1)}') : null,
          )).toList(),
        );
      },
    );
  }
}
