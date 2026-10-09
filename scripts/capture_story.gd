extends SceneTree
## State-driven rendered acceptance. Run without --headless.
var game: Node2D
var shots: int = 0

func _initialize() -> void:
	call_deferred("_run")

func drain() -> void:
	var guard := 0
	while game.current_state==game.State.DIALOGUE and guard<200:
		game.advance_dialogue()
		guard += 1
	assert(guard<200)

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.local/validation/frames/%s.png"%name))
	shots += 1
	print("CAPTURE ",name," state=",game.current_state," real=",game.reality_choice," sim=",game.in_simulation," line=",game.line_index)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.local/validation/frames"))
	game = load("res://scenes/apartment.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await shot("00_title")
	game.new_game()
	drain()
	await shot("01_apartment")
	game.interact("phone")
	await shot("02_first_choice")
	game.select_option("first_2")
	for i in range(6): game.advance_dialogue()
	await shot("03_lin_xia_seated")
	drain()
	assert(game.reality_choice==2 and game.stage.active_branch==2)
	await shot("04_reply_traces")
	game.interact("laptop")
	await shot("05_else")
	game.select_option("data")
	await shot("06_sources")
	game.select_option("back_else")
	game.select_option("reconstruct")
	game.select_option("sim_1")
	game.advance_dialogue()
	await shot("07_entrance")
	while game.current_state==game.State.DIALOGUE and not game.shelf_hint_known: game.advance_dialogue()
	assert(game.shelf_hint_known and game.in_simulation)
	await shot("08_simulation_hint")
	drain()
	assert(not game.in_simulation and not game.stage.simulation and game.stage.active_branch==2)
	game.interact("bookshelf")
	await shot("09_inspection_choice")
	game.select_option("verify")
	game.advance_dialogue()
	assert(game.hair_tie_verified)
	await shot("10_verified")
	drain()
	await shot("11_anchor")
	game.select_option("anchor")
	drain()
	await shot("12_final_choice")
	game.select_option("final_1")
	drain()
	assert(game.phase==game.Phase.END and game.final_response==1)
	await shot("13_credits")
	game.new_game()
	drain()
	game.ui.set_font_scale(1.35)
	game.interact("phone")
	await shot("14_large_text")
	game.select_option("close")
	game._pause()
	await shot("15_settings")
	game._resume()
	game.ui.set_font_scale(1)
	root.size = Vector2i(1920,1080)
	await shot("16_1080p")
	print("CAPTURE_PASS shots=",shots)
	game.queue_free()
	await create_timer(0.35).timeout
	quit()
