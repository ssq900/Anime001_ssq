import 'package:flutter/material.dart';
import '../services/rule_engine.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<UnifiedRule> rules;
  const SearchScreen({super.key, required this.rules});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _engine = RuleEngine();
  final _controller = TextEditingController();
  UnifiedRule? _selectedRule;
  List<SearchResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.rules.isNotEmpty) _selectedRule = widget.rules.first;
  }

  Future<void> _search() async {
    final rule = _selectedRule;
    if (rule == null || _controller.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; });
    try {
      final results = await _engine.search(rule, _controller.text.trim());
      setState(() { _results = results; _loading = false; });
    } catch (e) {
      setState(() { _error = '搜索失败：$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: Column(
        children: [
          if (widget.rules.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('还没有导入规则。请先在“规则管理”中导入 Kazumi 或 Animeko 规则。'),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<UnifiedRule>(
                value: _selectedRule,
                decoration: const InputDecoration(labelText: '选择动漫源规则', border: OutlineInputBorder()),
                items: widget.rules.map((r) => DropdownMenuItem(value: r, child: Text('${r.name} (${r.type})'))).toList(),
                onChanged: (v) => setState(() => _selectedRule = v),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: '输入番名', border: OutlineInputBorder()), onSubmitted: (_) => _search())),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _loading ? null : _search, child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('搜索')),
              ],
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  title: Text(r.name),
                  subtitle: Text(r.link, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _openEpisodes(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEpisodes(SearchResult result) async {
    final rule = _selectedRule;
    if (rule == null) return;
    try {
      final episodes = await _engine.getEpisodes(rule, result.link);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => EpisodeListScreen(animeName: result.name, episodes: episodes),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('获取剧集失败：$e')));
    }
  }
}

class EpisodeListScreen extends StatelessWidget {
  final String animeName;
  final List<EpisodeResult> episodes;
  const EpisodeListScreen({super.key, required this.animeName, required this.episodes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(animeName)),
      body: ListView.builder(
        itemCount: episodes.length,
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(episodes[i].name),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PlayerScreen(title: '${animeName} - ${episodes[i].name}', url: episodes[i].url),
            ));
          },
        ),
      ),
    );
  }
}
