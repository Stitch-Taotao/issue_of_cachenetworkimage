import 'dart:async';
import 'dart:ui' as ui show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ly_muti_image_stream_completer.dart';

class LyImageStreamCompleter extends LYMultiImageStreamCompleter {
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
  int hasNewSchedule = 0;

  bool isScheduleCheck = false;
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
