extends CharacterBody2D
## Protagonist sprite: per-direction idle/walk frames.
## Eight-directional WASD / arrow movement. The facing picks the closest
## of three views (front / back / side; the side view is mirrored for
## rightward movement). Walk frames are pre-aligned in the art pipeline
## (identical canvas, silhouette-IoU anchored), so swapping them never
## slides or resizes the body. Collision stays small for navigation.

@export var speed: float = 220.0

## 角色身高（游戏单位），按背景沙发/门 2.5D 投影标定。
const TARGET_HEIGHT := 200.0
## 脚底相对节点原点的落点（与旧占位脚位一致）。
const GROUND_Y := 2.0
## 走路帧切换间隔（秒）。
const FRAME_TIME := 0.22

var _shadow: Polygon2D
var _body: Sprite2D
var _idle: Dictionary = {}   # facing -> Texture2D
var _walk: Dictionary = {}   # facing -> Array[Texture2D]

var _facing: String = "front"
var _flip: bool = false
var _moving_anim: bool = false
var _frame_timer: float = 0.0
var _frame_i: int = 0


func _ready() -> void:
	_idle = {
		"front": load("res://assets/player/player_front.png"),
		"back": load("res://assets/player/player_back.png"),
		"side": load("res://assets/player/player_side.png"),
	}
	# 背面走路帧待配额恢复后补齐；补齐后填入数组即可，无需改逻辑。
	_walk = {
		"front": [
			load("res://assets/player/walk_front_a.png"),
			load("res://assets/player/walk_front_b.png"),
		],
		"back": [],
		"side": [
			load("res://assets/player/walk_side_a.png"),
			load("res://assets/player/walk_side_b.png"),
		],
	}
	_build_body()


func _build_body() -> void:
	# Soft grounding shadow (static).
	_shadow = Polygon2D.new()
	_shadow.polygon = _circle_points(34.0, 24)
	_shadow.color = Color(0.0, 0.0, 0.0, 0.26)
	_shadow.position = Vector2(0.0, 7.0)
	add_child(_shadow)

	# Character sprite (frames managed by _show_frame).
	_body = Sprite2D.new()
	_body.name = "Body"
	add_child(_body)
	_show_frame()

	# Collision capsule (invisible; kept small for navigation).
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13.0
	capsule.height = 36.0
	collision.shape = capsule
	add_child(collision)


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	var moving: bool = direction.length_squared() > 0.0
	if moving:
		direction = direction.normalized()
		_moving_anim = true
		_update_facing(direction)
		_advance_walk(delta)
	else:
		_set_idle()

	velocity = direction * speed
	move_and_slide()


## 按贴图当前高度等比缩放、脚底对齐。
func _show_frame() -> void:
	var tex: Texture2D
	if _moving_anim and (_walk[_facing].size() >= 2):
		tex = _walk[_facing][_frame_i]
	else:
		tex = _idle[_facing]
	if tex == null or _body == null:
		return
	_body.texture = tex
	_body.flip_h = _flip
	var k: float = TARGET_HEIGHT / float(tex.get_height())
	_body.scale = Vector2(k, k)
	_body.position = Vector2(0.0, GROUND_Y - float(tex.get_height()) * k * 0.5)


## 按移动方向取最近视角：横移用侧面（右移镜像），纵移用正面/背面。
func _update_facing(dir: Vector2) -> void:
	var new_facing := _facing
	if absf(dir.x) > absf(dir.y):
		new_facing = "side"
		_flip = dir.x > 0.0
	elif dir.y < 0.0:
		new_facing = "back"
		_flip = false
	else:
		new_facing = "front"
		_flip = false
	if new_facing != _facing:
		_facing = new_facing
		_frame_i = 0
		_frame_timer = 0.0
		_show_frame()
	else:
		_body.flip_h = _flip


## 走路帧推进：定时循环切换。
func _advance_walk(delta: float) -> void:
	if _walk[_facing].size() < 2:
		return
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer -= FRAME_TIME
		_frame_i = (_frame_i + 1) % _walk[_facing].size()
		_show_frame()


## 停下：回到当前方向待机帧。
func _set_idle() -> void:
	_moving_anim = false
	_frame_i = 0
	_frame_timer = 0.0
	_show_frame()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
