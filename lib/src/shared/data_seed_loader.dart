
import 'package:flutter/material.dart';

class DataSeedLoader {
  static bool _loaded = false;
  static Future<void> ensureSeed(BuildContext context) async {
    if (_loaded) return;
    _loaded = true;
    // Seeds já estão em assets; nenhuma ação adicional.
  }
}
