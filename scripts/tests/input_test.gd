extends SceneTree
## Exercises the real viewport input dispatch, including UI focus and mouse buttons.
var game: Node2D
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func key(code: int,down: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func tap(code: int) -> void:
	await key(code)
	await key(code,false)

func drain() -> void:
	var guard := 0
	while game.current_state==game.State.DIALOGUE and guard<200:
		await tap(KEY_E)
		guard += 1
	check(guard<200,"E advances dialogue to completion")

func _run() -> void:
	game = load("res://scenes/apartment.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	await physics_frame
	await tap(KEY_1)
	check(game.current_state==game.State.DIALOGUE,"number chooses title button")
	await drain()
	var start: Vector2 = game.stage.player.position
	await key(KEY_S)
	for i in range(12): await physics_frame
	await key(KEY_S,false)
	check(game.stage.player.position.y>start.y+15,"sustained WASD moves player")
	await tap(KEY_ESCAPE)
	var paused_pos: Vector2 = game.stage.player.position
	await key(KEY_A)
	for i in range(6): await physics_frame
	await key(KEY_A,false)
	check(game.paused and game.stage.player.position==paused_pos,"pause blocks movement")
	await tap(KEY_ESCAPE)
	check(not game.paused,"ESC resumes")
	await tap(KEY_ESCAPE)
	await tap(KEY_1)
	check(not game.paused,"number chooses pause menu option")
	check(game.stage.player.walk_to(Vector2(588,532)),"navigation works after keyboard movement")
	var guard := 0
	while not game.stage.player.path.is_empty() and guard<300:
		await physics_frame
		guard += 1
	await process_frame
	print("INPUT_PHONE pos=",game.stage.player.position," current=",game.stage.current," state=",game.current_state)
	await tap(KEY_E)
	check("first_2" in game.ui.option_ids,"E opens nearby phone")
	await tap(KEY_2)
	check(game.reality_choice==2,"number selects first choice")
	await drain()
	game.interact("phone")
	await process_frame
	var button: Button
	for child in game.ui.content.get_children():
		if child is Button:
			button = child
			break
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await process_frame
	check(game.phase==game.Phase.FINAL_READY,"mouse activates real UI button")
	await drain()
	await tap(KEY_2)
	await drain()
	check(game.phase==game.Phase.END and game.final_response==2,"input route reaches credits")
	await tap(KEY_1)
	check(game.phase==game.Phase.OPENING and game.reality_choice==0,"number restarts from credits")
	print("INPUT_TEST checks=",checks," failures=",failures)
	game.queue_free()
	await create_timer(0.35).timeout
	quit(0 if failures==0 else 1)
