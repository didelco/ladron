class_name PadFilter
extends Node
## Drops the events of devices that are not really pads (Pads.FAKE) before
## anything else sees them: the menus, the player-select screen, the game.
## And puts Start and View back where they belong on the pads that send them
## swapped (Pads.SWAPPED_START): the press itself is changed, so every screen
## after this reads the right button.
## It must be the root's last child: _input goes to the last nodes first.


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and not Pads.real(event.device):
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		event.button_index = Pads.button(event.device, event.button_index)
