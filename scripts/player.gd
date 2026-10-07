extends CharacterBody2D
## Temporary protagonist placeholder: a muted quarter-view sprite.
## Eight-directional WASD / arrow movement on a fixed camera.

@export var speed: float = 220.0


func _ready() -> void:
	_build_body()


func _build_body() -> void:
	# Soft grounding shadow.
	var shadow := Polygon2D.new()
	shadow.polygon = _circle_points(16.0, 24)
	shadow.color = Color(0.0, 0.0, 0.0, 0.26)
	shadow.position = Vector2(0.0, 7.0)
	add_child(shadow)

	# Torso.
	var torso := Polygon2D.new()
	torso.polygon = _rect_points(Vector2(-13.0, -27.0), Vector2(13.0, 2.0))
	torso.color = Color(0.32, 0.44, 0.46)
	add_child(torso)

	# Head.
	var head := Polygon2D.new()
	head.polygon = _circle_points(11.0, 20)
	head.color = Color(0.80, 0.66, 0.54)
	head.position = Vector2(0.0, -26.0)
	add_child(head)

	# Collision capsule (invisible).
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
	velocity = direction * speed
	move_and_slide()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _rect_points(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])