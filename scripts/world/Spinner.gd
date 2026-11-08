extends Node3D
## Tiny helper that spins a node forever (wind turbine blades, fans...).

@export var speed: float = 2.0


func _process(delta: float) -> void:
	rotate_z(speed * delta)