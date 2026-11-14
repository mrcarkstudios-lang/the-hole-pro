class_name Music
extends Node
## Adaptive music: 5 synced loop layers (pad, bass, drums, lead, hype).
## Layers fade in/out with game state, combo and remaining time.
## Key: A minor (Am - F - C - G), 128 BPM.
## The layers are rendered once on the PC (tools/render_audio.gd) and shipped as
## resources; render() is only used as a fallback / by the bake tool.

const RATE := 44100
const BPM := 128.0
const LAYERS := ["pad", "bass", "drums", "lead", "hype"]
const BAKED := "res://assets/audio/music_%s.res"
const ROOTS := [110.0, 87.31, 130.81, 98.0]
const TRIADS := [
	[220.0, 261.63, 329.63],
	[174.61, 220.0, 261.63],
	[261.63, 329.63, 392.0],
	[196.0, 246.94, 293.66],
]

var players: Dictionary = {}
var started: bool = false

var mode: String = "menu"     # menu | play | result
var intensity: float = 0.0    # 0..1
var hype: bool = false
var enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var streams: Dictionary = {}
	for l in LAYERS:
		var path: String = BAKED % l
		if ResourceLoader.exists(path):
			streams[l] = load(path)
	if streams.size() < LAYERS.size():
		# fallback: synthesise at lower quality (slow on phones)
		var r := render(16000)
		for l in LAYERS:
			streams[l] = _make_stream(r["pcm"][l], 16000, int(r["n"]))
	for l in LAYERS:
		var p := AudioStreamPlayer.new()
		p.stream = streams[l]
		p.volume_db = -80.0
		add_child(p)
		players[l] = p
	for l in LAYERS:
		(players[l] as AudioStreamPlayer).play()
	started = true


static func _make_stream(pcm: PackedByteArray, rate: int, n: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	w.data = pcm
	return w


## Synthesises all layers. Returns {"n": samples, "pcm": {layer: PackedByteArray}}.
static func render(rate: int) -> Dictionary:
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var n := int(bar * 4.0 * float(rate))
	var bufs: Dictionary = {}
	for l in LAYERS:
		var b := PackedFloat32Array()
		b.resize(n)
		bufs[l] = b
	var drums: PackedFloat32Array = bufs["drums"]
	var bass: PackedFloat32Array = bufs["bass"]
	var pad: PackedFloat32Array = bufs["pad"]
	var lead: PackedFloat32Array = bufs["lead"]
	var hy: PackedFloat32Array = bufs["hype"]

	for b in 4:
		var bt := float(b) * bar
		var tri: Array = TRIADS[b]
		for k in 4:
			var t := bt + float(k) * beat
			Synth.add_note(drums, rate, t, 0.3, 50.0, 0.8, "kick")
			if k == 1 or k == 3:
				Synth.add_note(drums, rate, t, 0.22, 190.0, 0.35, "snare")
			Synth.add_note(drums, rate, t + beat * 0.5, 0.06, 8000.0, 0.16, "hat")
		var steps := [0, 2, 3, 4, 6, 7]
		for s in steps:
			var f: float = ROOTS[b]
			if s == 3 or s == 7:
				f *= 2.0
			Synth.add_note(bass, rate, bt + float(s) * beat * 0.5, beat * 0.45, f, 0.34, "bass")
		for f2 in tri:
			Synth.add_note(pad, rate, bt, bar, float(f2), 0.07, "pad")
		var pat := [0, 1, 2, 1, 0, 1, 2, 1, 2, 1, 0, 1, 2, 1, 0, 2]
		for s2 in 16:
			if s2 == 6 or s2 == 14:
				continue
			var f3: float = float(tri[pat[s2]]) * 2.0
			Synth.add_note(lead, rate, bt + float(s2) * beat * 0.25, beat * 0.55, f3, 0.15, "pluck")
		for k2 in 4:
			var f4: float = float(tri[(k2 + b) % 3]) * 4.0
			Synth.add_note(hy, rate, bt + (float(k2) + 0.5) * beat, beat * 0.4, f4, 0.1, "pluck")
		if b == 3:
			for s3 in 16:
				Synth.add_note(hy, rate, bt + float(s3) * beat * 0.25, 0.1, 190.0, 0.08 + 0.2 * float(s3) / 16.0, "snare")
	var out: Dictionary = {}
	for l in LAYERS:
		out[l] = Synth.to_pcm(bufs[l])
	return {"n": n, "pcm": out}


func _targets() -> Dictionary:
	var off := -80.0
	var t := {"pad": off, "bass": off, "drums": off, "lead": off, "hype": off}
	if not enabled:
		return t
	match mode:
		"menu":
			t["pad"] = -9.0
			t["lead"] = -14.0
			t["bass"] = -13.0
		"play":
			t["pad"] = -11.0
			t["bass"] = -8.0
			t["drums"] = -7.0 if intensity > 0.0 else -10.0
			t["lead"] = -11.0 + (1.0 - intensity) * -3.0 if intensity > 0.2 else off
			t["hype"] = -10.0 if (hype or intensity > 0.75) else off
		"result":
			t["pad"] = -9.0
			t["lead"] = -12.0
	return t


func _process(delta: float) -> void:
	if not started:
		return
	var t := _targets()
	for l in LAYERS:
		var p: AudioStreamPlayer = players[l]
		p.volume_db = lerpf(p.volume_db, float(t[l]), 1.0 - exp(-3.0 * delta))
