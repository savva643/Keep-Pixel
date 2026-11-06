extends SceneTree

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var client = load("res://keep_pixel_client.gd").new()
    root.add_child(client)
    if not client.initialize():
        printerr("No local SDK session")
        quit(1)
        return
    for operation in ["get_session", "get_profile", "get_friends", "check_license", "set_presence"]:
        var response: Dictionary = await client.call(operation)
        if response.get("ok") != true:
            printerr("SDK operation failed: ", operation)
            quit(1)
            return
    print("GODOT_SDK_OK")
    client.queue_free()
    await process_frame
    quit(0)
