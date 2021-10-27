import 'dart:async';
import 'dart:web_audio';

import 'package:ambience/metadata.dart';
import 'package:http/http.dart';

const defaultTransition = 7;
final httpClient = Client();

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
  final List<C> _clips = [];

  int? _activeClip;
  C? get activeClip => _activeClip == null ? null : _clips[_activeClip!];

  num get volume;
  set volume(num volume);

  TrackBase(Ambience ambience) {
    ambience._tracks.add(this);
    this.ambience = ambience;
  }

  C addClip(String url);
  Iterable<C> addAll(Iterable<String> urls) {
    return urls.map((url) => addClip(url)).toList();
  }

  void cueClip(int? index,
      {num transition = defaultTransition, num secondsIn = 0}) {
    activeClip?.fadeOut(transition: transition);

    if (index != null) {
      _clips[index].fadeIn(transition: transition, secondsIn: secondsIn);
    }
    _activeClip = index;
  }

  Future<void> clear({num fadeOut = 1}) async {
    activeClip?.fadeOut(transition: fadeOut);
    await Future.delayed(Duration(milliseconds: (1000 * fadeOut).toInt()));

    for (var c in _clips) {
      c.dispose();
    }
    _activeClip = null;
    _clips.clear();
  }
}

abstract class ClipBase {
  final TrackBase track;
  late final int id;

  bool _active = false;
  bool get isActive => _active;

  Future<num> get duration;

  ClipBase(this.track) {
    id = track._clips.length;
    track._clips.add(this);
  }

  void cue({num transition = defaultTransition}) {
    track.cueClip(id);
  }

  void fadeIn({num transition = defaultTransition, num secondsIn = 0}) {
    if (!_active) {
      _active = true;
      fadeVolume(1, transition: transition, secondsIn: secondsIn);
    }
  }

  void fadeOut({num transition = defaultTransition}) {
    if (_active) {
      _active = false;
      fadeVolume(0, transition: transition);
    }
  }

  void fadeVolume(num volume,
      {num transition = defaultTransition, num secondsIn = 0});

  void dispose();
}

class ClipPlaylist<T extends TrackBase> {
  final T track;
  final _ctrl = StreamController<ClipBase?>.broadcast();
  num fadeOutTransition = 2;
  Timer? _timer;

  Stream<ClipBase?> get onClipChange => _ctrl.stream;

  int _index = 0;
  int get index => _index;
  set index(int index) => _setTrack(index);

  ClipPlaylist(this.track);

  void start() => cueClip(_index, transition: 1);

  void skip() => index++;

  void stop() => cueClip(null, transition: defaultTransition);

  void _setTrack(int index, {num secondsIn = 0}) {
    _index = index % track._clips.length;
    _timer?.cancel();
    track.activeClip?.fadeOut(transition: fadeOutTransition);

    _ctrl.sink.add(track._clips[_index]);
    _timer = Timer(Duration(seconds: 1), () {
      cueClip(
        _index,
        transition: 0.1,
        notifyListeners: false,
        secondsIn: secondsIn,
      );
    });
  }

  void cueClip(
    int? index, {
    num transition = 1,
    bool notifyListeners = true,
    num secondsIn = 0,
  }) async {
    track.cueClip(index, transition: transition, secondsIn: secondsIn);
    if (notifyListeners) {
      _ctrl.sink.add(track.activeClip);
    }

    _timer?.cancel();
    if (index != null) {
      _index = index;

      var duration = (await track.activeClip!.duration).toInt();
      var wait = duration - fadeOutTransition - secondsIn;

      _timer = Timer(Duration(milliseconds: (1000 * wait).round()), skip);
    }
  }

  void syncToTracklist(Tracklist tracklist) {
    var t = tracklist.getTrackAtTime();
    _setTrack(t.playlistIndex, secondsIn: t.secondsIn);
  }

  Future<void> fromTracklist(
      Tracklist? tracklist, String Function(Track track) trackToUrl) async {
    await track.clear();
    if (tracklist == null) {
      _timer?.cancel();
    } else {
      track.addAll(tracklist.tracks.map(trackToUrl));
      syncToTracklist(tracklist);
    }
  }
}
