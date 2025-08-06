// Cleaned version of FlutterLocalNotificationsPlugin.dart
// with all Linux-related code removed, zonedSchedule method restored

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:timezone/timezone.dart';

import 'initialization_settings.dart';
import 'notification_details.dart';
import 'platform_flutter_local_notifications.dart';
import 'platform_specifics/ios/enums.dart';
import 'types.dart';

class FlutterLocalNotificationsPlugin {
  factory FlutterLocalNotificationsPlugin() => _instance;

  FlutterLocalNotificationsPlugin._() {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      FlutterLocalNotificationsPlatform.instance =
          IOSFlutterLocalNotificationsPlugin();
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      FlutterLocalNotificationsPlatform.instance =
          MacOSFlutterLocalNotificationsPlugin();
    }
  }

  static final FlutterLocalNotificationsPlugin _instance =
  FlutterLocalNotificationsPlugin._();

  T? resolvePlatformSpecificImplementation<
  T extends FlutterLocalNotificationsPlatform>() {
    if (T == FlutterLocalNotificationsPlatform) {
      throw ArgumentError.value(
          T,
          'The type argument must be a concrete subclass of '
              'FlutterLocalNotificationsPlatform');
    }
    if (kIsWeb) return null;

    if (defaultTargetPlatform == TargetPlatform.android &&
        T == AndroidFlutterLocalNotificationsPlugin &&
        FlutterLocalNotificationsPlatform.instance
        is AndroidFlutterLocalNotificationsPlugin) {
      return FlutterLocalNotificationsPlatform.instance as T?;
    } else if (defaultTargetPlatform == TargetPlatform.iOS &&
        T == IOSFlutterLocalNotificationsPlugin &&
        FlutterLocalNotificationsPlatform.instance
        is IOSFlutterLocalNotificationsPlugin) {
      return FlutterLocalNotificationsPlatform.instance as T?;
    } else if (defaultTargetPlatform == TargetPlatform.macOS &&
        T == MacOSFlutterLocalNotificationsPlugin &&
        FlutterLocalNotificationsPlatform.instance
        is MacOSFlutterLocalNotificationsPlugin) {
      return FlutterLocalNotificationsPlatform.instance as T?;
    }

    return null;
  }

  Future<bool?> initialize(
      InitializationSettings initializationSettings, {
        DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
        DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
      }) async {
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (initializationSettings.android == null) {
        throw ArgumentError(
            'Android settings must be set when targeting Android platform.');
      }

      return resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.initialize(
        initializationSettings.android!,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (initializationSettings.iOS == null) {
        throw ArgumentError(
            'iOS settings must be set when targeting iOS platform.');
      }

      return await resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.initialize(
        initializationSettings.iOS!,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
      );
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      if (initializationSettings.macOS == null) {
        throw ArgumentError(
            'macOS settings must be set when targeting macOS platform.');
      }

      return await resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
          ?.initialize(
        initializationSettings.macOS!,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
    }
    return true;
  }

  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.getNotificationAppLaunchDetails();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.getNotificationAppLaunchDetails();
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return await resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
          ?.getNotificationAppLaunchDetails();
    } else {
      return await FlutterLocalNotificationsPlatform.instance
          .getNotificationAppLaunchDetails() ??
          const NotificationAppLaunchDetails(false);
    }
  }

  Future<void> show(
      int id,
      String? title,
      String? body,
      NotificationDetails? notificationDetails, {
        String? payload,
      }) async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.show(id, title, body,
          notificationDetails: notificationDetails?.android,
          payload: payload);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.show(id, title, body,
          notificationDetails: notificationDetails?.iOS, payload: payload);
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      await resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
          ?.show(id, title, body,
          notificationDetails: notificationDetails?.macOS,
          payload: payload);
    } else {
      await FlutterLocalNotificationsPlatform.instance.show(id, title, body);
    }
  }

  Future<void> cancel(int id, {String? tag}) async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.cancel(id, tag: tag);
    } else {
      await FlutterLocalNotificationsPlatform.instance.cancel(id);
    }
  }

  Future<void> cancelAll() async {
    await FlutterLocalNotificationsPlatform.instance.cancelAll();
  }

  Future<void> zonedSchedule(
      int id,
      String? title,
      String? body,
      TZDateTime scheduledDate,
      NotificationDetails notificationDetails, {
        required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
        required bool androidAllowWhileIdle,
        String? payload,
        DateTimeComponents? matchDateTimeComponents,
      }) async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()!
          .zonedSchedule(id, title, body, scheduledDate,
          notificationDetails.android,
          payload: payload,
          androidAllowWhileIdle: androidAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents);
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.zonedSchedule(id, title, body, scheduledDate,
          notificationDetails.iOS,
          uiLocalNotificationDateInterpretation:
          uiLocalNotificationDateInterpretation,
          payload: payload,
          matchDateTimeComponents: matchDateTimeComponents);
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      await resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
          ?.zonedSchedule(id, title, body, scheduledDate,
          notificationDetails.macOS,
          payload: payload,
          matchDateTimeComponents: matchDateTimeComponents);
    }
  }

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      FlutterLocalNotificationsPlatform.instance.pendingNotificationRequests();

  Future<List<ActiveNotification>> getActiveNotifications() =>
      FlutterLocalNotificationsPlatform.instance.getActiveNotifications();
}
