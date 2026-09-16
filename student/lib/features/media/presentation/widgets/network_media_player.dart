import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// Shared network video/audio player for S-22 / S-26.
class NetworkMediaPlayer extends StatefulWidget {
  const NetworkMediaPlayer({
    super.key,
    required this.url,
    this.autoPlay = false,
    this.aspectRatio,
    this.onPosition,
    this.height = 220,
  });

  final String url;
  final bool autoPlay;
  final double? aspectRatio;
  final ValueChanged<Duration>? onPosition;
  final double height;

  @override
  State<NetworkMediaPlayer> createState() => _NetworkMediaPlayerState();
}

class _NetworkMediaPlayerState extends State<NetworkMediaPlayer> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant NetworkMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposePlayers();
      _init();
    }
  }

  @override
  void dispose() {
    _disposePlayers();
    super.dispose();
  }

  void _disposePlayers() {
    _chewie?.dispose();
    _chewie = null;
    final video = _video;
    _video = null;
    video?.removeListener(_onTick);
    video?.dispose();
  }

  void _onTick() {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    widget.onPosition?.call(video.value.position);
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      controller.addListener(_onTick);
      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: widget.autoPlay,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: widget.aspectRatio ?? controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.accent,
          handleColor: AppColors.brand,
          bufferedColor: AppColors.brandSoft,
          backgroundColor: Colors.white24,
        ),
      );
      if (!mounted) {
        chewie.dispose();
        controller.dispose();
        return;
      }
      setState(() {
        _video = controller;
        _chewie = chewie;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to play this media.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2433),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    if (_error != null || _chewie == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_outline, color: Colors.white70, size: 36),
              const SizedBox(height: 10),
              Text(
                _error ?? 'Player unavailable',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _init,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Chewie(controller: _chewie!);
  }
}
