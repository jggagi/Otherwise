extends SceneTree
## Milestone 3 验收截图工具（供远程 / mobile 验收用）。
## 用法（非 headless，需要真实渲染）：
##   godot --path . --script res://scripts/capture_m3.gd
## 自动走完整垂直切片链路（含两次重构）：
## 初始房间 -> 手机选「下楼」-> ELSE 第一次重构 -> 选「回复」（信节拍）->
## 返回看惊悚的信 -> ELSE 第二次重构 -> 选「回复」（书架异常台词）->
## 返回，书架下层真的出现发圈 -> 朝向/遮挡展示帧。
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
				_key(KEY_2)                        # 分支：回复（信节拍台词）
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
				_key(KEY_1)                        # 第二次 RECONSTRUCT
			262:
				_shot("12_reconstruct_two_blackout")
			312:
				_shot("13_reopened_choice_two")    # 第二次重构后选项重开
			326:
				_key(KEY_2)                        # 分支：回复（书架异常台词）
			334:
				_shot("14_shelf_hint_branch")      # 林夏：书柜最下层有我的东西
			342:
				_key(KEY_SPACE)                    # 返回：发圈出现在真实书架
			348:
				player.global_position = Vector2(478, 330)   # 书架右前方（最近交互=书架）
			356:
				_shot("15_bookshelf_hair_tie")     # 现实书架下层的发圈
			360:
				_key(KEY_E)                        # 打开书架下层文本
			366:
				_shot("16_shelf_anomaly_text")
			369:
				apartment.message_time = 0.0
				apartment.message_label.visible = false   # 提前收起文本（默认 3.5s 计时）
			370:
				player.global_position = Vector2(620, 570)
				player.set_physics_process(false)             # 冻结物理，精确控制帧
			376:
				_show_player_frame(player, "front", false, 0)   # 正面·走路A
			382:
				_shot("17_player_front")
			388:
				_show_player_frame(player, "back", false, 0)    # 背面·待机（走路帧待补）
			394:
				_shot("18_player_back")
			400:
				_show_player_frame(player, "side", false, 0)    # 左侧·走路A
			406:
				_shot("19_player_side_left")
			412:
				_show_player_frame(player, "side", true, 0)     # 右侧·镜像
			418:
				_shot("20_player_side_right")
			424:
				player.global_position = Vector2(720, 460)   # 沙发北侧（沙发与衣柜之间）
			432:
				_shot("21_occlusion_behind_sofa")   # 角色身体被沙发遮挡
			438:
				player.global_position = Vector2(620, 570)
				_show_player_frame(player, "front", false, 1)   # 正面·走路B（与帧17对照）
			446:
				_shot("22_player_front_walk_b")
			452:
				get_tree().quit()

	# 强制玩家展示指定朝向/帧（物理已冻结）。
	func _show_player_frame(player: CharacterBody2D, facing: String, flip: bool, frame_i: int) -> void:
		player._facing = facing
		player._flip = flip
		player._frame_i = frame_i
		player._moving_anim = true
		player._show_frame()

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
