extends SceneTree
## Run externally against the extracted release binary. This script is excluded from PCK.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if ResourceLoader.exists("res://scripts/tests/story_test.gd") or ResourceLoader.exists("res://scripts/capture_story.gd"):
		push_error("Development scripts present: package isolation failed")
		quit(1)
		return
	for path in ["res://assets/fonts/NotoSansSC.ttf","res://assets/art_sources/lin_xia_poses_v1.png","res://assets/art_sources/hair_tie_detail_v1.png","res://assets/audio/rain.wav"]:
		if not ResourceLoader.exists(path):
			push_error("Missing packaged resource: "+path)
			quit(1)
			return
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await process_frame
	await process_frame
	var game: Node2D = current_scene
	if game.ui.option_ids[0]!="new":
		quit(1)
		return
	print("PACKAGE_PROBE_PASS version=",ProjectSettings.get_setting("application/config/version")," development_resources_absent=true main_scene_title=true")
	game._request_quit()
