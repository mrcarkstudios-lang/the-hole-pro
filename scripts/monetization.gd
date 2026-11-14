class_name Monetization
extends CanvasLayer
## Ads + store service layer.
##
## ADS: real Google AdMob (Poing Studios plugin) on Android, with UMP consent.
##   - debug builds use Google's TEST ad units (never click real ads while developing)
##   - release builds use the real ad units below
##   - on PC / when the plugin is unavailable, a labelled "TEST AD" screen is used in debug builds
## STORE: Google Play Billing (official Godot plugin) in RELEASE builds on Android.
##   - debug build (test_mode): purchases are granted for free so every flow can be tested
##   - release build: real Play purchases only; if billing is unavailable nothing is granted

signal purchase_done(id: String, ok: bool)
signal ad_unavailable

const PRODUCTS := {
	"starter": {"name": "Starter Pack", "price": "$1.99", "desc": "1000 coins + Lava skin + free boost. One time only!"},
	"remove_ads": {"name": "Remove Ads", "price": "$2.99", "desc": "No more between-round ads (rewarded ads stay optional)"},
	"vip": {"name": "VIP Membership", "price": "$4.99 / month", "desc": "No ads, 2x coins, free boost + free revive every round"},
	"pass_premium": {"name": "Pro Pass - Premium", "price": "$4.99", "desc": "Unlock the premium reward lane + exclusive Pro Gold skin"},
	"coins_s": {"name": "500 Coins", "price": "$0.99", "desc": "", "coins": 500},
	"coins_m": {"name": "3,000 Coins", "price": "$4.99", "desc": "Best seller", "coins": 3000},
	"coins_l": {"name": "8,000 Coins", "price": "$9.99", "desc": "Best value", "coins": 8000},
}

# Real AdMob ids (account owner's). Debug builds use Google's TEST units instead.
const ADMOB_APP_ID := "ca-app-pub-6221264275692660~7510857064"
const AD_REWARDED := "ca-app-pub-6221264275692660/3676212970"
const AD_INTERSTITIAL := "ca-app-pub-6221264275692660/9905920261"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"

var profile: Profile
var test_mode: bool = OS.is_debug_build()
var ads_real: bool = false        # true once AdMob initialised on Android
var billing_real: bool = false    # true once connected to Google Play Billing (release builds)

const VIP_BASE_PLAN := "monthly"   # base plan id of the "vip" subscription in Play Console
const INAPP_IDS := ["remove_ads", "pass_premium", "starter", "coins_s", "coins_m", "coins_l"]
const CONSUMABLES := ["coins_s", "coins_m", "coins_l"]

var _billing: BillingClient
var _details_done: int = 0
var _query_stage: int = 0
var _pending_buy: Dictionary = {}
var overlay: Control = null

var _rewarded: RewardedAd = null
var _interstitial: InterstitialAd = null
var _rewarded_loader := RewardedAdLoader.new()
var _interstitial_loader := InterstitialAdLoader.new()
var _rewarded_loading := false
var _interstitial_loading := false


## Tiny on-device log (user://ads_log.txt) so ad problems can be diagnosed without a debugger.
func _log(msg: String) -> void:
	print("[Ads] ", msg)
	var path := "user://ads_log.txt"
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line("%d  %s" % [int(Time.get_unix_time_from_system()), msg])
		f.close()


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android":
		_log("start: requesting consent (test units=%s)" % test_mode)
		_request_consent()
		if not test_mode:
			_init_billing()


# ---------- AdMob init (UMP consent -> SDK init) ----------
func _request_consent() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		params,
		func() -> void:
			var ci := UserMessagingPlatform.consent_information
			_log("consent info ok, status=%d form_available=%s" % [ci.get_consent_status(), ci.get_is_consent_form_available()])
			if ci.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED 					and ci.get_is_consent_form_available():
				_show_consent_form()
			else:
				_init_ads(),
		func(e: FormError) -> void:
			_log("consent info update failed: " + str(e.message if e else ""))
			_init_ads())


func _show_consent_form() -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			form.show(func(_e: FormError) -> void: _init_ads()),
		func(_e: FormError) -> void:
			_init_ads())


func _init_ads() -> void:
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_status: InitializationStatus) -> void:
		ads_real = true
		_log("AdMob initialised")
		_load_rewarded()
		_load_interstitial()
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(on_init)


func _rewarded_id() -> String:
	return TEST_REWARDED if test_mode else AD_REWARDED


func _interstitial_id() -> String:
	return TEST_INTERSTITIAL if test_mode else AD_INTERSTITIAL


func _load_rewarded() -> void:
	if not ads_real or _rewarded_loading or _rewarded != null:
		return
	_rewarded_loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded_loading = false
		_rewarded = ad
		_log("rewarded loaded")
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		_rewarded_loading = false
		_log("rewarded FAILED to load: %s (code %s)" % [e.message, str(e.code)])
		get_tree().create_timer(30.0, true).timeout.connect(_load_rewarded)
	_rewarded_loader.load(_rewarded_id(), AdRequest.new(), cb)


func _load_interstitial() -> void:
	if not ads_real or _interstitial_loading or _interstitial != null:
		return
	_interstitial_loading = true
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_loading = false
		_interstitial = ad
		_log("interstitial loaded")
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		_interstitial_loading = false
		_log("interstitial FAILED to load: %s (code %s)" % [e.message, str(e.code)])
		get_tree().create_timer(30.0, true).timeout.connect(_load_interstitial)
	_interstitial_loader.load(_interstitial_id(), AdRequest.new(), cb)


# ---------- policy ----------
func ads_enabled() -> bool:
	return not (profile.no_ads or profile.vip)


## Show the watch-an-ad buttons? (real SDK on Android, or the test overlay on PC debug builds)
func rewarded_available() -> bool:
	if OS.get_name() == "Android":
		return ads_real
	return test_mode


func can_show_interstitial() -> bool:
	if not ads_enabled():
		return false
	if OS.get_name() == "Android":
		if not ads_real or _interstitial == null:
			return false
	elif not test_mode:
		return false
	if profile.rounds < 3 or profile.rounds_since_ad < 3:
		return false
	return int(Time.get_unix_time_from_system()) - profile.last_ad_unix >= 90


func store_available() -> bool:
	return billing_real or test_mode


# ---------- ads ----------
## cb(ok: bool) - ok == true only if the player earned the reward.
func show_rewarded(placement: String, cb: Callable) -> void:
	if OS.get_name() == "Android":
		_real_show_rewarded(placement, cb)
	elif test_mode:
		_test_overlay("TEST AD", 3.0, true, cb)
	else:
		cb.call(false)


func show_interstitial(cb: Callable) -> void:
	if OS.get_name() == "Android":
		_real_show_interstitial(cb)
	elif test_mode:
		_test_overlay("TEST AD", 2.0, false, func(_ok: bool): cb.call())
	else:
		cb.call()


func _real_show_rewarded(_placement: String, cb: Callable) -> void:
	if not ads_real or _rewarded == null:
		_load_rewarded()
		ad_unavailable.emit()
		cb.call(false)
		return
	var ad := _rewarded
	_rewarded = null
	var earned := [false]
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_rewarded()
		cb.call(earned[0])
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		_load_rewarded()
		cb.call(false)
	ad.full_screen_content_callback = fs
	var rl := OnUserEarnedRewardListener.new()
	rl.on_user_earned_reward = func(_item: RewardedItem) -> void:
		earned[0] = true
	ad.show(rl)


func _real_show_interstitial(cb: Callable) -> void:
	if not ads_real or _interstitial == null:
		_load_interstitial()
		cb.call()
		return
	var ad := _interstitial
	_interstitial = null
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_interstitial()
		cb.call()
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		ad.destroy()
		_load_interstitial()
		cb.call()
	ad.full_screen_content_callback = fs
	ad.show()


func _test_overlay(title: String, seconds: float, skippable: bool, cb: Callable) -> void:
	if overlay != null:
		# an ad is already showing: never drop the callback silently
		cb.call(false)
		return
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.1, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	cc.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 90)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.25))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := Label.new()
	sub.text = "(debug build - a real ad would play here)"
	sub.add_theme_font_size_override("font_size", 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var cd := Label.new()
	cd.add_theme_font_size_override("font_size", 56)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cd)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(420, 90)
	btn.add_theme_font_size_override("font_size", 40)
	btn.text = "CLAIM REWARD" if skippable else "CLOSE"
	btn.visible = false
	vb.add_child(btn)
	var skip := Button.new()
	skip.custom_minimum_size = Vector2(300, 64)
	skip.add_theme_font_size_override("font_size", 28)
	skip.text = "Skip (no reward)"
	skip.visible = skippable
	vb.add_child(skip)

	var state := {"left": seconds, "done": false}
	var finish := func(ok: bool) -> void:
		if state["done"]:
			return
		state["done"] = true
		if overlay != null:
			overlay.queue_free()
			overlay = null
		cb.call(ok)
	btn.pressed.connect(func(): finish.call(true))
	skip.pressed.connect(func(): finish.call(false))
	var tm := Timer.new()
	tm.wait_time = 0.1
	tm.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(tm)
	tm.timeout.connect(func():
		state["left"] = float(state["left"]) - 0.1
		if float(state["left"]) > 0.0:
			cd.text = "Reward in %.0f..." % ceil(float(state["left"]))
		else:
			cd.text = "Done!"
			btn.visible = true
			skip.visible = false
			tm.stop())
	tm.start()
	cd.text = "Reward in %.0f..." % ceil(seconds)


# ---------- store ----------
## cb(ok: bool)
func buy(id: String, cb: Callable) -> void:
	if not PRODUCTS.has(id):
		cb.call(false)
		return
	if billing_real:
		_real_buy(id, cb)
	elif test_mode:
		_apply_purchase(id)
		purchase_done.emit(id, true)
		cb.call(true)
	else:
		cb.call(false)


# ---------- real Google Play Billing ----------
func _init_billing() -> void:
	_billing = BillingClient.new()
	add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.disconnected.connect(func() -> void:
		billing_real = false
		_log("billing disconnected"))
	_billing.connect_error.connect(func(code: int, msg: String) -> void:
		_log("billing connect error %d: %s" % [code, msg]))
	_billing.query_product_details_response.connect(func(r: Dictionary) -> void:
		_details_done += 1
		_log("product details: code=%s count=%d" % [str(r.get("response_code")), (r.get("product_details", []) as Array).size()]))
	_billing.query_purchases_response.connect(_on_purchases_queried)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.consume_purchase_response.connect(func(r: Dictionary) -> void:
		_log("consume: " + str(r.get("response_code"))))
	_billing.acknowledge_purchase_response.connect(func(r: Dictionary) -> void:
		_log("acknowledge: " + str(r.get("response_code"))))
	_billing.start_connection()


func _on_billing_connected() -> void:
	billing_real = true
	_log("billing connected")
	_billing.query_product_details(PackedStringArray(INAPP_IDS), BillingClient.ProductType.INAPP)
	_billing.query_product_details(PackedStringArray(["vip"]), BillingClient.ProductType.SUBS)
	_query_stage = 0
	_billing.query_purchases(BillingClient.ProductType.INAPP)   # restore purchases


func _on_purchases_queried(r: Dictionary) -> void:
	if int(r.get("response_code", -99)) != BillingClient.BillingResponseCode.OK:
		_log("query purchases failed: " + str(r.get("debug_message", "")))
		return
	var vip_found := false
	for p in (r.get("purchases", []) as Array):
		_process_purchase(p)
		if (p.get("product_ids", PackedStringArray()) as PackedStringArray).has("vip") \
				and int(p.get("purchase_state", 0)) == BillingClient.PurchaseState.PURCHASED:
			vip_found = true
	if _query_stage == 0:
		_query_stage = 1
		_billing.query_purchases(BillingClient.ProductType.SUBS)
	else:
		# subscription result: VIP only while the subscription is active
		if profile.vip != vip_found:
			profile.vip = vip_found
			profile.save_all()
			_log("vip active = %s" % vip_found)


## Grants the purchase once, then acknowledges (one-time / sub) or consumes (coin packs).
func _process_purchase(p: Dictionary) -> bool:
	if int(p.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
		return false
	var token := str(p.get("purchase_token", ""))
	var ids: PackedStringArray = p.get("product_ids", PackedStringArray())
	for id in ids:
		if CONSUMABLES.has(id):
			if not profile.granted_tokens.has(token):
				_apply_purchase(id)
				profile.granted_tokens.append(token)
				while profile.granted_tokens.size() > 80:
					profile.granted_tokens.pop_front()
				profile.save_all()
			_billing.consume_purchase(token)
		else:
			_apply_purchase(id)
			if not bool(p.get("is_acknowledged", false)):
				_billing.acknowledge_purchase(token)
	return true


func _on_purchase_updated(r: Dictionary) -> void:
	var ok_ids: Array = []
	if int(r.get("response_code", -99)) == BillingClient.BillingResponseCode.OK:
		for p in (r.get("purchases", []) as Array):
			if _process_purchase(p):
				for id in (p.get("product_ids", PackedStringArray()) as PackedStringArray):
					ok_ids.append(id)
	for id in _pending_buy.keys():
		var cb: Callable = _pending_buy[id]
		var ok := ok_ids.has(id)
		purchase_done.emit(id, ok)
		cb.call(ok)
	_pending_buy.clear()


func _real_buy(id: String, cb: Callable) -> void:
	if _billing == null or _details_done < 2 or _pending_buy.has(id):
		cb.call(false)
		return
	_pending_buy[id] = cb
	var r: Dictionary
	if id == "vip":
		r = _billing.purchase_subscription("vip", VIP_BASE_PLAN)
	else:
		r = _billing.purchase(id)
	if int(r.get("response_code", 0)) != BillingClient.BillingResponseCode.OK:
		_log("purchase launch failed: " + str(r))
		_pending_buy.erase(id)
		cb.call(false)


func _apply_purchase(id: String) -> void:
	match id:
		"remove_ads":
			profile.no_ads = true
		"vip":
			profile.vip = true          # ads are off while VIP is active (see ads_enabled)
		"pass_premium":
			profile.pass_premium = true
		"starter":
			if profile.starter_bought:
				return
			profile.starter_bought = true
			profile.coins += 1000
			if not profile.owned.has(3):
				profile.owned.append(3)
			profile.boost_ready = true
		_:
			var p: Dictionary = PRODUCTS[id]
			if p.has("coins"):
				profile.coins += int(p["coins"])
	profile.save_all()
