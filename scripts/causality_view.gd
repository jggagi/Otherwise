extends Control
## Six authored nodes, not an editor. Known events are solid; possibilities subdued.
var reality: int = 0
var simulated: int = 0
var completed: bool = false
var anchored: bool = false

func _draw() -> void:
	var width := size.x
	var font := get_theme_default_font()
	var known := Color(0.83,0.82,0.76)
	var unknown := Color(0.39,0.42,0.46)
	var gold := Color(0.91,0.75,0.42)
	var top := Vector2(width*0.5,20)
	draw_string(font,top-Vector2(55,5),"楼下的消息",HORIZONTAL_ALIGNMENT_LEFT,-1,15,known)
	for choice in [1,2,3]:
		var pos := Vector2(width*(0.18+0.32*(choice-1)),65)
		var color := known if choice==reality else (gold if completed and choice==simulated else unknown)
		draw_line(top+Vector2(0,6),pos-Vector2(0,14),color,1)
		draw_string(font,pos-Vector2(33,0),["","下楼","让她上来","不回复"][choice],HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)
		if choice==reality:
			draw_line(pos+Vector2(0,5),Vector2(width*0.5,97),color,1)
	draw_string(font,Vector2(width*0.5-55,115),"最后的回应",HORIZONTAL_ALIGNMENT_LEFT,-1,15,known)
	if anchored:
		draw_string(font,Vector2(width-130,115),"● 记住的理解",HORIZONTAL_ALIGNMENT_LEFT,-1,14,gold)
