class_name PlatformSelection extends OptionButton

@export var main_screen: MainScreen
@export var version_list: VersionList
@export var remove_button: Button
@export var download_button: Button
@export var validate_button: Button
@export var run_button: Button
@export var progress_bar_container: Control
@export var status: Status
@export var logs: Logs
@onready var http: HTTPRequest = $DownloadRequest

var _current_version: String

func _on_version_list_new_version_selected(version):
  if _current_version == version:
    return
  if version != null:
    _current_version = version
    logs.add("New version selected: %s" % [version])
  refresh_platform_list()

func _on_version_list_new_version_added(version):
  refresh_platform_list()

func _is_for_this_platform(platform: String):
  var this_platform := OS.get_name()
  var this_arch := Engine.get_architecture_name()
  var is_64_bit := "64" in this_arch
  match this_platform:
    "Windows", "macOS", "Linux":
      return platform.contains(this_platform) and (platform.contains("64") == is_64_bit)
    "UWP":
      return platform.contains("Windows") and (platform.contains("64") == is_64_bit)
  return false

func select_current_platform():
  var use_mono: bool = Settings.data.get_value("Settings", "IncludeMono", false) and Settings.data.get_value("Settings", "AutoSelectMono", false)
  if use_mono:
    for i in item_count:
      if not get_item_text(i).contains("Mono"):
        continue
      if _is_for_this_platform(get_item_text(i)):
        logs.add("Auto selecting platform %d: %s" % [i, get_item_text(i)])
        select(i)
        return
  for i in item_count:
    if _is_for_this_platform(get_item_text(i)):
      logs.add("Auto selecting platform %d: %s" % [i, get_item_text(i)])
      select(i)
      return
  select(0)

func refresh_platform_list():
  var platforms: Array = main_screen.versions[_current_version]["downloads"].keys() if _current_version in main_screen.versions else []
  var current_selection := get_item_text(selected) if item_count > 0 else "Select Platform..."
  var popup := get_popup()
  popup.clear()
  popup.add_item("Select Platform...")
  for platform in platforms:
    if not Settings.data.get_value("Settings", "IncludeMono", false) and platform.contains("Mono"):
      continue
    if not Settings.data.get_value("Settings", "AllPlatforms", false) and not _is_for_this_platform(platform):
      continue
    popup.add_item(platform)
  if Settings.data.get_value("Settings", "AutoSelectPlatform", true):
    select_current_platform()
  elif selected == -1 or current_selection != get_item_text(selected):
    select(0)
  _update_ui_states()

func _get_download_url(platform: String) -> String:
  if not _current_version in main_screen.versions:
    return ""
  var version: Dictionary = main_screen.versions[_current_version]
  if not ("downloads" in version and platform in version["downloads"]):
    return ""
  return version["downloads"][platform]

func _get_current_download_url() -> String:
  if selected <= 0 or selected >= get_popup().item_count:
    return ""
  return _get_download_url(get_item_text(selected))

func _is_current_version_downloadable() -> bool:
  return _get_current_download_url().is_empty()

func _get_download_path(platform: String) -> String:
  var download_url: String = _get_download_url(platform)
  if download_url.is_empty():
    return ""
  var extension: String = Array(download_url.split(".")).back()
  var root_directory: String = Settings.data.get_value("Settings", "LocalBuildDirectory", "user://builds")
  return root_directory.path_join("%s/%s.%s" % [_current_version, platform, extension])

func _get_current_download_path() -> String:
  if selected <= 0 or selected >= get_popup().item_count:
    return ""
  var platform := get_item_text(selected)
  return _get_download_path(platform)

func _get_executable_path(platform: String) -> String:
  var version: String = main_screen.versions[_current_version]["version"]
  if "build" in main_screen.versions[_current_version]:
    version = "%s-%s" % [main_screen.versions[_current_version]["version"], main_screen.versions[_current_version]["build"]]
  var file: String
  var root_directory: String = Settings.data.get_value("Settings", "LocalBuildDirectory", "user://builds")
  match platform:
    "Windows 64-bit", "Windows 32-bit":
      return root_directory.path_join("%s/Godot_v%s_win%s.exe" % [_current_version, version, platform.substr(8, 2)])
    "macOS":
      return root_directory.path_join("%s/Godot.app" % [_current_version])
    "Linux x86_64", "Linux x86_32":
      return root_directory.path_join("%s/Godot_v%s_linux.x86_%s" % [_current_version, version, platform.substr(10, 2)])
    # Mono
    "Windows 64-bit (Mono)", "Windows 32-bit (Mono)":
      var name := "Godot_v%s_win%s" % [version, platform.substr(8, 2)]
      return root_directory.path_join("%s/%s/%s.exe" % [_current_version, name, name])
    "macOS (Mono)":
      return root_directory.path_join("%s/Godot_mono.app" % [_current_version])
    "Linux x86_64 (Mono)", "Linux x86_32 (Mono)":
      var name := "Godot_v%s_mono_linux" % [version]
      var extension := "x86_%s" % [platform.substr(10, 2)]
      return root_directory.path_join("%s/%s_%s/%s.%s" % [_current_version, name, extension, name, extension])
  return ""

func _get_current_executable_path() -> String:
  if selected <= 0 or selected >= get_popup().item_count:
    return ""
  var platform := get_item_text(selected)
  return _get_executable_path(platform)

func _on_item_selected(index):
  _update_ui_states()

func _make_bytes_human_readable(bytes: int) -> String:
  var unit := " bytes"
  if bytes < 5000:
    return "%d%s" % [bytes, unit]
  var result: float = bytes
  result /= 1024.0
  unit = "KB"
  if result > 5000:
    result /= 1024.0
    unit = "MB"
  if result > 5000:
    result /= 1024.0
    unit = "GB"
  return "%.2f%s" % [result, unit]

var _current_download
func _process(_delta):
  if _current_download != null:
    var total := http.get_body_size()
    var downloaded := http.get_downloaded_bytes()
    var total_size := _make_bytes_human_readable(total)
    var download_size := _make_bytes_human_readable(downloaded)
    var percent := (float(downloaded) / float(total))
    status.override_text = "Downloading %s... %s / %s (%.0f%%)" % [_current_download, download_size, total_size, percent * 100.0]
    var progress_bar: Control = progress_bar_container.get_node("ProgressBar")
    progress_bar.anchor_right = lerp(progress_bar.anchor_right, percent, 0.1)

func _is_downloaded():
  var path := _get_current_download_path()
  if path.is_empty():
    return false
  return FileAccess.file_exists(path as String)

func _is_runable():
  var path := _get_current_executable_path()
  if path.is_empty():
    return false
  return _is_for_this_platform(get_item_text(selected)) and (FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path))

func _update_ui_states():
  if _current_download != null:
    disabled = true
    remove_button.disabled = true
    download_button.disabled = true
    validate_button.disabled = true
    run_button.disabled = true
    return
  disabled = false
  var directory := _get_current_download_path().get_base_dir()
  remove_button.disabled = directory.is_empty() or not DirAccess.dir_exists_absolute(directory)
  download_button.disabled = _is_current_version_downloadable()
  validate_button.disabled = not _is_downloaded()
  run_button.disabled = not _is_runable()

func _on_download_pressed():
  main_screen.save_build_data(_current_version, true)
  var download_url := _get_current_download_url()
  var download_path := _get_current_download_path()
  if download_url.is_empty() or download_path.is_empty():
    logs.add("Attempted to download when no valid platform was selected")
    push_error(logs.last_msg)
    return
  var platform := get_item_text(selected)
  if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
    await http.request_completed
  http.request_completed.connect(_on_download_complete.bind(download_path, platform), CONNECT_ONE_SHOT)
  var directory := ProjectSettings.globalize_path(download_path).get_base_dir()
  if not DirAccess.dir_exists_absolute(directory):
    DirAccess.make_dir_recursive_absolute(directory)
  http.download_file = download_path
  logs.add("Starting download (URL: %s) -> (File: %s)" % [download_url, download_path])
  match http.request(download_url):
    OK:
      _current_download = "%s for %s" % [_current_version, platform]
      var tween := progress_bar_container.create_tween()
      tween.tween_property(progress_bar_container, "custom_minimum_size:y", 32, 0.5)
    var err:
      logs.add("HTTP request failed: " + error_string(err))
  _update_ui_states()

func _post_process_download(download_path: String, platform: String):
  var directory := ProjectSettings.globalize_path(download_path).get_base_dir()
  var failed := false
  if download_path.ends_with(".zip"):
    logs.add("Unpacking zip: " + ProjectSettings.globalize_path(download_path))
    var zip_reader := ZIPReader.new()
    zip_reader.open(download_path)
    for packed_file in zip_reader.get_files():
      var full_path := directory.path_join(packed_file)
      if full_path.ends_with("/"):
        logs.add("\tCreating directory: " + packed_file)
        DirAccess.make_dir_recursive_absolute(full_path)
      else:
        logs.add("\tUnpacking file: " + packed_file)
        var data := zip_reader.read_file(packed_file)
        var file := FileAccess.open(full_path, FileAccess.WRITE)
        file.store_buffer(data)
        if "macOS" in platform:
          if full_path.ends_with("Contents/MacOS/Godot") and OS.get_name() in ["macOS", "Linux"]:
            logs.add("\t\tPost processing file for %s: chmod +x %s" % [platform, full_path])
            var cmd_out := []
            if OS.execute("chmod", ["+x", full_path], cmd_out, true) != 0:
              logs.add("\t\tPost processing failure:\t" + "\t\t\t\n".join(cmd_out))
              failed = true
        elif "Linux" in platform:
          if ProjectSettings.globalize_path(_get_executable_path(platform)) == full_path and OS.get_name() in ["macOS", "Linux"]:
            logs.add("\t\tPost processing file for %s: chmod +x %s" % [platform, full_path])
            var cmd_out := []
            if OS.execute("chmod", ["+x", full_path], cmd_out, true) != 0:
              logs.add("\t\tPost processing failure:\t" + "\t\t\t\n".join(cmd_out))
              failed = true
    logs.add("Download post process %s" % ["failed! (See log in Settings)" if failed else "completed!"])

func _on_download_complete(_result: int, response_code: int, _headers: PackedStringArray, content: PackedByteArray, download_path: String, platform: String):
  status.override_text = ""
  if response_code != 200:
    logs.add("Failed to download file. HTTP Error: %d" % [response_code])
    push_error(logs.last_msg)
    return
  logs.add("Download complete")
  _current_download = null
  var progress_bar: Control = progress_bar_container.get_node("ProgressBar")
  var tween := progress_bar_container.create_tween()
  tween.tween_property(progress_bar_container, "custom_minimum_size:y", 0, 0.5)
  tween.tween_property(progress_bar, "anchor_right", 0, 0)
  _post_process_download(download_path, platform)
  _update_ui_states()

func _on_validate_pressed():
  # TODO: Validate via hash
  logs.add("Validation not yet implemented")

func _on_run_pressed():
  var path := ProjectSettings.globalize_path(_get_current_executable_path())
  var platform := get_item_text(selected)
  logs.add("Running %s for %s..." % [_current_version, platform])
  OS.create_process(path, ["--project-manager"])
  if Settings.data.get_value("Settings", "AutoClose", false):
    get_tree().quit()

func _on_remove_pressed():
  var directory := _get_current_download_path().get_base_dir()
  match DirAccess.remove_absolute(directory):
    OK:
      logs.add("Removed build " + _current_version)
    var err:
      logs.add("Failed to remove all data: " + error_string(err))
