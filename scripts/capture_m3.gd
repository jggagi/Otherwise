extends SceneTree
## Milestone 3 验收截图工具（供远程 / mobile 验收用）。
## 用法（非 headless，需要真实渲染）：
##   godot --path . --script res://scripts/capture_m3.gd
## 自动走一遍完整垂直切片链路：
## 初始房间（信平淡、无道具）-> 手机选「下楼」-> 返回看门口伞痕迹 ->
## 笔记本 ELSE（无 Anchor）-> 重构 -> 选「回复」看林夏「信」台词 ->
## 返回（回复道具 + Anchor 获得）-> 交互「信」看惊悚确认 ->
## 再开 ELSE 看金色 Anchor。
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
				_shot("00_initial_room")             # 无道具；书桌角有信封占位
			16:
				player.global_position = Vector2(885, 475)   # 信旁（书桌左前角南侧）
			24:
				_key(KEY_E)                        # 信：平淡文本
			32:
				_shot("01_letter_plain")
			40:
				player.global_position = Vector2(500, 490)   # 手机旁（茶几南侧）
			48:
				_key(KEY_E)                        # 打开手机选项
			56:
				_shot("02_phone_choices")
			62:
				_key(KEY_1)                        # 分支：下楼
			70:
				_shot("03_branch_down")
			76:
				_key(KEY_SPACE)                    # 返回房间（下楼伞出现）
			84:
				_shot("04_down_umbrella")          # 门口靠墙收拢伞
			92:
				player.global_position = Vector2(940, 500)   # 笔记本旁（书桌正前方）
			100:
				_key(KEY_E)                        # ELSE（历史：下楼，无 Anchor）
			108:
				_shot("05_else_no_anchor")
			114:
				_key(KEY_1)                        # RECONSTRUCT（0.8s 黑屏）
			122:
				_shot("06_reconstruct_blackout")
			170:
				_shot("07_reopened_choice")        # 伞被清空，选项重开
			176:
				_key(KEY_2)                        # 分支：回复（含信台词）
			184:
				_shot("08_branch_reply_letter")    # 林夏指出桌上的信
			190:
				_key(KEY_SPACE)                    # 返回：Anchor 获得 + 回复道具
			198:
				_shot("09_reply_props")            # 鞋 + 第二杯 + 湿伞
			206:
				player.global_position = Vector2(885, 475)   # 信旁
			214:
				_key(KEY_E)                        # 信：惊悚确认
			222:
				_shot("10_letter_horror")
			230:
				player.global_position = Vector2(940, 500)   # 笔记本旁
			238:
				_key(KEY_E)                        # ELSE：金色 Anchor
			246:
				_shot("11_else_gold_anchor")
			254:
				_key(KEY_2)                        # NOT NOW 关闭
			258:
				player.global_position = Vector2(620, 570)   # 空地展示朝向
			262:
				player._update_facing(Vector2(0, 1))   # 正面（朝镜头）
			266:
				_shot("12_player_front")
			270:
				player._update_facing(Vector2(0, -1))  # 背面
			274:
				_shot("13_player_back")
			278:
				player._update_facing(Vector2(-1, 0))  # 左侧
			282:
				_shot("14_player_side_left")
			286:
				player._update_facing(Vector2(1, 0))   # 右侧（镜像）
			290:
				_shot("15_player_side_right")
			298:
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
