extends Node2D

var amount = 1
var canBePickedUp = false
var pickupDistance = 120
var pickingUp = false
var pickupDuration = 0.35

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Cash.scale = Vector2.ZERO
	$CashShadow.scale = Vector2.ZERO
	$AnimationPlayer.speed_scale = randfn(1.0, 0.15)
	$AnimationPlayer.play("CashBounce")
	var moveTween = NodeRelations.createTween()
	moveTween.set_ease(Tween.EASE_OUT)
	moveTween.set_trans(Tween.TRANS_CUBIC)
	var newPosition = global_position
	var randomNormal = Vector2.from_angle(randf_range(0, 360))
	newPosition.x += randomNormal.x * randf_range(35, 80)
	newPosition.y += randomNormal.y * randf_range(20, 35)
	var tweenDuration = 1.0 / $AnimationPlayer.speed_scale
	moveTween.tween_property(self, "global_position", newPosition, tweenDuration)
	moveTween.parallel().tween_property($Cash, "rotation_degrees", randfn(0, 15), tweenDuration)
	await TimeManager.wait(1.25)
	VillageController.addNodeToGridGroup(self)
	canBePickedUp = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
var frame = 0
func _process(delta: float) -> void:
	if Player.current.dead:
		return
	if pickingUp:
		pickupAnimationProgress += delta / pickupDuration
		var targetPosition = Player.current.global_position + Vector2(0, -35)
		var newPosition = originalPosition.lerp(targetPosition, pickupAnimationProgress)
		global_position = newPosition
		$Cash.rotation_degrees += (global_position.x - Player.current.global_position.x) * 0.125
		z_index = 4096
		if pickupAnimationProgress >= 1.0:
			Player.current.pickupCash(amount)
			queue_free()
		return
	
	# only check once every few frames
	frame += 1
	if frame == 5:
		if canBePickedUp:
			var distanceToPlayerSquared = Player.current.global_position.distance_squared_to(global_position)
			if distanceToPlayerSquared <= (pickupDistance * Player.current.pickUpRangeMultiplier) ** 2:
				pickup()
		frame = 0

var pickupAnimationProgress = 0.0
var originalPosition: Vector2
func pickup() -> void:
	canBePickedUp = false
	pickingUp = true
	originalPosition = global_position
	$AnimationPlayer.play("CashPickup")
