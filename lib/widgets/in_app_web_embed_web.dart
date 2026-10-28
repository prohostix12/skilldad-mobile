import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

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
  final targetUrl = cleanMeetingUrl(url);
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = targetUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'camera; microphone; display-capture; autoplay; clipboard-write; encrypted-media; fullscreen'
      ..allowFullscreen = true;
    return iframe;
  });
  return HtmlElementView(viewType: viewId);
}
