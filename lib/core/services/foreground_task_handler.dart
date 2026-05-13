import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

class ForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // You can handle background services here.
    // E.g. start location tracking or maintain socket connection.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send data to the main isolate.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Clean up resources.
  }


  @override
  void onNotificationPressed() {
    // Called when the notification itself on the Android platform is pressed.
    FlutterForegroundTask.launchApp("/");
  }
}

class ForegroundTaskService {
  static Future<void> initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gtx_app_foreground_service',
        channelName: 'GTX Background Service',
        channelDescription: 'This notification appears when the background service is running.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'GTX App is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  }

  static Future<void> stopForegroundTask() async {
    await FlutterForegroundTask.stopService();
  }
}
