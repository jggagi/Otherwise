extends Node3D
## Otherwise — Milestone 0: Apartment Slice Foundation.
## Builds the apartment graybox (walls, furniture, rainy exterior),
## the four interactables, lighting, and the minimal UI.

const WALL_H := 2.6
const WALL_T := 0.2

@onready var player: CharacterBody3D = $Player
@onready var cam: Camera3D = $Camera3D
@onready var interactables_root: Node3D = $Interactables
@onready var environment_root: Node3D = $Environment
@onready var lighting_root: Node3D = $Lighting
@onready var hint_label: Label = $UI/Hint
@onready var prompt_label: Label = $UI/Prompt
@onready var message_label: Label = $UI/Message

var interactables: Array[Interactable] = []
var current: Interactable = null
var message_time := 0.0
var message_duration := 3.5


func _ready() -> void:
	_build_world()
	_build_interactables()
	_setup_player()
	_setup_camera()
	_setup_ui()
	_setup_environment()


func _process(delta: float) -> void:
	_update_interaction()
	_update_message(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and current != null:
			_show_message(current.text)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _colored_mesh(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


func _solid_box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	_colored_mesh(body, size, Vector3.ZERO, color)
	parent.add_child(body)


func _cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	instance.mesh = cyl
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


func _emissive(parent: Node, size: Vector3, pos: Vector3, color: Color, energy := 1.0) -> MeshInstance3D:
	var instance := _colored_mesh(parent, size, pos, color)
	var material: StandardMaterial3D = instance.material_override
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return instance


# ---------------------------------------------------------------------------
# World construction
# ---------------------------------------------------------------------------

func _build_world() -> void:
	_build_floor_and_walls()
	_build_entrance()
	_build_living_room()
	_build_kitchen()
	_build_bedroom()
	_build_exterior()
	_build_lighting()


func _build_floor_and_walls() -> void:
	# Floor (12 x 8.4 m), warm wood tone.
	_solid_box(environment_root, Vector3(12.0, 0.2, 8.4), Vector3(0, -0.1, -0.2), Color(0.40, 0.33, 0.25))

	# Left, right and back walls (warm gray).
	_solid_box(environment_root, Vector3(WALL_T, WALL_H, 7.4), Vector3(-5.0, WALL_H * 0.5, -0.5), Color(0.72, 0.68, 0.63))
	_solid_box(environment_root, Vector3(WALL_T, WALL_H, 7.4), Vector3(5.0, WALL_H * 0.5, -0.5), Color(0.72, 0.68, 0.63))

	# Back wall split around a wide window (opening spans x in [-2, 2]).
	_solid_box(environment_root, Vector3(3.6, WALL_H, WALL_T), Vector3(-3.8, WALL_H * 0.5, -4.0), Color(0.72, 0.68, 0.63))
	_solid_box(environment_root, Vector3(3.6, WALL_H, WALL_T), Vector3(3.8, WALL_H * 0.5, -4.0), Color(0.72, 0.68, 0.63))
	# Window sill and lintel.
	_solid_box(environment_root, Vector3(4.0, 0.8, 0.3), Vector3(0, 0.4, -4.0), Color(0.55, 0.48, 0.40))
	_solid_box(environment_root, Vector3(4.0, 0.5, 0.3), Vector3(0, WALL_H - 0.25, -4.0), Color(0.55, 0.48, 0.40))

	# Front low wall — an architectural "cutaway" so the fixed camera reads the room.
	_solid_box(environment_root, Vector3(10.4, 0.5, WALL_T), Vector3(0, 0.25, 3.0), Color(0.62, 0.58, 0.53))


func _build_entrance() -> void:
	# Front door on the left wall.
	_colored_mesh(environment_root, Vector3(0.06, 2.1, 0.9), Vector3(-4.86, 1.05, 1.7), Color(0.33, 0.26, 0.20))
	_colored_mesh(environment_root, Vector3(0.10, 0.12, 1.0), Vector3(-4.86, 2.2, 1.7), Color(0.45, 0.36, 0.28))
	# Shoe cabinet along the left wall.
	_solid_box(environment_root, Vector3(0.4, 0.9, 0.8), Vector3(-4.35, 0.45, 0.7), Color(0.50, 0.40, 0.30))
	# A couple of shoes on the floor.
	_colored_mesh(environment_root, Vector3(0.3, 0.08, 0.13), Vector3(-4.05, 0.04, 2.4), Color(0.16, 0.16, 0.18))
	_colored_mesh(environment_root, Vector3(0.3, 0.08, 0.13), Vector3(-4.05, 0.04, 2.62), Color(0.16, 0.16, 0.18))
	# Umbrella leaning near the door.
	_cylinder(environment_root, 0.05, 1.1, Vector3(-4.35, 0.55, 2.3), Color(0.15, 0.18, 0.24))


func _build_living_room() -> void:
	# Rug.
	_colored_mesh(environment_root, Vector3(3.4, 0.02, 2.2), Vector3(3.0, 0.01, 0.3), Color(0.28, 0.30, 0.30))
	# Sofa against the right wall.
	_solid_box(environment_root, Vector3(1.0, 0.5, 2.4), Vector3(4.25, 0.25, 0.2), Color(0.34, 0.38, 0.44))
	_colored_mesh(environment_root, Vector3(0.3, 0.95, 2.4), Vector3(4.85, 0.55, 0.2), Color(0.30, 0.34, 0.40))
	# Coffee table.
	_solid_box(environment_root, Vector3(1.4, 0.06, 0.8), Vector3(2.5, 0.45, 0.2), Color(0.52, 0.40, 0.28))
	_solid_box(environment_root, Vector3(0.4, 0.45, 0.4), Vector3(2.5, 0.225, 0.2), Color(0.44, 0.33, 0.24))
	# Floor lamp in the far corner.
	_cylinder(environment_root, 0.035, 1.5, Vector3(3.9, 0.75, 1.8), Color(0.30, 0.28, 0.26))
	var shade := _cylinder(environment_root, 0.22, 0.42, Vector3(3.9, 1.72, 1.8), Color(0.92, 0.82, 0.62))
	shade.material_override.emission_enabled = true
	shade.material_override.emission = Color(1.0, 0.82, 0.55)
	shade.material_override.emission_energy_multiplier = 1.0


func _build_kitchen() -> void:
	# Dining table + two chairs (left-back area).
	_solid_box(environment_root, Vector3(1.7, 0.07, 1.0), Vector3(-3.0, 0.75, -2.5), Color(0.52, 0.40, 0.28))
	_solid_box(environment_root, Vector3(0.5, 0.75, 0.5), Vector3(-3.0, 0.375, -2.5), Color(0.44, 0.33, 0.24))
	_colored_mesh(environment_root, Vector3(0.45, 0.5, 0.45), Vector3(-2.5, 0.25, -1.7), Color(0.40, 0.36, 0.34))
	_colored_mesh(environment_root, Vector3(0.45, 0.5, 0.45), Vector3(-3.5, 0.25, -1.7), Color(0.40, 0.36, 0.34))
	# Kitchen counters along the back and left walls.
	_solid_box(environment_root, Vector3(2.5, 0.9, 0.6), Vector3(-3.25, 0.45, -3.6), Color(0.40, 0.40, 0.40))
	_solid_box(environment_root, Vector3(0.6, 0.9, 2.0), Vector3(-4.5, 0.45, -3.0), Color(0.40, 0.40, 0.40))


func _build_bedroom() -> void:
	# Half-height divider so the bed is only glimpsed from above.
	_solid_box(environment_root, Vector3(2.8, 1.3, 0.15), Vector3(3.1, 0.65, -1.2), Color(0.68, 0.64, 0.60))
	# Bed against the right/back corner.
	_solid_box(environment_root, Vector3(2.0, 0.4, 1.6), Vector3(4.0, 0.2, -3.0), Color(0.66, 0.64, 0.70))
	_colored_mesh(environment_root, Vector3(0.15, 0.8, 1.6), Vector3(4.9, 0.4, -3.0), Color(0.52, 0.42, 0.34))
	_colored_mesh(environment_root, Vector3(0.5, 0.16, 0.6), Vector3(3.7, 0.48, -3.4), Color(0.82, 0.80, 0.85))
	# Nightstand.
	_solid_box(environment_root, Vector3(0.4, 0.5, 0.4), Vector3(2.7, 0.25, -3.0), Color(0.48, 0.38, 0.28))


func _build_exterior() -> void:
	# Balcony slab just outside the window.
	_colored_mesh(environment_root, Vector3(12.0, 0.12, 1.0), Vector3(0, -0.06, -4.6), Color(0.1, 0.11, 0.13))
	# Distant building silhouettes.
	_colored_mesh(environment_root, Vector3(3.0, 6.0, 1.5), Vector3(-4.0, 3.0, -9.0), Color(0.07, 0.08, 0.12))
	_colored_mesh(environment_root, Vector3(4.0, 8.0, 1.5), Vector3(-0.5, 4.0, -8.5), Color(0.06, 0.07, 0.11))
	_colored_mesh(environment_root, Vector3(3.0, 5.0, 1.5), Vector3(3.0, 2.5, -10.0), Color(0.08, 0.09, 0.13))
	_colored_mesh(environment_root, Vector3(2.5, 3.5, 1.5), Vector3(1.5, 1.75, -11.0), Color(0.07, 0.08, 0.12))
	# Distant lit apartment windows (warm/cool dots).
	var window_dots := [
		Vector3(-4.8, 2.5, -8.2), Vector3(-3.5, 1.5, -8.2), Vector3(-3.2, 3.6, -8.2),
		Vector3(-2.0, 2.2, -7.7), Vector3(-0.8, 3.0, -7.7), Vector3(0.3, 1.4, -7.7),
		Vector3(1.2, 2.8, -7.7), Vector3(2.2, 2.2, -9.2), Vector3(3.6, 1.6, -9.2),
		Vector3(3.8, 3.2, -9.2), Vector3(-1.0, 4.6, -7.7), Vector3(0.6, 5.2, -7.7),
		Vector3(1.8, 3.6, -10.2), Vector3(-4.0, 4.2, -8.2), Vector3(3.2, 4.0, -9.2),
	]
	for p in window_dots:
		_emissive(environment_root, Vector3(0.26, 0.34, 0.02), p, Color(0.85, 0.72, 0.45), 1.2)
	_build_rain()


func _build_rain() -> void:
	var rain := CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 350
	rain.lifetime = 1.1
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(6.0, 3.0, 1.0)
	rain.direction = Vector3(0, -1, 0)
	rain.spread = 4.0
	rain.gravity = Vector3(0, -11.0, 0)
	rain.initial_velocity_min = 5.0
	rain.initial_velocity_max = 9.0
	rain.scale_amount_min = 0.8
	rain.scale_amount_max = 1.2
	rain.color = Color(0.62, 0.72, 0.9, 0.55)
	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.5, 0.02)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.62, 0.72, 0.9, 0.5)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_material
	rain.mesh = drop
	rain.position = Vector3(0, 3.0, -5.6)
	environment_root.add_child(rain)


func _build_lighting() -> void:
	# Warm living-room lamp.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(3.9, 1.9, 1.8)
	lamp.light_color = Color(1.0, 0.82, 0.62)
	lamp.light_energy = 1.1
	lamp.omni_range = 5.5
	lamp.shadow_enabled = true
	lighting_root.add_child(lamp)
	# Warm kitchen light.
	var kitchen := OmniLight3D.new()
	kitchen.position = Vector3(-3.0, 1.7, -2.0)
	kitchen.light_color = Color(1.0, 0.86, 0.68)
	kitchen.light_energy = 0.8
	kitchen.omni_range = 4.5
	kitchen.shadow_enabled = true
	lighting_root.add_child(kitchen)
	# Cool moonlight coming through the window.
	var moon := DirectionalLight3D.new()
	moon.position = Vector3(0, 5.0, -7.0)
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	lighting_root.add_child(moon)
	moon.look_at(Vector3(0, 0, 0), Vector3.UP)


# ---------------------------------------------------------------------------
# Interactables
# ---------------------------------------------------------------------------

func _build_interactables() -> void:
	var phone := _make_interactable("Phone", Vector3(2.1, 0.49, 0.2), "手机", "林夏：我在你楼下。", 1.0)
	_colored_mesh(phone, Vector3(0.16, 0.012, 0.08), Vector3(0, 0.05, 0), Color(0.1, 0.1, 0.12))
	# A faintly lit screen on top.
	_emissive(phone, Vector3(0.14, 0.002, 0.06), Vector3(0, 0.058, 0), Color(0.55, 0.7, 0.95), 2.0)

	var door := _make_interactable("Door", Vector3(-4.86, 1.05, 1.7), "门", "门外只有雨声。", 1.1)
	_colored_mesh(door, Vector3(0.06, 2.1, 0.9), Vector3(0, 0, 0), Color(0.33, 0.26, 0.20))

	var laptop := _make_interactable("Laptop", Vector3(3.1, 0.54, 0.2), "笔记本", "你的个人电脑，屏幕暗着。", 1.0)
	_colored_mesh(laptop, Vector3(0.32, 0.025, 0.22), Vector3(0, 0.03, 0), Color(0.18, 0.18, 0.22))
	_colored_mesh(laptop, Vector3(0.32, 0.22, 0.02), Vector3(0, 0.15, -0.09), Color(0.15, 0.15, 0.18))

	var photo := _make_interactable("Photo", Vector3(4.84, 1.7, 0.2), "照片", "一张有些褪色的合影。", 1.0)
	_colored_mesh(photo, Vector3(0.04, 0.66, 0.5), Vector3(0, 0, 0), Color(0.48, 0.38, 0.28))
	_colored_mesh(photo, Vector3(0.01, 0.58, 0.42), Vector3(-0.03, 0, 0), Color(0.72, 0.7, 0.68))


func _make_interactable(node_name: String, pos: Vector3, prompt: String, text: String, radius: float) -> Interactable:
	var interactable := Interactable.new()
	interactable.name = node_name
	interactable.position = pos
	interactable.prompt = prompt
	interactable.text = text
	interactable.radius = radius
	interactables_root.add_child(interactable)
	interactables.append(interactable)
	return interactable


# ---------------------------------------------------------------------------
# Player / camera / UI / environment setup
# ---------------------------------------------------------------------------

func _setup_player() -> void:
	player.position = Vector3(1.0, 0.0, 1.2)


func _setup_camera() -> void:
	cam.position = Vector3(0.0, 8.0, 8.5)
	cam.look_at(Vector3(0.0, 0.0, -0.5), Vector3.UP)
	cam.fov = 46.0


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


func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.06, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.50, 0.45)
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.12, 0.17)
	env.fog_density = 0.008
	world_env.environment = env
	add_child(world_env)


# ---------------------------------------------------------------------------
# Interaction + message updates
# ---------------------------------------------------------------------------

func _update_interaction() -> void:
	var nearest: Interactable = null
	var best := INF
	for interactable in interactables:
		var distance := player.global_position.distance_to(interactable.global_position)
		if distance <= interactable.radius and distance < best:
			best = distance
			nearest = interactable
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