class_name Profile
extends RefCounted
## Everything that is saved between sessions + the retention systems
## (daily reward streak, daily missions, skins, XP).

const PATH := "user://hole_rush.cfg"
const MAX_LVL := 10

const SKINS: Array[Dictionary] = [
	{"name": "Classic", "color": Color(1.0, 0.8, 0.1), "cost": 0},
	{"name": "Neon Pink", "color": Color(1.0, 0.2, 0.65), "cost": 250},
	{"name": "Ice", "color": Color(0.45, 0.85, 1.0), "cost": 450},
	{"name": "Lava", "color": Color(1.0, 0.35, 0.05), "cost": 700},
	{"name": "Toxic", "color": Color(0.55, 1.0, 0.1), "cost": 1000},
	{"name": "Royal", "color": Color(0.65, 0.35, 1.0), "cost": 1500},
	{"name": "Rainbow", "color": Color(1.0, 1.0, 1.0), "cost": 2500, "rainbow": true},
	{"name": "Pro Gold", "color": Color(1.0, 0.92, 0.45), "cost": -1, "exclusive": true},
]
const PASS_TIERS := 20
const PASS_XP_PER_TIER := 120
const DAILY: Array[int] = [50, 75, 100, 150, 200, 300, 500]
const MISSION_POOL: Array[Dictionary] = [
	{"id": "eat", "text": "Swallow %d objects", "min": 80, "max": 200, "reward": 60},
	{"id": "cars", "text": "Swallow %d cars", "min": 5, "max": 12, "reward": 70},
	{"id": "combo", "text": "Reach a x%d combo", "min": 3, "max": 5, "reward": 80},
	{"id": "holes", "text": "Eat %d rival holes", "min": 2, "max": 5, "reward": 90},
	{"id": "wins", "text": "Win %d rounds", "min": 1, "max": 2, "reward": 120},
	{"id": "play", "text": "Play %d rounds", "min": 3, "max": 5, "reward": 60},
	{"id": "orbs", "text": "Grab %d power-ups", "min": 3, "max": 6, "reward": 60},
	{"id": "build", "text": "Swallow %d buildings", "min": 4, "max": 10, "reward": 90},
]

var coins: int = 0
var level: int = 1            # campaign level
var xp: int = 0
var plevel: int = 1           # player (profile) level
var upg: Dictionary = {"speed": 0, "size": 0, "growth": 0, "time": 0}
var owned: Array = [0]
var skin: int = 0
var streak: int = 0
var claimed_day: int = -1
var mission_day: int = -1
var missions: Array = []
var best: int = 0
var rounds: int = 0
var wins: int = 0
var royale_wins: int = 0
var music_on: bool = true
var sfx_on: bool = true
var vib_on: bool = true
var tutorial_done: bool = false
# monetization state
var no_ads: bool = false
var vip: bool = false
var pass_premium: bool = false
var pass_xp: int = 0
var pass_free_claimed: Array = []
var pass_prem_claimed: Array = []
var first_time: int = 0
var starter_bought: bool = false
var rounds_since_ad: int = 0
var last_ad_unix: int = 0
var boost_ready: bool = false
var granted_tokens: Array = []   # Play purchase tokens already granted (no double rewards)


func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	coins = int(cf.get_value("g", "coins", 0))
	level = int(cf.get_value("g", "level", 1))
	xp = int(cf.get_value("g", "xp", 0))
	plevel = int(cf.get_value("g", "plevel", 1))
	owned = cf.get_value("g", "owned", [0])
	skin = int(cf.get_value("g", "skin", 0))
	streak = int(cf.get_value("g", "streak", 0))
	claimed_day = int(cf.get_value("g", "claimed_day", -1))
	mission_day = int(cf.get_value("g", "mission_day", -1))
	missions = cf.get_value("g", "missions", [])
	best = int(cf.get_value("g", "best", 0))
	rounds = int(cf.get_value("g", "rounds", 0))
	wins = int(cf.get_value("g", "wins", 0))
	royale_wins = int(cf.get_value("g", "royale_wins", 0))
	music_on = bool(cf.get_value("s", "music", true))
	sfx_on = bool(cf.get_value("s", "sfx", true))
	vib_on = bool(cf.get_value("s", "vib", true))
	tutorial_done = bool(cf.get_value("s", "tutorial", false))
	no_ads = bool(cf.get_value("m", "no_ads", false))
	vip = bool(cf.get_value("m", "vip", false))
	pass_premium = bool(cf.get_value("m", "pass_premium", false))
	pass_xp = int(cf.get_value("m", "pass_xp", 0))
	pass_free_claimed = cf.get_value("m", "pass_free", [])
	pass_prem_claimed = cf.get_value("m", "pass_prem", [])
	first_time = int(cf.get_value("m", "first_time", 0))
	starter_bought = bool(cf.get_value("m", "starter_bought", false))
	rounds_since_ad = int(cf.get_value("m", "rounds_since_ad", 0))
	last_ad_unix = int(cf.get_value("m", "last_ad", 0))
	boost_ready = bool(cf.get_value("m", "boost_ready", false))
	granted_tokens = cf.get_value("m", "granted_tokens", [])
	for k in upg.keys():
		upg[k] = int(cf.get_value("u", k, 0))


func save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "coins", coins)
	cf.set_value("g", "level", level)
	cf.set_value("g", "xp", xp)
	cf.set_value("g", "plevel", plevel)
	cf.set_value("g", "owned", owned)
	cf.set_value("g", "skin", skin)
	cf.set_value("g", "streak", streak)
	cf.set_value("g", "claimed_day", claimed_day)
	cf.set_value("g", "mission_day", mission_day)
	cf.set_value("g", "missions", missions)
	cf.set_value("g", "best", best)
	cf.set_value("g", "rounds", rounds)
	cf.set_value("g", "wins", wins)
	cf.set_value("g", "royale_wins", royale_wins)
	cf.set_value("s", "music", music_on)
	cf.set_value("s", "sfx", sfx_on)
	cf.set_value("s", "vib", vib_on)
	cf.set_value("s", "tutorial", tutorial_done)
	cf.set_value("m", "no_ads", no_ads)
	cf.set_value("m", "vip", vip)
	cf.set_value("m", "pass_premium", pass_premium)
	cf.set_value("m", "pass_xp", pass_xp)
	cf.set_value("m", "pass_free", pass_free_claimed)
	cf.set_value("m", "pass_prem", pass_prem_claimed)
	cf.set_value("m", "first_time", first_time)
	cf.set_value("m", "starter_bought", starter_bought)
	cf.set_value("m", "rounds_since_ad", rounds_since_ad)
	cf.set_value("m", "last_ad", last_ad_unix)
	cf.set_value("m", "boost_ready", boost_ready)
	cf.set_value("m", "granted_tokens", granted_tokens)
	for k in upg.keys():
		cf.set_value("u", k, upg[k])
	cf.save(PATH)


# ---------- upgrades ----------
func upgrade_cost(id: String) -> int:
	return int(40.0 * pow(1.6, float(upg[id])))


# ---------- XP ----------
func xp_needed() -> int:
	return 100 + 60 * (plevel - 1)


## Returns the number of levels gained (each gives 100 coins).
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		plevel += 1
		coins += 100
		gained += 1
	return gained


# ---------- daily reward ----------
func daily_status() -> Dictionary:
	var day := today()
	var s := streak
	if claimed_day != day - 1 and claimed_day != day:
		s = 0
	return {"available": claimed_day != day, "index": s % DAILY.size(), "reward": DAILY[s % DAILY.size()], "streak": s}


func claim_daily() -> int:
	var st := daily_status()
	if not st["available"]:
		return 0
	streak = int(st["streak"]) + 1
	claimed_day = today()
	var r: int = st["reward"]
	coins += r
	save_all()
	return r


# ---------- missions ----------
func roll_missions() -> void:
	if mission_day == today() and missions.size() == 3:
		return
	mission_day = today()
	missions = []
	var pool: Array = MISSION_POOL.duplicate()
	pool.shuffle()
	for i in 3:
		var d: Dictionary = pool[i]
		var target: int = randi_range(int(d["min"]), int(d["max"]))
		if str(d["id"]) == "eat":
			target = int(round(float(target) / 10.0)) * 10
		missions.append({
			"id": d["id"],
			"text": str(d["text"]) % target,
			"target": target,
			"prog": 0,
			"reward": int(d["reward"]),
			"claimed": false,
		})
	save_all()


func progress(id: String, amount: int = 1, as_max: bool = false) -> void:
	for m in missions:
		if m["id"] != id or m["claimed"]:
			continue
		if as_max:
			m["prog"] = maxi(int(m["prog"]), amount)
		else:
			m["prog"] = int(m["prog"]) + amount
		m["prog"] = mini(int(m["prog"]), int(m["target"]))


func claimable_count() -> int:
	var c := 0
	for m in missions:
		if not m["claimed"] and int(m["prog"]) >= int(m["target"]):
			c += 1
	return c


func claim_mission(i: int) -> int:
	if i < 0 or i >= missions.size():
		return 0
	var m: Dictionary = missions[i]
	if m["claimed"] or int(m["prog"]) < int(m["target"]):
		return 0
	m["claimed"] = true
	coins += int(m["reward"])
	save_all()
	return int(m["reward"])


# ---------- monetization helpers ----------
func ensure_first_time() -> void:
	if first_time == 0:
		first_time = int(Time.get_unix_time_from_system())
		save_all()


func coin_multiplier() -> int:
	return 2 if vip else 1


## One-time 48h offer for new players (appears after round 2).
func is_starter_available() -> bool:
	if starter_bought or rounds < 2 or first_time == 0:
		return false
	return int(Time.get_unix_time_from_system()) < first_time + 172800


func starter_seconds_left() -> int:
	return maxi(0, first_time + 172800 - int(Time.get_unix_time_from_system()))


func pass_tier() -> int:
	return mini(pass_xp / PASS_XP_PER_TIER, PASS_TIERS)


## tier is 1..PASS_TIERS. Returns {"coins": n} or {"skin": idx}.
func pass_reward(tier: int, premium: bool) -> Dictionary:
	if premium:
		if tier == PASS_TIERS:
			return {"skin": 7}
		if tier == 10:
			return {"skin": 5}
		return {"coins": 80 + 20 * tier}
	return {"coins": 30 + 10 * tier}


func pass_reward_text(r: Dictionary) -> String:
	if r.has("skin"):
		return "SKIN: " + str(SKINS[int(r["skin"])]["name"])
	return "+%d" % int(r["coins"])


func pass_is_claimed(tier: int, premium: bool) -> bool:
	return (pass_prem_claimed if premium else pass_free_claimed).has(tier)


func pass_can_claim(tier: int, premium: bool) -> bool:
	if tier > pass_tier() or pass_is_claimed(tier, premium):
		return false
	return pass_premium or not premium


func claim_pass(tier: int, premium: bool) -> bool:
	if not pass_can_claim(tier, premium):
		return false
	var r := pass_reward(tier, premium)
	if r.has("skin"):
		if not owned.has(int(r["skin"])):
			owned.append(int(r["skin"]))
	else:
		coins += int(r["coins"])
	(pass_prem_claimed if premium else pass_free_claimed).append(tier)
	save_all()
	return true
