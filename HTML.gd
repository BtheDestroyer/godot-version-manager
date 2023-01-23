class_name HTML

enum CharSet {
  INVALID,
  ASCII,
  UTF8,
  UTF16,
  UTF32
}

static func find_charset(headers: PackedStringArray):
  for header in headers:
    if header.begins_with("Content-Type:"):
      header = header.to_lower()
      if header.contains("charset=ascii") or header.contains("charset=us-ascii") or header.begins_with("content-type: text/plain"):
        return CharSet.ASCII
      elif header.contains("charset=utf-8"):
        return CharSet.UTF8
      elif header.contains("charset=utf-16"):
        return CharSet.UTF16
      elif header.contains("charset=utf-32"):
        return CharSet.UTF32
      break
  push_error("HTTP Response's Content-Type is unknown or invalid. Supported types: ascii, us-ascii, utf-8, utf-16, utf-32")
  return CharSet.INVALID

static func get_body_as_string(headers: PackedStringArray, body: PackedByteArray) -> String:
  match find_charset(headers):
    CharSet.ASCII:
      return body.get_string_from_ascii()
    CharSet.UTF8:
      return body.get_string_from_utf8()
    CharSet.UTF16:
      return body.get_string_from_utf16()
    CharSet.UTF32:
      return body.get_string_from_utf32()
    CharSet.INVALID:
      push_warning("HTTP body has unknown or invlalid charset, attempting ascii")
      return body.get_string_from_ascii()
  return ""

static func walk_html_for_tag_path(html: String, tags: Array) -> String:
  var tag = tags.pop_front()
  var child: String
  if tag is String:
    child = get_child_tag(html, tag)
  elif tag is Array:
    child = get_child_tag(html, tag[0], tag[1])
  else:
    return ""
  if tags.size() == 0:
    return child
  return walk_html_for_tag_path(child, tags)

static func get_child_tag(html: String, tag: String, attributes: PackedStringArray = PackedStringArray()) -> String:
  var start_regex := RegEx.new()
  var start_pattern := "<%s" % [tag]
  for attribute in attributes:
    start_pattern += "( +[^ >]*)*%s" % [attribute]
  start_pattern += "( +[^ >]*)*>"
  start_regex.compile(start_pattern)
  var start_match := start_regex.search(html)
  if start_match.get_start() == -1:
    return ""
  var end_regex := RegEx.new()
  end_regex.compile("<\\/%s( +[^ >]*)*>" % [tag])
  var end_match := end_regex.search(html, start_match.get_end())
  if end_match.get_start() == -1:
    return ""
  var length := end_match.get_start() - start_match.get_end()
  return html.substr(start_match.get_end(), length)

