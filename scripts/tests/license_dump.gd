extends SceneTree
func _initialize() -> void:
	var file := FileAccess.open("res://docs/GODOT_LICENSES.txt",FileAccess.WRITE)
	file.store_string("Godot Engine 4.7.2 — license notices from the installed official engine\n\n")
	file.store_string(Engine.get_license_text())
	file.store_string("\n\nBundled library copyright information:\n")
	file.store_string(JSON.stringify(Engine.get_copyright_info(),"  "))
	file.store_string("\n\nBundled license texts:\n")
	file.store_string(JSON.stringify(Engine.get_license_info(),"  "))
	file.close()
	print("GODOT_LICENSE_DUMP_PASS")
	quit()
