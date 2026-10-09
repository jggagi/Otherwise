extends Node2D
## Sole owner of narrative progress. Stage/UI/audio only present it.
const STAGE = preload("res://scripts/apartment_stage.gd")
const UI = preload("res://scripts/game_ui.gd")
const SOUND = preload("res://scripts/soundscape.gd")
const STORY = preload("res://scripts/story.gd")
enum State { NORMAL, DIALOGUE, OPTIONS, TRANSITION, ENDED }
enum Phase { OPENING, FIRST_READY, DEPARTURE, ELSE_READY, VERIFY_READY, FINAL_READY, END }
var stage: Node2D
var ui: CanvasLayer
var sound: Node
var current_state: State = State.OPTIONS
var phase: Phase = Phase.OPENING
var reality_choice: int = 0
var simulation_choice: int = 0
var in_simulation: bool = false
var simulation_completed: bool = false
var shelf_hint_known: bool = false
var hair_tie_verified: bool = false
var anchor: bool = false
var final_response: int = 0
var reconstruct_count: int = 0
var seen_events: Array[String] = []
var seen_branches: Array[int] = []
var lines: Array = []
var line_index: int = 0
var dialogue_done: Callable
var paused: bool = false
var paused_state: State
var _paused_title: String
var _paused_text: String
var _paused_options: Array = []
var _menu_title: String
var _menu_text: String
var _menu_options: Array = []
var _reality_position := Vector2(605,570)
var _quitting: bool = false
const SAVE_PATH := "user://otherwise_save.json"
const SETTINGS_PATH := "user://otherwise_settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	_configure_input()
	stage = Node2D.new()
	stage.set_script(STAGE)
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)
	sound = Node.new()
	sound.set_script(SOUND)
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	ui = CanvasLayer.new()
	ui.set_script(UI)
	add_child(ui)
	ui.selected.connect(select_option)
	ui.continued.connect(advance_dialogue)
	ui.setting_changed.connect(_change_setting)
	_load_settings()
	_show_title()
	# Minimal release smoke entry: normal boot and normal audio-aware shutdown.
	if "--verify-boot" in OS.get_cmdline_user_args():
		print("RELEASE_BOOT_PASS version=",ProjectSettings.get_setting("application/config/version"))
		_request_quit()

func _configure_input() -> void:
	var actions := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"interact":[KEY_E]}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action,event)

func _process(delta: float) -> void:
	if paused:
		return
	if current_state==State.NORMAL:
		ui.update_prompt(stage.current)
		sound.walking(delta,stage.player.actually_moving)
	ui.mode_label.text = "ELSE · 概率重构中" if in_simulation else ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if current_state==State.NORMAL and not paused:
			stage.player.walk_to(get_global_mouse_position())
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key==KEY_ESCAPE:
		if paused:
			_resume()
		elif current_state==State.OPTIONS and "close" in ui.option_ids:
			select_option("close")
		elif current_state!=State.ENDED:
			_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		if key>=KEY_1 and key<=KEY_9:
			var pause_index := key-KEY_1
			if pause_index<ui.option_ids.size(): select_option(ui.option_ids[pause_index])
			get_viewport().set_input_as_handled()
		return
	if current_state in [State.OPTIONS,State.ENDED] and key>=KEY_1 and key<=KEY_9:
		var index := key-KEY_1
		if index<ui.option_ids.size():
			select_option(ui.option_ids[index])
	elif current_state==State.DIALOGUE and key in [KEY_E,KEY_SPACE,KEY_ENTER]:
		advance_dialogue()
	elif current_state==State.NORMAL and key==KEY_E and not stage.current.is_empty():
		interact(stage.current.id)
	get_viewport().set_input_as_handled()

func _freeze() -> void:
	stage.player.stop()
	stage.player.set_physics_process(false)

func _normal() -> void:
	current_state = State.NORMAL
	ui.close()
	stage.player.set_physics_process(true)
	ui.hint.visible = true

func _options(title: String,text: String,options: Array,settings: bool = false) -> void:
	current_state = State.OPTIONS
	_freeze()
	_menu_title = title
	_menu_text = text
	_menu_options = options.duplicate(true)
	ui.show_options(title,text,options,settings)

func _show_title() -> void:
	var options: Array = [["new","开始这个雨夜"]]
	if FileAccess.file_exists(SAVE_PATH):
		options.append(["load","继续上次的雨夜"])
	options.append(["settings","声音与文字"])
	options.append(["quit","退出"])
	_options("OTHERWISE","雨停之前\n一个关于告别、记忆和另一种可能的短篇。\n建议戴耳机，也可以完全静音游玩。",options)

func new_game() -> void:
	get_tree().paused = false
	paused = false
	phase = Phase.OPENING
	reality_choice = 0
	simulation_choice = 0
	in_simulation = false
	simulation_completed = false
	shelf_hint_known = false
	hair_tie_verified = false
	anchor = false
	final_response = 0
	reconstruct_count = 0
	seen_events.clear()
	seen_branches.clear()
	stage.simulation = false
	stage.apply_branch(0)
	stage.tie.visible = false
	stage.set_pose("empty")
	stage.set_location(false)
	stage.player.position = Vector2(605,570)
	stage.phone_glow.visible = false
	stage.laptop_glow.visible = false
	stage.set_location(false)
	_start_dialogue(STORY.opening(),func(): phase=Phase.FIRST_READY; _normal(); save_checkpoint())

func _start_dialogue(data: Array,finished: Callable) -> void:
	_freeze()
	current_state = State.DIALOGUE
	lines = data
	line_index = 0
	dialogue_done = finished
	_render_line()

func _render_line() -> void:
	var data: Dictionary = lines[line_index]
	stage.set_pose("empty" if phase==Phase.FINAL_READY else data.pose)
	var event: String = data.event
	if event!="" and not seen_events.has(event):
		seen_events.append(event)
		match event:
			"phone_arrived":
				stage.phone_glow.visible = true
				sound.cue("phone")
			"shelf_hint":
				if in_simulation:
					shelf_hint_known = true
			"tie_verified":
				if not in_simulation and shelf_hint_known:
					hair_tie_verified = true
					stage.tie.visible = true
	ui.show_line(data,line_index,lines.size())

func advance_dialogue() -> void:
	if paused or current_state!=State.DIALOGUE:
		return
	line_index += 1
	if line_index<lines.size():
		_render_line()
	else:
		var done := dialogue_done
		dialogue_done = Callable()
		ui.close()
		if done.is_valid():
			done.call()

func interact(id: String) -> void:
	if paused or current_state!=State.NORMAL:
		return
	match id:
		"phone":
			_open_phone()
		"door":
			if phase==Phase.DEPARTURE:
				sound.cue("door")
				_start_branch(1,false)
			else:
				_inspect("门","雨声在门缝外。今晚发生的事没有消失；你仍可以决定下一句话怎么说。")
		"laptop":
			if reality_choice==0 or phase==Phase.DEPARTURE:
				_inspect("电脑","你的离线个人实验 ELSE。屏幕还暗着，今晚的那条消息还没有一个结果。")
			else:
				_open_else()
		"bookshelf":
			if shelf_hint_known and not hair_tie_verified and not in_simulation:
				_options("书架下层","最左边那本旧书还在。你记得模拟里那句具体的位置。",[["verify","把旧书挪开，检查背后"],["close","先放回去"]])
			elif hair_tie_verified and not anchor:
				_verify_finished()
			elif hair_tie_verified:
				_inspect("书架下层","发圈还在旧书背后。内侧的蓝线是真的。你没有把它从模拟里带出来。")
			else:
				_inspect("书架","大学时的旧书。最下层挤得很满，只能看见书脊。")
		"photo":
			_inspect("照片","那次你们在街角的咖啡店躲雨。她嫌你看镜头太认真，按快门前笑了一下。照片不是 ELSE 的输入资料。")
		"letter":
			_inspect("信","普通的纸信，封口完好。你总说等忙完再拆。它不能证明 ELSE 知道什么秘密，只提醒你：有些事情一直被推到明天。")
		"mug":
			_inspect("第二个杯子","杯沿还留着一点水。她握住杯子的时候，才终于把明天的事说出口。")
		"shoes":
			_inspect("鞋","她上楼时换下的备用鞋。位置和以前一样，人却没有留下。")
		"umbrella":
			_inspect("伞","伞尖的水已经滴得很慢。你们都提起过‘等雨停’，今晚却不能一直等下去。")
		"note":
			_inspect("字条","明早七点的车。她希望你陪她走一段；如果不能，也请今晚告诉她。纸已经没有刚才那么湿了。")

func _inspect(title: String,text: String) -> void:
	_start_dialogue([STORY.line(title,text)],_normal)

func _open_phone() -> void:
	if reality_choice==0:
		_options("林夏","我在你楼下。",[["first_1","下楼"],["first_2","回复：上来吧"],["first_3","不回复"],["close","再想一想"]])
	elif phase==Phase.DEPARTURE:
		_inspect("手机","你已经决定下楼。走到门口，按 E 出门。原来的消息不能重新选择。")
	else:
		var text := "原来的决定：%s。\n林夏明早七点离开，今晚还在等一个明确答复。"%_choice_name(reality_choice)
		if shelf_hint_known and not hair_tie_verified:
			text += "\n你也可以先检查书架里的那条线索。"
		_options("手机",text,[["call","联系林夏，把今晚的话说完"],["close","先在房间走走"]])

func _choice_name(choice: int) -> String:
	return ["未选择","下楼","让她上来","不回复"][choice]

func _start_branch(choice: int,simulated: bool) -> void:
	stage.apply_branch(choice)
	stage.set_location(choice==1)
	_start_dialogue(STORY.branch(choice,simulated),func(): _finish_branch(choice,simulated))

func _finish_branch(choice: int,simulated: bool) -> void:
	stage.set_pose("empty")
	stage.set_location(false)
	if not seen_branches.has(choice):
		seen_branches.append(choice)
	if simulated:
		simulation_completed = true
		_return_from_simulation()
	else:
		phase = Phase.ELSE_READY
		stage.laptop_glow.visible = true
		sound.cue("computer")
		_normal()
		save_checkpoint()
		_inspect("", "电脑的屏幕自己亮了一下。你可以查看 ELSE，也可以直接拿起手机给林夏最后的答复。")

func _else_text() -> String:
	var text := "概率重构，不是已发生的事实。\n输入：手动导入的近期消息、日历、文字笔记。\n未接入照片、摄像头、房间扫描或实时设备。\n输入不含书架、发圈和蓝线修补。"
	if simulation_completed:
		text += "\n已体验：%s。重构结束，现实仍是原来的选择。"%_choice_name(simulation_choice)
	if anchor:
		text += "\n\nANCHOR：她不只是生气。她也在害怕明天。"
	return text

func _open_else() -> void:
	ui.graph_data = {"reality":reality_choice,"simulated":simulation_choice,"completed":simulation_completed,"anchored":anchor}
	var options: Array = []
	if not simulation_completed:
		options.append(["reconstruct","重构另一种可能"])
	options.append(["data","查看实际输入资料"])
	options.append(["call","暂不重构，回到现实联系她"])
	options.append(["close","关闭电脑"])
	_options("ELSE",_else_text(),options)

func _enter_simulation(choice: int) -> void:
	if simulation_completed or choice==reality_choice or reality_choice==0:
		return
	_reality_position = stage.player.position
	in_simulation = true
	simulation_choice = choice
	reconstruct_count += 1
	stage.simulation = true
	stage.phone_glow.visible = false
	stage.laptop_glow.visible = false
	stage.tie.visible = false
	_start_branch(choice,true)

func _return_from_simulation() -> void:
	in_simulation = false
	stage.simulation = false
	stage.set_location(false)
	stage.set_pose("empty")
	stage.apply_branch(reality_choice)
	stage.player.position = _reality_position
	stage.tie.visible = hair_tie_verified
	stage.phone_glow.visible = false
	stage.laptop_glow.visible = not simulation_completed
	phase = Phase.VERIFY_READY if shelf_hint_known else Phase.ELSE_READY
	_normal()
	save_checkpoint()
	_inspect("现实", "重构已关闭。原来的房间和选择还在。"+("\n那句关于书架的话却留在你脑子里。" if shelf_hint_known else "\n你没有读到的内容，没有成为记忆。"))

func _verify_finished() -> void:
	save_checkpoint()
	_options("记住一种理解","她不是只在责怪你今晚的选择。\n她也在害怕明天，害怕最后的话又被放下。",[["anchor","记住它，再联系她"],["close","先想一想"]])

func _begin_final() -> void:
	if reality_choice==0 or phase==Phase.DEPARTURE or in_simulation:
		return
	phase = Phase.FINAL_READY
	_start_dialogue(STORY.final_call(anchor),func(): _options("最后的答复","她的离开已经决定。你能决定的是，接下来怎样认真回应。",[["final_1","答应明早陪她去车站"],["final_2","坦白不能陪同，把今晚的话说完"]]))

func _end() -> void:
	phase = Phase.END
	current_state = State.ENDED
	stage.set_pose("empty")
	ui.show_options("雨停之前",("你答应陪她走完离开前的那段路。" if final_response==1 else "你给出了清楚的答复，告别不再停在沉默里。")+"\n\nOTHERWISE · 短篇终\n剧情与工程：Otherwise 项目\n角色与回忆画面：AI 辅助创作\n声音：项目原创程序合成\n字体：Noto Sans SC · SIL OFL\n\n"+("关系得到回应，ELSE 的秘密仍留在那枚发圈里。" if anchor else "这一晚没有被改写。但你把下一句话说完了。"),[["new","重新开始这个雨夜"],["quit","退出"]])
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func select_option(id: String) -> void:
	if not id in ui.option_ids:
		return
	if paused:
		match id:
			"resume": _resume()
			"save": save_checkpoint(); _resume()
			"abort": _resume(); _return_from_simulation()
			"new": _resume(); new_game()
			"quit": _request_quit()
		return
	if current_state not in [State.OPTIONS,State.ENDED]:
		return
	match id:
		"new": new_game()
		"load": load_checkpoint()
		"quit": _request_quit()
		"settings": _options("声音与文字","静音不影响理解剧情。字号设置会保留。",[["title","返回标题"]],true)
		"title": _show_title()
		"close": _normal()
		"first_1","first_2","first_3":
			if reality_choice!=0: return
			reality_choice = int(id.right(1))
			stage.phone_glow.visible = false
			if reality_choice==1:
				phase = Phase.DEPARTURE
				_normal()
				save_checkpoint()
				_inspect("", "你决定下楼。走到门口，按 E 出门。")
			else:
				_start_branch(reality_choice,false)
		"reconstruct":
			var options: Array = []
			for choice in [1,2,3]:
				if choice!=reality_choice:
					options.append(["sim_%d"%choice,_choice_name(choice)])
			options.append(["close","暂不重构"])
			_options("选择一种可能","只有重构中的事件会重置。退出后，现实的决定和痕迹保持原样。",options)
		"sim_1","sim_2","sim_3": _enter_simulation(int(id.right(1)))
		"data": _options("ELSE 输入记录","2026-10-07 消息：林夏问你最近是否很忙。\n2026-10-08 日历：工作例会，交稿。\n手记：最近睡得晚，想把房间收拾一下。\n\n记录到此为止。没有书架照片或实时感知，没有发圈、蓝线、修补位置。\n输出仍只是推测，不能替她作出真实答复。",[["back_else","返回 ELSE"]])
		"back_else": _open_else()
		"verify": _start_dialogue(STORY.verify(),_verify_finished)
		"anchor":
			if not hair_tie_verified: return
			anchor = true
			phase = Phase.FINAL_READY
			_normal()
			save_checkpoint()
			_begin_final()
		"call": _begin_final()
		"final_1","final_2":
			if final_response!=0: return
			final_response = int(id.right(1))
			_start_dialogue(STORY.ending(final_response,anchor),_end)

func _pause() -> void:
	if current_state==State.TRANSITION:
		return
	paused_state = current_state
	_paused_title = _menu_title
	_paused_text = _menu_text
	_paused_options = _menu_options.duplicate(true)
	paused = true
	get_tree().paused = true
	var options: Array = [["resume","继续"]]
	if current_state==State.NORMAL and not in_simulation:
		options.append(["save","保存当前进度并继续"])
	if in_simulation:
		options.append(["abort","退出重构，回到原来的现实"])
	options.append(["new","重新开始"])
	options.append(["quit","退出游戏"])
	ui.show_options("暂停","剧情与环境已暂停。进度在现实的关键节点自动保存。",options,true)

func _resume() -> void:
	get_tree().paused = false
	paused = false
	current_state = paused_state
	if current_state==State.DIALOGUE:
		ui.show_line(lines[line_index],line_index,lines.size())
	elif current_state==State.OPTIONS:
		ui.show_options(_paused_title,_paused_text,_paused_options)
	else:
		ui.close()

func save_checkpoint() -> bool:
	if in_simulation or phase in [Phase.OPENING,Phase.END] or reality_choice<0:
		return false
	var data := {"version":1,"choice":reality_choice,"phase":phase,"completed":simulation_completed,"sim_choice":simulation_choice,"hint":shelf_hint_known,"verified":hair_tie_verified,"anchor":anchor,"reconstructions":reconstruct_count,"events":seen_events,"branches":seen_branches,"position":[stage.player.position.x,stage.player.position.y]}
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file==null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var success := file.get_error()==OK
	file.close()
	return success

func load_checkpoint() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var parser := JSON.new()
	var parsed := parser.parse(FileAccess.get_file_as_string(SAVE_PATH))
	var data: Variant = parser.data if parsed==OK else null
	if not _valid_checkpoint(data):
		_options("无法读取进度","存档格式不完整，可以重新开始。",[["new","重新开始"]])
		return false
	var choice := int(data.get("choice",-1))
	var saved_phase := int(data.get("phase",-1))
	if choice<0 or choice>3 or saved_phase not in [Phase.FIRST_READY,Phase.DEPARTURE,Phase.ELSE_READY,Phase.VERIFY_READY,Phase.FINAL_READY]:
		_options("无法读取进度","存档内容不符合这个版本，可以重新开始。",[["new","重新开始"]])
		return false
	get_tree().paused = false
	paused = false
	reality_choice = choice
	phase = saved_phase
	in_simulation = false
	simulation_completed = bool(data.get("completed",false))
	simulation_choice = clampi(int(data.get("sim_choice",0)),0,3)
	shelf_hint_known = bool(data.get("hint",false))
	hair_tie_verified = bool(data.get("verified",false)) and shelf_hint_known
	anchor = bool(data.get("anchor",false)) and hair_tie_verified
	reconstruct_count = maxi(0,int(data.get("reconstructions",0)))
	seen_events.assign(data.get("events",[]))
	seen_branches.assign(data.get("branches",[]))
	stage.simulation = false
	stage.apply_branch(choice if phase>=Phase.ELSE_READY else 0)
	stage.set_location(false)
	var pos: Array = data.position
	var position := Vector2(float(pos[0]),float(pos[1]))
	var cell := Vector2i((position/8).floor())
	if not stage.player.navigator.region.has_point(cell) or stage.player.navigator.is_point_solid(cell):
		position = Vector2(605,570)
	stage.player.position = position
	stage.set_pose("empty")
	stage.tie.visible = hair_tie_verified
	stage.phone_glow.visible = choice==0
	stage.laptop_glow.visible = phase>=Phase.ELSE_READY and not simulation_completed
	final_response = 0
	_normal()
	return true

func _valid_checkpoint(data: Variant) -> bool:
	if not data is Dictionary or data.get("version",0)!=1: return false
	for key in ["choice","phase","sim_choice","reconstructions"]:
		if typeof(data.get(key)) not in [TYPE_INT,TYPE_FLOAT]: return false
	for key in ["completed","hint","verified","anchor"]:
		if not data.get(key) is bool: return false
	for key in ["events","branches","position"]:
		if not data.get(key) is Array: return false
	if data.position.size()!=2: return false
	for coordinate in data.position:
		if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)): return false
	for event in data.events:
		if not event is String: return false
	for branch in data.branches:
		if typeof(branch) not in [TYPE_INT,TYPE_FLOAT] or int(branch) not in [1,2,3]: return false
	if int(data.phase)==Phase.FIRST_READY and int(data.choice)!=0: return false
	if int(data.phase)!=Phase.FIRST_READY and int(data.choice)==0: return false
	if int(data.phase)==Phase.DEPARTURE and int(data.choice)!=1: return false
	return true

func _change_setting(id: String,value: float) -> void:
	if id=="volume": sound.set_volume(value)
	var config := ConfigFile.new()
	config.set_value("audio","volume",sound.volume)
	config.set_value("text","scale",ui.font_scale)
	config.save(SETTINGS_PATH)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()

func _request_quit() -> void:
	if _quitting: return
	_quitting = true
	_freeze()
	sound.stop_all()
	await get_tree().create_timer(0.35,true).timeout
	get_tree().quit()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH)==OK:
		sound.set_volume(clampf(float(config.get_value("audio","volume",0.65)),0,1))
		ui.set_font_scale(clampf(float(config.get_value("text","scale",1.0)),1,1.35))
