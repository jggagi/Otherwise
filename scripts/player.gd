extends CharacterBody3D
## Temporary protagonist placeholder: a muted capsule.
## Movement is simple, world-axis-aligned keyboard navigation
## (the camera is fixed, so no camera-relative math is needed).

@export var speed: float = 3.0

const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.7


func _ready() -> void:
	# Floating motion keeps the body on the floor plane without gravity.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_body()


func _build_body() -> void:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	mesh_instance.mesh = capsule
	# A muted coat color — purely a readable placeholder silhouette.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.42, 0.36)
	material.roughness = 0.95
	mesh_instance.material_override = material
	# Centre the capsule so its base rests on the floor (y = 0).
	mesh_instance.position.y = CAPSULE_HEIGHT * 0.5
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	collision.shape = shape
	collision.position.y = CAPSULE_HEIGHT * 0.5
	add_child(collision)


func _physics_process(_delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()