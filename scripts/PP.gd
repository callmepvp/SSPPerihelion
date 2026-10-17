extends Node

const SAVE_PATH = "user://pp_scores.json"

# ---- tuning knobs: expect to adjust these ----
const SECTION_MS = 400.0      # strain is measured in windows this long
const STRAIN_DECAY = 0.15     # fraction of strain left after 1 second
const MIN_DT_MS = 20.0        # stacked/simultaneous notes count as this far apart
const STAR_SCALE = 0.0037
const PP_SCALE = 5.0
const PP_EXPONENT = 2.2
const ACC_EXPONENT = 12.0
# plays with easier-than-default settings give no pp
const MAX_HITWINDOW = 55.0
const MAX_HITBOX = 1.1401

var plays:Dictionary = {}       # map id -> best play
var diff_cache:Dictionary = {}  # "id|speed" -> stars

func _ready():
	load_plays()

# Difficulty from note positions and timing (osu-style strain)
func get_stars(song:Song, speed:float) -> float:
	var key = "%s|%.2f" % [song.id, speed]
	if diff_cache.has(key): return diff_cache[key]

	var notes:Array = song.read_notes()
	if notes.size() < 2: return 0.0

	var strain:float = 0.0
	var peaks:Dictionary = {}
	for i in range(1, notes.size()):
		var dt:float = max((notes[i][2] - notes[i-1][2]) / speed, MIN_DT_MS)
		var dist:float = Vector2(notes[i][0], notes[i][1]).distance_to(Vector2(notes[i-1][0], notes[i-1][1]))
		var dt_s:float = dt / 1000.0
		# movement needed per second, plus a small bonus for raw note density
		var hit_strain:float = (dist + 0.3) / dt_s
		strain = strain * pow(STRAIN_DECAY, dt_s) + hit_strain
		var section:int = int(notes[i][2] / SECTION_MS)
		peaks[section] = max(peaks.get(section, 0.0), strain)

	var values:Array = peaks.values()
	values.sort()
	values.invert() # hardest sections first
	var total:float = 0.0
	for i in range(values.size()):
		total += values[i] * pow(0.9, i)

	var stars:float = total * STAR_SCALE
	diff_cache[key] = stars
	return stars

func calc_pp(stars:float, accuracy:float, note_count:int) -> float:
	var base:float = pow(stars, PP_EXPONENT) * PP_SCALE
	var length_factor:float = 0.9 + 0.3 * min(float(note_count) / 1500.0, 1.0)
	var acc_factor:float = pow(accuracy, ACC_EXPONENT)
	return base * length_factor * acc_factor

func record_play():
	var r = Rhythia
	if r.song_end_type != Globals.END_PASS: return
	if r.was_replay or r.just_ended_queue: return
	if !settings_allow_pp(): return
	var song:Song = r.selected_song
	if song == null: return

	var acc:float = float(r.song_end_hits) / max(r.song_end_total_notes, 1)
	var speed:float = Globals.speed_multi[r.mod_speed_level]
	var stars:float = get_stars(song, speed)
	var pp:float = calc_pp(stars, acc, song.note_count)

	var old = plays.get(song.id)
	if old == null or pp > old.pp:
		plays[song.id] = {
			id = song.id, name = song.name, pp = pp, stars = stars, accuracy = acc,
			misses = r.song_end_misses, speed = speed, date = OS.get_unix_time()
		}
		save_plays()
	Globals.notify(Globals.NOTIFY_SUCCEED, "%.1f pp  (%.2f stars)" % [pp, stars], "Performance")

func total_pp() -> float:
	var list:Array = plays.values()
	list.sort_custom(self, "_sort_pp")
	var total:float = 0.0
	for i in range(list.size()):
		total += list[i].pp * pow(0.95, i)
	return total

func _sort_pp(a, b):
	return a.pp > b.pp

func save_plays():
	var f:File = File.new()
	if f.open(Globals.p(SAVE_PATH), File.WRITE) == OK:
		f.store_string(JSON.print(plays, "\t"))
		f.close()

func load_plays():
	var f:File = File.new()
	if f.file_exists(Globals.p(SAVE_PATH)) and f.open(Globals.p(SAVE_PATH), File.READ) == OK:
		var res = parse_json(f.get_as_text())
		f.close()
		if res is Dictionary: plays = res
		
		
		
		
		
		
func settings_allow_pp() -> bool:
	var r = Rhythia
	return not (r.mod_nofail or r.start_offset != 0 or r.hitwindow_ms > MAX_HITWINDOW or r.note_hitbox_size > MAX_HITBOX)

func get_top_plays(n:int = 10) -> Array:
	var list:Array = plays.values()
	list.sort_custom(self, "_sort_pp")
	var out:Array = []
	for i in range(min(n, list.size())):
		out.append(list[i])
	return out

func max_pp_info(song:Song) -> Dictionary:
	if song == null or song.is_online or song.is_broken or song.note_count < 2:
		return {state = "hidden"}
	if !settings_allow_pp():
		return {state = "blocked"}
	var speed:float = Globals.speed_multi[Rhythia.mod_speed_level]
	var stars:float = get_stars(song, speed)
	var pp:float = calc_pp(stars, 1.0, song.note_count)
	var best:float = 0.0
	var old = plays.get(song.id)
	if old != null: best = old.pp
	var gain:float = 0.0
	if pp > best: gain = total_pp_with(song.id, pp) - total_pp()
	return {state = "ok", pp = pp, stars = stars, speed = speed, best = best, gain = gain}

# total pp if this map's score were new_pp (used for the "+X total" preview)
func total_pp_with(song_id:String, new_pp:float) -> float:
	var list:Array = []
	for id in plays.keys():
		if id != song_id: list.append(plays[id].pp)
	list.append(new_pp)
	list.sort()
	list.invert()
	var total:float = 0.0
	for i in range(list.size()):
		total += list[i] * pow(0.95, i)
	return total
