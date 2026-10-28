import 'package:flutter/material.dart';

import 'in_app_web_embed_stub.dart'
    if (dart.library.js_interop) 'in_app_web_embed_web.dart';

/// Embeds any web meeting / video stream URL directly inside the Flutter app's
/// video player box container without opening any external tabs or windows.
class InAppWebEmbed extends StatefulWidget {
  const InAppWebEmbed({super.key, required this.url});

  final String url;

  @override
  State<InAppWebEmbed> createState() => _InAppWebEmbedState();
}

class _InAppWebEmbedState extends State<InAppWebEmbed> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'iframe-embed-${widget.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return buildPlatformEmbedWidget(_viewId, widget.url);
  }
}
