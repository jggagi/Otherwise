extends SceneTree
var game: Node2D
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: "+message)

func drain() -> void:
	var guard := 0
	while game.current_state==game.State.DIALOGUE and guard<200:
		game.advance_dialogue()
		guard += 1
	check(guard<200,"dialogue terminates")

func first(choice: int) -> void:
	game.new_game()
	drain()
	game.interact("phone")
	game.select_option("first_%d"%choice)
	drain()
	if choice==1:
		game.interact("door")
		drain()
	check(game.reality_choice==choice,"first choice fixed")
	check(game.phase==game.Phase.ELSE_READY,"real branch completed")
	check(game.stage.active_branch==choice,"real traces applied")

func simulate(choice: int) -> void:
	game.interact("laptop")
	game.select_option("reconstruct")
	game.select_option("sim_%d"%choice)
	drain()
	check(not game.in_simulation,"returns to reality")
	check(game.simulation_completed,"simulation completion")
	check(game.shelf_hint_known,"hint from all simulated branches")
	check(not game.hair_tie_verified,"not found before inspection")
	check(not game.stage.simulation,"rain returns to normal")
	check(game.stage.active_branch==game.reality_choice,"no physical outcome crosses")
	game.interact("bookshelf")
	game.select_option("verify")
	drain()
	check(game.hair_tie_verified,"active reality inspection verifies tie")
	game.select_option("anchor")
	drain()
	check(game.anchor,"anchor earned with evidence")

func finish(response: int) -> void:
	game.select_option("final_%d"%response)
	drain()
	check(game.phase==game.Phase.END,"ending reached")
	check(game.current_state==game.State.ENDED,"credits visible")
	check(game.final_response==response,"correct final response")
	var original: int = game.reality_choice
	game.interact("phone")
	game.select_option("first_2")
	check(game.reality_choice==original,"no interaction after credits")

func _run() -> void:
	game = load("res://scenes/apartment.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	for choice in [1,2,3]:
		for response in [1,2]:
			first(choice)
			game.interact("phone")
			check(not "first_1" in game.ui.option_ids,"phone cannot reselect")
			game.select_option("call")
			drain()
			finish(response)
			check(not game.anchor,"ordinary ending has no anchor")
			await process_frame
	for choice in [1,2,3]:
		for other in [1,2,3]:
			if other==choice: continue
			for response in [1,2]:
				first(choice)
				simulate(other)
				finish(response)
				await process_frame
	for choice in [1,2,3]:
		first(choice)
		game.interact("laptop")
		game.select_option("reconstruct")
		var other: int = 2 if choice==1 else 1
		game.select_option("sim_%d"%other)
		game._pause()
		var rain_position: Vector2 = game.stage.rain[0].position
		await create_timer(0.06,true).timeout
		check(game.stage.rain[0].position==rain_position,"pause freezes atmosphere")
		game.select_option("abort")
		drain()
		check(not game.simulation_completed and not game.shelf_hint_known,"abort does not grant unseen hint")
		check(game.stage.active_branch==choice,"abort restores branch")
		game.interact("laptop")
		game.select_option("close")
		check(game.current_state==game.State.NORMAL,"cancel does not trap")
		game.interact("phone")
		game.select_option("call")
		drain()
		finish(2)
		check(not game.anchor,"early abort permits ordinary ending")
		first(choice)
		simulate(other)
		finish(2)
		await process_frame
	first(2)
	check(game.save_checkpoint(),"checkpoint saved")
	game.new_game()
	check(game.load_checkpoint(),"checkpoint restored")
	check(game.reality_choice==2 and game.stage.active_branch==2,"load restores authored baseline")
	var original_save := FileAccess.get_file_as_string(game.SAVE_PATH)
	for bad in ["{",'{"version":1}', '{"version":1,"position":"bad"}']:
		var file := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
		file.store_string(bad)
		file.close()
		check(not game.load_checkpoint(),"corrupt save rejected")
	var corrupt: Dictionary = JSON.parse_string(original_save)
	corrupt.events = [null]
	var file := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt))
	file.close()
	check(not game.load_checkpoint(),"typed corrupt events rejected")
	corrupt = JSON.parse_string(original_save)
	corrupt.position = [-500,999999]
	file = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt))
	file.close()
	check(game.load_checkpoint() and game.stage.player.position==Vector2(605,570),"invalid saved position safely restored")
	first(2)
	game.interact("laptop")
	game.select_option("reconstruct")
	game.select_option("sim_3")
	drain()
	game.interact("bookshelf")
	game.select_option("verify")
	drain()
	game.select_option("close")
	game.interact("bookshelf")
	check("anchor" in game.ui.option_ids,"deferred anchor can be revisited")
	check(game.load_checkpoint() and game.hair_tie_verified,"inspection checkpoint survives reload")
	game.interact("bookshelf")
	game.select_option("anchor")
	drain()
	finish(1)
	first(1)
	game.interact("laptop")
	game.select_option("reconstruct")
	game.select_option("sim_3")
	game._pause()
	game.select_option("abort")
	drain()
	game.interact("phone")
	game.select_option("call")
	drain()
	check(not game.stage.npc.visible,"telephone does not spawn NPC in apartment")
	finish(2)
	game.new_game()
	drain()
	game.interact("phone")
	game.select_option("first_1")
	drain()
	game.interact("door")
	check(game.stage.in_entrance,"branch uses entrance stage")
	game._pause()
	game.select_option("new")
	check(game.stage.player.position==Vector2(605,570) and not game.stage.in_entrance,"restart during entrance restores player")
	game.new_game()
	drain()
	check(not game.anchor and not game.hair_tie_verified and game.reality_choice==0,"restart clears knowledge")
	await process_frame
	await _navigation()
	print("STORY_TEST checks=",checks," failures=",failures.size()," endings=18 + 3 abort/retry + 3 abort/ordinary paths")
	for failure in failures: print(failure)
	game.queue_free()
	await create_timer(0.35).timeout
	quit(0 if failures.is_empty() else 1)

func _navigation() -> void:
	var targets := ["phone","door","laptop","photo","letter","bookshelf"]
	for id in targets:
		var best: Vector2 = Vector2.ZERO
		var best_length := INF
		var grid: AStarGrid2D = game.stage.player.navigator
		var source := Vector2i((game.stage.player.position/8).floor())
		for x in range(18,138):
			for y in range(40,77):
				var cell := Vector2i(x,y)
				if grid.is_point_solid(cell): continue
				var pos := Vector2(x*8+4,y*8+4)
				var entry: Dictionary = game.stage.nearest(pos)
				if entry.is_empty() or entry.id!=id: continue
				if pos.distance_to(entry.pos)>entry.radius-18: continue
				var stable := true
				for offset in [Vector2(-10,0),Vector2(10,0),Vector2(0,-10),Vector2(0,10)]:
					var nearby: Dictionary = game.stage.nearest(pos+offset)
					if nearby.is_empty() or nearby.id!=id: stable=false
				if not stable: continue
				var route := grid.get_id_path(source,cell)
				if not route.is_empty() and route.size()<best_length:
					best_length = route.size()
					best = pos
		check(best_length<INF,"reachable target "+id)
		if best_length==INF: continue
		check(game.stage.player.walk_to(best),"click path "+id)
		var frames := 0
		while not game.stage.player.path.is_empty() and frames<900:
			await physics_frame
			frames += 1
		check(frames<900,"actual movement reaches "+id)
		var entry: Dictionary = game.stage.nearest(game.stage.player.position)
		check(not entry.is_empty() and entry.id==id,"correct prompt after walking "+id)
		game.interact(id)
		drain()
		if "close" in game.ui.option_ids: game.select_option("close")
		print("WALK ",id," frames=",frames," pos=",game.stage.player.position)
