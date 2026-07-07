class_name ConfirmationPrompt extends NinePatchRect

static var currentAcceptID = ""
static var signals = {}
static var acceptedPrompt = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var data = GamePopup.current.data
	$Title.text = data["title"]
	$Description.text = data["description"]
	$"../Cancel/Text".text = data["cancelText"]
	$"../Confirm/Text".text = data["confirmText"]
	currentAcceptID = data["signalID"]
	acceptedPrompt = false

static func onAccept(signalID: String, call: Callable) -> void:
	signals[signalID] = call

static func currentAccepted() -> void:
	if acceptedPrompt:
		return
	acceptedPrompt = true
	if currentAcceptID in signals:
		var call: Callable = signals[currentAcceptID]
		call.call()
