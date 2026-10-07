class_name Interactable
extends Area3D
## Minimal reusable interaction node.
## Holds the prompt label and the text shown after interacting.
## Distance-based activation is handled by the main scene script.

@export var prompt: String = "E"
@export var text: String = ""
@export var radius: float = 1.2


func _ready() -> void:
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	add_child(collision)