class Track {
  final String id;
  String title;
  String artist;
  final int duration;
  String get thumbnail => 'https://i.ytimg.com/vi_webp/$id/maxresdefault.webp';

  Track(this.id, this.title, this.artist, this.duration);

  Track.fromJson(Map<String, dynamic> json)
      : this(json['id'], json['title'], json['artist'], json['duration']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration': duration,
      };

  @override
  String toString() {
    var d = Duration(seconds: duration);

    var min = d.inMinutes;
    var sec = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$title ($min:$sec)';
  }
}

class Tracklist {
  final List<Track> tracks = [];

  int _index = 0;
  int get index => _index;
  set index(int index) {
    _index = index % tracks.length;
  }

  Track? get currentTrack => tracks.isEmpty ? null : tracks[index];

  void fromJson(json) {
    _index = json['index'];
    tracks.clear();
    Iterable jTracks = json['tracks'];

    tracks.addAll(jTracks.map((j) => Track.fromJson(j)));
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'tracks': tracks,
      };
}
