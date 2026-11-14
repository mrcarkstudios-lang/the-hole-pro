class_name Fonts
extends RefCounted
## Game fonts (both SIL Open Font License, free for commercial use):
##  - Lilita One  : chunky UI font used everywhere (also set as project default)
##  - Titan One   : extra-bold display font for the title / big headings

static var _ui: Font = null
static var _title: Font = null


static func ui() -> Font:
	if _ui == null:
		_ui = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _ui


static func title() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/TitanOne-Regular.ttf")
	return _title
