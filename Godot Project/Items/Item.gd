class_name Item extends Node2D

var entity: Item.Entity
var pickupItem: NearbyItemsListInteractor.ItemPickup
var canBePickedUp = true
var pickingUp = false
var pickupDistance = 120
var pickupDuration = 0.25
var autoPickupDelay = 1.5
var timeToDespawn = 120.0
static var itemData = {}

static func _static_init() -> void:
	print("------- Setting up items -------")
	var filePaths = DirAccess.get_files_at("res://Items/")
	var loadedPaths = []
	for filePath in filePaths:
		if filePath.ends_with(".gd"):
			var itemPath = "res://Items/" + filePath
			var currentScript: Script = ResourceLoader.load(itemPath)
			if not currentScript:
				continue
			if currentScript.has_method("setup"):
				currentScript.setup()
				loadedPaths.append(itemPath)
				print("preload(\"" + itemPath + "\"),")
	if loadedPaths.size() == 0:
		print("No item paths found - loading them from predefined item paths")
		for preloadedScript in PreloadContents.preloadedItemPaths:
			if preloadedScript.has_method("setup"):
				preloadedScript.setup()
	print("------- End setup items -------")

static func spawnItem(identifier: String, amount: int, position: Vector2) -> Item:
	if identifier not in itemData.keys():
		return
	if amount <= 0:
		return
	var newItem: Item = preload("res://Items/Item.tscn").instantiate()
	newItem.setupWithItemEntity(itemData[identifier])
	newItem.entity.amount = amount
	newItem.global_position = position
	NodeRelations.rootNode.find_child("Level").add_child(newItem)
	return newItem

static func registerItem(entity: Item.Entity) -> void:
	print("Registered item with identifier: " + entity.identifier)
	itemData[entity.identifier] = entity

static func getEntity(identifier: String) -> Item.Entity:
	return itemData.get(identifier)

func setupWithItemEntity(newEntity: Item.Entity) -> void:
	entity = newEntity.copy()
	$Item.texture = newEntity.itemTexture
	$Item.offset = newEntity.itemOffset

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position.y -= 35
	$Item.scale = Vector2.ZERO
	$Shadow.scale = Vector2.ZERO
	$AnimationPlayer.speed_scale = randfn(1.0, 0.15)
	$AnimationPlayer.play("Spawn")
	var moveTween = NodeRelations.createTween()
	moveTween.set_ease(Tween.EASE_OUT)
	moveTween.set_trans(Tween.TRANS_CUBIC)
	var newPosition = global_position
	newPosition.x += randfn(0, 30)
	newPosition.y += randfn(0, 12.5)
	var tweenDuration = 1.0 / $AnimationPlayer.speed_scale
	moveTween.tween_property(self, "global_position", newPosition, tweenDuration)
	await $AnimationPlayer.animation_finished
	VillageController.addNodeToGridGroup(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Player.current.dead:
		return
	autoPickupDelay -= delta
	timeToDespawn -= delta
	if timeToDespawn <= 0:
		if pickupItem:
			NearbyItemsListInteractor.removeItem(self)
		queue_free()
		return
	if autoPickupDelay <= 0.0 and not pickingUp:
		if Save.loadValue("autoPickupItems", true):
			var distanceToPlayerSquared = Player.current.global_position.distance_squared_to(global_position)
			if distanceToPlayerSquared <= (pickupDistance * Player.current.pickUpRangeMultiplier) ** 2:
				if pickupItem:
					NearbyItemsListInteractor.removeItem(self)
				pickup()
	if pickingUp:
		pickupAnimationProgress += delta / pickupDuration
		var targetPosition = Player.current.global_position + Vector2(0, -35)
		var newPosition = originalPosition.lerp(targetPosition, pickupAnimationProgress)
		global_position = newPosition
		$Item.rotation_degrees += (global_position.x - Player.current.global_position.x) * delta
		z_index = 4096
		if pickupAnimationProgress >= 1.0:
			if not InventoryManager.pickupItem(entity):
				TextAlert.setupAlert("Your inventory is full!", Color.TOMATO)
			queue_free()

var pickupAnimationProgress = 0.0
var originalPosition: Vector2
func pickup() -> void:
	if not canBePickedUp:
		return
	canBePickedUp = false
	pickingUp = true
	originalPosition = global_position
	$AnimationPlayer.play("Pickup")
	remove_from_group("Item")

class Entity extends Node:
	var identifier: String
	var displayName: String
	var description: String
	var itemTexture: Texture2D
	var itemOffset: Vector2
	var consumable: bool = false
	var removeWhenConsumed: bool = true
	var amount: int = 1
	
	## override this method to define what happens when the user consumes this item
	var onConsume: Callable
	
	## this method should return bool and determines if an item can be consumed at a given point
	var consumeTest: Callable
	
	func copy() -> Item.Entity:
		var copy = Item.Entity.new()
		copy.identifier = identifier
		copy.displayName = displayName
		copy.description = description
		copy.itemTexture = itemTexture
		copy.itemOffset = itemOffset
		copy.consumable = consumable
		copy.onConsume = onConsume
		copy.consumeTest = consumeTest
		copy.removeWhenConsumed = removeWhenConsumed
		copy.amount = amount
		copy.onConsume = onConsume
		return copy
