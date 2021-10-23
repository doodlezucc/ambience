import 'dart:async';
import 'dart:web_audio';

import 'audio_track.dart';

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

  num get duration;

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

class PlaylistAudioClipTrack extends AudioClipTrack {
  int _index = 0;
  Timer? _timer;

  PlaylistAudioClipTrack(Ambience ambience) : super(ambience);

  void start() {
    cueClip(_index, transition: 1);
  }

  void skip() {
    print('skipu');
    cueClip((_index + 1) % _clips.length);
  }

  void stop() {
    cueClip(null, transition: 1);
  }

  @override
  void cueClip(int? index, {num transition = 1}) {
    super.cueClip(index, transition: transition);

    _timer?.cancel();
    if (index != null) {
      _index = index;

      _timer = Timer(Duration(seconds: 2), () {
        _timer = Timer(Duration(seconds: activeClip!.duration.toInt() - 2), () {
          skip();
        });
      });
    }
  }
}
