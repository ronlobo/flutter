// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:meta/meta.dart';

import 'package:flutter/services.dart';

import 'basic.dart';
import 'framework.dart';
import 'media_query.dart';

/// Creates an [ImageConfiguration] based on the given [BuildContext] (and
/// optionally size).
///
/// This is the object that must be passed to [BoxPainter.paint] and to
/// [ImageProvider.resolve].
ImageConfiguration createLocalImageConfiguration(BuildContext context, { Size size }) {
  return new ImageConfiguration(
    bundle: DefaultAssetBundle.of(context),
    devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
    // TODO(ianh): provide the locale
    size: size,
    platform: Platform.operatingSystem
  );
}

/// A widget that displays an image.
///
/// Several constructors are provided for the various ways that an image can be
/// specified:
///
/// * [new Image], for obtaining an image from an [ImageProvider].
/// * [new Image.network], for obtaining an image from a URL.
/// * [new Image.asset], for obtaining an image from an [AssetBundle]
///   using a key.
///
/// To automatically perform pixel-density-aware asset resolution, specify the
/// image using an [AssetImage] and make sure that a [MaterialApp], [WidgetsApp],
/// or [MediaQuery] widget exists above the [Image] widget in the widget tree.
///
/// The image is painted using [paintImage], which describes the meanings of the
/// various fields on this class in more detail.
///
/// See also:
///
///  * [Icon]
class Image extends StatefulWidget {
  /// Creates a widget that displays an image.
  ///
  /// To show an image from the network or from an asset bundle, consider using
  /// [new Image.network] and [new Image.asset] respectively.
  ///
  /// The [image] and [repeat] arguments must not be null.
  Image({
    Key key,
    @required this.image,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.alignment,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice,
    this.gaplessPlayback: false
  }) : super(key: key) {
    assert(image != null);
  }

  /// Creates a widget that displays an [ImageStream] obtained from the network.
  ///
  /// The [src], [scale], and [repeat] arguments must not be null.
  Image.network(String src, {
    Key key,
    double scale: 1.0,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.alignment,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice,
    this.gaplessPlayback: false
  }) : image = new NetworkImage(src, scale: scale),
       super(key: key);

  /// Creates a widget that displays an [ImageStream] obtained from an asset
  /// bundle. The key for the image is given by the `name` argument.
  ///
  /// If the `bundle` argument is omitted or null, then the
  /// [DefaultAssetBundle] will be used.
  ///
  /// If the `scale` argument is omitted or null, then pixel-density-aware asset
  /// resolution will be attempted.
  ///
  /// If [width] and [height] are both specified, and [scale] is not, then
  /// size-aware asset resolution will be attempted also.
  ///
  /// The [name] and [repeat] arguments must not be null.
  Image.asset(String name, {
    Key key,
    AssetBundle bundle,
    double scale,
    this.width,
    this.height,
    this.color,
    this.fit,
    this.alignment,
    this.repeat: ImageRepeat.noRepeat,
    this.centerSlice,
    this.gaplessPlayback: false
  }) : image = scale != null ? new ExactAssetImage(name, bundle: bundle, scale: scale)
                             : new AssetImage(name, bundle: bundle),
       super(key: key);

  /// The image to display.
  final ImageProvider image;

  /// If non-null, require the image to have this width.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio.
  final double width;

  /// If non-null, require the image to have this height.
  ///
  /// If null, the image will pick a size that best preserves its intrinsic
  /// aspect ratio.
  final double height;

  /// If non-null, apply this color filter to the image before painting.
  final Color color;

  /// How to inscribe the image into the space allocated during layout.
  ///
  /// The default varies based on the other fields. See the discussion at
  /// [paintImage].
  final ImageFit fit;

  /// How to align the image within its bounds.
  ///
  /// An alignment of (0.0, 0.0) aligns the image to the top-left corner of its
  /// layout bounds.  An alignment of (1.0, 0.5) aligns the image to the middle
  /// of the right edge of its layout bounds.
  final FractionalOffset alignment;

  /// How to paint any portions of the layout bounds not covered by the image.
  final ImageRepeat repeat;

  /// The center slice for a nine-patch image.
  ///
  /// The region of the image inside the center slice will be stretched both
  /// horizontally and vertically to fit the image into its destination. The
  /// region of the image above and below the center slice will be stretched
  /// only horizontally and the region of the image to the left and right of
  /// the center slice will be stretched only vertically.
  final Rect centerSlice;

  /// Whether to continue showing the old image (true), or briefly show nothing
  /// (false), when the image provider changes.
  final bool gaplessPlayback;

  @override
  _ImageState createState() => new _ImageState();

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('image: $image');
    if (width != null)
      description.add('width: $width');
    if (height != null)
      description.add('height: $height');
    if (color != null)
      description.add('color: $color');
    if (fit != null)
      description.add('fit: $fit');
    if (alignment != null)
      description.add('alignment: $alignment');
    if (repeat != ImageRepeat.noRepeat)
      description.add('repeat: $repeat');
    if (centerSlice != null)
      description.add('centerSlice: $centerSlice');
  }
}

class _ImageState extends State<Image> {
  ImageStream _imageStream;
  ImageInfo _imageInfo;

  @override
  void dependenciesChanged() {
    _resolveImage();
    super.dependenciesChanged();
  }

  @override
  void didUpdateConfig(Image oldConfig) {
    if (config.image != oldConfig.image)
      _resolveImage();
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    final ImageStream oldImageStream = _imageStream;
    _imageStream = config.image.resolve(createLocalImageConfiguration(
      context,
      size: config.width != null && config.height != null ? new Size(config.width, config.height) : null
    ));
    assert(_imageStream != null);
    if (_imageStream.key != oldImageStream?.key) {
      oldImageStream?.removeListener(_handleImageChanged);
      if (!config.gaplessPlayback)
        setState(() { _imageInfo = null; });
      _imageStream.addListener(_handleImageChanged);
    }
  }

  void _handleImageChanged(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _imageInfo = imageInfo;
    });
  }

  @override
  void dispose() {
    assert(_imageStream != null);
    _imageStream.removeListener(_handleImageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new RawImage(
      image: _imageInfo?.image,
      width: config.width,
      height: config.height,
      scale: _imageInfo?.scale ?? 1.0,
      color: config.color,
      fit: config.fit,
      alignment: config.alignment,
      repeat: config.repeat,
      centerSlice: config.centerSlice
    );
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('stream: $_imageStream');
    description.add('pixels: $_imageInfo');
  }
}
