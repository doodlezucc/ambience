import 'dart:web_audio';

class Ambience {
  late final AudioContext ctx;
  final List<Track> tracks = [];

  Ambience({AudioNode? destination})
      : ctx = (destination?.context as AudioContext?) ?? AudioContext();

  Track createTrack() {
    return Track(this);
  }
}

class Track {
  final Ambience ambience;

  Track(this.ambience);
}
