import 'package:flutter/material.dart';

import 'http_helper.dart';
import 'ly_avatar_image_provider.dart';

class LYAvatarCacheImage extends StatelessWidget {
  LYAvatarCacheImage({
    Key? key,
    required String imageUrl,
    this.fit=BoxFit.cover,
    String? cacheKey,
  })  : _image =
            LYAvatarImageProvider(url:imageUrl, cacheKey: cacheKey,httpHelper: JmtHeepHepler()),
        super(key: key);
  final ImageProvider _image;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    return  Image(
      image: _image,
      gaplessPlayback: true,
      fit: fit,
    );
  }
}
