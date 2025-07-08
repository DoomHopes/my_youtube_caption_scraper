// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:my_youtube_caption_scraper/home/list_item.dart';
import 'package:my_youtube_caption_scraper/home/web_view.dart';
import 'package:my_youtube_caption_scraper/service/snackbar_service.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:youtube_caption_scraper/youtube_caption_scraper.dart';

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  bool isLoading = false;
  bool isStopped = false;
  int errors = 0;

  late final Talker talker;

  final captionScraper = YouTubeCaptionScraper();
  final searchEditingController = TextEditingController();
  final wordEditingController = TextEditingController();
  List<ListItem> finds = [];
  List<String> errorsList = [];

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final ms = (duration.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds.$ms';
  }

  Future<void> getSubtitles(String videoUrl, {bool append = false}) async {
    if (isStopped) return;
    try {
      final captionTracks = await captionScraper.getCaptionTracks(videoUrl);
      final subtitles = await captionScraper.getSubtitles(captionTracks.first);
      _findByTheWord(wordEditingController.text, videoUrl, subtitles, append: append);
    } catch (e, st) {
      setState(() {
        errors++;
        errorsList.add(e.toString());
      });
      talker.handle(e, st);
    }
  }

  void _findByTheWord(String word, String url, List<SubtitleLine> subtitles, {bool append = false}) {
    if (!append) finds = [];
    if (subtitles.isEmpty) return;

    final newFinds = <ListItem>[];
    for (int index = 0; index < subtitles.length; index++) {
      if (subtitles[index].text.contains(word)) {
        final nextTexts = List.generate(
          3,
          (i) => (index + i + 1) < subtitles.length ? subtitles[index + i + 1].text : '',
        ).join(' ');

        newFinds.add(
          ListItem(
            time: _formatDuration(subtitles[index].start),
            find: '${subtitles[index].text} $nextTexts',
            url: url,
          ),
        );
      }
    }
    setState(() {
      finds.addAll(newFinds);
    });
  }

  Future<void> readExcelFile() async {
    setState(() {
      errors = 0;
      isLoading = true;
      isStopped = false;
    });
    try {
      final pickedFile = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );
      if (pickedFile?.files.first.path != null) {
        final file = File(pickedFile!.files.first.path!);
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        for (var table in excel.tables.values) {
          for (var row in table.rows) {
            final url = row.last?.value?.toString();
            if (url != null) {
              await getSubtitles(url, append: true);
            }
          }
        }
      }
      if (mounted) setState(() => isLoading = false);
    } catch (e, st) {
      talker.handle(e, st);
    }
  }

  void stop() {
    setState(() {
      isStopped = true;
    });
  }

  @override
  void initState() {
    talker = TalkerFlutter.init();
    super.initState();
  }

  @override
  void dispose() {
    searchEditingController.dispose();
    wordEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => TalkerScreen(talker: talker),
              ));
            },
            icon: Icon(Symbols.logo_dev),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildTextField(searchEditingController, 'url'),
            _buildTextField(wordEditingController, 'word'),
            if (isLoading) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: stop,
                  child: const Icon(Symbols.stop),
                ),
              ),
              const LinearProgressIndicator(),
            ] else
              _buildActionButtons(),
            if (errors > 0) Text('Errors $errors'),
            Expanded(child: _buildFindsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      readOnly: isLoading,
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => WebView(talker: talker),
                ),
              );
            },
            child: const Icon(Symbols.web),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              setState(() {
                isLoading = true;
                isStopped = false;
              });
              if (searchEditingController.text.isEmpty) {
                setState(() => isLoading = false);
                return;
              }
              await getSubtitles(searchEditingController.text);
              if (mounted) setState(() => isLoading = false);
            },
            child: const Icon(Symbols.search),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              if (wordEditingController.text.isEmpty) {
                ref.read(snackbarService).showMessage('Write a word for a search');

                return;
              }
              readExcelFile();
            },
            child: const Icon(Symbols.file_copy),
          ),
        ),
      ],
    );
  }

  Widget _buildFindsList() {
    return ListView.builder(
      itemCount: finds.length,
      itemBuilder: (context, index) {
        final item = finds[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: item.receivedAMistake
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Error: ${item.error}'),
                      GestureDetector(
                        onTap: () => _copyToClipboard(item.url),
                        child: Text(item.url),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Time: ${item.time}'),
                      Text('Text: ${item.find}'),
                      Row(
                        children: [
                          const Text('URL: '),
                          GestureDetector(
                            onTap: () => _copyToClipboard(item.url),
                            child: Text(item.url),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ref.read(snackbarService).showMessage('copied to clipboard');
    }
  }
}
