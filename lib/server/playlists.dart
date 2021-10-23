import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

class PlaylistCollection {
  final Directory directory;
  final Directory tracksDirectory;
  final File file;

  List<Playlist> _playlists = [];
  Iterable<Playlist> get playlists => _playlists;

  Iterable<TrackInfo> get allTracks => _playlists.expand((pl) => pl.tracks);

  PlaylistCollection(this.directory)
      : file = File(path.join(directory.path, 'meta.json')),
        tracksDirectory = Directory(path.join(directory.path, 'tracks'));

  Future<void> reload() async {
    await loadMeta();
    await readSource();
  }

  Future<void> loadMeta() async {
    if (await file.exists()) {
      var content = await file.readAsString();
      var json = jsonDecode(content);

      var tracks =
          List.from(json['tracks']).map((j) => TrackInfo.fromJson(j)).toSet();

      _playlists = List.from(json['playlists'])
          .map((j) => Playlist.fromJson(tracks, j))
          .toList();
    }
  }

  Future<void> saveMeta() async {
    var tracks = <TrackInfo>[];

    for (var track in allTracks) {
      if (!tracks.any((t) => t.id == track.id)) {
        tracks.add(track);
      }
    }

    var json = {
      'tracks': tracks,
      'playlists': _playlists,
    };
    var content = JsonEncoder.withIndent('  ').convert(json);

    await file.writeAsString(content);
  }

  Future<void> readSource() async {
    var file = File(path.join(directory.path, 'source.json'));
    var json = jsonDecode(await file.readAsString());

    for (var pl in json['playlists']) {
      String? id = (pl is String) ? pl : pl['id'];
      if (id != null) {
        await addPlaylist(id, download: false);
      }
    }
  }

  Playlist? getPlaylist(String url) {
    for (var pl in _playlists) {
      if (url.contains(pl.id)) {
        return pl;
      }
    }
    return null;
  }

  Future<Playlist> addPlaylist(String url, {bool download = true}) async {
    Playlist? pl = getPlaylist(url);

    if (pl == null) {
      pl = await Playlist.extract(url, allTracks);
      _playlists.add(pl);
      await saveMeta();
    }

    if (download) {
      await pl.download(tracksDirectory);
    }

    return pl;
  }

  Future<void> sync() async {
    for (var pl in _playlists) {
      await pl.download(tracksDirectory);
    }
  }
}

class Playlist {
  final String id;
  String title;
  final List<TrackInfo> tracks;

  Playlist(this.id, this.title, this.tracks);

  Playlist.fromJson(Set<TrackInfo> tracks, Map<String, dynamic> json)
      : this(
            json['id'],
            json['title'],
            List.from(json['tracks'])
                .map((id) => tracks.firstWhere((t) => t.id == id))
                .toList());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tracks': tracks.map((t) => t.id).toList(),
      };

  static Future<Playlist> extract(String url,
      [Iterable<TrackInfo>? reuse]) async {
    var meta = await _collectYTDLLines([
      '-J',
      '--flat-playlist',
      url,
    ]);

    var json = jsonDecode(meta[0]);

    List entries = json['entries'];
    var tracks = entries.map((j) {
      String id = j['id'];

      if (reuse != null && reuse.any((t) => t.id == id)) {
        return reuse.firstWhere((t) => t.id == id);
      }

      String title = j['title'];
      String uploader = j['uploader'];
      int duration = (j['duration'] as num).toInt();

      return TrackInfo(id, title, uploader, duration);
    }).toList();

    return Playlist(json['id'], json['title'], tracks);
  }

  Future<void> download(Directory directory,
      {int threads = 8, void Function()? onProgress}) async {
    var queue = List<TrackInfo>.from(tracks);
    var completer = Completer();
    var count = 0;
    for (var i = 0; i < threads; i++) {
      _downloadThread(directory, queue, () {
        count++;
        //print('Downloaded track $count/${tracks.length}');

        if (count == tracks.length) {
          completer.complete();
        }
      });
    }

    return completer.future;
  }

  void _downloadThread(
      Directory dir, List<TrackInfo> queue, void Function() onSuccess) {
    if (queue.isNotEmpty) {
      var track = queue.removeAt(0);

      track
          .download(File(path.join(dir.path, '${track.id}.mp3')))
          .then((success) {
        if (success) {
          onSuccess();
        } else {
          queue.add(track);
        }

        _downloadThread(dir, queue, onSuccess);
      });
    }
  }
}

class TrackInfo {
  final String id;
  String title;
  String artist;
  final int duration;

  String get thumbnail => 'https://i.ytimg.com/vi_webp/$id/maxresdefault.webp';

  TrackInfo(this.id, this.title, this.artist, this.duration);

  TrackInfo.fromJson(Map<String, dynamic> json)
      : this(json['id'], json['title'], json['artist'], json['duration']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'duration': duration,
      };

  static Future<TrackInfo> extract(String url) async {
    var lines = await _collectYTDLLines([
      '-j',
      url,
    ]);

    var json = jsonDecode(lines[0]);

    return TrackInfo(
      json['id'],
      json['fulltitle'],
      json['channel'],
      json['duration'],
    );
  }

  Future<bool> download(File file,
      {String format = 'bestaudio', bool redownload = false}) async {
    if (!redownload && await file.exists()) {
      return true;
    }

    try {
      await _collectYTDLLines([
        '-f',
        format,
        '--extract-audio',
        '--audio-format',
        'mp3',
        '-o',
        file.path,
        '--',
        id,
      ]);

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  @override
  String toString() {
    var d = Duration(seconds: duration);

    var min = d.inMinutes;
    var sec = (d.inSeconds % 60).toString().padLeft(2, '0');

    return '$title ($min:$sec)';
  }
}

Future<List<String>> getVideosInPlaylist(String playlist) async {
  var lines = await _collectYTDLLines([
    '--flat-playlist',
    '--get-id',
    playlist,
  ]);

  return lines;
}

Future<List<String>> _collectYTDLLines(List<String> arguments,
    {bool debug = false}) async {
  var process = await Process.start('youtube-dl', arguments);

  var lines = <String>[];

  process.stdout.listen((data) {
    var s = utf8.decode(data).trimRight();
    lines.addAll(s.split('\n'));
    if (debug) {
      print(s);
    }
  });
  process.stderr.listen((data) {
    stderr.add(data);
  });

  var exitCode = await process.exitCode;
  if (exitCode == 0) {
    return lines;
  }

  throw 'Error executing youtube-dl';
}
