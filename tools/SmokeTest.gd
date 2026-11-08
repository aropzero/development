extends Node
## Headless gameplay smoke test.
## Run with:  godot --headless --path . res://tools/SmokeTest.tscn
## Exercises placement, economy, upgrades, quests, savings and the world scene.
## Any engine ERROR that appears in the log means the test failed.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== HORIZON CITY SMOKE TEST ===")
	await _test_catalogue()
	await _test_placement()
	await _test_simulation()
	await _test_quests()
	await _test_save_load()
	await _test_world_scene()
	_report()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		_failures.append(label)


func _test_catalogue() -> void:
	print("[catalogue]")
	_check(BuildingDB.order.size() >= 15, "building catalogue populated")
	for id in BuildingDB.order:
		var d: Dictionary = BuildingDB.get_def(id)
		_check(not d.is_empty(), "definition for %s" % id)
		for key in ["name", "cat", "cost", "unlock", "kind"]:
			if not d.has(key):
				_check(false, "%s is missing %s" % [id, key])
	for def in BuildingDB.all():
		if String(def.get("kind", "")) == "model":
			var models: Array = def.get("models", [])
			_check(not models.is_empty(), "%s has model list" % String(def["id"]))
			for m in models:
				if not ResourceLoader.exists(String(m)):
					_check(false, "missing model %s" % String(m))
	# Every category should have at least one entry.
	for cat in Cfg.CATEGORIES:
		_check(not BuildingDB.in_category(String(cat["id"])).is_empty(),
			"category %s has buildings" % String(cat["id"]))


func _test_placement() -> void:
	print("[placement]")
	GameState.new_game()
	QuestManager.begin(false)
	_check(is_equal_approx(GameState.money, Cfg.START_MONEY), "starting money")

	var cell := Vector2i(8, 8)
	var err := GameState.try_place("cottage", cell)
	_check(err == "", "place cottage -> '%s'" % err)
	_check(GameState.buildings.size() == 1, "one building recorded")
	_check(GameState.money < Cfg.START_MONEY, "money spent")
	_check(GameState.housing_capacity == 6, "housing capacity counted")
	_check(not GameState.cell_free(cell), "cell no longer free")

	_check(GameState.try_place("cottage", cell) != "", "cannot stack buildings")
	_check(GameState.try_place("cottage", Vector2i(-3, 4)) != "", "cannot build outside")

	var upgrade := GameState.upgrade_cost(cell)
	_check(upgrade > 0.0, "upgrade cost computed")
	GameState.add_money(10000.0)
	err = GameState.try_upgrade(cell)
	_check(err == "", "upgrade -> '%s'" % err)
	_check(int(GameState.building_at(cell)["level"]) == 2, "level is now 2")
	_check(GameState.upgrades_done == 1, "upgrade counted")

	var refund := GameState.sell_value(cell)
	_check(refund > 0.0, "sell value positive")
	err = GameState.demolish(cell)
	_check(err == "", "demolish -> '%s'" % err)
	_check(GameState.buildings.is_empty(), "building removed")

	GameState.add_money(10000.0)
	err = GameState.try_road(Vector2i(5, 5))
	_check(err == "", "lay road -> '%s'" % err)
	_check(GameState.roads.has(Vector2i(5, 5)), "road recorded")
	_check(GameState.roads_built == 1, "road counted")
	GameState.demolish(Vector2i(5, 5))
	_check(not GameState.roads.has(Vector2i(5, 5)), "road removed")


func _test_simulation() -> void:
	print("[simulation]")
	GameState.new_game()
	GameState.add_money(100000.0)
	var cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(5, 2), Vector2i(6, 2)]
	for c in cells:
		GameState.try_place("cottage", c)
	GameState.try_place("wind", Vector2i(2, 6))
	GameState.try_place("park", Vector2i(7, 7))
	GameState._recompute()
	_check(GameState.housing_capacity == 30, "housing capacity 30")
	_check(GameState.power_make > 0, "turbine generates power")

	var before := GameState.population
	for i in 25:
		GameState._tick_day()
	_check(GameState.population > before, "population grows (%d)" % int(GameState.population))
	_check(GameState.day > 25, "days advance")
	_check(GameState.happiness >= 0.0 and GameState.happiness <= 100.0, "happiness in range")
	_check(GameState.lifetime_earned > 0.0, "income recorded")
	_check(Cfg.tier_name(GameState.population) != "", "tier name resolves")

	GameState.speed = 3.0
	GameState._process(1.0)
	GameState.speed = 1.0

	# Never let a penniless, empty city become unrecoverable.
	GameState.new_game()
	GameState.money = -800.0
	GameState._tick_day()
	_check(GameState.money >= 400.0, "penniless empty city gets a rescue grant")


func _test_quests() -> void:
	print("[quests]")
	GameState.new_game()
	QuestManager.begin(false)
	_check(QuestManager.active.size() >= 1, "a tutorial quest is active")
	_check(QuestManager.progress_text(QuestManager.active[0]) != "", "quest progress text")
	_check(QuestManager.progress_ratio(QuestManager.active[0]) >= 0.0, "quest ratio")

	GameState.add_money(100000.0)
	var placed := 0
	for c in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]:
		if GameState.try_place("cottage", c) == "":
			placed += 1
	GameState.task_progress.emit()
	_check(placed == 6, "placed six cottages")

	# Skip the tutorial chain and verify procedural goals generate.
	QuestManager.tutorial_index = QuestManager.TUTORIAL.size()
	QuestManager.active.clear()
	QuestManager._ensure_slots()
	_check(QuestManager.active.size() >= 1, "procedural quests generated")
	for t in QuestManager.active:
		_check(String(t.get("title", "")) != "", "procedural task has a title")
		_check(float(t.get("target", 0)) > 0.0, "procedural task has a target")
		_check(float(t.get("reward", 0)) > 0.0, "procedural task has a reward")
	QuestManager.reset()


func _test_save_load() -> void:
	print("[save/load]")
	GameState.new_game()
	GameState.add_money(5000.0)
	GameState.try_place("cottage", Vector2i(4, 4))
	GameState.try_place("shop", Vector2i(5, 4))
	GameState.try_road(Vector2i(6, 4))
	GameState.population = 5.0
	var expected_money := GameState.money
	var expected_count := GameState.buildings.size()

	_check(SaveManager.save_game(), "save succeeds")
	_check(SaveManager.has_save(), "save file exists")
	var data := SaveManager.load_game()
	_check(not data.is_empty(), "save loads")
	_check(data.has("city") and data.has("quests"), "payload shape")

	GameState.new_game()
	GameState.from_dict(data["city"])
	_check(is_equal_approx(GameState.money, expected_money), "money restored")
	_check(GameState.buildings.size() == expected_count, "buildings restored")
	_check(GameState.roads.size() == 1, "roads restored")
	_check(is_equal_approx(GameState.population, 5.0), "population restored")

	SaveManager.music_volume = 0.4
	SaveManager.save_settings()
	var volume := SaveManager.music_volume
	SaveManager.music_volume = 1.0
	SaveManager.load_settings()
	_check(is_equal_approx(SaveManager.music_volume, volume), "settings round trip")


func _test_world_scene() -> void:
	print("[world]")
	GameState.new_game()
	GameState.simulate = true
	QuestManager.begin(false)
	var game: Node = load("res://scenes/Game.tscn").instantiate()
	add_child(game)
	var frames := 0
	while frames < 900 and game.hud == null:
		await get_tree().process_frame
		frames += 1
	print("  (HUD ready after %d frames)" % frames)
	_check(game.world != null, "city world built")
	_check(game.rig != null, "camera rig built")
	_check(game.hud != null, "HUD built")
	print("  (icons baked: %d)" % game.icons.size())
	_check(game.hud.build_bar != null, "build bar built")
	_check(game.hud.task_panel != null, "task panel built")
	_check(game.hud.build_bar._cards.size() > 0, "build cards present")
	_check(game.world.building_nodes.is_empty(), "empty world has no buildings")

	GameState.add_money(100000.0)
	game.build_mode = "cottage"
	game._place(Vector2i(7, 7))
	_check(game.world.building_nodes.has(Vector2i(7, 7)), "building visual spawned")
	game._place(Vector2i(7, 8))
	game.build_mode = "road"
	game._place(Vector2i(8, 8))
	_check(game.world.road_nodes.has(Vector2i(8, 8)), "road visual spawned")
	game._select(Vector2i(7, 7))
	_check(game.hud.info_panel.visible, "info panel opens on select")
	game._upgrade(Vector2i(7, 7))
	_check(int(GameState.building_at(Vector2i(7, 7))["level"]) == 2, "in-game upgrade")
	game._toggle_demolish()
	game._demolish(Vector2i(7, 8))
	_check(not GameState.buildings.has(Vector2i(7, 8)), "in-game demolish")
	game._cancel_mode()
	game.rig.rotate_step(1.0)
	game.rig.zoom(0.9)
	game.rig.focus_center()
	_check(game.rig.cell_under_screen(Vector2(640, 360)) != Vector2i(-999, -999),
		"screen ray resolves to a cell")
	game.world.rebuild_from_state()
	_check(game.world.building_nodes.size() == 1, "world rebuilds from state")

	# Mobile back button must never dump the player out of a live city.
	game._on_back_pressed()
	_check(game.hud.is_paused(), "back opens pause menu")
	game._on_back_pressed()
	_check(not game.hud.is_paused(), "back closes pause menu")
	game.build_mode = "cottage"
	game._on_back_pressed()
	_check(game.build_mode == "", "back cancels build mode")

	# Goal progress must refresh live while the player is building.
	QuestManager.progress_changed.emit()
	game.hud.task_panel.update_progress()
	_check(true, "task panel progress refresh")
	game.queue_free()
	await get_tree().process_frame


func _report() -> void:
	print("=== %d checks, %d failures ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  - ", f)
	print("SMOKE RESULT: ", "PASS" if _failures.is_empty() else "FAIL")
	get_tree().quit(0 if _failures.is_empty() else 1)