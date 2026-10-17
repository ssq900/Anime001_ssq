import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  final String? subjectId;
  final StorageService? storage;
  const PlayerScreen({super.key, required this.title, required this.url, this.subjectId, this.storage});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await controller.initialize();
    final history = widget.storage?.getHistory(widget.subjectId ?? '');
    if (history != null && history['position'] is int) {
      final pos = Duration(milliseconds: history['position'] as int);
      if (pos.inSeconds > 5) await controller.seekTo(pos);
    }
    setState(() => _controller = controller);
    controller.play();
    _startProgressTimer(controller);
  }

  void _startProgressTimer(VideoPlayerController controller) {
    Future.delayed(const Duration(seconds: 10), () async {
      if (!mounted || widget.subjectId == null || widget.storage == null) return;
      await widget.storage!.saveHistory(
        widget.subjectId!, 
        widget.title, 
        '当前集', 
        controller.value.position
      );
      if (mounted) _startProgressTimer(controller);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
          });
        },
        child: Icon(_controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
