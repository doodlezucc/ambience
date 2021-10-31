import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'dart:web_audio';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';

final Map<String, AudioBuffer> resources = {};

abstract class NodeClip extends ClipBase {
  final GainNode clipGain;

  NodeClip(FilterableAudioClipTrack track)
      : clipGain = GainNode(track.ambience.ctx, {'gain': 0}),
        super(track) {
    clipGain.connectNode(track.filterNode);
  }

  @override
  void fadeVolume(num volume,
      {num transition = defaultTransition, num secondsIn = 0}) {
    var ctx = track.ambience.ctx;

    clipGain.gain!.cancelScheduledValues(ctx.currentTime!);
    clipGain.gain!.setValueAtTime(
      min(max(clipGain.gain!.value!, 0.005), 1),
      track.ambience.ctx.currentTime!,
    );

    var clamp = min(max(volume, 0.005), 1);
    var when = ctx.currentTime! + transition;

    if (volume > clipGain.gain!.value!) {
      clipGain.gain!.exponentialRampToValueAtTime(clamp, when);
    } else {
      clipGain.gain!.linearRampToValueAtTime(min(max(volume, 0), 1), when);
    }
  }
}

class FilterableAudioClip extends NodeClip {
  static final curveLH = _powCurve(false);
  static final curveHL = _powCurve(true);

  final String url;
  late final AudioBuffer buffer;
  late final GainNode gain1;
  late final GainNode gain2;
  final num loopTransition = 5;
  bool _playFirst = false;
  bool _initialized = false;
  Timer? _timer;
  final _durationCompleter = Completer<num>();

  @override
  Future<num> get duration => _durationCompleter.future;

  FilterableAudioClip(FilterableAudioClipTrack track, this.url) : super(track) {
    gain1 = _createGain();
    gain2 = _createGain();
  }

  Future<void> _init() async {
    _initialized = true;
    var bytes = await httpClient.readBytes(Uri.parse(url));
    buffer = await track.ambience.ctx.decodeAudioData(bytes.buffer);
    _durationCompleter.complete(buffer.duration);
  }

  @override
  void dispose() {
    _stopCoroutine();
    clipGain.disconnect();
  }

  @override
  void fadeVolume(num volume,
      {num transition = defaultTransition, num secondsIn = 0}) {
    super.fadeVolume(volume, transition: transition, secondsIn: secondsIn);
    if (volume > 0 && _timer == null) {
      if (!_initialized) {
        _init();
      }
      _startCoroutine(secondsIn);
    }
  }

  void _startCoroutine(num secondsIn) async {
    var loopLength = (1000 * ((await duration) - loopTransition)).round();

    _crossFade(secondsIn);

    _timer = Timer.periodic(
      Duration(milliseconds: loopLength),
      (_) => _crossFade(secondsIn),
    );
  }

  void _crossFade(num secondsIn) {
    _playFirst = !_playFirst;
    var fadeIn = _playFirst ? gain1 : gain2;
    var fadeOut = _playFirst ? gain2 : gain1;

    fadeOut.gain!.cancelScheduledValues(track.ambience.ctx.currentTime!);
    fadeIn.gain!.cancelScheduledValues(track.ambience.ctx.currentTime!);
    fadeOut.gain!.setValueCurveAtTime(
        curveHL, track.ambience.ctx.currentTime!, loopTransition);
    fadeIn.gain!.setValueCurveAtTime(
        curveLH, track.ambience.ctx.currentTime!, loopTransition);
    _createSource(fadeIn).start(track.ambience.ctx.currentTime, secondsIn);
  }

  void _stopCoroutine() {
    _timer?.cancel();
    _timer = null;
  }

  AudioBufferSourceNode _createSource(GainNode gain) {
    return AudioBufferSourceNode(track.ambience.ctx)
      ..buffer = buffer
      ..connectNode(gain);
  }

  GainNode _createGain() {
    return GainNode(track.ambience.ctx)..connectNode(clipGain);
  }

  static List<num> _powCurve(bool startHigh) {
    var steps = 8;

    var curve = List<num>.generate(steps, (i) {
      var t = i / (steps - 1);
      if (startHigh) t = 1 - t;

      return pow(t, 0.65);
    });

    return curve;
  }
}

class CrossOriginAudioClip extends ClipBase {
  final String _url;
  final AudioElement audio;
  Timer? _volumeTimer;
  final _durationCompleter = Completer<num>();

  double _volume = 0;
  double get volume => _volume;
  set volume(double volume) {
    _volume = volume;
    audio.volume = track.ambience.volume * track.volume * volume;
  }

  @override
  Future<num> get duration => _durationCompleter.future;

  CrossOriginAudioClip(AudioClipTrack track, String url)
      : audio = AudioElement(),
        _url = url,
        super(track) {
    audio
      ..autoplay = true
      ..onDurationChange
          .first
          .then((_) => _durationCompleter.complete(audio.duration));

    volume = 0;

    track.onVolumeChange.listen((v) {
      volume = volume; // Multiply audio output with correct master volume
    });
  }

  @override
  void dispose() {
    audio.removeAttribute('src');
  }

  @override
  void fadeVolume(num volume,
      {num transition = defaultTransition, num secondsIn = 0}) {
    _volumeTimer?.cancel();

    if (volume > 0 && audio.paused) {
      audio.src = _url;
      audio.currentTime = secondsIn;
    }

    var start = this.volume;
    var i = 1;
    var step = 20;

    _volumeTimer = Timer.periodic(Duration(milliseconds: step), (timer) {
      var t = (i * step / 1000) / transition;

      if (t < 1) {
        this.volume = start + t * (volume - start);
      } else {
        this.volume = volume.toDouble();
        if (volume == 0) {
          audio.removeAttribute('src');
        }
        timer.cancel();
      }

      i++;
    });
  }
}
