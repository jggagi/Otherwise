extends Node2D
## Otherwise — Milestone 3 (vertical slice: branch props, Anchors, the letter).
## Builds the apartment stage box: warm interior, a rainy city window,
## interactables, the player, ELSE interface and minimal UI.

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

# Milestone 3 新增：Choice -> Array[Node2D] 分支占位道具
var props_by_branch: Dictionary = {}

# Milestone 3 新增：Anchor id 列表（跨重构持久的知识）
var anchors: Array[String] = []
# Milestone 3 新增：「没拆开的信」惊悚时刻是否已在模拟中被透露
var letter_revealed: bool = false

# 重构异常节拍：模拟中林夏提到书架 → 返回现实，发圈真的在
var bookshelf_hinted: bool = false
var hair_tie_found: bool = false
var _hair_tie_node: Node2D

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
var else_anchor_label: Label
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
	_build_furniture()
	_build_bookshelf()
	_build_interactables()
	_build_props()
	_build_occluders()
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
# Physics helpers
# ---------------------------------------------------------------------------

func _add_obstacle(parent: Node, pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body


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
	var bg := Sprite2D.new()
	bg.name = "Background"
	var tex: Texture2D = load("res://assets/apartment_bg_v1.jpg")
	bg.texture = tex
	bg.position = Vector2(1152.0 * 0.5, 648.0 * 0.5)
	if tex != null:
		bg.scale = Vector2(1152.0 / tex.get_width(), 648.0 / tex.get_height())
	bg.z_index = -150
	add_child(bg)


func _build_walls() -> void:
	_build_rain()


func _build_rain() -> void:
	for i in range(16):
		var drop := Polygon2D.new()
		var dh := 8.0 + float(i % 4) * 4.0
		drop.polygon = PackedVector2Array([
			Vector2(-1.0, -dh * 0.5), Vector2(1.0, -dh * 0.5),
			Vector2(1.0, dh * 0.5), Vector2(-1.0, dh * 0.5),
		])
		drop.color = Color(0.62, 0.72, 0.9, 0.45)
		drop.position = Vector2(randf_range(935.0, 1080.0), randf_range(126.0, 260.0))
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
		drop.position = Vector2(randf_range(960.0, 1065.0), randf_range(126.0, 260.0))
		drop.visible = false
		walls.add_child(drop)
		_rain_anomaly.append(drop)


func _build_furniture() -> void:
	# 全部按背景图实际占地标定（坐标网格读数）。
	# 床（左，含床头；占地 x48..295）
	_add_obstacle(room, Vector2(171, 419), Vector2(247, 179))
	# 床尾长凳
	_add_obstacle(room, Vector2(338, 481), Vector2(97, 80))
	# 衣柜（后墙，柜体正面约 y330..420）
	_add_obstacle(room, Vector2(710, 374), Vector2(170, 88))
	# 茶几（地毯中央，带腿）
	_add_obstacle(room, Vector2(528, 467), Vector2(95, 68))
	# 沙发（中右，x642..799）
	_add_obstacle(room, Vector2(720, 508), Vector2(157, 80))
	# 落地灯（沙发右侧）
	_add_obstacle(room, Vector2(805, 528), Vector2(46, 36))
	# 书桌（右前）
	_add_obstacle(room, Vector2(921, 452), Vector2(162, 92))


## 后墙照片下方：开放式木书架（Antigravity 生成精灵）。
## 前沿碰撞贴墙根，玩家无法绕到书架背面，不需要遮挡精灵。
## 发圈是书架精灵的子节点（跟随 YSort），位于最下层隔板，默认隐藏。
func _build_bookshelf() -> void:
	const SHELF_ANCHOR := Vector2(440.0, 312.0)
	const SHELF_WIDTH := 70.0

	var shelf := Sprite2D.new()
	shelf.name = "Bookshelf"
	shelf.texture = load("res://assets/props/prop_bookshelf.png")
	var k: float = SHELF_WIDTH / float(shelf.texture.get_width())
	shelf.scale = Vector2(k, k)
	var drawn_h: float = float(shelf.texture.get_height()) * k
	# 纹理 bbox 下沿 = 书架最靠前的下角，对齐 YSort 锚点。
	shelf.position = SHELF_ANCHOR - Vector2(0.0, drawn_h * 0.5)
	room.add_child(shelf)

	# 发圈：书架子节点（父级有缩放，position 为纹理本地坐标）。
	# 最下层隔板测定点 = 纹理 (324,748)，换算为相对纹理中心的偏移。
	var tie := Sprite2D.new()
	tie.name = "PropHairTie"
	tie.texture = load("res://assets/props/prop_hair_tie.png")
	var tk: float = 12.0 / float(tie.texture.get_width())
	tie.scale = Vector2(tk / k, tk / k)   # 抵消父级缩放，保证最终尺寸
	tie.position = Vector2(324.0, 748.0) - Vector2(
		float(shelf.texture.get_width()) * 0.5, float(shelf.texture.get_height()) * 0.5)
	tie.visible = false
	shelf.add_child(tie)
	_hair_tie_node = tie

	# 前沿浅碰撞（贴着墙根，背面不可达）。
	_add_obstacle(room, Vector2(SHELF_ANCHOR.x, 306.0), Vector2(64.0, 20.0))


# ---------------------------------------------------------------------------
# Milestone 3: branch props (Antigravity-generated sprites, hidden by default)
# ---------------------------------------------------------------------------

## 造一个道具精灵：加载纹理，等比缩放进 target 框，居中于 pos。
func _make_prop_sprite(tex_path: String, pos: Vector2, target: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	var tex: Texture2D = load(tex_path)
	s.texture = tex
	if tex != null:
		var k: float = minf(target.x / tex.get_width(), target.y / tex.get_height())
		s.scale = Vector2(k, k)
	s.position = pos
	return s


func _build_props() -> void:
	# 回复分支：门口多一双鞋
	var reply_shoes := _make_prop_sprite("res://assets/props/prop_shoes.png", Vector2(250, 352), Vector2(34, 30))
	reply_shoes.name = "PropShoes"
	reply_shoes.visible = false
	room.add_child(reply_shoes)

	# 回复分支：茶几上的第二个杯子
	var reply_mug := _make_prop_sprite("res://assets/props/prop_mug.png", Vector2(545, 422), Vector2(13, 15))
	reply_mug.name = "PropMug"
	reply_mug.visible = false
	room.add_child(reply_mug)

	# 回复分支：门口湿伞（带水渍）
	var reply_umbrella := _make_wet_umbrella()
	reply_umbrella.name = "PropWetUmbrella"
	room.add_child(reply_umbrella)

	# 下楼分支：门口一把没撑开的伞靠墙
	var down_umbrella := _make_prop_sprite("res://assets/props/prop_umbrella_dry.png", Vector2(225, 320), Vector2(27, 66))
	down_umbrella.name = "PropDownUmbrella"
	down_umbrella.visible = false
	room.add_child(down_umbrella)

	# 不回复分支：门口地上被雨打湿的字条
	var ignore_note := _make_prop_sprite("res://assets/props/prop_note.png", Vector2(245, 356), Vector2(28, 23))
	ignore_note.name = "PropNote"
	ignore_note.visible = false
	room.add_child(ignore_note)

	props_by_branch = {
		Choice.REPLY: [reply_shoes, reply_mug, reply_umbrella],
		Choice.DOWN: [down_umbrella],
		Choice.IGNORE: [ignore_note],
	}


## 门口湿伞：收拢伞精灵（自带约 20° 倚靠倾角）+ 底部一摊水渍。
func _make_wet_umbrella() -> Node2D:
	var g := Node2D.new()
	g.position = Vector2(225, 320)
	var sprite := _make_prop_sprite("res://assets/props/prop_umbrella_wet.png", Vector2.ZERO, Vector2(30, 66))
	g.add_child(sprite)

	var puddle := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(Vector2(cos(a) * 16.0 - 9.0, sin(a) * 5.0 + 31.0))
	puddle.polygon = pts
	puddle.color = Color(0.45, 0.58, 0.78, 0.40)
	g.add_child(puddle)

	g.visible = false
	return g


## 隐藏全部道具，再显示指定分支的道具（Choice.NONE 表示清空）。
func _apply_branch_props(choice: Choice) -> void:
	for prop_list in props_by_branch.values():
		for p in prop_list:
			p.visible = false
	var chosen: Array = props_by_branch.get(choice, [])
	for p in chosen:
		p.visible = true


# ---------------------------------------------------------------------------
# Interactables
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Furniture occluders: same painted furniture re-drawn over the player via
# YSort when the player walks north of it (extracted from the background
# art by scripts/extract_occluders.ps1).
# ---------------------------------------------------------------------------

# 每件: 遮挡纹理 + 游戏内 bbox (x, y, w, h)，坐标由提取脚本打印。
const OCC_SCALE := Vector2(1152.0 / 1376.0, 648.0 / 768.0)

func _build_occluders() -> void:
	var pieces := [
		{ "tex": "res://assets/occluders/occ_bed.png", "box": Rect2(48.6, 315.6, 246.1, 178.9) },
		{ "tex": "res://assets/occluders/occ_bench.png", "box": Rect2(290.5, 440.4, 96.3, 80.2) },
		{ "tex": "res://assets/occluders/occ_table.png", "box": Rect2(476.4, 390.7, 103.8, 103.8) },
		{ "tex": "res://assets/occluders/occ_sofa.png", "box": Rect2(642.1, 418.5, 156.6, 109.7) },
		{ "tex": "res://assets/occluders/occ_desk.png", "box": Rect2(840.6, 388.1, 161.6, 92.0) },
	]
	for piece in pieces:
		var box: Rect2 = piece["box"]
		var wrapper := Node2D.new()
		wrapper.name = "Occluder"
		# YSort 排序锚点 = 家具前沿（y 最大处）。
		wrapper.position = Vector2(box.position.x + box.size.x * 0.5, box.position.y + box.size.y)
		var sprite := Sprite2D.new()
		sprite.texture = load(piece["tex"])
		sprite.scale = OCC_SCALE
		sprite.position = Vector2(0.0, -box.size.y * 0.5)
		wrapper.add_child(sprite)
		room.add_child(wrapper)


func _register(id: String, node: Node2D, prompt: String, text: String, radius: float) -> void:
	interactables.append(InteractableEntry.new(id, node, prompt, text, radius))


func _build_interactables() -> void:
	# 手机（背景图茶几在中央偏左约 (500,450)，热区改 (500,455)，半径 95）
	var phone := Node2D.new()
	phone.name = "Phone"
	phone.position = Vector2(500, 455)
	room.add_child(phone)
	_register("phone", phone, "手机", "林夏：我在你楼下。", 95.0)

	# 门（背景图门在左后墙，门板约 (175,140)，热区改 (180,325)，半径 105）
	var door := Node2D.new()
	door.name = "Door"
	door.position = Vector2(175, 335)
	walls.add_child(door)
	_register("door", door, "门", "门外只有雨声。", 105.0)

	# 笔记本（标定 (960,435) 压书桌桌面，热区放桌面中心，半径 95）
	var laptop := Node2D.new()
	laptop.name = "Laptop"
	laptop.position = Vector2(940, 440)
	room.add_child(laptop)
	_register("laptop", laptop, "笔记本", "你的个人电脑，屏幕暗着。", 95.0)

	# 相框（背景图相框在中左墙约 (415,195)，热区改 (415,335)，半径 95）
	var photo := Node2D.new()
	photo.name = "Photo"
	photo.position = Vector2(415, 335)
	walls.add_child(photo)
	_register("photo", photo, "照片", "一张有些褪色的合影。", 95.0)

	# 信（书桌左前角，标定 (898,415)，半径 80；信封精灵常显）
	var letter := Node2D.new()
	letter.name = "Letter"
	letter.position = Vector2(898, 415)
	var envelope := _make_prop_sprite("res://assets/props/prop_envelope.png", Vector2.ZERO, Vector2(24, 18))
	letter.add_child(envelope)
	room.add_child(letter)
	_register("letter", letter, "信", "一封没拆开的信，压在桌角。", 80.0)

	# 书架（后墙照片下方，锚点 (440,312)，半径 64）
	var bookshelf := Node2D.new()
	bookshelf.name = "BookshelfAnchor"
	bookshelf.position = Vector2(440, 312)
	room.add_child(bookshelf)
	_register("bookshelf", bookshelf, "书架", "旧书架，塞着大学时的书。", 64.0)


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

	# Milestone 3: 金色 Anchor 展示（仅在获得后可见）
	else_anchor_label = Label.new()
	else_anchor_label.name = "Anchor"
	else_anchor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else_anchor_label.text = ""
	else_anchor_label.add_theme_font_size_override("font_size", 16)
	else_anchor_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	else_anchor_label.add_theme_constant_override("line_spacing", 6)
	else_anchor_label.visible = false
	else_box.add_child(else_anchor_label)

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

	# 分支字幕内容（基础文本 + Anchor / 信等叠加，集中于 _branch_text）
	branch_text_label.text = _branch_text(choice)

	# 显示全屏黑色遮罩
	overlay.visible = true


## 分支演出文本：基础文本 + 叠加（Anchor 领悟行 → 重构中的「信」台词）。
func _branch_text(choice: Choice) -> String:
	var text := ""
	match choice:
		Choice.DOWN:
			text = "你披上外套下楼。她站在单元门口，伞没撑开，发梢滴着水。\n林夏：「明天……你能陪我去车站吗？就这一次。」"
		Choice.REPLY:
			text = "你回：「上来吧。」\n她进门，带着一身雨气，却没怎么说话。你倒水时发现，她的手机一直扣在桌上，屏幕分明还亮着。"
		Choice.IGNORE:
			text = "你没有回复。后半夜你走到窗边，楼下的人影已经不见了。\n天亮时你在门口捡到一张被雨打湿的字条，只写着半句：「其实我明天要——」"

	# 叠加：Anchor 领悟行（已有 Anchor 时的内心独白）
	if anchors.has("fear_of_tomorrow"):
		text += "\n你忽然明白：她不是在等一个答复，她是在害怕明天。"
	# 节拍：
	# 第一次重构·回复：林夏指出桌上未拆的信（信节拍）
	# 第二次重构·回复：林夏提到书架下层（书架异常节拍）
	if reconstruct_count >= 1 and choice == Choice.REPLY and not letter_revealed:
		text += "\n林夏：「……你桌上那封信，一直没拆开吧。」"
		letter_revealed = true
	elif reconstruct_count >= 2 and choice == Choice.REPLY and not bookshelf_hinted:
		text += "\n林夏：「你书柜最下面那层，还有我的东西。」"
		bookshelf_hinted = true
	return text


## 去重后体验过 ≥2 个分支时获得 fear_of_tomorrow Anchor（仅一次）。
func _maybe_earn_anchor() -> void:
	if anchors.has("fear_of_tomorrow"):
		return
	var unique_branches: Array[String] = []
	for b in seen_branches:
		if not unique_branches.has(b):
			unique_branches.append(b)
	if unique_branches.size() >= 2:
		anchors.append("fear_of_tomorrow")


func _return_to_room() -> void:
	# 每完整看过一个分支演出就追加该分支名
	var branch_name := _get_choice_name(made_choice)
	if branch_name != "":
		seen_branches.append(branch_name)
	_maybe_earn_anchor()

	overlay.visible = false
	current_state = State.NORMAL
	hint_label.text = "WASD / 方向键 移动 · E 交互"
	hint_label.visible = true
	player.set_physics_process(true)

	# 房间反映刚看过的分支留下的痕迹
	_apply_branch_props(made_choice)
	_update_letter_text()
	_update_bookshelf()


## 信被模拟中的林夏指认后，真实房间里的信变为惊悚确认文本。
func _update_letter_text() -> void:
	if not letter_revealed:
		return
	for entry in interactables:
		if entry.id == "letter":
			entry.text = "封口完好，从未拆开。可你盯着它，后背发凉——\nELSE 是怎么知道它在这里的？"


## 书架异常：模拟中的台词听过之后，真实书架最下层出现发圈。
func _update_bookshelf() -> void:
	if not bookshelf_hinted or hair_tie_found:
		return
	hair_tie_found = true
	if _hair_tie_node != null:
		_hair_tie_node.visible = true
	for entry in interactables:
		if entry.id == "bookshelf":
			entry.prompt = "书架下层"
			entry.text = "最下层隔板上，静静躺着一枚发圈。\n是她的。可你从没见她碰过这个书架——ELSE 的数据里，也不该有它。"


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

	# Anchor（金色，置于已体验分支下方）
	if anchors.is_empty():
		else_anchor_label.visible = false
	else:
		else_anchor_label.text = "ANCHOR\n她不是因为你没有下楼而生气。\n她是在害怕明天。"
		else_anchor_label.visible = true

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
	_apply_branch_props(Choice.NONE)
	made_choice = Choice.NONE

	# 玩家瞬移到手机旁
	player.position = Vector2(500, 545)
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
			drop.position.x = randf_range(935.0, 1080.0)

	if reconstruct_count >= 1:
		for drop in _rain_anomaly:
			drop.position.y += 140.0 * delta
			drop.position.x -= 28.0 * delta
			if drop.position.y > 262.0:
				drop.position.y = 124.0
				drop.position.x = randf_range(960.0, 1065.0)