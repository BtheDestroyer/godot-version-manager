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
  _get_github_builds()

func _get_releases_from_github() -> Array:
  var http := HTTPRequest.new()
  add_child(http)
  http.request("https://api.github.com/repos/godotengine/godot-builds/releases?per_page=50", ["Accept: application/vnd.github+json"])
  var result = await http.request_completed
  http.queue_free()
  return JSON.parse_string(result[3].get_string_from_utf8())

func _get_github_builds():
  for release in await _get_releases_from_github():
    _add_github_version(release["tag_name"], release["published_at"], release["html_url"], release["body"], release["assets"], release["prerelease"])

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

static func _markdown_to_bbcode_tag(markdown: String, regex_pattern: String, bbcode_tag: String, suffix := "") -> String:
  var regex := RegEx.create_from_string(regex_pattern)
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}[{1}]{2}[/{1}]{3}".format([markdown.substr(plain_start, RE_match.get_start() - plain_start), bbcode_tag, RE_match.strings[1], suffix])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode_url(markdown: String) -> String:
  var regex := RegEx.create_from_string("\\[(.+)\\]\\((.+)\\)")
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}[url={1}]{2}[/url]".format([markdown.substr(plain_start, RE_match.get_start() - plain_start), RE_match.strings[2], RE_match.strings[1]])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode_ul(markdown: String) -> String:
  var regex := RegEx.create_from_string("(?<=\n)- ?(.+)\n")
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}[ul]{1}[/ul]\n".format([markdown.substr(plain_start, RE_match.get_start() - plain_start), RE_match.strings[1]])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode_hr(markdown: String) -> String:
  var regex := RegEx.create_from_string("\n---+\n")
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}\n[fill][font_size=1][bgcolor=#cccccc] [/bgcolor][/font_size][/fill]\n".format([markdown.substr(plain_start, RE_match.get_start() - plain_start)])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode_h1(markdown: String) -> String:
  var regex := RegEx.create_from_string("\n#(.+)\n")
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}\n[font_size=30]{1}[/font_size]\n".format([markdown.substr(plain_start, RE_match.get_start() - plain_start), RE_match.strings[1]])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode_h2(markdown: String) -> String:
  var regex := RegEx.create_from_string("\n##(.+)\n")
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}\n[font_size=24]{1}[/font_size]\n".format([markdown.substr(plain_start, RE_match.get_start() - plain_start), RE_match.strings[1]])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode_h3(markdown: String) -> String:
  var regex := RegEx.create_from_string("\n###(.+)\n")
  var plain_start := 0
  var bbcode := ""
  for RE_match in regex.search_all(markdown):
    bbcode += "{0}\n[font_size=20]{1}[/font_size]\n".format([markdown.substr(plain_start, RE_match.get_start() - plain_start), RE_match.strings[1]])
    plain_start = RE_match.get_end()
  return bbcode + markdown.substr(plain_start)

static func _markdown_to_bbcode(markdown: String) -> String:
  for converter in [
    _markdown_to_bbcode_url, _markdown_to_bbcode_hr, _markdown_to_bbcode_ul,
    _markdown_to_bbcode_h1, _markdown_to_bbcode_h2, _markdown_to_bbcode_h3
    ]:
      markdown = converter.call(markdown)
  for conversion_pair in [
      ["\\*\\*(.+)\\*\\*", "b", ""],
      ["\\*(.+)\\*", "i", ""],
      ["`(.+)`", "code", ""],
    ]:
      markdown = _markdown_to_bbcode_tag(markdown, conversion_pair[0], conversion_pair[1], conversion_pair[2])
  return markdown

func _add_github_version(version: String, modified: String, url: String, body: String, assets: Array, prerelease: bool):
  var get_url := func(a): return a["browser_download_url"]
  var downloads := {
      "Windows 64-bit": assets.filter(func(a): return a["name"].find("win64") != -1 and a["name"].find("mono") == -1).map(get_url).front(),
      "Windows 32-bit": assets.filter(func(a): return a["name"].find("win32") != -1 and a["name"].find("mono") == -1).map(get_url).front(),
      "macOS": assets.filter(func(a): return a["name"].find("macos") != -1 and a["name"].find("mono") == -1).map(get_url).front(),
      "Linux x86_64": assets.filter(func(a): return a["name"].find("linux.x86_64") != -1 and a["name"].find("mono") == -1).map(get_url).front(),
      "Linux x86_32": assets.filter(func(a): return a["name"].find("linux.x86_32") != -1 and a["name"].find("mono") == -1).map(get_url).front(),
      "Web": assets.filter(func(a): return a["name"].find("web") != -1).map(get_url).front(),
      "Windows 64-bit (Mono)": assets.filter(func(a): return a["name"].find("win64") != -1 and a["name"].find("mono") != -1).map(get_url).front(),
      "Windows 32-bit (Mono)": assets.filter(func(a): return a["name"].find("win32") != -1 and a["name"].find("mono") != -1).map(get_url).front(),
      "macOS (Mono)": assets.filter(func(a): return a["name"].find("macos") != -1 and a["name"].find("mono") != -1).map(get_url).front(),
      "Linux x86_64 (Mono)": assets.filter(func(a): return a["name"].find("linux.x86_64") != -1 and a["name"].find("mono") != -1).map(get_url).front(),
      "Linux x86_32 (Mono)": assets.filter(func(a): return a["name"].find("linux.x86_32") != -1 and a["name"].find("mono") != -1).map(get_url).front(),
    }
  for platform in downloads.keys():
    if downloads[platform] == null:
      downloads.erase(platform)
  if downloads.is_empty():
    return
  var key := "Godot " + version.replace("-", " ")
  versions[key] = {
    "version": version,
    "modified": modified,
    "modified_dict": Time.get_datetime_dict_from_datetime_string(modified, false),
    "url": url,
    "readme": _markdown_to_bbcode(body),
    "downloads": downloads,
    "prerelease": prerelease
  }
  logs.add("Added remote build data for " + key)
  save_build_data(key)
  sort_versions()
  versions_updated.emit()

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
