class ListItem {
  String find;
  String time;
  String url;
  String? error;
  bool receivedAMistake;

  ListItem({required this.find, required this.time, required this.url, this.error, this.receivedAMistake = false});
}
