import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hex_color/hex_color.dart';
import 'package:my_youtube_caption_scraper/main.dart';

final snackbarService = Provider<SnackBarService>((ref) => SnackBarService());

const errorTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.w400,
);

class SnackBarService with ChangeNotifier {
  
  void showError(String title, {String? error}) {
    SnackBar snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HexColor.fromHex('#DC6A6A'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: errorTextStyle,
          ),
          if (null != error)
            Text(
              error,
              style: errorTextStyle,
            ),
        ],
      ),
    );
    snackBarKey.currentState?.showSnackBar(snackBar);
  }

  void showErrorWithCloseIconOnTop(String title, {String? error, required BuildContext context}) {
    SnackBar snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HexColor.fromHex('#DC6A6A'),
      showCloseIcon: true,
      closeIconColor: Colors.white,
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 170,
        left: 10,
        right: 10,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: errorTextStyle,
          ),
          if (null != error)
            Text(
              error,
              style: errorTextStyle,
            ),
        ],
      ),
    );
    snackBarKey.currentState?.showSnackBar(snackBar);
  }

  void showWarning(String title, {String? error}) {
    SnackBar snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.yellow,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (null != error) Text(error),
        ],
      ),
    );
    snackBarKey.currentState?.showSnackBar(snackBar);
  }

  void showMessage(String title, {String? message, CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) {
    SnackBar snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.grey,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black),
          ),
          if (null != message)
            Text(
              message,
              style: const TextStyle(color: Colors.black),
            ),
        ],
      ),
    );
    snackBarKey.currentState?.showSnackBar(snackBar);
  }
}
