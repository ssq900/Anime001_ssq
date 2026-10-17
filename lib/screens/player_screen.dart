import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  WebViewController? _webController;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.url.contains('.mp4') || widget.url.contains('.m3u8') || widget.url.contains('.flv')) {
      _playDirect(widget.url);
    } else {
      setState(() => _isExtracting = true);
      _initWebView();
    }
  }

  Future<void> _playDirect(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await controller.initialize();
    
    // 恢复历史记录
    final history = widget.storage?.getHistory(widget.subjectId ?? '');
    if (history != null && history['position'] is int) {
      final pos = Duration(milliseconds: history['position'] as int);
      if (pos.inSeconds > 5) await controller.seekTo(pos);
    }
    
    setState(() {
      _controller = controller;
      _isExtracting = false;
    });
    controller.play();
    _startProgressTimer(controller);
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (url.contains('.m3u8')) {
              _playDirect(url);
              _webController?.stopLoading();
            }
          },
          onPageFinished: (url) async {
            if (_controller != null) return;
            final html = await _webController!.runJavaScriptReturningResult("document.documentElement.outerHTML");
            final regex = RegExp(r'''(https?://[^\s"'<>]+\.(m3u8|mp4)[^\s"'<>]*)''');
            final match = regex.firstMatch(html.toString());
            if (match != null) {
              _playDirect(match.group(1)!);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _startProgressTimer(VideoPlayerController controller) {
    Future.delayed(const Duration(seconds: 10), () async {
      if (!mounted || widget.subjectId == null || widget.storage == null) return;
      await widget.storage!.saveHistory(widget.subjectId!, widget.title, '当前集', controller.value.position);
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isExtracting) {
      return Stack(
        children: [
          WebViewWidget(controller: _webController!),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_controller == null) return const Center(child: CircularProgressIndicator());
    
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
