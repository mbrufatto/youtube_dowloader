import 'dart:async';
import 'dart:io';

import 'package:console/console.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Initialize the YoutubeExplode instance.
final yt = YoutubeExplode();

Future<void> main() async {
  print('Aguarde...');
  stdout.writeln('Informe a url do vídeo ou da playlist que deseja a musica: ');
  var url = stdin.readLineSync()!.trim();

  stdout
      .writeln('Informe o local que deseja salvar a música sem a barra fina: ');
  var directory = stdin.readLineSync()!.trim();

  stdout.writeln('Esse link é de uma playlist? (S ou N)');
  var isPlaylist = stdin.readLineSync()!.trim();

  if (directory.isEmpty) {
    print('Você deve informar um local para que a música seja salva.');
    return;
  }
  // Save the video to the download directory.
  Directory(directory).createSync();

  // Download the video.
  if (isPlaylist.toLowerCase() == 's') {
    await downloadPlaylist(url, directory);
  } else {
    await download(url, directory);
  }

  yt.close();
  exit(0);
}

Future<void> download(String id, String directory) async {
  // Get video metadata.
  var video = await yt.videos.get(id);

  // Get the video manifest.
  var manifest = await yt.videos.streamsClient.getManifest(id);
  var streams = manifest.audioOnly;

  // Get the audio track with the highest bitrate.
  var audio = streams.first;
  var audioStream = yt.videos.streamsClient.get(audio);

  // Compose the file name removing the unallowed characters in windows.
  var fileName = '${video.title}.${audio.container.name}'
      .replaceAll(r'\', '')
      .replaceAll('/', '')
      .replaceAll('*', '')
      .replaceAll('?', '')
      .replaceAll('"', '')
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('|', '');
  var file = File('$directory/$fileName');

  // Delete the file if exists.
  if (file.existsSync()) {
    file.deleteSync();
  }

  // Open the file in writeAppend.
  var output = file.openWrite(mode: FileMode.writeOnlyAppend);

  // Track the file download status.
  var len = audio.size.totalBytes;
  var count = 0;

  // Create the message and set the cursor position.
  var msg = 'Downloading ${video.title}.${audio.container.name}';
  stdout.writeln(msg);

  // Listen for data received.
  var progressBar = ProgressBar();
  await for (final data in audioStream) {
    // Keep track of the current downloaded data.
    count += data.length;

    // Calculate the current progress.
    var progress = ((count / len) * 100).ceil();

    // Update the progressbar.
    progressBar.update(progress);

    // Write to file.
    output.add(data);
  }
  await output.close();
}

Future<void> downloadPlaylist(String id, String directory) async {
// Get playlist metadata.
  var playlist = await yt.playlists.get(id);

  await for (var video in yt.playlists.getVideos(playlist.id)) {
    try {
      await download(video.id.toString(), directory);
    } on VideoUnplayableException catch (e) {
      print('Erro: $e');
      print('URL do vídeo: ${video.url}');
      print('Título: ${video.title}');
      continue;
    }
  }
}
