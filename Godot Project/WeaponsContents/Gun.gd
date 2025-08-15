class_name Gun extends Node

# DO NOT EDIT THESE PROPERTIES HERE!
# Go into the Inspector on the right to modify properties on a weapon.

@export_group("Gun Info")

## the user-facing display name of this weapon
@export var displayName: String = "Gun"

@export_group("Gun Properties")

## whether or not this gun needs to be cocked before firing again (like a Shotgun)
@export var needsCocking: bool = false
var cockedGun = true:
	set(setBool):
		cockedGun = setBool

## the time to wait between shots in seconds before the weapon can be fired again
@export var fireRate: float = 0.2

## the amount of pushback experienced per shot
@export var recoilAmount: float = 5.0

## if enabled, the gun can fire again while holding the shoot trigger
@export var automatic: bool = true

## how much ammo this weapon can hold per mag
@export var maximumMagCapacity: int = 10
var currentMagCapacity: int:
	set(newAmount):
		currentMagCapacity = newAmount

## how much ammo the player starts with when picking up this weapon
@export var startingAmmoCount: int = 50
var leftoverAmmoCount: int:
	set(newAmount):
		leftoverAmmoCount = newAmount

## how many bullets come from one shot - this can be increased for shotguns
@export var bulletMultiplier: int = 1

## how much time it takes to reload this weapon in seconds
@export var reloadTime: float = 1.5
var baseReloadTimeMultiplier = 1.0

@export_group("Bullet Properties")

## how much a bullet's trajectory angle deviates in degrees
@export var bulletSpreadDegrees: float = 5

## how far bullets should travel before stopping
@export var targetRange: float = 1000

## how far to deviate from the target range
@export var rangeSpread: float = 50

## how much a single bullet can damage an enemy
@export var targetDamage: float = 10

## how far to deviate from the target damage
@export var damageSpread: float = 3

## the color of the bullet when fired
@export var bulletFireColor: Color = Color.BEIGE

## the color of the trail the bullet leaves behind
@export var bulletTrailColor: Color = Color.DIM_GRAY

## the visual size of the bullet - does not affect collision
@export var bulletSize: float = 0.75

@export_group("Textures")

## this is the graphic used to display this weapon
@export var texture: Texture2D

## the shell graphic to use for this weapon (dropped when cocking a weapon)
## this requires the cocking animation to call an event to trigger at a specific time
@export var shellTexture: Texture2D

## the magazine graphic to use for this weapon (this is dropped when finishing reloading)
## this requires the reloading animation to call an event to trigger at a specific time
@export var magazineTexture: Texture2D

## the crosshair icon to use for this weapon
@export var crosshairTexture: Texture2D

## the drawing offset for the gun texture - this only applies to the player model
@export var drawingOffset: Vector2 = Vector2.ZERO

## how much to offset the right hand to correctly hold the gun - affects the player model only
@export var rightHandOffset: Vector2 = Vector2.ZERO

## how much to offset where the gun is held by the land hand to correctly hold the gun - affects the player model only
@export var leftHandOffset: Vector2 = Vector2.ZERO

## drop texture offset
@export var dropTextureOffset: Vector2 = Vector2.ZERO

## drop texture scale
@export var dropTextureScale: float = 1.0

## enable if you shouldn't see the player's right arm while holding this weapon (UMP45)
## this is used to hide the arm when the right and left hands are too close
@export var hideRightArm: bool = false

@export_group("Audio")

## the sound to use when firing the weapon
@export var shootSound: AudioStream

## volume offset of the shoot sound in db
@export var shootVolumeOffset: float = -8.0

## pitch variance of the shoot sound
@export var shootPitchVariance: float = 0.15

## the sound to use when cocking the weapon
## -- this requires an animation to trigger this sound effect
@export var cockingSound: AudioStream

## volume offset of the cocking sound
@export var cockingSoundVolumeOffset: float = -3.0

## the sound to use when reloading the weapon
## -- this requires an animation to trigger this sound effect
@export var reloadSound: AudioStream

## volume offset of the reload sound
@export var reloadSoundVolumeOffset: float = -2.0

@export_group("Silver Rarity Property Overrides")

## how much to multiply the spread for silver rarity
@export var silverTargetSpreadMultiplier: float = 0.9

## how much to multiply the damage for silver rarity
@export var silverTargetDamageMultiplier: float = 1.4

## how much to multiply the firing rate for silver rarity
@export var silverFireRateMultiplier: float = 0.85

## how much to multiply the reload time for silver rarity
@export var silverReloadTimeMultiplier: float = 0.7

## how much to increase the magazine size for silver rarity
@export var silverMagazineSizeIncrease: int = 10

## how much to increase the bullet multiplier for silver rarity
@export var silverBulletMultiplierIncrease: int = 0


@export_group("Golden Rarity Property Overrides")

## how much to multiply the spread for golden rarity
@export var goldenTargetSpreadMultiplier: float = 0.8

## how much to multiply the damage for golden rarity
@export var goldenTargetDamageMultiplier: float = 2.0

## how much to multiply the firing rate for golden rarity
@export var goldenFireRateMultiplier: float = 0.75

## how much to multiply the reload time for golden rarity
@export var goldenReloadTimeMultiplier: float = 0.5

## how much to increase the magazine size for golden rarity
@export var goldenMagazineSizeIncrease: int = 20

## how much to increase the bullet multiplier for golden rarity
@export var goldenBulletMultiplierIncrease: int = 0

var canFire = true
var reloading = false
enum Rarity {COMMON, SILVER, GOLD}
var rarity: Gun.Rarity = Rarity.COMMON

## must be only called once
var raritySet = false
func setWeaponRarity(newRarity: Gun.Rarity) -> void:
	if raritySet:
		return
	raritySet = true
	rarity = newRarity
	if newRarity == Rarity.SILVER:
		rangeSpread *= silverTargetSpreadMultiplier
		targetDamage *= silverTargetDamageMultiplier
		fireRate *= silverFireRateMultiplier
		baseReloadTimeMultiplier = silverReloadTimeMultiplier
		maximumMagCapacity += silverMagazineSizeIncrease
		bulletMultiplier += silverBulletMultiplierIncrease
		displayName = "Silver " + displayName
	if newRarity == Rarity.GOLD:
		rangeSpread *= goldenTargetSpreadMultiplier
		targetDamage *= goldenTargetDamageMultiplier
		fireRate *= goldenFireRateMultiplier
		baseReloadTimeMultiplier = goldenReloadTimeMultiplier
		maximumMagCapacity += goldenMagazineSizeIncrease
		bulletMultiplier += goldenBulletMultiplierIncrease
		displayName = "Golden " + displayName

var shootAudioPlayer: AudioStreamPlayer2D
var lastBulletAngleRadians: float
var sourceNode: Node2D
var fileName: String
func fire(holding: bool, angleRadians: float) -> void:
	gunInteractor.gunSprite.texture = gunInteractor.currentWeapon.texture
	if not automatic and holding:
		return
	if not canFire or reloading:
		return
	if currentMagCapacity <= 0:
		return
	if needsCocking:
		if not cockedGun:
			return
		cockedGun = false
	canFire = false
	currentMagCapacity -= 1
	gunInteractor.ammoConsumptionPercent -= gunInteractor.ammoConsumptionDecrease
	if gunInteractor.ammoConsumptionPercent <= 0.0:
		gunInteractor.ammoConsumptionPercent = 100.0
		currentMagCapacity += 1
	lastBulletAngleRadians = angleRadians
	if shootAudioPlayer:
		shootAudioPlayer.pitch_scale = randfn(1.0, shootPitchVariance)
		shootAudioPlayer.play()
	if gunInteractor.onFire:
		gunInteractor.onFire.call()
	for i in range(bulletMultiplier):
		Bullet.fire(gunInteractor.originNode.global_position, angleRadians, self, sourceNode, gunInteractor.sourcePositionOffset)
	await TimeManager.wait(fireRate / gunInteractor.fireRateDivisor)
	canFire = true

func reloadAmount(count: int):
	var lastMagCapacity = currentMagCapacity
	currentMagCapacity += min(count, leftoverAmmoCount)
	currentMagCapacity = min(currentMagCapacity, maximumMagCapacity)
	var ammoTaken = currentMagCapacity - lastMagCapacity
	leftoverAmmoCount -= ammoTaken

var reloadAudioPlayer: AudioStreamPlayer2D
func playReloadSound() -> void:
	if reloadAudioPlayer:
		reloadAudioPlayer.play()

var reloadTimer: SceneTreeTimer
func reload(forced: bool) -> void:
	if reloading or (not canFire and not forced):
		return
	var modifiedMaximumMagCapacity = round(maximumMagCapacity * gunInteractor.magazineCapacityMultiplier)
	if currentMagCapacity >= modifiedMaximumMagCapacity or leftoverAmmoCount <= 0:
		return
	reloading = true
	if gunInteractor.onReload:
		gunInteractor.onReload.call()
	var playbackSpeed = gunInteractor.reloadSpeedDivisor / baseReloadTimeMultiplier
	var newReloadTimer = TimeManager.waitTimer(reloadTime / playbackSpeed)
	reloadAudioPlayer.pitch_scale = playbackSpeed
	reloadTimer = newReloadTimer
	await reloadTimer.timeout
	if reloadTimer != newReloadTimer:
		return
	var ammoAmountNeeded = modifiedMaximumMagCapacity - currentMagCapacity
	var ammoLeft = max(leftoverAmmoCount - ammoAmountNeeded, 0)
	currentMagCapacity += leftoverAmmoCount - ammoLeft
	leftoverAmmoCount = ammoLeft
	if gunInteractor.onFinishReload:
		gunInteractor.onFinishReload.call()
	reloading = false
	cockedGun = false
	if needsCocking:
		cockWeapon()

func cancelReload() -> void:
	if reloading:
		reloading = false
		reloadTimer = null
		if reloadAudioPlayer:
			reloadAudioPlayer.stop()
		if gunInteractor.onReloadInterrupted:
			gunInteractor.onReloadInterrupted.call()
		gunInteractor.gunSprite.texture = gunInteractor.currentWeapon.texture

func cockWeapon() -> void:
	if cockedGun or not needsCocking:
		return
	if gunInteractor.onCockWeapon:
		gunInteractor.onCockWeapon.call()
		cockedGun = true

func dropShell() -> void:
	if shellTexture:
		var newShell = BulletShell.new()
		newShell.texture = shellTexture
		newShell.global_position = gunInteractor.originNode.global_position + gunInteractor.sourcePositionOffset
		newShell.xVelocity = Vector2.from_angle(lastBulletAngleRadians).x * -35
		NodeRelations.rootNode.find_child("Level").add_child(newShell)

func dropMagazine() -> void:
	if magazineTexture:
		var newMagazine = BulletShell.new()
		newMagazine.texture = magazineTexture
		newMagazine.global_position = gunInteractor.originNode.global_position + gunInteractor.sourcePositionOffset
		NodeRelations.rootNode.find_child("Level").add_child(newMagazine)

var cockingAudioPlayer: AudioStreamPlayer2D
func playCockingSound() -> void:
	if cockingAudioPlayer:
		cockingAudioPlayer.play()

static func gunFromString(string: String) -> Gun:
	var weaponScene = load("res://Weapons/" + string + ".tscn")
	var weapon: Gun = weaponScene.instantiate()
	weapon.fileName = string
	return weapon

# this is what other nodes can use to be able to use guns (see PlayerController.gd)
# yes, this also includes enemies! (or any Node2D)
var gunInteractor: Gun.Interactor
class Interactor:
	var audioStreams = {}
	var weapons = []
	var fireRateDivisor: float = 1.0
	var reloadSpeedDivisor: float = 1.0
	var magazineCapacityMultiplier: float = 1.0
	var damageMultiplier: float = 1.0
	var ammoConsumptionDecrease: float = 0.0
	var ammoConsumptionPercent: float = 100.0
	var currentWeapon: Gun:
		set(newWeapon):
			if not weapons.has(newWeapon.displayName):
				# setup audio players for different sounds the gun can play
				if newWeapon.shootSound:
					var newAudioPlayer = AudioStreamPlayer2D.new()
					newAudioPlayer.stream = newWeapon.shootSound
					newAudioPlayer.max_polyphony = 10
					newAudioPlayer.volume_db = newWeapon.shootVolumeOffset 
					originNode.add_child(newAudioPlayer)
					newWeapon.shootAudioPlayer = newAudioPlayer
					audioStreams[newWeapon.displayName + "-shoot"] = newAudioPlayer
				if newWeapon.cockingSound:
					var newAudioPlayer = AudioStreamPlayer2D.new()
					newAudioPlayer.stream = newWeapon.cockingSound
					newAudioPlayer.max_polyphony = 2
					newAudioPlayer.volume_db = newWeapon.cockingSoundVolumeOffset
					originNode.add_child(newAudioPlayer)
					newWeapon.cockingAudioPlayer = newAudioPlayer
					audioStreams[newWeapon.displayName + "-cocking"] = newAudioPlayer
				if newWeapon.reloadSound:
					var newAudioPlayer = AudioStreamPlayer2D.new()
					newAudioPlayer.stream = newWeapon.reloadSound
					newAudioPlayer.max_polyphony = 1
					newAudioPlayer.volume_db = newWeapon.reloadSoundVolumeOffset
					originNode.add_child(newAudioPlayer)
					newWeapon.reloadAudioPlayer = newAudioPlayer
					audioStreams[newWeapon.displayName + "-reload"] = newAudioPlayer
				weapons.append(newWeapon.displayName)
				
				# setup ammo
				newWeapon.currentMagCapacity = newWeapon.maximumMagCapacity
				newWeapon.leftoverAmmoCount = newWeapon.maximumMagCapacity * 3
			else:
				newWeapon.shootAudioPlayer = audioStreams.get(newWeapon.displayName + "-shoot")
				newWeapon.cockingAudioPlayer = audioStreams.get(newWeapon.displayName + "-cocking")
				newWeapon.reloadAudioPlayer = audioStreams.get(newWeapon.displayName + "-reload")
			newWeapon.gunInteractor = self
			currentWeapon = newWeapon
			newWeapon.sourceNode = originNode
			gunSprite.texture = currentWeapon.texture
			if newWeapon.rarity == Gun.Rarity.COMMON:
				gunSprite.material = null
			if newWeapon.rarity == Gun.Rarity.SILVER:
				gunSprite.material = preload("res://WeaponsContents/Silver.tres")
			if newWeapon.rarity == Gun.Rarity.GOLD:
				gunSprite.material = preload("res://WeaponsContents/Golden.tres")
			if originNode is Player:
				gunSprite.offset = currentWeapon.drawingOffset
			if not newWeapon.cockedGun and newWeapon.leftoverAmmoCount > 0:
				newWeapon.cockWeapon()
	var gunSprite: Sprite2D
	var onFire: Callable
	var onReload: Callable
	var onFinishReload: Callable
	var onReloadInterrupted: Callable
	var onCockWeapon: Callable
	var originNode: Node2D
	var sourcePositionOffset: Vector2
