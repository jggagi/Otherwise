extends SceneTree
## Milestone 2 验收截图工具（供远程 / mobile 验收用）。
## 用法（非 headless，需要真实渲染）：
##   godot --path . --script res://scripts/capture_m2.gd
## 自动走一遍 ELSE 重构流程：门控 -> 手机选择 -> 分支持久化 ->
## ELSE 界面 -> 重构黑屏 -> 重开选项 -> 二次历史 -> 照片/雨丝异常 -> 门回归，
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
				_shot("00_room_overview")          # 重构前：窗户只有一组雨丝
			14:
				player.global_position = Vector2(940, 500)  # 笔记本旁（书桌正前方）
			22:
				_key(KEY_E)                        # 未做选择：笔记本保持普通文案
			28:
				_shot("01_laptop_before_choice")   # 门控验证
			36:
				player.global_position = Vector2(500, 490)  # 手机旁（茶几南侧）
			44:
				_key(KEY_E)                       # 打开手机选项
			52:
				_shot("02_phone_choices")
			58:
				_key(KEY_1)                       # 分支：下楼
			66:
				_shot("03_branch_down")
			72:
				_key(KEY_SPACE)                   # 返回房间
			80:
				player.global_position = Vector2(940, 500)  # 笔记本旁（书桌正前方）
			88:
				_key(KEY_E)                       # 做过选择后：ELSE 界面
			96:
				_shot("04_else_interface")        # 历史：下楼
			102:
				_key(KEY_1)                       # RECONSTRUCT（0.8s 黑屏）
			110:
				_shot("05_reconstruct_blackout")  # 纯黑停顿
			158:
				_shot("06_reopened_choice")       # 瞬移手机旁，三选项重开
			164:
				_key(KEY_2)                       # 分支：回复
			172:
				_shot("07_branch_reply")
			178:
				_key(KEY_SPACE)                   # 返回房间
			186:
				player.global_position = Vector2(940, 500)  # 笔记本旁（书桌正前方）
			194:
				_key(KEY_E)                       # 二次打开 ELSE
			202:
				_shot("08_else_history_two")       # 历史：下楼、回复
			208:
				_key(KEY_2)                       # NOT NOW 关闭
			216:
				player.global_position = Vector2(415, 385)  # 相框下（新热区）
			224:
				_key(KEY_E)                       # 重构后照片异常文案
			232:
				_shot("09_photo_anomaly")
			244:
				_shot("10_rain_anomaly")          # 大窗第二组斜浅雨丝
			248:
				player.global_position = Vector2(275, 350)  # 门热区内、床碰撞安全距离外
			256:
				_key(KEY_E)                       # 门交互（回归检查）
			264:
				_shot("11_door_regression")
			272:
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
