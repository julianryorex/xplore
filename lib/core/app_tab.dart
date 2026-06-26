import 'package:flutter/material.dart';

/// Top-level destinations owned by the authenticated root shell.
///
/// Keep tab order and chrome metadata together so the navbar and shell cannot
/// drift out of sync as more destinations are added.
enum AppTab {
  home,
  map;

  String get label => switch (this) {
    AppTab.home => 'Home',
    AppTab.map => 'Map',
  };

  IconData get icon => switch (this) {
    AppTab.home => Icons.home_outlined,
    AppTab.map => Icons.map_rounded,
  };
}
