extends GdUnitTestSuite

const COLLECTION: String = "law-of-the-jungle"
const CLASSES: Array[String] = ["war", "decay", "knowledge", "fortune", "order", "shadow"]

class CollectionMeta:
	extends MetaStub
	var collection_open: bool = false
	var keys: Array = []

	func is_collection_unlocked(id: String) -> bool:
		return collection_open and id == COLLECTION

	func unlocked_keys() -> Array:
		return keys.duplicate()

var _db: CardDatabase

func before() -> void:
	_db = ShippedMatch.database()
	assert_bool(_db.report().has_errors()).override_failure_message(_db.report().to_text()).is_false()

func _machine(meta: MetaApi) -> RunMachine:
	var treasures: Treasures = Treasures.new(_db, _db.config("treasures_balance"))
	var draft: RewardDraft = RewardDraft.new(_db, treasures, meta, _db.config("reward_draft"))
	var config: Dictionary = _db.config("run_structure").duplicate(true)
	config["max_match_events"] = 10000
	config["engine_version"] = "collection-test"
	return RunMachine.new(_db, meta, draft, treasures, config, func(_config: Dictionary) -> MatchDriver: return null)

func test_registry_exposes_collection_separately_from_classes() -> void:
	assert_int(_db.collections().size()).is_equal(1)
	assert_str(_db.collection(COLLECTION).id).is_equal(COLLECTION)
	assert_bool(RecordSchemas.SETS.has(COLLECTION)).is_false()
	assert_object(_db.collection("missing")).is_null()

func test_core_collectible_pools_exclude_expansion_for_every_class() -> void:
	for class_id: String in CLASSES:
		for card: Dictionary in _db.collectible_pool(class_id):
			assert_bool(card.has("collection_id")).is_false()

func test_featured_pools_add_exactly_58_legal_cards_per_class() -> void:
	for class_id: String in CLASSES:
		var core: Array = _db.collectible_pool(class_id)
		var featured: Array = _db.collectible_pool(class_id, COLLECTION)
		assert_int(featured.size() - core.size()).is_equal(58)
		for card: Dictionary in featured:
			assert_bool(card.set in [class_id, "neutral"]).is_true()
			assert_bool(card.get("token", false)).is_false()

func test_unknown_featured_collection_cannot_include_expansion() -> void:
	assert_array(_db.collectible_pool("war", "missing")).is_equal(_db.collectible_pool("war"))

func test_featured_bundle_pool_adds_14_class_legal_bundles() -> void:
	for class_id: String in CLASSES:
		var core: Array = _db.bundle_pool(class_id)
		var featured: Array = _db.bundle_pool(class_id, COLLECTION)
		assert_int(featured.size() - core.size()).is_equal(14)
		for bundle: Dictionary in featured:
			for id: String in bundle.cards:
				assert_bool(_db.card(id).set in [class_id, "neutral"]).is_true()

func test_core_boss_and_treasure_pools_exclude_expansion() -> void:
	for band: int in [1, 2, 3]:
		for boss: Dictionary in _db.bosses_in_band(band):
			assert_bool(boss.has("collection_id")).is_false()
	for treasure: Dictionary in _db.treasure_pool():
		assert_bool(treasure.has("collection_id")).is_false()

func test_featured_bosses_and_treasures_enter_their_existing_pools() -> void:
	assert_int(_db.bosses_in_band(1, COLLECTION).size() - _db.bosses_in_band(1).size()).is_equal(1)
	assert_int(_db.bosses_in_band(2, COLLECTION).size() - _db.bosses_in_band(2).size()).is_equal(1)
	assert_int(_db.bosses_in_band(3, COLLECTION).size()).is_equal(_db.bosses_in_band(3).size())
	assert_int(_db.treasure_pool(COLLECTION).size() - _db.treasure_pool().size()).is_equal(3)

func test_locked_collection_is_rejected_before_a_run_or_save_exists() -> void:
	var meta: CollectionMeta = CollectionMeta.new(_db)
	var machine: RunMachine = _machine(meta)
	assert_int(machine.new_run("hero_war", "seed", "", COLLECTION)).is_equal(RunCodes.E_COLLECTION_LOCKED)
	assert_object(machine.state).is_null()
	assert_object(meta.load_active_run()).is_null()

func test_unlocked_collection_choice_is_saved_and_survives_resume_after_revocation() -> void:
	var meta: CollectionMeta = CollectionMeta.new(_db)
	meta.collection_open = true
	var machine: RunMachine = _machine(meta)
	assert_int(machine.new_run("hero_war", "seed", "", COLLECTION)).is_equal(OK)
	var saved: Dictionary = meta.load_active_run()
	assert_str(saved.featured_collection_id).is_equal(COLLECTION)
	meta.collection_open = false
	var resumed: RunMachine = _machine(meta)
	assert_int(resumed.resume()).is_equal(OK)
	assert_str(resumed.state.featured_collection_id).is_equal(COLLECTION)
	assert_array(resumed.state.boss_sequence).is_equal(machine.state.boss_sequence)
	assert_dict(resumed.state.draft_state).is_equal(machine.state.draft_state)

func test_default_run_keeps_core_pools_even_when_collection_is_unlocked() -> void:
	var meta: CollectionMeta = CollectionMeta.new(_db)
	meta.collection_open = true
	var machine: RunMachine = _machine(meta)
	assert_int(machine.new_run("hero_war", "seed")).is_equal(OK)
	assert_str(machine.state.featured_collection_id).is_empty()
	for id: String in machine.state.boss_sequence:
		assert_bool(_db.boss(id).has("collection_id")).is_false()
	for id: String in machine.state.draft_state.bundle_pool:
		assert_bool(_db.bundle(id).has("collection_id")).is_false()

func test_locked_bundle_is_not_offered_and_unlocks_only_apply_to_next_run() -> void:
	var fixture: DraftHarness = DraftHarness.new(_db)
	var original: Dictionary = fixture.db.bundle_pool("war")[0]
	var locked: Dictionary = original.duplicate(true)
	locked.unlock = {"key": "bundle_test_lock", "condition": {"runs_won": 1}}
	var pool_db: DraftHarness.PoolDb = fixture.pool_db([locked])
	pool_db.extra[locked.id] = locked
	fixture.meta.keys = []
	var draft: RewardDraft = fixture.draft({}, pool_db)
	var state: RunState = fixture.state()
	state.draft_state = draft.init_run(state)
	assert_array(draft.offer(&"bundle", state, DraftHarness.stream(5, 1)).option_ids).is_empty()
	fixture.meta.keys = ["bundle_test_lock"]
	assert_array(draft.offer(&"bundle", state, DraftHarness.stream(5, 1)).option_ids).is_empty()
	state.draft_state = draft.init_run(state)
	assert_bool(draft.offer(&"bundle", state, DraftHarness.stream(5, 1)).option_ids.has(locked.id)).is_true()

func test_saved_collection_deck_is_rejected_if_choice_is_removed() -> void:
	var meta: CollectionMeta = CollectionMeta.new(_db)
	meta.collection_open = true
	var machine: RunMachine = _machine(meta)
	assert_int(machine.new_run("hero_war", "seed", "", COLLECTION)).is_equal(OK)
	var saved: Dictionary = meta.load_active_run()
	for card: Dictionary in _db.collectible_pool("war", COLLECTION):
		if card.has("collection_id"):
			saved.deck.append(card.id)
			break
	saved.featured_collection_id = ""
	assert_int(RunRecord.validate(saved, _db)).is_equal(RunCodes.E_UNKNOWN_ID)

func test_mixed_collection_card_file_retains_class_prefix_validation() -> void:
	var card: Dictionary = _db.collectible_pool("war", COLLECTION).filter(func(record: Dictionary) -> bool: return record.get("collection_id") == COLLECTION and record.set == "war")[0].duplicate(true)
	var report: ValidationReport = ValidationReport.new()
	assert_bool(RecordSchemas.check_record("CardDef", COLLECTION + "/cards.json", 0, card, report)).is_true()
	card.set = "shadow"
	report = ValidationReport.new()
	assert_bool(RecordSchemas.check_record("CardDef", COLLECTION + "/cards.json", 0, card, report)).is_false()

func test_resolver_and_clone_keep_selected_collection_generation_pool() -> void:
	var resolver: EffectResolver = EffectResolver.new(_db, _db.config("card_effects"), "war", COLLECTION)
	var engine: RulesEngine = RulesEngine.new(_db, _db.config("match_rules"), resolver)
	var log: EventLog = EventLog.new(10000, EventLog.SCOPE_MATCH)
	var config: Dictionary = ShippedMatch.match_config(_db, "hero_war", "boss_torchbearer", log)
	engine.start(config)
	var clone: RulesEngine = engine.clone()
	assert_str((clone._resolver as EffectResolver).featured_collection_id()).is_equal(COLLECTION)
	assert_array(resolver.collectible_pool()).is_equal(_db.collectible_pool("war", COLLECTION))
	clone.end_match()
	engine.end_match()


func test_explicit_generation_lists_obey_match_collection_context() -> void:
	var core: Dictionary = _db.collectible_pool("war")[0]
	var expansion: Dictionary = _db.collectible_pool("war", COLLECTION).filter(func(card: Dictionary) -> bool: return card.get("collection_id") == COLLECTION)[0]
	var spec: Dictionary = {"pool": "list", "list": [core.id, expansion.id]}
	for selected: String in ["", COLLECTION]:
		var resolver: EffectResolver = EffectResolver.new(_db, _db.config("card_effects"), "war", selected)
		var engine: RulesEngine = RulesEngine.new(_db, _db.config("match_rules"), resolver)
		var log: EventLog = EventLog.new(10000, EventLog.SCOPE_MATCH)
		engine.start(ShippedMatch.match_config(_db, "hero_war", "boss_torchbearer", log))
		var candidates: Array[String] = EffectOps.pool_candidates(resolver, spec, {"owner": "player"})
		assert_bool(candidates.has(core.id)).is_true()
		assert_bool(candidates.has(expansion.id)).is_equal(selected == COLLECTION)
		engine.end_match()

func test_expansion_tokens_are_available_only_to_selected_collection_lists() -> void:
	var token: Dictionary = _db.cards_by_set("neutral").filter(func(card: Dictionary) -> bool: return card.get("collection_id") == COLLECTION and card.get("token", false))[0]
	var core: EffectResolver = EffectResolver.new(_db, _db.config("card_effects"), "war")
	var selected: EffectResolver = EffectResolver.new(_db, _db.config("card_effects"), "war", COLLECTION)
	assert_bool(core.collection_allows(token.id)).is_false()
	assert_bool(selected.collection_allows(token.id)).is_true()
	assert_bool(selected.collectible_pool().has(token)).is_false()


func test_installed_collection_requires_its_trial_and_unlock_validators() -> void:
	var validators: Dictionary = ContentValidateCommand.boot_validators(true)
	validators.configs.erase(COLLECTION + "/trial")
	validators.configs.erase(COLLECTION + "/unlock")
	var report: ValidationReport = CardDatabase.new().load(validators)
	var missing: Array = report.errors().filter(func(entry: Dictionary) -> bool: return entry.code == ValidationReport.E_DELEGATED and entry.field == null)
	assert_array(missing.map(func(entry: Dictionary) -> String: return entry.file)).contains_exactly_in_any_order([COLLECTION + "/trial.json", COLLECTION + "/unlock.json"])
