@tool
extends EditorPlugin
## Adds the OrbitNotifications Android library to Gradle exports.

var _export: OrbitNotificationsExport


func _enter_tree() -> void:
	_export = OrbitNotificationsExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class OrbitNotificationsExport extends EditorExportPlugin:
	const AAR := "orbit_notifications/bin/orbit_notifications-release.aar"

	func _get_name() -> String:
		return "OrbitNotifications"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR])
