import 'dart:async';
import 'dart:ui' as ui show Codec;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LyImageStreamCompleter extends MultiImageStreamCompleter {
  LyImageStreamCompleter({
    required this.codecController,
    required this.retryFn,
    required this.hasNewFile,
    required double scale,
    Stream<ImageChunkEvent>? chunkEvents,
    InformationCollector? informationCollector,
  }) : super(
          codec: codecController.stream,
          scale: scale,
          chunkEvents: chunkEvents,
          informationCollector: informationCollector,
        );
  StreamController<ui.Codec> codecController;

  void Function() retryFn;
  Future<bool> Function() hasNewFile;

  tryRefresh() async {
    await doTry();
  }

  doTry() async {
    final hasNew = await hasNewFile();
    if (hasNew) {
      retryFn();
    }
  }
}
