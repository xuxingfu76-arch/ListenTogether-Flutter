import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
class RoomAudio {
  final AudioPlayer player = AudioPlayer();
  String? _currentUrl;
  bool _ready = false;
  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }
  String? get currentUrl => _currentUrl;
  Stream<Duration> get positionStream => player.positionStream;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  Future<void> playUrl(String url, {double positionSec = 0, bool playing = true}) async {
    if (url.isEmpty) return;
    try {
      if (_currentUrl != url) {
        _currentUrl = url;
        _ready = false;
        await player.setUrl(url);
        _ready = true;
        if (positionSec > 0) await player.seek(Duration(milliseconds: (positionSec * 1000).toInt()));
      }
      if (playing) { await player.play(); } else { await player.pause(); }
    } catch (_) {}
  }
  Future<void> applyPlaying(bool playing) async {
    if (!_ready) return;
    try { if (playing) { await player.play(); } else { await player.pause(); } } catch (_) {}
  }
  Future<void> seekTo(double sec) async {
    try { await player.seek(Duration(milliseconds: (sec * 1000).toInt())); } catch (_) {}
  }
  Future<void> stop() async {
    try { await player.stop(); } catch (_) {}
    _currentUrl = null; _ready = false;
  }
  void dispose() { player.dispose(); }
}
