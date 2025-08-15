class_name BulletExplosionFragment extends Node2D

static func create(position: Vector2, color: Color) -> void:
	var explosion = preload("res://Models/BulletExplosionFragment.tscn").instantiate()
	explosion.global_position = position
	explosion.color = color
	NodeRelations.rootNode.find_child("Level").add_child(explosion)

# Called when the node enters the scene tree for the first time.
var color: Color
func _ready() -> void:
	var flash = $Flash
	flash.self_modulate = color
	var tween = NodeRelations.createTween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_property(flash, "modulate", Color.TRANSPARENT, 1.2)
	var newPosition = global_position
	newPosition.y += randf_range(-230, -400)
	newPosition.x += randfn(0, 150)
	tween.parallel().tween_property(self, "global_position", newPosition, 1.0)
	$Blast.emitting = true
	await TimeManager.wait(10.0)
	queue_free()
