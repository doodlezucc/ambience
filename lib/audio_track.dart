import 'dart:async';
import 'dart:web_audio';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_clip.dart';

class AudioClipTrack extends TrackBase<CrossOriginAudioClip> {
  var _ctrl = StreamController<num>.broadcast();
  Stream<num> get onVolumeChange => _ctrl.stream;

  num _volume = 0.8;

  @override
  num get volume => _volume;

  @override
  set volume(num volume) {
    _volume = volume;
    _ctrl.sink.add(volume);
  }

  AudioClipTrack(Ambience ambience) : super(ambience) {
    ambience.onVolumeChange.listen((_) => volume = volume);
  }

  @override
  CrossOriginAudioClip addClip(String url) {
    return CrossOriginAudioClip(this, url);
  }

  @override
  Future<void> clear({num fadeOut = 1}) {
    _ctrl.close();
    _ctrl = StreamController<num>.broadcast();
    return super.clear(fadeOut: fadeOut);
  }
}

class FilterableAudioClipTrack extends TrackBase<FilterableAudioClip> {
  late final GainNode trackGain = GainNode(ambience.ctx, {'gain': 0.8})
    ..connectNode(ambience.gainNode);

  late final BiquadFilterNode filterNode = BiquadFilterNode(ambience.ctx)
    ..connectNode(trackGain)
    ..type = 'lowpass'
    ..frequency!.value = 20000;

  @override
  num get volume => trackGain.gain!.value!;

  @override
  set volume(num volume) => trackGain.gain!.value = volume;

  num get filter => filterNode.frequency!.value!;
  set filter(num filter) => filterNode.frequency!.value = filter;

  FilterableAudioClipTrack(Ambience ambience) : super(ambience);

  @override
  FilterableAudioClip addClip(String url) {
    return FilterableAudioClip(this, url);
  }
}
