extends EnemyAI
class_name BaseSlimeEnemy
 
var canDealDamage = false

# Function called when the enemy spawns into the scene
func onStart() -> void:
	var wave = VillageController.currentWave
	setTarget(Player.current, 110)
	
	if wave >= 5:
		navigationAgent.avoidance_enabled = true
	
	while not dead:
		walkMovementSpeed = 2
		walkMovementSpeed = 2 * (1 + (wave - 1) * 0.05)
		walkMovementSpeed = min(walkMovementSpeed, 6)
		mainAnimationPlayer.play("Walk")
		
		var jumpTimeMultiplier = max(1 - (wave * 0.025), 0.15)
		var jumpTime = randf_range(5.0, 10.0) * jumpTimeMultiplier
		await TimeManager.promise([enemyReachedTarget], jumpTime)
		
		# enemy jumps towards the player while in range
		while true:
			faceTarget()
			walkMovementSpeed = 0  
			mainAnimationPlayer.stop()
			playAnimation("Attack")
			await TimeManager.wait(0.2)
			canDealDamage = true
			if withinRangeOfTarget():
				jumpToPoint(getTargetPosition(), 0.5)
			else:
				jumpToPoint(navigationAgent.get_next_path_position(), 0.5)
			await TimeManager.wait(0.5)
			if canDealDamage:
				activateHurtBox($ColliderBox/Hurtbox, randf_range(3, 5), HurtBoxType.PLAYER)
			await enemyAnimationFinished
			await TimeManager.wait(0.02)
			if not withinRangeOfTarget():
				break
		await TimeManager.wait(0.02)

var jumpNormal: Vector2
var jumping = false
# jumps towards a position with given air time
func jumpToPoint(targetPosition: Vector2, airTime: float) -> void:
	jumpNormal = (targetPosition - getPosition()).normalized()
	jumping = true
	await TimeManager.wait(airTime)
	jumping = false

func physicsProcess(delta: float) -> void:
	if not jumping or dead:
		return
	# move the slime as it is jumping
	var result = collisionRigidBody.move_and_collide(jumpNormal * 5.0)
	if result:
		# stop the slime from moving any more when it hits an obstacle and deal damage
		activateHurtBox($ColliderBox/Hurtbox,  randf_range(3, 5), HurtBoxType.PLAYER)
		canDealDamage = false
		jumping = false
