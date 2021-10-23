import 'dart:convert';

import 'package:ambience/ambience.dart';
import 'package:ambience/audio_clip.dart';
import 'package:ambience/audio_track.dart';
import 'package:http/http.dart' as http;

final httpClient = http.Client();

class CustomAmbience extends Ambience {
  late final PlaylistAudioClipTrack music;
  late final FilterableAudioClipTrack weather;

  CustomAmbience() {
    music = PlaylistAudioClipTrack(this);
    weather = FilterableAudioClipTrack(this);

    httpClient.get(Uri.parse('http://localhost:7070/audio')).then((response) {
      var json = jsonDecode(response.body);

      print(json['tracks']);

      for (var track in json['tracks']) {
        CrossOriginAudioClip(music,
            'http://localhost:7070/resources/music/tracks/${track['id']}.mp3');
      }

      music.cueClip(0);
    });

    FilterableAudioClip(
      weather,
      'http://localhost:7070/resources/weather-rain.mp3',
    ).cue(transition: 5);
  }

  void changeWeather(bool rain) {
    weather.cueClip(rain ? 0 : null);
  }
}
