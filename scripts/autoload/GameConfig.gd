extends Node
## Global configuration, palette and small helpers shared by every system.

const GRID_SIZE := 16
const TILE := 2.0
const BUILD_SIZE := GRID_SIZE * TILE
const HALF_BUILD := BUILD_SIZE * 0.5
const ISLAND_SIZE := 40.0
const ISLAND_HALF := ISLAND_SIZE * 0.5
const WATER_Y := -0.34

const DAY_SECONDS := 8.0
const FULL_DAY_SECONDS := 300.0
const START_MONEY := 1400.0
const SAVE_VERSION := 3

const COL_BG := Color("0b1220")
const COL_BG_2 := Color("0e1929")
const COL_PANEL := Color("131f33")
const COL_PANEL_2 := Color("1b2b46")
const COL_PANEL_3 := Color("24395c")
const COL_TEXT := Color("eef4ff")
const COL_MUTED := Color("93a7c8")
const COL_DIM := Color("63779a")
const COL_ACCENT := Color("46dfc3")
const COL_ACCENT_DARK := Color("1b8c79")
const COL_GOLD := Color("ffc857")
const COL_CORAL := Color("ff7d6b")
const COL_BLUE := Color("6fa8ff")
const COL_GREEN := Color("6ede90")
const COL_PURPLE := Color("b28dff")

const CATEGORIES := [
	{"id": "homes", "name": "Homes", "color": Color("6fa8ff"), "icon": "house"},
	{"id": "commerce", "name": "Shops", "color": Color("ffc857"), "icon": "shop"},
	{"id": "industry", "name": "Industry", "color": Color("ff9f6b"), "icon": "factory"},
	{"id": "civic", "name": "Civic", "color": Color("46dfc3"), "icon": "civic"},
]

const TIERS := [
	{"name": "Outpost", "pop": 0},
	{"name": "Hamlet", "pop": 25},
	{"name": "Village", "pop": 70},
	{"name": "Town", "pop": 150},
	{"name": "City", "pop": 300},
	{"name": "Metropolis", "pop": 520},
	{"name": "Megacity", "pop": 800},
	{"name": "Horizon", "pop": 1200},
]

var font_display: Font
var font_body: Font
var font_bold: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_fonts()


func _load_fonts() -> void:
	font_display = _try_font("res://assets/fonts/Quicksand-Bold.ttf")
	font_body = _try_font("res://assets/fonts/Nunito-Regular.ttf")
	font_bold = _try_font("res://assets/fonts/Nunito-SemiBold.ttf")


func _try_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	return ThemeDB.fallback_font


func cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(
		(float(cell.x) - float(GRID_SIZE) * 0.5 + 0.5) * TILE,
		y,
		(float(cell.y) - float(GRID_SIZE) * 0.5 + 0.5) * TILE
	)


func world_to_cell(pos: Vector3) -> Vector2i:
	var fx := pos.x / TILE + float(GRID_SIZE) * 0.5 - 0.5
	var fz := pos.z / TILE + float(GRID_SIZE) * 0.5 - 0.5
	return Vector2i(int(floor(fx)), int(floor(fz)))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE and cell.y < GRID_SIZE


func tier_index(population: float) -> int:
	var idx := 0
	for i in TIERS.size():
		if population >= float(TIERS[i]["pop"]):
			idx = i
	return idx


func tier_name(population: float) -> String:
	return String(TIERS[tier_index(population)]["name"])


func next_tier(population: float) -> Dictionary:
	var idx := tier_index(population)
	if idx + 1 < TIERS.size():
		return TIERS[idx + 1]
	return {}


func format_money(value: float) -> String:
	var negative := value < 0.0
	var v := int(absf(round(value)))
	var s := str(v)
	if s.length() > 3:
		var out := ""
		var count := 0
		for i in range(s.length() - 1, -1, -1):
			out = s[i] + out
			count += 1
			if count % 3 == 0 and i > 0:
				out = "," + out
		s = out
	return ("-$" if negative else "$") + s


func format_short(value: float) -> String:
	var v := absf(value)
	if v >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if v >= 10000.0:
		return "%.1fK" % (value / 1000.0)
	return str(int(round(value)))


func format_time(time_of_day: float) -> String:
	var hours := fmod(time_of_day * 24.0 + 6.0, 24.0)
	var h := int(hours)
	var m := int((hours - float(h)) * 60.0)
	return "%02d:%02d" % [h, m]


func cat_color(cat_id: String) -> Color:
	for cat in CATEGORIES:
		if String(cat["id"]) == cat_id:
			return cat["color"]
	return COL_ACCENT


func cat_name(cat_id: String) -> String:
	for cat in CATEGORIES:
		if String(cat["id"]) == cat_id:
			return cat["name"]
	return cat_id.capitalize()