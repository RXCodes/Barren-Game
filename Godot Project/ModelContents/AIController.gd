class_name EnemyAI extends Node2D

@export_category("Enemy Info")

## The user-facing name of this enemy
@export var enemyName: String = "Dummy"

## The maximum HP that the enemy starts with
@export var maxHealth: int = 100
var currentHealth: float

## How much cash this enemy should drop
@export var cashDrop: int = 5

## How much the amount of cash dropped varies
@export var cashDropVariance: int = 1

## The hitbox body of this enemy (what detects attacks)
@export var hitBoxRigidBody: RigidBody2D

## The collision body of this enemy (what interacts with physical bodies)
@export var collisionRigidBody: RigidBody2D
static var enemyAIKey = "EnemyAI"

@export_category("Behaviors")

## Does the enemy do anything?
@export var hasAI: bool = false

## Speed when enemy travels
@export var walkMovementSpeed: float = 1

enum PathfindAgentSize {SMALL, MEDIUM, LARGE}
## Larger enemies should use larger sizes - small = 40px, medium = 60px, large = 80px
@export var pathfindAgentSize: PathfindAgentSize = PathfindAgentSize.SMALL

@export_subgroup("")
@export_subgroup("Gun")

## The enemy attacks by using a gun
@export var gunAttacksEnabled: bool = false

## What gun does the enemy use?
@export var gun: String = "Shotgun"

## Where's the gun that the enemy is holding? (required)
@export var gunSprite: Sprite2D

@export_subgroup("")
@export_category("Animations")

## Animation player for walking, idle and death animations
@export var mainAnimationPlayer: AnimationPlayer

## Animation to play when walking
@export var walkAnimation: String

## Animation to play when idling
@export var idleAnimation: String

## Animation to play when dying
@export var deathAnimation: String

## Animation player for when  or is hit
@export var actionAnimationPlayer: AnimationPlayer

## Animation to play when being hit from the front
@export var hitFrontAnimation: String

## Animation to play when being hit from the back
## -- will reuse front animation if left blank
@export var hitBackAnimation: String

@export_category("Visuals")

## Offset where damage number is displayed
@export var damageIndicatorPositionOffset: Vector2 = Vector2.ZERO

## Offset where health bar is displayed
@export var healthBarPositionOffset: Vector2 = Vector2(0, 20)

## The health bar's color
@export var healthBarColor: Color = Color(1.0, 0.4, 0.4, 1.0):
	set(newColor):
		healthBarColor = newColor
		if healthBar:
			healthBar.setHealthBarColor(healthBarColor)

## If enabled, the enemy will face the opposite direction
@export var invertXFlip: bool = false

@export_category("Audio")

## How long to wait before a hit sound effect can be played again
@export var hitSoundDelay: float = 0.05

@export_category("Debug")
enum EnemyVariantType {NORMAL, ACID, LIGHTNING, INFERNO}
## for debugging purposes, you can edit this variable but make sure to revert it back when done
@export var variantType: EnemyVariantType = EnemyVariantType.NORMAL

static var parentControllerKey = "ParentControllerKey"

# Called when the node enters the scene tree for the first time.
var navigationAgent: NavigationAgent2D
var hitboxShape: CollisionShape2D
var hitboxShapeInitialPosition: Vector2
var flipTransform: Node2D
var target: Node2D
var healthBar: EnemyHealthBar
var hitboxOffset = Vector2(0, 24)
func _ready() -> void:
	# setup the enemy
	await get_tree().physics_frame
	renderer = get_parent()
	navigationAgent = find_child("NavigationAgent2D")
	flipTransform = find_child("FlipTransform")
	hitboxShape = hitBoxRigidBody.get_child(0)
	hitboxShape.global_position += hitboxOffset # vertical offset so bullets can hit enemies
	enemies.append(self)
	hitboxShapeInitialPosition = hitboxShape.position
	currentHealth = maxHealth
	
	# setup hitboxes, health bar, etc.
	if not hitBoxRigidBody:
		hitBoxRigidBody = find_child("Hitbox")
	if hitBoxRigidBody:
		hitBoxRigidBody.set_meta(EnemyAI.enemyAIKey, self)
	if hitBackAnimation.is_empty():
		hitBackAnimation = hitFrontAnimation
	navigationAgent.target_reached.connect(reachedTarget)
	navigationAgent.velocity_computed.connect(velocityComputed)
	var children = NodeRelations.getChildrenRecursive(self)
	for child: Node in children:
		child.set_meta(EnemyAI.parentControllerKey, self)
	healthBar = preload("res://UI/EnemyHealthBar.tscn").instantiate()
	healthBar.position += healthBarPositionOffset - (hitboxOffset / 2.0)
	hitboxShape.add_child(healthBar)
	healthBar.setHealthBarColor(healthBarColor)
	
	# material has been set on instantiation for variants
	if not renderer.material:
		defaultMaterial = ShaderMaterial.new()
		defaultMaterial.shader = defaultEnemyShader
	renderer.material = defaultMaterial
	
	# deeal with different variants
	setVariantType(variantType)
	if variantType == EnemyVariantType.ACID:
		damageMultiplier = 1.5
		maxHealth *= 2.5
		currentHealth *= 2.5
		cashDrop *= 2.0
		createAcidFX()
		acidFX.modulate = Color(1, 1, 1, 0.4)
		acidFX.amount = 6
	if variantType == EnemyVariantType.LIGHTNING:
		damageMultiplier = 2.0
		maxHealth *= 4.0
		currentHealth *= 4.0
		cashDrop *= 3.0
		createLightningFX()
	if variantType == EnemyVariantType.INFERNO:
		damageMultiplier = 2.5
		maxHealth *= 6.0
		currentHealth *= 6.0
		cashDrop *= 5.0
		createBurnFX()
		burnFX.modulate = Color(1, 1, 1, 0.4)
		burnFX.amount = 4
	onStart()

# Called every frame. 'delta' is the elapsed time since the previous frame.
var flipX = false
var timeAlive: float = 0.0
func _process(delta: float) -> void:
	if not flipTransform:
		return
	flipTransform.scale.x = -1 if flipX else 1
	timeAlive += delta
	if invertXFlip:
		flipTransform.scale.x *= -1
	if renderer.material is ShaderMaterial:
		renderer.material.set_shader_parameter("normalizedRandom", randf_range(0.6, 1.0))
	runNavigationQueue()
	if not damageInTick.is_empty():
		for nodeRid in damageInTick.keys():
			var damageIndicatorPosition = collisionRigidBody.global_position
			damageIndicatorPosition += damageIndicatorPositionOffset
			damageIndicatorPosition.x += randfn(0, 15)
			damageIndicatorPosition.y += randfn(0, 20)
			var damageValue = damageInTick[nodeRid]
			var indicator = DamageIndicator.createDamageIndicator(damageIndicatorPosition, damageValue, instance_from_id(nodeRid), criticalDamaged)
			if criticalDamaged:
				renderer.material = ShaderMaterial.new()
				renderer.material.shader = criticalHitShader
		damageInTick.clear()
		criticalDamaged = false

static var flashWhiteShader = preload("res://ModelContents/EntityFlashWhite.gdshader")
static var criticalHitShader = preload("res://ModelContents/CriticalHit.gdshader")
static var defaultEnemyShader = preload("res://ModelContents/DefaultEnemy.gdshader")
static var acidEnemyShaderMaterial = preload("res://ModelContents/AcidShaderMaterial.tres")
static var lightningEnemyShaderMaterial = preload("res://ModelContents/LightningShaderMaterial.tres")
static var infernoEnemyShaderMaterial = preload("res://ModelContents/InfernoShaderMaterial.tres")
var renderer: EntityRender

# adjust brightness of enemy - used in special heavy attacks
var brightness: float = 0.0:
	set(newBrightness):
		brightness = newBrightness
		var shaderMaterial: ShaderMaterial = renderer.material
		shaderMaterial.set_shader_parameter("brightness", newBrightness)

# animate brightness - returns a signal that emits when the animation is complete
func animateBrightness(newValue: float, duration: float) -> Signal:
	var tween = NodeRelations.createTween()
	tween.tween_property(self, "brightness", newValue, duration)
	return TimeManager.wait(duration)

var damageMultiplier: float = 1.0

# set the enemy's variant type
func setVariantType(type: EnemyVariantType) -> void:
	variantType = type
	if type == EnemyVariantType.ACID:
		defaultMaterial = acidEnemyShaderMaterial.duplicate()
		currentHealth = maxHealth
	if type == EnemyVariantType.LIGHTNING:
		defaultMaterial = lightningEnemyShaderMaterial.duplicate()
		currentHealth = maxHealth
	if type == EnemyVariantType.INFERNO:
		defaultMaterial = infernoEnemyShaderMaterial.duplicate()
		currentHealth = maxHealth
	if not renderer:
		renderer = get_parent()
	renderer.material = defaultMaterial

# called when enemy is hit
func onHit(globalPosition: Vector2) -> void:
	if dead:
		return
	if actionAnimationPlayer:
		var directionVector = globalPosition - collisionRigidBody.global_position
		if directionVector.x > 0 == not flipX:
			if actionAnimationPlayer.has_animation(hitFrontAnimation):
				actionAnimationPlayer.stop()
				actionAnimationPlayer.play(hitFrontAnimation)
		else:
			if actionAnimationPlayer.has_animation(hitBackAnimation):
				actionAnimationPlayer.stop()
				actionAnimationPlayer.play(hitBackAnimation)
	var random = Vector2(randfn(0, 10), randfn(0, 10))
	HitParticle.spawnParticle(globalPosition + random, z_index + 30)

var canPlayHitSound = true
func playHitSound() -> void:
	var hitSounds = $ColliderBox/HitSounds
	if hitSounds and canPlayHitSound:
		if hitSounds.get_child_count() == 0:
			return
		var hitSound = hitSounds.get_children().pick_random()
		hitSound.play()
		canPlayHitSound = false
		await TimeManager.wait(hitSoundDelay)
		canPlayHitSound = true

# called when enemy is damaged
var damageInTick := {}
var criticalDamaged = false
var burnNodeSource: Node2D
func damage(amount: float, source: Node2D) -> void:
	if dead:
		return
		
	# critical damage functionality
	if source is Player:
		var criticalChance = randf_range(0, Player.current.criticalDamageMultiplier)
		var roll = randf_range(0, 100.0)
		if criticalChance >= roll:
			Crosshair.criticalHit()
			criticalDamaged = true
			amount *= 12.5
		else:
			Crosshair.enemyHit()
		Player.current.damageDealt += amount
		
		# flaming bullets effect
		if Player.current.flamingBullets:
			if randi_range(1, 5) == 1:
				burnNodeSource = Player.current
				burningTime = 10
		
		# explosive bullets effect
		if Player.current.explosiveBullets:
			if randi_range(1, 10) == 1:
				BulletExplosion.create(getPosition(), 50, EnemyAI.HurtBoxType.ENEMY, Player.current.gunInteractor.currentWeapon.bulletFireColor)
		
	if source is Explosion:
		if source.isFromPlayer:
			var criticalChance = randf_range(0, Player.current.criticalDamageMultiplier)
			var roll = randf_range(0, 100.0)
			if criticalChance >= roll:
				criticalDamaged = true
				amount *= 12.5
			Player.current.damageDealt += amount
	
	# burning effect from molotov
	if source is MolotovFire:
		burnNodeSource = source
		if source.isFromPlayer:
			var criticalChance = randf_range(0, Player.current.criticalDamageMultiplier)
			var roll = randf_range(0, 100.0)
			if criticalChance >= roll:
				criticalDamaged = true
				amount *= 12.5
			Player.current.damageDealt += amount
	
	enemyDamaged.emit()
	onDamage()
	if not damageInTick.has(source.get_instance_id()):
		damageInTick[source.get_instance_id()] = 0
	damageInTick[source.get_instance_id()] += amount
	currentHealth -= amount
	if currentHealth <= 0:
		currentHealth = 0
		if source is Player:
			Player.current.enemiesDefeated += 1
		kill()
	updateHealthBar()
	
	playHitSound()
	flashWhite(true)
	await TimeManager.wait(0.05)
	flashWhite(false)

# called when health bar needs to update
func updateHealthBar() -> void:
	healthBar.progress = (currentHealth / maxHealth) * 100.0
	
# called when changing the flashing state of the enemy
var defaultMaterial: ShaderMaterial
var canFlash = true
func flashWhite(flashing: bool) -> void:
	if not canFlash:
		return
	if flashing:
		renderer.material = ShaderMaterial.new()
		renderer.material.shader = flashWhiteShader
	else:
		renderer.material = defaultMaterial

# called on every physics tick
var burningTime = 0.0
var burnTick = 1.0
var burnFX: EntityFire
var acidFX: EntityAcid
var lightningFX: EntityLightning
var shapeTests: Array[ShapeIntersectionTest] = []
func _physics_process(delta: float) -> void:
	if hitboxShape:
		hitboxShape.global_position = collisionRigidBody.global_position + hitboxShapeInitialPosition
	if dead:
		return
	
	# pathfinding and attacks
	if hasAI:
		if walkMovementSpeed > 0:
			navigate()
		if shapeTests.size() > 0:
			var directPhysicsState = get_world_2d().direct_space_state
			for shapeTest in shapeTests:
				var intersectedShapes = directPhysicsState.intersect_shape(shapeTest.shapeQueryParameters)
				if intersectedShapes.size() > 0:
					if shapeTest.onSuccess:
						shapeTest.onSuccess.call(intersectedShapes)
			shapeTests.clear()
	
	# burning effect from molotov
	# inferno enemies are immune to burning
	if variantType != EnemyVariantType.INFERNO:
		if burningTime > 0:
			burningTime -= delta
			burnTick -= delta
			if not burnFX:
				createBurnFX()
			if burnTick <= 0:
				damage(randf_range(5.0, 10.0), burnNodeSource)
				burnTick = 1.0
		else:
			if burnFX:
				burnFX.stopEmitting()
				burnFX = null
	
	physicsProcess(delta)

# create particle effects for when the enemy is burning
func createBurnFX() -> void:
	burnFX = EntityFire.create()
	hitboxShape.add_child(burnFX)
	var width = hitboxShape.shape.get_rect().size.x / 25.0
	var height = hitboxShape.shape.get_rect().size.y / 25.0
	burnFX.scale = Vector2(width, height)

# create particle effects for acid enemies
func createAcidFX() -> void:
	acidFX = EntityAcid.create()
	hitboxShape.add_child(acidFX)
	var width = hitboxShape.shape.get_rect().size.x / 25.0
	var height = hitboxShape.shape.get_rect().size.y / 25.0
	acidFX.scale = Vector2(width, height)

# create particle effects for acid enemies
func createLightningFX() -> void:
	lightningFX = EntityLightning.create()
	hitboxShape.add_child(lightningFX)
	var width = hitboxShape.shape.get_rect().size.x / 25.0
	var height = hitboxShape.shape.get_rect().size.y / 25.0
	lightningFX.scale = Vector2(width, height)

# pathfinding and movement functionality
var targetDistance: float = 30
var previousPosition: Vector2
var samePositionThresholdSquared = 75 ** 2
var samePositionTime = 0
var lastNavigationCheck: float = 0
var requestingTeleportation: bool = false
var farFromPlayerTime: float = 0
var farFromPlayerTimeToTeleport: float = 10
var farFromPlayerMinDistanceSquared = 750 ** 2
func navigate() -> void:
	# adjust navigation properties depending on defined propreties
	if pathfindAgentSize == PathfindAgentSize.SMALL:
		navigationAgent.navigation_layers = 1
	elif pathfindAgentSize == PathfindAgentSize.MEDIUM:
		navigationAgent.navigation_layers = 2
	elif pathfindAgentSize == PathfindAgentSize.LARGE:
		navigationAgent.navigation_layers = 4
	navigationAgent.target_desired_distance = targetDistance
	navigationAgent.avoidance_layers = 1
	navigationAgent.avoidance_mask = 1
	var timeElapsed = timeAlive - lastNavigationCheck
	lastNavigationCheck = timeAlive
	if withinRangeOfTarget():
		reachedTarget()
		return
	
	# if this enemy is stuck in the same spot for too long, adjust its pathfinding
	if previousPosition.distance_squared_to(collisionRigidBody.global_position) < samePositionThresholdSquared and not requestingTeleportation:
		samePositionTime += timeElapsed
		if samePositionTime >= 5.0:
			navigationAgent.avoidance_enabled = true
			pathfindAgentSize = PathfindAgentSize.LARGE
		if samePositionTime >= 12.5:
			requestingTeleportation = true
			add_to_group("RequestingTeleportation")
			print("Enemy stuck in the same area for too long, requesting teleportation...")
			samePositionTime = 0.0
	else:
		previousPosition = collisionRigidBody.global_position
		samePositionTime = 0.0
	
	# if this enemy is too far from the player for too long, request teleportation
	if Player.current.global_position.distance_squared_to(collisionRigidBody.global_position) < farFromPlayerMinDistanceSquared and not requestingTeleportation:
		farFromPlayerTime += timeElapsed
		if farFromPlayerTime >= 7.5:
			requestingTeleportation = true
			add_to_group("RequestingTeleportation")
			print("Enemy far from player for too long, requesting teleportation...")
		else:
			farFromPlayerTime -= timeElapsed
			farFromPlayerTime = max(0, farFromPlayerTime)
	
	if mainAnimationPlayer.current_animation != walkAnimation:
		mainAnimationPlayer.stop()
		if mainAnimationPlayer.has_animation("Walk"):
			mainAnimationPlayer.play(walkAnimation)
	var pathfindDirectionVector = collisionRigidBody.global_position.direction_to(navigationAgent.get_next_path_position())
	var newVelocity = pathfindDirectionVector * walkMovementSpeed
	if not navigationAgent.avoidance_enabled:
		collisionRigidBody.move_and_collide(newVelocity)
	else:
		navigationAgent.max_speed = walkMovementSpeed
		navigationAgent.set_velocity(newVelocity)
	flipX = newVelocity.x < 0
	if newVelocity.x == 0:
		faceTarget()

func velocityComputed(vector: Vector2) -> void:
	if dead:
		return
	if walkMovementSpeed == 0:
		return
	collisionRigidBody.move_and_collide(vector)

# called when enemy reaches its target and is ready to attack
func reachedTarget() -> void:
	if mainAnimationPlayer.current_animation != idleAnimation:
		mainAnimationPlayer.stop()
		mainAnimationPlayer.play(idleAnimation)
	enemyReachedTarget.emit()

# this prevents too many enemies pathfinding at once (laggy)
static var enemies := []
static var enemyQueueIndex = 0
static var maxPathfindLimit = 5
static var readyToRunNavigation = true
static var navigateQueueInterval = 0.05
static func runNavigationQueue() -> void:
	if not readyToRunNavigation:
		return
	readyToRunNavigation = false
	for i in range(maxPathfindLimit):
		enemyQueueIndex += 1
		if enemyQueueIndex >= enemies.size():
			enemyQueueIndex = 0
		if not is_instance_valid(enemies[enemyQueueIndex]):
			enemies.remove_at(enemyQueueIndex)
			enemyQueueIndex -= 1
			continue
		var currentAI: EnemyAI = enemies[enemyQueueIndex]
		if not currentAI.hasAI:
			continue
		if not is_instance_valid(currentAI.target):
			continue
		if currentAI.target:
			currentAI.navigationAgent.target_position = currentAI.target.global_position
	await TimeManager.wait(navigateQueueInterval)
	readyToRunNavigation = true

#                  #
# HELPER FUNCTIONS #
#                  #

# targets a node and starts pathfinding to it
func setTarget(targetNode: Node2D, newTargetDistance: float) -> void:
	target = targetNode
	targetDistance = newTargetDistance
	navigationAgent.target_position = target.global_position

# targets a specific position
func setTargetWorldPosition(targetPosition: Vector2, newTargetDistance: float) -> void:
	target = null
	targetDistance = newTargetDistance
	navigationAgent.target_position = targetPosition

# plays an animation from the Main Animation Player
func playAnimation(animationName: String) -> void:
	if dead:
		return
	actionAnimationPlayer.play(animationName)
	var attackTime = maxf(actionAnimationPlayer.current_animation_length, 0.01)
	await TimeManager.wait(attackTime)
	enemyAnimationFinished.emit()

# makes the enemy face the target
func faceTarget() -> void:
	if dead or not target:
		return
	var directionVector = target.global_position - collisionRigidBody.global_position
	flipX = directionVector.x < 0

# checks if the enemy is within the range of the target
func withinRangeOfTarget() -> bool:
	if not target:
		return false
	var distanceSquared = collisionRigidBody.global_position.distance_squared_to(target.global_position)
	return distanceSquared <= targetDistance ** 2

# checks if the enemy is within a specified distance of the target
func withinDistanceOfTarget(distance: float) -> bool:
	if not target:
		return false
	var distanceSquared = collisionRigidBody.global_position.distance_squared_to(target.global_position)
	return distanceSquared <= distance ** 2

# gets the position of the enemy in global coordinates
func getPosition() -> Vector2:
	return collisionRigidBody.global_position

# gets the position of the target in global coordinates
func getTargetPosition() -> Vector2:
	return target.global_position

var dead = false
# kills the enemy - setting dead to true
func kill() -> void:
	if dead:
		return
	enemyDied.emit()
	onDeath()
	dead = true
	hitBoxRigidBody.collision_mask = 0
	hitBoxRigidBody.collision_layer = 0
	collisionRigidBody.collision_mask = 0
	collisionRigidBody.collision_layer = 0
	hasAI = false
	if actionAnimationPlayer:
		if actionAnimationPlayer.is_playing():
			actionAnimationPlayer.stop()
	mainAnimationPlayer.stop()
	mainAnimationPlayer.play(deathAnimation)
	var deathSounds = $ColliderBox/DeathSounds
	if deathSounds:
		if deathSounds.get_child_count() == 0:
			return
		var deathSound = deathSounds.get_children().pick_random()
		deathSound.play()
	await TimeManager.wait(mainAnimationPlayer.current_animation_length)
	for i in range(3):
		flashWhite(true)
		await TimeManager.wait(0.05)
		flashWhite(false)
		await TimeManager.wait(0.05)
	flashWhite(true)
	await TimeManager.wait(0.05)
	
	# rare chance to spawn a lucky coin
	if randi_range(1, 600) == 1:
		Item.spawnItem("LuckyCoin", 1, collisionRigidBody.global_position)
	
	# chances to drop random items
	if randi_range(1, 200) == 1:
		Item.spawnItem("Bandages", randi_range(1, 2), collisionRigidBody.global_position)
	if randi_range(1, 1000) == 1:
		Item.spawnItem("HealthKit", 1, collisionRigidBody.global_position)
	if randi_range(1, 250) == 1:
		var potions = ["ElixirOfFortune", "EnergyDrink", "PotionOfHealing", "PotionOfRage", "ShieldSpireSerum", "StaminaPotion", "WarriorSerum"]
		Item.spawnItem(potions.pick_random(), randi_range(1, 2), collisionRigidBody.global_position)
	
	DeathSmokeParticles.spawnParticle(collisionRigidBody.global_position, z_index)
	enemies.erase(self)
	var cashAmountToDrop = ceil(randfn(cashDrop, cashDropVariance) * Player.current.enemyCashDropMultiplier)
	cashAmountToDrop += ceil(maxHealth * Player.current.bountyMultiplier)
	EnemySpawner.spawnMoney(cashAmountToDrop, collisionRigidBody.global_position)
	if Player.current.lifestealAmount > 0 and Player.current.health < Player.current.maximumHealth:
		var lifestealEntity = EnemySpawner.spawnEnemy("LifestealEntity", global_position)
		lifestealEntity.healthIncrease = Player.current.lifestealAmount
	get_parent().queue_free()
	
	# enemy can explode on death with explosive bullets
	if Player.current.explosiveBullets:
			if randi_range(1, 20) == 1:
				Explosion.create(getPosition(), 50, EnemyAI.HurtBoxType.ENEMY, Player.current.gunInteractor.currentWeapon.bulletFireColor)

enum HurtBoxType {PLAYER, ENEMY, ALL}

# checks if a shape intersects with other players and enemies, dealing damage
func activateHurtBox(shape: CollisionShape2D, damage: float, type: HurtBoxType) -> void:
	damage *= damageMultiplier
	var newIntersectionTest = ShapeIntersectionTest.new()
	newIntersectionTest.setDetectionType(type)
	newIntersectionTest.setCollisionShape(shape)
	newIntersectionTest.exclude(collisionRigidBody)
	newIntersectionTest.onSuccess = func(shapes):
		for dictionary: Dictionary in shapes:
			var collider = dictionary.collider
			var parent = collider.get_meta(parentControllerKey)
			if parent:
				if type == HurtBoxType.ALL:
					parent.damage(damage, collisionRigidBody)
				elif parent is EnemyAI and type == HurtBoxType.ENEMY:
					parent.damage(damage, collisionRigidBody)
				elif parent is Player and type == HurtBoxType.PLAYER:
					parent.damage(damage, collisionRigidBody)
	shapeTests.append(newIntersectionTest)
	
	# let's also make it flash so we can see it being activated in debug
	var originalDebugColor = shape.debug_color
	shape.debug_color = Color(1, 1, 1, 0.9)
	await TimeManager.wait(0.05)
	shape.debug_color = originalDebugColor

#                                  #
# FUNCTIONS THAT CAN BE OVERRIDDEN #
#                                  #

# define what the enemy does on start
func onStart() -> void:
	pass

# define what happens when the enemy dies
func onDeath() -> void:
	pass

# define what happened when the enemy is damaged
func onDamage() -> void:
	pass

# define what happens in each physics tick
func physicsProcess(delta: float) -> void:
	pass

#                     #
# SIGNALS             #
#                     #
# Usage: await <name> #

# when the enemy has reached the range of its target
signal enemyReachedTarget

# when the enemy finishes an animation
signal enemyAnimationFinished

# when the enemy was damaged
signal enemyDamaged

# when the enemy has been killed
signal enemyDied

#            #
# STRUCTURES #
#            #

class ShapeIntersectionTest:
	var shapeQueryParameters: PhysicsShapeQueryParameters2D
	var onSuccess: Callable
	
	func _init() -> void:
		shapeQueryParameters = PhysicsShapeQueryParameters2D.new()
		shapeQueryParameters.collide_with_bodies = true
		shapeQueryParameters.collide_with_areas = false
		setDetectionType(HurtBoxType.PLAYER)
	
	func exclude(collider: CollisionObject2D) -> void:
		var exclude = shapeQueryParameters.exclude
		exclude.append(collider.get_rid())
		shapeQueryParameters.exclude = exclude
	
	func setCollisionShape(newCollisionShape: CollisionShape2D) -> void:
		shapeQueryParameters.shape = newCollisionShape.shape
		shapeQueryParameters.transform = newCollisionShape.global_transform
	
	func setDetectionType(hurtboxType: HurtBoxType) -> void:
		if hurtboxType == HurtBoxType.PLAYER:
			shapeQueryParameters.collision_mask = 2**(1-1) # collision mask 0
		elif hurtboxType == HurtBoxType.ENEMY:
			shapeQueryParameters.collision_mask = 2**(3-1) # collision mask 3
		elif hurtboxType == HurtBoxType.ALL:
			shapeQueryParameters.collision_mask = (2**(1-1)) + (2**(3-1)) # collision masks 0 and 3
