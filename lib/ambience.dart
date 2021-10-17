import 'dart:async';
import 'dart:web_audio';

const defaultTransition = 10;

class Ambience {
  late final AudioContext ctx;
  final List<TrackBase> _tracks = [];
  late AudioNode destination;
  late final GainNode gainNode;

  final _ctrl = StreamController<num>.broadcast();
  Stream<num> get onVolumeChange => _ctrl.stream;

  num get volume => gainNode.gain!.value!;
  set volume(num volume) {
    gainNode.gain!.value = volume;
    _ctrl.sink.add(volume);
  }

  Ambience({AudioNode? destination})
      : ctx = (destination?.context as AudioContext?) ?? AudioContext() {
    this.destination = destination ?? ctx.destination!;
    gainNode = GainNode(ctx, {'gain': 0.5})..connectNode(this.destination);
  }
}

mixin AmbienceObject {
  late final Ambience ambience;
}

abstract class TrackBase<C extends ClipBase> with AmbienceObject {
  late final int id;
  final List<C> _clips = [];

  int? _activeClip;
  C? get activeClip => _activeClip == null ? null : _clips[_activeClip!];

  num get volume;
  set volume(num volume);

  TrackBase(Ambience ambience) {
    id = ambience._tracks.length;
    ambience._tracks.add(this);
    this.ambience = ambience;
  }

  void cueClip(int? index, {num transition = defaultTransition}) {
    activeClip?.fadeOut(transition: transition);

    if (index != null) {
      _clips[index].fadeIn(transition: transition);
    }
    _activeClip = index;
  }
}

abstract class ClipBase {
  final TrackBase track;
  late final int id;

  bool _active = false;
  bool get isActive => _active;

  ClipBase(this.track) {
    id = track._clips.length;
    track._clips.add(this);
  }

  void cue({num transition = defaultTransition}) {
    track.cueClip(id);
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
}
