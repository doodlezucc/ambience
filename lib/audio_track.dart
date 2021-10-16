import 'dart:async';
import 'dart:html';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:ambience/ambience.dart';

final Map<String, AudioBuffer> resources = {};

mixin Filterable on Track {
  late final BiquadFilterNode filterNode = BiquadFilterNode(ambience.ctx)
    ..connectNode(trackGain)
    ..type = 'lowpass'
    ..frequency!.value = 20000;

  num get filter => filterNode.frequency!.value!;
  set filter(num filter) => filterNode.frequency!.value = filter;
}

@Deprecated("Use AudioStreamTrack instead for better performance")
class AudioBufferTrack extends Track with Filterable {
  final AudioBufferSourceNode sourceNode;

  AudioBufferTrack(Ambience ambience, String url)
      : sourceNode = AudioBufferSourceNode(ambience.ctx),
        super(ambience) {
    sourceNode.connectNode(filterNode);

    // Load URL as audio buffer
    getBuffer(url).then((buffer) {
      print(buffer.duration);
      sourceNode
        ..buffer = buffer
        ..loop = true
        ..start();
    });
  }

  Future<AudioBuffer> getBuffer(String url) async {
    if (resources[url] != null) return resources[url]!;

    var req = await HttpRequest.request(url, responseType: 'blob');
    var response = req.response;

    var reader = FileReader();
    reader.readAsArrayBuffer(response);
    var loadEndEvent = await reader.onLoadEnd.first;

    print('Loaded ${loadEndEvent.total} bytes');

    var bytes = (reader.result as Uint8List);

    var audioBuffer = await ambience.ctx.decodeAudioData(bytes.buffer);
    resources[url] = audioBuffer;
    return audioBuffer;
  }
}

class AudioStreamTrack extends Track with Filterable {
  late final MediaElementAudioSourceNode sourceNode;

  AudioStreamTrack(Ambience ambience, String url) : super(ambience) {
    var element = AudioElement(url)
      ..crossOrigin = 'anonymous'
      ..loop = true;

    element.onCanPlay.first.then((_) {
      sourceNode = ambience.ctx.createMediaElementSource(element)
        ..connectNode(filterNode);
      element.play();
      // fadeIn(transition: 3);
    });
  }
}

class CrossOriginAudioTrack extends TrackBase {
  final AudioElement audio;
  Timer? _volumeTimer;

  double _volume = 0;
  double get volume => _volume;
  set volume(double volume) {
    _volume = volume;
    audio.volume = ambience.volume * volume;
  }

  CrossOriginAudioTrack(Ambience ambience, String url)
      : audio = AudioElement(url),
        super(ambience) {
    document.body!.append(audio);
    audio
      ..loop = true
      ..autoplay = true
      ..controls = true
      ..volume = 0;
  }

  @override
  void fadeVolume(num volume, {num transition = defaultTransition}) {
    _volumeTimer?.cancel();
    var start = this.volume;
    var i = 1;

    var step = 20;

    _volumeTimer = Timer.periodic(Duration(milliseconds: step), (timer) {
      var t = (i * step / 1000) / transition;

      if (t < 1) {
        this.volume = start + t * (volume - start);
      } else {
        timer.cancel();
      }

      i++;
    });
  }

  @override
  void onAmbienceUpdate() {
    volume = volume; // Multiply volume with correct ambience master volume
  }
}
