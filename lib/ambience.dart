import 'dart:math';
import 'dart:web_audio';

const defaultTransition = 10;

class Ambience {
  late final AudioContext ctx;
  final List<ClipBase> _clips = [];
  late AudioNode destination;
  late final GainNode _gainNode;

  num get volume => _gainNode.gain!.value!;
  set volume(num volume) {
    _gainNode.gain!.value = volume;
    for (var t in _clips) {
      t.onAmbienceUpdate();
    }
  }

  Ambience({AudioNode? destination})
      : ctx = (destination?.context as AudioContext?) ?? AudioContext() {
    this.destination = destination ?? ctx.destination!;
    _gainNode = GainNode(ctx, {'gain': 0.5})..connectNode(this.destination);
  }
}

mixin AmbienceObject {
  late final Ambience ambience;
}

abstract class ClipBase with AmbienceObject {
  bool _active = false;
  bool get isActive => _active;

  ClipBase(Ambience ambience) {
    this.ambience = ambience;
    ambience._clips.add(this);
    onAmbienceUpdate();
  }

  void fadeIn({num transition = defaultTransition}) {
    if (!_active) {
      _active = true;
      fadeVolume(1, transition: transition);
    }
  }

  void fadeOut({num transition = defaultTransition}) {
    if (_active) {
      _active = false;
      fadeVolume(0, transition: transition);
    }
  }

  void fadeVolume(num volume, {num transition = defaultTransition});

  void onAmbienceUpdate() {}
}

abstract class NodeClip extends ClipBase {
  final GainNode clipGain;

  NodeClip(Ambience ambience)
      : clipGain = GainNode(ambience.ctx, {'gain': 0}),
        super(ambience) {
    clipGain.connectNode(ambience._gainNode);
  }

  @override
  void fadeVolume(num volume, {num transition = defaultTransition}) {
    clipGain.gain!.cancelScheduledValues(ambience.ctx.currentTime!);
    clipGain.gain!.setValueAtTime(
      min(max(clipGain.gain!.value!, 0.005), 1),
      ambience.ctx.currentTime!,
    );

    var clamp = min(max(volume, 0.005), 1);
    var when = ambience.ctx.currentTime! + transition;

    if (volume > clipGain.gain!.value!) {
      clipGain.gain!.exponentialRampToValueAtTime(clamp, when);
    } else {
      clipGain.gain!.linearRampToValueAtTime(min(max(volume, 0), 1), when);
    }
  }
}
