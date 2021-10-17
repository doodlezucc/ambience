import 'dart:async';
import 'dart:web_audio';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_clip.dart';

class AudioClipTrack extends TrackBase<CrossOriginAudioClip> {
  final _ctrl = StreamController<num>.broadcast();
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
}

class FilterableAudioClipTrack extends TrackBase<FilterableAudioClip> {
  late final GainNode trackGain = GainNode(ambience.ctx, {'gain': 0.8})
    ..connectNode(ambience.gainNode);

  late final BiquadFilterNode filterNode = BiquadFilterNode(ambience.ctx)
    ..connectNode(trackGain)
    ..type = 'lowpass'
    ..frequency!.value = 20000;

  FilterableAudioClipTrack(Ambience ambience) : super(ambience);

  @override
  num get volume => trackGain.gain!.value!;

  @override
  set volume(num volume) => trackGain.gain!.value = volume;

  num get filter => filterNode.frequency!.value!;
  set filter(num filter) => filterNode.frequency!.value = filter;
}
