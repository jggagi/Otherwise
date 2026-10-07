extends CharacterBody2D
## Protagonist: Antigravity-generated 3-view sprite (front / back / side).
## Eight-directional WASD / arrow movement on a fixed camera.
## Facing picks the closest of the three views; the side view is
## mirrored for rightward movement. Collision stays small on purpose
## so the cramped apartment remains navigable.

@export var speed: float = 220.0

## 角色身高（游戏单位），按背景沙发/门屏幕高度做 2.5D 投影标定。
const TARGET_HEIGHT := 200.0
## 脚底相对节点原点的落点（与旧占位脚位一致）。
const GROUND_Y := 2.0

var _body: Sprite2D
var _tex_front: Texture2D
var _tex_back: Texture2D
var _tex_side: Texture2D


func _ready() -> void:
	_tex_front = load("res://assets/player/player_front.png")
	_tex_back = load("res://assets/player/player_back.png")
	_tex_side = load("res://assets/player/player_side.png")
	_build_body()


func _build_body() -> void:
	# Soft grounding shadow.
	var shadow := Polygon2D.new()
	shadow.polygon = _circle_points(34.0, 24)
	shadow.color = Color(0.0, 0.0, 0.0, 0.26)
	shadow.position = Vector2(0.0, 7.0)
	add_child(shadow)

	# Character sprite (facing managed by _set_facing).
	_body = Sprite2D.new()
	_body.name = "Body"
	add_child(_body)
	_set_facing(_tex_front, false)

	# Collision capsule (invisible; kept small for navigation).
	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13.0
	capsule.height = 36.0
	collision.shape = capsule
	add_child(collision)


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		_update_facing(direction)
	velocity = direction * speed
	move_and_slide()


## 切换朝向贴图：等比缩放到 TARGET_HEIGHT，脚底对齐 GROUND_Y。
func _set_facing(tex: Texture2D, flip: bool) -> void:
	if tex == null or _body == null:
		return
	if _body.texture == tex and _body.flip_h == flip:
		return
	_body.texture = tex
	_body.flip_h = flip
	var k: float = TARGET_HEIGHT / tex.get_height()
	_body.scale = Vector2(k, k)
	_body.position = Vector2(0.0, GROUND_Y - tex.get_height() * k * 0.5)


## 按移动方向取最近视角：横移用侧面（右移镜像），纵移用正面/背面。
func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_set_facing(_tex_side, dir.x > 0.0)
	elif dir.y < 0.0:
		_set_facing(_tex_back, false)
	else:
		_set_facing(_tex_front, false)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
