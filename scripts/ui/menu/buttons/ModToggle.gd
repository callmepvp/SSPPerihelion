#ModToggle
extends CheckBox

var mod_property:String = ""

func _process(_d):
	if mod_property == "": return
	if pressed != Rhythia.get(mod_property):
		Rhythia.set(mod_property, pressed)

func upd():
	if mod_property == "": return
	pressed = Rhythia.get(mod_property)

func _ready():
	upd()
	Rhythia.connect("mods_changed",self,"upd")
