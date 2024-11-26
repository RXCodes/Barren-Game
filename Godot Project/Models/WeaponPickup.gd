class_name WeaponEntity extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$WeaponShadow.scale = Vector2.ZERO
	$Weapon.scale = Vector2.ZERO
	$AnimationPlayer.speed_scale = randfn(1.0, 0.15)
	$AnimationPlayer.play("GunSpawn")
	var moveTween = NodeRelations.createTween()
	moveTween.set_ease(Tween.EASE_OUT)
	moveTween.set_trans(Tween.TRANS_CUBIC)
	var newPosition = global_position
	newPosition.x += randfn(0, 12.5)
	newPosition.y += randfn(0, 7.5)
	var tweenDuration = 1.0 / $AnimationPlayer.speed_scale
	moveTween.tween_property(self, "global_position", newPosition, tweenDuration)

var gun: Gun
func setupWithGun(newGun: Gun) -> void:
	$Weapon/WeaponSprite.texture = newGun.texture
	$Weapon/WeaponSprite.scale = Vector2(newGun.dropTextureScale, newGun.dropTextureScale)
	$Weapon/WeaponSprite.position = newGun.dropTextureOffset
	gun = newGun
