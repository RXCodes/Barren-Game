extends Node2D

var amount = 1
var canBePickedUp = false
var pickupDistance = 75
var pickingUp = false
var pickupDuration = 0.35

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Cash.scale = Vector2.ZERO
	$AnimationPlayer.speed_scale = randfn(1.0, 0.15)
	$AnimationPlayer.play("CashBounce")
	var moveTween = NodeRelations.createTween()
	moveTween.set_ease(Tween.EASE_OUT)
	moveTween.set_trans(Tween.TRANS_CUBIC)
	var newPosition = global_position
	newPosition.x += randfn(0, 40)
	newPosition.y += randfn(0, 25)
	var tweenDuration = 1.0 / $AnimationPlayer.speed_scale
	moveTween.tween_property(self, "global_position", newPosition, tweenDuration)
	moveTween.parallel().tween_property($Cash, "rotation_degrees", randfn(0, 15), tweenDuration)
	set_meta(ZIndexSorter.zScoreKey, newPosition.y)
	await TimeManager.wait(1.25)
	canBePickedUp = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if canBePickedUp:
		var distanceToPlayer = Player.current.global_position.distance_squared_to(global_position)
		if distanceToPlayer <= pickupDistance ** 2:
			pickup()
	if pickingUp:
		pickupAnimationProgress += delta / pickupDuration
		var newPosition = originalPosition.lerp(Player.current.global_position, pickupAnimationProgress)
		global_position = newPosition
		$Cash.rotation_degrees += (global_position.x - Player.current.global_position.x) * 0.1
		set_meta(ZIndexSorter.zScoreKey, INF)
		z_index = 4096
		if pickupAnimationProgress >= 1.0:
			Player.current.pickupCash(amount)
			queue_free()

var pickupAnimationProgress = 0.0
var originalPosition: Vector2
func pickup() -> void:
	canBePickedUp = false
	pickingUp = true
	originalPosition = global_position
	$AnimationPlayer.play("CashPickup")