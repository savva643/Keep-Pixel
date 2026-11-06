# Godot 4.x. Add this node to a scene; all request methods are awaited.
class_name KeepPixelClient
extends Node

var _url: String
var _capability: String
var game_id: int

func initialize() -> bool:
    _url = OS.get_environment("KEEPPIXEL_SDK_URL")
    _capability = OS.get_environment("KEEPPIXEL_SDK_TOKEN")
    var pattern := RegEx.new()
    pattern.compile("^http://127\\.0\\.0\\.1:([0-9]{1,5})/v1$")
    var match_result := pattern.search(_url)
    var token_pattern := RegEx.new()
    token_pattern.compile("^[A-Za-z0-9_-]{43}$")
    game_id = OS.get_environment("KEEPPIXEL_GAME_ID").to_int()
    return match_result != null and match_result.get_string(1).to_int() > 0 \
        and match_result.get_string(1).to_int() <= 65535 \
        and token_pattern.search(_capability) != null and game_id > 0

func _request(path: String, body: Variant = null) -> Dictionary:
    if not initialize():
        return {"ok": false, "error": {"code": "not_initialized", "message": "Start from Keep Pixel"}}
    var http := HTTPRequest.new()
    http.timeout = 8.0
    http.max_redirects = 0
    http.body_size_limit = 1048576
    add_child(http)
    var headers := PackedStringArray(["Authorization: Bearer " + _capability, "Accept: application/json"])
    var method := HTTPClient.METHOD_GET
    if body != null:
        method = HTTPClient.METHOD_POST
        headers.append("Content-Type: application/json")
    var err := http.request(_url + path, headers, method, "" if body == null else JSON.stringify(body))
    if err != OK:
        http.queue_free()
        return {"ok": false, "error": {"code": "launcher_unavailable", "message": "Request could not start"}}
    var response: Array = await http.request_completed
    http.queue_free()
    var decoded: Variant = JSON.parse_string(response[3].get_string_from_utf8())
    if response[0] != HTTPRequest.RESULT_SUCCESS or not decoded is Dictionary:
        return {"ok": false, "error": {"code": "launcher_unavailable", "message": "Keep Pixel unavailable"}}
    if response[1] != 200 or decoded.get("ok") != true:
        return {"ok": false, "error": decoded.get("error", {"code": "request_failed", "message": "SDK request failed"})}
    return decoded

func get_session() -> Dictionary: return await _request("/session")
func get_profile() -> Dictionary: return await _request("/profile")
func get_friends() -> Dictionary: return await _request("/friends")
func check_license() -> Dictionary: return await _request("/license")
func set_presence(away: bool = false) -> Dictionary:
    return await _request("/presence", {"status": "away" if away else "in_game"})
func show_overlay(visible: bool = true) -> Dictionary:
    return await _request("/overlay", {"visible": visible})
