import 'dart:async';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:my_youtube_caption_scraper/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:window_manager/window_manager.dart';

class WebView extends ConsumerStatefulWidget {
  const WebView({super.key, required this.talker});

  final Talker talker;

  @override
  ConsumerState<WebView> createState() => _WebView();
}

class _WebView extends ConsumerState<WebView> {
  final _controller = WebviewController();
  final _textController = TextEditingController();
  final List<StreamSubscription> _subscriptions = [];
  bool _isWebviewSuspended = false;

  bool isLoading = false;

  @override
  void initState() {
    initPlatformState();
    super.initState();
  }

  Future<void> doSomething() async {
    setState(() {
      isLoading = true;
    });

    try {
      widget.talker.info('Старт скрипта');
      // 1. Запустить автоскролл с автоматическим определением конца
      final startScrollScript = '''
      window._scrollEnded = false;
      window._scrollTries = 0;
      window._scrollInterval = setInterval(function() {
        var before = window.scrollY;
        window.scrollBy({top: 1000, left: 0, behavior: 'smooth'});
        setTimeout(function() {
          if (window.scrollY === before) {
            window._scrollTries += 1;
          } else {
            window._scrollTries = 0;
          }
          if (window._scrollTries >= 3) {
            clearInterval(window._scrollInterval);
            window._scrollEnded = true;
          }
        }, 500);
      }, 1000);
      'scroll started';
      ''';
      final scrollResult = await _controller.executeScript(startScrollScript);

      if (scrollResult == null || !scrollResult.contains('scroll started')) {
        widget.talker.info('Ошибка запуска скролла');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 2. Ждать окончания скролла (опрашиваем флаг в JS)
      bool ended = false;
      while (!ended) {
        await Future.delayed(const Duration(seconds: 1));
        final res = await _controller.executeScript('window._scrollEnded ? "ended" : "scrolling";');
        if (res == 'ended') ended = true;
      }

      // 3. Собрать ссылки и заголовки
      final urlsScript = '''
      var links = document.querySelectorAll('a#video-title-link');
      var result = '';
      links.forEach(function(v) {
        result += v.title + '\\t' + v.href + '\\n';
      });
      result;
      ''';
      final urls = await _controller.executeScript(urlsScript);

      if (urls != null && urls.trim().isNotEmpty) {
        widget.talker.info('Ссылки собраны, создаём Excel...');
        await createExcelFromString(urls, 'test');
      } else {
        widget.talker.info('Не удалось собрать ссылки');
      }
    } catch (e, st) {
      widget.talker.handle(e, st);
    } finally {
      setState(() {
        isLoading = false;
      });
      widget.talker.info('Конец скрипта');
    }
  }

  Future<Directory?> pickDirectory() async {
    final dir = DirectoryPicker()..title = 'Выберите папку для сохранения файла';
    return dir.getDirectory();
  }

  Future<void> createExcelFromString(String input, String fileName) async {
    List<String> rows = input.split('\n');
    List<List<String>> data = rows.map((row) => row.split('\t')).toList();

    var excel = Excel.createExcel();
    String sheetName = "Sheet1";
    Sheet sheet = excel[sheetName];

    for (var row in data) {
      List<CellValue?> cellRow = row.map((cell) {
        final numValue = int.tryParse(cell);
        if (numValue != null) {
          return IntCellValue(numValue);
        }
        return TextCellValue(cell);
      }).toList();
      sheet.appendRow(cellRow);
    }

    List<int>? bytes = excel.save();
    if (bytes == null) return;

    Directory? directory = await pickDirectory();

    directory ??= await getApplicationDocumentsDirectory();

    String path = "${directory.path}/$fileName.xlsx";
    File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    widget.talker.info('Файл создан $path');
  }

  Future<void> initPlatformState() async {
    try {
      await _controller.initialize();
      _subscriptions.add(_controller.url.listen((url) {
        _textController.text = url;
      }));

      _subscriptions.add(_controller.containsFullScreenElementChanged.listen((flag) {
        debugPrint('Contains fullscreen element: $flag');
        windowManager.setFullScreen(flag);
      }));

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl('https://www.youtube.com');

      if (!mounted) return;
      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Code: ${e.code}'),
                  Text('Message: ${e.message}'),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Continue'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                )
              ],
            ),
          );
        },
      );
    }
  }

  Widget compositeView() {
    if (!_controller.value.isInitialized) {
      return const Text(
        'Not Initialized',
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 0,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'URL',
                        contentPadding: EdgeInsets.all(10.0),
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      controller: _textController,
                      onSubmitted: (val) {
                        _controller.loadUrl(val);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    splashRadius: 20,
                    onPressed: () {
                      _controller.reload();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.developer_mode),
                    tooltip: 'Open DevTools',
                    splashRadius: 20,
                    onPressed: () {
                      _controller.openDevTools();
                    },
                  )
                ],
              ),
            ),
            Expanded(
              child: Card(
                color: Colors.transparent,
                elevation: 0,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: Stack(
                  children: [
                    Webview(
                      _controller,
                      permissionRequested: _onPermissionRequested,
                    ),
                    StreamBuilder<LoadingState>(
                      stream: _controller.loadingState,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data == LoadingState.loading) {
                          return LinearProgressIndicator();
                        } else {
                          return SizedBox();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: _isWebviewSuspended ? 'Resume webview' : 'Suspend webview',
        onPressed: () async {
          if (_isWebviewSuspended) {
            await _controller.resume();
          } else {
            await _controller.suspend();
          }
          setState(() {
            _isWebviewSuspended = !_isWebviewSuspended;
          });
        },
        child: Icon(_isWebviewSuspended ? Icons.play_arrow : Icons.pause),
      ),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (!_controller.value.isInitialized) return;

            Navigator.pop(context);
          },
          icon: Icon(
            Symbols.arrow_back,
          ),
        ),
        title: StreamBuilder<String>(
          stream: _controller.title,
          builder: (context, snapshot) {
            return Text(snapshot.hasData ? snapshot.data! : 'WebView (Windows) Example');
          },
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await doSomething();
            },
            icon: isLoading
                ? CircularProgressIndicator(
                    color: Colors.white,
                  )
                : Icon(Symbols.script),
          ),
        ],
      ),
      body: Center(
        child: compositeView(),
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  @override
  void dispose() async {
    for (var s in _subscriptions) {
      s.cancel();
    }
    await _controller.executeScript("clearInterval(window._scrollInterval);");
    _controller.suspend();
    _controller.dispose();
    super.dispose();
  }
}
