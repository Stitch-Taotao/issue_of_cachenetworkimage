// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'http_helper.dart';
import 'ly_image_stream_completer.dart';

typedef DecoderBufferCallback = Future<ui.Codec> Function(ui.ImmutableBuffer buffer,
    {int? cacheWidth, int? cacheHeight, bool allowUpscaling});

class LYAvatarImageProvider extends ImageProvider<LYAvatarImageProvider> {
  HttpHelper httpHelper;
  String url;
  String? cacheKey;
  double scale;
  LYAvatarImageProvider({
    required this.httpHelper,
    required this.url,
    this.cacheKey,
    this.scale = 1,
  });
  @override
  Future<LYAvatarImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<LYAvatarImageProvider>(this);
  }

  @override
  void resolveStreamForKey(
      ImageConfiguration configuration, ImageStream stream, LYAvatarImageProvider key, ImageErrorListener handleError) {
    if (stream.completer != null) {
      final ImageStreamCompleter? completer = PaintingBinding.instance?.imageCache?.putIfAbsent(
        key,
        () => stream.completer!,
        onError: handleError,
      );
      if (completer != null) {
        if (completer is LyImageStreamCompleter) {
          completer.tryRefresh();
        }
      }
      assert(identical(completer, stream.completer));
      return;
    }
    final ImageStreamCompleter? completer = PaintingBinding.instance?.imageCache?.putIfAbsent(
      key,
      () {
        return load(key, PaintingBinding.instance!.instantiateImageCodec);
      },
      onError: handleError,
    );
    if (completer != null) {
      stream.setCompleter(completer);
      if (completer is LyImageStreamCompleter) {
        completer.tryRefresh();
      }
    }
  }

  @override
  LyImageStreamCompleter load(LYAvatarImageProvider key, DecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    final wrapStreamController = wrapStream(key, chunkEvents, decode);
    return LyImageStreamCompleter(
      codecController: wrapStreamController,
      retryFn: () {
        loadAndhandleData(wrapStreamController, key, chunkEvents, decode);
      },
      hasNewFile: () async {
        return httpHelper.needUpdate(key.url, key: key.cacheKey);
      },
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>(
          'Image provider: $this \n Image key: $key',
          this,
          style: DiagnosticsTreeStyle.errorProperty,
        );
      },
    );
  }

  StreamController<ui.Codec> wrapStream(
    LYAvatarImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    StreamController<ui.Codec> controller = StreamController<ui.Codec>();

    /// first time load data
    loadAndhandleData(controller, key, chunkEvents, decode);
    return controller;
  }

  void loadAndhandleData(
    StreamController<ui.Codec> controller,
    LYAvatarImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    final stream = _loadAsync(key, chunkEvents, decode);
    stream.listen((event) {
      controller.add(event);
    }, onError: (error, stackTrace) {
      /// print for debug
      print('''
      JMT - Image Raw Data Error: --- 
        key : key,
        error : $error,
        stackTrace:$stackTrace
      ''');
      throw error;
    });
  }

  final random = Random();
  Stream<ui.Codec> _loadAsync(
    LYAvatarImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) async* {
    final data = await httpHelper.getUint8List(key.url);
    // mock mutiple image data ;
    for (var i = 0; i < 3; i++) {
      final int delay = random.nextInt(3500);
      await Future.delayed(Duration(milliseconds: delay));
      yield await decode(data);
    }
  }
}
