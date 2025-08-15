extends Upgrade

func onUpgrade(amounts: Array) -> void:
	# enable flaming bullets
	Player.current.explosiveBullets = true
	incrementUpgradeStat(1)
	
