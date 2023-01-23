class_name Logs extends TextEdit

var last_msg := ""

func add(msg: String):
  print(msg)
  if text.is_empty():
    text += msg
  else:
    text += "\n%s" % [msg]
  last_msg = msg
