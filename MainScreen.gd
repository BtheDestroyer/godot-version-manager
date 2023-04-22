class_name MainScreen extends Control

@export var logs: Logs
var versions: Dictionary

var sorted_versions: Array

const GODOT_URL := "https://downloads.tuxfamily.org/godotengine/"

func _ready():
  refresh_builds()

func _add_local_builds():
  var root_directory = Settings.data.get_value("Settings", "LocalBuildDirectory")
  if root_directory == null:
    return
  var dir_access := DirAccess.open(root_directory)
  if dir_access == null:
    return
  for build in dir_access.get_directories():
    var build_info := FileAccess.open(root_directory.path_join(build).path_join("build_info.json"), FileAccess.READ)
    if build_info == null:
      logs.add("Failed to read build data for local build %s: %s" % [build, error_string(FileAccess.get_open_error())])
      continue
    versions[build] = JSON.parse_string(build_info.get_as_text())
    logs.add("Added local build data for " + build)
  sort_versions()
  versions_updated.emit()

func save_build_data(version: String, force := false):
  var directory: String = Settings.data.get_value("Settings", "LocalBuildDirectory", "user://build").path_join(version)
  if not DirAccess.dir_exists_absolute(directory):
    if not force:
      return
    DirAccess.make_dir_recursive_absolute(directory)
  var build_info := FileAccess.open(directory.path_join("build_info.json"), FileAccess.WRITE)
  if build_info == null:
    logs.add("Failed to save build data for %s: %s" % [version, error_string(FileAccess.get_open_error())])
    return
  build_info.store_string(JSON.stringify(versions[version], "  "))
  logs.add("Stored local build data for " + version)

func refresh_builds():
  logs.add("Refreshing builds...")
  versions.clear()
  sorted_versions.clear()
  _add_local_builds()
  _get_godot_builds(await _get_html_file_list_array(GODOT_URL))

func _get_html_file_list(url: String) -> String:
  var http_response: Array
  var http := HTTPRequest.new()
  add_child(http)
  var request_result := http.request(url)
  if request_result != OK:
    push_error("HTTP Request failed: ", error_string(request_result))
    return ""
  http_response = await http.request_completed
  http.queue_free()
  var response_code: int = http_response[1]
  if response_code != 200:
    push_error("HTTP response_code=", response_code, " from url ", url)
    return ""
  var headers: PackedStringArray = http_response[2]
  var body: PackedByteArray = http_response[3]
  var html := HTML.get_body_as_string(headers, body)
  var html_list := HTML.walk_html_for_tag_path(html, [
    "body",
    ["div", ["class=\"list\""]],
    "table",
    "tbody"
    ])
  if html_list.is_empty():
    push_warning("HTTP Response had no list")
    return ""
  return html_list

func _convert_html_file_list_to_array(html_list: String) -> PackedStringArray:
  var rows: PackedStringArray
  while not html_list.is_empty():
    var row := HTML.get_child_tag(html_list, "tr")
    if row.is_empty():
      break
    rows.append(row)
    html_list = html_list.substr(html_list.find(row) + row.length() + "</tr>\n".length())
  return rows

func _get_html_file_list_array(url: String) -> PackedStringArray:
  return await _convert_html_file_list_to_array(await _get_html_file_list(url))

func _add_builds_from_html(row: String):
  var build_data: Dictionary = await _add_build_from_html(row)
  if build_data.is_empty():
    return
  var child_list: PackedStringArray = await _get_html_file_list_array(build_data["url"])
  child_list.reverse()
  for child in child_list:
    _add_prerelease_from_html(child, build_data["version"])

func _get_godot_builds(builds: PackedStringArray):
  for build in builds:
    _add_builds_from_html(build)

func sort_versions():
  sorted_versions = versions.keys()
  sorted_versions.sort_custom(
    func(a, b):
      a = versions[a]["modified_dict"]
      b = versions[b]["modified_dict"]
      if a["year"] < b["year"]:
        return true
      if a["year"] > b["year"]:
        return false
      if a["month"] < b["month"]:
        return true
      if a["month"] > b["month"]:
        return false
      if a["day"] < b["day"]:
        return true
      if a["day"] > b["day"]:
        return false
      if a["hour"] < b["hour"]:
        return true
      if a["hour"] > b["hour"]:
        return false
      if a["minute"] < b["minute"]:
        return true
      if a["minute"] > b["minute"]:
        return false
      if a["second"] < b["second"]:
        return true
      if a["second"] > b["second"]:
        return false
      return true
      )

func _first_file_in_list(file_list: Array[String], patterns: Array[String]):
  for pattern in patterns:
    if pattern in file_list:
      return pattern
  return ""

func _find_win64_url(file_list: Array[String], version: String, build: String) -> String:
  return _first_file_in_list(file_list, [
    "Godot_v%s-%s_win64.exe.zip" % [version, build],
    "Godot_v%s-%s_mono_win64.zip" % [version, build],
    ])

func _find_win32_url(file_list: Array[String], version: String, build: String) -> String:
  return _first_file_in_list(file_list, [
    "Godot_v%s-%s_win32.exe.zip" % [version, build],
    "Godot_v%s-%s_mono_win32.zip" % [version, build],
    ])

func _find_macos_url(file_list: Array[String], version: String, build: String, mono := false) -> String:
  return _first_file_in_list(file_list, [
    "Godot_v%s-%s_macos.universal.zip" % [version, build],
    "Godot_v%s-%s_mono_macos.universal.zip" % [version, build],
    "Godot_v%s-%s_osx.universal.zip" % [version, build],
    "Godot_v%s-%s_mono_osx.universal.zip" % [version, build],
    "Godot_v%s-%s_osx.fat.zip" % [version, build],
    "Godot_v%s-%s_mono_osx.fat.zip" % [version, build],
    ])

func _find_linux64_url(file_list: Array[String], version: String, build: String, mono := false) -> String:
  return _first_file_in_list(file_list, [
    "Godot_v%s-%s_linux.x86_64.zip" % [version, build],
    "Godot_v%s-%s_mono_linux.x86_64.zip" % [version, build],
    "Godot_v%s-%s_linux_x86_64.zip" % [version, build],
    "Godot_v%s-%s_mono_linux_x86_64.zip" % [version, build],
    "Godot_v%s-%s_x11.64.zip" % [version, build],
    "Godot_v%s-%s_mono_x11.64.zip" % [version, build],
    "Godot_v%s-%s_x11_64.zip" % [version, build],
    "Godot_v%s-%s_mono_x11_64.zip" % [version, build],
    ])

func _find_linux32_url(file_list: Array[String], version: String, build: String, mono := false) -> String:
  return _first_file_in_list(file_list, [
    "Godot_v%s-%s_linux.x86_32.zip" % [version, build],
    "Godot_v%s-%s_mono_linux.x86_32.zip" % [version, build],
    "Godot_v%s-%s_linux_x86_32.zip" % [version, build],
    "Godot_v%s-%s_mono_linux_x86_32.zip" % [version, build],
    "Godot_v%s-%s_x11.32.zip" % [version, build],
    "Godot_v%s-%s_mono_x11.32.zip" % [version, build],
    "Godot_v%s-%s_x11_32.zip" % [version, build],
    "Godot_v%s-%s_mono_x11_32.zip" % [version, build],
    ])

func _find_web_url(file_list: Array[String], version: String, build: String) -> String:
  return _first_file_in_list(file_list, ["Godot_v%s-%s_web.zip" % [version, build]])

func _find_readme_url(file_list: Array[String]) -> String:
  return _first_file_in_list(file_list, ["README.txt"])

func _add_version(version: String, build: String, modified: String, url_root: String) -> Dictionary:
  var html_list: String = await _get_html_file_list(url_root)
  var file_list: Array[String]
  while not html_list.is_empty():
    var row := HTML.get_child_tag(html_list, "tr")
    if row.is_empty():
      break
    html_list = html_list.substr(html_list.find(row) + row.length() + "</tr>\n".length())
    var row_name := HTML.get_child_tag(row, "td", ["class=\"n\""])
    if row_name.is_empty():
      continue
    file_list.append(HTML.get_child_tag(row_name, "a"))
  var downloads := {
      "Windows 64-bit": _find_win64_url(file_list, version, build),
      "Windows 32-bit": _find_win32_url(file_list, version, build),
      "macOS": _find_macos_url(file_list, version, build),
      "Linux x86_64": _find_linux64_url(file_list, version, build),
      "Linux x86_32": _find_linux32_url(file_list, version, build),
      "Web": _find_web_url(file_list, version, build),
      }
  if "mono" in file_list:
    html_list = await _get_html_file_list(url_root.path_join("mono"))
    var mono_file_list: Array[String]
    while not html_list.is_empty():
      var row := HTML.get_child_tag(html_list, "tr")
      if row.is_empty():
        break
      html_list = html_list.substr(html_list.find(row) + row.length() + "</tr>\n".length())
      var row_name := HTML.get_child_tag(row, "td", ["class=\"n\""])
      if row_name.is_empty():
        continue
      mono_file_list.append(HTML.get_child_tag(row_name, "a"))
    downloads.merge({
      "Windows 64-bit (Mono)": _find_win64_url(mono_file_list, version, build),
      "Windows 32-bit (Mono)": _find_win32_url(mono_file_list, version, build),
      "macOS (Mono)": _find_macos_url(mono_file_list, version, build),
      "Linux x86_64 (Mono)": _find_linux64_url(mono_file_list, version, build),
      "Linux x86_32 (Mono)": _find_linux32_url(mono_file_list, version, build)
    })
  for platform in downloads.keys():
    if downloads[platform] == null or downloads[platform].is_empty():
      downloads.erase(platform)
    elif platform.contains("Mono"):
      downloads[platform] = "mono".path_join(downloads[platform])
  if downloads.is_empty():
    return {
      "version": version,
      "build": build,
      "url": url_root,
    }
  var key := "Godot %s %s" % [version, build]
  versions[key] = {
    "version": version,
    "build": build,
    "modified": modified,
    "modified_dict": Time.get_datetime_dict_from_datetime_string(modified, false),
    "url": url_root,
    "downloads": downloads,
  }
  var readme: String = _find_readme_url(file_list)
  if not readme.is_empty():
    versions[key]["readme"] = readme
  const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  for i in 12:
    if modified.contains(MONTHS[i]):
      versions[key]["modified_dict"]["month"] = i
      break
  logs.add("Added remote build data for " + key)
  save_build_data(key)
  sort_versions()
  versions_updated.emit()
  return versions[key]

func _add_build_from_html(row: String) -> Dictionary:
    var row_name := HTML.get_child_tag(row, "td", ["class=\"n\""])
    if row_name.is_empty():
      return {}
    var version := HTML.get_child_tag(row_name, "a")
    if not (version.begins_with("3.") or version.begins_with("4.")):
      return {}
    var row_modified := HTML.get_child_tag(row, "td", ["class=\"m\""])
    if row_modified.is_empty():
      return {}
    return await _add_version(version, "stable", row_modified, GODOT_URL.path_join(version))

func _add_prerelease_from_html(row: String, version: String) -> Dictionary:
    var row_name := HTML.get_child_tag(row, "td", ["class=\"n\""])
    if row_name.is_empty():
      return {}
    var build := HTML.get_child_tag(row_name, "a")
    if not build.begins_with("pre-alpha") and not build.begins_with("alpha") and not build.begins_with("beta") and not build.begins_with("rc") and not build.begins_with("dev"):
      return {}
    var row_modified := HTML.get_child_tag(row, "td", ["class=\"m\""])
    if row_modified.is_empty():
      return {}
    return await _add_version(version, build, row_modified, GODOT_URL.path_join(version).path_join(build))

signal versions_updated()

func _on_settings_pressed():
  $VersionList.visible = false
  $Settings.visible = true

func _on_versions_pressed():
  $VersionList.visible = true
  $Settings.visible = false

func clear_all_data():
  var root_directory: String = Settings.data.get_value("Settings", "LocalBuildDirectory", "user://builds")
  match DirAccess.remove_absolute(root_directory):
    OK:
      logs.add("Removed all data")
    var err:
      logs.add("Failed to remove all data: " + error_string(err))
