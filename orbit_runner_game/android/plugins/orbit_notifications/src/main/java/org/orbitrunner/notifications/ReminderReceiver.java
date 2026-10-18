package org.orbitrunner.notifications;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Shows a scheduled reminder; tapping it opens the game. */
public class ReminderReceiver extends BroadcastReceiver {
	static final String EXTRA_ID = "orbit_id";
	static final String EXTRA_TITLE = "orbit_title";
	static final String EXTRA_BODY = "orbit_body";
	private static final String CHANNEL = "orbit_reminders";

	@Override
	public void onReceive(Context context, Intent intent) {
		NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
		if (manager == null) {
			return;
		}
		Notification.Builder builder;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			if (manager.getNotificationChannel(CHANNEL) == null) {
				manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Orbit Runner",
						NotificationManager.IMPORTANCE_DEFAULT));
			}
			builder = new Notification.Builder(context, CHANNEL);
		} else {
			builder = new Notification.Builder(context);
		}
		Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
		if (launch != null) {
			launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
			builder.setContentIntent(PendingIntent.getActivity(context, 0, launch,
					PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
		}
		builder.setSmallIcon(context.getApplicationInfo().icon)
				.setContentTitle(intent.getStringExtra(EXTRA_TITLE))
				.setContentText(intent.getStringExtra(EXTRA_BODY))
				.setAutoCancel(true);
		try {
			manager.notify(intent.getIntExtra(EXTRA_ID, 0), builder.build());
		} catch (SecurityException ignored) {
			// Notifications not permitted (Android 13+ without the permission).
		}
	}

	static void dismiss(Context context, int id) {
		NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
		if (manager != null) {
			manager.cancel(id);
		}
	}
}
