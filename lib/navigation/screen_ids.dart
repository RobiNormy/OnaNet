import 'package:flutter/material.dart';

enum ScreenId { home, search, saved, profile }

class ScreenIds {
  const ScreenIds._();

  static const tabs = [
    ScreenId.home,
    ScreenId.search,
    ScreenId.saved,
    ScreenId.profile,
  ];

  static ScreenId fromIndex(int index) => tabs[index];
}

extension ScreenIdInfo on ScreenId {
  int get tabIndex => ScreenIds.tabs.indexOf(this);

  String get label {
    switch (this) {
      case ScreenId.home:
        return 'Home';
      case ScreenId.search:
        return 'Search';
      case ScreenId.saved:
        return 'Saved';
      case ScreenId.profile:
        return 'Profile';
    }
  }

  IconData get icon {
    switch (this) {
      case ScreenId.home:
        return Icons.home_rounded;
      case ScreenId.search:
        return Icons.explore_rounded;
      case ScreenId.saved:
        return Icons.bookmark_rounded;
      case ScreenId.profile:
        return Icons.person_rounded;
    }
  }
}
