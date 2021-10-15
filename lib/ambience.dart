import 'dart:web_audio';

const defaultTransition = 5;

class Ambience {
  late final AudioContext ctx;
  final List<Track> _tracks = [];
  late AudioNode destination;

  Ambience({AudioNode? destination})
      : ctx = (destination?.context as AudioContext?) ?? AudioContext() {
    this.destination = destination ?? ctx.destination!;
  }

  Track createTrack() {
    return Track(this);
  }
}

class Track {
  final Ambience ambience;
  final GainNode trackGain;
  bool _active = false;
  bool get isActive => _active;

  Track(this.ambience) : trackGain = GainNode(ambience.ctx, {'gain': 0}) {
    ambience._tracks.add(this);
    trackGain.connectNode(ambience.destination);
  }

  void fadeIn({num transition = defaultTransition}) {
    if (!_active) {
      _active = true;
      _fade(1, transition: transition);
    }
  }

  void fadeOut({num transition = defaultTransition}) {
    if (_active) {
      _active = false;
      _fade(0, transition: transition);
    }
  }

  void _fade(num gain, {num transition = defaultTransition}) {
    trackGain.gain!.exponentialRampToValueAtTime(
      gain,
      ambience.ctx.currentTime! + transition,
    );
  }
}
