extends Upgrade

func onUpgrade(amounts: Array) -> void:
	# spawn a supply crate near the player
	while true:
		await TimeManager.wait(0.01)
		var spawnPoint = VillageController.current.getRandomSpawnPoint()
		var distancedSquared = spawnPoint.distance_squared_to(Player.current.global_position)
		if distancedSquared <= 450 ** 2 and distancedSquared > 75 ** 2:
			EnemySpawner.spawnEnemy("SupplyCrate", spawnPoint)
			TextAlert.setupAlert("A supply crate has summoned near you!", Color.DARK_ORANGE)
			Player.current.playUIAudio(preload("res://UI/SupplyDrop.mp3"))
			break
