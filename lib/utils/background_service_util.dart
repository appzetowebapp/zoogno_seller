import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:webview_master_app/config/app_config.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isRinging = false;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // Set initial notification content once
    service.setForegroundNotificationInfo(
      title: "zoogno seller   Service Active",
      content: "Waiting for new orders...",
    );

    // Listen for ringtone start (optional title/body from FCM payload)
    service.on('startRingtone').listen((event) async {
      final Map<String, dynamic> payload = switch (event) {
        null => <String, dynamic>{},
        final Map<String, dynamic> data => data,
        _ => <String, dynamic>{},
      };
      final orderTitle =
          payload['title']?.toString() ?? '🔥 NEW ORDER ARRIVED!';
      final orderBody = payload['body']?.toString() ??
          'Tap to view and accept the order';

      if (!isRinging) {
        debugPrint('🔔 Background Service: Starting Ringtone');
        isRinging = true;
        await audioPlayer.setReleaseMode(ReleaseMode.loop);
        await audioPlayer.play(AssetSource('audio/iphone-remix-68028.mp3'));
      }

      // Always refresh the foreground-service notification (visible in tray)
      service.setForegroundNotificationInfo(
        title: orderTitle,
        content: orderBody,
      );
    });

    // Listen for ringtone stop
    service.on('stopRingtone').listen((event) async {
      if (isRinging) {
        debugPrint('🔕 Background Service: Stopping Ringtone');
        isRinging = false;
        await audioPlayer.stop();
        
        // Reset notification info
        service.setForegroundNotificationInfo(
          title: "zoogno seller   Service Active",
          content: "Waiting for new orders...",
        );
      }
    });
  }

  service.on('stopService').listen((event) async {
    await audioPlayer.dispose();
    service.stopSelf();
  });

  // Location tracking logic (remains same)
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        
        debugPrint('📍 Background Location: ${position.latitude}, ${position.longitude}');
        
        // Broadcast location update
        service.invoke('update', {
          "latitude": position.latitude,
          "longitude": position.longitude,
        });
      } catch (e) {
        debugPrint('❌ Background Location Error: $e');
      }
    }
  });
}

@pragma('vm:entry-point')
class BackgroundServiceUtil {
  static const int notificationId = 888;

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConfig.silentChannelId,
        initialNotificationTitle: 'Restaurant service active',
        initialNotificationContent: 'Waiting for new orders...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  }

  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}
