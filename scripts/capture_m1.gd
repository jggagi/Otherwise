extends SceneTree
## Milestone 1 验收截图工具（供远程 / mobile 验收用）。
## 用法（非 headless，需要真实渲染）：
##   godot --path . --script res://scripts/capture_m1.gd
## 自动走一遍流程：手机三选项 -> 三条分支字幕 -> 门交互回归，
## 截图保存到项目根下 .verify/ 目录。


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.verify"))
	var packed: PackedScene = load("res://scenes/apartment.tscn")
	var apartment: Node2D = packed.instantiate()
	root.add_child(apartment)
	var driver := CaptureDriver.new()
	driver.apartment = apartment
	root.add_child(driver)


class CaptureDriver extends Node:
	var apartment: Node2D
	var frame := 0

	func _process(_delta: float) -> void:
		frame += 1
		var player: CharacterBody2D = apartment.get_node("Room/Player")
		match frame:
			10:
				_shot("00_room_overview")
			14:
				player.global_position = Vector2(430, 545)  # 手机旁
			22:
				_key(KEY_E)                    # 打开手机选项
			30:
				_shot("01_phone_choices")
				_key(KEY_1)                   # 分支：下楼
			40:
				_shot("02_branch_down")
				_key(KEY_SPACE)               # 返回房间
			48:
				_key(KEY_E)                   # 重新打开选项
			56:
				_key(KEY_2)                   # 分支：回复
			66:
				_shot("03_branch_reply")
				_key(KEY_SPACE)
			74:
				_key(KEY_E)
			82:
				_key(KEY_3)                   # 分支：不回复
			92:
				_shot("04_branch_ignore")
				_key(KEY_SPACE)
			100:
				player.global_position = Vector2(290, 390)  # 门口
			108:
				_key(KEY_E)                   # 门交互（回归检查）
			116:
				_shot("05_door_message")
			124:
				get_tree().quit()

	# 直接调用主脚本的输入处理，模拟按键。
	func _key(k: Key) -> void:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.echo = false
		ev.physical_keycode = k
		ev.keycode = k
		apartment._unhandled_input(ev)

	# 抓取当前视口并保存 PNG。
	func _shot(shot_name: String) -> void:
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://.verify/" + shot_name + ".png"))
