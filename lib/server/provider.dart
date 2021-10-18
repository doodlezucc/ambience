import 'dart:convert';
import 'dart:io';

class Playlist {
  int _index = -1;
  final List<String> ids;

  Playlist(List<String> videoIDs, {bool shuffle = true})
      : ids = List.from(videoIDs) {
    if (shuffle) {
      ids.shuffle();
    }
  }

  String getNextVideoID() {
    _index = (_index + 1) % ids.length;
    return ids[_index];
  }
}

class AudioInfo {
  final String pageUrl;
  final String title;
  final String audioUrl;
  final String duration;

  AudioInfo(this.pageUrl, this.title, this.audioUrl, this.duration);

  static Future<AudioInfo> extract(String url) async {
    var lines = await _collectYTDLLines([
      '--get-title',
      '--get-duration',
      '-g',
      '-f',
      'bestaudio',
      url,
    ]);

    return AudioInfo(url, lines[0], lines[1], lines[2]);
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

Future<List<String>> _collectYTDLLines(List<String> arguments) async {
  var process = await Process.start('youtube-dl', arguments);

  var lines = <String>[];

  process.stdout.listen((data) {
    var s = utf8.decode(data).trimRight();
    lines.addAll(s.split('\n'));
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
