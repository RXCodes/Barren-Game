class_name VillageController extends Node

# this is where the game actually happens (waves, enemy spawning, etc.)
signal completedWave
signal finishedSpawningEnemies
static var currentWave = 1
static var current: VillageController
func _ready() -> void:
	# first fade in
	current = self
	var fadeIn = ScreenUI.current.find_child("FadeIn")
	fadeIn.scale = Vector2(1000, 1000)
	currentWave = 1
	await get_tree().physics_frame
	await TimeManager.wait(0.5)
	startGridGroupLoop()
	TutorialManager.shouldDisableControls = false
	var fadeInTween = NodeRelations.createTween()
	fadeInTween.tween_property(fadeIn, "self_modulate", Color(0, 0, 0, 0), 4.0)

	# here we can start waves
	await TimeManager.wait(4.5)
	WaveDisplay.start(1, 30)
	startItemSpawnLoop()
	startSupplyDropLoop()
	prepareEnemies()
	startBluePortalLoop()
	WaveInfoDisplay.setCurrentWave(1, false)
	WaveInfoDisplay.setEnemyCount(targetEnemyCount, false)
	WaveInfoDisplay.revealDisplay()
	await TimeManager.wait(30)
	
	# the game loop: prepare enemies -> wait -> spawn enemies -> wait for player to complete wave -> repeat
	while true:
		waveStarted = true
		spawnEnemies()
		await finishedSpawningEnemies
		await completedWave
		receivingUpgrade = true
		waveStarted = false
		currentWave += 1
		var earnings = round(Player.current.compoundInterest * Player.current.cash)
		earnings += max(currentWave * 25, 200)
		Player.current.pickupCash(earnings)
		Player.current.wavesCompleted += 1
		WaveDisplay.waveCompleted(earnings)
		await TimeManager.wait(3.0)
		GamePopup.openPopup("UpgradeSelection")
		receivingUpgrade = false
		await TimeManager.wait(0.5)
		await GamePopup.popupClosed
		await TimeManager.wait(2.0)
		WaveDisplay.start(currentWave, 25)
		prepareEnemies()
		WaveInfoDisplay.setCurrentWave(currentWave)
		WaveInfoDisplay.setEnemyCount(targetEnemyCount)
		await TimeManager.wait(26)

var minimumSpawningRadiusSquared = 1000 ** 2
var maximumSpawningRadiusSquared = 2500 ** 2
var targetEnemyCount = 0

# controls how many enemies are active at once, not total spawned
var maximumActiveEnemyCount = 50

var waveStarted = false
var receivingUpgrade = false
var enemyObjectPool = []
var enemySpawnNames = []

# asychronously instantiate enemy objects on another thread
var enemiesPrepared = false
func prepareEnemies() -> void:
	# compute the amount of enemies to spawn
	enemiesPrepared = false
	var amountToSpawn = sqrt(((25 * (currentWave - 1) + 10) ** 1.25) * (currentWave - 1) * 0.3)
	amountToSpawn += randfn(0, 5)
	amountToSpawn = clampf(amountToSpawn, 10, 150)
	targetEnemyCount = round(amountToSpawn)
	
	# prepare an array of enemy names that will spawn
	enemyObjectPool.clear()
	var possibleEnemyTypes = determineEnemies()
	enemySpawnNames = []
	for i in range(round(amountToSpawn)):
		enemySpawnNames.append(possibleEnemyTypes.pick_random())
	
	# now create all the enemies in another thread
	# this prevents performance drops while instantiating massive amounts of enemies
	var batchRequest = EnemySpawner.batchInstantiateEnemies(enemySpawnNames)
	await batchRequest.completed
	if batchRequest.success:
		enemyObjectPool = batchRequest.nodes
		enemiesPrepared = true
	
# spawn all the enemies into the map
func spawnEnemies() -> void:
	var variationChances = determineEnemyVariationChances()
	var possibleEnemyTypes = determineEnemies()
	var index = 0
	for i in range(targetEnemyCount):
		while true:
			# make sure we don't reach the max active enemy count
			var currentEnemyCount = get_tree().get_nodes_in_group("Enemy").size()
			if currentEnemyCount >= maximumActiveEnemyCount:
				await TimeManager.wait(1.0)
				continue

			# determine a random point on the traversable map
			var randomPoint = getRandomSpawnPoint()
			
			# check if it is within range of the player, but not too close
			var distanceSquared = Player.current.global_position.distance_squared_to(randomPoint)
			if distanceSquared < minimumSpawningRadiusSquared or distanceSquared > maximumSpawningRadiusSquared:
				await TimeManager.wait(0.01)
				continue
			
			var enemy: Node
			if enemiesPrepared:
				enemy = enemyObjectPool[i]
			else:
				# if the enemies have not been prepared by a thread, we have to create them synchronously
				enemy = EnemySpawner.spawnEnemy(possibleEnemyTypes.pick_random(), randomPoint)
			
			# determine if this enemy should be a variant
			var enemyAI: EnemyAI = enemy.get_child(0)
			var variantChance = variationChances[enemySpawnNames[index]]
			if randf() <= variantChance:
				# after a specific amount of waves, include other variants
				if currentWave <= 12:
					enemyAI.setVariantType(EnemyAI.EnemyVariantType.ACID)
				elif currentWave > 12 and currentWave < 18:
					var roll = randi_range(1, 10)
					if roll <= 7:
						enemyAI.setVariantType(EnemyAI.EnemyVariantType.ACID)
					else:
						enemyAI.setVariantType(EnemyAI.EnemyVariantType.LIGHTNING)
				else:
					var roll = randi_range(1, 10)
					if roll <= 3:
						enemyAI.setVariantType(EnemyAI.EnemyVariantType.ACID)
					elif roll <= 8:
						enemyAI.setVariantType(EnemyAI.EnemyVariantType.LIGHTNING)
					else:
						enemyAI.setVariantType(EnemyAI.EnemyVariantType.INFERNO)
			else:
				enemyAI.setVariantType(EnemyAI.EnemyVariantType.NORMAL)
			
			# add the enemy to the scene then move on to the next enemy
			NodeRelations.rootNode.find_child("Level").add_child(enemy)
			enemyAI.enemyDied.connect(enemyKilled)
			enemy.add_to_group("Enemy")
			
			enemy.position = randomPoint
			index += 1
			await TimeManager.wait(0.01)
			break
	finishedSpawningEnemies.emit()

# determine what enemies should be spawned for a particular wave
# adjust how frequent a particular enemy spawns by adding more entries
func determineEnemies() -> Array:
	var enemyNames = ["slime_enemy"]
	if currentWave >= 3:
		enemyNames.append("slime_enemy")
		enemyNames.append("slime_enemy")
		enemyNames.append("slime_enemy")
		enemyNames.append("slime_enemy")
		enemyNames.append("slime_enemy")
		enemyNames.append("manta_ray_enemy")
	if currentWave >= 5:
		enemyNames.erase("slime_enemy")
		enemyNames.erase("slime_enemy")
		enemyNames.append("snake_enemy")
	if currentWave >= 7:
		enemyNames.append("snake_enemy")
		enemyNames.append("manta_ray_enemy")
		enemyNames.append("scorpion_enemy")
	if currentWave >= 10:
		enemyNames.append("worm_enemy")
	return enemyNames

# determines how often a variant should spawn for a particular enemy
func determineEnemyVariationChances() -> Dictionary:
	var slimeVariantChance = min((currentWave - 2.0) * 0.05, 0.5)
	var mantaRayVariantChance = min((currentWave - 7.0) * 0.05, 0.5)
	var scorpionVariantChance = min((currentWave - 9.0) * 0.05, 0.5)
	var snakeVariantChance = min((currentWave - 11.0) * 0.05, 0.5)
	var wormVariantChance = min((currentWave - 12.0) * 0.05, 0.5)
	return {
		"slime_enemy": slimeVariantChance,
		"manta_ray_enemy": mantaRayVariantChance,
		"snake_enemy": snakeVariantChance,
		"scorpion_enemy": scorpionVariantChance,
		"worm_enemy": wormVariantChance
	}

# get a random point on the traversable map
func getRandomSpawnPoint() -> Vector2:
	var navigationRegion = $"../NavigationRegions/Spawn"
	return NavigationServer2D.region_get_random_point(navigationRegion.get_rid(), 1, false)

func _process(delta: float) -> void:
	# check if the wave is completed
	currentSupplyDropCooldown -= delta
	if waveStarted:
		var enemyCount = get_tree().get_nodes_in_group("Enemy").size()
		if enemyCount == 0:
			completedWave.emit()

var maxItemDrops = 25
func startItemSpawnLoop() -> void:
	while not Player.current.dead:
		
		# this shouldn't happen while the game is paused
		if GamePopup.current:
			await TimeManager.wait(2.0)
			continue
		
		# make sure we can never exceed over 25 items at any given time on the map
		# this doesn't count player dropped items or items bought from shops
		var currentItemCount = get_tree().get_nodes_in_group("SpawnedItem").size()
		if currentItemCount >= 25:
			await TimeManager.wait(2.0)
			continue
		
		# determine a random point on the traversable map
		var randomPoint = getRandomSpawnPoint()
			
		# check if it is within range of the player, but not too close
		var distanceSquared = Player.current.global_position.distance_squared_to(randomPoint)
		if distanceSquared < minimumSpawningRadiusSquared or distanceSquared > maximumSpawningRadiusSquared:
			await TimeManager.wait(0.5)
			continue
		
		# randomly spawn items throughout the map
		if randi_range(1, 60) == 1:
			var item = Item.spawnItem("Bandages", randi_range(1, 3), randomPoint)
			item.add_to_group("SpawnedItem")
		if randi_range(1, 110) == 1:
			var item = Item.spawnItem("HealthKit", randi_range(1, 2), randomPoint)
			item.add_to_group("SpawnedItem")
		if randi_range(1, 220) == 1:
			var potions = ["ElixirOfFortune", "EnergyDrink", "PotionOfHealing", "PotionOfRage", "ShieldSpireSerum", "StaminaPotion", "WarriorSerum"]
			var item = Item.spawnItem(potions.pick_random(), randi_range(1, 2), randomPoint)
			item.add_to_group("SpawnedItem")
		await TimeManager.wait(1.0)

var supplyDropCooldown: float = 120.0
var currentSupplyDropCooldown: float = 50.0
func startSupplyDropLoop() -> void:
	while not Player.current.dead:
		
		if currentSupplyDropCooldown > 0:
			await TimeManager.wait(2.0)
			continue
		
		# this shouldn't happen while the game is paused
		if GamePopup.current:
			await TimeManager.wait(2.0)
			continue
		
		# determine a random point on the traversable map
		var randomPoint = getRandomSpawnPoint()
			
		# check if it is within range of the player, but not too close
		var distanceSquared = Player.current.global_position.distance_squared_to(randomPoint)
		if distanceSquared < minimumSpawningRadiusSquared or distanceSquared > maximumSpawningRadiusSquared:
			await TimeManager.wait(0.5)
			continue
		
		# small chance of supply drop spawning
		var roll = randi_range(0, 160)
		if roll == 1:
			currentSupplyDropCooldown = supplyDropCooldown
			EnemySpawner.spawnEnemy("SupplyCrate", randomPoint)
			TextAlert.setupAlert("A supply crate has been summoned!", Color.MEDIUM_PURPLE)
			Player.current.playUIAudio(preload("res://UI/SupplyDrop.mp3"))

var currentBluePortal: BluePortal
func startBluePortalLoop() -> void:
	while not Player.current.dead:
		var enemiesRequestingPortal = get_tree().get_nodes_in_group("RequestingTeleportation")
		if enemiesRequestingPortal.size() == 0:
			await TimeManager.wait(1.0)
			continue
		
		# if there are enemies that need to teleport, move them to the current blue portal
		if currentBluePortal:
			if not is_instance_valid(currentBluePortal):
				currentBluePortal = null
				continue
			if currentBluePortal.beingCreated:
				await TimeManager.wait(0.25)
				continue
			if not currentBluePortal.shouldTeleportEnemies:
				currentBluePortal = null
				continue
			var teleportingEnemy: EnemyAI = enemiesRequestingPortal.pick_random()
			teleportingEnemy.remove_from_group("RequestingTeleportation")
			teleportingEnemy.requestingTeleportation = false
			teleportingEnemy.collisionRigidBody.global_position = currentBluePortal.global_position
			await TimeManager.wait(0.3)
			continue
		
		# otherwise start finding a location near the player to create a new portal
		var randomPoint = getRandomSpawnPoint()
		
		# check if it is within range of the player, but not too close
		var distanceSquared = Player.current.global_position.distance_squared_to(randomPoint)
		if distanceSquared < 400 ** 2 and distanceSquared > 250 ** 2:
			
			# finally, spawn the portal
			TextAlert.setupAlert("The wizard is summoning a portal!", Color.GOLD)
			currentBluePortal = BluePortal.create(randomPoint)
		
		await TimeManager.wait(0.1)

# called every time an enemy has been killed
func enemyKilled() -> void:
	targetEnemyCount -= 1
	WaveInfoDisplay.setEnemyCount(targetEnemyCount)

# pauses events in the village controller and the level
static func pause() -> void:
	NodeRelations.rootNode.find_child("Level").process_mode = Node.PROCESS_MODE_DISABLED
	if current:
		current.process_mode = Node.PROCESS_MODE_DISABLED

# resumes processes in the village controller and the level
static func unpause() -> void:
	NodeRelations.rootNode.find_child("Level").process_mode = Node.PROCESS_MODE_INHERIT
	if current:
		current.process_mode = Node.PROCESS_MODE_INHERIT

# used to group entities into a grid for performance optimization
static var gridSize = 250
static var activeGridPositions = {}
static func addNodeToGridGroup(node: Node2D) -> void:
	if Player.current.pickUpRangeMultiplier >= 99:
		return
	var gridGroup = gridGroupForPosition(node.global_position)
	node.add_to_group(gridGroup)
	if gridGroup not in activeGridPositions.keys():
		node.process_mode = Node.PROCESS_MODE_DISABLED

static func gridGroupForPosition(position: Vector2) -> String:
	var x = round(position.x / gridSize) + 0
	var y = round(position.y / gridSize) + 0
	return str(x) + "G" + str(y)

static func gridPositionForPosition(position: Vector2) -> Vector2:
	var x = round(position.x / gridSize) * gridSize
	var y = round(position.y / gridSize) * gridSize
	return Vector2(x, y)
	
static func activateGridGroup(position: Vector2) -> void:
	var gridGroup = gridGroupForPosition(position)
	var nodes = VillageController.current.get_tree().get_nodes_in_group(gridGroup)
	activeGridPositions[gridGroup] = gridPositionForPosition(position)
	for node: Node2D in nodes:
		node.process_mode = Node.PROCESS_MODE_INHERIT

static func deactivateGridGroup(position: Vector2) -> void:
	var gridGroup = gridGroupForPosition(position)
	var nodes = VillageController.current.get_tree().get_nodes_in_group(gridGroup)
	activeGridPositions.erase(gridGroup)
	for node: Node2D in nodes:
		node.process_mode = Node.PROCESS_MODE_DISABLED

static func processGridGroups() -> void:
	var playerPosition = Player.current.global_position
	var targetRange = (Player.current.pickUpRangeMultiplier * 500)
	var targetRangeSquared = (Player.current.pickUpRangeMultiplier * 500) ** 2
	
	# find grid groups to activate
	for x in range(-targetRange - gridSize, targetRange + gridSize, gridSize):
		for y in range(-targetRange - gridSize, targetRange + gridSize, gridSize):
			var gridPosition = playerPosition + Vector2(x, y)
			if gridPosition.distance_squared_to(playerPosition) <= targetRangeSquared:
				activateGridGroup(gridPosition)
	
	# find grid groups to deactivate
	for gridGroup: String in activeGridPositions.keys():
		var gridPosition: Vector2 = activeGridPositions[gridGroup]
		if gridPosition.distance_squared_to(playerPosition) > targetRangeSquared:
			deactivateGridGroup(gridPosition)

static func startGridGroupLoop() -> void:
	while not Player.current.dead:
		await TimeManager.wait(0.25)
		if Player.current.pickUpRangeMultiplier >= 99:
			var nodes = VillageController.current.get_tree().get_nodes_in_group("GridEntities")
			for node: Node2D in nodes:
				node.process_mode = Node.PROCESS_MODE_INHERIT
			return
		processGridGroups()
