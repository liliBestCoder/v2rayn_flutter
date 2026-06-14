import 'package:flutter/material.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppToast(String message, {bool success = false}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null || message.trim().isEmpty) {
    return;
  }

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 320,
        elevation: 10,
        duration: const Duration(seconds: 3),
        backgroundColor: success ? const Color(0xffe9f8ef) : const Color(0xfffff7e6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: success ? const Color(0xff95de64) : const Color(0xffffd591)),
        ),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.info_outline,
              size: 18,
              color: success ? const Color(0xff237804) : const Color(0xffd46b08),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: success ? const Color(0xff135200) : const Color(0xff873800),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
