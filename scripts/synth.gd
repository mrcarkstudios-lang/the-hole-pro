class_name Synth
extends RefCounted
## Tiny additive synthesizer used for all sound effects and the adaptive music.
## Thread-safe (no engine singletons, own noise generator).

const KINDS := ["pluck", "tri", "pad", "bass", "kick", "snare", "hat", "saw", "sine", "noise", "slide"]


static func add_note(buf: PackedFloat32Array, rate: int, t0: float, dur: float, freq: float, vol: float, kind: String, freq_end: float = 0.0) -> void:
	var size := buf.size()
	if size == 0:
		return
	var i0 := int(t0 * float(rate))
	var n := int(dur * float(rate))
	var id := KINDS.find(kind)
	var inc := TAU * freq / float(rate)
	var ph := 0.0
	var prev := 0.0
	var rs := (int(t0 * 1000.0) * 7919 + int(freq) * 104729 + 12345) & 0x7fffffff
	var frate := float(rate)
	for k in n:
		var t := float(k) / frate
		var u := float(k) / float(n)
		var s := 0.0
		var atk := minf(1.0, t * 500.0)
		match id:
			0:  # pluck
				ph += inc
				s = (sin(ph) + 0.42 * sin(ph * 2.0) * exp(-t * 14.0) + 0.16 * sin(ph * 3.0) * exp(-t * 20.0)) * exp(-t * 6.0) * atk
			1:  # triangle
				ph += inc
				s = asin(sin(ph)) * 0.6366 * exp(-t * 4.0) * atk
			2:  # pad (slow attack / release)
				ph += inc
				s = (sin(ph) + 0.3 * sin(ph * 2.01)) * minf(1.0, t / 0.18) * minf(1.0, (dur - t) / 0.3) * 0.6
			3:  # bass
				ph += inc
				s = tanh(1.7 * sin(ph) + 0.55 * sin(ph * 2.0)) * exp(-t * 3.2) * atk * 0.8
			4:  # kick
				var f := 42.0 + 120.0 * exp(-t * 26.0)
				ph += TAU * f / frate
				s = sin(ph) * exp(-t * 9.5) * 1.1
			5:  # snare / clap
				rs = (rs * 1103515245 + 12345) & 0x7fffffff
				var nz := float(rs) / 1073741824.0 - 1.0
				ph += TAU * 188.0 / frate
				s = (nz * 0.8 + sin(ph) * 0.5) * exp(-t * 17.0)
			6:  # hat
				rs = (rs * 1103515245 + 12345) & 0x7fffffff
				var nz2 := float(rs) / 1073741824.0 - 1.0
				s = (nz2 - prev) * 0.7 * exp(-t * 55.0)
				prev = nz2
			7:  # saw (soft)
				ph += inc
				s = (fposmod(ph / TAU, 1.0) * 2.0 - 1.0) * exp(-t * 5.0) * atk * 0.5
			8:  # plain sine
				ph += inc
				s = sin(ph) * minf(1.0, (dur - t) / 0.05) * atk
			9:  # noise burst
				rs = (rs * 1103515245 + 12345) & 0x7fffffff
				s = (float(rs) / 1073741824.0 - 1.0) * exp(-t * 12.0)
			10:  # pitch slide
				var f2 := lerpf(freq, freq_end, u)
				ph += TAU * f2 / frate
				s = (sin(ph) + 0.3 * sin(ph * 2.0)) * (1.0 - u) * atk
		var idx := i0 + k
		if idx >= size:
			idx -= size
		buf[idx] += s * vol


static func to_pcm(buf: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var x := buf[i]
		x = x / (1.0 + absf(x) * 0.6)
		data.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 32000.0))
	return data


static func to_wav(buf: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = to_pcm(buf)
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w
