import 'dart:io';

import 'package:flutter/foundation.dart';

/// Whether the app runs in a desktop window (Windows, macOS, or Linux).
/// Android and web have no native window to manage.
bool get isDesktopPlatform =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
