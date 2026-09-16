import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:student_mobile/app/theme/app_colors.dart';

/// S-25 LiveKit video stage — connects with join JWT + wss URL.
class LiveKitStage extends StatefulWidget {
  const LiveKitStage({
    super.key,
    required this.url,
    required this.token,
    this.canPublish = false,
    this.height = 220,
  });

  final String url;
  final String token;
  final bool canPublish;
  final double height;

  @override
  State<LiveKitStage> createState() => _LiveKitStageState();
}

class _LiveKitStageState extends State<LiveKitStage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _error;
  bool _connecting = true;
  VideoTrack? _primaryTrack;
  String? _speakerName;

  @override
  void initState() {
    super.initState();
    unawaited(_connect());
  }

  @override
  void dispose() {
    unawaited(_disconnect());
    super.dispose();
  }

  Future<void> _disconnect() async {
    final listener = _listener;
    _listener = null;
    if (listener != null) {
      await listener.dispose();
    }
    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await room.disconnect();
        await room.dispose();
      } catch (_) {}
    }
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
      _primaryTrack = null;
    });

    try {
      await _disconnect();

      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );
      final listener = room.createListener();
      listener
        ..on<RoomConnectedEvent>((_) {
          if (!mounted) return;
          setState(() => _connecting = false);
          _refreshTracks();
        })
        ..on<TrackSubscribedEvent>((event) {
          if (!mounted) return;
          _refreshTracks();
        })
        ..on<TrackUnsubscribedEvent>((event) {
          if (!mounted) return;
          _refreshTracks();
        })
        ..on<ParticipantConnectedEvent>((_) {
          if (!mounted) return;
          _refreshTracks();
        })
        ..on<ParticipantDisconnectedEvent>((_) {
          if (!mounted) return;
          _refreshTracks();
        })
        ..on<RoomDisconnectedEvent>((event) {
          if (!mounted) return;
          setState(() {
            _error = 'Disconnected from live room.';
            _connecting = false;
            _primaryTrack = null;
          });
        });

      _room = room;
      _listener = listener;

      await room.connect(
        widget.url,
        widget.token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );

      if (widget.canPublish) {
        try {
          await room.localParticipant?.setMicrophoneEnabled(true);
        } catch (error) {
          debugPrint('LiveKit mic enable failed: $error');
        }
      }

      if (!mounted) return;
      setState(() => _connecting = false);
      _refreshTracks();
    } catch (error) {
      debugPrint('LiveKit connect failed: $error');
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Could not connect to live video. Check your connection.';
      });
    }
  }

  void _refreshTracks() {
    final room = _room;
    if (room == null) return;

    VideoTrack? track;
    String? name;

    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final candidate = publication.track;
        if (candidate is VideoTrack && publication.subscribed) {
          track = candidate;
          name = participant.name.isNotEmpty
              ? participant.name
              : participant.identity;
          break;
        }
      }
      if (track != null) break;
    }

    if (track == null) {
      final localPubs = room.localParticipant?.videoTrackPublications ?? [];
      for (final publication in localPubs) {
        final candidate = publication.track;
        if (candidate is VideoTrack) {
          track = candidate;
          name = 'You';
          break;
        }
      }
    }

    setState(() {
      _primaryTrack = track;
      _speakerName = name;
    });
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_primaryTrack != null)
            VideoTrackRenderer(
              _primaryTrack!,
              fit: VideoViewFit.cover,
            )
          else
            _StatusOverlay(
              connecting: _connecting,
              error: _error,
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _speakerName?.isNotEmpty == true
                        ? 'LIVE · $_speakerName'
                        : 'LIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              right: 8,
              top: 8,
              child: TextButton(
                onPressed: () => unawaited(_connect()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.85),
                ),
                child: const Text('Retry'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({
    required this.connecting,
    this.error,
  });

  final bool connecting;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connecting)
              const CircularProgressIndicator(color: Colors.white70)
            else
              const Icon(
                Icons.videocam_outlined,
                color: Colors.white70,
                size: 36,
              ),
            const SizedBox(height: 12),
            Text(
              error ??
                  (connecting
                      ? 'Connecting to live class…'
                      : 'Waiting for the teacher’s video…'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (kIsWeb && error == null && !connecting) ...[
              const SizedBox(height: 6),
              const Text(
                'Allow camera/mic if the browser asks.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
