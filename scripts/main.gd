extends Node2D
## Otherwise — Milestone 0 (2D quarter-view).
## Builds the apartment stage box: warm interior walls/floor, a rainy city
## window, four interactables, the player and the minimal UI.

const VOID := Color(0.03, 0.045, 0.07)
const WALL_BACK := Color(0.55, 0.49, 0.43)
const WALL_SIDE := Color(0.44, 0.39, 0.34)
const FLOOR_WOOD := Color(0.34, 0.27, 0.20)
const FLOOR_SEAM := Color(0.30, 0.24, 0.17)
const WINDOW_SKY := Color(0.12, 0.16, 0.23)
const FRAME := Color(0.38, 0.33, 0.28)

@onready var player: CharacterBody2D = $Room/Player
@onready var walls: Node2D = $Walls
@onready var floor_node: Node2D = $Floor
@onready var room: Node2D = $Room
@onready var hint_label: Label = $UI/Hint
@onready var prompt_label: Label = $UI/Prompt
@onready var message_label: Label = $UI/Message

var interactables: Array[InteractableEntry] = []
var current: InteractableEntry = null
var message_time := 0.0
var message_duration := 3.5

var _rain: Array[Polygon2D] = []


class InteractableEntry:
	var node: Node2D
	var prompt: String
	var text: String
	var radius: float

	func _init(n: Node2D, p: String, t: String, r: float) -> void:
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
	_update_interaction()
	_update_message(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and current != null:
			_show_message(current.text)


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

func _register(node: Node2D, prompt: String, text: String, radius: float) -> void:
	interactables.append(InteractableEntry.new(node, prompt, text, radius))


func _build_interactables() -> void:
	# Phone on the coffee table.
	var phone := _add_box(room, Vector2(430, 468), 34, 16, 6, Color(0.12, 0.12, 0.15), Color(0.08, 0.08, 0.10))
	_rect(phone, Rect2(-13, -13, 26, 10), Color(0.55, 0.70, 0.95, 0.9))
	_register(phone, "手机", "林夏：我在你楼下。", 95.0)

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
	_register(door, "门", "门外只有雨声。", 105.0)

	# Laptop on the desk.
	var laptop := _add_box(room, Vector2(940, 372), 44, 26, 4, Color(0.16, 0.16, 0.20), Color(0.12, 0.12, 0.15))
	_poly(laptop, PackedVector2Array([
		Vector2(-20, -26), Vector2(20, -26), Vector2(20, 0), Vector2(-20, 0),
	]), Color(0.13, 0.15, 0.20))
	_rect(laptop, Rect2(-17, -23, 30, 16), Color(0.10, 0.12, 0.16))
	_register(laptop, "笔记本", "你的个人电脑，屏幕暗着。", 95.0)

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
	_register(photo, "照片", "一张有些褪色的合影。", 105.0)


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
	message_label.offset_left = -360.0
	message_label.offset_right = 360.0
	message_label.offset_top = -24.0
	message_label.offset_bottom = 24.0
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.visible = false


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
	message_label.text = text
	message_label.visible = true
	message_time = message_duration


func _update_rain(delta: float) -> void:
	for drop in _rain:
		drop.position.y += 130.0 * delta
		drop.position.x -= 16.0 * delta
		if drop.position.y > 262.0:
			drop.position.y = 124.0
			drop.position.x = randf_range(872.0, 1018.0)