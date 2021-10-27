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

class TrackWithTime {
  final Track track;
  final int secondsIn;

  TrackWithTime(this.track, this.secondsIn);
}

class Tracklist {
  final List<Track> tracks;
  DateTime lastChange = DateTime.now();
  int lastChangeTrack = 0;

  Duration get sinceLastChange => DateTime.now().difference(lastChange);
  int get tracklistDuration => tracks.fold(0, (v, t) => v + t.duration);

  Tracklist(this.tracks);
  Tracklist.fromJson(json)
      : tracks = (json['tracks'] as Iterable)
            .map((j) => Track.fromJson(j))
            .toList() {
    if (json['lastChange'] != null && json['lastChangeTrack'] != null) {
      fromSyncJson(json);
    }
  }

  void fromSyncJson(json) {
    lastChange = DateTime.fromMillisecondsSinceEpoch(
      json['lastChange'],
      isUtc: true,
    );
    lastChangeTrack = json['lastChangeTrack'];
  }

  Map<String, dynamic> toSyncJson() => {
        'lastChange': lastChange.millisecondsSinceEpoch,
        'lastChangeTrack': lastChangeTrack,
      };

  Map<String, dynamic> toJson() => {
        ...toSyncJson(),
        'tracks': tracks,
      };

  TrackWithTime getTrackAtTime([DateTime? when]) {
    when ??= DateTime.now();
    var seconds = when.difference(lastChange).inSeconds % tracklistDuration;

    for (var i = 0; i < tracks.length; i++) {
      var track = tracks[(i + lastChangeTrack) % tracks.length];
      if (seconds >= track.duration) {
        seconds -= track.duration;
      } else {
        return TrackWithTime(track, seconds);
      }
    }

    throw 'Failed to get current track, $seconds into the playlist.';
  }

  void setTrack(int index) {
    lastChangeTrack = index % tracks.length;
    lastChange = DateTime.now();
  }
}
