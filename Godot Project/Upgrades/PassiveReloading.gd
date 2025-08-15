extends Upgrade

func onUpgrade(amounts: Array) -> void:
	# enable passive reloading
	Player.current.passiveReloading = true
	incrementUpgradeStat(1)
	
