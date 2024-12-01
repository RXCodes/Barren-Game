class_name InventorySlot extends Sprite2D

var index: int = 0
var itemEntity: ItemEntity

func setupSlot(index: int) -> void:
	$Key.text = str(index)
	self.index = index
	clearSlot()

func clearSlot() -> void:
	$Key.scale = Vector2(0.4, 0.4)
	$Amount.hide()
	$Item.hide()

func setItemCount(count: int) -> void:
	$Amount.text = str(count)
	$Amount.visible = count > 1
	$Key.scale = Vector2(0.275, 0.275)
	if count == 0:
		clearSlot()

func setupWithItemEntity(entity: ItemEntity) -> void:
	setItemCount(entity.amount)
	$Item.texture = entity.itemTexture
	$Item.offset = entity.itemOffset
	$Item.scale = Vector2(entity.itemScale, entity.itemScale)

func select() -> void:
	texture = preload("res://UI/SelectedInventorySlot.png")

func deselect() -> void:
	texture = preload("res://UI/InventorySlot.png")

class ItemEntity:
	var displayName: String
	var description: String
	var itemTexture: Texture2D
	var itemOffset: Vector2
	var itemScale: float
	var amount: int
