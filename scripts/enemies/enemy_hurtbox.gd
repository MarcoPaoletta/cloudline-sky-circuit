class_name EnemyHurtbox
extends Area3D
## The part of an enemy the bowling head can hurt. Lives on the enemy_hurt layer; the head's HitArea overlaps it
## and calls receive_head_hit(). The hit is accepted (or not) by the owning enemy, so a boss in its hit
## cooldown refuses a contact without consuming it.

@export var enabled: bool = true


func receive_head_hit(head: Node) -> bool:
	if not enabled:
		return false
	var e := get_parent()
	if e and e.has_method(&"take_head_hit"):
		return e.take_head_hit(head)
	return false


## One API for the three pieces of physics state (bool, monitorable, shape), applied deferred.
func set_enabled(value: bool) -> void:
	enabled = value
	set_deferred("monitorable", value)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not value)
