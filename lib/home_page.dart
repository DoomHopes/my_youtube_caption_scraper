import 'package:flutter/material.dart';
import 'package:youtube_caption_scraper/youtube_caption_scraper.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isLoading = false;

  TextEditingController searchEditingController = TextEditingController();
  TextEditingController wordEditingController = TextEditingController();
  List<SubtitleLine> subtitles = [];
  List<String> finds = [];
  List<String> time = [];

  String _formatDuration(Duration duration) {
    return '${duration.inHours}:'
        '${duration.inMinutes.remainder(60)}:'
        '${duration.inSeconds.remainder(60)}:'
        '${duration.inMilliseconds.remainder(60)}';
  }

  Future<void> getSubtitles(String videoUrl) async {
    final captionScraper = YouTubeCaptionScraper();
    final captionTracks = await captionScraper.getCaptionTracks(videoUrl);

    subtitles = await captionScraper.getSubtitles(captionTracks[0]);

    findByTheWord(wordEditingController.text);
  }

  void findByTheWord(String word) {
    finds = [];
    if (subtitles.isEmpty) {
      return;
    }

    for (var item in subtitles) {
      if (item.text.contains(word)) {
        time.add(_formatDuration(item.start));
        finds.add(item.text);
      }
    }

    setState(() {});
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
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: searchEditingController,
                      decoration: InputDecoration(
                        hintText: 'url',
                      ),
                    ),
                    TextField(
                      controller: wordEditingController,
                      decoration: InputDecoration(
                        hintText: 'word',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            isLoading = true;
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
                        child: Icon(Icons.search),
                      ),
                    ),
                    if (finds.isEmpty) Text('nothing found'),
                    Row(
                      children: [
                        if (finds.isNotEmpty)
                          for (var item in time) Text(item),
                        if (finds.isNotEmpty)
                          for (var item in finds)
                            Padding(
                              padding: const EdgeInsets.only(left: 20),
                              child: Text(item),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
