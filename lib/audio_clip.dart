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
  void fadeVolume(num volume, {num transition = defaultTransition}) {
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
  late final MediaElementAudioSourceNode sourceNode;
  late final MediaElementAudioSourceNode sourceNode2;
  num loopTransition = 5;
  bool _loopSwitch = false;

  FilterableAudioClip(FilterableAudioClipTrack track, String url)
      : super(track) {
    var a1 = _initUrl(url);

    AudioElement? a2;

    a1.onCanPlay.first.then((_) => a1.play());

    a1.onTimeUpdate.listen((_) {
      if (!_loopSwitch && a1.currentTime >= a1.duration - loopTransition) {
        _crossFade(a2!, a1);
      }
    });

    a1.onCanPlayThrough.first.then((ev) {
      a2 = _initUrl(url);

      a2!.onTimeUpdate.listen((_) {
        if (!_loopSwitch && a2!.currentTime >= a2!.duration - loopTransition) {
          _crossFade(a1, a2!);
        }
      });
    });
  }

  void _crossFade(AudioElement fadeIn, AudioElement fadeOut) {
    _loopSwitch = true;
    fadeIn.volume = 0;
    fadeIn.play();

    var i = 1;
    var step = 50;

    Timer.periodic(Duration(milliseconds: step), (timer) {
      var t = i * step / (1000 * loopTransition);

      if (t <= 1) {
        fadeIn.volume = pow(t, 0.65);
        fadeOut.volume = pow(1 - t, 0.65);
      } else {
        fadeOut.currentTime = 0;
        fadeOut.pause();
        _loopSwitch = false;
        timer.cancel();
      }
      i++;
    });
  }

  AudioElement _initUrl(String url) {
    var element = AudioElement(url)..crossOrigin = 'anonymous';

    track.ambience.ctx.createMediaElementSource(element).connectNode(clipGain);
    return element;
  }
}

class CrossOriginAudioClip extends ClipBase {
  final AudioElement audio;
  Timer? _volumeTimer;

  double _volume = 0;
  double get volume => _volume;
  set volume(double volume) {
    _volume = volume;
    audio.volume = track.ambience.volume * track.volume * volume;
  }

  CrossOriginAudioClip(AudioClipTrack track, String url)
      : audio = AudioElement(url),
        super(track) {
    document.body!.append(audio);
    audio
      ..loop = true
      ..autoplay = true
      ..controls = true;

    volume = 0;

    track.onVolumeChange.listen((v) {
      volume = volume; // Multiply audio output with correct master volume
    });
  }

  @override
  void fadeVolume(num volume, {num transition = defaultTransition}) {
    _volumeTimer?.cancel();
    var start = this.volume;
    var i = 1;

    var step = 20;

    _volumeTimer = Timer.periodic(Duration(milliseconds: step), (timer) {
      var t = (i * step / 1000) / transition;

      if (t < 1) {
        this.volume = start + t * (volume - start);
      } else {
        timer.cancel();
      }

      i++;
    });
  }
}
