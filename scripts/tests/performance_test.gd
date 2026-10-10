extends SceneTree
## Records measured frame intervals, not a hardware-wide performance guarantee.
var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if "--vsync-off" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 60
	game = load("res://scenes/apartment.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	while game.current_state==game.State.DIALOGUE: game.advance_dialogue()
	for i in range(60): await process_frame
	var times: Array[float] = []
	var before := Time.get_ticks_usec()
	for i in range(360):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-before)/1000.0)
		before = now
	times.sort()
	var report := {"frames":times.size(),"window":str(root.size),"median_ms":times[180],"p95_ms":times[342],"max_ms":times[-1],"engine_static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,"render_video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"renderer":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open("res://.local/validation/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("PERFORMANCE ",JSON.stringify(report))
	game.queue_free()
	await create_timer(0.35).timeout
	quit()
