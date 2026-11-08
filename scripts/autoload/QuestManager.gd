extends Node
## Progressive, dynamic quests. A short hand-authored tutorial chain flows into
## an endless supply of generated goals that scale with the size of the city.

signal tasks_changed()
signal progress_changed()
signal task_completed(task: Dictionary)

const MAX_ACTIVE := 3

const TUTORIAL := [
	{
		"title": "Welcome to Horizon City",
		"desc": "Place 2 cottages to welcome your first citizens.",
		"type": "build_id", "key": "cottage", "target": 2, "reward": 180,
		"icon": "house",
	},
	{
		"title": "A Breath of Fresh Air",
		"desc": "Build a wind turbine so the lights can shine.",
		"type": "build_id", "key": "wind", "target": 1, "reward": 140,
		"icon": "bolt",
	},
	{
		"title": "Open for Business",
		"desc": "Build a corner shop to create jobs and income.",
		"type": "build_id", "key": "shop", "target": 1, "reward": 180,
		"icon": "shop",
	},
	{
		"title": "A Little Green",
		"desc": "Build a pocket park and let the city breathe.",
		"type": "build_id", "key": "park", "target": 1, "reward": 160,
		"icon": "tree",
	},
	{
		"title": "Growing Pains",
		"desc": "Grow to 20 citizens — build more homes if you run out.",
		"type": "population", "key": "", "target": 20, "reward": 340,
		"icon": "people",
	},
	{
		"title": "Paving the Way",
		"desc": "Lay 6 road tiles to connect the neighbourhood.",
		"type": "roads", "key": "", "target": 6, "reward": 200,
		"icon": "road",
	},
	{
		"title": "A Little Polish",
		"desc": "Upgrade any building once.",
		"type": "upgrades", "key": "", "target": 1, "reward": 260,
		"icon": "upgrade",
	},
]

var active: Array[Dictionary] = []
var completed: int = 0
var tutorial_index: int = 0
var active_city: bool = false

var _rng := RandomNumberGenerator.new()
var _generating: bool = false
var _uid: int = 1
var _TIMER := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	GameState.task_progress.connect(_evaluate)
	GameState.day_passed.connect(_on_day_passed)
	GameState.changed.connect(_recalc_hint)


func begin(load_from_save: bool, saved: Dictionary = {}) -> void:
	active_city = true
	if load_from_save and not saved.is_empty():
		from_dict(saved)
	else:
		active.clear()
		completed = 0
		tutorial_index = 0
		GameState.tutorial_step = 0
		_uid = 1
		_ensure_slots()
	tasks_changed.emit()


func end_city() -> void:
	active_city = false
	active.clear()


func reset() -> void:
	active.clear()
	completed = 0
	tutorial_index = 0
	_uid = 1


func _ensure_slots() -> void:
	if not active_city:
		return
	if tutorial_index < TUTORIAL.size():
		if active.is_empty():
			_add_tutorial(tutorial_index)
		tasks_changed.emit()
		return
	var guard := 0
	while active.size() < MAX_ACTIVE and guard < 24:
		guard += 1
		var t := _make_procedural()
		if t.is_empty():
			continue
		active.append(t)
	tasks_changed.emit()


func _add_tutorial(index: int) -> void:
	var base: Dictionary = TUTORIAL[index].duplicate(true)
	base["uid"] = _uid
	_uid += 1
	base["start"] = 0
	base["hold"] = 0
	base["hold_days"] = 0
	base["tutorial"] = true
	active.append(base)


func _make_procedural() -> Dictionary:
	var level := Cfg.tier_index(GameState.population)
	var options: Array[String] = ["homes", "commerce", "industry", "civic",
		"population", "power", "happiness", "roads", "upgrades", "earned"]
	var picked := String(options[_rng.randi() % options.size()])
	if picked in ["homes", "commerce", "industry", "civic"]:
		return _make_build_cat(picked, level)
	match picked:
		"population":
			return _make_population(level)
		"power":
			return _make_power(level)
		"happiness":
			return _make_happiness(level)
		"roads":
			return _make_roads(level)
		"upgrades":
			return _make_upgrades(level)
		"earned":
			return _make_earned(level)
	return {}


func _task_key(type: String, key: String) -> String:
	return type + ":" + key


func _already_active(type: String, key: String) -> bool:
	for t in active:
		if String(t["type"]) == type and String(t["key"]) == key:
			return true
	return false


func _new_task(type: String, key: String, title: String, desc: String, target: float,
		reward: float, icon: String, start: float = 0.0, hold_days: int = 0) -> Dictionary:
	var t := {
		"uid": _uid,
		"type": type,
		"key": key,
		"title": title,
		"desc": desc,
		"target": target,
		"start": start,
		"reward": reward,
		"icon": icon,
		"hold": 0,
		"hold_days": hold_days,
		"tutorial": false,
	}
	_uid += 1
	return t


func _make_build_cat(cat: String, level: int) -> Dictionary:
	if _already_active("build_cat", cat):
		return {}
	var target := 2 + mini(level, 7)
	var titles := {
		"homes": ["Room to Grow", "A New Neighbourhood", "Welcome Home"],
		"commerce": ["High Street Buzz", "Open for Business", "Market Day"],
		"industry": ["Make It Work", "Industrial Heart", "Productive City"],
		"civic": ["Civic Pride", "Green Lungs", "Care for All"],
	}
	var arr: Array = titles[cat]
	var title := String(arr[_rng.randi() % arr.size()])
	var desc := "Build %d more %s buildings." % [target, Cfg.cat_name(cat).to_lower()]
	var reward := 150.0 + float(level) * 55.0 + float(target) * 22.0
	return _new_task("build_cat", cat, title, desc, float(target), reward,
		String(Cfg.CATEGORIES[_cat_index(cat)]["icon"]),
		float(GameState.total_built_cat.get(cat, 0)))


func _cat_index(cat: String) -> int:
	for i in Cfg.CATEGORIES.size():
		if String(Cfg.CATEGORIES[i]["id"]) == cat:
			return i
	return 0


func _make_population(level: int) -> Dictionary:
	if _already_active("population", ""):
		return {}
	var base := maxf(25.0, GameState.population + 12.0)
	var target := float((int(base / 5.0) + 1) * 5)
	var reward := 200.0 + float(level) * 70.0
	return _new_task("population", "", "A Growing Town",
		"Reach %d citizens." % int(target), target, reward, "people")


func _make_power(level: int) -> Dictionary:
	if _already_active("power", ""):
		return {}
	var target := float(8 + level * 4)
	var reward := 180.0 + float(level) * 60.0
	return _new_task("power", "", "Keep the Lights On",
		"Have %d spare power in the grid." % int(target), target, reward, "bolt")


func _make_happiness(level: int) -> Dictionary:
	if _already_active("happiness", ""):
		return {}
	var target := clampf(72.0 + float(level) * 2.5, 72.0, 92.0)
	var days := 3
	var reward := 240.0 + float(level) * 75.0
	return _new_task("happiness", "", "A Happy City",
		"Keep happiness above %d%% for %d days." % [int(target), days],
		target, reward, "heart", 0.0, days)


func _make_roads(level: int) -> Dictionary:
	if _already_active("roads", ""):
		return {}
	var target := 5 + level * 2
	var reward := 140.0 + float(level) * 45.0
	return _new_task("roads", "", "Paving the Way",
		"Lay %d more road tiles." % target, float(target), reward, "road",
		float(GameState.roads_built))


func _make_upgrades(level: int) -> Dictionary:
	if _already_active("upgrades", ""):
		return {}
	var target := 1 + int(level / 3)
	var reward := 220.0 + float(level) * 60.0
	return _new_task("upgrades", "", "A Little Polish",
		"Upgrade %d building%s." % [target, "" if target == 1 else "s"],
		float(target), reward, "upgrade", float(GameState.upgrades_done))


func _make_earned(level: int) -> Dictionary:
	if _already_active("earned", ""):
		return {}
	var target := GameState.lifetime_earned + 500.0 + float(level) * 260.0
	var reward := 200.0 + float(level) * 70.0
	return _new_task("earned", "", "Save for Tomorrow",
		"Earn %s in total income." % Cfg.format_money(target), target, reward, "coin")


# ------------------------------------------------------------------ progress

func progress_of(task: Dictionary) -> float:
	var type := String(task["type"])
	var key := String(task["key"])
	var start := float(task.get("start", 0.0))
	match type:
		"build_id":
			return float(int(GameState.total_built.get(key, 0)) - int(start))
		"build_cat":
			return float(int(GameState.total_built_cat.get(key, 0)) - int(start))
		"population":
			return GameState.population
		"roads":
			return float(GameState.roads_built) - start
		"upgrades":
			return float(GameState.upgrades_done) - start
		"earned":
			return GameState.lifetime_earned
		"money":
			return GameState.money
		"power":
			return float(GameState.power_make - GameState.power_use)
		"happiness":
			return float(int(task.get("hold", 0)))
	return 0.0


func progress_text(task: Dictionary) -> String:
	var type := String(task["type"])
	var p := progress_of(task)
	var target := float(task["target"])
	match type:
		"population":
			return "%d / %d" % [int(p), int(target)]
		"happiness":
			return "%d / %d days  (%d%%)" % [int(p), int(task["hold_days"]), int(target)]
		"earned", "money":
			return "%s / %s" % [Cfg.format_money(p), Cfg.format_money(target)]
		"power":
			return "%d / %d spare" % [int(maxf(0.0, p)), int(target)]
	return "%d / %d" % [int(minf(p, target)), int(target)]


func progress_ratio(task: Dictionary) -> float:
	var target := maxf(1.0, float(task["target"]))
	return clampf(progress_of(task) / target, 0.0, 1.0)


func _evaluate() -> void:
	if not active_city or _generating:
		return
	for t in active.duplicate():
		var done := false
		if String(t["type"]) == "happiness":
			done = int(t.get("hold", 0)) >= int(t.get("hold_days", 0))
		else:
			done = progress_of(t) >= float(t["target"])
		if done:
			_complete(t)
			return


func _on_day_passed(_day: int) -> void:
	if not active_city:
		return
	for t in active:
		if String(t["type"]) == "happiness":
			if GameState.happiness >= float(t["target"]):
				t["hold"] = mini(int(t.get("hold", 0)) + 1, int(t.get("hold_days", 0)))
			else:
				t["hold"] = 0
	tasks_changed.emit()
	_evaluate()


func _complete(task: Dictionary) -> void:
	if _generating:
		return
	_generating = true
	active.erase(task)
	var reward := float(task.get("reward", 0.0))
	GameState.grant_task_reward(reward, String(task["title"]))
	completed += 1
	GameState.tasks_completed += 1
	if bool(task.get("tutorial", false)):
		tutorial_index += 1
		GameState.tutorial_step = tutorial_index
	task_completed.emit(task)
	tasks_changed.emit()
	GameState.changed.emit()
	await get_tree().create_timer(1.5).timeout
	_generating = false
	_ensure_slots()
	_evaluate()


func _recalc_hint() -> void:
	if active_city and not active.is_empty():
		progress_changed.emit()


# ------------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	return {
		"tutorial_index": tutorial_index,
		"completed": completed,
		"active": active,
		"uid": _uid,
	}


func from_dict(data: Dictionary) -> void:
	active.clear()
	completed = int(data.get("completed", 0))
	tutorial_index = int(data.get("tutorial_index", 0))
	_uid = int(data.get("uid", 1))
	for t in data.get("active", []):
		if typeof(t) == TYPE_DICTIONARY:
			active.append(t)
	GameState.tutorial_step = tutorial_index
	_ensure_slots()
	tasks_changed.emit()