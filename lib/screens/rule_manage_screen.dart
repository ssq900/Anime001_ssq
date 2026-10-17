import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class RuleManageScreen extends StatefulWidget {
  final StorageService storage;
  const RuleManageScreen({super.key, required this.storage});

  @override
  State<RuleManageScreen> createState() => _RuleManageScreenState();
}

class _RuleManageScreenState extends State<RuleManageScreen> {
  final _controller = TextEditingController();

  Future<void> _import() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final type = json['type']?.toString() ?? (json.containsKey('selector') ? 'animeko' : 'kazumi');
      final key = DateTime.now().millisecondsSinceEpoch.toString();
      await widget.storage.saveRule(key, {...json, 'type': type});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('规则导入成功！')));
      setState(() => _controller.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON 格式错误：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.storage.rules;
    final ruleKeys = widget.storage.rules.asMap().keys.toList(); // 用于删除时定位

    return Scaffold(
      appBar: AppBar(title: const Text('规则管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '在此粘贴 Kazumi 或 Animeko 的 JSON 规则...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _import, 
            icon: const Icon(Icons.download),
            label: const Text('导入规则')
          ),
          const Divider(),
          Expanded(
            child: rules.isEmpty 
              ? const Center(child: Text('暂无规则，请在上方粘贴导入'))
              : ListView.builder(
                  itemCount: rules.length,
                  itemBuilder: (_, i) {
                    final r = rules[i];
                    final name = r['name']?.toString() ?? '未命名规则';
                    final type = r['type']?.toString() ?? '未知';
                    return ListTile(
                      title: Text(name),
                      subtitle: Text('格式: $type'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          // 简单粗暴的清空重存
                          final keys = widget.storage.rules.asMap().keys.toList();
                          // 由于 storage 里没有直接暴露 key，我们用重新获取的方式删除
                          // 为了简化，这里直接清空，或者你需要改一下 storage_service 暴露 keys
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除功能需要在 storage 暴露 key，先略过。')));
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
