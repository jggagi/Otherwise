extends CharacterBody2D
## Protagonist sprite: per-direction idle/walk frames with a walk bob.
## Eight-directional WASD / arrow movement. The facing picks the closest
## of three views (front / back / side; the side view is mirrored for
## rightward movement). Walk frames are swapped on a timer and a subtle
## vertical bob sells the step; collision stays small for navigation.

@export var speed: float = 220.0

## 角色身高（游戏单位），按背景沙发/门 2.5D 投影标定。
const TARGET_HEIGHT := 200.0
## 脚底相对节点原点的落点（与旧占位脚位一致）。
const GROUND_Y := 2.0
## 走路帧切换间隔（秒）与步伐频率（Hz，用于身体起伏）。
const FRAME_TIME := 0.16
const STRIDE_HZ := 2.2
const BOB_AMOUNT := 2.2

var _shadow: Polygon2D
var _body: Sprite2D
var _idle: Dictionary = {}   # facing -> Texture2D
var _walk: Dictionary = {}   # facing -> Array[Texture2D]

var _facing: String = "front"
var _flip: bool = false
var _moving: bool = false
var _frame_timer: float = 0.0
var _frame_i: int = 0
var _phase: float = 0.0


func _ready() -> void:
	_idle = {
		"front": load("res://assets/player/player_front.png"),
		"back": load("res://assets/player/player_back.png"),
		"side": load("res://assets/player/player_side.png"),
	}
	# 目前只有正面有真走路帧；其余方向待配额恢复后补齐。
	_walk = {
		"front": [
			load("res://assets/player/walk_front_a.png"),
			load("res://assets/player/walk_front_b.png"),
		],
		"back": [],
		"side": [],
	}
	_build_body()


func _build_body() -> void:
	# Soft grounding shadow.
	_shadow = Polygon2D.new()
	_shadow.polygon = _circle_points(34.0, 24)
	_shadow.color = Color(0.0, 0.0, 0.0, 0.26)
	_shadow.position = Vector2(0.0, 7.0)
	add_child(_shadow)

	# Character sprite (frames managed by _show_texture).
	_body = Sprite2D.new()
	_body.name = "Body"
	add_child(_body)
	_show_texture(_idle["front"], false, 0.0)

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

	_moving = direction.length_squared() > 0.0
	var bob := 0.0
	if _moving:
		direction = direction.normalized()
		_update_facing(direction)
		_advance_walk(delta)
		_phase += delta * STRIDE_HZ * TAU
		bob = -absf(sin(_phase)) * BOB_AMOUNT
		# 侧面走路轻微前倾；纵向时细微左右晃。
		if _facing == "side":
			_body.rotation = lerp(_body.rotation, 0.04, 0.2)
		# 阴影随步伐轻微脉动。
		var pulse := 1.0 + 0.05 * absf(sin(_phase))
		_shadow.scale = Vector2(pulse, pulse)
	else:
		_set_idle()
		_body.rotation = lerp(_body.rotation, 0.0, 0.2)
		_shadow.scale = _shadow.scale.lerp(Vector2.ONE, 0.2)

	var tex: Texture2D = _body.texture
	if tex != null:
		var k: float = TARGET_HEIGHT / tex.get_height()
		_body.scale = Vector2(k, k)
		_body.position = Vector2(0.0, GROUND_Y - tex.get_height() * k * 0.5 + bob)

	velocity = direction * speed
	move_and_slide()


## 切换贴图（含镜像），并按其自身高度等比缩放、脚底对齐。
func _show_texture(tex: Texture2D, flip: bool, bob: float) -> void:
	if tex == null or _body == null:
		return
	_body.texture = tex
	_body.flip_h = flip
	_flip = flip
	var k: float = TARGET_HEIGHT / tex.get_height()
	_body.scale = Vector2(k, k)
	_body.position = Vector2(0.0, GROUND_Y - tex.get_height() * k * 0.5 + bob)


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
		_show_texture(_idle[_facing], _flip, 0.0)
	else:
		_body.flip_h = _flip


## 走路帧推进：有真帧时定时切换；无帧时保持待机（靠起伏表现）。
func _advance_walk(delta: float) -> void:
	var frames: Array = _walk[_facing]
	if frames.size() < 2:
		return
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame_i = (_frame_i + 1) % frames.size()
		_show_texture(frames[_frame_i], _flip, 0.0)


## 停下：回到当前方向待机帧。
func _set_idle() -> void:
	if _frame_i != 0 or _body.texture != _idle[_facing]:
		_frame_i = 0
		_frame_timer = 0.0
		_show_texture(_idle[_facing], _flip, 0.0)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
