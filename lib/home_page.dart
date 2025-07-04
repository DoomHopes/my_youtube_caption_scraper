// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:my_youtube_caption_scraper/list_item.dart';
import 'package:youtube_caption_scraper/youtube_caption_scraper.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isLoading = false;
  final captionScraper = YouTubeCaptionScraper();

  TextEditingController searchEditingController = TextEditingController();
  TextEditingController wordEditingController = TextEditingController();
  List<ListItem> finds = [];
  int errors = 0;
  bool isStopped = false;

  String _formatDuration(Duration duration) {
    return '${duration.inHours}:'
        '${duration.inMinutes.remainder(60)}:'
        '${duration.inSeconds.remainder(60)}:'
        '${duration.inMilliseconds.remainder(60)}';
  }

  Future<void> getSubtitles(String videoUrl, {bool append = false}) async {
    if (isStopped) {
      return;
    }

    try {
      List<SubtitleLine> subtitles = [];

      final captionTracks = await captionScraper.getCaptionTracks(videoUrl);

      subtitles = await captionScraper.getSubtitles(captionTracks[0]);

      findByTheWord(wordEditingController.text, videoUrl, subtitles, append: append);
    } catch (e) {
      setState(() {
        errors++;
      });
      var snackBar = SnackBar(
        content: Text(e.toString()),
        duration: Duration(seconds: 1),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  void findByTheWord(String word, String url, List<SubtitleLine> subtitles, {bool append = false}) {
    if (!append) {
      finds = [];
    }

    if (subtitles.isEmpty) {
      return;
    }

    for (int index = 0; index < subtitles.length; index++) {
      if (subtitles[index].text.contains(word)) {
        ListItem listitem = ListItem(
          time: _formatDuration(subtitles[index].start),
          find: (index + 1) > subtitles.length
              ? subtitles[index].text
              : '${subtitles[index].text} ${subtitles[index + 1].text} ${subtitles[index + 2].text} ${subtitles[index + 3].text}',
          url: url,
        );

        setState(() {
          finds.add(listitem);
        });
      }
    }
  }

  void readExcelFile() async {
    setState(() {
      errors = 0;
      isLoading = true;
      isStopped = false;
    });
    FilePickerResult? pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );

    if (pickedFile != null && pickedFile.files.first.path != null) {
      File file = File(pickedFile.files.first.path!);

      var bytes = file.readAsBytesSync();

      var excel = Excel.decodeBytes(bytes);
      for (var table in excel.tables.keys) {
        for (var row in excel.tables[table]!.rows) {
          if (row.last!.value != null) {
            await getSubtitles(row.last!.value.toString(), append: true);
          }
        }
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  void stop() {
    setState(() {
      isStopped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: searchEditingController,
              readOnly: isLoading ? true : false,
              decoration: InputDecoration(
                hintText: 'url',
              ),
            ),
            TextField(
              controller: wordEditingController,
              readOnly: isLoading ? true : false,
              decoration: InputDecoration(
                hintText: 'word',
              ),
            ),
            isLoading
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        stop();
                      },
                      child: Icon(Symbols.stop),
                    ),
                  )
                : const SizedBox(),
            isLoading
                ? LinearProgressIndicator()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              isLoading = true;
                              isStopped = false;
                            });

                            if (searchEditingController.text.isEmpty) {
                              setState(() {
                                isLoading = false;
                              });
                              return;
                            }

                            String url = searchEditingController.text;

                            await getSubtitles(url).then(
                              (value) {
                                setState(() {
                                  isLoading = false;
                                });
                              },
                            );
                          },
                          child: Icon(Symbols.search),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (wordEditingController.text.isEmpty) {
                              var snackBar = SnackBar(
                                content: Text('Write a word for a search'),
                                duration: Duration(seconds: 1),
                              );

                              ScaffoldMessenger.of(context).showSnackBar(snackBar);
                              return;
                            }

                            readExcelFile();
                          },
                          child: Icon(Symbols.file_copy),
                        ),
                      ),
                    ],
                  ),
            if (errors > 0) Text('Errors $errors'),
            Expanded(
              child: ListView.builder(
                itemCount: finds.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: finds[index].receivedAMistake
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Error: ${finds[index].error}'),
                                GestureDetector(
                                  onTap: () async {
                                    await Clipboard.setData(ClipboardData(text: finds[index].url));
                                    var snackBar = SnackBar(
                                      content: Text('copied to clipboard'),
                                      duration: Duration(milliseconds: 500),
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                  },
                                  child: Text(finds[index].url),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Time: ${finds[index].time}'),
                                Text('Text: ${finds[index].find}'),
                                Row(
                                  children: [
                                    Text('URL: '),
                                    GestureDetector(
                                      onTap: () async {
                                        await Clipboard.setData(ClipboardData(text: finds[index].url));
                                        var snackBar = SnackBar(
                                          content: Text('copied to clipboard'),
                                          duration: Duration(milliseconds: 500),
                                        );

                                        ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                      },
                                      child: Text(finds[index].url),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
