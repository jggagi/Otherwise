extends Node2D
## Otherwise — Milestone 2 (ELSE 重构 / ELSE reconstruction).
## Builds the apartment stage box: warm interior walls/floor, a rainy city
## window, four interactables, the player, ELSE interface and minimal UI.

const VOID := Color(0.03, 0.045, 0.07)
const WALL_BACK := Color(0.55, 0.49, 0.43)
const WALL_SIDE := Color(0.44, 0.39, 0.34)
const FLOOR_WOOD := Color(0.34, 0.27, 0.20)
const FLOOR_SEAM := Color(0.30, 0.24, 0.17)
const WINDOW_SKY := Color(0.12, 0.16, 0.23)
const FRAME := Color(0.38, 0.33, 0.28)

## 游戏主状态
enum State {
	NORMAL,       # 自由探索房间
	CHOICE,       # 手机分支选择中
	BRANCH_VIEW,  # 分支剧情全屏黑屏展示中
	ELSE,         # 笔记本 ELSE 重构界面
}

## 手机第一个选择的三个分支
enum Choice {
	NONE,
	DOWN,    # [1] 下楼
	REPLY,   # [2] 回复
	IGNORE,  # [3] 不回复
}

@onready var player: CharacterBody2D = $Room/Player
@onready var walls: Node2D = $Walls
@onready var floor_node: Node2D = $Floor
@onready var room: Node2D = $Room
@onready var hint_label: Label = $UI/Hint
@onready var prompt_label: Label = $UI/Prompt
@onready var message_label: Label = $UI/Message

var current_state: State = State.NORMAL
var made_choice: Choice = Choice.NONE

# Milestone 2 新增状态记录
var seen_branches: Array[String] = []
var reconstruct_count: int = 0
var _is_reconstructing: bool = false

var interactables: Array[InteractableEntry] = []
var current: InteractableEntry = null
var message_time := 0.0
var message_duration := 3.5

var _rain: Array[Polygon2D] = []
var _rain_anomaly: Array[Polygon2D] = []

# Milestone 1 新增 UI 节点
var choices_label: Label
var overlay: ColorRect
var branch_text_label: Label
var continue_hint_label: Label

# Milestone 2 新增 UI 节点
var else_overlay: ColorRect
var else_box: VBoxContainer
var else_title_label: Label
var else_subtitle_label: Label
var else_options_label: Label
var else_history_label: Label
var else_hint_label: Label


class InteractableEntry:
	var id: String
	var node: Node2D
	var prompt: String
	var text: String
	var radius: float

	func _init(i: String, n: Node2D, p: String, t: String, r: float) -> void:
		id = i
		node = n
		prompt = p
		text = t
		radius = r


func _ready() -> void:
	room.y_sort_enabled = true
	_build_backdrop()
	_build_walls()
	_build_floor()
	_build_light_pools()
	_build_furniture()
	_build_interactables()
	_build_boundary()
	_setup_player()
	_setup_ui()


func _process(delta: float) -> void:
	_update_rain(delta)
	if current_state == State.NORMAL:
		_update_interaction()
		_update_message(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	var key: Key = key_event.physical_keycode
	var key_code: Key = key_event.keycode

	match current_state:
		State.NORMAL:
			if (key == KEY_E or key_code == KEY_E) and current != null:
				if current.id == "phone":
					_open_choice()
				elif current.id == "laptop" and made_choice != Choice.NONE:
					_open_else()
				else:
					var text_to_show := current.text
					if current.id == "photo" and reconstruct_count >= 1:
						text_to_show = "一张有些褪色的合影。照片里的笑容，好像比记忆里淡了一点。"
					_show_message(text_to_show)
		State.CHOICE:
			if key == KEY_1 or key == KEY_KP_1 or key_code == KEY_1 or key_code == KEY_KP_1:
				_select_choice(Choice.DOWN)
			elif key == KEY_2 or key == KEY_KP_2 or key_code == KEY_2 or key_code == KEY_KP_2:
				_select_choice(Choice.REPLY)
			elif key == KEY_3 or key == KEY_KP_3 or key_code == KEY_3 or key_code == KEY_KP_3:
				_select_choice(Choice.IGNORE)
			elif key == KEY_ESCAPE or key_code == KEY_ESCAPE:
				_close_choice()
		State.BRANCH_VIEW:
			if key == KEY_E or key == KEY_SPACE or key_code == KEY_E or key_code == KEY_SPACE:
				_return_to_room()
		State.ELSE:
			if _is_reconstructing:
				return
			if key == KEY_1 or key == KEY_KP_1 or key_code == KEY_1 or key_code == KEY_KP_1:
				_reconstruct()
			elif key == KEY_2 or key == KEY_KP_2 or key_code == KEY_2 or key_code == KEY_KP_2:
				_close_else()
			elif key == KEY_ESCAPE or key_code == KEY_ESCAPE:
				_close_else()


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

func _poly(parent: Node, points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	parent.add_child(p)
	return p


func _rect(parent: Node, r: Rect2, color: Color) -> Polygon2D:
	return _poly(parent, PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
	]), color)


func _circle(parent: Node, center: Vector2, radius: float, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return _poly(parent, points, color)


func _add_box(parent: Node, pos: Vector2, w: float, d: float, h: float, top: Color, front: Color) -> Node2D:
	var box := Node2D.new()
	box.position = pos
	# Top face (recedes up-screen by depth d).
	_poly(box, PackedVector2Array([
		Vector2(-w * 0.5, -d), Vector2(w * 0.5, -d),
		Vector2(w * 0.5, 0.0), Vector2(-w * 0.5, 0.0),
	]), top)
	# Front face (drops down by height h).
	_poly(box, PackedVector2Array([
		Vector2(-w * 0.5, 0.0), Vector2(w * 0.5, 0.0),
		Vector2(w * 0.5, h), Vector2(-w * 0.5, h),
	]), front)
	# Collision footprint covering the visible extent.
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, d + h)
	col.shape = shape
	col.position = Vector2(0.0, (h - d) * 0.5)
	body.add_child(col)
	box.add_child(body)
	parent.add_child(box)
	return box


func _add_wall(parent: Node, a: Vector2, b: Vector2, thickness: float) -> void:
	var mid := (a + b) * 0.5
	var delta := b - a
	var body := StaticBody2D.new()
	body.position = mid
	body.rotation = delta.angle()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(delta.length(), thickness)
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var bg := _poly(self, PackedVector2Array([
		Vector2(-2000, -2000), Vector2(2000, -2000),
		Vector2(2000, 2000), Vector2(-2000, 2000),
	]), VOID)
	bg.z_index = -100


func _build_walls() -> void:
	# Back wall (straight-on far wall).
	_rect(walls, Rect2(220, 80, 840, 220), WALL_BACK)
	# Side walls, slanting toward the viewer.
	_poly(walls, PackedVector2Array([
		Vector2(120, 80), Vector2(220, 80), Vector2(220, 300), Vector2(130, 660),
	]), WALL_SIDE)
	_poly(walls, PackedVector2Array([
		Vector2(1160, 80), Vector2(1060, 80), Vector2(1060, 300), Vector2(1150, 660),
	]), WALL_SIDE)
	# Kitchen sink window (small) and, right, the big rainy living-room window.
	_build_window(Rect2(385, 145, 120, 90), false)
	_build_window(Rect2(865, 120, 160, 145), true)
	_build_rain()
	# Bedroom glimpse: a dark doorway with a faint bed inside.
	_poly(walls, PackedVector2Array([
		Vector2(700, 100), Vector2(790, 100), Vector2(790, 300), Vector2(700, 300),
	]), Color(0.06, 0.07, 0.09))
	_poly(walls, PackedVector2Array([
		Vector2(712, 240), Vector2(778, 240), Vector2(778, 298), Vector2(712, 298),
	]), Color(0.13, 0.14, 0.18))
	_poly(walls, PackedVector2Array([
		Vector2(712, 210), Vector2(778, 210), Vector2(778, 232), Vector2(712, 232),
	]), Color(0.20, 0.21, 0.26))


func _build_window(r: Rect2, with_city: bool) -> void:
	_rect(walls, r, WINDOW_SKY)
	if with_city:
		var buildings := [
			Rect2(r.position.x + 6, r.end.y - 60, 34, 60),
			Rect2(r.position.x + 46, r.end.y - 40, 44, 40),
			Rect2(r.position.x + 96, r.end.y - 66, 40, 66),
			Rect2(r.position.x + 140, r.end.y - 34, 20, 34),
		]
		for br: Rect2 in buildings:
			_rect(walls, br, Color(0.07, 0.09, 0.14))
		for i in range(8):
			var wx := r.position.x + 10.0 + float(i) * 19.0
			var wy := r.position.y + 14.0 + float(i % 3) * 22.0
			_rect(walls, Rect2(wx, wy, 7, 9), Color(0.88, 0.74, 0.48, 0.75))
	var fw := 6.0
	_rect(walls, Rect2(r.position.x - fw, r.position.y - fw, r.size.x + fw * 2.0, fw), FRAME)
	_rect(walls, Rect2(r.position.x - fw, r.position.y + r.size.y, r.size.x + fw * 2.0, fw), FRAME)
	_rect(walls, Rect2(r.position.x - fw, r.position.y, fw, r.size.y), FRAME)
	_rect(walls, Rect2(r.position.x + r.size.x, r.position.y, fw, r.size.y), FRAME)
	_rect(walls, Rect2(r.position.x + r.size.x * 0.5 - 2.0, r.position.y, 4.0, r.size.y), FRAME)


func _build_rain() -> void:
	for i in range(16):
		var drop := Polygon2D.new()
		var dh := 8.0 + float(i % 4) * 4.0
		drop.polygon = PackedVector2Array([
			Vector2(-1.0, -dh * 0.5), Vector2(1.0, -dh * 0.5),
			Vector2(1.0, dh * 0.5), Vector2(-1.0, dh * 0.5),
		])
		drop.color = Color(0.62, 0.72, 0.9, 0.45)
		drop.position = Vector2(randf_range(872.0, 1018.0), randf_range(126.0, 260.0))
		walls.add_child(drop)
		_rain.append(drop)

	# Milestone 2 视觉异常：第二组略微倾斜、颜色更浅、偏右的雨丝（仅重构后可见）
	for i in range(12):
		var drop := Polygon2D.new()
		var dh := 7.0 + float(i % 3) * 3.5
		drop.polygon = PackedVector2Array([
			Vector2(-0.8, -dh * 0.5), Vector2(0.8, -dh * 0.5),
			Vector2(0.8, dh * 0.5), Vector2(-0.8, dh * 0.5),
		])
		drop.rotation = deg_to_rad(-12.0)
		drop.color = Color(0.75, 0.82, 0.95, 0.28)
		drop.position = Vector2(randf_range(920.0, 1022.0), randf_range(126.0, 260.0))
		drop.visible = false
		walls.add_child(drop)
		_rain_anomaly.append(drop)


func _build_floor() -> void:
	_poly(floor_node, PackedVector2Array([
		Vector2(220, 300), Vector2(1060, 300), Vector2(1150, 660), Vector2(130, 660),
	]), FLOOR_WOOD)
	for i in range(1, 6):
		var t := float(i) / 6.0
		var y := lerpf(300.0, 660.0, t)
		var lx := lerpf(220.0, 130.0, t)
		var rx := lerpf(1060.0, 1150.0, t)
		_poly(floor_node, PackedVector2Array([
			Vector2(lx, y), Vector2(rx, y), Vector2(rx, y + 1.5), Vector2(lx, y + 1.5),
		]), FLOOR_SEAM)


func _build_light_pools() -> void:
	# Cool spill from the living-room window onto the floor.
	_poly(floor_node, PackedVector2Array([
		Vector2(865, 268), Vector2(1025, 268), Vector2(1090, 620), Vector2(760, 620),
	]), Color(0.45, 0.60, 0.85, 0.09))
	# Warm pool around the floor lamp.
	_circle(floor_node, Vector2(950, 470), 150.0, Color(1.0, 0.78, 0.50, 0.10))
	# Warm pool near the entrance.
	_circle(floor_node, Vector2(350, 360), 120.0, Color(1.0, 0.78, 0.50, 0.07))


func _build_furniture() -> void:
	# Rug under the sofa.
	_rect(room, Rect2(360, 380, 300, 150), Color(0.25, 0.27, 0.29))
	# Sofa.
	_add_box(room, Vector2(430, 400), 200, 80, 46, Color(0.42, 0.46, 0.52), Color(0.34, 0.38, 0.44))
	# Coffee table.
	_add_box(room, Vector2(430, 480), 120, 55, 22, Color(0.55, 0.42, 0.28), Color(0.44, 0.33, 0.24))
	# Kitchen counter along the back wall.
	_add_box(room, Vector2(450, 306), 210, 55, 58, Color(0.50, 0.50, 0.52), Color(0.40, 0.40, 0.42))
	# Dining table and two chairs.
	_add_box(room, Vector2(830, 440), 140, 90, 26, Color(0.55, 0.42, 0.28), Color(0.44, 0.33, 0.24))
	_add_box(room, Vector2(752, 436), 46, 46, 40, Color(0.42, 0.46, 0.52), Color(0.34, 0.38, 0.44))
	_add_box(room, Vector2(908, 436), 46, 46, 40, Color(0.42, 0.46, 0.52), Color(0.34, 0.38, 0.44))
	# Desk under the window.
	_add_box(room, Vector2(940, 386), 130, 60, 26, Color(0.52, 0.40, 0.28), Color(0.42, 0.32, 0.24))
	# Floor lamp.
	_build_lamp()


func _build_lamp() -> void:
	var lamp := Node2D.new()
	lamp.position = Vector2(950, 470)
	_poly(lamp, PackedVector2Array([
		Vector2(-2, -120), Vector2(2, -120), Vector2(2, 0), Vector2(-2, 0),
	]), Color(0.30, 0.28, 0.26))
	_rect(lamp, Rect2(-14, -2, 28, 6), Color(0.32, 0.30, 0.28))
	_poly(lamp, PackedVector2Array([
		Vector2(-26, -120), Vector2(26, -120), Vector2(18, -150), Vector2(-18, -150),
	]), Color(1.0, 0.82, 0.55, 0.95))
	room.add_child(lamp)


# ---------------------------------------------------------------------------
# Interactables
# ---------------------------------------------------------------------------

func _register(id: String, node: Node2D, prompt: String, text: String, radius: float) -> void:
	interactables.append(InteractableEntry.new(id, node, prompt, text, radius))


func _build_interactables() -> void:
	# Phone on the coffee table.
	var phone := _add_box(room, Vector2(430, 468), 34, 16, 6, Color(0.12, 0.12, 0.15), Color(0.08, 0.08, 0.10))
	_rect(phone, Rect2(-13, -13, 26, 10), Color(0.55, 0.70, 0.95, 0.9))
	_register("phone", phone, "手机", "林夏：我在你楼下。", 95.0)

	# Front door on the back wall.
	var door := Node2D.new()
	door.position = Vector2(290, 300)
	_poly(door, PackedVector2Array([
		Vector2(-33, -205), Vector2(33, -205), Vector2(33, 0), Vector2(-33, 0),
	]), Color(0.33, 0.26, 0.20))
	_poly(door, PackedVector2Array([
		Vector2(-40, -210), Vector2(-33, -210), Vector2(-33, 0), Vector2(-40, 0),
	]), Color(0.42, 0.34, 0.26))
	_poly(door, PackedVector2Array([
		Vector2(33, -210), Vector2(40, -210), Vector2(40, 0), Vector2(33, 0),
	]), Color(0.42, 0.34, 0.26))
	_rect(door, Rect2(20, -105, 5, 5), Color(0.85, 0.78, 0.60))
	walls.add_child(door)
	_register("door", door, "门", "门外只有雨声。", 105.0)

	# Laptop on the desk.
	var laptop := _add_box(room, Vector2(940, 372), 44, 26, 4, Color(0.16, 0.16, 0.20), Color(0.12, 0.12, 0.15))
	_poly(laptop, PackedVector2Array([
		Vector2(-20, -26), Vector2(20, -26), Vector2(20, 0), Vector2(-20, 0),
	]), Color(0.13, 0.15, 0.20))
	_rect(laptop, Rect2(-17, -23, 30, 16), Color(0.10, 0.12, 0.16))
	_register("laptop", laptop, "笔记本", "你的个人电脑，屏幕暗着。", 95.0)

	# Framed photo on the back wall.
	var photo := Node2D.new()
	photo.position = Vector2(615, 300)
	_poly(photo, PackedVector2Array([
		Vector2(-28, -78), Vector2(28, -78), Vector2(28, 0), Vector2(-28, 0),
	]), Color(0.44, 0.36, 0.28))
	_poly(photo, PackedVector2Array([
		Vector2(-23, -72), Vector2(23, -72), Vector2(23, -6), Vector2(-23, -6),
	]), Color(0.62, 0.60, 0.58))
	walls.add_child(photo)
	_register("photo", photo, "照片", "一张有些褪色的合影。", 105.0)


func _build_boundary() -> void:
	_add_wall(self, Vector2(220, 300), Vector2(1060, 300), 8.0)
	_add_wall(self, Vector2(220, 300), Vector2(130, 660), 8.0)
	_add_wall(self, Vector2(1060, 300), Vector2(1150, 660), 8.0)
	_add_wall(self, Vector2(130, 660), Vector2(1150, 660), 8.0)


# ---------------------------------------------------------------------------
# Player / UI setup
# ---------------------------------------------------------------------------

func _setup_player() -> void:
	player.position = Vector2(620, 570)


func _setup_ui() -> void:
	hint_label.text = "WASD / 方向键 移动 · E 交互"
	hint_label.anchor_left = 0.0
	hint_label.anchor_top = 1.0
	hint_label.anchor_right = 0.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = 24.0
	hint_label.offset_top = -42.0
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))

	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.72
	prompt_label.anchor_bottom = 0.72
	prompt_label.offset_left = -200.0
	prompt_label.offset_right = 200.0
	prompt_label.offset_top = -20.0
	prompt_label.offset_bottom = 20.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.visible = false

	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.anchor_top = 0.82
	message_label.anchor_bottom = 0.82
	message_label.offset_left = -480.0
	message_label.offset_right = 480.0
	message_label.offset_top = -24.0
	message_label.offset_bottom = 24.0
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.visible = false

	# 分支选项 UI（按 1/2/3 交互）
	choices_label = Label.new()
	choices_label.name = "Choices"
	choices_label.anchor_left = 0.5
	choices_label.anchor_right = 0.5
	choices_label.anchor_top = 0.80
	choices_label.anchor_bottom = 0.80
	choices_label.offset_left = -300.0
	choices_label.offset_right = 300.0
	choices_label.offset_top = -15.0
	choices_label.offset_bottom = 95.0
	choices_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choices_label.add_theme_font_size_override("font_size", 20)
	choices_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96, 0.95))
	choices_label.add_theme_constant_override("line_spacing", 8)
	choices_label.visible = false
	$UI.add_child(choices_label)

	# 全屏黑色遮罩与分支字幕展示
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	$UI.add_child(overlay)

	branch_text_label = Label.new()
	branch_text_label.name = "BranchText"
	branch_text_label.anchor_left = 0.5
	branch_text_label.anchor_right = 0.5
	branch_text_label.anchor_top = 0.45
	branch_text_label.anchor_bottom = 0.45
	branch_text_label.offset_left = -480.0
	branch_text_label.offset_right = 480.0
	branch_text_label.offset_top = -80.0
	branch_text_label.offset_bottom = 80.0
	branch_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	branch_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	branch_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	branch_text_label.add_theme_font_size_override("font_size", 22)
	branch_text_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
	branch_text_label.add_theme_constant_override("line_spacing", 16)
	overlay.add_child(branch_text_label)

	continue_hint_label = Label.new()
	continue_hint_label.name = "ContinueHint"
	continue_hint_label.anchor_left = 0.5
	continue_hint_label.anchor_right = 0.5
	continue_hint_label.anchor_top = 0.88
	continue_hint_label.anchor_bottom = 0.88
	continue_hint_label.offset_left = -200.0
	continue_hint_label.offset_right = 200.0
	continue_hint_label.offset_top = -15.0
	continue_hint_label.offset_bottom = 15.0
	continue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_hint_label.text = "按 E 或 空格 返回"
	continue_hint_label.add_theme_font_size_override("font_size", 16)
	continue_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	overlay.add_child(continue_hint_label)

	# Milestone 2: ELSE 全屏界面与布局
	else_overlay = ColorRect.new()
	else_overlay.name = "ElseOverlay"
	else_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	else_overlay.anchor_left = 0.0
	else_overlay.anchor_top = 0.0
	else_overlay.anchor_right = 1.0
	else_overlay.anchor_bottom = 1.0
	else_overlay.offset_left = 0.0
	else_overlay.offset_top = 0.0
	else_overlay.offset_right = 0.0
	else_overlay.offset_bottom = 0.0
	else_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	else_overlay.visible = false
	$UI.add_child(else_overlay)

	else_box = VBoxContainer.new()
	else_box.name = "ElseBox"
	else_box.anchor_left = 0.5
	else_box.anchor_right = 0.5
	else_box.anchor_top = 0.44
	else_box.anchor_bottom = 0.44
	else_box.offset_left = -360.0
	else_box.offset_right = 360.0
	else_box.offset_top = -170.0
	else_box.offset_bottom = 170.0
	else_box.alignment = BoxContainer.ALIGNMENT_CENTER
	else_box.add_theme_constant_override("separation", 22)
	else_overlay.add_child(else_box)

	else_title_label = Label.new()
	else_title_label.name = "Title"
	else_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else_title_label.text = "ELSE"
	else_title_label.add_theme_font_size_override("font_size", 28)
	else_title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	else_box.add_child(else_title_label)

	else_subtitle_label = Label.new()
	else_subtitle_label.name = "Subtitle"
	else_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else_subtitle_label.text = "Unresolved decision detected.\n重构另一种可能？"
	else_subtitle_label.add_theme_font_size_override("font_size", 19)
	else_subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	else_subtitle_label.add_theme_constant_override("line_spacing", 8)
	else_box.add_child(else_subtitle_label)

	else_options_label = Label.new()
	else_options_label.name = "Options"
	else_options_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else_options_label.text = "[ 1 ] RECONSTRUCT  重构\n[ 2 ] NOT NOW      暂不"
	else_options_label.add_theme_font_size_override("font_size", 20)
	else_options_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	else_options_label.add_theme_constant_override("line_spacing", 12)
	else_box.add_child(else_options_label)

	else_history_label = Label.new()
	else_history_label.name = "History"
	else_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else_history_label.text = ""
	else_history_label.add_theme_font_size_override("font_size", 15)
	else_history_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	else_box.add_child(else_history_label)

	else_hint_label = Label.new()
	else_hint_label.name = "ElseHint"
	else_hint_label.anchor_left = 0.5
	else_hint_label.anchor_right = 0.5
	else_hint_label.anchor_top = 0.88
	else_hint_label.anchor_bottom = 0.88
	else_hint_label.offset_left = -200.0
	else_hint_label.offset_right = 200.0
	else_hint_label.offset_top = -15.0
	else_hint_label.offset_bottom = 15.0
	else_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else_hint_label.text = "按 1 / 2 选择 · ESC 取消"
	else_hint_label.add_theme_font_size_override("font_size", 16)
	else_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	else_overlay.add_child(else_hint_label)


# ---------------------------------------------------------------------------
# Interaction, message and rain updates
# ---------------------------------------------------------------------------

func _update_interaction() -> void:
	var nearest: InteractableEntry = null
	var best := INF
	for entry in interactables:
		var distance := player.global_position.distance_to(entry.node.global_position)
		if distance <= entry.radius and distance < best:
			best = distance
			nearest = entry
	current = nearest
	if current != null:
		prompt_label.text = "E · " + current.prompt
		prompt_label.visible = true
	else:
		prompt_label.visible = false


func _update_message(delta: float) -> void:
	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			message_label.visible = false


func _show_message(text: String) -> void:
	message_label.anchor_top = 0.82
	message_label.anchor_bottom = 0.82
	message_label.text = text
	message_label.visible = true
	message_time = message_duration


func _open_choice() -> void:
	current_state = State.CHOICE
	prompt_label.visible = false
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	# 手机消息（置于选项上方）
	message_label.anchor_top = 0.71
	message_label.anchor_bottom = 0.71
	message_label.text = "林夏：我在你楼下。"
	message_label.visible = true
	message_time = 0.0

	# 三个分支选项
	choices_label.text = "[1] 下楼\n[2] 回复\n[3] 不回复"
	choices_label.visible = true
	hint_label.text = "按 1 / 2 / 3 做出选择 · ESC 取消"
	hint_label.visible = true


func _close_choice() -> void:
	current_state = State.NORMAL
	message_label.visible = false
	choices_label.visible = false
	hint_label.text = "WASD / 方向键 移动 · E 交互"
	player.set_physics_process(true)


func _select_choice(choice: Choice) -> void:
	made_choice = choice
	current_state = State.BRANCH_VIEW

	# 隐藏选择与提示界面
	message_label.visible = false
	choices_label.visible = false
	prompt_label.visible = false
	hint_label.visible = false

	# 分支字幕内容（分行显示叙述与台词）
	match choice:
		Choice.DOWN:
			branch_text_label.text = "你披上外套下楼。她站在单元门口，伞没撑开，发梢滴着水。\n林夏：「明天……你能陪我去车站吗？就这一次。」"
		Choice.REPLY:
			branch_text_label.text = "你回：「上来吧。」\n她进门，带着一身雨气，却没怎么说话。你倒水时发现，她的手机一直扣在桌上，屏幕分明还亮着。"
		Choice.IGNORE:
			branch_text_label.text = "你没有回复。后半夜你走到窗边，楼下的人影已经不见了。\n天亮时你在门口捡到一张被雨打湿的字条，只写着半句：「其实我明天要——」"

	# 显示全屏黑色遮罩
	overlay.visible = true


func _return_to_room() -> void:
	# 每完整看过一个分支演出就追加该分支名
	var branch_name := _get_choice_name(made_choice)
	if branch_name != "":
		seen_branches.append(branch_name)

	overlay.visible = false
	current_state = State.NORMAL
	hint_label.text = "WASD / 方向键 移动 · E 交互"
	hint_label.visible = true
	player.set_physics_process(true)


func _get_choice_name(c: Choice) -> String:
	match c:
		Choice.DOWN:
			return "下楼"
		Choice.REPLY:
			return "回复"
		Choice.IGNORE:
			return "不回复"
		_:
			return ""


func _open_else() -> void:
	current_state = State.ELSE
	prompt_label.visible = false
	message_label.visible = false
	hint_label.visible = false
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	# 去重列出已体验的分支
	var unique_branches: Array[String] = []
	for b in seen_branches:
		if not unique_branches.has(b):
			unique_branches.append(b)

	if unique_branches.is_empty():
		else_history_label.text = ""
		else_history_label.visible = false
	else:
		else_history_label.text = "已体验的分支：" + "、".join(unique_branches)
		else_history_label.visible = true

	else_box.visible = true
	else_hint_label.visible = true
	else_overlay.visible = true


func _close_else() -> void:
	if _is_reconstructing:
		return
	else_overlay.visible = false
	current_state = State.NORMAL
	hint_label.text = "WASD / 方向键 移动 · E 交互"
	hint_label.visible = true
	player.set_physics_process(true)


func _reconstruct() -> void:
	if _is_reconstructing:
		return
	_is_reconstructing = true

	# 隐藏文本内容，留出纯黑屏幕停顿约 0.8 秒
	else_box.visible = false
	else_hint_label.visible = false

	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return

	# 房间回到决策时刻，之前分支结果视为未发生
	reconstruct_count += 1
	_apply_reconstruct_anomalies()
	made_choice = Choice.NONE

	# 玩家瞬移到手机旁
	player.position = Vector2(430, 545)
	player.velocity = Vector2.ZERO

	else_overlay.visible = false
	else_box.visible = true
	else_hint_label.visible = true
	_is_reconstructing = false

	# 立即重新显示「林夏：我在你楼下。」+ 三个选项
	_open_choice()


func _apply_reconstruct_anomalies() -> void:
	for drop in _rain_anomaly:
		drop.visible = true
	for entry in interactables:
		if entry.id == "photo":
			entry.text = "一张有些褪色的合影。照片里的笑容，好像比记忆里淡了一点。"


func _update_rain(delta: float) -> void:
	for drop in _rain:
		drop.position.y += 130.0 * delta
		drop.position.x -= 16.0 * delta
		if drop.position.y > 262.0:
			drop.position.y = 124.0
			drop.position.x = randf_range(872.0, 1018.0)

	if reconstruct_count >= 1:
		for drop in _rain_anomaly:
			drop.position.y += 140.0 * delta
			drop.position.x -= 28.0 * delta
			if drop.position.y > 262.0:
				drop.position.y = 124.0
				drop.position.x = randf_range(920.0, 1022.0)