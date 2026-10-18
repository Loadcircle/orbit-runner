package org.orbitrunner.notifications;

import android.Manifest;
import android.app.Activity;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.SystemClock;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Local reminders for Orbit Runner (energy full, new season...). The game
 * schedules them by id; an inexact alarm wakes ReminderReceiver, which shows
 * the notification. Alarms do not survive a reboot: the game reschedules them
 * on its next launch. Called from GDScript through Engine.get_singleton.
 */
public class OrbitNotifications extends GodotPlugin {
	private static final String TAG = "OrbitNotifications";
	private static final int PERMISSION_REQUEST = 7301;

	public OrbitNotifications(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "OrbitNotifications";
	}

	/** Shows `title`/`body` as reminder `id` in `delaySeconds` (replaces a pending one with the same id). */
	@UsedByGodot
	public void schedule(int id, int delaySeconds, String title, String body) {
		Context context = appContext();
		if (context == null) {
			return;
		}
		AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
		if (alarms == null) {
			return;
		}
		long at = SystemClock.elapsedRealtime() + Math.max(delaySeconds, 1) * 1000L;
		Log.i(TAG, "Reminder " + id + " in " + delaySeconds + " s");
		alarms.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pending(context, id, title, body));
	}

	@UsedByGodot
	public void cancel(int id) {
		Context context = appContext();
		if (context == null) {
			return;
		}
		AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
		if (alarms != null) {
			alarms.cancel(pending(context, id, "", ""));
		}
		ReminderReceiver.dismiss(context, id);
	}

	/** Android 13+ asks the player once; earlier versions need no permission. */
	@UsedByGodot
	public void requestPermission() {
		Activity activity = getActivity();
		if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
			return;
		}
		if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
			Log.i(TAG, "Requesting POST_NOTIFICATIONS");
			activity.runOnUiThread(() -> activity.requestPermissions(
					new String[] { Manifest.permission.POST_NOTIFICATIONS }, PERMISSION_REQUEST));
		}
	}

	@UsedByGodot
	public boolean isPermitted() {
		Context context = appContext();
		return context != null && (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU
				|| context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED);
	}

	private Context appContext() {
		Activity activity = getActivity();
		return activity != null ? activity.getApplicationContext() : null;
	}

	private static PendingIntent pending(Context context, int id, String title, String body) {
		Intent intent = new Intent(context, ReminderReceiver.class);
		intent.putExtra(ReminderReceiver.EXTRA_ID, id);
		intent.putExtra(ReminderReceiver.EXTRA_TITLE, title);
		intent.putExtra(ReminderReceiver.EXTRA_BODY, body);
		return PendingIntent.getBroadcast(context, id, intent,
				PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
	}
}
