import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

String cleanMeetingUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.contains('meet.skilldad.com') || trimmed.contains('jitsi') || trimmed.contains('8x8.vc')) {
    final jitsiFlags = [
      'config.prejoinPageEnabled=false',
      'config.enableWelcomePage=false',
      'config.enableClosePage=false',
      'config.deepLinking.enabled=false',
      'config.disableDeepLinking=true',
      'config.requireDisplayName=false',
      'config.readOnlyName=true',
      'config.disableInviteFunctions=true',
      'interfaceConfig.SHOW_JITSI_WATERMARK=false',
      'interfaceConfig.SHOW_WATERMARK_FOR_GUESTS=false',
      'interfaceConfig.SHOW_BRAND_WATERMARK=false',
      'interfaceConfig.SHOW_POWERED_BY=false',
      'interfaceConfig.SHOW_PROMOTIONAL_CLOSE_PAGE=false',
      'interfaceConfig.DISPLAY_WELCOME_PAGE_CONTENT=false',
      'interfaceConfig.DISPLAY_WELCOME_PAGE_TOOLBAR_ADDITIONAL_CONTENT=false',
      'interfaceConfig.GENERATE_ROOM_NAMES_ON_WELCOME_PAGE=false',
      'interfaceConfig.MOBILE_APP_PROMO=false',
      'interfaceConfig.HIDE_DEEP_LINKING_LOGO=true',
      'interfaceConfig.APP_NAME="SkillDad"',
      'interfaceConfig.PROVIDER_NAME="SkillDad"',
    ].join('&');
    if (!trimmed.contains('#')) {
      return '$trimmed#$jitsiFlags';
    } else if (!trimmed.contains('config.prejoinPageEnabled')) {
      return '$trimmed&$jitsiFlags';
    }
  }
  return trimmed;
}

Widget buildPlatformEmbedWidget(String viewId, String url) {
  return NativeEmbedWidget(url: url);
}

class NativeEmbedWidget extends StatefulWidget {
  const NativeEmbedWidget({super.key, required this.url});

  final String url;

  @override
  State<NativeEmbedWidget> createState() => _NativeEmbedWidgetState();
}

class _NativeEmbedWidgetState extends State<NativeEmbedWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final targetUrl = cleanMeetingUrl(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.contains('close') ||
                url.contains('thank') ||
                url.contains('static/close') ||
                url.contains('close3.html') ||
                url.contains('left')) {
              if (mounted) {
                Navigator.of(context).maybePop();
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            final lowerUrl = url.toLowerCase();
            if (lowerUrl.contains('close') || lowerUrl.contains('thank') || lowerUrl.contains('static/close')) {
              if (mounted) {
                Navigator.of(context).maybePop();
              }
            }
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            final lowerUrl = url.toLowerCase();
            if (lowerUrl.contains('close') || lowerUrl.contains('thank') || lowerUrl.contains('static/close')) {
              if (mounted) {
                Navigator.of(context).maybePop();
              }
              return;
            }
            _controller.runJavaScript('''
              (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                  .watermark, .jitsi-icon, .header-logo, .welcome-page, .welcome-card, .welcome,
                  .watermarks, .brand-watermark, .jitsi-watermark, .powered-by,
                  .thanks-page, .promotional-close-page, .close-page,
                  a[href*="jitsi"], img[src*="jitsi"], img[src*="watermark"],
                  .css-169z32o-watermark, .css-1y5c6y8-watermark,
                  #welcome-page-additional-content, .welcome-page-settings {
                    display: none !important;
                    visibility: hidden !important;
                    opacity: 0 !important;
                  }
                `;
                document.head.appendChild(style);

                var joinBtn = document.querySelector('button[aria-label="Join meeting"], button.join-button, .prejoin-btn, button[data-testid="prejoin.joinmeeting"]');
                if (joinBtn) joinBtn.click();
              })();
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
