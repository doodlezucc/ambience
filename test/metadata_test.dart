import 'package:ambience/metadata.dart';
import 'package:test/test.dart';

void main() {
  var tracklist = Tracklist.fromJson({
    'tracks': [
      {
        'id': '9YfrZaql4EE',
        'title': 'A Drink Deserved',
        'artist': 'Hayden McGowan',
        'duration': 175
      },
      {
        'id': 'GrfwoMw3EFU',
        'title': "Maiden's Lullaby",
        'artist': 'Adrian von Ziegler',
        'duration': 129
      },
      {
        'id': 'V_Z6MkNh4yM',
        'title': 'Winter Journey',
        'artist': 'TeknoAXE',
        'duration': 306
      },
    ],
  });

  test('Get Track At Time', () {
    tracklist.setTrack(4);

    var when = DateTime.now().add(Duration(minutes: 3));
    var track = tracklist.getTrackAtTime(when);
    expect(track.track.id, 'V_Z6MkNh4yM');
    expect(track.secondsIn, 180 - 129);
  });
}
