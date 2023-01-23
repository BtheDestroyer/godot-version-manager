extends LineEdit

@export var category := "Settings"
@export var setting := ""
@export_group("Requirement")
@export var requirement_category := "Settings"
@export var requirement_setting := ""
@onready var default_text := text

func _ready():
  text_changed.connect(update_setting)
  text = Settings.data.get_value(category, setting, text)
  Settings.data.set_value(category, setting, text)

func update_setting(new_text: String):
  Settings.data.set_value(category, setting, new_text)
  Settings.save_settings()

func reset():
  text = default_text
  update_setting(default_text)

func _process(_delta):
  editable = Settings.data.get_value(requirement_category, requirement_setting, true)
