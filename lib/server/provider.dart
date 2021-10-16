import 'dart:convert';
import 'dart:io';

class YoutubeProvider {}

class Playlist {}

class AudioInfo {
  final String pageUrl;
  final String title;
  final String audioUrl;
  final String duration;

  AudioInfo(this.pageUrl, this.title, this.audioUrl, this.duration);

  static Future<AudioInfo> fromUrl(String url) async {
    var process = await Process.start('youtube-dl', [
      '--get-title',
      '--get-duration',
      '-g',
      '-f',
      'bestaudio',
      url,
    ]);

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
      return AudioInfo(url, lines[0], lines[1], lines[2]);
    }

    throw 'Error executing youtube-dl';
  }
}
