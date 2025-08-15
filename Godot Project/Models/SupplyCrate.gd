class_name Crate extends EnemyAI

var cashDropped = 0
func onDamage() -> void:
	var cashDropAmount = (maxHealth - currentHealth) / 10.0
	var cashToDrop = round(cashDropAmount - cashDropped)
	if cashToDrop > 0:
		EnemySpawner.spawnMoney(cashToDrop, getPosition())
	cashDropped = cashDropAmount

func onDeath() -> void:
	# spawn some random items
	Item.spawnItem("Bandages", randi_range(1, 3), getPosition())
	Item.spawnItem("HealthKit", randi_range(0, 2), getPosition())
	Item.spawnItem("MolotovCocktail", randi_range(0, 3), getPosition())
	Item.spawnItem("Grenade", randi_range(0, 3), getPosition())
	for i in range(randi_range(2, 3)):
		EnemySpawner.spawnEnemy("AmmoPickup", getPosition())
	for i in range(3):
		var special = ["ElixirOfFortune", "EnergyDrink", "PotionOfHealing", "PotionOfRage", "ShieldSpireSerum", "StaminaPotion", "WarriorSerum"]
		Item.spawnItem(special.pick_random(), 1, getPosition())
	
	# rare chance to spawn weapon upgrade kit
	if randi_range(1, 40) == 1:
		Item.spawnItem("WeaponUpgradeKit", 1, getPosition())
	
	# chance to spawn a weapon
	var spawnWeaponNames = []
	if randi_range(1, 5) == 1:
		spawnWeaponNames.append("UMP45")
	if randi_range(1, 5) == 1:
		spawnWeaponNames.append("Shotgun")
	if randi_range(1, 8) == 1:
		spawnWeaponNames.append("AK47")
	if randi_range(1, 10) == 1:
		spawnWeaponNames.append("MachineGun")
	if randi_range(1, 15) == 1:
		spawnWeaponNames.append("ScarL")
	if randi_range(1, 20) == 1:
		spawnWeaponNames.append("GrenadeLauncher")
	
	for weaponName: String in spawnWeaponNames:
		var gun = Gun.gunFromString(weaponName)
		
		# chances to have different rarities
		if randi_range(1, 5) == 1:
			gun.setWeaponRarity(Gun.Rarity.SILVER)
		if randi_range(1, 10) == 1:
			gun.setWeaponRarity(Gun.Rarity.GOLD)
		
		var weapon = EnemySpawner.spawnWeapon(gun, getPosition())
