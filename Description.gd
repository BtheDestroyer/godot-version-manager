class_name Description extends RichTextLabel

@export var main_screen: MainScreen
@export var version_list: VersionList
@export var platform_selection: PlatformSelection

var readme := ""
var current_version := "Select a version"
var current_version_index := -1

func refresh_readme():
  if version_list == null:
    readme = "Invalid version_list export"
    return
  if main_screen == null:
    readme = "Invalid main_screen export"
    return
  if current_version_index < 0 or current_version_index >= main_screen.sorted_versions.size():
    readme = "Invalid current_version_index"
    return
  if not current_version in main_screen.versions:
    readme = "Invalid current_version"
    return
  readme = main_screen.versions[current_version].get("readme", "")

func _on_version_list_new_version_selected(version):
  if current_version == version:
    return
  current_version = version if version != null else "Select a version"
  current_version_index = version_list.currently_selected_index
  refresh_readme()

func _process(_delta):
  if main_screen.versions.size() == 0:
    text = "Loading versions..."
  else:
    text = "%s\n%s\n%s\n\nCurrent Platform: %s" % [
      current_version,
      main_screen.versions[current_version]["modified"] if current_version in main_screen.versions else "",
      readme,
      OS.get_name()
      ]
    text += "\n\nDownload Locations:"
    for i in range(1, platform_selection.item_count):
      var platform := platform_selection.get_item_text(i)
      text += "\n%s%s: %s" % ["(This) " if platform_selection._is_for_this_platform(platform) else "", platform, ProjectSettings.globalize_path(platform_selection._get_download_path(platform))]
    text += "\n\nExecutable Locations:"
    for i in range(1, platform_selection.item_count):
      var platform := platform_selection.get_item_text(i)
      text += "\n%s%s: %s" % ["(This) " if platform_selection._is_for_this_platform(platform) else "", platform, ProjectSettings.globalize_path(platform_selection._get_executable_path(platform))]
