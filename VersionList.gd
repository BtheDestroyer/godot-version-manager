class_name VersionList extends PanelContainer

@export var main_screen: MainScreen
@export var version_buttons_parent: Control
@export var description: Description
var currently_selected_version := ""
var currently_selected_index := -1
var _next_index := 0
var _buttons: Array[Button]

func clear_versions():
  for child in version_buttons_parent.get_children():
    child.queue_free()
  _next_index = 0
  currently_selected_index = -1
  _buttons.clear()

func select_version(version_index: int):
  if currently_selected_index == version_index:
    return
  if _buttons.size() > currently_selected_index and currently_selected_index >= 0:
    _buttons[currently_selected_index].button_pressed = false
  currently_selected_index = version_index
  if _buttons.size() > currently_selected_index and currently_selected_index >= 0:
    var selected := _buttons[currently_selected_index]
    selected.button_pressed = true
    currently_selected_version = selected.text
    new_version_selected.emit(selected.text)
  else:
    new_version_selected.emit(null)

func add_version(version: String):
  var new_version := Button.new()
  new_version.text = version
  new_version.toggle_mode = true
  new_version.pressed.connect(select_version.bind(_next_index))
  version_buttons_parent.add_child(new_version)
  _buttons.append(new_version)
  if currently_selected_index == -1 and version == currently_selected_version:
    select_version(_next_index)
  _next_index += 1

func refresh_version_list():
  clear_versions()
  main_screen.sort_versions()
  var versions := main_screen.sorted_versions
  versions.reverse()
  for version in versions:
    if Settings.data.get_value("Settings", "IncludeGodot3", true) and version.contains("Godot 3") and version.contains("stable"):
      add_version(version)
    elif Settings.data.get_value("Settings", "IncludeGodot3PreReleases", true) and version.contains("Godot 3") and not version.contains("stable"):
      add_version(version)
    elif Settings.data.get_value("Settings", "IncludeGodot4PreReleases", true) and version.contains("Godot 4") and not version.contains("stable"):
      add_version(version)
  if currently_selected_index == -1:
    select_version(0)

signal new_version_selected(version: String)
signal new_version_added(version: String)
