import 'dart:convert';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_track.dart';
import 'package:ambience/metadata.dart';

const server = 'http://localhost:7070';

class CustomAmbience extends Ambience {
  late final ClipPlaylist music;
  late final FilterableAudioClipTrack weather;
  late final FilterableAudioClipTrack crowd;
  late final Tracklist tracklist;

  CustomAmbience() {
    var musicTrack = AudioClipTrack(this);
    music = ClipPlaylist(musicTrack);
    weather = FilterableAudioClipTrack(this);
    crowd = FilterableAudioClipTrack(this);

    music.onClipChange.listen((clip) => print('CHANGE: ${clip?.id}'));

    httpClient.get(Uri.parse('$server/audio')).then((response) {
      var json = jsonDecode(response.body);

      print(json);
      tracklist = Tracklist.fromJson(json);

      music.fromTracklist(tracklist,
          (track) => '$server/resources/music/tracks/${track.id}.mp3');
    });

    weather
      ..addAll(['wind', 'rain', 'heavy-rain']
          .map((id) => '$server/resources/weather-$id.mp3'))
      ..cueClip(1, transition: 3);

    crowd
      ..addAll(['pub', 'market'].map((id) => '$server/resources/crowd-$id.mp3'))
      ..cueClip(0, transition: 3);
  }

  void changeWeather(int intensity) {
    weather.cueClip(intensity >= 0 ? intensity : null);
  }

  void changeCrowd(int intensity) {
    crowd.cueClip(intensity >= 0 ? intensity : null);
  }
}
