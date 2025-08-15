class_name InventoryManager extends Node2D

static var slots = []
static var currentSlotIndex = -1
static var itemName: Label
static var itemDescription: Label
static var maxStackCount = 5
static var clickSound: AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	itemName = $ItemName
	itemDescription = $ItemDescription
	clickSound = $Click
	maxStackCount = 5
	await get_tree().physics_frame
	
	# create slots (keys 3 to 7)
	slots.clear()
	slots.append($Slot)
	var separation = 104
	$Slot.setupSlot(3)
	var slotIndex = 4
	for i in range(4):
		var newSlot: InventorySlot = $Slot.duplicate()
		add_child(newSlot)
		newSlot.position.x += (i + 1) * separation
		slots.append(newSlot)
		newSlot.setupSlot(slotIndex)
		slotIndex += 1
	selectSlot(-1)
	hideItemInfo()

static func selectSlot(index: int) -> void:
	clickSound.play()
	if getCurrentItem():
		promptTip()
	for slot in slots:
		if not is_instance_valid(slot):
			continue
		slot.deselect()
	if index == currentSlotIndex or index < 0:
		currentSlotIndex = -1
		hideItemInfo()
		return
	currentSlotIndex = index
	var selectedSlot: InventorySlot = slots[index]
	Crosshair.current.texture = preload("res://UI/Crosshairs/ItemCrosshair.png")
	selectedSlot.select()
	showItemInfo()

static func showItemInfo() -> void:
	var selectedSlot: InventorySlot = slots[currentSlotIndex]
	var item = selectedSlot.itemEntity
	if not item:
		hideItemInfo()
		return
	itemDescription.text = item.description
	itemName.text = item.displayName
	itemDescription.show()
	itemName.show()

static func hideItemInfo() -> void:
	if Player.current.gunInteractor != null:
		Crosshair.current.texture = Player.current.gunInteractor.currentWeapon.crosshairTexture
	itemDescription.hide()
	itemName.hide()

func _input(event: InputEvent) -> void:
	if GamePopup.current or TutorialManager.shouldDisableControls:
		return
	if not event.is_pressed():
		return
	if event is InputEventKey:
		var key = event.as_text_key_label()
		key = key.trim_prefix("Shift+")
		match key:
			"3": selectSlot(0)
			"4": selectSlot(1)
			"5": selectSlot(2)
			"6": selectSlot(3)
			"7": selectSlot(4)

# prompt a tip that can help users
static var promptedTip = false
static func promptTip() -> void:
	if promptedTip:
		return
	promptedTip = true
	await TimeManager.wait(2.0)
	TextAlert.setupAlert("TIP: Right click to drop items.", Color.HOT_PINK)

# picks up an item and attempts to collect all of it
# returns false if none of the items can be picked up (inventory full)
static func pickupItem(item: Item.Entity) -> bool:
	clickSound.play()
	var initialAmount = item.amount
	var leftover = item.amount
	for slot: InventorySlot in slots:
		if leftover <= 0:
			break
		if not slot.itemEntity:
			var amountToAdd = min(leftover, maxStackCount)
			leftover -= amountToAdd
			slot.itemEntity = item.copy()
			slot.itemEntity.amount = amountToAdd
		elif slot.itemEntity.identifier == item.identifier:
			var newAmount = min(slot.itemEntity.amount + leftover, maxStackCount)
			var amountToAdd = newAmount - slot.itemEntity.amount
			slot.itemEntity.amount += amountToAdd
			leftover -= amountToAdd
	if leftover > 0:
		var newItem = item.copy()
		newItem.amount = leftover
		Player.current.dropItem(newItem)
	refreshInventory()
	if initialAmount != leftover:
		var pickedUp = initialAmount - leftover
		TextAlert.setupAlert("Picked up x" + str(initialAmount) +  " " + item.displayName, Color.WHITE)
		return true
	return false

# refreshes the entire inventory
static func refreshInventory() -> void:
	for slot: InventorySlot in slots:
		slot.setupWithItemEntity(slot.itemEntity)
	if currentSlotIndex < 0:
		return
	showItemInfo()

# drops one of the currently selected item
static func dropItem() -> void:
	var currentItem = getCurrentItem()
	if not currentItem:
		return
	clickSound.play()
	currentItem.amount -= 1
	
	# all of the items are gone for this slot - shift items to the left
	if currentItem.amount == 0:
		currentItem.queue_free()
		for i in range(currentSlotIndex, slots.size()):
			if i == slots.size() - 1:
				slots[i].itemEntity = null
			else:
				slots[i].itemEntity = slots[i + 1].itemEntity
	
	# create the item to drop into the scene
	var droppingItem = currentItem.copy()
	droppingItem.amount = 1
	Player.current.dropItem(droppingItem)
	
	# refresh the inventory
	refreshInventory()

# consumes one of the currently selected item
static func consumeItem() -> void:
	consumeItemAtIndex(currentSlotIndex)

# consumes an item for a specified index
static func consumeItemAtIndex(index: int) -> void:
	var selectedSlot: InventorySlot = slots[index]
	var currentItem = selectedSlot.itemEntity
	if not currentItem:
		return
	currentItem.amount -= 1
	clickSound.play()
	
	# create a visual indicator that an item was consumed
	var itemIndicator = preload("res://UI/ItemUsed.tscn").instantiate()
	itemIndicator.setTexture(currentItem.itemTexture)
	itemIndicator.position = Crosshair.current.position
	ScreenUI.current.add_child(itemIndicator) 
	
	# all of the items are gone for this slot - shift items to the left
	if currentItem.amount == 0:
		currentItem.queue_free()
		for i in range(index, slots.size()):
			if i == slots.size() - 1:
				slots[i].itemEntity = null
			else:
				slots[i].itemEntity = slots[i + 1].itemEntity
	
	# refresh the inventory
	refreshInventory()

# gets the current item if it exists
static func getCurrentItem() -> Item.Entity:
	if currentSlotIndex < 0:
		return null
	if not slots[currentSlotIndex]:
		return null
	var selectedSlot: InventorySlot = slots[currentSlotIndex]
	var item = selectedSlot.itemEntity
	if not item:
		return null
	return item
