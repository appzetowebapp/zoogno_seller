import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:webview_master_app/utils/new_order_notification_util.dart';
import 'package:webview_master_app/utils/notification_service.dart';
import 'package:webview_master_app/utils/notification_payload_util.dart';

/// Background message handler for Firebase Cloud Messaging.
/// Must be a top-level function — runs when app is backgrounded or terminated.
///
/// This isolate is completely separate from the main Flutter isolate.
/// Static variables, singletons, and shared state from the main isolate are
/// NOT available here — every resource (plugin, channel) must be re-initialised.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {}

  try {
    debugPrint('📨 [BG] Background message received');
    final data = message.data;
    debugPrint('📨 [BG] Data: $data');

    final isNewOrder = NotificationService.isNewOrderNotification(data);
    debugPrint('🔔 [BG] isNewOrder: $isNewOrder');

    final title = NewOrderNotificationUtil.titleFrom(message, data);
    final body = NewOrderNotificationUtil.bodyFrom(message, data);

    if (isNewOrder) {
      debugPrint('🔔 [BG] New order — posting tray notification, then ringtone');

      // 2) Background service ringtone (looping alert via audioplayers).
      // The service also shows its own foreground-service tray banner as a fallback.
      try {
        final service = FlutterBackgroundService();
        final orderPayload = {
          'title': title,
          'body': body,
        };
        if (await service.isRunning()) {
          service.invoke('startRingtone', orderPayload);
        } else {
          await service.startService();
          // Give the service a moment to initialise before invoking.
          await Future.delayed(const Duration(milliseconds: 1500));
          service.invoke('startRingtone', orderPayload);
        }
      } catch (e) {
        debugPrint('❌ [BG] Error invoking background service: $e');
      }
      return;
    }

    final silentTitle = NotificationPayloadUtil.titleFrom(message, data);
    final silentBody = NotificationPayloadUtil.bodyFrom(message, data);
    if (silentTitle.isEmpty && silentBody.isEmpty) {
      debugPrint('ℹ️ [BG] Empty non-order message, skipping');
      return;
    }

    debugPrint('🔕 [BG] Status/other notification — silent (no ringtone)');

  } catch (e, stack) {
    debugPrint('❌ [BG] FATAL ERROR: $e');
    debugPrint('❌ [BG] STACK: $stack');
  }
}
