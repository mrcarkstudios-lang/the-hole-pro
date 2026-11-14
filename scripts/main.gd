extends Node3D
## Hole Rush - main game controller.
## City generation, holes + bot AI, swallowing, combos, power-ups, modes
## (Classic / Royale), themes, rounds, rewards and juice.

const TILE := 2.0
const N := 22                 # city is N x N tiles (roads every 3rd tile)
const HALF := 22.0            # half-size of the city in world units
const CELL := 2.0             # spatial-grid cell size
const SEA_SHADER := "shader_type spatial;\nrender_mode unshaded;\nuniform vec3 deep = vec3(0.08, 0.42, 0.72);\nuniform vec3 shallow = vec3(0.3, 0.8, 0.9);\nuniform float edge = 23.0;\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() {\n\tfloat w = sin(wp.x * 1.3 + TIME * 0.9) + sin(wp.z * 1.7 - TIME * 0.7) + sin((wp.x + wp.z) * 0.6 + TIME * 0.5);\n\tfloat d = max(abs(wp.x), abs(wp.z));\n\tfloat near = 1.0 - smoothstep(edge, edge + 9.0, d);\n\tvec3 c = mix(deep, shallow, near * 0.85);\n\tc += vec3(0.6) * smoothstep(1.9, 2.7, w) * 0.22;\n\tfloat foam = smoothstep(edge + 1.6, edge + 1.0, d) * (0.55 + 0.45 * sin(TIME * 1.6 + wp.x * 0.7 + wp.z * 0.7));\n\tc += vec3(0.85) * foam * 0.4;\n\tALBEDO = c;\n}"
const JOY_R := 110.0
const MODEL_PATH := "res://assets/models/%s.gltf"
const ROAD_YAW := 0.0

const MODEL_NAMES: Array[String] = ["road_junction", "road_straight", "base", "streetlight",
	"trafficlight_A", "trafficlight_B", "trafficlight_C", "watertower", "bush", "bench", "box_A", "box_B",
	"dumpster", "firehydrant", "trash_A", "trash_B", "car_hatchback", "car_police", "car_sedan",
	"car_stationwagon", "car_taxi", "building_A", "building_B", "building_C", "building_D", "building_E",
	"building_F", "building_G", "building_H", "building_A_withoutBase", "building_B_withoutBase",
	"building_C_withoutBase", "building_D_withoutBase", "building_E_withoutBase", "building_F_withoutBase",
	"building_G_withoutBase", "building_H_withoutBase",
	"chair_A", "chair_B", "chair_stool", "couch", "table_medium", "table_small", "armchair", "lamp_standing", "cabinet_small", "shelf_A_small", "cactus_medium_A", "cactus_small_A", "bed_single_A", "table_low", "Fuel_A_Barrel", "Fuel_B_Barrels", "Fuel_C_Barrel", "Fuel_A_Jerrycan", "Pallet_Wood", "Pallet_Wood_Covered_A", "Wood_Log_Stack", "Wood_Planks_Stack_Large", "Stone_Bricks_Stack_Large", "Stone_Chunks_Large", "Gold_Bars_Stack_Large", "Gold_Nugget_Large", "Iron_Bars_Stack_Large", "Copper_Bars_Stack_Medium", "Parts_Pile_Large", "Textiles_Stack_Large_Colored", "Silver_Bars_Stack_Large", "Wood_Log_A", "anvil", "bucket_metal", "shovel", "pickaxe", "hammer", "grindstone", "lantern", "torch", "rope_bundle_A", "saw", "wrench_A"]
const PROPS: Array[String] = ["bush", "bush", "bench", "box_A", "box_B", "dumpster",
	"firehydrant", "trash_A", "trash_B", "trash_A", "trash_B", "bush",
	"@tree", "@tree", "@barrel", "@crate", "@cone", "@bin"]
const BUILDINGS: Array[String] = ["building_A_withoutBase", "building_B_withoutBase",
	"building_C_withoutBase", "building_D_withoutBase", "building_E_withoutBase",
	"building_F_withoutBase", "building_G_withoutBase", "building_H_withoutBase"]
const CARS: Array[String] = ["car_hatchback", "car_police", "car_sedan", "car_stationwagon", "car_taxi"]
const SKY_MODELS: Array[String] = ["building_C_withoutBase", "building_D_withoutBase", "building_G_withoutBase", "building_H_withoutBase"]
const MEGA_MODELS: Array[String] = ["building_A_withoutBase", "building_B_withoutBase", "building_E_withoutBase",
	"building_F_withoutBase", "building_G_withoutBase", "building_H_withoutBase"]
const HOUSES: Array[String] = ["building_A_withoutBase", "building_B_withoutBase", "building_C_withoutBase", "building_D_withoutBase"]
const VEH_KINDS: Array[String] = ["@truck", "@bus", "@schoolbus", "@firetruck", "@tanker", "@garbage", "@bicycle", "@motorbike"]
# model, spawn weight, longest side in world units
const VEH_TABLE := [
	["car_hatchback", 10, 1.35], ["car_sedan", 11, 1.38], ["car_taxi", 9, 1.38], ["car_police", 6, 1.38],
	["car_stationwagon", 8, 1.38], ["@truck", 11, 2.1], ["@bus", 6, 2.6], ["@schoolbus", 3, 2.6],
	["@firetruck", 3, 2.4], ["@tanker", 4, 2.3], ["@garbage", 3, 2.2], ["@bicycle", 7, 0.62], ["@motorbike", 6, 0.8]]
const TRUCK_COLS: Array[Color] = [Color(0.9, 0.3, 0.25), Color(0.25, 0.55, 0.95), Color(0.95, 0.75, 0.15),
	Color(0.3, 0.75, 0.45), Color(0.95, 0.5, 0.15), Color(0.7, 0.4, 0.9)]
# model, longest side in world units
const SMALLS := [["bush", 0.45], ["bench", 0.85], ["box_A", 0.38], ["box_B", 0.34], ["dumpster", 0.95],
	["firehydrant", 0.32], ["trash_A", 0.26], ["trash_B", 0.22], ["@tree", 1.25], ["@barrel", 0.36],
	["@crate", 0.4], ["@cone", 0.32], ["@bin", 0.32]]
const TOOLS := [["anvil", 0.7], ["bucket_metal", 0.4], ["shovel", 0.8], ["pickaxe", 0.8], ["hammer", 0.55],
	["grindstone", 0.9], ["lantern", 0.4], ["torch", 0.7], ["rope_bundle_A", 0.5], ["saw", 0.6], ["wrench_A", 0.5],
	["@cone", 0.32], ["@cone", 0.32], ["@crate", 0.4], ["@barrel", 0.36], ["Pallet_Wood", 0.9]]
const STOCK := [["Pallet_Wood_Covered_A", 1.0], ["Wood_Log_Stack", 1.1], ["Wood_Planks_Stack_Large", 1.0],
	["Stone_Bricks_Stack_Large", 0.9], ["Iron_Bars_Stack_Large", 0.9], ["Copper_Bars_Stack_Medium", 0.8],
	["Fuel_B_Barrels", 0.9], ["Fuel_A_Barrel", 0.5], ["Fuel_C_Barrel", 0.5], ["Fuel_A_Jerrycan", 0.4],
	["Parts_Pile_Large", 0.9], ["Textiles_Stack_Large_Colored", 0.9], ["Stone_Chunks_Large", 0.8],
	["Silver_Bars_Stack_Large", 0.8], ["Wood_Log_A", 0.7], ["dumpster", 0.95]]
const BOT_NAMES: Array[String] = ["Kai", "Zed", "Mia", "Rex", "Luna", "Bolt", "Nova", "Tank"]
const BOT_COLORS: Array[Color] = [Color(1.0, 0.25, 0.3), Color(0.3, 0.55, 1.0),
	Color(0.35, 0.9, 0.4), Color(0.8, 0.4, 1.0), Color(1.0, 0.55, 0.15), Color(0.2, 0.9, 0.9),
	Color(1.0, 0.9, 0.2), Color(1.0, 0.45, 0.75)]
const ORB_TYPES := {
	"speed": Color(0.2, 0.6, 1.0),
	"magnet": Color(0.9, 0.3, 1.0),
	"grow": Color(0.3, 1.0, 0.4),
	"time": Color(1.0, 0.9, 0.2),
}
const THEMES := [
	{"name": "Sunny City", "bg": Color(0.55, 0.78, 0.95), "amb": Color(0.85, 0.9, 1.0), "amb_e": 0.75,
		"sun": Color(1, 0.97, 0.9), "sun_e": 1.15, "sun_rot": Vector3(-58, -35, 0),
		"ground": Color(0.36, 0.62, 0.3), "glow": 0.25},
	{"name": "Golden Hour", "bg": Color(1.0, 0.62, 0.4), "amb": Color(1.0, 0.75, 0.6), "amb_e": 0.7,
		"sun": Color(1, 0.72, 0.42), "sun_e": 1.35, "sun_rot": Vector3(-30, -60, 0),
		"ground": Color(0.55, 0.5, 0.25), "glow": 0.4},
	{"name": "Neon Night", "bg": Color(0.04, 0.03, 0.13), "amb": Color(0.4, 0.35, 0.8), "amb_e": 1.0,
		"sun": Color(0.55, 0.6, 1.0), "sun_e": 0.8, "sun_rot": Vector3(-62, 20, 0),
		"ground": Color(0.06, 0.09, 0.17), "glow": 1.0},
	{"name": "Frost Town", "bg": Color(0.78, 0.9, 1.0), "amb": Color(0.9, 0.95, 1.0), "amb_e": 0.95,
		"sun": Color(0.92, 0.96, 1.0), "sun_e": 1.0, "sun_rot": Vector3(-60, -30, 0),
		"ground": Color(0.93, 0.96, 1.0), "glow": 0.2},
]

var rng := RandomNumberGenerator.new()
var profile: Profile
var world: Node3D
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var ui: GameUI
var sfx: Sfx
var music: Music
var fx: Fx
var zone_walls: Array[MeshInstance3D] = []

var items: Array[Item] = []
var grid: Dictionary = {}
var movers: Array[Item] = []
var faded: Array = []
var occ_t := 0.0
var road_coords: Array[float] = []
var sig_t := 0.0
var sig_last := [-1, -1]
var lamp_mat: StandardMaterial3D
var lamp_halo_mat: StandardMaterial3D
var lamp_pool_mat: StandardMaterial3D
var lanes: Array[Dictionary] = []
var target_veh := 0
var target_walk := 0
var falling: Array[Item] = []
var holes: Array[Hole] = []
var orbs: Array[Node3D] = []
var road_points: Array[Vector3] = []
var junctions: Array[Vector3] = []
var block_points: Array[Vector3] = []
var scene_cache: Dictionary = {}
var bb_cache: Dictionary = {}
var start_item_count := 1
var restock_timer := 0.0

var player: Hole
var state := "menu"          # menu | countdown | playing | result
var mode := "classic"        # classic | royale
var theme_idx := 0
var time_left := 90.0
var round_total := 90.0
var elapsed := 0.0
var zone_half := HALF - 0.3
var countdown_t := 0.0
var last_count := -1
var last_tick := -1
var orb_timer := 5.0
var clock := 0.0
var cam_focus := Vector3.ZERO
var cam_dist := 8.0
var trauma := 0.0
var fov_kick := 0.0
var is_boss := false
var tut_stage := 0
var tut_timer := 0.0
var last_mult := 1
var round_stats := {"orbs": 0}
var last_gain := 0
var last_danger := -10.0
var log_fps := false
var building := false
var tile_batches: Dictionary = {}
var sky_batches: Dictionary = {}
var parts_cache: Dictionary = {}
var model_requested: Dictionary = {}
var mon: Monetization
var revive_used := false
var revive_ad_running := false
var starter_shown := false
var mobile_low := false
var fps_acc := 0.0
var fps_frames := 0

var joy_active := false
var joy_origin := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_touch := -1


func _ready() -> void:
	rng.randomize()
	log_fps = FileAccess.file_exists("user://fps_log")
	profile = Profile.new()
	profile.load_all()
	profile.roll_missions()
	profile.ensure_first_time()
	_setup_environment()
	sfx = Sfx.new()
	if not FileAccess.file_exists("user://no_sfx"):
		add_child(sfx)
	music = Music.new()
	if not FileAccess.file_exists("user://no_music"):
		add_child(music)
	fx = Fx.new()
	add_child(fx)
	mon = Monetization.new()
	mon.profile = profile
	add_child(mon)
	ui = GameUI.new()
	ui.profile = profile
	ui.mon = mon
	add_child(ui)
	ui.play_pressed.connect(_on_play)
	ui.again_pressed.connect(_on_again)
	ui.home_pressed.connect(_on_home)
	ui.pause_toggled.connect(_on_pause)
	ui.bonus_claimed.connect(_on_bonus)
	ui.settings_changed.connect(_on_settings)
	ui.skin_changed.connect(_on_skin_changed)
	ui.sound.connect(func(n: String):
		if n.begins_with("pop:"):
			sfx.pop(int(n.substr(4)))
		else:
			sfx.play(n))
	ui.intro_done.connect(_on_intro_done)
	ui.double_requested.connect(_on_double)
	ui.boost_requested.connect(_on_boost)
	ui.revive_choice.connect(_on_revive_choice)
	mon.ad_unavailable.connect(func(): ui.flash("Ad not ready yet - try again in a moment"))
	_on_settings()
	music.enabled = false   # silent during the brand + game intro
	starter_shown = true
	_request_models()
	ui.play_intro()
	await get_tree().process_frame
	await _new_round(false, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and state == "playing":
		ui._set_pause(true)


# =====================================================================
# Setup / theme
# =====================================================================
func _setup_environment() -> void:
	if OS.has_feature("mobile"):
		# phones: render the 3D world at lower resolution (UI stays sharp) + cheap shadows
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = 0.72
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		mobile_low = true
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_density = 0.005
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	if OS.has_feature("mobile") or FileAccess.file_exists("user://q_noglow"):
		env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	# measured on a mid-range phone: shadows cost ~12 fps in landscape, so they are PC-only
	if mobile_low or FileAccess.file_exists("user://q_noshadow"):
		sun.shadow_enabled = false
	if FileAccess.file_exists("user://q_scale60"):
		get_viewport().scaling_3d_scale = 0.6
	add_child(sun)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = 52.0
	cam.near = 0.1
	cam.far = 200.0
	add_child(cam)
	cam.make_current()


func _apply_theme(idx: int) -> void:
	var th: Dictionary = THEMES[idx]
	env.background_color = th["bg"]
	env.fog_light_color = th["bg"]
	env.ambient_light_color = th["amb"]
	env.ambient_light_energy = th["amb_e"]
	env.glow_hdr_threshold = 1.0 if idx != 2 else 0.7
	env.glow_intensity = 0.4 + float(th["glow"])
	sun.light_color = th["sun"]
	sun.light_energy = th["sun_e"]
	sun.rotation_degrees = th["sun_rot"]


func _on_settings() -> void:
	sfx.enabled = profile.sfx_on
	music.enabled = profile.music_on
	if ui != null and ui.home.visible:
		ui.refresh_home(THEMES[(profile.level - 1) % THEMES.size()]["name"])


func _on_skin_changed() -> void:
	_skin_player()
	ui.refresh_home(THEMES[(profile.level - 1) % THEMES.size()]["name"])


func _skin_player() -> void:
	if player == null:
		return
	var sk: Dictionary = Profile.SKINS[profile.skin]
	player.set_skin(sk["color"], sk.has("rainbow"))


# =====================================================================
# Rounds
# =====================================================================
func _new_round(play: bool, async_build: bool = false) -> void:
	building = true
	if world:
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	items.clear()
	falling.clear()
	holes.clear()
	orbs.clear()
	road_points.clear()
	junctions.clear()
	block_points.clear()
	zone_walls.clear()
	theme_idx = (profile.level - 1) % THEMES.size()
	if mode == "royale" and play:
		theme_idx = rng.randi_range(0, THEMES.size() - 1)
	_apply_theme(theme_idx)
	is_boss = mode == "classic" and profile.level % 5 == 0
	await _build_city(async_build)
	start_item_count = items.size()
	ui.minimap.half = HALF
	ui.minimap.roads = road_coords
	restock_timer = 3.0
	_spawn_holes()
	if mode == "royale":
		_build_zone_walls()
	round_total = 120.0 + 5.0 * float(profile.upg["time"]) if mode == "classic" else 140.0
	time_left = round_total
	elapsed = 0.0
	player_out = false
	zone_half = HALF - 0.3
	orb_timer = 4.0
	joy_active = false
	joy_vec = Vector2.ZERO
	trauma = 0.0
	last_mult = 1
	last_tick = -1
	tut_stage = 0
	tut_timer = 0.0
	round_stats = {"orbs": 0}
	cam_focus = player.position
	cam_dist = 14.0
	revive_used = false
	revive_ad_running = false
	if play:
		if profile.boost_ready or profile.vip:
			# free boost (VIP every round, others after watching an ad / starter pack)
			player.effects["speed"] = 11.0
			player.effects["magnet"] = 11.0
			profile.boost_ready = false
			profile.save_all()
		state = "countdown"
		countdown_t = 3.0
		last_count = -1
		ui.show_hud()
		music.mode = "play"
		music.intensity = 0.0
		music.hype = false
		if is_boss:
			ui.toast("BOSS LEVEL!", Color(1, 0.3, 0.3))
	else:
		state = "menu"
		music.mode = "menu"
		ui.refresh_home(THEMES[(profile.level - 1) % THEMES.size()]["name"])
		ui.show_home()
		if profile.is_starter_available() and not starter_shown:
			starter_shown = true
			ui.call_deferred("show_starter")
	building = false


func _on_play(m: String) -> void:
	mode = m
	_new_round(true)


func _on_intro_done() -> void:
	music.enabled = profile.music_on
	# let the player take in the menu first; popups come after a calm pause
	await get_tree().create_timer(2.2).timeout
	if state != "menu" or ui.intro_active:
		return
	ui.show_daily()
	if ui.modal == null and profile.is_starter_available():
		await get_tree().create_timer(1.0).timeout
		if state == "menu" and ui.modal == null:
			ui.show_starter()


func _on_again() -> void:
	_with_interstitial(func(): _new_round(true))


func _on_home() -> void:
	mode = "classic"
	get_tree().paused = false
	if state == "result":
		_with_interstitial(func(): _new_round(false))
	else:
		_new_round(false)


## Short ad between rounds (never during play; skipped for VIP / Remove Ads).
func _with_interstitial(next: Callable) -> void:
	if mon.can_show_interstitial():
		mon.show_interstitial(func():
			profile.rounds_since_ad = 0
			profile.last_ad_unix = int(Time.get_unix_time_from_system())
			profile.save_all()
			next.call())
	else:
		next.call()


func _on_double() -> void:
	mon.show_rewarded("double_coins", func(ok: bool):
		if ok:
			profile.coins += last_gain
			profile.save_all()
			sfx.play("coin")
			ui.mark_double_done(last_gain)
		else:
			ui.res_double_btn.disabled = false)


func _on_boost() -> void:
	mon.show_rewarded("boost", func(ok: bool):
		if ok:
			profile.boost_ready = true
			profile.save_all()
			sfx.play("power")
			ui.refresh_home(THEMES[(profile.level - 1) % THEMES.size()]["name"]))


# ---------- Royale revive ----------
func _offer_revive() -> void:
	player.invuln = 99.0
	if profile.vip:
		_do_revive("VIP free revive!")
		return
	state = "revive"
	revive_ad_running = false
	get_tree().paused = true
	ui.show_revive()
	get_tree().create_timer(8.0, true).timeout.connect(func():
		if state == "revive" and not revive_ad_running:
			ui.close_revive()
			_decline_revive())


func _on_revive_choice(accept: bool) -> void:
	if state != "revive":
		return
	if accept:
		revive_ad_running = true
		mon.show_rewarded("revive", func(ok: bool):
			revive_ad_running = false
			if ok:
				_do_revive("REVIVED!")
			else:
				_decline_revive())
	else:
		_decline_revive()


func _do_revive(msg: String) -> void:
	get_tree().paused = false
	state = "playing"
	revive_used = true
	var spot: Vector3 = junctions.pick_random()
	player.position = Vector3(spot.x, 0.115, spot.z)
	player.invuln = 3.0
	player.combo = 0
	sfx.play("power")
	ui.toast(msg, Color(0.5, 1, 0.6))


func _decline_revive() -> void:
	get_tree().paused = false
	state = "playing"
	player_out = true
	_finish_round()


func _on_pause(p: bool) -> void:
	get_tree().paused = p


func _on_bonus(mult: int) -> void:
	var extra := last_gain * (mult - 1)
	profile.coins += extra
	profile.save_all()
	sfx.play("coin")
	sfx.play("levelup" if mult >= 5 else "gold")


func _spawn_holes() -> void:
	var cand: Array[Vector3] = []
	for j in junctions:
		if absf(j.x) <= HALF - 4.0 and absf(j.z) <= HALF - 4.0:
			cand.append(j)
	cand.shuffle()
	var spots: Array[Vector3] = []
	for c in cand:
		var ok := true
		for s in spots:
			if c.distance_to(s) < 8.0:
				ok = false
				break
		if ok:
			spots.append(c)
		if spots.size() >= 9:
			break
	while spots.size() < 9:
		spots.append(cand.pick_random())
	var lvl := profile.level
	var start_r := 0.30 + 0.025 * float(profile.upg["size"])
	player = _make_hole("YOU", Color.WHITE, true, spots[0], start_r)
	player.max_r = 4.2
	player.speed_mult = 1.0 + 0.06 * float(profile.upg["speed"])
	_skin_player()
	var bots := 4 if lvl < 3 else 5
	if mode == "royale":
		bots = 7
	var names: Array[String] = BOT_NAMES.duplicate()
	names.shuffle()
	for b in bots:
		var h := _make_hole(names[b], BOT_COLORS[b], false, spots[b + 1], 0.30 + 0.01 * float(lvl))
		h.skill = clampf(0.5 + 0.08 * float(lvl), 0.5, 1.2)
		h.speed_mult = clampf(0.68 + 0.035 * float(lvl), 0.7, 1.05)
		h.max_r = 1.4 + 0.15 * minf(float(lvl), 10.0)
		h.aggr = rng.randf_range(0.25, 0.9)
	if is_boss:
		var boss := holes[holes.size() - 1]
		boss.hname = "BOSS"
		boss.label.text = "BOSS"
		boss.set_skin(Color(0.9, 0.1, 0.12), false)
		boss.is_boss = true
		boss.skill = 1.2
		boss.aggr = 0.95
		boss.speed_mult = 0.98
		boss.max_r = 3.0
		boss.r = 0.55
		boss.target_r = 0.55


func _make_hole(hname: String, col: Color, is_player: bool, pos: Vector3, start_r: float) -> Hole:
	var h := Hole.new()
	world.add_child(h)
	h.setup(hname, col, is_player, start_r)
	h.position = Vector3(pos.x, 0.115, pos.z)
	h.invuln = 1.5
	holes.append(h)
	return h


func _build_zone_walls() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.2, 0.2, 0.85)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.1, 0.1)
	m.emission_energy_multiplier = 2.0
	for i in 4:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1, 0.3, 1)
		mi.mesh = bm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		zone_walls.append(mi)
	_update_zone_walls()


func _update_zone_walls() -> void:
	if zone_walls.size() < 4:
		return
	var z := zone_half + 0.3
	var len := 60.0
	var w := 0.18
	zone_walls[0].scale = Vector3(len, 1, w)
	zone_walls[0].position = Vector3(0, 0.15, -z)
	zone_walls[1].scale = Vector3(len, 1, w)
	zone_walls[1].position = Vector3(0, 0.15, z)
	zone_walls[2].scale = Vector3(w, 1, len)
	zone_walls[2].position = Vector3(-z, 0.15, 0)
	zone_walls[3].scale = Vector3(w, 1, len)
	zone_walls[3].position = Vector3(z, 0.15, 0)


# ---------- end of round ----------
func _finish_round() -> void:
	if state == "result":
		return
	state = "result"
	joy_active = false
	ui.set_joystick(false, Vector2.ZERO, Vector2.ZERO)
	music.mode = "result"
	music.hype = false
	var sorted: Array = holes.duplicate()
	sorted.sort_custom(func(a: Hole, b: Hole) -> bool: return a.score > b.score)
	var rank: int = sorted.find(player) + 1
	if not holes.has(player):
		rank = holes.size() + 1
	if player_out:
		rank = holes.size()
	var won := rank == 1
	var bonus := [80, 40, 20, 0, 0, 0]
	var gain: int = int(player.score / 12.0) + int(bonus[mini(rank - 1, 5)])
	if mode == "royale":
		gain = int(gain * 1.5)
	if is_boss and won:
		gain *= 2
	gain *= profile.coin_multiplier()   # VIP: 2x coins
	profile.rounds_since_ad += 1
	coins_gain(gain)
	last_gain = gain
	var xp_gain: int = 25 + int(player.score / 10.0) + (40 if won else 0)
	var lv_up := profile.add_xp(xp_gain) > 0
	profile.pass_xp += xp_gain
	var new_best := player.score > profile.best
	if new_best:
		profile.best = player.score
	profile.rounds += 1
	profile.progress("play", 1)
	if won:
		profile.wins += 1
		profile.progress("wins", 1)
		if mode == "classic":
			profile.level += 1
		else:
			profile.royale_wins += 1
		sfx.play("win")
	else:
		sfx.play("lose")
	if lv_up:
		sfx.play("levelup")
	profile.tutorial_done = true
	profile.save_all()
	var near := ""
	if won:
		var lead := 0
		if sorted.size() > 1:
			lead = player.score - (sorted[1] as Hole).score
		near = "Winner by %d points!" % lead
	elif rank >= 2 and holes.has(player):
		var above: Hole = sorted[rank - 2]
		near = "So close! Only %d points behind %s" % [above.score - player.score + 1, above.hname]
	elif player_out:
		near = "You were eliminated - %d left standing" % (holes.size() - 1)
	var lines := ""
	for i in sorted.size():
		var h: Hole = sorted[i]
		lines += "%d. %s  -  %d\n" % [i + 1, h.hname, h.score]
	var head := "YOU WIN!" if won else "RANK #%d" % rank
	if mode == "royale" and won:
		head = "LAST ONE STANDING!"
	ui.show_result({"head": head, "won": won, "score": player.score, "gain": gain,
		"xp": xp_gain, "level_up": lv_up, "near": near, "board": lines.strip_edges(),
		"new_best": new_best})


var player_out := false


func coins_gain(g: int) -> void:
	profile.coins += g


# =====================================================================
# City generation
# =====================================================================
func _tile_pos(i: int, j: int) -> Vector3:
	return Vector3((float(i) - float(N - 1) * 0.5) * TILE, 0.0, (float(j) - float(N - 1) * 0.5) * TILE)


## Start loading every model on a background thread (done at launch, before the city is built).
func _request_models() -> void:
	for m in MODEL_NAMES:
		ResourceLoader.load_threaded_request(MODEL_PATH % m)
		model_requested[m] = true


func _scene(model: String) -> PackedScene:
	if not scene_cache.has(model):
		var path := MODEL_PATH % model
		if model_requested.has(model):
			scene_cache[model] = ResourceLoader.load_threaded_get(path)   # waits only if still loading
		else:
			scene_cache[model] = load(path)
	return scene_cache[model]


func _make_model(model: String, col: Color = Color(0, 0, 0, 0)) -> Node3D:
	if model.begins_with("@"):
		var k := model.substr(1)
		if Vehicles.has(k):
			return Vehicles.build(k, col)
		return Props.build(k)
	return _scene(model).instantiate() as Node3D


func _collect(n: Node, xf: Transform3D, out: Array[AABB]) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		out.append(t * (n as MeshInstance3D).get_aabb())
	for c in n.get_children():
		_collect(c, t, out)


func _bb(model: String) -> AABB:
	if bb_cache.has(model):
		return bb_cache[model]
	var inst := _make_model(model)
	var out: Array[AABB] = []
	_collect(inst, Transform3D.IDENTITY, out)
	var box: AABB = out[0]
	for k in range(1, out.size()):
		box = box.merge(out[k])
	inst.free()
	bb_cache[model] = box
	return box


func _static(model: String, pos: Vector3, yaw: float) -> Node3D:
	var n := _make_model(model)
	n.position = pos
	n.rotation.y = yaw
	world.add_child(n)
	return n


## Static scenery (roads, ground tiles, skyline) is merged into a few MultiMesh draw calls.
func _batch(into: Dictionary, model: String, pos: Vector3, yaw: float, scl: Vector3 = Vector3.ONE) -> void:
	if not into.has(model):
		into[model] = []
	(into[model] as Array).append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scl), pos))


func _collect_parts(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append({"mesh": (n as MeshInstance3D).mesh, "xf": t})
	for c in n.get_children():
		_collect_parts(c, t, out)


func _mesh_parts(model: String) -> Array:
	if parts_cache.has(model):
		return parts_cache[model]
	var inst := _make_model(model)
	var out: Array = []
	_collect_parts(inst, Transform3D.IDENTITY, out)
	inst.free()
	parts_cache[model] = out
	return out


func _flush_batches(batches: Dictionary) -> void:
	for model in batches:
		var xfs: Array = batches[model]
		for part in _mesh_parts(model):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part["mesh"]
			mm.instance_count = xfs.size()
			var pxf: Transform3D = part["xf"]
			for k in xfs.size():
				mm.set_instance_transform(k, (xfs[k] as Transform3D) * pxf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mmi)


func _item(model: String, pos: Vector3, yaw: float, s: float, pts_override: int = 0, special: String = "", ysc: float = 1.0, col: Color = Color(0, 0, 0, 0)) -> Item:
	var it := Item.new()
	it.add_child(_make_model(model, col))
	it.position = pos
	it.rotation.y = yaw
	var sc := Vector3(s, s * ysc, s)
	it.scale = sc
	it.base_yaw = yaw
	it.base_scale = sc
	it.kind = model
	it.special = special
	var bb := _bb(model)
	it.size = maxf(bb.size.x, bb.size.z) * s
	it.height = bb.size.y * s * ysc
	it.pts = maxi(2, int(round(it.size * it.size * (it.height + 0.3) * 4.0)))
	it.mass = it.size * it.size * (0.5 + 0.5 * it.height)
	if pts_override > 0:
		it.pts = pts_override
	it.big = it.height > 1.6 and it.size > 1.2
	it.is_vehicle = model.begins_with("car_") or VEH_KINDS.has(model)
	world.add_child(it)
	items.append(it)
	_grid_add(it)
	return it


## Place a model so that its longest side equals `longest` world units.
func _item_t(model: String, pos: Vector3, yaw: float, longest: float, pts_override: int = 0, special: String = "", col: Color = Color(0, 0, 0, 0)) -> Item:
	var bb := _bb(model)
	var s := longest / maxf(maxf(bb.size.x, bb.size.y), bb.size.z)
	return _item(model, pos, yaw, s, pts_override, special, 1.0, col)


func _put(model: String, pos: Vector3, longest: float, pts: int = 0, special: String = "") -> Item:
	return _item_t(model, pos, rng.randf() * TAU, longest, pts, special)


func _small(pos: Vector3) -> void:
	var r: Array = SMALLS.pick_random()
	_put(str(r[0]), pos, float(r[1]))


func _grid_key(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL), floori(z / CELL))


func _grid_add(it: Item) -> void:
	var k := _grid_key(it.position.x, it.position.z)
	it.cell = k
	if not grid.has(k):
		grid[k] = []
	(grid[k] as Array).append(it)


func _grid_remove(it: Item) -> void:
	if grid.has(it.cell):
		(grid[it.cell] as Array).erase(it)


func _grid_move(it: Item) -> void:
	var k := _grid_key(it.position.x, it.position.z)
	if k != it.cell:
		_grid_remove(it)
		it.cell = k
		if not grid.has(k):
			grid[k] = []
		(grid[k] as Array).append(it)


func _build_city(async_build: bool = false) -> void:
	tile_batches.clear()
	sky_batches.clear()
	grid.clear()
	movers.clear()
	lanes.clear()
	target_veh = 0
	target_walk = 0
	_build_island()
	var n_done := 0
	for i in N:
		for j in N:
			var p := _tile_pos(i, j)
			var vroad := i % 3 == 0
			var hroad := j % 3 == 0
			if vroad and hroad:
				_batch(tile_batches, "road_junction", p, 0.0)
				junctions.append(p)
				road_points.append(p)
				_junction_props(p)
			elif vroad:
				_batch(tile_batches, "road_straight", p, ROAD_YAW + PI * 0.5)
				road_points.append(p)
				_road_props(p, true)
			elif hroad:
				_batch(tile_batches, "road_straight", p, ROAD_YAW)
				road_points.append(p)
				_road_props(p, false)
			else:
				_batch(tile_batches, "base", p, 0.0)
			n_done += 1
			if async_build and n_done % 12 == 0:
				await get_tree().process_frame   # keep the intro animation smooth while building
	var nb := (N - 1) / 3
	for bi in nb:
		for bj in nb:
			var bp := Vector3((float(3 * bi + 1) + 0.5 - float(N - 1) * 0.5) * TILE, 0.0, (float(3 * bj + 1) + 0.5 - float(N - 1) * 0.5) * TILE)
			block_points.append(bp)
			_build_block(bp, bi, bj, nb)
			if async_build and (bi * nb + bj) % 2 == 0:
				await get_tree().process_frame
	_spawn_traffic()
	_spawn_sidewalkers()
	_flush_batches(tile_batches)
	_flush_batches(sky_batches)


## Decorative city ring around the playable area (not swallowable) so the
## camera never looks at an empty void.
func _build_island() -> void:
	var idx := theme_idx
	# sea
	var sea := MeshInstance3D.new()
	var spm := PlaneMesh.new()
	spm.size = Vector2(500, 500)
	var sh := Shader.new()
	sh.code = SEA_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var dim: float = [1.0, 1.0, 0.3, 1.1][idx]
	sm.set_shader_parameter("deep", Vector3(0.08, 0.42, 0.72) * dim)
	sm.set_shader_parameter("shallow", Vector3(0.3, 0.8, 0.9) * dim)
	sm.set_shader_parameter("edge", HALF + 1.0)
	sea.mesh = spm
	sea.material_override = sm
	sea.position.y = -0.2
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(sea)
	# sand + land
	var sand_cols: Array[Color] = [Color(0.93, 0.84, 0.6), Color(0.9, 0.75, 0.5), Color(0.35, 0.33, 0.42), Color(0.98, 0.98, 1.0)]
	var sand := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(HALF * 2.0 + 4.6, HALF * 2.0 + 4.6)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = sand_cols[idx]
	sand.mesh = sp
	sand.material_override = smat
	sand.position.y = -0.08
	world.add_child(sand)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 2.0 + 2.0, HALF * 2.0 + 2.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = THEMES[idx]["ground"]
	ground.mesh = pm
	ground.material_override = gm
	ground.position.y = -0.03
	world.add_child(ground)
	# shared glow materials for street lamps
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.92, 0.65)
	lamp_halo_mat = StandardMaterial3D.new()
	lamp_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lamp_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lamp_halo_mat.albedo_color = Color(1.0, 0.85, 0.45, 0.35 if idx != 2 else 0.7)
	lamp_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var gt := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	lamp_halo_mat.albedo_texture = gt
	lamp_pool_mat = StandardMaterial3D.new()
	lamp_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lamp_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lamp_pool_mat.albedo_color = Color(1.0, 0.85, 0.5, 0.22 if idx != 2 else 0.55)
	lamp_pool_mat.albedo_texture = gt


func _lamp_glow(it: Item, head: Vector3) -> void:
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	halo.mesh = q
	halo.material_override = lamp_halo_mat
	halo.position = head
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	it.add_child(halo)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 8
	sm.rings = 4
	bulb.mesh = sm
	bulb.material_override = lamp_mat
	bulb.position = head
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	it.add_child(bulb)
	var pool := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(1.7, 1.7)
	pool.mesh = pq
	pool.material_override = lamp_pool_mat
	pool.rotation.x = -PI * 0.5
	pool.position = Vector3(head.x, 0.02, 0.0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	it.add_child(pool)


func _build_skyline() -> void:
	var tall: Array[String] = ["building_A", "building_B", "building_C", "building_D",
		"building_E", "building_F", "building_G", "building_H"]
	var pad := 6
	for i in range(-pad, N + pad):
		for j in range(-pad, N + pad):
			if i >= 0 and i < N and j >= 0 and j < N:
				continue
			if rng.randf() < 0.35:
				continue
			var ring := maxi(maxi(-i, i - (N - 1)), maxi(-j, j - (N - 1)))
			# low buildings next to the map (never block the view), towers further out
			var sy := rng.randf_range(0.6, 0.95) if ring <= 2 else rng.randf_range(1.3, 3.2)
			_batch(sky_batches, tall.pick_random(), _tile_pos(i, j), rng.randi_range(0, 3) * PI * 0.5, Vector3(1.0, sy, 1.0))


func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


func _junction_props(p: Vector3) -> void:
	var corners: Array[Vector3] = [Vector3(0.9, 0.1, 0.9), Vector3(-0.9, 0.1, -0.9), Vector3(-0.9, 0.1, 0.9), Vector3(0.9, 0.1, -0.9)]
	for k in 4:
		_item_t("@signal_%d" % (1 if k < 2 else 0), p + corners[k], 0.0, 1.15)


func _road_props(p: Vector3, along_z: bool) -> void:
	if rng.randf() < 0.5:
		var side := 0.93 if rng.randf() < 0.5 else -0.93
		var off2 := Vector3(side, 0.1, rng.randf_range(-0.6, 0.6)) if along_z else Vector3(rng.randf_range(-0.6, 0.6), 0.1, side)
		var yaw2 := (0.0 if side < 0.0 else PI) + (PI * 0.5 if along_z else 0.0)
		var lamp := _item_t("streetlight", p + off2, yaw2, 1.5)
		_lamp_glow(lamp, Vector3(-0.13, 0.93, 0.0))


func _block_content(p: Vector3) -> void:
	pass


# ---------- city blocks (4x4 world units each) ----------
func _wpick(opts: Array) -> String:
	var total := 0
	for k in range(1, opts.size(), 2):
		total += int(opts[k])
	var roll := rng.randi_range(0, total - 1)
	for k in range(0, opts.size(), 2):
		roll -= int(opts[k + 1])
		if roll < 0:
			return str(opts[k])
	return str(opts[0])


func _slots(p: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for a in 4:
		for b in 4:
			out.append(p + Vector3(-1.5 + float(a) + rng.randf_range(-0.2, 0.2), 0.1, -1.5 + float(b) + rng.randf_range(-0.2, 0.2)))
	out.shuffle()
	return out


func _people(p: Vector3, n: int) -> void:
	var k := n if not mobile_low else maxi(1, n * 6 / 10)
	for i in k:
		_spawn_person(p)


func _build_block(p: Vector3, bi: int, bj: int, nb: int) -> void:
	var c := nb / 2
	var d := maxi(absi(bi - c), absi(bj - c))
	var kind := ""
	if d == 0:
		kind = "sky"
	elif d == 1:
		kind = _wpick(["sky", 55, "mega", 35, "plaza", 10])
	elif d == 2:
		kind = _wpick(["mega", 34, "houses", 40, "market", 8, "park", 6, "plaza", 4, "build", 4, "sky", 4])
	else:
		kind = _wpick(["houses", 46, "industry", 16, "build", 12, "market", 10, "park", 8, "mega", 8])
	match kind:
		"sky":
			_blk_mega(p, true)
		"mega":
			_blk_mega(p, false)
		"houses":
			_blk_houses(p)
		"park":
			_blk_park(p, false)
		"plaza":
			_blk_park(p, true)
		"market":
			_blk_market(p)
		"build":
			_blk_build(p)
		"industry":
			_blk_industry(p)
	if rng.randf() < 0.16:
		_put("Gold_Bars_Stack_Large", p + Vector3(rng.randf_range(-1.6, 1.6), 0.1, rng.randf_range(-1.6, 1.6)), 0.75, 90, "gold")


func _blk_mega(p: Vector3, tall: bool) -> void:
	var m: String = (SKY_MODELS if tall else MEGA_MODELS).pick_random()
	var s := rng.randf_range(1.5, 1.75)
	var ysc := rng.randf_range(1.0, 1.3)
	if tall:
		ysc = clampf(rng.randf_range(4.0, 5.4) / (_bb(m).size.y * s), 0.8, 2.4)
	_item(m, p, float(rng.randi_range(0, 1)) * PI, s, 0, "", ysc)
	for k in 5:
		var z := 1.7 if k % 2 == 0 else -1.7
		_small(p + Vector3(rng.randf_range(-1.6, 1.6), 0.1, z))
	_people(p, 2)


func _blk_houses(p: Vector3) -> void:
	var offs: Array[Vector3] = [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]
	for o in offs:
		if rng.randf() < 0.95:
			_item(HOUSES.pick_random(), p + o, rng.randi_range(0, 3) * PI * 0.5, rng.randf_range(0.82, 1.0))
		else:
			for k in 3:
				_small(p + o + Vector3(rng.randf_range(-0.6, 0.6), 0.1, rng.randf_range(-0.6, 0.6)))
	for k in 4:
		var a := rng.randf_range(-1.8, 1.8)
		var b := rng.randf_range(-0.12, 0.12)
		_small(p + (Vector3(a, 0.1, b) if k % 2 == 0 else Vector3(b, 0.1, a)))
	_people(p, 3)


func _blk_park(p: Vector3, plaza: bool) -> void:
	var sl := _slots(p)
	var fount := plaza or rng.randf() < 0.4
	if fount:
		_item_t("@fountain", p + Vector3(0, 0.1, 0), 0.0, 1.9 if plaza else 1.3, 140 if plaza else 60)
	var n_tree := 4 if plaza else rng.randi_range(6, 9)
	var used := 0
	for pos in sl:
		if fount and Vector2(pos.x - p.x, pos.z - p.z).length() < 1.1:
			continue
		if used < n_tree:
			_put("@tree", pos, rng.randf_range(0.95, 1.55))
		elif used < n_tree + 3:
			_put("bush", pos, 0.5)
		elif used < n_tree + 5:
			_put("bench", pos, 0.85)
		elif used < n_tree + 7:
			_put("lamp_standing", pos, 1.4)
		used += 1
	_people(p, 9 if plaza else 6)


func _blk_market(p: Vector3) -> void:
	var sl := _slots(p)
	var picks: Array = [["table_small", 0.6], ["table_small", 0.6], ["table_small", 0.6], ["couch", 1.3],
		["armchair", 0.75], ["armchair", 0.75], ["cactus_medium_A", 0.55], ["cactus_small_A", 0.4],
		["lamp_standing", 1.4], ["lamp_standing", 1.4], ["cabinet_small", 0.6], ["shelf_A_small", 0.6],
		["bed_single_A", 1.3], ["table_low", 0.9], ["@crate", 0.4], ["@barrel", 0.36]]
	var k := 0
	for pk in picks:
		var pos: Vector3 = sl[k]
		_put(str(pk[0]), pos, float(pk[1]))
		if str(pk[0]) == "table_small":
			for s in 2:
				_put("chair_A" if s == 0 else "chair_stool", pos + Vector3(0.42 if s == 0 else -0.42, 0, 0), 0.5)
		k += 1
	_people(p, 6)


func _blk_build(p: Vector3) -> void:
	_item(HOUSES.pick_random(), p + Vector3(-1, 0, -1), 0.0, 0.9)
	var sl := _slots(p)
	var n := rng.randi_range(13, 17)
	for k in n:
		var r: Array = TOOLS.pick_random()
		_put(str(r[0]), sl[k % sl.size()], float(r[1]))
	if rng.randf() < 0.7:
		_item_t(["@truck", "@garbage", "@tanker"].pick_random(), p + Vector3(1.0, 0.1, 1.5), PI * 0.5, 2.1)
	_people(p, 2)


func _blk_industry(p: Vector3) -> void:
	var sl := _slots(p)
	var n := rng.randi_range(8, 11)
	for k in n:
		var r: Array = STOCK.pick_random()
		_put(str(r[0]), sl[k], float(r[1]))
	if rng.randf() < 0.3:
		_put("watertower", sl[n], 1.4)
	if rng.randf() < 0.7:
		_item_t(["@truck", "@tanker", "@bus"].pick_random(), p + Vector3(-1.0, 0.1, 1.6), PI * 0.5, 2.1)
	_people(p, 2)


# ---------- living traffic and pedestrians ----------
func _pick_vehicle() -> Array:
	var total := 0
	for row in VEH_TABLE:
		total += int(row[1])
	var roll := rng.randi_range(0, total - 1)
	for row in VEH_TABLE:
		roll -= int(row[1])
		if roll < 0:
			return row
	return VEH_TABLE[0]


func _spawn_traffic() -> void:
	road_coords.clear()
	var per_lane := 3 if mobile_low else 4
	var span := (HALF + 0.3) * 2.0
	for k in range(0, N, 3):
		var c := (float(k) - float(N - 1) * 0.5) * TILE
		road_coords.append(c)
		for axis in 2:
			for side in [-1.0, 1.0]:
				var ln := {"cars": [], "axis": axis, "c": c, "off": 0.5 * float(side),
					"dir": float(side) if axis == 0 else -float(side), "spd": rng.randf_range(1.1, 2.3)}
				lanes.append(ln)
				for j in per_lane:
					var along := -(HALF + 0.3) + (float(j) + rng.randf_range(0.0, 0.35)) * span / float(per_lane)
					_spawn_vehicle(ln, along)
	target_veh = movers.size()


func _spawn_vehicle(ln: Dictionary, along: float) -> void:
	var row := _pick_vehicle()
	var model: String = row[0]
	var col := Color(0, 0, 0, 0)
	if model == "@truck" or model == "@bus":
		col = TRUCK_COLS.pick_random()
	var axis: int = ln["axis"]
	var dir: float = ln["dir"]
	var lane := float(ln["c"]) + float(ln["off"])
	var pos := Vector3(along, 0.1, lane) if axis == 0 else Vector3(lane, 0.1, along)
	var yaw := PI * 0.5 * dir if axis == 0 else (0.0 if dir > 0.0 else PI)
	var bb := _bb(model)
	var longest := float(row[2])
	var s := longest / maxf(maxf(bb.size.x, bb.size.y), bb.size.z)
	pos.y = 0.1 - bb.position.y * s
	var it := _item(model, pos, yaw, s, 0, "", 1.0, col)
	it.mover = 1
	it.axis = axis
	it.dir = dir
	it.spd = ln["spd"]
	it.cur = it.spd
	it.lane = ln
	(ln["cars"] as Array).append(it)
	movers.append(it)


func _spawn_person(home_c: Vector3, half: float = 2.0) -> void:
	var pos := home_c + Vector3(rng.randf_range(-half, half), 0.1, rng.randf_range(-half, half))
	_make_person(pos, Rect2(home_c.x - half - 0.2, home_c.z - half - 0.2, (half + 0.2) * 2.0, (half + 0.2) * 2.0), -1)


func _spawn_sidewalkers() -> void:
	var per := 2 if mobile_low else 3
	for k in range(0, N, 3):
		var c := (float(k) - float(N - 1) * 0.5) * TILE
		for axis in 2:
			for side in [-1.0, 1.0]:
				for j in per:
					var along := rng.randf_range(-HALF + 1.5, HALF - 1.5)
					var off := c + 0.9 * float(side)
					var pos := Vector3(along, 0.1, off) if axis == 0 else Vector3(off, 0.1, along)
					var rect := Rect2(-HALF, off - 0.08, HALF * 2.0, 0.16) if axis == 0 else Rect2(off - 0.08, -HALF, 0.16, HALF * 2.0)
					_make_person(pos, rect, axis)


func _make_person(pos: Vector3, rect: Rect2, lock: int) -> void:
	var it := _item("@person", pos, rng.randf() * TAU, 1.1, 3, "")
	it.mover = 2
	it.lock = lock
	it.home = rect
	it.spd = rng.randf_range(0.3, 0.55)
	it.heading = Vector2.from_angle(rng.randf() * TAU)
	if lock >= 0:
		it.heading = Vector2(1.0 if rng.randf() < 0.5 else -1.0, 0.0) if lock == 0 else Vector2(0.0, 1.0 if rng.randf() < 0.5 else -1.0)
	it.turn_t = rng.randf_range(0.5, 3.5)
	it.phase = rng.randf() * TAU
	it.body = it.get_child(0) as Node3D
	movers.append(it)
	target_walk += 1


func _gis(n: Node, out: Array) -> void:
	if n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		_gis(c, out)


func _set_fade(it: Variant, v: float) -> void:
	if not is_instance_valid(it):
		return
	if not it.has_meta("gis"):
		var arr: Array = []
		_gis(it, arr)
		it.set_meta("gis", arr)
	for g in it.get_meta("gis"):
		(g as GeometryInstance3D).transparency = v


## Buildings between the camera and the player turn see-through so the hole is never hidden.
func _update_occlusion(delta: float) -> void:
	occ_t -= delta
	if occ_t > 0.0:
		return
	occ_t = 0.1
	for fi in faded:
		if is_instance_valid(fi):
			_set_fade(fi, 0.0)
	faded.clear()
	var pp := player.position
	var c0 := _grid_key(pp.x - 9.0, pp.z - 3.0)
	var c1 := _grid_key(pp.x + 9.0, pp.z + 12.0)
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for it: Item in grid.get(Vector2i(cx, cz), []):
				if not it.big:
					continue
				var dz := it.position.z - pp.z
				var dx := absf(it.position.x - pp.x)
				if dz > -it.size * 0.45 and dz < it.height * 0.55 + it.size * 0.5 + player.r + 0.6 and dx < it.size * 0.5 + player.r + 0.8:
					_set_fade(it, 0.72)
					faded.append(it)


## 0 red, 1 yellow, 2 green. 14 s cycle with an all-red gap so crossing traffic never meets.
func _light(axis: int) -> int:
	var t := sig_t
	if axis == 1:
		if t < 5.0:
			return 2
		return 1 if t < 6.0 else 0
	if t < 7.0:
		return 0
	if t < 12.0:
		return 2
	return 1 if t < 13.0 else 0


func _update_movers(delta: float) -> void:
	sig_t = fmod(sig_t + delta, 14.0)
	for a in 2:
		var st := _light(a)
		if sig_last[a] != st:
			sig_last[a] = st
			Vehicles.set_signal(a, st)
	var lim := HALF + 0.4
	for it in movers:
		if it.falling:
			continue
		if it.mover == 1:
			var pc0 := it.position.x if it.axis == 0 else it.position.z
			var target := it.spd
			var front := pc0 + it.dir * it.size * 0.5
			var light := _light(it.axis)
			if light != 2:
				for cj in road_coords:
					var dsl := (cj - it.dir * 1.15 - front) * it.dir   # distance to the stop line ahead
					if dsl > -0.05 and dsl < 1.8:
						if light == 1 and dsl < 0.5:
							continue
						target = minf(target, it.spd * clampf(dsl / 1.4, 0.0, 1.0))
			for o: Item in it.lane["cars"]:
				if o == it or o.falling:
					continue
				var po: float = o.position.x if it.axis == 0 else o.position.z
				var dl := (po - pc0) * it.dir
				if dl <= 0.0 or dl > 4.0:
					continue
				var gap: float = dl - (it.size + o.size) * 0.5
				target = minf(target, it.spd * clampf((gap - 0.2) / 1.0, 0.0, 1.0))
			it.cur = move_toward(it.cur, target, (9.0 if target < it.cur else 3.0) * delta)
			var mv := it.dir * it.cur * delta
			if it.axis == 0:
				it.position.x += mv
				if it.position.x > lim:
					it.position.x = -lim
				elif it.position.x < -lim:
					it.position.x = lim
			else:
				it.position.z += mv
				if it.position.z > lim:
					it.position.z = -lim
				elif it.position.z < -lim:
					it.position.z = lim
			var pc := it.position.x if it.axis == 0 else it.position.z
			var f := clampf((lim - absf(pc)) / 1.6, 0.05, 1.0)
			if not it.leaning:
				it.scale = it.base_scale * f
			_grid_move(it)
		else:
			it.flee_t -= delta
			if it.flee_t <= 0.0:
				it.flee_t = 0.18
				var fl := Vector2.ZERO
				for h in holes:
					var dx := it.position.x - h.position.x
					var dz := it.position.z - h.position.z
					var rr := h.r * 2.0 + 0.7
					var d2 := dx * dx + dz * dz
					if d2 < rr * rr:
						fl += Vector2(dx, dz) / maxf(sqrt(d2), 0.01)
				if fl != Vector2.ZERO:
					it.heading = fl.normalized()
					if it.lock == 0:
						it.heading = Vector2(signf(fl.x) if fl.x != 0.0 else 1.0, 0.0)
					elif it.lock == 1:
						it.heading = Vector2(0.0, signf(fl.y) if fl.y != 0.0 else 1.0)
					it.turn_t = 0.6
					it.running = true
				else:
					it.running = false
			it.turn_t -= delta
			if it.turn_t <= 0.0:
				it.turn_t = rng.randf_range(1.5, 4.0)
				if it.lock == 0:
					it.heading = Vector2(1.0 if rng.randf() < 0.5 else -1.0, 0.0)
				elif it.lock == 1:
					it.heading = Vector2(0.0, 1.0 if rng.randf() < 0.5 else -1.0)
				else:
					it.heading = Vector2.from_angle(rng.randf() * TAU)
			var running := it.running
			var sp := it.spd * (4.0 if running else 1.0)
			var nx := it.position.x + it.heading.x * sp * delta
			var nz := it.position.z + it.heading.y * sp * delta
			if nx < it.home.position.x or nx > it.home.end.x:
				it.heading.x = -it.heading.x
				nx = clampf(nx, it.home.position.x, it.home.end.x)
			if nz < it.home.position.y or nz > it.home.end.y:
				it.heading.y = -it.heading.y
				nz = clampf(nz, it.home.position.y, it.home.end.y)
			it.position.x = nx
			it.position.z = nz
			it.rotation.y = atan2(it.heading.x, it.heading.y)
			var ph := it.phase + clock * (14.0 if running else 6.0)
			if it.body != null:
				it.body.position.y = absf(sin(ph)) * 0.025
				it.body.rotation.z = sin(ph) * 0.12
			_grid_move(it)


# =====================================================================
# Input
# =====================================================================
func _input(e: InputEvent) -> void:
	if state != "playing" and state != "countdown":
		return
	if get_tree().paused:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and not joy_active:
			if ui.get_pause_rect().has_point(t.position):
				return
			joy_active = true
			joy_touch = t.index
			joy_origin = t.position
			joy_vec = Vector2.ZERO
		elif not t.pressed and t.index == joy_touch:
			joy_active = false
			joy_vec = Vector2.ZERO
		ui.set_joystick(joy_active, joy_origin, joy_origin + joy_vec * JOY_R)
	elif e is InputEventScreenDrag and joy_active:
		var d := e as InputEventScreenDrag
		if d.index != joy_touch:
			return
		var v := d.position - joy_origin
		if v.length() > JOY_R:
			joy_origin = d.position - v.normalized() * JOY_R
			v = d.position - joy_origin
		joy_vec = (v / JOY_R).limit_length(1.0)
		ui.set_joystick(true, joy_origin, joy_origin + joy_vec * JOY_R)


func _input_vector() -> Vector2:
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		k.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		k.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		k.y += 1.0
	var v := joy_vec
	if k != Vector2.ZERO:
		v = k.normalized()
	return v


# =====================================================================
# Main loop
# =====================================================================
func _process(delta: float) -> void:
	clock += delta
	if log_fps:
		fps_acc += delta
		fps_frames += 1
		if fps_acc >= 1.0:
			var f := FileAccess.open("user://fps.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://fps.txt") else FileAccess.WRITE)
			f.seek_end()
			f.store_line("%s t=%.0f fps=%d items=%d" % [state, clock, fps_frames, items.size()])
			f.close()
			fps_acc = 0.0
			fps_frames = 0
	if building or player == null:
		return
	match state:
		"countdown":
			_tick_countdown(delta)
		"playing":
			time_left -= delta
			elapsed += delta
			_tick_clock()
			if time_left <= 0.0:
				time_left = 0.0
				_finish_round()
	if mode == "royale" and state == "playing":
		var grace := 12.0
		var k := clampf((elapsed - grace) / (round_total - grace), 0.0, 1.0)
		zone_half = lerpf(HALF - 0.3, 6.0, k)
		_update_zone_walls()
	for h in holes:
		if state == "countdown":
			h.move_dir = Vector2.ZERO
		elif h.is_player and state == "playing":
			h.move_dir = _input_vector()
		else:
			_bot_think(h, delta)
			h.target_r = minf(h.target_r, h.max_r)
		h.tick(delta, zone_half)
	_update_movers(delta)
	if state != "countdown":
		_eat_items(delta)
		_eat_holes()
	_update_falling(delta)
	_update_orbs(delta)
	_replenish(delta)
	_update_camera(delta)
	_update_occlusion(delta)
	if state == "playing" or state == "countdown":
		_update_hud(delta)
		_update_music()
	if state == "playing":
		_update_tutorial(delta)


func _tick_countdown(delta: float) -> void:
	countdown_t -= delta
	var sec := int(ceil(countdown_t))
	if sec != last_count:
		last_count = sec
		if sec > 0:
			ui.show_count(str(sec))
			sfx.play("tick", 1.0 + float(3 - sec) * 0.12)
		else:
			ui.show_count("GO!")
			sfx.play("go")
	if countdown_t <= 0.0:
		state = "playing"
		fov_kick = 5.0


func _tick_clock() -> void:
	var s := int(ceil(time_left))
	if s <= 10 and s != last_tick and s > 0:
		last_tick = s
		sfx.play("tick", 1.4 if s <= 3 else 1.0, 2.0)
		if s == 10:
			ui.toast("FINAL 10 SECONDS!", Color(1, 0.4, 0.3))


func _update_music() -> void:
	var inten := clampf(float(player.combo) / 12.0, 0.0, 1.0)
	inten = maxf(inten, clampf(elapsed / round_total, 0.0, 1.0) * 0.6)
	music.intensity = inten
	music.hype = time_left <= 15.0 or player.combo >= 12


# ---------- swallowing ----------
func _eat_items(delta: float) -> void:
	for h in holes:
		var hp := h.position
		var r := h.r
		var mag: bool = h.effects["magnet"] > 0.0
		var pull_r := r * (3.4 if mag else 1.5)
		var eat_r := r * 0.75
		var eat_r2 := eat_r * eat_r
		var pull_r2 := pull_r * pull_r
		var lean_r := r * 1.05
		var lean_r2 := lean_r * lean_r
		var pull_spd := (3.2 if mag else 1.3) * delta
		var c0 := _grid_key(hp.x - pull_r, hp.z - pull_r)
		var c1 := _grid_key(hp.x + pull_r, hp.z + pull_r)
		for cx in range(c0.x, c1.x + 1):
			for cz in range(c0.y, c1.y + 1):
				var cell_arr: Array = grid.get(Vector2i(cx, cz), [])
				var i := cell_arr.size() - 1
				while i >= 0:
					var it: Item = cell_arr[i]
					i -= 1
					if it.size * 0.4 > r:
						continue
					var dx := it.position.x - hp.x
					var dz := it.position.z - hp.z
					var d2 := dx * dx + dz * dz
					if d2 < eat_r2:
						cell_arr.erase(it)
						items.erase(it)
						_start_fall(it, h)
						continue
					if d2 < pull_r2 and not it.big:
						var d := sqrt(d2)
						var mv := minf(pull_spd, d)
						it.position.x -= dx / d * mv
						it.position.z -= dz / d * mv
						var nk := _grid_key(it.position.x, it.position.z)
						if nk != it.cell:
							cell_arr.erase(it)
							it.cell = nk
							if not grid.has(nk):
								grid[nk] = []
							(grid[nk] as Array).append(it)
					if it.mover == 2:
						continue
					if d2 < lean_r2:
						var dd := sqrt(d2)
						var tl := clampf(1.0 - (dd - eat_r) / maxf(lean_r - eat_r, 0.001), 0.0, 1.0)
						var u := Vector3(-dx, 0.0, -dz) / maxf(dd, 0.001)
						var axis := Vector3.UP.cross(u)
						if axis.length() > 0.001:
							it.basis = Basis(axis.normalized(), tl * 0.6) * Basis(Vector3.UP, it.base_yaw) * Basis.from_scale(it.base_scale)
							it.leaning = true
					elif it.leaning:
						it.basis = Basis(Vector3.UP, it.base_yaw) * Basis.from_scale(it.base_scale)
						it.leaning = false


func _start_fall(it: Item, h: Hole) -> void:
	it.falling = true
	it.fall_t = 0.0
	it.fall_dur = 0.55 + clampf(it.height * 0.2, 0.0, 0.9)
	if it.mover != 0:
		movers.erase(it)
		if it.lane.has("cars"):
			(it.lane["cars"] as Array).erase(it)
		it.mover = 0
		it.rotation.z = 0.0
		if it.body != null:
			it.body.rotation.z = 0.0
	it.fall_from = it.position
	it.fall_scale = it.scale
	it.fall_to = h
	falling.append(it)
	var mult := 1
	var growth := 1.0
	h.pulse = 1.0
	if h.is_player:
		h.combo += 1
		h.combo_t = 1.7
		mult = 1 + mini(h.combo / 6, 4)
		growth = 1.0 + 0.08 * float(profile.upg["growth"])
	h.score += it.pts * mult
	h.add_mass(it.mass * 7.0, growth)
	var col := h.color if h.is_player else h.color.lightened(0.2)
	if it.special == "gold":
		col = Color(1.0, 0.85, 0.2)
	fx.burst(Vector3(h.position.x, 0.25, h.position.z), col, clampf(0.7 + float(it.pts) / 14.0, 0.7, 2.2))
	if not h.is_player or state != "playing":
		return
	# --- player feedback ---
	profile.progress("eat", 1)
	if it.is_vehicle:
		profile.progress("cars", 1)
	elif it.kind.begins_with("building_"):
		profile.progress("build", 1)
	if mult > last_mult:
		profile.progress("combo", mult, true)
		sfx.play("combo")
		fx.popup(h.position, "COMBO x%d!" % mult, Color(1, 0.6, 0.15), 1.3)
		trauma = maxf(trauma, 0.25)
	last_mult = mult
	if h.combo == 0:
		last_mult = 1
	if it.special == "gold":
		sfx.play("gold")
		fx.popup(it.position, "GOLD +%d" % (it.pts * mult), Color(1, 0.9, 0.2), 1.4)
		fx.ring(Vector3(h.position.x, 0.14, h.position.z), h.r, Color(1, 0.85, 0.2))
		trauma = maxf(trauma, 0.3)
	elif it.pts >= 40:
		sfx.play("thud")
		fx.popup(it.position, "+%d" % (it.pts * mult), Color(1, 0.9, 0.3), 1.5)
		fx.ring(Vector3(h.position.x, 0.14, h.position.z), h.r, h.color)
		trauma = maxf(trauma, 0.55)
		fov_kick = 4.0
		_vibrate(40)
		if it.big:
			trauma = maxf(trauma, 0.95)
			fov_kick = 7.0
			fx.burst(Vector3(it.position.x, 0.3, it.position.z), Color(0.85, 0.8, 0.7), 2.4)
			fx.ring(Vector3(it.position.x, 0.14, it.position.z), maxf(h.r, it.size * 0.6), Color(1, 0.8, 0.4))
			fx.popup(it.position + Vector3(0, minf(it.height, 3.0) * 0.6, 0), "BUILDING +%d" % (it.pts * mult), Color(1, 0.55, 0.2), 1.9)
			sfx.play("thud", 0.6, 0.0)
			_vibrate(70)
	elif it.pts >= 8:
		sfx.play("thud", 1.2, -4.0)
		sfx.pop(h.combo)
		fx.popup(it.position, "+%d" % (it.pts * mult), Color(1, 0.9, 0.3), 1.0)
		trauma = maxf(trauma, 0.15)
		_vibrate(20)
	else:
		sfx.pop(h.combo)


func _vibrate(ms: int) -> void:
	if profile.vib_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _update_falling(delta: float) -> void:
	var i := falling.size() - 1
	while i >= 0:
		var it := falling[i]
		it.fall_t += delta / it.fall_dur
		var t := minf(it.fall_t, 1.0)
		var tgt := it.position
		if is_instance_valid(it.fall_to):
			tgt = Vector3(it.fall_to.position.x, -1.5 - it.height, it.fall_to.position.z)
		it.position = it.fall_from.lerp(tgt, t * t)
		it.scale = it.fall_scale * (1.0 - 0.85 * t)
		if it.big:
			it.rotation.z = sin(clock * 38.0) * 0.05 * (1.0 - t)   # rumble as it collapses
		else:
			it.rotation.y += delta * 3.0
		if it.fall_t >= 1.0:
			it.queue_free()
			falling[i] = falling.back()
			falling.pop_back()
		i -= 1


func _eat_holes() -> void:
	for a in holes.duplicate():
		for b in holes.duplicate():
			if a == b or b.invuln > 0.0 or a.invuln > 0.0:
				continue
			if not holes.has(a) or not holes.has(b):
				continue
			if a.r > b.r * 1.25:
				var d := Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length()
				if d < a.r * 0.6:
					_hole_eaten(a, b)
					if state == "result":
						return


func _hole_eaten(a: Hole, b: Hole) -> void:
	var taken := int(b.score * 0.25) + 40
	if not a.is_player:
		taken = int(taken * 0.4)
	a.score += taken
	a.add_mass(minf(float(taken) * 0.6, 120.0), 1.0)
	a.pulse = 1.0
	fx.burst(Vector3(b.position.x, 0.3, b.position.z), b.color, 2.4)
	fx.ring(Vector3(b.position.x, 0.14, b.position.z), b.r, b.color)
	if a.is_player:
		profile.progress("holes", 1)
		sfx.play("eat_hole")
		trauma = maxf(trauma, 0.5)
		fx.popup(b.position, "+%d" % taken, Color(0.5, 1, 0.5), 1.5)
		ui.toast("You ate %s!" % b.hname, Color(0.5, 1, 0.5))
		_vibrate(50)
	if b.is_player:
		sfx.play("eaten")
		trauma = maxf(trauma, 0.9)
		ui.toast("Eaten by %s!" % a.hname, Color(1, 0.4, 0.35))
		_vibrate(80)
	if mode == "royale":
		if b.is_player:
			if not revive_used:
				_offer_revive()
				return
			player_out = true
			_finish_round()
			return
		holes.erase(b)
		b.queue_free()
		ui.toast("%s eliminated! %d left" % [b.hname, holes.size()], Color(1, 0.8, 0.4))
		if holes.size() <= 1:
			_finish_round()
		return
	b.score = int(b.score * 0.75)
	b.target_r = maxf(0.3, b.target_r * 0.62)
	b.r = b.target_r
	b.combo = 0
	b.invuln = 2.5
	var spot: Vector3 = junctions.pick_random()
	b.position = Vector3(spot.x, 0.115, spot.z)
	b.ai_target = null
	b.ai_chase = null


# ---------- bot brain ----------
func _bot_think(h: Hole, delta: float) -> void:
	h.ai_timer -= delta
	if h.ai_timer <= 0.0:
		h.ai_timer = rng.randf_range(0.3, 0.6)
		h.ai_flee = Vector2.ZERO
		h.ai_chase = null
		for o in holes:
			if o == h:
				continue
			var d := h.position.distance_to(o.position)
			if o.r > h.r * 1.25 and d < 1.5 + o.r * 2.6:
				h.ai_flee += Vector2(h.position.x - o.position.x, h.position.z - o.position.z).normalized()
			elif h.r > o.r * 1.3 and d < 4.5 and rng.randf() < h.aggr * h.skill:
				h.ai_chase = o
		h.ai_target = _pick_target(h)
		if h.ai_target == null or rng.randf() < 0.05:
			h.ai_wander = Vector2.from_angle(rng.randf() * TAU)
	var dir := Vector2.ZERO
	if h.ai_flee != Vector2.ZERO:
		dir = h.ai_flee.normalized()
	elif is_instance_valid(h.ai_chase) and holes.has(h.ai_chase):
		dir = Vector2(h.ai_chase.position.x - h.position.x, h.ai_chase.position.z - h.position.z).normalized()
	elif is_instance_valid(h.ai_target) and not h.ai_target.falling:
		dir = Vector2(h.ai_target.position.x - h.position.x, h.ai_target.position.z - h.position.z).normalized()
	else:
		dir = h.ai_wander
	var edge := zone_half - 0.8
	if absf(h.position.x) > edge and signf(dir.x) == signf(h.position.x):
		dir.x = -dir.x
		h.ai_wander.x = dir.x
	if absf(h.position.z) > edge and signf(dir.y) == signf(h.position.z):
		dir.y = -dir.y
		h.ai_wander.y = dir.y
	h.move_dir = dir * (0.85 + 0.15 * h.skill)


func _pick_target(h: Hole) -> Item:
	var best: Item = null
	var best_score := -1.0
	for it in items:
		if it.size * 0.4 > h.r:
			continue
		if absf(it.position.x) > zone_half or absf(it.position.z) > zone_half:
			continue
		var dx := it.position.x - h.position.x
		var dz := it.position.z - h.position.z
		var d := sqrt(dx * dx + dz * dz)
		var sc := (1.0 + sqrt(float(it.pts))) / (d + 0.4)
		if sc > best_score:
			best_score = sc
			best = it
	return best


# ---------- keep the city stocked ----------
func _replenish(delta: float) -> void:
	if state != "playing":
		return
	restock_timer -= delta
	if restock_timer > 0.0:
		return
	restock_timer = 1.0
	var nv := 0
	var nw := 0
	for m in movers:
		if m.mover == 1:
			nv += 1
		else:
			nw += 1
	if nv < target_veh * 7 / 10 and not lanes.is_empty():
		var ln: Dictionary = lanes.pick_random()
		_spawn_vehicle(ln, -float(ln["dir"]) * (HALF + 0.3))
	if nw < target_walk * 6 / 10:
		var bp: Vector3 = block_points.pick_random()
		for k in 3:
			_spawn_person(bp)
	if items.size() > start_item_count * 6 / 10:
		return
	for k in 4:
		var p: Vector3 = block_points.pick_random()
		_small(p + Vector3(rng.randf_range(-1.8, 1.8), 0.1, rng.randf_range(-1.8, 1.8)))


# ---------- power-ups ----------
func _update_orbs(delta: float) -> void:
	if state == "playing":
		orb_timer -= delta
		if orb_timer <= 0.0 and orbs.size() < 3:
			orb_timer = 8.0
			_spawn_orb()
	var i := orbs.size() - 1
	while i >= 0:
		var o := orbs[i]
		o.position.y = 0.5 + sin(clock * 3.0 + float(i)) * 0.08
		o.rotation.y += delta * 2.0
		for h in holes:
			var d := Vector2(o.position.x - h.position.x, o.position.z - h.position.z).length()
			if d < h.r + 0.22:
				_apply_orb(h, str(o.get_meta("otype")))
				fx.burst(o.position, ORB_TYPES[str(o.get_meta("otype"))], 1.4)
				o.queue_free()
				orbs[i] = orbs.back()
				orbs.pop_back()
				break
		i -= 1


func _spawn_orb() -> void:
	var kinds: Array = ORB_TYPES.keys()
	var kind: String = kinds.pick_random()
	var col: Color = ORB_TYPES[kind]
	var o := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	mi.mesh = sm
	mi.material_override = mat
	o.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.34
	ring.mesh = tm
	ring.material_override = mat
	ring.rotation.x = 0.6
	o.add_child(ring)
	var lbl := Label3D.new()
	lbl.text = kind.to_upper()
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = true
	lbl.pixel_size = 0.0009
	lbl.position = Vector3(0, 0.5, 0)
	lbl.modulate = col.lightened(0.4)
	o.add_child(lbl)
	var p: Vector3 = road_points.pick_random()
	if absf(p.x) > zone_half or absf(p.z) > zone_half:
		p = Vector3(0, 0, 0)
	o.position = Vector3(p.x, 0.5, p.z)
	o.set_meta("otype", kind)
	world.add_child(o)
	orbs.append(o)


func _apply_orb(h: Hole, kind: String) -> void:
	match kind:
		"speed":
			h.effects["speed"] = 5.0
		"magnet":
			h.effects["magnet"] = 6.0
		"grow":
			h.add_mass(45.0, 1.0)
		"time":
			if state == "playing":
				time_left += 8.0
	h.pulse = 1.0
	if h.is_player:
		profile.progress("orbs", 1)
		sfx.play("power")
		var names := {"speed": "SPEED BOOST!", "magnet": "MAGNET!", "grow": "GROW!", "time": "+8 SECONDS!"}
		ui.toast(str(names[kind]), ORB_TYPES[kind])
		_vibrate(30)


# ---------- tutorial ----------
func _update_tutorial(delta: float) -> void:
	if profile.tutorial_done or mode != "classic" or profile.level != 1:
		return
	tut_timer += delta
	match tut_stage:
		0:
			ui.set_hint("Drag your finger to move the hole")
			if player.score > 0:
				tut_stage = 1
				tut_timer = 0.0
		1:
			ui.set_hint("Swallow things smaller than you to GROW!")
			if player.score >= 12 or tut_timer > 12.0:
				tut_stage = 2
				tut_timer = 0.0
		2:
			ui.set_hint("Bigger hole = bigger things. Try the cars!")
			if tut_timer > 8.0:
				tut_stage = 3
				tut_timer = 0.0
		3:
			ui.set_hint("Watch out: BIGGER holes can eat you!")
			if tut_timer > 6.0:
				tut_stage = 4
				ui.set_hint("")


# ---------- camera / HUD ----------
func _update_camera(delta: float) -> void:
	var tgt := player.position
	# keep the camera over the playfield so edge skyline never blocks the view
	var lim := HALF - 3.0
	tgt.x = clampf(tgt.x, -lim, lim)
	tgt.z = clampf(tgt.z, -lim, lim)
	cam_focus = cam_focus.lerp(tgt, 1.0 - exp(-6.0 * delta))
	var want := 3.3 + player.r * 5.4
	if state == "menu" or state == "result":
		want = 4.6 + player.r * 6.5
		want *= 1.25
	if state == "countdown":
		want *= 1.0 + 0.9 * clampf(countdown_t / 3.0, 0.0, 1.0)
	cam_dist = lerpf(cam_dist, want, 1.0 - exp(-3.0 * delta))
	trauma = maxf(0.0, trauma - delta * 1.6)
	var sh := trauma * trauma
	var shake := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * sh * 0.35
	cam.position = cam_focus + Vector3(0, cam_dist * 0.9, cam_dist * 0.44) + shake
	# look slightly ahead of the hole so it sits in the lower half of tall phone screens
	cam.look_at(cam_focus + Vector3(0, 0, -cam_dist * 0.18), Vector3.UP)
	fov_kick = lerpf(fov_kick, 0.0, 1.0 - exp(-6.0 * delta))
	cam.fov = 52.0 + fov_kick


func _update_hud(delta: float) -> void:
	var mm_dots: Array = []
	for h in holes:
		mm_dots.append([h.position.x, h.position.z, h.r, h.color, h.is_player])
	ui.update_minimap(mm_dots, zone_half if mode == "royale" else HALF)
	var powers := ""
	if player.effects["speed"] > 0.0:
		powers += "SPEED %.0fs   " % player.effects["speed"]
	if player.effects["magnet"] > 0.0:
		powers += "MAGNET %.0fs" % player.effects["magnet"]
	var board: Array = []
	var sorted: Array = holes.duplicate()
	sorted.sort_custom(func(a: Hole, b: Hole) -> bool: return a.score > b.score)
	for h in sorted:
		board.append([h.hname, h.score, h.is_player])
	# danger vignette when a bigger hole is closing in
	var danger := 0.0
	for o in holes:
		if o == player or o.r <= player.r * 1.25:
			continue
		var reach := 1.5 + o.r * 2.6
		var dd := player.position.distance_to(o.position)
		if dd < reach:
			danger = maxf(danger, 1.0 - dd / reach)
	ui.set_danger(danger, clock)
	if danger > 0.6 and state == "playing" and clock - last_danger > 5.0:
		last_danger = clock
		ui.toast("DANGER! Run!", Color(1, 0.35, 0.3))
		sfx.play("error")
		_vibrate(30)
	var sub := "Level %d" % profile.level
	if mode == "royale":
		sub = "ROYALE  %d alive" % holes.size()
	elif is_boss:
		sub = "BOSS LEVEL %d" % profile.level
	ui.update_hud(player.score, time_left, sub, player.combo, 1 + mini(player.combo / 6, 4), board, powers.strip_edges(), clock)
