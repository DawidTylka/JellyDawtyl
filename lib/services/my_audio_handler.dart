import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  Player? _player;
  StreamSubscription<dynamic>? _playingSub;
  StreamSubscription<dynamic>? _positionSub;
  StreamSubscription<dynamic>? _bufferSub;
  StreamSubscription<dynamic>? _durationSub;

  Function()? onSkipToNextLocal;
  Function()? onSkipToPreviousLocal;

  // Dostępność poprzedniego/następnego odcinka dla przycisków powiadomienia.
  bool _hasPreviousEpisode = false;
  bool _hasNextEpisode = false;

  void updateEpisodeStatus(bool hasPrev, bool hasNext) {
    _hasPreviousEpisode = hasPrev;
    _hasNextEpisode = hasNext;
    _broadcastState();
  }

  void attachPlayer(Player player) {
    _player = player;

    _playingSub?.cancel();
    _positionSub?.cancel();
    _bufferSub?.cancel();
    _durationSub?.cancel();

    _playingSub = _player!.stream.playing.listen(
      (playing) => _broadcastState(playing: playing),
    );
    _positionSub = _player!.stream.position.listen((position) {
      if (_shouldBroadcastPosition(position)) {
        _broadcastState(position: position);
      }
    });
    _bufferSub = _player!.stream.buffer.listen((buffer) {
      if (_shouldBroadcastPosition(_player?.state.position ?? Duration.zero)) {
        _broadcastState(bufferedPosition: buffer);
      }
    });
    _durationSub = _player!.stream.duration.listen((dur) {
      if (dur.inSeconds > 0) {
        mediaItem.add(mediaItem.value?.copyWith(duration: dur));
      }
    });
  }

  // mpv reports the position many times a second; every report used to send
  // a full PlaybackState over the platform channel. The notification only
  // needs about one update per second, plus an immediate one after a seek.
  static const _positionBroadcastInterval = Duration(seconds: 1);
  DateTime _lastPositionBroadcastAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _lastBroadcastPosition = Duration.zero;

  bool _shouldBroadcastPosition(Duration position) {
    final now = DateTime.now();
    final jumped =
        (position - _lastBroadcastPosition).abs() > const Duration(seconds: 2);
    if (!jumped &&
        now.difference(_lastPositionBroadcastAt) < _positionBroadcastInterval) {
      return false;
    }
    _lastPositionBroadcastAt = now;
    _lastBroadcastPosition = position;
    return true;
  }

  bool isAttachedTo(Player player) => identical(_player, player);

  void detachPlayer(Player player) {
    // A route replacement creates the next player before the previous route is
    // disposed. Do not let the old route detach the newly attached player.
    if (!identical(_player, player)) return;

    _player = null;
    _playingSub?.cancel();
    _positionSub?.cancel();
    _bufferSub?.cancel();
    _durationSub?.cancel();
  }

  void _broadcastState({
    bool? playing,
    Duration? position,
    Duration? bufferedPosition,
  }) {
    if (_player == null) return;
    final isPlaying = playing ?? _player!.state.playing;

    // --- ZMIANA 2: Dynamiczna budowa przycisków ---
    final controls = <MediaControl>[];

    // Dodaj "Poprzedni", tylko jeśli to NIE jest pierwszy odcinek
    if (_hasPreviousEpisode) controls.add(MediaControl.skipToPrevious);

    // Play / Pauza są zawsze na środku
    controls.add(isPlaying ? MediaControl.pause : MediaControl.play);

    // Dodaj "Następny", tylko jeśli to NIE jest ostatni odcinek
    if (_hasNextEpisode) controls.add(MediaControl.skipToNext);

    // Dynamicznie dopasowujemy indeksy.
    // Jeśli nie ma np. przycisku "Poprzedni", to [0,1,2] wywołałoby awarię Androida.
    // List.generate generuje bezpieczne np. [0, 1].
    final compactIndices = List.generate(controls.length, (i) => i);

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: compactIndices,
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

  @override
  Future<void> skipToNext() async {
    onSkipToNextLocal?.call();
    super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPreviousLocal?.call();
    super.skipToPrevious();
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    return super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    // Usunięcie aplikacji z listy ostatnich aplikacji oznacza świadome
    // zakończenie odtwarzania. Samo zminimalizowanie nie wywołuje tej metody.
    await stop();
  }
}
