extends CanvasLayer
signal selected(id: String)
signal continued
signal setting_changed(id: String,value: float)
var root_control: Control
var theme: Theme
var dialog: PanelContainer
var speaker: Label
var body: Label
var next_button: Button
var modal: PanelContainer
var content: VBoxContainer
var option_ids: Array[String] = []
var hint: Label
var prompt: Label
var mode_label: Label
var font_scale: float = 1.0
var _fonts: Dictionary = {}
var graph_data: Dictionary = {}
var illustration: TextureRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	theme = Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansSC.ttf")
	theme.default_font_size = 19
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.065,0.071,0.08,0.96)
	panel_style.border_color = Color(0.58,0.53,0.42,0.4)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 26
	panel_style.content_margin_right = 26
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	theme.set_stylebox("panel","PanelContainer",panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0.14,0.15,0.16,0.98)
	button_style.set_corner_radius_all(5)
	button_style.content_margin_top = 8
	button_style.content_margin_bottom = 8
	button_style.content_margin_left = 14
	button_style.content_margin_right = 14
	theme.set_stylebox("normal","Button",button_style)
	var hover: StyleBoxFlat = button_style.duplicate()
	hover.bg_color = Color(0.24,0.22,0.18)
	theme.set_stylebox("hover","Button",hover)
	theme.set_stylebox("focus","Button",hover)
	theme.set_stylebox("pressed","Button",hover)
	root_control.theme = theme
	hint = _label("WASD／方向键移动 · 点击地面行走 · E 交互 · ESC 设置",14)
	hint.position = Vector2(22,617)
	hint.modulate = Color(1,1,1,0.75)
	root_control.add_child(hint)
	mode_label = _label("",14)
	mode_label.position = Vector2(22,18)
	root_control.add_child(mode_label)
	prompt = _label("",18)
	root_control.add_child(prompt)
	prompt.visible = false
	dialog = PanelContainer.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.anchor_left = 0.06
	dialog.anchor_right = 0.94
	dialog.anchor_top = 0.70
	dialog.anchor_bottom = 0.97
	root_control.add_child(dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	dialog.add_child(box)
	speaker = _label("",16)
	speaker.modulate = Color(0.88,0.75,0.5)
	box.add_child(speaker)
	body = _label("",21)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var text_row := HBoxContainer.new()
	text_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_row)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_row.add_child(body)
	illustration = TextureRect.new()
	illustration.custom_minimum_size = Vector2(150,92)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	text_row.add_child(illustration)
	illustration.visible = false
	next_button = _button("继续  ·  E／空格",func(): continued.emit())
	box.add_child(next_button)
	modal = PanelContainer.new()
	modal.anchor_left = 0.16
	modal.anchor_right = 0.84
	modal.anchor_top = 0.06
	modal.anchor_bottom = 0.94
	root_control.add_child(modal)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	close()

func _label(text: String,size: int) -> Label:
	var label := Label.new()
	label.text = text
	_fonts[label] = size
	label.add_theme_font_size_override("font_size",roundi(size*font_scale))
	return label

func _button(text: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	_fonts[button] = 18
	button.add_theme_font_size_override("font_size",roundi(18*font_scale))
	return button

func close() -> void:
	dialog.visible = false
	modal.visible = false
	option_ids.clear()
	prompt.visible = false

func show_line(data: Dictionary,index: int,total: int) -> void:
	close()
	dialog.visible = true
	speaker.text = data.who if data.who!="" else ""
	speaker.visible = data.who!=""
	body.text = data.text
	illustration.visible = data.get("event","")=="tie_verified" and ResourceLoader.exists("res://assets/art_sources/hair_tie_detail_v1.png")
	if illustration.visible:
		illustration.texture = load("res://assets/art_sources/hair_tie_detail_v1.png")
	next_button.text = "继续  ·  E／空格     %d / %d"%[index+1,total]
	next_button.grab_focus()

func show_options(title: String,text: String,options: Array,settings: bool = false) -> void:
	close()
	for child in content.get_children():
		_fonts.erase(child)
		content.remove_child(child)
		child.queue_free()
	var heading := _label(title,30)
	heading.modulate = Color(0.94,0.84,0.65)
	content.add_child(heading)
	var description := _label(text,17)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	if title=="ELSE":
		var graph := Control.new()
		graph.set_script(load("res://scripts/causality_view.gd"))
		graph.custom_minimum_size.y = 126
		graph.reality = graph_data.get("reality",0)
		graph.simulated = graph_data.get("simulated",0)
		graph.completed = graph_data.get("completed",false)
		graph.anchored = graph_data.get("anchored",false)
		content.add_child(graph)
	for item in options:
		var id: String = item[0]
		option_ids.append(id)
		var button := _button("%d  ·  %s"%[option_ids.size(),item[1]],func(): selected.emit(id))
		content.add_child(button)
	if settings:
		content.add_child(_label("总音量",16))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
		slider.value_changed.connect(func(value: float): setting_changed.emit("volume",value))
		content.add_child(slider)
		content.add_child(_label("文字大小",16))
		var font_slider := HSlider.new()
		font_slider.min_value = 1
		font_slider.max_value = 1.35
		font_slider.step = 0.05
		font_slider.value = font_scale
		font_slider.value_changed.connect(func(value: float): set_font_scale(value); setting_changed.emit("font",value))
		content.add_child(font_slider)
	modal.visible = true
	if options.size()>0:
		for child in content.get_children():
			if child is Button:
				child.grab_focus()
				break

func set_font_scale(value: float) -> void:
	font_scale = value
	for control in _fonts.keys():
		if is_instance_valid(control):
			control.add_theme_font_size_override("font_size",roundi(_fonts[control]*value))
		else:
			_fonts.erase(control)

func update_prompt(entry: Dictionary) -> void:
	prompt.visible = not entry.is_empty() and not dialog.visible and not modal.visible
	if prompt.visible:
		prompt.text = "E · "+entry.title
		prompt.position = entry.pos+Vector2(18,-12)
