class_name PokemonData
extends RefCounted

const DATABASE_PATH := "res://data/pokemon_db.json"
const SourceJavaHashOrder = preload("res://scripts/source_java_hash_order.gd")
static var _database: Dictionary = {}
static var _biome_species_cache: Dictionary = {}
static var _shiny_palettes: Dictionary = {}
static var _shiny_textures: Dictionary = {}
static var _evolution_fronts: Dictionary = {}
static var _overworld_layouts: Dictionary = {}

static func _supplemental_front(species: String, shiny: bool) -> Texture2D:
    if _evolution_fronts.is_empty():
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(
            "res://data/evolution_sprites.json"))
        if parsed is Dictionary:
            _evolution_fronts = parsed
    var entry: Dictionary = _evolution_fronts.get(canonical_species(species), {})
    var path := String(entry.get("shiny" if shiny else "normal", ""))
    return load(path) as Texture2D if not path.is_empty() else null

# Runtime encounter scaling uses the same evolution checks as GenIsland1.
# This is deliberately separate from world generation so the protected Java-
# parity generator remains byte-for-byte unchanged.

# PokeWilds uses TYPE in wilds_data.asm to append the species' type-default
# generation areas. Explicit biome entries remain weighted exactly as authored.
const TYPE_DEFAULT_BIOMES := {
    "NORMAL": ["SAVANNA", "FOREST"],
    "FIRE": ["DESERT", "SAVANNA", "VOLCANO"],
    "WATER": ["BEACH", "WOODED_LAKE", "RIVER"],
    "ELECTRIC": ["SAVANNA", "FOREST"],
    "GRASS": ["FOREST", "DEEP_FOREST", "WOODED_LAKE"],
    "ICE": ["SNOW"],
    "FIGHTING": ["MOUNTAIN", "SAVANNA"],
    "POISON": ["DEEP_FOREST", "GRAVEYARD"],
    "GROUND": ["DESERT", "MOUNTAIN", "OASIS"],
    "FLYING": ["FOREST", "SAVANNA", "MOUNTAIN"],
    "PSYCHIC": ["WOODED_LAKE", "RUINS_OUTER"],
    "BUG": ["FOREST", "DEEP_FOREST", "WOODED_LAKE"],
    "ROCK": ["MOUNTAIN", "ROCK_SMASH", "VOLCANO"],
    "GHOST": ["DEEP_FOREST", "GRAVEYARD", "RUINS_INNER"],
    "DRAGON": ["MOUNTAIN", "WOODED_LAKE"],
    "DARK": ["DEEP_FOREST", "GRAVEYARD"],
    "STEEL": ["MOUNTAIN", "RUINS_OUTER"],
    "FAIRY": ["FOREST", "WOODED_LAKE"]
}

const GENERATED_BIOME_MATCHES := {
    "FOREST": ["FOREST"],
    "DEEP_FOREST": ["DEEP_FOREST", "GRAVEYARD", "FOREST"],
    "GRAVEYARD": ["GRAVEYARD", "DEEP_FOREST"],
    "SAVANNA": ["SAVANNA"],
    "MOUNTAIN": ["MOUNTAIN", "MOUNTAIN_WATER", "ROCK_SMASH"],
    "DESERT": ["DESERT", "OASIS", "SAND_PIT", "SAND_FISHING", "RUINS_OUTER", "RUINS_INNER", "VOLCANO"],
    "OASIS": ["OASIS", "OASIS_POND", "DESERT"],
    "VOLCANO": ["VOLCANO", "MOUNTAIN", "DESERT"],
    "SNOW": ["SNOW"],
    "TUNDRA": ["SNOW"],
    "BEACH": ["BEACH", "TIDAL_BEACH", "TIDAL_BEACH_ROCKS", "TIDAL_BEACH_PLATEAU", "TIDAL_BEACH_WATER"],
    "WOODED_LAKE": ["WOODED_LAKE", "WOODED_LAKE_WATER", "WOODED_LAKE_FISHING", "RIVER", "OASIS", "OASIS_POND"],
    "RIVER": ["RIVER", "WOODED_LAKE_WATER", "WOODED_LAKE_FISHING"],
    "OCEAN": ["OCEAN", "OCEAN_FISHING", "TIDAL_BEACH_WATER"]
}

static func _ensure_loaded() -> void:
    if not _database.is_empty():
        return
    if not FileAccess.file_exists(DATABASE_PATH):
        _database = {"species": {}}
        return
    var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
    _database = parsed if typeof(parsed) == TYPE_DICTIONARY else {"species": {}}
    (_database["species"] as Dictionary).merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/mega_species.json")), true)
    (_database["species"] as Dictionary).merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/unown_king.json")), true)
    OriginalMods.apply_data(_database)
    # Specie.java excludes moves outside attacksImplemented before assignment.
    var implemented: Dictionary = _database.get("moves", {})
    for entry in (_database.get("species", {}) as Dictionary).values():
        var supported: Array = []
        for learned in entry.get("learnset", []):
            if implemented.has(String(learned.get("move", ""))):
                supported.append(learned)
        entry["learnset"] = supported

static func all_species() -> Array[String]:
    _ensure_loaded()
    var result: Array[String] = []
    for key in (_database.get("species", {}) as Dictionary).keys():
        result.append(String(key))
    result.sort()
    return result

# Original names and canonical database names refer to the same form.
const SOURCE_FORM_IDS := {
    "araichu": "raichu_alolan", "aexeggutor": "exeggutor_alolan",
    "amarowak": "marowak_alolan", "gdarumaka": "darumaka_galarian",
    "darmanitanzen": "darmanitan_zenmode", "aegislash": "aegislash_shield",
    "gyamask": "yamask_galarian",
    "gdarmanitan": "darmanitan_galarian", "gdarmanitanzen": "darmanitan_galarian_zenmode"
}

static func canonical_species(species: String) -> String:
    var key := species.to_lower().replace(" ", "_")
    return String(SOURCE_FORM_IDS.get(key, key))

static func source_species(species: String) -> String:
    var key := canonical_species(species)
    for original in SOURCE_FORM_IDS:
        if SOURCE_FORM_IDS[original] == key: return String(original)
    return key

static func info(species: String) -> Dictionary:
    _ensure_loaded()
    var all: Dictionary = _database.get("species", {})
    var key := species.to_lower().replace(" ", "_")
    key = canonical_species(key)
    var entry := (all.get(key, {}) as Dictionary).duplicate(true)
    if key=="nidoran_m":entry["name"]="NIDORAN♂"
    elif key=="nidoran_f":entry["name"]="NIDORAN♀"
    # Make the source sheet visible to population eligibility as well as the
    # texture loader. A loader-only fallback left this form out of biome pools.
    if key == "exeggutor_alolan" and not entry.is_empty():
        entry["overworld"] = "res://assets/original_pokemon/exeggutor_alolan/overworld.png"
    return entry

static func move_info(move_name: String) -> Dictionary:
    _ensure_loaded()
    var moves: Dictionary = _database.get("moves", {})
    return (moves.get(move_name.to_upper().replace(" ", "_"), {}) as Dictionary).duplicate(true)

static func evolution_rules(record: Dictionary) -> Array:
    var species := canonical_species(String(record.get("species", "")))
    # Specie.java moves Combee's evolution map to combee_female; Pokemon.java
    # selects it after gender assignment. Keep our saved species ID stable.
    if species == "combee" and String(record.get("gender", "")).to_lower() == "female":
        return [{"method":"EVOLVE_LEVEL", "parameter":"21", "species":"vespiquen"}]
    return info(species).get("evolutions", [])

static func all_moves() -> Array[String]:
    _ensure_loaded()
    var result: Array[String] = []
    for key in (_database.get("moves", {}) as Dictionary).keys():
        result.append(String(key))
    result.sort()
    return result

static func is_shiny(record: Dictionary) -> bool:
    # Explicit canonical state wins; false must never fall through to another roll.
    return bool(record.get("shiny", record.get("is_shiny", record.get("isShiny", false))))

static func record_texture(record: Dictionary, kind: String = "overworld") -> Texture2D:
    if kind in ["front", "back", "overworld"] and String(record.get("species", "")).to_lower() == "gengar" and String(record.get("form", "")).to_lower() == "mega":
        return preload("res://scripts/mega_gengar_art.gd").texture(kind, is_shiny(record))
    return texture(String(record.get("species", record.get("name", ""))), kind, is_shiny(record))

static func texture(species: String, kind: String = "overworld", shiny: bool = false) -> Texture2D:
    var legendary := preload("res://scripts/gen3_legendary_art.gd").texture(species, kind, shiny)
    if legendary != null: return legendary
    if shiny:
        var community_shiny := preload("res://scripts/divinakra_mega_art.gd").texture(species, kind, true)
        if community_shiny != null: return community_shiny
        return _shiny_texture(species, kind)
    var community := preload("res://scripts/divinakra_mega_art.gd").texture(species, kind)
    if community != null: return community
    var path := String(info("unown_a" if species.to_lower() == "unown" else species).get(kind, ""))
    # Mew's original sheet contains all six authored poses. The old imported
    # battle_front_frames entry retained only its first frame.
    if species.to_lower() == "mew" and kind == "front":
        path = "res://assets/original_pokemon/mew/front.png"
    if kind == "overworld" and path.is_empty() and \
            species.to_lower() in ["aexeggutor", "exeggutor_alolan"]:
        # Specie.java uses the dedicated six-frame 16x48 overworld sheet.
        return _overworld_layout(load("res://assets/original_pokemon/exeggutor_alolan/overworld.png") as Texture2D, species)
    if path.is_empty() or not ResourceLoader.exists(path):
        return _supplemental_front(species, false) if kind == "front" else null
    var loaded := load(path) as Texture2D
    return _overworld_layout(loaded, species) if kind == "overworld" else loaded

static func _overworld_layout(texture_value: Texture2D, species: String) -> Texture2D:
    if texture_value == null: return null
    if canonical_species(species) in ["mega_charizard_x", "mega_charizard_y", "mega_venusaur", "mega_blastoise", "mega_gyarados", "mega_sharpedo", "mega_kangaskhan", "arceus"]:
        texture_value.set_meta("mega_gengar_walk", true)
    if canonical_species(species) == "exeggutor_alolan":
        texture_value.set_meta("alolan_exeggutor_walk", true)
    if canonical_species(species) == "arceus":
        texture_value.set_meta("overworld_feet_offset", Vector2(0, -8))
    if texture_value.get_size() != Vector2(16, 96): return texture_value
    var key := texture_value.resource_path
    if _overworld_layouts.has(key): return _overworld_layouts[key]
    # Original source sheets are six 16x16 poses stacked vertically. Preserve
    # their exact order while adapting to the port's horizontal sheet layout.
    var image := Image.create(96, 16, false, Image.FORMAT_RGBA8)
    for index in range(6):
        image.blit_rect(texture_value.get_image(), Rect2i(0, index*16, 16, 16), Vector2i(index*16, 0))
    var result := ImageTexture.create_from_image(image)
    _overworld_layouts[key] = result
    return result

static func _shiny_texture(species: String, kind: String) -> Texture2D:
    var key := canonical_species(species)
    if key == "unown": key = "unown_a"
    if kind == "front" and String(info(key).get("front", "")).is_empty():
        return _supplemental_front(key, true)
    var cache_key := key + ":" + kind
    if _shiny_textures.has(cache_key): return _shiny_textures[cache_key] as Texture2D
    var normal := texture(species, kind)
    if normal == null: return null
    if kind in ["overworld", "back", "front"]:
        var authored_path := String(info(key).get(kind + "_shiny", ""))
        if not authored_path.is_empty() and ResourceLoader.exists(authored_path):
            var authored := load(authored_path) as Texture2D
            if kind == "overworld": authored = _overworld_layout(authored, species)
            if authored != null and authored.get_size() == normal.get_size() and authored.get_image().get_data() != normal.get_image().get_data():
                _shiny_textures[cache_key] = authored
                return authored
    if _shiny_palettes.is_empty():
        _shiny_palettes = JSON.parse_string(FileAccess.get_file_as_string("res://data/shiny_palettes.json"))
        _shiny_palettes.merge(preload("res://scripts/native_mod_pack.gd").palettes,true)
    var palette: Dictionary = _shiny_palettes.get(key, {})
    if palette.is_empty(): return normal
    var image := normal.get_image().duplicate() as Image
    if image == null or image.is_empty(): return normal
    image.convert(Image.FORMAT_RGBA8)
    var normal_colors: Array = palette.get("back_normal" if kind == "back" else "normal", []).duplicate(true)
    if kind == "overworld":
        # Source overworld art uses its own two-color palette, distinct from battle art.
        var discovered: Array[Color] = []
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                var c := image.get_pixel(x, y)
                if c.a == 0.0 or c == Color.BLACK or c == Color.WHITE: continue
                if not discovered.has(c): discovered.append(c)
                if discovered.size() == 2: break
            if discovered.size() == 2: break
        if discovered.size() == 2:
            if discovered[0].r + discovered[0].g + discovered[0].b < discovered[1].r + discovered[1].g + discovered[1].b:
                discovered.reverse()
            normal_colors.clear()
            for c in discovered: normal_colors.append([int(c.r * 32.0), int(c.g * 32.0), int(c.b * 32.0)])
    var replacements: Array = palette.get("colors", [])
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var c := image.get_pixel(x, y)
            if c.a == 0.0: continue
            var quantized := [int(c.r * 32.0), int(c.g * 32.0), int(c.b * 32.0)]
            for index in range(mini(normal_colors.size(), replacements.size())):
                if quantized[0] == int(normal_colors[index][0]) and quantized[1] == int(normal_colors[index][1]) and quantized[2] == int(normal_colors[index][2]):
                    var rgb: Array = replacements[index]
                    image.set_pixel(x, y, Color(float(rgb[0])/255.0, float(rgb[1])/255.0, float(rgb[2])/255.0, c.a))
                    break
    var result := ImageTexture.create_from_image(image)
    if kind == "overworld" and key == "exeggutor_alolan": result.set_meta("alolan_exeggutor_walk", true)
    _shiny_textures[cache_key] = result
    return result

static func cry_path(species: String) -> String:
    return String(info(species).get("cry", ""))

static func random_species(rng: RandomNumberGenerator, require_overworld: bool = true) -> String:
    var choices: Array[String] = []
    for species in all_species():
        if species.begins_with("mega_"): continue # World-unique encounters only.
        if species.begins_with("unown_"): continue
        var entry := info(species)
        if not require_overworld or not String(entry.get("overworld", "")).is_empty():
            choices.append(species)
    return choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else "pidgey"

static func spawn_biomes(species: String) -> Array[String]:
    var entry := info(species)
    var result: Array[String] = []
    var use_type_defaults := false
    for raw_biome in entry.get("spawn_biomes", []):
        var biome := String(raw_biome).to_upper()
        if biome == "TYPE":
            use_type_defaults = true
        elif not biome.is_empty() and biome != "NONE":
            # Duplicate explicit entries intentionally remain duplicates because
            # the source uses them as generation weight (for example RATTATA).
            result.append(biome)
    if use_type_defaults:
        for raw_type in entry.get("types", ["NORMAL"]):
            for raw_biome in TYPE_DEFAULT_BIOMES.get(String(raw_type), []):
                result.append(String(raw_biome))
    return result

static func species_for_biome(biome: String) -> Array[String]:
    _ensure_loaded()
    var key := biome.to_upper()
    if _biome_species_cache.has(key):
        return (_biome_species_cache[key] as Array).duplicate()

    var accepted: Array = GENERATED_BIOME_MATCHES.get(key, [key])
    var explicit_choices: Array[String] = []
    var fallback_choices: Array[String] = []
    for species in all_species():
        var entry := info(species)
        if String(entry.get("overworld", "")).is_empty():
            continue
        for raw_biome in entry.get("spawn_biomes", []):
            var explicit_biome := String(raw_biome).to_upper()
            if explicit_biome != "TYPE" and accepted.has(explicit_biome):
                explicit_choices.append(species)
        for species_biome in spawn_biomes(species):
            if accepted.has(species_biome):
                fallback_choices.append(species)
    # The hand-authored rows are the source game's actual regional spawn tables.
    # TYPE defaults are only used when a generated biome has no explicit table.
    var choices := (
        explicit_choices if not explicit_choices.is_empty() else fallback_choices
    )
    _biome_species_cache[key] = choices.duplicate()
    return choices

static func random_species_for_biome(
        biome: String,
        rng: RandomNumberGenerator
    ) -> String:
    var choices := species_for_biome(biome)
    if choices.is_empty():
        return random_species(rng, true)
    return choices[rng.randi_range(0, choices.size() - 1)]

static func adaptive_source_evolution(
        start_species: String,
        encounter_level: int,
        rng: RandomNumberGenerator
    ) -> String:
    var species := start_species.to_lower()
    var times_evolved := 0
    while times_evolved < 4:
        var evolutions: Array = info(species).get("evolutions", []) as Array
        if evolutions.is_empty():
            break
        var selected := ""
        for raw_evolution in _java_evolution_order(evolutions):
            var evolution := raw_evolution as Dictionary
            var parameter := String(evolution.get("parameter", ""))
            if parameter.is_valid_int():
                if int(parameter) <= encounter_level + 10 * (times_evolved + 1) \
                        and rng.randi_range(0, 255) >= 128:
                    selected = String(evolution.get("species", species)).to_lower()
                    break
            elif rng.randi_range(0, 255) >= 192:
                selected = String(evolution.get("species", species)).to_lower()
                break
        if selected.is_empty() or selected == species:
            break
        species = selected
        times_evolved += 1
    return species

static func _java_evolution_order(evolutions: Array) -> Array:
    var capacity := 16
    while evolutions.size() > int(float(capacity) * 0.75):
        capacity *= 2
    var decorated: Array[Dictionary] = []
    for index in range(evolutions.size()):
        var evolution := evolutions[index] as Dictionary
        var parameter := String(evolution.get("parameter", ""))
        var key := parameter if parameter.is_valid_int() else \
            parameter.to_lower().replace("_", " ")
        var hash := SourceJavaHashOrder._spread_hash(
            SourceJavaHashOrder._java_hash(key)
        )
        decorated.append({
            "bucket": hash & (capacity - 1),
            "index": index,
            "evolution": evolution
        })
    decorated.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a["bucket"]) < int(b["bucket"]) or (
            int(a["bucket"]) == int(b["bucket"]) and \
            int(a["index"]) < int(b["index"])
        )
    )
    var ordered: Array = []
    for entry in decorated:
        ordered.append((entry as Dictionary)["evolution"])
    return ordered


static func source_route_species_allowed(
        species: String, route_name: String, is_water: bool
    ) -> bool:
    var normalized := species.to_lower()
    var route := route_name.to_lower()
    var evolutions: Array = info(normalized).get("evolutions", []) as Array
    var has_evolution := not evolutions.is_empty()
    var allowed := not has_evolution
    if "beach" in route:
        allowed = has_evolution
    if "ruins" in route or "graveyard" in route:
        allowed = true
    if route in [
            "beach2", "beach2_rocks", "beach2_plateau",
            "savanna2", "volcano1", "wooded_lake1"
        ]:
        allowed = true
    if route == "beach2_water":
        allowed = is_water
    if route == "mountain1_water1":
        allowed = is_water
    # Match GenIsland1's final else-if attachment exactly.
    if route == "wooded_lake_water1":
        allowed = is_water
    elif "mountain" in route:
        allowed = (not has_evolution or normalized in ["machoke", "rhydon", "onix"])
    if "snow" in route:
        allowed = (not has_evolution or normalized in ["sneasel", "piloswine"])
    return allowed

static func egg_species_for(
        parent_species: String,
        rng: RandomNumberGenerator
    ) -> String:
    var forms: Array = info(parent_species).get("base_forms", [])
    if forms.is_empty():
        return parent_species.to_lower()
    var total_weight := 0
    for raw_form in forms:
        if typeof(raw_form) == TYPE_DICTIONARY:
            total_weight += maxi(1, int((raw_form as Dictionary).get("weight", 100)))
    if total_weight <= 0:
        return parent_species.to_lower()
    var roll := rng.randi_range(1, total_weight)
    for raw_form in forms:
        if typeof(raw_form) != TYPE_DICTIONARY:
            continue
        var form: Dictionary = raw_form
        roll -= maxi(1, int(form.get("weight", 100)))
        if roll <= 0:
            return String(form.get("species", parent_species)).to_lower()
    return parent_species.to_lower()

static func battle_display_name(species: String) -> String:
    if canonical_species(species)=="nidoran_m":return "NIDORAN♂"
    if canonical_species(species)=="nidoran_f":return "NIDORAN♀"
    var mod_name := String(info(species).get("mod_name",""))
    if not mod_name.is_empty(): return mod_name
    if canonical_species(species) == "raichu_alolan": return "ALOLAN RAICHU"
    if canonical_species(species) == "exeggutor_alolan": return "ALOLAN EXEGGUTOR"
    if species.to_lower() == "unown_king": return "UNOWN KING"
    if species.to_lower().begins_with("unown_"): return "UNOWN"
    return String(info(species).get("name", species.to_upper())) if species.begins_with("mega_") else species.to_upper()
