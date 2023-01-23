extends CheckButton

@export var category := "Settings"
@export var setting := ""
@export_group("Requirement")
@export var requirement_category := "Settings"
@export var requirement_setting := ""

func _ready():
  toggled.connect(_on_toggle)
  button_pressed = Settings.data.get_value(category, setting, button_pressed)
  Settings.data.set_value(category, setting, button_pressed)

func _on_toggle(state: bool):
  Settings.data.set_value(category, setting, state)
  Settings.save_settings()

func _process(_delta):
  disabled = not Settings.data.get_value(requirement_category, requirement_setting, true)
