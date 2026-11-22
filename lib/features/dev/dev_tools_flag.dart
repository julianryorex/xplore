import 'package:flutter/foundation.dart';
import 'package:xplore/features/auth/test_login_flag.dart';

/// Whether this build exposes the Developer page: debug builds, plus builds
/// made with the test-login flag so the tools can be used on a real device,
/// where a debug build cannot be launched from the home screen.
const devToolsEnabled = kDebugMode || testLoginEnabled;
