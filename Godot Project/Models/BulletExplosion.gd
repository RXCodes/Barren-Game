class_name BulletExplosion extends Node2D

var isFromPlayer = false
var enemySource: EnemyAI:
	set(newSource):
		set_meta(EnemyAI.parentControllerKey, newSource)
		enemySource = newSource

static func create(position: Vector2, damage: float, hurtBoxType: EnemyAI.HurtBoxType, color: Color = Color("f2d862")) -> BulletExplosion:
	var explosion: BulletExplosion = preload("res://Models/BulletExplosion.tscn").instantiate()
	explosion.global_position = position
	explosion.color = color
	NodeRelations.rootNode.find_child("Level").add_child(explosion)
	explosion.activateHurtBox(damage, hurtBoxType)
	return explosion

# Called when the node enters the scene tree for the first time.
var color: Color
func _ready() -> void:
	var flash = $Flash
	flash.self_modulate = color
	var distanceToPlayer = Player.current.global_position.distance_to(global_position)
	var shakeIntensity = 20 - (distanceToPlayer * 0.035)
	if shakeIntensity > 0:
		PlayerCamera.current.shakeScreen(shakeIntensity, 3.0)
	var tween = NodeRelations.createTween()
	tween.tween_property(flash, "modulate", Color.TRANSPARENT, 0.25)
	$Blast.emitting = true
	await get_tree().physics_frame
	for i in range(3):
		var fragmentPosition = global_position
		fragmentPosition.x += randfn(0, 30)
		fragmentPosition.y += randfn(0, 20)
		BulletExplosionFragment.create(fragmentPosition, color)
	await TimeManager.wait(10.0)
	queue_free()

var damageFalloff = 0.5
func activateHurtBox(damage: float, type: EnemyAI.HurtBoxType) -> void:
	var newIntersectionTest = EnemyAI.ShapeIntersectionTest.new()
	newIntersectionTest.setDetectionType(type)
	newIntersectionTest.setCollisionShape($StaticBody2D/Hurtbox)
	newIntersectionTest.onSuccess = func(shapes):
		for dictionary: Dictionary in shapes:
			var collider = dictionary.collider
			var distance = collider.global_position.distance_to(global_position)
			var parent = collider.get_meta(EnemyAI.parentControllerKey)
			if parent:
				var newDamage = lerpf(damage, damage * damageFalloff, distance / 180)
				if type == EnemyAI.HurtBoxType.ALL:
					parent.damage(newDamage, self)
				elif parent is EnemyAI and type == EnemyAI.HurtBoxType.ENEMY:
					parent.damage(newDamage, self)
				elif parent is Player and type == EnemyAI.HurtBoxType.PLAYER:
					parent.damage(newDamage, self)
	shapeTests.append(newIntersectionTest)

var shapeTests: Array[EnemyAI.ShapeIntersectionTest] = []
func _physics_process(delta: float) -> void:
	if shapeTests.size() > 0:
		var directPhysicsState = get_world_2d().direct_space_state
		for shapeTest in shapeTests:
			var intersectedShapes = directPhysicsState.intersect_shape(shapeTest.shapeQueryParameters, 100)
			if intersectedShapes.size() > 0:
				if shapeTest.onSuccess:
					shapeTest.onSuccess.call(intersectedShapes)
		shapeTests.clear()
