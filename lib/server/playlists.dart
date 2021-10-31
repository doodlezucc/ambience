import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ambience/metadata.dart';
import 'package:path/path.dart' as path;
import 'package:progressbar2/progressbar2.dart';

class PlaylistCollection {
  final Directory directory;
  final Directory tracksDirectory;
  final File metaFile;
  int _lastMod = 0;

  List<Playlist> _playlists = [];
  Iterable<Playlist> get playlists => _playlists;

  Iterable<TrackInfo> get allTracks => _playlists.expand((pl) => pl.tracks);

  PlaylistCollection(this.directory)
      : metaFile = File(path.join(directory.path, 'meta.json')),
        tracksDirectory = Directory(path.join(directory.path, 'tracks'));

  Future<void> reload() async {
    await loadMeta();
    await readSource();
  }

  Future<void> loadMeta() async {
    if (await metaFile.exists()) {
      var content = await metaFile.readAsString();
      var json = jsonDecode(content);

      _lastMod = json['modified'] ?? 0;

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
      'modified': _lastMod,
      'tracks': tracks,
      'playlists': _playlists,
    };
    var content = JsonEncoder.withIndent('  ').convert(json);

    await metaFile.writeAsString(content);
  }

  Future<void> readSource() async {
    var file = File(path.join(directory.path, 'source.json'));

    if (!await file.exists()) return;

    var sourceMod = (await file.lastModified()).millisecondsSinceEpoch;
    var update = sourceMod > _lastMod;

    if (update) {
      _lastMod = sourceMod;
      print('Updating ambience meta...');
    }

    var json = jsonDecode(await file.readAsString());

    for (var pl in json['playlists']) {
      String? id;
      Iterable<String>? exclude;

      if (pl is String) {
        id = pl;
      } else {
        id = pl['id'];
        exclude = List.from(pl['exclude']);
      }

      if (id != null) {
        await addPlaylist(
          id,
          download: false,
          exclude: exclude,
          update: update,
        );
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

  Future<Playlist> addPlaylist(
    String url, {
    bool download = true,
    bool update = false,
    Iterable<String>? exclude,
  }) async {
    Playlist? pl = getPlaylist(url);

    if (update && pl != null) {
      _playlists.remove(pl);
      pl = null;
    }

    if (pl == null) {
      pl = await Playlist.extract(
        url,
        reuse: allTracks,
        exclude: exclude ?? const [],
      );
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

  Tracklist toTracklist({bool shuffle = false}) {
    var src = tracks;
    if (shuffle) src.shuffle();

    return Tracklist(src);
  }

  static Future<Playlist> extract(
    String url, {
    Iterable<TrackInfo>? reuse,
    Iterable<String> exclude = const [],
  }) async {
    var meta = await _collectYTDLLines([
      '-J',
      '--flat-playlist',
      url,
    ]);

    var json = jsonDecode(meta.join());

    List entries = json['entries'];
    var tracks = entries.where((j) => !exclude.contains(j['id'])).map((j) {
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

  DownloadTask _trackToTask(TrackInfo track, Directory dir) =>
      DownloadTask(track, File(path.join(dir.path, '${track.id}.mp3')));

  Future<void> download(
    Directory directory, {
    int threads = 8,
    void Function(double progress)? onProgress,
  }) async {
    var queue = tracks.map((e) => _trackToTask(e, directory)).toList();

    ProgressBar? progressBar;

    if (stdout.hasTerminal) {
      var token = ProgressBar.formatterBarToken;
      progressBar = ProgressBar(
        total: 10000,
        formatter: (current, total, progress, elapsed) {
          var percentage = (100 * progress).toStringAsFixed(2) + '%';

          return '[$token] $percentage';
        },
        width: 100,
      );
    }

    var completer = Completer();
    var count = 0;
    var progress = 0.0;
    for (var i = 0; i < threads; i++) {
      _downloadThread(directory, queue, (downloaded) {
        count++;
        if (downloaded && progressBar == null) {
          print('Downloaded track $count/${tracks.length}');
        }

        if (count == tracks.length) {
          completer.complete();
        }
      }, () {
        progress =
            queue.fold<double>(0, (v, e) => v + e.progress) / queue.length;

        if (onProgress != null) onProgress(progress);

        if (progressBar != null) {
          progressBar.value = (progress * 10000).floor();
          progressBar.render();
        }
      });
    }

    if (progressBar == null) {
      var lastProgress = 0.0;

      Timer.periodic(Duration(seconds: 2), (t) {
        if (completer.isCompleted) {
          t.cancel();
        } else if (progress != lastProgress) {
          var percentage = (progress * 100).toStringAsFixed(2).padLeft(6);
          print('Downloading... $percentage%');
          lastProgress = progress;
        }
      });
    }

    return completer.future;
  }

  void _downloadThread(
    Directory dir,
    List<DownloadTask> queue,
    void Function(bool downloaded) onSuccess,
    void Function() onProgress,
  ) {
    for (var task in queue) {
      if (!task.isDownloading) {
        task.download(onProgress).then((result) {
          if (result != DownloadResult.failed) {
            onSuccess(result == DownloadResult.downloaded);
          }

          _downloadThread(dir, queue, onSuccess, onProgress);
        });
        return;
      }
    }
  }
}

enum DownloadResult { failed, downloaded, skipped }

/// amogus
class DownloadTask {
  final TrackInfo track;
  final File file;
  bool isDownloading = false;
  double progress = 0;

  DownloadTask(this.track, this.file);

  Future<DownloadResult> download(void Function() onProgressUpdate) async {
    isDownloading = true;
    var result = await track.download(file, onProgress: (p) {
      progress = p;
      onProgressUpdate();
    });
    if (result == DownloadResult.failed) isDownloading = false;
    return result;
  }
}

class TrackInfo extends Track {
  TrackInfo(String id, String title, String artist, int duration)
      : super(id, title, artist, duration);

  TrackInfo.fromJson(json) : super.fromJson(json);

  static Future<TrackInfo> extract(String url) async {
    var lines = await _collectYTDLLines([
      '-j',
      url,
    ]);

    var json = jsonDecode(lines.join());

    return TrackInfo(
      json['id'],
      json['fulltitle'],
      json['channel'],
      json['duration'],
    );
  }

  Future<DownloadResult> download(
    File file, {
    String format = '140/bestaudio',
    bool redownload = false,
    void Function(double progress)? onProgress,
  }) async {
    if (!redownload && await file.exists()) {
      if (onProgress != null) onProgress(1);
      return DownloadResult.skipped;
    }

    var tmp = file.path + '.tmp';

    try {
      await _collectYTDLLines(
        ['-f', format, '-o', tmp, '--', id],
        onProgress: onProgress,
      );

      await _collectProcessLines('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        tmp,
        '-filter:a',
        'loudnorm=I=-13', // normalize to -13 LUFS
        '-c:a',
        'libmp3lame',
        '-q:a',
        '5',
        file.path,
      ]);

      await File(tmp).delete();

      return DownloadResult.downloaded;
    } catch (e) {
      print(e);
      return DownloadResult.failed;
    }
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

Future<List<String>> _collectYTDLLines(
  List<String> arguments, {
  bool debug = false,
  void Function(double progress)? onProgress,
}) async {
  var lines = await _collectProcessLines(
    'youtube-dl',
    arguments,
    debug: debug,
    onStdOut: (s) {
      if (onProgress != null) {
        var char = s.indexOf('%');
        if (char > 10) {
          var percentage = s.substring(char - 4, char).trimLeft();

          onProgress(double.parse(percentage) / 100);
        }
      }
    },
  );

  if (onProgress != null) onProgress(1);
  return lines;
}

Future<List<String>> _collectProcessLines(
  String exe,
  List<String> arguments, {
  bool debug = false,
  void Function(String s)? onStdOut,
}) async {
  var process = await Process.start(exe, arguments);

  var lines = <String>[];

  process.stdout.listen((data) {
    var s = utf8.decode(data).trimRight();
    if (onStdOut != null) onStdOut(s);

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

  throw 'Error executing $exe';
}
