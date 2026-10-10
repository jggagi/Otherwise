extends Node2D
## Geometry and art have no narrative state ownership.
const PLAYER = preload("res://scripts/player.gd")
var room: Node2D
var player: CharacterBody2D
var interactables: Array[Dictionary] = []
var branch_props: Dictionary = {}
var rain: Array[Line2D] = []
var npc: Node2D
var npc_sprite: Sprite2D
var tie: Sprite2D
var phone_glow: Polygon2D
var laptop_glow: Polygon2D
var active_branch: int = 0
var simulation: bool = false
var _clock: float = 0.0
var _table: Node2D
var _desk: Node2D
var current: Dictionary = {}
var _background: Sprite2D
var in_entrance: bool = false
var _hidden_for_entrance: Dictionary = {}
var _apartment_player_pos: Vector2

func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = load("res://assets/apartment_bg_v1.jpg")
	background.position = Vector2(576,324)
	background.scale = Vector2(1152.0/background.texture.get_width(),648.0/background.texture.get_height())
	background.z_index = -100
	_background = background
	add_child(background)
	room = Node2D.new()
	room.name = "Room"
	room.y_sort_enabled = true
	add_child(room)
	_build_physics()
	_build_occluders()
	_build_props()
	_build_shelf()
	_build_rain()
	_register("phone","手机",Vector2(603,475),78)
	_register("door","门",Vector2(245,335),72)
	_register("laptop","电脑",Vector2(940,440),86)
	_register("photo","照片",Vector2(400,336),65)
	_register("letter","信",Vector2(869,432),58)
	_register("bookshelf","书架",Vector2(440,312),62)
	_register("umbrella","伞",Vector2(240,340),62,[1,2])
	_register("shoes","鞋",Vector2(266,363),52,[2])
	_register("mug","第二个杯子",Vector2(552,468),60,[2])
	_register("note","字条",Vector2(250,361),52,[3])
	player = CharacterBody2D.new()
	player.name = "Player"
	player.set_script(PLAYER)
	room.add_child(player)
	player.position = Vector2(605,570)
	_build_npc()
	phone_glow = _glow(Vector2(603,435),Color(0.8,0.9,1,0.28))
	phone_glow.polygon = PackedVector2Array([Vector2(-13,-5),Vector2(13,-5),Vector2(13,5),Vector2(-13,5)])
	phone_glow.reparent(_table,true)
	laptop_glow = _glow(Vector2(964,405),Color(0.8,0.85,0.9,0.22))
	laptop_glow.visible = false
	call_deferred("_build_navigation")

func _register(id: String,title: String,pos: Vector2,radius: float,branches: Array = []) -> void:
	interactables.append({"id":id,"title":title,"pos":pos,"radius":radius,"branches":branches})

func _polygon_obstacle(points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	add_child(body)

func _rect_obstacle(pos: Vector2,size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _wall(a: Vector2,b: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = (a+b)*0.5
	body.rotation = (b-a).angle()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(a.distance_to(b),8)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_physics() -> void:
	_wall(Vector2(218,302),Vector2(1060,302))
	_wall(Vector2(218,302),Vector2(128,620))
	_wall(Vector2(1060,302),Vector2(1105,576))
	_wall(Vector2(128,620),Vector2(576,625))
	_wall(Vector2(576,625),Vector2(1105,576))
	_polygon_obstacle(PackedVector2Array([Vector2(52,409),Vector2(110,410),Vector2(288,452),Vector2(275,496),Vector2(52,451)]))
	_rect_obstacle(Vector2(339,497),Vector2(88,46))
	_rect_obstacle(Vector2(710,371),Vector2(168,86))
	_rect_obstacle(Vector2(583,495),Vector2(94,42))
	_rect_obstacle(Vector2(720,506),Vector2(149,54))
	_rect_obstacle(Vector2(804,525),Vector2(28,27))
	_rect_obstacle(Vector2(921,460),Vector2(156,47))
	_rect_obstacle(Vector2(440,307),Vector2(62,18))

func _sprite(source: String,pos: Vector2,target: Vector2,parent: Node) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(source)
	var k := minf(target.x/sprite.texture.get_width(),target.y/sprite.texture.get_height())
	sprite.scale = Vector2.ONE*k
	sprite.position = pos
	parent.add_child(sprite)
	return sprite

func _build_occluders() -> void:
	var pieces := [
		["bed",Rect2(48.6,315.6,246.1,178.9)],
		["bench",Rect2(290.5,440.4,96.3,80.2)],
		["table",Rect2(533,391,104,128)],
		["sofa",Rect2(642.1,418.5,156.6,109.7)],
		["desk",Rect2(840.6,388.1,161.6,92.0)]
	]
	for piece in pieces:
		var box: Rect2 = piece[1]
		var wrapper := Node2D.new()
		wrapper.name = "Occluder_"+piece[0]
		wrapper.position = Vector2(box.get_center().x,box.end.y)
		room.add_child(wrapper)
		if piece[0]=="table":
			_table = wrapper
			var mask := Polygon2D.new()
			var silhouette := PackedVector2Array([Vector2(543,391),Vector2(629,395),Vector2(637,422),Vector2(632,517),Vector2(621,519),Vector2(621,477),Vector2(550,477),Vector2(550,517),Vector2(533,517),Vector2(533,421)])
			var polygon := PackedVector2Array()
			var uv := PackedVector2Array()
			for point in silhouette:
				polygon.append(point-wrapper.position)
				uv.append(point*Vector2(1376.0/1152,768.0/648))
			mask.polygon = polygon
			mask.uv = uv
			mask.texture = load("res://assets/apartment_bg_v1.jpg")
			wrapper.add_child(mask)
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/occluders/occ_%s.png"%piece[0])
		sprite.scale = Vector2(1152.0/1376.0,648.0/768.0)
		sprite.position = Vector2(0,-box.size.y*0.5)
		wrapper.add_child(sprite)
		if piece[0]=="table":
			_table = wrapper
		elif piece[0]=="desk":
			_desk = wrapper

func _build_props() -> void:
	var dry := _sprite("res://assets/props/prop_umbrella_dry.png",Vector2(235,324),Vector2(24,61),room)
	var wet := _sprite("res://assets/props/prop_umbrella_wet.png",Vector2(235,324),Vector2(27,61),room)
	var shoes := _sprite("res://assets/props/prop_shoes.png",Vector2(267,359),Vector2(32,25),room)
	var mug := _sprite("res://assets/props/prop_mug.png",Vector2(545,422)-_table.position,Vector2(14,17),_table)
	var note := _sprite("res://assets/props/prop_note.png",Vector2(252,361),Vector2(26,20),room)
	_sprite("res://assets/props/prop_envelope.png",Vector2(891,420)-_desk.position,Vector2(27,19),_desk)
	branch_props = {1:[dry],2:[wet,shoes,mug],3:[note]}
	apply_branch(0)
	if ResourceLoader.exists("res://assets/art_sources/photo_together_v1.png"):
		var photo := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/art_sources/photo_together_v1.png")
		atlas.region = Rect2(160,180,794,1006)
		photo.texture = atlas
		photo.position = Vector2(451,155)
		photo.scale = Vector2(30.0/794,38.0/1006)
		photo.z_index = -50
		add_child(photo)

func _build_shelf() -> void:
	var shelf := Node2D.new()
	shelf.position = Vector2(440,313)
	room.add_child(shelf)
	var body := _sprite("res://assets/props/prop_bookshelf.png",Vector2.ZERO,Vector2(70,180),shelf)
	body.position.y = -body.texture.get_height()*body.scale.y*0.5
	tie = _sprite("res://assets/props/prop_hair_tie.png",Vector2(3,-13),Vector2(10,6),shelf)
	# Exists under the books from the beginning; inspection makes it visible.
	tie.visible = false

func _build_npc() -> void:
	npc = Node2D.new()
	npc.name = "LinXia"
	room.add_child(npc)
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(20):
		points.append(Vector2(cos(TAU*i/20)*17,sin(TAU*i/20)*5))
	shadow.polygon = points
	shadow.color = Color(0,0,0,0.25)
	npc.add_child(shadow)
	npc_sprite = Sprite2D.new()
	npc.add_child(npc_sprite)
	npc.visible = false

func set_pose(pose: String) -> void:
	if pose=="" or pose=="corridor":
		return
	if pose=="empty":
		npc.visible = false
		return
	if not ResourceLoader.exists("res://assets/art_sources/lin_xia_poses_v1.png"):
		return
	var column := 1 if pose=="seated" else (2 if pose=="phone" else 0)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/art_sources/lin_xia_poses_v1.png")
	atlas.region = Rect2(column*512,0,512,1024)
	npc_sprite.texture = atlas
	var k := 164.0/978.0
	npc_sprite.scale = Vector2.ONE*k
	var anchor_x: float = [323,264,198][column]
	npc_sprite.position = Vector2((256-anchor_x)*k,(512-1005)*k)
	npc.position = Vector2(701,486) if column==1 else (Vector2(814,408) if column==2 else Vector2(612,415))
	if pose=="entry":
		npc.position = Vector2(292,356)
	if in_entrance:
		npc.position = Vector2(470,470)
	npc.visible = true

func set_location(entrance: bool) -> void:
	if entrance==in_entrance:
		return
	in_entrance = entrance
	var path := "res://assets/art_sources/entrance_rain_v1.png" if entrance else "res://assets/apartment_bg_v1.jpg"
	if ResourceLoader.exists(path):
		_background.texture = load(path)
		_background.scale = Vector2(1152.0/_background.texture.get_width(),648.0/_background.texture.get_height())
	if entrance:
		_apartment_player_pos = player.position
		player.position = Vector2(690,470)
		for node in room.get_children()+get_children():
			if node is CanvasItem and node not in [room,_background,player,npc]:
				_hidden_for_entrance[node] = node.visible
				node.visible = false
	else:
		player.position = _apartment_player_pos
		for node in _hidden_for_entrance:
			node.visible = _hidden_for_entrance[node]
		_hidden_for_entrance.clear()

func apply_branch(branch: int) -> void:
	active_branch = branch
	for key in branch_props:
		for prop in branch_props[key]:
			prop.visible = key==branch

func _glow(pos: Vector2,color: Color) -> Polygon2D:
	var glow := Polygon2D.new()
	glow.position = pos
	glow.polygon = PackedVector2Array([Vector2(-9,-4),Vector2(9,-4),Vector2(9,4),Vector2(-9,4)])
	glow.color = color
	add_child(glow)
	return glow

func _build_rain() -> void:
	var window := Polygon2D.new()
	window.polygon = PackedVector2Array([Vector2(864,88),Vector2(1070,146),Vector2(1070,340),Vector2(864,270)])
	window.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(window)
	for i in range(30):
		var drop := Line2D.new()
		drop.add_point(Vector2.ZERO)
		drop.add_point(Vector2(-2,9+i%4*3))
		drop.width = 1
		drop.default_color = Color(0.71,0.82,0.91,0.3)
		drop.position = Vector2(randf_range(850,1085),randf_range(80,345))
		window.add_child(drop)
		rain.append(drop)

func _process(delta: float) -> void:
	_clock += delta
	for i in range(rain.size()):
		var drop: Line2D = rain[i]
		if simulation and i==0:
			drop.position = Vector2(991,165+fmod(_clock,0.9)*105)
		else:
			drop.position += Vector2(-11,116)*delta
			if drop.position.y>345:
				drop.position = Vector2(randf_range(860,1080),80)
	phone_glow.modulate.a = 0.5+0.3*sin(_clock*2)
	laptop_glow.modulate.a = 0.6+0.18*sin(_clock)
	current = nearest(player.position)

func nearest(pos: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for entry in interactables:
		if not entry.branches.is_empty() and not active_branch in entry.branches:
			continue
		var distance := pos.distance_to(entry.pos)
		if distance<entry.radius and distance<best:
			best = distance
			result = entry
	return result

func _build_navigation() -> void:
	await get_tree().physics_frame
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0,0,144,81)
	grid.cell_size = Vector2(8,8)
	grid.offset = Vector2(4,4)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	grid.update()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("FeetCollision").shape
	query.exclude = [player.get_rid()]
	var space := get_world_2d().direct_space_state
	for x in range(144):
		for y in range(81):
			var pos := Vector2(x*8+4,y*8+4)
			query.transform = Transform2D(0,pos)
			var outside := pos.y<320 or pos.y>615 or pos.x<145 or pos.x>1100
			grid.set_point_solid(Vector2i(x,y),outside or not space.intersect_shape(query,1).is_empty())
	player.navigator = grid
