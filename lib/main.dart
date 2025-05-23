import 'package:flutter/material.dart';
import 'package:my_youtube_caption_scraper/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Youtube Caption Scraper',
      theme: ThemeData.dark(),
      home: const MyHomePage(title: 'My Youtube Caption Scraper'),
    );
  }
}
