extends CharacterBody2D
@export var speed: float = 185.0
const TARGET_HEIGHT := 164.0
const FRAME_TIME := 0.23
var navigator: AStarGrid2D
var path: PackedVector2Array = []
var _body: Sprite2D
var _idle: Dictionary = {}
var _walk: Dictionary = {}
var _facing: String = "front"
var _flip: bool = false
var _moving_anim: bool = false
var _frame_timer: float = 0.0
var _frame_i: int = 0
var actually_moving: bool = false

func _ready() -> void:
	for facing in ["front", "back", "side"]:
		_idle[facing] = load("res://assets/player/player_%s.png" % facing)
		var frames: Array = []
		for suffix in ["a", "b"]:
			var source := "res://assets/player/walk_%s_%s.png" % [facing, suffix]
			if ResourceLoader.exists(source):
				frames.append(load(source))
		_walk[facing] = frames
	if ResourceLoader.exists("res://assets/art_sources/player_back_walk_v1.png"):
		for box in [Rect2(180,17,440,1071), Rect2(754,17,440,1071)]:
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://assets/art_sources/player_back_walk_v1.png")
			atlas.region = box
			_walk["back"].append(atlas)
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(24):
		points.append(Vector2(cos(TAU*i/24.0)*19, sin(TAU*i/24.0)*6))
	shadow.polygon = points
	shadow.color = Color(0.06,0.035,0.02,0.3)
	shadow.position.y = 2
	add_child(shadow)
	_body = Sprite2D.new()
	_body.name = "Body"
	add_child(_body)
	var collision := CollisionShape2D.new()
	collision.name = "FeetCollision"
	var capsule := CapsuleShape2D.new()
	capsule.radius = 10
	capsule.height = 20
	collision.shape = capsule
	add_child(collision)
	_show_frame()

func walk_to(target: Vector2) -> bool:
	if navigator == null:
		return false
	var cell := Vector2i((target/8.0).floor())
	var source := Vector2i((position/8.0).floor())
	if not navigator.is_in_boundsv(cell) or navigator.is_point_solid(cell):
		return false
	# Keyboard movement can stop between free cells next to a wall.
	# Start the route at a nearby free cell, then walk there without teleporting.
	if not navigator.is_in_boundsv(source) or navigator.is_point_solid(source):
		var nearest := source
		var distance := INF
		for x in range(source.x-2,source.x+3):
			for y in range(source.y-2,source.y+3):
				var candidate := Vector2i(x,y)
				if not navigator.is_in_boundsv(candidate) or navigator.is_point_solid(candidate): continue
				var gap := position.distance_squared_to(navigator.get_point_position(candidate))
				if gap<distance:
					distance = gap
					nearest = candidate
		if distance==INF: return false
		source = nearest
	path = navigator.get_point_path(source,cell)
	return not path.is_empty()

func stop() -> void:
	path.clear()
	velocity = Vector2.ZERO
	actually_moving = false
	_set_idle()

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	if direction.length_squared()>0:
		path.clear()
	elif not path.is_empty():
		while not path.is_empty() and position.distance_to(path[0])<5:
			path.remove_at(0)
		if not path.is_empty():
			direction = position.direction_to(path[0])
	var before := position
	velocity = direction*speed
	move_and_slide()
	actually_moving = position.distance_squared_to(before)>0.05
	if actually_moving:
		_moving_anim = true
		_update_facing(position-before)
		_frame_timer += delta
		if _frame_timer>=FRAME_TIME:
			_frame_timer = 0
			_frame_i = (_frame_i+1)%maxi(1,_walk[_facing].size())
			_show_frame()
	else:
		_set_idle()

func _update_facing(direction: Vector2) -> void:
	var facing := "side" if absf(direction.x)>absf(direction.y) else ("back" if direction.y<0 else "front")
	_flip = facing=="side" and direction.x>0
	if facing!=_facing:
		_facing = facing
		_frame_i = 0
		_frame_timer = 0
	_show_frame()

func _set_idle() -> void:
	_moving_anim = false
	_frame_i = 0
	_frame_timer = 0
	if _body!=null:
		_show_frame()

func _show_frame() -> void:
	var texture: Texture2D = _idle[_facing]
	if _moving_anim and not _walk[_facing].is_empty():
		texture = _walk[_facing][_frame_i%_walk[_facing].size()]
	_body.texture = texture
	_body.flip_h = _flip
	var k := TARGET_HEIGHT/texture.get_height()
	_body.scale = Vector2.ONE*k
	_body.position = Vector2(0,-TARGET_HEIGHT*0.5+2)
