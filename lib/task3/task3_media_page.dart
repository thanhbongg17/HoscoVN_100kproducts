import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class Task3MediaPage extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> assets; // [{type:'image'|'video', url, sizeBytes}]
  const Task3MediaPage({super.key, required this.title, required this.assets});

  @override
  State<Task3MediaPage> createState() => _Task3MediaPageState();
}

class _Task3MediaPageState extends State<Task3MediaPage> {
  final Map<int, ChewieController> _chewie = {};
  final Map<int, VideoPlayerController> _video = {};
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _prepareVideos();
  }

  Future<void> _prepareVideos() async {
    for (var i = 0; i < widget.assets.length; i++) {
      final a = widget.assets[i];
      if (a['type'] == 'video') {
        final v = VideoPlayerController.networkUrl(Uri.parse(a['url'] as String));
        await v.initialize();
        final c = ChewieController(videoPlayerController: v, autoPlay: false, looping: false);
        _video[i] = v;
        _chewie[i] = c;
      }
    }
    if (mounted) setState(() => _initDone = true);
  }

  @override
  void dispose() {
    for (final c in _chewie.values) {
      c.dispose();
    }
    for (final v in _video.values) {
      v.dispose();
    }
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
    if (!_initDone && widget.assets.any((a) => a['type'] == 'video')) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.assets.isEmpty) {
      return const Center(child: Text('Không có media'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.assets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final a = widget.assets[i];
        final type = a['type'] as String;
        final url = a['url'] as String;
        final size = a['sizeBytes'] as int?;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (type == 'image') ...[
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 40)),
                  ),
                ),
              ] else ...[
                AspectRatio(
                  aspectRatio: _video[i]?.value.aspectRatio ?? (16 / 9),
                  child: _chewie[i] != null
                      ? Chewie(controller: _chewie[i]!)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
              ListTile(
                leading: Icon(type == 'image' ? Icons.image : Icons.play_circle_outline),
                title: Text(type == 'image' ? 'Hình ảnh' : 'Video'),
                subtitle: size != null ? Text('~ ${(size / (1024 * 1024)).toStringAsFixed(2)} MB (<5MB)') : null,
                trailing: TextButton(
                  onPressed: () => launchUrlString(url, mode: LaunchMode.externalApplication),
                  child: const Text('Mở link'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
