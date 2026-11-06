extends AudioStreamPlayer
## Placeholder car sounds synthesized in code (no audio files). M toggles mute.
## v2 (after "the sound is weird" feedback): smoother, more engine-like.
## - Engine: sum of sine harmonics + sub-octave (no raw saw/square buzz), slight per-cycle
##   amplitude jitter (rumble), more upper harmonics under throttle, low-passed.
##   Pitch from a fake RPM with fake gears.
## - Tires: soft band-passed noise scrub (dirt/sand) + quiet, detuned squeal (road only).
## - Wind: low-passed noise, rises with speed.
## Real recorded samples should replace this later. Web: audio starts after the first input.

@export var mix_rate: float = 22050.0
@export_range(0.0, 1.0) var engine_volume: float = 0.3
@export_range(0.0, 1.0) var tire_volume: float = 0.18
@export_range(0.0, 1.0) var squeal_volume: float = 0.08
@export_range(0.0, 1.0) var wind_volume: float = 0.1
## Engine firing frequency at idle and at max RPM (Hz).
@export var engine_freq_low: float = 32.0
@export var engine_freq_high: float = 105.0
## Speed ratios (0..1 of top speed) where fake gears change.
@export var gear_points: PackedFloat32Array = PackedFloat32Array([0.0, 0.18, 0.36, 0.56, 0.78, 1.0])

var rpm: float = 0.0     ## 0..1, readable by debug
var gear: int = 1

var _car: CarController
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _phase_sub: float = 0.0
var _cycle_amp: float = 1.0
var _engine_freq: float = 32.0
var _engine_amp: float = 0.0
var _engine_bright: float = 0.0
var _tire_amp: float = 0.0
var _squeal_amp: float = 0.0
var _wind_amp: float = 0.0
var _lp_engine: float = 0.0
var _lp_tire_fast: float = 0.0
var _lp_tire_slow: float = 0.0
var _lp_wind: float = 0.0
var _squeal_phase_a: float = 0.0
var _squeal_phase_b: float = 0.0
var _squeal_wobble: float = 0.0


func _ready() -> void:
	_car = get_parent() as CarController
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = mix_rate
	generator.buffer_length = 0.1
	stream = generator
	volume_db = -6.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


func _process(delta: float) -> void:
	if _car == null or _playback == null:
		return
	_update_rpm(delta)
	_fill_buffer()


func _update_rpm(delta: float) -> void:
	var ratio := clampf(absf(_car.speed) / _car.top_speed, 0.0, 1.0)

	# Find the fake gear and how far through it we are.
	var local := 0.0
	gear = 1
	for i in range(1, gear_points.size()):
		if ratio <= gear_points[i] or i == gear_points.size() - 1:
			var lo := gear_points[i - 1]
			var hi := gear_points[i]
			local = clampf((ratio - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
			gear = i
			break

	var target_rpm := lerpf(0.35, 1.0, local)
	if ratio < 0.02:
		target_rpm = 0.15 + 0.5 * _car.throttle_input  # idle / revving in place
	if _car.burnout_amount > 0.0:
		target_rpm = maxf(target_rpm, 0.9)
	if _car.is_drifting and _car.throttle_input > 0.1:
		target_rpm = minf(target_rpm + 0.12, 1.0)
	if not _car.on_ground:
		target_rpm = minf(target_rpm + 0.1 * _car.throttle_input, 1.0)  # wheels free in the air
	rpm = lerpf(rpm, target_rpm, 1.0 - exp(-8.0 * delta))


func _fill_buffer() -> void:
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return

	var ratio := clampf(absf(_car.speed) / _car.top_speed, 0.0, 1.0)
	var squeal_mix: float = Surfaces.get_data(_car.current_surface)["squeal"]
	var target_freq := lerpf(engine_freq_low, engine_freq_high, rpm)
	var target_engine := engine_volume * (0.5 + 0.5 * _car.throttle_input)
	var target_bright := 0.3 + 0.7 * _car.throttle_input
	var target_tire := tire_volume * _car.tire_slip * (1.0 - 0.7 * squeal_mix)
	var target_squeal := squeal_volume * _car.tire_slip * squeal_mix
	var target_wind := wind_volume * ratio * ratio

	# Ramp parameters across the buffer to avoid clicks.
	var inv := 1.0 / float(frames)
	var freq_step := (target_freq - _engine_freq) * inv
	var engine_step := (target_engine - _engine_amp) * inv
	var bright_step := (target_bright - _engine_bright) * inv
	var tire_step := (target_tire - _tire_amp) * inv
	var squeal_step := (target_squeal - _squeal_amp) * inv
	var wind_step := (target_wind - _wind_amp) * inv

	for i in frames:
		_engine_freq += freq_step
		_engine_amp += engine_step
		_engine_bright += bright_step
		_tire_amp += tire_step
		_squeal_amp += squeal_step
		_wind_amp += wind_step

		# --- Engine: harmonics of the firing frequency + a sub-octave rumble ---
		_phase += _engine_freq / mix_rate
		if _phase >= 1.0:
			_phase -= 1.0
			_cycle_amp = randf_range(0.82, 1.0)  # each "firing" slightly different
		_phase_sub += _engine_freq * 0.5 / mix_rate
		if _phase_sub >= 1.0:
			_phase_sub -= 1.0
		var a := TAU * _phase
		var engine_raw := sin(a) * 0.55 + sin(2.0 * a) * 0.28 + sin(3.0 * a) * 0.14 * _engine_bright
		engine_raw += sin(4.0 * a) * 0.07 * _engine_bright + sin(TAU * _phase_sub) * 0.35
		engine_raw *= _cycle_amp
		_lp_engine += (engine_raw - _lp_engine) * 0.3

		# --- Tires ---
		var noise := randf() * 2.0 - 1.0
		_lp_tire_fast += (noise - _lp_tire_fast) * 0.2
		_lp_tire_slow += (noise - _lp_tire_slow) * 0.03
		var scrub := _lp_tire_fast - _lp_tire_slow

		_squeal_wobble += 5.0 / mix_rate
		if _squeal_wobble >= 1.0:
			_squeal_wobble -= 1.0
		var wobble := sin(TAU * _squeal_wobble)
		_squeal_phase_a += (780.0 + 60.0 * wobble) / mix_rate
		if _squeal_phase_a >= 1.0:
			_squeal_phase_a -= 1.0
		_squeal_phase_b += (1015.0 + 45.0 * wobble) / mix_rate
		if _squeal_phase_b >= 1.0:
			_squeal_phase_b -= 1.0
		var squeal := sin(TAU * _squeal_phase_a) * 0.6 + sin(TAU * _squeal_phase_b) * 0.4

		# --- Wind ---
		_lp_wind += (noise - _lp_wind) * 0.02

		var sample := _lp_engine * _engine_amp + scrub * _tire_amp * 2.0 + squeal * _squeal_amp + _lp_wind * _wind_amp * 5.0
		sample = clampf(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
