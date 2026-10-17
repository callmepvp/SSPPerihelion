extends Control

const BOLD = "res://assets/font/Lato/Lato-Bold.ttf"
const REG = "res://assets/font/Lato/Lato-Regular.ttf"
const HEADERS = ["#", "Map", "pp", "Weighted", "Accuracy", "Misses", "Speed", "Stars"]
const WIDTHS = [40, 0, 90, 100, 100, 70, 70, 70]

var grid:GridContainer
var total_label:Label
var sub_label:Label

func _font(path:String, size:int) -> DynamicFont:
	var f:DynamicFont = DynamicFont.new()
	f.font_data = load(path)
	f.size = size
	f.use_filter = true
	return f

func _label(text:String, font:DynamicFont, color:Color, align:int = Label.ALIGN_LEFT, min_w:float = 0, expand:bool = false) -> Label:
	var l:Label = Label.new()
	l.text = text
	l.add_font_override("font", font)
	l.add_color_override("font_color", color)
	l.align = align
	l.rect_min_size = Vector2(min_w, 0)
	l.clip_text = true
	if expand: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _ready():
	var margin:MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_constant_override("margin_" + side, 40)

	var box:VBoxContainer = VBoxContainer.new()
	box.add_constant_override("separation", 6)
	margin.add_child(box)

	box.add_child(_label("Performance", _font(BOLD, 34), Color("#ffc1f5")))
	total_label = _label("0 pp", _font(BOLD, 56), Color("#91fffa"))
	box.add_child(total_label)
	sub_label = _label("", _font(REG, 18), Color("#b3b3b3"))
	box.add_child(sub_label)

	var spacer:Control = Control.new()
	spacer.rect_min_size = Vector2(0, 16)
	box.add_child(spacer)

	grid = GridContainer.new()
	grid.columns = HEADERS.size()
	grid.add_constant_override("hseparation", 18)
	grid.add_constant_override("vseparation", 10)
	box.add_child(grid)

	connect("visibility_changed", self, "refresh")
	refresh()

func refresh():
	if grid == null or !is_visible_in_tree(): return
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

	total_label.text = "%s pp" % Globals.comma_sep(int(round(PP.total_pp())))
	var top:Array = PP.get_top_plays(10)
	if top.empty():
		sub_label.text = "No plays yet. Pass a map with default hitbox and hitwindow settings to earn pp."
		return
	sub_label.text = "%d maps with a pp score (top 10 shown)" % PP.plays.size()

	var hf:DynamicFont = _font(REG, 16)
	for i in range(HEADERS.size()):
		var al = Label.ALIGN_LEFT if i < 2 else Label.ALIGN_RIGHT
		grid.add_child(_label(HEADERS[i], hf, Color("#9a9a9a"), al, WIDTHS[i], i == 1))

	var rf:DynamicFont = _font(REG, 20)
	var bf:DynamicFont = _font(BOLD, 20)
	var rank:int = 0
	for p in top:
		var vals:Array = [
			"%d" % (rank + 1),
			str(p.get("name", p.get("id", "?"))),
			"%.1f" % p.pp,
			"%.1f" % (p.pp * pow(0.95, rank)),
			"%.2f%%" % (p.accuracy * 100.0),
			"%d" % int(p.misses),
			"%.2fx" % p.speed,
			"%.2f" % p.get("stars", 0.0)
		]
		for i in range(vals.size()):
			var al = Label.ALIGN_LEFT if i < 2 else Label.ALIGN_RIGHT
			var col = Color("#ffffff")
			var font = rf
			if i == 2:
				col = Color("#91fffa")
				font = bf
			grid.add_child(_label(vals[i], font, col, al, WIDTHS[i], i == 1))
		rank += 1
