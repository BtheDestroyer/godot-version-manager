class_name Status extends Label

var override_text := ""
@export var logs: Logs

func _process(_delta):
  if override_text.is_empty():
    text = logs.last_msg
  else:
    text = override_text
