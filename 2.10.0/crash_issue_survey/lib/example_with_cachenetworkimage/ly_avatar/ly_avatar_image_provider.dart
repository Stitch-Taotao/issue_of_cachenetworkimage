import 'dart:async';
// import 'dart:ui' as ui show Codec;
import 'dart:ui' as ui show Codec, ImmutableBuffer;
import 'package:cached_network_image_platform_interface'
    '/cached_network_image_platform_interface.dart' show ImageRenderMethodForWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image/src/image_provider/_image_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'ly_avatar_manager.dart';
import 'ly_image_stream_completer.dart';

typedef DecoderBufferCallback = Future<ui.Codec> Function(ui.ImmutableBuffer buffer,
    {int? cacheWidth, int? cacheHeight, bool allowUpscaling});

class LYAvatarImageProvider extends CachedNetworkImageProvider {
  const LYAvatarImageProvider(
    String url, {
    int? maxHeight,
    int? maxWidth,
    double scale = 1.0,
    void Function()? errorListener,
    Map<String, String>? headers,
    TheCacheManager? cacheManager,
    String? cacheKey,
  })  : _cacheManager = cacheManager,
        super(
          url,
          maxHeight: maxHeight,
          maxWidth: maxWidth,
          scale: scale,
          errorListener: errorListener,
          headers: headers,
          cacheManager: cacheManager,
          cacheKey: cacheKey,
        );

  final TheCacheManager? _cacheManager;
  @override
  TheCacheManager? get cacheManager => _cacheManager;
  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream, CachedNetworkImageProvider key,
      ImageErrorListener handleError) {
    // This is an unusual edge case where someone has told us that they found
    // the image we want before getting to this method. We should avoid calling
    // load again, but still update the image cache with LRU information.
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
    bool isInital = false;
    final ImageStreamCompleter? completer = PaintingBinding.instance?.imageCache?.putIfAbsent(
      key,
      () {
        isInital = true;
        return load(key, PaintingBinding.instance!.instantiateImageCodec);
      },
      onError: handleError,
    );
    if (completer != null) {
      stream.setCompleter(completer);
      if (completer is LyImageStreamCompleter && !isInital) {
        completer.tryRefresh();
      }
    }
  }

  @override
  LyImageStreamCompleter load(CachedNetworkImageProvider key, DecoderCallback decode) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    final wrapStreamController = wrapStream(key, chunkEvents, decode);
    return LyImageStreamCompleter(
      codecController: wrapStreamController,
      retryFn: () {
        loadAndhandleData(wrapStreamController, key, chunkEvents, decode);
      },
      hasNewFile: () async {
        return cacheManager!.hasNewFile(key.url, key: key.cacheKey);
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
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    StreamController<ui.Codec> controller = StreamController<ui.Codec>();

    /// 第一次创建，必定请求
    loadAndhandleData(controller, key, chunkEvents, decode);
    return controller;
  }

  void loadAndhandleData(
    StreamController<ui.Codec> controller,
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    final stream = _loadAsync(key, chunkEvents, decode);
    stream.listen((event) {
      controller.add(event);
    }, onError: (error, stackTrace) {
      /// 任何情况，拿不到数据，不应该刷新，比如临时文件被删除的情况
      /// 暂时拦截处理，更符合我们的场景
      print('''
      JMT - Image Raw Data Error: --- 
        key : key,
        error : $error,
        stackTrace:$stackTrace
      ''');
      throw error;
    });
  }

  Stream<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
  ) {
    assert(key == this);
    return ImageLoader().loadAsync(
      url,
      cacheKey,
      chunkEvents,
      decode,
      cacheManager ?? DefaultCacheManager(),
      maxHeight,
      maxWidth,
      headers,
      errorListener,
      imageRenderMethodForWeb,
      () {
        PaintingBinding.instance?.imageCache?.evict(key);
      },
    );
  }

  Stream<ui.Codec> loadAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    Function()? errorListener,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
    Function() evictImage,
  ) async* {
    try {
      assert(
          cacheManager is ImageCacheManager || (maxWidth == null && maxHeight == null),
          'To resize the image with a CacheManager the '
          'CacheManager needs to be an ImageCacheManager. maxWidth and '
          'maxHeight will be ignored when a normal CacheManager is used.');

      var stream = cacheManager is ImageCacheManager
          ? cacheManager.getImageFile(url,
              maxHeight: maxHeight, maxWidth: maxWidth, withProgress: true, headers: headers, key: cacheKey)
          : cacheManager.getFileStream(url, withProgress: true, headers: headers, key: cacheKey);

      await for (var result in stream) {
        if (result is DownloadProgress) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: result.downloaded,
            expectedTotalBytes: result.totalSize,
          ));
        }
        if (result is FileInfo) {
          var file = result.file;
          if (file.existsSync()) {
            var bytes = file.readAsBytesSync();
            var decoded = await decode(bytes);
            yield decoded;
          }
        }
      }
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });

      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }
}
