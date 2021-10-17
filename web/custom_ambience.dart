import 'package:ambience/ambience.dart';
import 'package:ambience/audio_clip.dart';
import 'package:ambience/audio_track.dart';
import 'package:http/http.dart' as http;

final httpClient = http.Client();

class CustomAmbience extends Ambience {
  late final AudioClipTrack music;
  late final FilterableAudioClipTrack weather;

  CustomAmbience() {
    music = AudioClipTrack(this);
    weather = FilterableAudioClipTrack(this);

    httpClient.get(Uri.parse('http://localhost:7070/audio')).then((response) {
      CrossOriginAudioClip(music, response.body).fadeIn();
    });

    FilterableAudioClip(weather, 'http://localhost:7070/resources/rain.mp3')
        .cue(transition: 5);
  }

  void changeWeather(bool rain) {
    weather.cueClip(rain ? 0 : null);
  }
}
