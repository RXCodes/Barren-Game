class_name TutorialManager extends Node

static var shouldDisableControls = false
static var inTutorial = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TutorialManager.inTutorial = true
	var fadeIn = $"../ScreenUI/FadeIn"
	fadeIn.scale = Vector2(1000, 1000)
	await get_tree().physics_frame
	shouldDisableControls = true
	await TimeManager.wait(0.2)
	var primaryGun: Gun = Player.current.holdingWeapons[0]
	primaryGun.leftoverAmmoCount = 0
	primaryGun.currentMagCapacity = 0
	AmmoInfoDisplay.setAmmoLeft(0)
	AmmoInfoDisplay.setMagCapacity(0)
	var fadeInTween = NodeRelations.createTween()
	fadeInTween.tween_property(fadeIn, "self_modulate", Color(0, 0, 0, 0), 4.0)
	startGridGroupLoop()
	await TimeManager.wait(6.5)
	
	GamePopup.openPopup("TutorialMovementControls")
	shouldDisableControls = false
	await $"../TutorialTrigger1".body_entered
	GamePopup.openPopup("TutorialSprinting")
	await $"../TutorialTrigger2".body_entered
	GamePopup.openPopup("TutorialGunUsage")
	
	# wait for all enemies to be defeated
	while true:
		await TimeManager.wait(0.25)
		var enemies = get_tree().get_nodes_in_group("TutorialDummy")
		if enemies.size() == 0:
			break
	$"../Barrier/StaticBody2D".queue_free()
	$"../Barrier".emitting = false

	await $"../TutorialTrigger3".body_entered
	GamePopup.openPopup("TutorialShop")

	# wait for the player to buy an item from the shop
	while true:
		await TimeManager.wait(0.25)
		var weaponItems = get_tree().get_nodes_in_group("Weapon")
		if weaponItems.size() > 0:
			break
		
		# don't let the weapon despawn
		for weapon in weaponItems:
			weapon = weapon as WeaponEntity
			weapon.canDespawn = false
		
	await TimeManager.wait(2.5)
	GamePopup.openPopup("TutorialItemPickup")
	
	# wait for the player to pick up the gun
	while true:
		await TimeManager.wait(0.25)
		if Player.current.holdingWeapons.size() == 2:
			break
	$"../Barrier2/StaticBody2D".queue_free()
	$"../FinalText".show()
	$"../Barrier2".emitting = false
	
	# wait for the player to defeat all the enemies at the end
	while true:
		await TimeManager.wait(0.25)
		var enemies = get_tree().get_nodes_in_group("TutorialDummyFinal")
		if enemies.size() == 0:
			break
	GamePopup.openPopup("TutorialComplete")
	
	# wait for the player to close the last popup
	while true:
		await TimeManager.wait(0.25)
		if not is_instance_valid(GamePopup.current):
			break
	await TimeManager.wait(1.0)
	
	# tutorial has been completed
	var fadeOutTween = NodeRelations.createTween()
	fadeOutTween.tween_property(fadeIn, "self_modulate", Color.BLACK, 3.0)
	TutorialManager.inTutorial = false
	Save.saveValue("completedTutorial", true)
	await TimeManager.wait(3.5)
	NodeRelations.loadScene("res://Scenes/TitleScreen.tscn")

# used to group entities into a grid for performance optimization
static var gridSize = 250
static var activeGridPositions = {}
static func addNodeToGridGroup(node: Node2D) -> void:
	if not is_instance_valid(Player.current):
		return;
	if Player.current.pickUpRangeMultiplier >= 99:
		return
	var gridGroup = gridGroupForPosition(node.global_position)
	node.add_to_group(gridGroup)
	if gridGroup not in activeGridPositions.keys():
		node.process_mode = Node.PROCESS_MODE_DISABLED

static func gridGroupForPosition(position: Vector2) -> String:
	var x = round(position.x / gridSize)
	var y = round(position.y / gridSize)
	return str(x) + "G" + str(y)

static func gridPositionForPosition(position: Vector2) -> Vector2:
	var x = round(position.x / gridSize) * gridSize
	var y = round(position.y / gridSize) * gridSize
	return Vector2(x, y)
	
static func activateGridGroup(position: Vector2) -> void:
	var gridGroup = gridGroupForPosition(position)
	var nodes = NodeRelations.rootNode.get_tree().get_nodes_in_group(gridGroup)
	activeGridPositions[gridGroup] = gridPositionForPosition(position)
	for node: Node2D in nodes:
		node.process_mode = Node.PROCESS_MODE_INHERIT

static func deactivateGridGroup(position: Vector2) -> void:
	var gridGroup = gridGroupForPosition(position)
	var nodes = NodeRelations.rootNode.get_tree().get_nodes_in_group(gridGroup)
	activeGridPositions.erase(gridGroup)
	for node: Node2D in nodes:
		node.process_mode = Node.PROCESS_MODE_DISABLED

static func processGridGroups() -> void:
	var playerPosition = Player.current.global_position
	var targetRange = (Player.current.pickUpRangeMultiplier * 500)
	var targetRangeSquared = (Player.current.pickUpRangeMultiplier * 500) ** 2
	
	# find grid groups to activate
	for x in range(-targetRange, targetRange, gridSize):
		for y in range(-targetRange, targetRange, gridSize):
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
		if not is_instance_valid(Player.current):
			return;
		if Player.current.pickUpRangeMultiplier >= 99:
			var nodes = VillageController.current.get_tree().get_nodes_in_group("GridEntities")
			for node: Node2D in nodes:
				node.process_mode = Node.PROCESS_MODE_INHERIT
			return
		processGridGroups()
