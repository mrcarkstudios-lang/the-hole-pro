class_name Sfx
extends Node
## Sound effects, all synthesised. Swallow "pops" are tuned to A-minor pentatonic
## so a combo plays a rising melody that matches the music key.

const RATE := 22050
const SEMIS := [0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24, 27]
const BAKED := "res://assets/audio/sfx_%s.res"
const NAMES := ["thud", "gold", "power", "eaten", "eat_hole", "win", "lose", "click", "coin",
	"tick", "go", "levelup", "combo", "error", "whoosh"]

var streams: Dictionary = {}
var pops: Array[AudioStreamWAV] = []
var players: Array[AudioStreamPlayer] = []
var idx: int = 0
var enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		players.append(p)
	if ResourceLoader.exists(BAKED % "thud"):
		_load_baked()
	else:
		_build()


func _load_baked() -> void:
	for n in NAMES:
		streams[n] = load(BAKED % n)
	for i in SEMIS.size():
		pops.append(load(BAKED % ("pop%d" % i)))


## Used by tools/render_audio.gd to write the baked resources.
func bake() -> void:
	_build()
	for n in NAMES:
		ResourceSaver.save(streams[n], BAKED % n)
	for i in pops.size():
		ResourceSaver.save(pops[i], BAKED % ("pop%d" % i))


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _w(b: PackedFloat32Array) -> AudioStreamWAV:
	return Synth.to_wav(b, RATE)


func _build() -> void:
	for s in SEMIS:
		var f := 220.0 * pow(2.0, float(s) / 12.0)
		var b := _buf(0.32)
		Synth.add_note(b, RATE, 0.0, 0.3, f, 0.5, "pluck")
		Synth.add_note(b, RATE, 0.0, 0.05, 1800.0, 0.08, "noise")
		pops.append(_w(b))

	var b2 := _buf(0.5)
	Synth.add_note(b2, RATE, 0.0, 0.45, 70.0, 0.9, "kick")
	Synth.add_note(b2, RATE, 0.0, 0.2, 400.0, 0.35, "noise")
	Synth.add_note(b2, RATE, 0.02, 0.4, 110.0, 0.4, "bass")
	streams["thud"] = _w(b2)

	var b3 := _buf(0.7)
	for i in 4:
		Synth.add_note(b3, RATE, float(i) * 0.06, 0.4, 880.0 * pow(2.0, float([0, 3, 7, 12][i]) / 12.0), 0.3, "pluck")
	Synth.add_note(b3, RATE, 0.0, 0.6, 1760.0, 0.1, "sine")
	streams["gold"] = _w(b3)

	var b4 := _buf(0.6)
	for i in 5:
		Synth.add_note(b4, RATE, float(i) * 0.055, 0.35, 440.0 * pow(2.0, float([0, 3, 7, 10, 15][i]) / 12.0), 0.32, "pluck")
	streams["power"] = _w(b4)

	var b5 := _buf(0.8)
	Synth.add_note(b5, RATE, 0.0, 0.7, 520.0, 0.5, "slide", 70.0)
	Synth.add_note(b5, RATE, 0.0, 0.35, 300.0, 0.3, "noise")
	streams["eaten"] = _w(b5)

	var b6 := _buf(0.6)
	Synth.add_note(b6, RATE, 0.0, 0.4, 90.0, 0.8, "kick")
	for i in 3:
		Synth.add_note(b6, RATE, 0.08 + float(i) * 0.07, 0.3, 330.0 * pow(2.0, float([0, 7, 12][i]) / 12.0), 0.3, "pluck")
	streams["eat_hole"] = _w(b6)

	var b7 := _buf(1.6)
	var fan := [0, 3, 7, 12, 15, 19]
	for i in fan.size():
		Synth.add_note(b7, RATE, float(i) * 0.1, 0.9, 440.0 * pow(2.0, float(fan[i]) / 12.0), 0.3, "pluck")
	for f2 in [440.0, 523.25, 659.25, 880.0]:
		Synth.add_note(b7, RATE, 0.6, 0.9, f2, 0.12, "pad")
	streams["win"] = _w(b7)

	var b8 := _buf(1.2)
	var dn := [7, 3, 0, -5]
	for i in dn.size():
		Synth.add_note(b8, RATE, float(i) * 0.18, 0.5, 440.0 * pow(2.0, float(dn[i]) / 12.0), 0.35, "tri")
	streams["lose"] = _w(b8)

	var b9 := _buf(0.08)
	Synth.add_note(b9, RATE, 0.0, 0.07, 1200.0, 0.3, "pluck")
	streams["click"] = _w(b9)

	var b10 := _buf(0.4)
	Synth.add_note(b10, RATE, 0.0, 0.2, 1318.0, 0.3, "pluck")
	Synth.add_note(b10, RATE, 0.07, 0.3, 1976.0, 0.3, "pluck")
	streams["coin"] = _w(b10)

	var b11 := _buf(0.2)
	Synth.add_note(b11, RATE, 0.0, 0.15, 520.0, 0.5, "sine")
	streams["tick"] = _w(b11)

	var b12 := _buf(0.9)
	for f3 in [440.0, 659.25, 880.0, 1318.5]:
		Synth.add_note(b12, RATE, 0.0, 0.7, f3, 0.2, "pluck")
	Synth.add_note(b12, RATE, 0.0, 0.3, 90.0, 0.7, "kick")
	streams["go"] = _w(b12)

	var b13 := _buf(0.9)
	var lv := [0, 4, 7, 12, 16, 19, 24]
	for i in lv.size():
		Synth.add_note(b13, RATE, float(i) * 0.07, 0.4, 392.0 * pow(2.0, float(lv[i]) / 12.0), 0.3, "pluck")
	streams["levelup"] = _w(b13)

	var b14 := _buf(0.5)
	for i in 4:
		Synth.add_note(b14, RATE, float(i) * 0.05, 0.3, 523.25 * pow(2.0, float([0, 4, 7, 12][i]) / 12.0), 0.3, "saw")
	streams["combo"] = _w(b14)

	var b15 := _buf(0.35)
	Synth.add_note(b15, RATE, 0.0, 0.25, 200.0, 0.4, "tri")
	Synth.add_note(b15, RATE, 0.1, 0.25, 150.0, 0.4, "tri")
	streams["error"] = _w(b15)

	var b16 := _buf(0.35)
	Synth.add_note(b16, RATE, 0.0, 0.3, 300.0, 0.3, "slide", 900.0)
	streams["whoosh"] = _w(b16)


func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or not streams.has(sound):
		return
	_play_stream(streams[sound], pitch, vol_db)


## Swallow sound: note climbs the pentatonic scale with the combo count.
func pop(combo: int) -> void:
	if not enabled:
		return
	var n := pops.size()
	var i := combo
	if i >= n:
		i = n - 1 - (combo % 2) * 2
	_play_stream(pops[clampi(i, 0, n - 1)], 1.0, -3.0)


func _play_stream(st: AudioStream, pitch: float, vol_db: float) -> void:
	var p := players[idx]
	idx = (idx + 1) % players.size()
	p.stream = st
	p.pitch_scale = pitch
	p.volume_db = -4.0 + vol_db
	p.play()
