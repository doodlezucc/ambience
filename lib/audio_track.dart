import 'dart:html';
import 'dart:typed_data';
import 'dart:web_audio';

import 'package:ambience/ambience.dart';

final Map<String, AudioBuffer> resources = {};

class AudioTrack extends Track {
  final AudioBufferSourceNode sourceNode;

  AudioTrack(Ambience ambience, String url)
      : sourceNode = AudioBufferSourceNode(ambience.ctx),
        super(ambience) {
    sourceNode.connectNode(trackGain);

    // Load URL as audio buffer
    getBuffer(url).then((buffer) => sourceNode.buffer = buffer);
  }

  Future<AudioBuffer> getBuffer(String url) async {
    if (resources[url] != null) return resources[url]!;

    var req = await HttpRequest.request(url);
    var response = req.response;

    if (response is! Blob) {
      throw 'Requested URL is of type ${response.runtimeType} instead of Blob!';
    }

    var reader = FileReader();
    reader.readAsArrayBuffer(response);
    var loadEndEvent = await reader.onLoadEnd.first;

    print('Loaded ${loadEndEvent.total} bytes');
    print(reader.result.runtimeType);

    var byteBuffer = (reader.result as ByteBuffer);

    var audioBuffer = await ambience.ctx.decodeAudioData(byteBuffer);
    resources[url] = audioBuffer;
    return audioBuffer;
  }
}
