extends Node
## The living simulation: city data, economy, population, happiness and power.

signal changed()
signal toast(text: String, icon: String, tone: String)
signal day_passed(day: int)
signal tier_changed(index: int)
signal placed(id: String, cell: Vector2i, level: int)
signal removed(cell: Vector2i)
signal road_changed(cell: Vector2i, present: bool)
signal task_progress()

var money: float = Cfg.START_MONEY
var population: float = 0.0
var happiness: float = 62.0
var day: int = 1
var time_of_day: float = 0.20
var speed: float = 1.0
var simulate: bool = false

# Aggregates (recomputed whenever the city changes).
var housing_capacity: int = 0
var jobs: int = 0
var power_use: int = 0
var power_make: int = 0
var pollution: float = 0.0
var service_happiness: float = 0.0
var upkeep: float = 0.0
var tax_income: float = 0.0

# Cumulative statistics used by dynamic quests.
var total_built: Dictionary = {}
var total_built_cat: Dictionary = {}
var roads_built: int = 0
var upgrades_done: int = 0
var tasks_completed: int = 0
var lifetime_earned: float = 0.0
var tutorial_step: int = 0
var trees: int = 0

# City contents. Keys are Vector2i cell coordinates.
var buildings: Dictionary = {}
var roads: Dictionary = {}

var _day_timer: float = 0.0
var _tier: int = 0
var _last_unlocked: Dictionary = {}
var _suppress_unlock_toast: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_tier = Cfg.tier_index(population)


func _process(delta: float) -> void:
	if speed <= 0.0:
		return
	var d := delta * speed
	time_of_day = fmod(time_of_day + d / Cfg.FULL_DAY_SECONDS, 1.0)
	if not simulate:
		return
	_day_timer += d
	while _day_timer >= Cfg.DAY_SECONDS:
		_day_timer -= Cfg.DAY_SECONDS
		_tick_day()


func night_factor() -> float:
	# 1.0 at midnight, 0.0 in daylight.
	var sun_up := sin(time_of_day * TAU)
	return clampf(-sun_up * 1.35 + 0.18, 0.0, 1.0)


func sun_direction() -> Vector3:
	var a := time_of_day * TAU
	return Vector3(cos(a), sin(a), 0.42).normalized()


func new_game() -> void:
	money = Cfg.START_MONEY
	population = 0.0
	happiness = 62.0
	day = 1
	time_of_day = 0.20
	speed = 1.0
	buildings.clear()
	roads.clear()
	total_built.clear()
	total_built_cat.clear()
	roads_built = 0
	upgrades_done = 0
	tasks_completed = 0
	lifetime_earned = 0.0
	tutorial_step = 0
	trees = 0
	_day_timer = 0.0
	_tier = 0
	_last_unlocked.clear()
	_recompute()
	changed.emit()


# ------------------------------------------------------------------ placement

func cell_free(cell: Vector2i) -> bool:
	return not buildings.has(cell) and not roads.has(cell)


func building_at(cell: Vector2i) -> Dictionary:
	return buildings.get(cell, {})


func has_road(cell: Vector2i) -> bool:
	return roads.has(cell)


func can_place(id: String, cell: Vector2i) -> String:
	if not Cfg.is_inside(cell):
		return "Outside the island"
	if not cell_free(cell):
		return "That plot is taken"
	var d: Dictionary = BuildingDB.get_def(id)
	if d.is_empty():
		return "Unknown building"
	if population < float(d.get("unlock", 0)):
		return "Unlocks at %d citizens" % int(d["unlock"])
	if money < float(d["cost"]):
		return "Not enough money"
	return ""


func try_place(id: String, cell: Vector2i, variant: int = -1) -> String:
	var err := can_place(id, cell)
	if err != "":
		return err
	var d: Dictionary = BuildingDB.get_def(id)
	var cost: float = float(d["cost"])
	money -= cost
	if variant < 0:
		variant = _rng.randi_range(0, 999)
	var b := {
		"id": id,
		"level": 1,
		"variant": variant,
		"cell": cell,
	}
	buildings[cell] = b
	total_built[id] = int(total_built.get(id, 0)) + 1
	var cat := String(d["cat"])
	total_built_cat[cat] = int(total_built_cat.get(cat, 0)) + 1
	_recompute()
	placed.emit(id, cell, 1)
	changed.emit()
	task_progress.emit()
	return ""


func try_road(cell: Vector2i) -> String:
	if not Cfg.is_inside(cell):
		return "Outside the island"
	if not cell_free(cell):
		return "That plot is taken"
	var d: Dictionary = BuildingDB.get_def("road")
	var cost: float = float(d["cost"])
	if money < cost:
		return "Not enough money"
	money -= cost
	roads[cell] = true
	roads_built += 1
	_recompute()
	road_changed.emit(cell, true)
	changed.emit()
	task_progress.emit()
	return ""


func upgrade_cost(cell: Vector2i) -> float:
	var b := building_at(cell)
	if b.is_empty():
		return 0.0
	var d: Dictionary = BuildingDB.get_def(String(b["id"]))
	var level: int = int(b["level"])
	if level >= 3:
		return 0.0
	return round(float(d["cost"]) * (0.85 if level == 1 else 1.45))


func try_upgrade(cell: Vector2i) -> String:
	var b := building_at(cell)
	if b.is_empty():
		return "Nothing to upgrade"
	var level: int = int(b["level"])
	if level >= 3:
		return "Already max level"
	var cost := upgrade_cost(cell)
	if money < cost:
		return "Not enough money"
	money -= cost
	b["level"] = level + 1
	buildings[cell] = b
	upgrades_done += 1
	_recompute()
	changed.emit()
	task_progress.emit()
	return ""


func sell_value(cell: Vector2i) -> float:
	if buildings.has(cell):
		var b: Dictionary = buildings[cell]
		var d: Dictionary = BuildingDB.get_def(String(b["id"]))
		var level: int = int(b["level"])
		return round(float(d["cost"]) * 0.5 * (1.0 + 0.55 * float(level - 1)))
	if roads.has(cell):
		return 2.0
	return 0.0


func demolish(cell: Vector2i) -> String:
	if buildings.has(cell):
		var refund := sell_value(cell)
		money += refund
		buildings.erase(cell)
		_recompute()
		removed.emit(cell)
		changed.emit()
		task_progress.emit()
		return ""
	if roads.has(cell):
		money += sell_value(cell)
		roads.erase(cell)
		_recompute()
		road_changed.emit(cell, false)
		changed.emit()
		task_progress.emit()
		return ""
	return "Nothing here"


func add_money(amount: float, reason: String = "") -> void:
	money += amount
	if amount > 0.0:
		lifetime_earned += amount
	changed.emit()
	if reason != "":
		toast.emit(reason, "coin", "good")


func grant_task_reward(reward_money: float, reward_text: String = "") -> void:
	money += reward_money
	lifetime_earned += maxf(0.0, reward_money)
	tasks_completed += 1
	changed.emit()


# ------------------------------------------------------------------ simulation

func _tick_day() -> void:
	day += 1
	_recompute_power_only()

	var workforce := population * 0.55
	var unemployment := 0.0
	if workforce > 0.5:
		unemployment = clampf((workforce - float(jobs)) / workforce, 0.0, 1.0)
	var shortage := 0.0
	if power_use > 0:
		shortage = clampf(float(power_use - power_make) / float(power_use), 0.0, 1.0)
	var power_ok := 1.0 - shortage * 0.85

	var happ_factor := clampf(happiness / 100.0, 0.15, 1.0)
	var jobs_factor := clampf(1.0 - unemployment * 0.8, 0.2, 1.0)

	if population < float(housing_capacity):
		var growth: float = maxf(0.6, float(housing_capacity) * 0.10)
		growth *= happ_factor * jobs_factor * power_ok
		population = minf(float(housing_capacity), population + growth)
	elif population > float(housing_capacity):
		var leave: float = maxf(0.6, population * 0.08)
		population = maxf(float(housing_capacity), population - leave)

	var pop_tax := population * 0.55 * (0.6 + 0.4 * happ_factor)
	var income := (tax_income + pop_tax) * power_ok
	money += income - upkeep
	if income > 0.0:
		lifetime_earned += income
	if money < -2000.0:
		money = -2000.0

	_update_happiness(shortage, unemployment, power_ok)
	_check_tier()

	day_passed.emit(day)
	changed.emit()
	task_progress.emit()
	if money < 0.0:
		toast.emit("The city is in debt — sell something soon.", "coin", "bad")


func _recompute_power_only() -> void:
	power_use = 0
	power_make = 0
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		var d: Dictionary = BuildingDB.get_def(String(b["id"]))
		if d.is_empty():
			continue
		var level: int = int(b["level"])
		var lm := 1.0 + 0.65 * float(level - 1)
		power_use += int(round(float(d.get("power_use", 0)) * (1.0 + 0.45 * float(level - 1))))
		power_make += int(round(float(d.get("power_make", 0)) * lm))


func _update_happiness(shortage: float, unemployment: float, power_ok: float) -> void:
	var target := 56.0
	target += service_happiness * 0.95
	target -= pollution * 0.42
	target -= unemployment * 30.0
	target -= shortage * 34.0
	target += minf(9.0, float(trees) * 0.18)
	if housing_capacity == 0:
		target = 62.0
	if power_ok > 0.98:
		target += 4.0
	target = clampf(target, 12.0, 100.0)
	happiness = lerpf(happiness, target, 0.38)


func _check_tier() -> void:
	var idx := Cfg.tier_index(population)
	if idx != _tier:
		_tier = idx
		tier_changed.emit(idx)
		toast.emit("Welcome to a %s!" % String(Cfg.TIERS[idx]["name"]), "star", "level")
	_notify_unlocks()


func _notify_unlocks() -> void:
	var unlocked_now := {}
	for id in BuildingDB.order:
		var d: Dictionary = BuildingDB.buildings[id]
		if population >= float(d["unlock"]):
			unlocked_now[id] = true
	if _suppress_unlock_toast:
		_last_unlocked = unlocked_now
		return
	for id in unlocked_now:
		if not _last_unlocked.has(id):
			var d: Dictionary = BuildingDB.buildings[id]
			if float(d["unlock"]) > 0.0:
				toast.emit("New building unlocked: %s" % String(d["name"]), "lock", "unlock")
	_last_unlocked = unlocked_now


# ------------------------------------------------------------------ aggregate

func _recompute() -> void:
	housing_capacity = 0
	jobs = 0
	power_use = 0
	power_make = 0
	pollution = 0.0
	service_happiness = 0.0
	upkeep = 0.0
	tax_income = 0.0
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		var d: Dictionary = BuildingDB.get_def(String(b["id"]))
		if d.is_empty():
			continue
		var level: int = int(b["level"])
		var lm := 1.0 + 0.65 * float(level - 1)
		housing_capacity += int(round(float(d.get("housing", 0)) * lm))
		jobs += int(round(float(d.get("jobs", 0)) * lm))
		power_use += int(round(float(d.get("power_use", 0)) * (1.0 + 0.45 * float(level - 1))))
		power_make += int(round(float(d.get("power_make", 0)) * lm))
		pollution += float(d.get("pollution", 0)) * (1.0 + 0.25 * float(level - 1))
		service_happiness += float(d.get("happiness", 0))
		tax_income += float(d.get("tax", 0)) * lm
		upkeep += float(d.get("upkeep", 0)) * (1.0 + 0.3 * float(level - 1))
	upkeep += float(roads.size()) * 0.15
	if population > float(housing_capacity):
		population = float(housing_capacity)
	_notify_unlocks()


func estimated_income() -> float:
	var happ_factor := clampf(happiness / 100.0, 0.15, 1.0)
	var pop_tax := population * 0.55 * (0.6 + 0.4 * happ_factor)
	return tax_income + pop_tax


func estimated_net() -> float:
	return estimated_income() - upkeep


func power_ratio() -> float:
	if power_use <= 0:
		return 1.0
	return clampf(float(power_make) / float(power_use), 0.0, 1.0)


func unemployment_ratio() -> float:
	var workforce := population * 0.55
	if workforce <= 0.5:
		return 0.0
	return clampf((workforce - float(jobs)) / workforce, 0.0, 1.0)


func building_count(id: String) -> int:
	var n := 0
	for cell in buildings:
		if String(buildings[cell]["id"]) == id:
			n += 1
	return n


func category_count(cat: String) -> int:
	return int(total_built_cat.get(cat, 0))


# ------------------------------------------------------------------ persistence

func to_dict() -> Dictionary:
	var blist: Array = []
	for cell in buildings:
		var b: Dictionary = buildings[cell]
		blist.append({
			"x": cell.x, "y": cell.y,
			"id": b["id"], "level": b["level"], "variant": b["variant"],
		})
	var rlist: Array = []
	for cell in roads:
		rlist.append({"x": cell.x, "y": cell.y})
	return {
		"version": Cfg.SAVE_VERSION,
		"money": money,
		"population": population,
		"happiness": happiness,
		"day": day,
		"time_of_day": time_of_day,
		"tutorial_step": tutorial_step,
		"total_built": total_built,
		"total_built_cat": total_built_cat,
		"roads_built": roads_built,
		"upgrades_done": upgrades_done,
		"tasks_completed": tasks_completed,
		"lifetime_earned": lifetime_earned,
		"trees": trees,
		"buildings": blist,
		"roads": rlist,
	}


func from_dict(data: Dictionary) -> void:
	new_game()
	_suppress_unlock_toast = true
	money = float(data.get("money", Cfg.START_MONEY))
	population = float(data.get("population", 0.0))
	happiness = float(data.get("happiness", 62.0))
	day = int(data.get("day", 1))
	time_of_day = float(data.get("time_of_day", 0.20))
	tutorial_step = int(data.get("tutorial_step", 0))
	total_built = data.get("total_built", {})
	total_built_cat = data.get("total_built_cat", {})
	roads_built = int(data.get("roads_built", 0))
	upgrades_done = int(data.get("upgrades_done", 0))
	tasks_completed = int(data.get("tasks_completed", 0))
	lifetime_earned = float(data.get("lifetime_earned", 0.0))
	trees = int(data.get("trees", 0))
	for item in data.get("buildings", []):
		var cell := Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))
		buildings[cell] = {
			"id": String(item.get("id", "cottage")),
			"level": int(item.get("level", 1)),
			"variant": int(item.get("variant", 0)),
			"cell": cell,
		}
	for item in data.get("roads", []):
		roads[Vector2i(int(item.get("x", 0)), int(item.get("y", 0)))] = true
	_recompute()
	_tier = Cfg.tier_index(population)
	_suppress_unlock_toast = false
	_last_unlocked.clear()
	_notify_unlocks()
	changed.emit()
	task_progress.emit()