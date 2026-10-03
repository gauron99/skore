import 'package:flutter/material.dart';

/// Gold, silver and bronze for places 1 to 3, shared by the podium and the
/// final standings.
abstract final class Medal {
  static const gold = Color(0xFFFFE082);
  static const silver = Color(0xFFDDE1E6);
  static const bronze = Color(0xFFE8C9A8);

  /// The medal for [place], or null from 4th place on.
  static Color? forPlace(int place) => switch (place) {
    1 => gold,
    2 => silver,
    3 => bronze,
    _ => null,
  };
}
