extends Node

@onready var data := ConfigFile.new()

func _ready():
  load_settings()

func load_settings():
  data.load("user://settings.conf")

func save_settings():
  data.save("user://settings.conf")
