import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _bufferSub;

  void attachPlayer(Player player) {
    _player = player;

    _playingSub?.cancel();
    _positionSub?.cancel();
    _bufferSub?.cancel();

    _playingSub = _player!.stream.playing.listen((playing) {
      _broadcastState(playing: playing);
    });

    _positionSub = _player!.stream.position.listen((position) {
      _broadcastState(position: position);
    });

    _bufferSub = _player!.stream.buffer.listen((buffer) {
      _broadcastState(bufferedPosition: buffer);
    });

    player.stream.position.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));

      player.stream.duration.listen((dur) {
        if (dur.inSeconds > 0) {
          mediaItem.add(mediaItem.value?.copyWith(duration: dur));
        }
      });

      player.stream.playing.listen((playing) {
        playbackState.add(
          playbackState.value.copyWith(
            playing: playing,
            controls: [
              MediaControl.rewind,
              playing ? MediaControl.pause : MediaControl.play,
              MediaControl.fastForward,
            ],
            systemActions: {MediaAction.seek},
          ),
        );
      });
    });
  }

  void detachPlayer() {
    _player = null;
    _playingSub?.cancel();
    _positionSub?.cancel();
    _bufferSub?.cancel();
  }

  void _broadcastState({
    bool? playing,
    Duration? position,
    Duration? bufferedPosition,
  }) {
    if (_player == null) return;

    final isPlaying = playing ?? _player!.state.playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: isPlaying,
        updatePosition: position ?? _player!.state.position,
        bufferedPosition: bufferedPosition ?? _player!.state.buffer,
      ),
    );
  }

  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);
  // Obsługa przewijania z poziomu powiadomienia (popupu)

  @override
  Future<void> fastForward() async {
    // Sprawdzamy czy _player nie jest nullem ZANIM go użyjemy
    final player = _player;
    if (player != null) {
      await player.seek(player.state.position + const Duration(seconds: 10));
    }
  }

  @override
  Future<void> rewind() async {
    final player = _player;
    if (player != null) {
      await player.seek(player.state.position - const Duration(seconds: 10));
    }
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    return super.stop();
  }
}
