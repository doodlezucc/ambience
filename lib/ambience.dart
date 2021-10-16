import 'dart:math';
import 'dart:web_audio';

const defaultTransition = 10;

class Ambience {
  late final AudioContext ctx;
  final List<Track> _tracks = [];
  late AudioNode destination;
  late GainNode gainNode;

  num get volume => gainNode.gain!.value!;
  set volume(num volume) => gainNode.gain!.value = volume;

  Ambience({AudioNode? destination})
      : ctx = (destination?.context as AudioContext?) ?? AudioContext() {
    this.destination = destination ?? ctx.destination!;
    gainNode = GainNode(ctx, {'gain': 0.5})..connectNode(this.destination);
  }

  Track createTrack() {
    return Track(this);
  }
}

mixin AmbienceObject {
  late final Ambience ambience;
}

abstract class TrackBase with AmbienceObject {
  bool _active = false;
  bool get isActive => _active;

  void fadeIn({num transition = defaultTransition}) {
    if (!_active) {
      _active = true;
      fadeVolume(1, transition: transition);
    }
  }

  void fadeOut({num transition = defaultTransition}) {
    if (!_active) {
      _active = true;
      fadeVolume(0, transition: transition);
    }
  }

  void fadeVolume(num volume, {num transition = defaultTransition});
}

class Track extends TrackBase {
  final GainNode trackGain;

  Track(Ambience ambience) : trackGain = GainNode(ambience.ctx, {'gain': 0}) {
    this.ambience = ambience;
    ambience._tracks.add(this);
    trackGain.connectNode(ambience.gainNode);
  }

  @override
  void fadeVolume(num volume, {num transition = defaultTransition}) {
    trackGain.gain!.cancelScheduledValues(ambience.ctx.currentTime!);
    trackGain.gain!.setValueAtTime(
      min(max(trackGain.gain!.value!, 0.001), 1),
      ambience.ctx.currentTime!,
    );
    trackGain.gain!.exponentialRampToValueAtTime(
      min(max(volume, 0.001), 1),
      ambience.ctx.currentTime! + transition,
    );

    if (volume == 0) {
      trackGain.gain!.linearRampToValueAtTime(
          0, ambience.ctx.currentTime! + transition + 0.1);
    }
  }
}
