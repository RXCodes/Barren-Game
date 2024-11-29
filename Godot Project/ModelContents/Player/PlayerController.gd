class_name Player extends CharacterBody2D
static var current: Player
var renderer: EntityRender
var mainAnimationPlayer: AnimationPlayer
var actionAnimationPlayer: AnimationPlayer
var animationTree: AnimationTree
var textureOutput: Sprite2D
var sprintBar: SprintBar
var sprintingSpeedMultiplier = 1.5
var isSprinting = false
var playerSpeed = 3.5
var health = 100.0
var dead = false
var cash = 0

var sprintZoomOffset = -0.125
var sprintZoomDampening = 0.075
var currentScrollZoom = 1.0
var scrollZoomDampening = 0.12
var minScrollZoom = 0.65
var maxScrollZoom = 1.5

var gunInteractor: Gun.Interactor
var gunFireShakeDampening = 0.1
var reloadMovementSpeedMultiplier = 0.5
var shooting = false

var holdingWeapons = []
var currentWeaponSlot = 1

# setup renderer and gun interactor
var hitboxShape: Node2D
var hitBoxRigidBody: Node2D
func _ready() -> void:
	TutorialManager.shouldDisableControls = false
	Upgrade.playerUpgrades.clear()
	holdingWeapons.append(Gun.gunFromString("Shotgun"))
	renderer = get_parent()
	current = self
	mainAnimationPlayer = $Subviewport/Transform/MainAnimationPlayer
	actionAnimationPlayer = $Subviewport/Transform/ActionAnimationPlayer
	animationTree = $Subviewport/Transform/AnimationTree
	textureOutput = $TextureDisplay
	sprintBar = $SprintBar
	sprintBar.modulate = Color.TRANSPARENT
	await get_tree().physics_frame
	gunInteractor = Gun.Interactor.new()
	gunInteractor.originNode = self
	gunInteractor.gunSprite = $Subviewport/Transform/Torso/Coat/LeftElbow/Weapon
	gunInteractor.onFire = self.onFire
	gunInteractor.onCockWeapon = self.onCockWeapon
	gunInteractor.onFinishReload = self.onFinishReload
	gunInteractor.onReloadInterrupted = self.onReloadInterrupted
	gunInteractor.onReload = self.onReload
	gunInteractor.sourcePositionOffset = Vector2(0, -48)
	selectWeapon(holdingWeapons[0])
	refreshAmmoDisplay()
	hitBoxRigidBody = $"../Hitbox"
	hitboxShape = hitBoxRigidBody.get_children()[0]
	var children = NodeRelations.getChildrenRecursive(self)
	for child: Node in children:
		child.set_meta(EnemyAI.parentControllerKey, self)

# player looping animations
enum {IDLE, WALK, BACKWARDSWALK}
var blendSpeed = 7.5
var currentAnimation = IDLE
var animationValues = {
	"parameters/WalkProgress/blend_amount": 0,
	"parameters/WalkBackwardsProgress/blend_amount": 0
}

var sprintBarHidden = true
func _process(delta: float) -> void:
	# interrupt controls if needed
	if GamePopup.current or TutorialManager.shouldDisableControls:
		currentMovementKeypresses.clear()
		isSprinting = false
		shooting = false
	
	# blend animations so we can have smoother transitions between them
	var animSpeed = delta * blendSpeed
	match currentAnimation:
		WALK: animationValues["parameters/WalkProgress/blend_amount"] += animSpeed * 2.0
		BACKWARDSWALK: animationValues["parameters/WalkBackwardsProgress/blend_amount"] += animSpeed * 2.0
	for key in animationValues.keys():
		animationValues[key] -= animSpeed
		animationValues[key] = clampf(animationValues[key], 0.0, 1.0)
		animationTree[key] = animationValues[key]
	
	# calculate normal vector to crosshair and flip player if needed
	var crosshairNormal = Vector2.from_angle(global_position.angle_to_point(Crosshair.current.cursorPosition))
	facingLeft = crosshairNormal.x < 0
	textureOutput.scale.x = -1 if facingLeft else 1
	
	# zoom camera when player is sprinting
	var shouldZoomCamera = Input.is_key_pressed(KEY_SHIFT) and walking and not walkingBackwards and sprintPower > 0
	var targetZoomOffset = sprintZoomOffset if shouldZoomCamera else 0.0
	PlayerCamera.current.sprintingZoomOffset += (targetZoomOffset - PlayerCamera.current.sprintingZoomOffset) * sprintZoomDampening
	PlayerCamera.current.zoomMultiplier += (currentScrollZoom - PlayerCamera.current.zoomMultiplier) * scrollZoomDampening
	
	# weapon functionality
	if shooting and not dead:
		var originPosition = global_position + Vector2(0, -48)
		var aimAngle = originPosition.angle_to_point(Crosshair.current.cursorPosition)
		gunInteractor.currentWeapon.fire(true, aimAngle)
	PlayerCamera.current.gunFireShakeOffset *= 1.0 - gunFireShakeDampening
	
	# damage display
	if not damageInTick.is_empty():
		for nodeRid in damageInTick.keys():
			var damageIndicatorPositionOffset = Vector2(0, -20)
			var damageIndicatorPosition = global_position
			damageIndicatorPosition += damageIndicatorPositionOffset
			damageIndicatorPosition.x += randfn(0, 15)
			damageIndicatorPosition.y += randfn(0, 20)
			var damageValue = damageInTick[nodeRid]
			var indicator = DamageIndicator.createDamageIndicator(damageIndicatorPosition, damageValue, instance_from_id(nodeRid))
			indicator.modulate = Color(1.0, 0.5, 0.5)
		damageInTick.clear()
	
	# sprint bar display
	sprintBar.value = sprintPower
	if sprintPower == 100 and not sprintBarHidden:
		sprintBarHidden = true
		sprintBar.fadeOut()
	if sprintPower < 100 and sprintBarHidden:
		sprintBarHidden = false
		sprintBar.fadeIn()
	if sprintPower == 0:
		sprintBar.startFlashing()
	else:
		sprintBar.stopFlashing()

var walking = false
var walkingBackwards = false
var facingLeft = false
var sprintPower = 100.0
var sprintDecreaseRate = 20
var sprintRecoveryRate = 30
var regenerationRate = 1.0 / 10.0 # one hp every 10 seconds

# properties that can be modified during runtime (Upgrades)
var criticalDamageMultiplier: float = 1.0
var movementSpeedMultiplier: float = 1.0
var sprintRecoveryMultiplier: float = 1.0
var reloadSpeedDivisor: float = 1.0
var defenseDivisor: float = 1.0
var pickUpRangeMultiplier: float = 1.0
var regenerationRateMultiplier: float = 1.0
var maximumHealth: int = 100
var sprintDecreaseRateDivisor: float = 1.0
var enemyCashDropMultiplier: float = 1.0
var shopPriceDivisor: float = 1.0
var bountyMultiplier: float = 0.0
var compoundInterest: float = 0.0
var lifestealMultiplier: float = 0.0

# statistics
var totalCashEarned: int = 0

func _physics_process(delta: float) -> void:
	if dead:
		return
	
	# passive regeneration
	if not dead:
		health += regenerationRate * regenerationRateMultiplier * delta
		health = min(health, maximumHealth)
		PlayerHealthBar.setHealth(health)
		PlayerHealthBar.setMaxHealth(maximumHealth)
	
	# player movement
	if currentMovementKeypresses.size() > 0:
		var movementVector = Vector2.ZERO
		walking = true
		
		# calculate the total movement velocity
		for currentMovementVector in  currentMovementKeypresses:
			movementVector += currentMovementVector
		
		# normalize the vector to ensure same speed regardless of direction
		movementVector = movementVector.normalized()
		
		# play a specific animation depending on speed and direction
		walkingBackwards = movementVector.x > 0 if facingLeft else movementVector.x < 0
		currentAnimation = BACKWARDSWALK if walkingBackwards else WALK
		if movementVector.length_squared() == 0:
			currentAnimation = IDLE
		
		# finally move the player
		var speedMultiplier = movementSpeedMultiplier
		if movementSpeedMultiplier < 1:
			speedMultiplier = 1.0 / absf(movementSpeedMultiplier - 2)
		if isSprinting and not gunInteractor.currentWeapon.reloading and not walkingBackwards:
			if sprintPower > 0:
				speedMultiplier *= sprintingSpeedMultiplier
				sprintPower -= (sprintDecreaseRate * delta) / sprintDecreaseRateDivisor
		else:
			sprintPower += sprintRecoveryRate * sprintRecoveryMultiplier * delta * 0.5
		if gunInteractor != null and gunInteractor.currentWeapon.reloading:
			speedMultiplier *= reloadMovementSpeedMultiplier
		if sprintPower == 0:
			# sprint has exhausted, slow down player
			speedMultiplier *= 0.6
		animationTree["parameters/Speed/scale"] = speedMultiplier
		movementVector *= playerSpeed * speedMultiplier
		if walkingBackwards:
			movementVector *= 0.6
		move_and_collide(Vector2(movementVector.x, 0))
		move_and_collide(Vector2(0, movementVector.y))
	else:
		sprintPower += sprintRecoveryRate * sprintRecoveryMultiplier * delta
		currentAnimation = IDLE
		walking = false
	sprintPower = clampf(sprintPower, 0.0, 100.0)
	
	# move player hitbox
	if hitboxShape:
		hitboxShape.global_position = global_position

# keep track of which movement keys are being pressed
var currentMovementKeypresses: Array = []
var movementKeyBinds = {
	"A": Vector2.LEFT,
	"W": Vector2.UP,
	"S": Vector2.DOWN,
	"D": Vector2.RIGHT
}
func _input(event: InputEvent) -> void:
	if dead:
		return
	if GamePopup.current or TutorialManager.shouldDisableControls:
		currentMovementKeypresses.clear()
		isSprinting = false
		shooting = false
		return
	if event is InputEventKey:
		var key: String = event.as_text_key_label()
		key = key.trim_prefix("Shift+")
		
		# keep track of WASD movement
		if movementKeyBinds.has(key):
			var moveVector = movementKeyBinds[key]
			if event.pressed:
				if not currentMovementKeypresses.has(moveVector):
					currentMovementKeypresses.push_front(moveVector)
			else:
				currentMovementKeypresses.erase(moveVector)
		
		# just for debugging purposes -- have the player be able to swap weapons
		if gunInteractor == null:
			return
		if not gunInteractor.currentWeapon.reloading and gunInteractor.currentWeapon.canFire:
			if event.pressed:
				if key == "1":
					currentWeaponSlot = 1
					WeaponSlots.selectPrimary()
					selectWeapon(holdingWeapons[0])
				elif key == "2":
					if holdingWeapons.size() >= 2:
						currentWeaponSlot = 2
						WeaponSlots.selectSecondary()
						selectWeapon(holdingWeapons[1])
				
	# mouse clicks and scrolling
	if event is InputEventMouseButton:
		# don't register clicks when hovering over buttons
		if Crosshair.hoveringOverButton:
			return
		# handle left click
		if event.button_index == 1:
			shooting = event.pressed
			if event.pressed and gunInteractor != null:
				var originPosition = global_position + Vector2(0, -48)
				var aimAngle = originPosition.angle_to_point(Crosshair.current.cursorPosition)
				gunInteractor.currentWeapon.fire(false, aimAngle)
		# handle right click
		elif event.button_index == 2:
			if event.pressed:
				if gunInteractor.currentWeapon.reloading:
					gunInteractor.currentWeapon.cancelReload()
				else:
					gunInteractor.reloadSpeedDivisor = self.reloadSpeedDivisor
					gunInteractor.currentWeapon.reload(false)
		# scrolling up should reduce zoom
		elif event.button_index == 4:
			currentScrollZoom *= 0.975
			currentScrollZoom = maxf(currentScrollZoom, minScrollZoom)
		# scrolling down should increase zoom
		elif event.button_index == 5:
			currentScrollZoom *= 1.025
			currentScrollZoom = minf(currentScrollZoom, maxScrollZoom)
	
	# player is sprinting while shift is held
	isSprinting = Input.is_key_pressed(KEY_SHIFT)

func onFire() -> void:
	# briefly shake screen
	var recoilMultiplier = gunInteractor.currentWeapon.recoilAmount
	var random = Vector2(randf_range(-250, 250), randf_range(-250, 250))
	var crosshairNormal = Vector2.from_angle(Crosshair.current.cursorPosition.angle_to_point(global_position + random)).normalized()
	PlayerCamera.current.gunFireShakeOffset += crosshairNormal * recoilMultiplier
	
	# update ammo info and animate it
	AmmoInfoDisplay.gunFired()
	refreshAmmoDisplay()
	
	# play shoot animation
	actionAnimationPlayer.stop()
	actionAnimationPlayer.play("Fire-" + gunInteractor.currentWeapon.fileName, -1, gunInteractor.fireRateDivisor)
	gunInteractor.currentWeapon.cockedGun = false
	var shootAnimationTime = actionAnimationPlayer.current_animation_length
	var currentGunIdentifier = gunInteractor.currentWeapon.fileName
	
	# after shoot animation is played, play cocking animation if any
	# this only plays if there's at least one ammo in the magazine to load from
	await TimeManager.wait(shootAnimationTime / gunInteractor.fireRateDivisor)
	if currentGunIdentifier == gunInteractor.currentWeapon.fileName:
		if gunInteractor.currentWeapon.currentMagCapacity >= 1:
			gunInteractor.currentWeapon.cockWeapon()
		else:
			# player has no ammo left in magazine - let's reload
			if gunInteractor.currentWeapon.leftoverAmmoCount > 0:
				gunInteractor.reloadSpeedDivisor = self.reloadSpeedDivisor
				gunInteractor.currentWeapon.reload(true)
			else:
				# oh, there's no leftover ammo - player can't reload
				print("No ammo left")

func onCockWeapon() -> void:
	actionAnimationPlayer.play("Cock-" + gunInteractor.currentWeapon.fileName, -1, gunInteractor.fireRateDivisor)
	refreshAmmoDisplay()

func onReload() -> void:
	actionAnimationPlayer.play("Reload-" + gunInteractor.currentWeapon.fileName, -1, reloadSpeedDivisor)
	Crosshair.reloadWeapon(gunInteractor.currentWeapon.reloadTime / reloadSpeedDivisor)

func onFinishReload() -> void:
	AmmoInfoDisplay.gunReloaded()
	refreshAmmoDisplay()

func refreshAmmoDisplay() -> void:
	AmmoInfoDisplay.setAmmoLeft(gunInteractor.currentWeapon.leftoverAmmoCount)
	AmmoInfoDisplay.setMagCapacity(gunInteractor.currentWeapon.currentMagCapacity)

func onReloadInterrupted() -> void:
	actionAnimationPlayer.stop()
	actionAnimationPlayer.play(&"RESET")
	actionAnimationPlayer.advance(0)
	Crosshair.stopReloadingWeapon()

func callGunMethod(string: String):
	if gunInteractor.currentWeapon.has_method(string):
		gunInteractor.currentWeapon.call(string)

# called when player is damaged
var damageInTick := {}
func damage(amount: float, source: Node2D) -> void:
	if dead:
		return
	
	# apply defense
	if defenseDivisor >= 1:
		amount /= defenseDivisor
	else:
		# case for negative defense
		amount *= absf(defenseDivisor - 2)
		
	# play random hit sound
	var hitSounds = $HitSounds.get_children()
	var hitSound: AudioStreamPlayer = hitSounds.pick_random()
	hitSound.pitch_scale = randfn(1.0, 0.075)
	hitSound.play()
	
	# keep track of damage
	if not damageInTick.has(source.get_instance_id()):
		damageInTick[source.get_instance_id()] = 0
	damageInTick[source.get_instance_id()] += amount
	health -= amount
	
	# animate hurt vignette and camera
	var hurtVignetteOpacity = lerpf(0.75, 0.3, health / 100.0)
	var animationTime = lerpf(2.0, 0.6, health / 100.0)
	HurtVignette.animate(hurtVignetteOpacity, animationTime)
	PlayerCamera.current.playerDamaged()
	
	# update health
	PlayerHealthBar.setHealth(health)
	if health <= 0:
		HurtVignette.animate(1.0, 5.0)
		health = 0
		kill()

# called when player dies
func kill() -> void:
	if dead:
		return
	dead = true
	GamePopup.closeCurrent()
	$DeathSound.play()
	TutorialManager.shouldDisableControls = true
	hitBoxRigidBody.collision_mask = 0
	hitBoxRigidBody.collision_layer = 0
	self.collision_mask = 0
	self.collision_layer = 0
	actionAnimationPlayer.stop()
	mainAnimationPlayer.stop()
	mainAnimationPlayer.play("death")
	await TimeManager.wait(mainAnimationPlayer.current_animation_length)
	DeathSmokeParticles.spawnParticle(global_position, z_index)
	hide()
	
	# after dying, restart scene - we'll change this to be the death screen
	await TimeManager.wait(2.25)
	NodeRelations.loadScene("res://Scenes/Debug.tscn")

func playWalkSound() -> void:
	var walkSounds = $WalkSounds.get_children()
	var walkSound: AudioStreamPlayer2D = walkSounds.pick_random()
	walkSound.pitch_scale = randfn(1.0, 0.1)
	walkSound.play()

func pickupCash(amount: int) -> void:
	cash += amount
	if amount > 0:
		totalCashEarned += amount
	MoneyDisplay.setMoney(cash)
	$CashPickup.pitch_scale = randfn(1.0, 0.075)
	$CashPickup.play()

func pickupAmmo() -> void:
	$AmmoPickup.pitch_scale = randfn(1.0, 0.085)
	$AmmoPickup.play()
	for gun: Gun in holdingWeapons:
		var ammoToAdd = min(gun.maximumMagCapacity, 50)
		if ammoToAdd < 10:
			ammoToAdd *= 2
		gun.leftoverAmmoCount += ammoToAdd
	if gunInteractor.currentWeapon.currentMagCapacity == 0:
		gunInteractor.currentWeapon.reload(true)
	AmmoInfoDisplay.gunReloaded()
	refreshAmmoDisplay()

func selectWeapon(gun: Gun) -> void:
	gunInteractor.currentWeapon = gun
	var rightHandTransform = $"Subviewport/Transform/Skeleton2D/Torso/Right Elbow/Right Arm/Right Hand/RemoteTransform2D"
	rightHandTransform.position = gunInteractor.currentWeapon.rightHandOffset
	refreshAmmoDisplay()
	WeaponSlots.setWeaponName(gunInteractor.currentWeapon.displayName)

func pickupWeapon(gun: Gun) -> void:
	selectWeapon(gun)
	
	# if you only have a single gun, the new gun can populate the second slot
	if holdingWeapons.size() == 1:
		holdingWeapons.append(gun)
		currentWeaponSlot = 2
		WeaponSlots.selectSecondary()
		WeaponSlots.secondaryWeaponPickedUp()
	else:
		# if you already have two weapons, the one you're holding must be replaced
		var previousGun: Gun = holdingWeapons[currentWeaponSlot - 1]
		EnemySpawner.spawnWeapon(previousGun, global_position)
		holdingWeapons[currentWeaponSlot - 1] = gun
	
	# update weapon slot display
	if currentWeaponSlot == 1:
		WeaponSlots.setPrimaryWeapon(gun)
	elif currentWeaponSlot == 2:
		WeaponSlots.setSecondaryWeapon(gun)
