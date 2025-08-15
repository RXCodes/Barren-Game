class_name WormFireball extends Node2D

var targetPosition: Vector2
var maxDistance = 800
var travelTime = 1
var targetVelocity: Vector2
var wormEnemy: EnemyAI
var canHitObstacles = true
var enemyColor: Color
var damage = 20

func refreshColor() -> void:
	if wormEnemy.variantType == EnemyAI.EnemyVariantType.ACID:
		enemyColor = Color("#10ed00")
	if wormEnemy.variantType == EnemyAI.EnemyVariantType.LIGHTNING:
		enemyColor =  Color("#ffe100")
	if wormEnemy.variantType == EnemyAI.EnemyVariantType.INFERNO:
		enemyColor =  Color("#ff0000")
	if wormEnemy.variantType == EnemyAI.EnemyVariantType.NORMAL:
		enemyColor =  Color("#7cb5eb")
	damage *= wormEnemy.damageMultiplier

var hasExploded = false
func explode() -> void:
	if hasExploded:
		return
	hasExploded = true
	
	# create explosion and change color based on enemy type
	var explosion = Explosion.create($RigidBody2D/Fireball.global_position, damage, EnemyAI.HurtBoxType.PLAYER, enemyColor)
	if is_instance_valid(wormEnemy):
		explosion.enemySource = wormEnemy
	else:
		explosion.enemySource = Player.current
	
	queue_free()

# determines the trajectory of the fireball - assume this is called on start as intended
func goToPosition(newTargetPosition: Vector2) -> void:
	var distance = global_position.distance_to(newTargetPosition)
	var normal = (newTargetPosition - global_position).normalized()
	var trajectory = normal * min(distance, maxDistance)
	targetPosition = global_position + trajectory
	targetVelocity = (targetPosition - global_position) / travelTime
	
	# chance for the fireball to go over obstacles, avoiding collision
	if randi_range(1, 2) == 1:
		travelTime = 2
		canHitObstacles = false
		$RigidBody2D/AnimationPlayer.play("SummonAir")
		$WormIndicator/AnimationPlayer.play("Summon")
		$WormIndicator.self_modulate = enemyColor
		$WormIndicator.global_position = targetPosition
		$WormIndicator.show()
	else:
		travelTime = 1
		$RigidBody2D/AnimationPlayer.play("Summon")
		$WormIndicator.hide()
	
	await TimeManager.wait(travelTime)
	explode()
	
func _physics_process(delta: float) -> void:
	$RigidBody2D/Fireball.rotation_degrees += delta * 700
	var collision = $RigidBody2D.move_and_collide(targetVelocity * delta)
	if collision:
		var collider = collision.get_collider()
		if not collider.has_meta(EnemyAI.parentControllerKey):
			if canHitObstacles:
				explode()
		else:
			$RigidBody2D.add_collision_exception_with(collider)
