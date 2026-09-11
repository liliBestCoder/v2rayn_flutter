import 'package:flutter/material.dart';
import 'theme/luxwap_theme.dart';

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
        elevation: 2,
        duration: const Duration(seconds: 3),
        backgroundColor: success
            ? LuxwapColors.stateSuccessSurface
            : LuxwapColors.stateErrorSurface,
        shape: RoundedRectangleBorder(
          borderRadius: LuxwapRadius.rMd,
          side: BorderSide(
            color: success
                ? LuxwapColors.stateSuccess.withOpacity(0.3)
                : LuxwapColors.stateError.withOpacity(0.3),
          ),
        ),
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: success
                  ? LuxwapColors.stateSuccess
                  : LuxwapColors.stateError,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: success
                      ? LuxwapColors.stateSuccess
                      : LuxwapColors.stateError,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
