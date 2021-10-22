import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

class PlaylistCollection {
  final Directory directory;
  final File file;
  final List<Playlist> _playlists = [];
  Iterable<Playlist> get playlists => _playlists;

  PlaylistCollection(this.directory)
      : file = File(path.join(directory.path, 'playlists.json'));

  Future<void> load() async {
    if (!await file.exists()) return;

    var content = await file.readAsString();
    var json = jsonDecode(content);

    _playlists
      ..clear()
      ..addAll(List.from(json['playlists']).map((j) => Playlist.fromJson(j)));
  }

  Future<void> save() async {
    var json = {'playlists': _playlists};
    var content = JsonEncoder.withIndent('  ').convert(json);

    await file.writeAsString(content);
  }

  Playlist? getPlaylist(String url) {
    for (var pl in _playlists) {
      if (url.contains(pl.id)) {
        return pl;
      }
    }
    return null;
  }

  Future<Playlist> addPlaylist(String url, {download = true}) async {
    var pl = getPlaylist(url) ?? await Playlist.extract(url);
    _playlists.add(pl);

    if (download) {
      await pl.download(Directory(path.join(directory.path, 'tracks')));
    }

    return pl;
  }
}

class Playlist {
  final String id;
  String title;
  final List<TrackInfo> tracks;

  Playlist(this.id, this.title, this.tracks);

  Playlist.fromJson(Map<String, dynamic> json)
      : this(
            json['id'],
            json['title'],
            List.from(json['tracks'])
                .map((j) => TrackInfo.fromJson(j))
                .toList());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'tracks': tracks.map((e) => e.toJson()).toList(),
      };

  static Future<Playlist> extract(String url) async {
    var meta = await _collectYTDLLines([
      '-J',
      '--flat-playlist',
      url,
    ]);

    var json = jsonDecode(meta[0]);

    List entries = json['entries'];
    var tracks = entries
        .map((j) => TrackInfo(
              j['id'],
              j['title'],
              j['uploader'],
              j['duration'].toInt(),
            ))
        .toList();

    return Playlist(json['id'], json['title'], tracks);
  }

  Future<void> download(Directory directory, {int threads = 8}) async {
    var queue = List<TrackInfo>.from(tracks);
    var completer = Completer();
    var count = 0;
    for (var i = 0; i < threads; i++) {
      _downloadThread(directory, queue, () {
        count++;
        print('Downloaded track $count/${tracks.length}');

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
  final String title;
  final String channel;
  final int duration;

  String get thumbnail => 'https://i.ytimg.com/vi_webp/$id/maxresdefault.webp';

  TrackInfo(this.id, this.title, this.channel, this.duration);

  TrackInfo.fromJson(Map<String, dynamic> json)
      : this(json['id'], json['title'], json['channel'], json['duration']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'channel': channel,
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
  String toString() => '$title (${Duration(seconds: duration)})';
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
