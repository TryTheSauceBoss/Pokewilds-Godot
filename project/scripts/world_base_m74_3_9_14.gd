extends Node2D

const SourceMineRuntime = preload("res://scripts/source_mine_runtime.gd")
var source_mine_pokemon: Dictionary = {}

signal generation_progress(value: float, message: String)
signal generation_finished
signal encounter_requested(species: String, level: int)
signal battle_requested(context: Dictionary)
signal world_message(message: String)
signal unown_message(message: String)
signal trainer_tip_message(message: String)
signal item_collected(item_name: String)
signal material_collected(item_name: String, amount: int)
signal material_bundle_collected(items: Dictionary)
signal paint_requested(picture_index: int, cell: Vector2i)
signal teleport_map_requested(destinations: Array)
signal crafting_station_requested(station: String)
signal build_requested(build_name: String, cell: Vector2i)
signal build_selection_changed(index: int)
signal dig_requested(choice: String, cell: Vector2i, material: String)
signal build_refund_requested(refund: Dictionary)
signal structure_removal_requested(cell: Vector2i, move: String)
signal pokemon_recalled(pokemon_data: Dictionary)
signal deployed_recall_requested(cell: Vector2i, species: String, message: String)
signal structure_action(action: String)
signal egg_collected(species: String)
signal egg_pickup_prompt_requested(cell: Vector2i)
# Source-style A-button wild interaction prompt. Main owns the modal box so it
# can reuse the approved dialogue border/font without changing world logic.
signal wild_pokemon_prompt_requested(wild_id: int, species: String, kind: String)
signal player_stepped
signal pokemon_ecology_changed(pokemon_data: Dictionary)

const TILE := 16
const CraftingData = preload("res://scripts/crafting_data.gd")
const FieldMoveData = preload("res://scripts/field_move_data.gd")
const PokemonData = preload("res://scripts/pokemon_data.gd")
const PokemonEcology = preload("res://scripts/pokemon_ecology.gd")
const WorldParity = preload("res://scripts/world_parity.gd")
const SourceWorldGenerator = preload("res://scripts/source_world_generator.gd")
const SourceWorldCache = preload("res://scripts/source_world_cache.gd")
const SourceWorldData = preload("res://scripts/source_world_data.gd")
const SourceInteriorGenerator = preload("res://scripts/source_interior_generator.gd")
const SourceRouteData = preload("res://scripts/source_route_data.gd")
const SourceExactWorldAdapter = preload("res://scripts/source_exact_world_adapter.gd")
const SOURCE_CHUNK_TILE_LAYER_SCRIPT = preload("res://scripts/source_resident_tile_layer.gd")
const SourceChunkCollisionStreamer = preload("res://scripts/source_resident_collision_layer.gd")
const SourceReflectionLayerScript = preload("res://scripts/source_resident_reflection_layer.gd")
const SourceJavaRandom = preload("res://scripts/source_java_random.gd")
const SourceEventData = preload("res://scripts/source_event_data.gd")
const WorldEnvironmentSystem = preload(
    "res://scripts/world_environment_system.gd"
)

const FARM_SECONDS := 60.0 # legacy saves only; new farms use world-day harvest tracking
const SOURCE_DAY_TICKS := 18000.0
const SOURCE_NIGHT_TICKS := 5000.0
const WORLD_DAY_SECONDS := (SOURCE_DAY_TICKS + SOURCE_NIGHT_TICKS) / 60.0
const NIGHT_START_FRACTION := (
    SOURCE_DAY_TICKS / (SOURCE_DAY_TICKS + SOURCE_NIGHT_TICKS)
)
const LOW_TIDE_START_1 := 5000.0 / 23000.0
const LOW_TIDE_END_1 := 13000.0 / 23000.0
const LOW_TIDE_START_2 := 18000.0 / 23000.0
const TIDE_MESSAGE_COOLDOWN_SECONDS := 600.0
const FARM_RADIUS := 2
const WILD_INITIAL_EGG_SECONDS := 30.0
const MATE_BOND_RADIUS := 6

# The live generator must use the original 0.8.11 GenIsland1 radius and tile
# algorithms.  The smaller bounded generator remains below only as a diagnostic
# fallback for old QA fixtures; it must never be selected for a normal game.
const MAP_SIZE_PRESETS := [
    Vector2i(80, 60),
    Vector2i(96, 72),
    Vector2i(112, 84),
    Vector2i(128, 96),
    Vector2i(144, 108)
]

var map_w: int = 64
var map_h: int = 48
var map_size_index: int = 1
var exact_world_mode := true
var exact_world: SourceExactWorldAdapter
var exact_world_bounds := Rect2i()

const GRASS := preload("res://assets/grass_runtime.png")
const SAND := preload("res://assets/sand_runtime.png")
const WATER := preload("res://assets/water_runtime.png")
const TREE_1 := preload("res://assets/tree1_runtime.png")
const TREE_2 := preload("res://assets/tree2_runtime.png")
const TREE_LARGE := preload("res://assets/tree_large_runtime.png")
const BUSH := preload("res://assets/bush_runtime.png")
const ROCK_1 := preload("res://assets/rock1_runtime.png")
const ROCK_3 := preload("res://assets/rock3_runtime.png")
const FLOWER_1 := preload("res://assets/flower1_runtime.png")
const FLOWER_3 := preload("res://assets/flower3_runtime.png")
const TALL_GRASS := preload("res://assets/tall_grass.png")
const TALL_GRASS_FRONT := preload("res://assets/tall_grass_front.png")
const BIOME_SAVANNA := preload("res://assets/biome_savanna.png")
const BIOME_MOUNTAIN := preload("res://assets/biome_mountain.png")
const BIOME_DESERT := preload("res://assets/biome_desert.png")
const BIOME_SNOW := preload("res://assets/biome_snow.png")
const BIOME_WOODED_LAKE := preload("res://assets/biome_wooded_lake.png")
const BIOME_TREE_SAVANNA := preload("res://assets/biome_tree_savanna.png")
const BIOME_CACTUS := preload("res://assets/biome_cactus.png")
const BIOME_TREE_SNOW := preload("res://assets/biome_tree_snow.png")
const POKEMON_EGG := preload("res://assets/pokemon_egg.png")
const SOURCE_STORAGE_BOX := preload(
    "res://assets/source_0_8_11/tiles/chest1.png"
)
const ECOLOGY_EMOTES := preload("res://assets/ecology/emotes.png")
const TRAPINCH_BURROW := preload("res://assets/ecology/trapinch_ow1.png")
const DESERT_WHIRLPOOL := preload("res://assets/ecology/whirlpool_desert2.png")
const DESERT_BURROW_SAND := preload("res://assets/ecology/grass_over_sheet3.png")
const LANDMARK_BALL := preload("res://assets/landmark_pokeball.png")
const LANDMARK_SIGN := preload("res://assets/landmark_sign.png")
const LANDMARK_CAMP := preload("res://assets/landmark_campfire.png")
const SOURCE_PATH_1 := preload("res://assets/world_source/path1.png")
const SOURCE_PATH_2 := preload("res://assets/world_source/path2.png")
const SOURCE_SIGN := preload("res://assets/world_source/sign1.png")
const SOURCE_CAVE_DOOR := preload("res://assets/world_source/cave_door.png")
const SOURCE_HOUSE := preload("res://assets/world_source/house6_all.png")
const SOURCE_HOUSE_ROOF := preload("res://assets/world_source/house6_roof_all.png")
const SOURCE_HOUSE_DOOR := preload("res://assets/world_source/house6_door1.png")
const SOURCE_FLOOR := preload("res://assets/world_source/floor1.png")
const SOURCE_HOUSE5_FLOOR := preload("res://assets/source_0_8_11/tiles/buildings/house5_floor1.png")
const SOURCE_SAVANNA_TREE := preload("res://assets/source_0_8_11/tiles/tree_savanna1.png")
const SOURCE_HOUSE5_RUG := preload("res://assets/source_0_8_11/tiles/buildings/house5_floor_rug1.png")
const SOURCE_HOUSE5_WALL := preload("res://assets/source_0_8_11/tiles/buildings/house5_wall1.png")
const SOURCE_HOUSE5_WALL_LEFT := preload("res://assets/source_0_8_11/tiles/buildings/house5_left1.png")
const SOURCE_HOUSE5_WALL_MIDDLE := preload("res://assets/source_0_8_11/tiles/buildings/house5_middle1.png")
const SOURCE_HOUSE5_WALL_RIGHT := preload("res://assets/source_0_8_11/tiles/buildings/house5_right1.png")
const SOURCE_HOUSE5_SIDE_W := preload("res://assets/source_0_8_11/tiles/buildings/house5_W.png")
const SOURCE_HOUSE5_SIDE_E := preload("res://assets/source_0_8_11/tiles/buildings/house5_E.png")
const SOURCE_HOUSE5_STAIRS := preload("res://assets/source_0_8_11/tiles/buildings/stairs_down2.png")
const SOURCE_HOUSE5_DOOR := preload("res://assets/source_0_8_11/tiles/buildings/house5_door1.png")
const SOURCE_NORMAL_ENCOUNTER_GRASS := preload("res://assets/source_0_8_11/tiles/grass1.png")
const SOURCE_HOUSE8_WALL_SHEET := preload("res://assets/source_0_8_11/tiles/buildings/house8_all.png")
const SOURCE_HOUSE8_ROOF := preload("res://assets/source_0_8_11/tiles/buildings/house8_roof_middle1.png")
const SOURCE_HOUSE8_DOOR := preload("res://assets/source_0_8_11/tiles/buildings/house8_door1.png")
const SOURCE_HOUSE12_WALL_SHEET := preload("res://assets/source_0_8_11/tiles/buildings/house12_all.png")
const SOURCE_HOUSE12_ROOF := preload("res://assets/source_0_8_11/tiles/buildings/house12_roof_middle1.png")
const SOURCE_HOUSE12_DOOR := preload("res://assets/source_0_8_11/tiles/buildings/house12_door1.png")
const SOURCE_WALL_1 := preload("res://assets/world_source/wall1.png")
const SOURCE_WALL_2 := preload("res://assets/world_source/wall2.png")
const SOURCE_WALL_3 := preload("res://assets/world_source/wall3.png")
const SOURCE_STAIRS_DOWN := preload("res://assets/world_source/stairs_down1.png")
const SOURCE_CAVE_FLOOR := preload("res://assets/world_source/cave1_floor1.png")
const SOURCE_CAVE_STONE := preload("res://assets/world_source/cave1_stone1.png")
const SOURCE_CAVE_RAMP := preload("res://assets/world_source/cave1_ramp1.png")
const SOURCE_BED := preload("res://assets/world_source/house_bed1.png")
const SOURCE_TABLE := preload("res://assets/world_source/house_table1_default.png")
const SOURCE_PLANT := preload("res://assets/world_source/house_plant1.png")
const SOURCE_NPC_SHEET := preload("res://assets/events/npcs-sheet.png")
const SOURCE_MYSTERY_NPC := preload("res://assets/events/npc1.png")
const SOURCE_PUDDLE_SPLASH := preload("res://assets/source_ui/puddle3.png")
const SOURCE_TIDAL_WATER := preload("res://assets/source_0_8_11/tiles/water2.png")
const SOURCE_SLEEPING_BAG := preload("res://assets/source_ui/sleeping_bag1.png")
const SOURCE_PIXEL_FONT := preload("res://assets/source_text_font.fnt")
const FARM_POKEMON_TEXTURES := {
    "pidgey": preload("res://assets/pokemon_pidgey.png"),
    "rattata": preload("res://assets/pokemon_rattata.png"),
    "caterpie": preload("res://assets/pokemon_caterpie.png"),
    "pikachu": preload("res://assets/pokemon_pikachu.png"),
    "machop": preload("res://assets/pokemon_machop.png")
}

var terrain_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var biome_noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

var terrain: Array = []
var biomes: Array = []
var blocked: Dictionary = {}
var tall_grass: Dictionary = {}
var landmarks: Dictionary = {}
var resource_objects: Dictionary = {}
var ground_sprites: Dictionary = {}
var ground_collisions: Dictionary = {}
var removed_resources: Dictionary = {}
var terrain_changes: Dictionary = {}
var built_structures: Dictionary = {}
var deployed_pokemon: Dictionary = {}
var build_mode_active := false
var build_selection_index := 0
var build_preview_sprite: Sprite2D
var source_plant_farms: Dictionary = {}
var planting_item := ""
var source_plant_system

func plants():
    if source_plant_system == null:
        source_plant_system = preload("res://scripts/source_plant_farming.gd").new()
        source_plant_system.configure(self)
    return source_plant_system

var active_field_move := ""
var active_field_species := ""
var active_field_pokemon: Dictionary = {}
var dig_selection_index := 0
var world_elapsed_seconds := 0.0
var repel_until_elapsed := 0.0
const DIG_CHOICES := FieldMoveData.DIG_CHOICES
const PAINT_CHOICES := [
    "PICTURE 1", "PICTURE 2", "PICTURE 3", "PICTURE 4", "PICTURE 5",
    "PICTURE 6", "PICTURE 7", "PICTURE 8", "PICTURE 9", "PICTURE 10",
    "PICTURE 11", "PICTURE 12", "PICTURE 13", "PICTURE 14", "PICTURE 15",
    "PICTURE 16", "PICTURE 17", "PICTURE 18", "PICTURE 19", "PICTURE 20"
]
var travel_selection_index := 0
var paint_selection_index := 0
var respawn_cell := Vector2i(-2147483648, -2147483648)
var respawn_house: Dictionary = {}
var field_previous_collision_mask := 1
var structure_textures: Dictionary = {}
var horizontal_sprite_center_cache: Dictionary = {}
var grass_exclusion: Dictionary = {}
var flower_cells: Dictionary = {}
var animated_flowers: Array[Sprite2D] = []
var flower_anim_time := 0.0
var spawn_cell := Vector2i(map_w / 2, map_h / 2)
var starting_biome := "FOREST"
var biome_order: Array[String] = []
var biome_regions: Array = []
var biome_centers: Dictionary = {}
var route_cells: Dictionary = {}
var source_landmarks: Dictionary = {}
var source_tiles: Dictionary = {}
var habitat_routes: Dictionary = {}
var source_area_entries: Dictionary = {}
var source_area_rects: Dictionary = {}
var source_area_layers: Dictionary = {}
var source_area_origins: Dictionary = {}
var source_layer_area_ids: Dictionary = {}
var generated_source_interior_plans: Array[Dictionary] = []
var interior_interactables: Dictionary = {}
var source_interior_upper_sprites: Dictionary = {}
var source_interior_mutations: Dictionary = {}
var built_house_interior_cells: Dictionary = {}
var built_house_paintable_walls: Dictionary = {}
# Persistent paint records are keyed by exterior door + local interior wall.
var built_house_paintings: Dictionary = {}
# Sprite instances are runtime-only and rebuilt whenever the house is entered.
var built_house_paint_sprites: Dictionary = {}
var active_built_house_door := Vector2i(-2147483648, -2147483648)
var built_house_interior_origin := Vector2i.ZERO
# Built houses use separate off-map coordinate bands for each source-style
# interior floor. Upper floors begin as void except for the 3x3 patch created
# by a staircase and can then be expanded with FLOOR tiles.
const BUILT_HOUSE_FLOOR_STRIDE := 64
var built_house_floor_origins: Dictionary = {}
var built_house_origins: Dictionary = {}
var built_house_exit_doors: Dictionary = {}
var built_house_room_size := Vector2i.ZERO
var built_house_footprint: Dictionary = {}
## Where each house's room was last drawn from: its place in the interior
## strip -> [the outside corner the room was measured from, the room's size].
## Lets a piece of the outside be matched to its tile of the room after the
## piece has been cut off from the door, or the house has changed shape.
var built_house_rooms_seen: Dictionary = {}
var built_house_floor_capacity := 1
var built_house_floor_tiles: Dictionary = {}
var built_house_decorations: Dictionary = {}
var built_house_decoration_sprites: Dictionary = {}
var built_house_void_collisions: Dictionary = {}
## The inside of a built house and the generated dungeons are laid out in the
## same far-off stretch of coordinates, so a dungeon's walls could mark tiles
## of a house's floor as blocked: BUILD and the other work moves then refused
## to start on open floor ("Leave one clear tile ahead"), and furniture could
## not be placed there. While a house is entered those marks are set aside
## here, and put back when it is left.
var built_house_displaced_blocks: Dictionary = {}
var built_house_blocks_stale := false
var normal_grass_front_sprite: Sprite2D
var savanna_tree_front_sprite: Sprite2D
var active_regi_pedestal_cell := Vector2i(-2147483648, -2147483648)
var active_area_id := "OVERWORLD"
var area_return_cells: Dictionary = {}
var discovered_cells: Dictionary = {}
var map_art_revision := 0
var dropped_item_manager: Node2D

func dropped_items() -> Node2D:
    if not is_instance_valid(dropped_item_manager):
        dropped_item_manager = preload("res://scripts/source_dropped_items.gd").new()
        add_child(dropped_item_manager)
        dropped_item_manager.world = self
    return dropped_item_manager

var wild_pokemon: Dictionary = {}
var wild_eggs: Dictionary = {}
var next_wild_id := 1
var next_deployed_id := 1
var ecology_accumulator := 0.0
var follower_pokemon: Dictionary = {}
var follower_sprite: Sprite2D
var follower_move_tween: Tween
var follower_walk_phase := 0
var field_helper_pokemon: Dictionary = {}
var field_helper_sprite: Sprite2D
var fly_shadow: Polygon2D
var field_helper_cell := Vector2i(-2147483648, -2147483648)
var work_trainer_sprite: Sprite2D
var work_trail: Array[Vector2] = []
var stool_seated_sprite: Sprite2D
var work_trainer_facing := Vector2i.DOWN
var work_trainer_position := Vector2.ZERO
var work_trainer_walking := false
var reflection_layer: SourceReflectionLayer
var sleeping_bag_sprite: Sprite2D
var sleeping_bag_rest_texture: Texture2D
var sleeping_bag_sleep_marks: Array[Label] = []
var sleeping_bag_anim_time := 0.0
var bed_rest_active := false
var last_pokemon_push_msec := -1000
var follower_cell := Vector2i(-2147483648, -2147483648)
var deployed_recall_candidate := Vector2i(-2147483648, -2147483648)
var deployed_recall_candidate_msec := 0
var pending_egg_record: Dictionary = {}
var burrow_busy := false
var sand_trap_ids: Dictionary = {}
var pending_encounter_record: Dictionary = {}
var pending_battle_context: Dictionary = {}
var event_progress: Dictionary = {
    "completed": {},
    "trainer_defeated": {},
    "keystone_life_force": {},
    "regis_caught": [],
    "mewtwo_defeated_day": -1,
    "fossil_machine_powered": false,
    "biome_first_entries": {}
}
var event_npcs: Dictionary = {}
var source_event_collisions: Dictionary = {}
var ghost_step_countdown := -1
var last_event_day := 0

const WORLD_BIOMES: Array[String] = [
    "FOREST", "SAVANNA", "MOUNTAIN", "DESERT", "SNOW", "WOODED_LAKE"
]

# Source GenIsland1 keeps several authored habitat names that the surrounding
# Godot systems historically collapsed into the six compatibility biomes.
# Normalize only aliases that are semantically identical (notably TUNDRA ->
# SNOW); preserve real sub-biomes such as GRAVEYARD, VOLCANO, BEACH and RIVER.
const SOURCE_BIOME_ALIASES := {
    "TUNDRA": "SNOW",
    "SNOW": "SNOW",
    "DEEP FOREST": "DEEP_FOREST",
    "WOODED LAKE": "WOODED_LAKE",
    "BEACH_BLACKSAND": "BEACH"
}
const DISCOVERY_RADIUS := 5
const WILD_MOVE_MIN := 1.0
const WILD_MOVE_MAX := 4.0
const ECOLOGY_ACTIVE_RADIUS := 24
const SOURCE_GRASS_ENCOUNTER_RATE := 75
const SOURCE_INTERIOR_ENCOUNTER_RATE := 4
const ENCOUNTER_GRACE_SECONDS := 24.0

var world_seed: int = 81102
var generated := false
var gameplay_enabled := true
var last_player_cell := Vector2i(-9999, -9999)
var encounter_count := 0
var encounter_grace_remaining := 0.0
var water_sprites: Array[Sprite2D] = []
var water_anim_time := 0.0
var water_frame := 0
var environment_system: WorldEnvironmentSystem
var tide_initialized := false
var low_tide_active := false
var tide_target_low := false
var tide_transition_tiles: Array[SourceTile] = []
var tide_band_cursor := 0
var tide_transition_bands: Array = []
var tide_topology_bands: Array = []
var tide_transition_band_index: int = 0
var tide_transition_accumulator := 0.0
var tide_wade_ripple: Sprite2D
var tide_wade_base: Sprite2D
var last_tide_message_seconds := -TIDE_MESSAGE_COOLDOWN_SECONDS
# The source video shows a coherent shoreline draining/flooding over several
# seconds, not globally ordered single-cell flicker. Each interval advances
# one distance band from the permanent ocean.
const TIDE_FRONTIER_SECONDS := 0.45
const TIDE_RETREAT_FRONTIER_SECONDS := 0.50
const TIDE_TRANSITION_STEPS := 14
const WATER_FRAME_TIME := 0.32
const CAMERA_ZOOM_MIN := 0.45
const CAMERA_ZOOM_MAX := 1.60
const CAMERA_ZOOM_STEP := 0.10
var camera_zoom_level := 1.0

@onready var player: CharacterBody2D = $Player

func _ready() -> void:
    # Generation is intentionally started by main.gd so the normal generation
    # screen can be shown first.
    player.visible = false
    for recipe in CraftingData.build_recipes():
        var build_name := String(recipe.get("name", ""))
        var asset_name := build_name.to_lower().replace(" ", "_")
        var texture_path := "res://assets/build/%s.png" % asset_name
        if ResourceLoader.exists(texture_path):
            structure_textures[build_name] = load(texture_path)
    # The original build sprites live in the imported 0.8.11 tile tree.  Keep
    # the recipe names stable while using those source textures directly.
    var source_build_textures := {
        "TORCH":"torch_sheet1.png", "STORAGE BOX":"chest1.png",
        "SIGN":"sign_built1.png", "STATUE":"statue1.png",
        "GRAVE":"gravestone1.png", "BRIDGE":"bridge1.png",
        "FENCE":"fence1.png", "CAMPFIRE":"campfire1.png",
        "CHIMNEY":"chimney_sheet1.png", "STAIRS":"stairs_up1.png",
        "BEACON":"warp_tile1.png", "KILN":"ball_kiln1.png",
        "FLOWERS":"flower1.png"
    }
    for raw_name in source_build_textures.keys():
        var build_name := String(raw_name)
        if structure_textures.has(build_name):
            continue
        var source_path := "res://assets/source_0_8_11/tiles/%s" % String(source_build_textures[raw_name])
        if ResourceLoader.exists(source_path):
            structure_textures[build_name] = load(source_path)
    # Always use the authored chest sheet. A legacy transparent placeholder
    # could otherwise win the generic res://assets/build lookup above.
    structure_textures["STORAGE BOX"] = SOURCE_STORAGE_BOX
    structure_textures["PRIVATE CHEST"] = SOURCE_STORAGE_BOX
    structure_textures["TABLE"] = SOURCE_TABLE
    var source_warp_tile := "res://assets/source_0_8_11/tiles/warp_tile1.png"
    if ResourceLoader.exists(source_warp_tile):
        structure_textures["BEACON"] = load(source_warp_tile)
    var indoor_build_textures := {
        "PLANT":"house_plant1.png", "WALL":"building1_wall1.png",
        "ROOF":"house6_roof_middle1.png", "WINDOW":"house_window1.png",
        "BED":"house_bed1.png", "CLOCK":"house_clock1.png",
        "COUCH":"house_couch1.png", "TRASH CAN":"house_trashcan1.png",
        "SHELF":"house_shelf1.png", "DRESSER":"house_wardrobe1.png",
        "VANITY":"house_vanity1.png", "STOOL":"house_stool1.png",
        "TABLE":"table.png", "FLOOR":"building1_floor1.png",
        "INTERIOR WALL":"house5_wall1.png", "DOOR":"house5_door1.png"
    }
    for raw_name in indoor_build_textures.keys():
        var build_name := String(raw_name)
        if structure_textures.has(build_name):
            continue
        var source_path := "res://assets/source_0_8_11/tiles/buildings/%s" % String(indoor_build_textures[raw_name])
        if ResourceLoader.exists(source_path):
            structure_textures[build_name] = load(source_path)
    # Match the downstairs brown vertical-plank back wall, including legacy builds.
    structure_textures["INTERIOR WALL"] = SOURCE_HOUSE5_WALL
    var doll_texture := "res://assets/source_0_8_11/tiles/pokedoll1.png"
    if ResourceLoader.exists(doll_texture):
        for doll in ["PICHU DOLL", "DUSKULL DOLL", "SKITTY DOLL", "JIGGLYPUFF DOLL"]:
            if not structure_textures.has(doll):
                structure_textures[doll] = load(doll_texture)
    environment_system = WorldEnvironmentSystem.new()
    environment_system.name = "WorldEnvironmentSystem"
    add_child(environment_system)
    environment_system.configure(self)

var generation_error := ""
var _accepted_exact_result: Dictionary = {}

func generate_world(
        seed_value: int, size_index: int = 1, prefer_saved_cache: bool = false
    ) -> void:
    generation_error = ""
    var previous_gameplay_enabled := gameplay_enabled
    gameplay_enabled = false
    if exact_world_mode:
        var normalized_seed: int = absi(seed_value)
        if normalized_seed == 0: normalized_seed = 81102
        var accepted := await _prepare_exact_world(normalized_seed, clampi(size_index,0,MAP_SIZE_PRESETS.size()-1), prefer_saved_cache)
        if accepted.is_empty() or accepted.has("generation_error"):
            generation_error = String(accepted.get("generation_error", "World generation failed. Please try again."))
            gameplay_enabled = previous_gameplay_enabled
            return
        _accepted_exact_result = accepted
    generated = false
    gameplay_enabled = false

    map_size_index = clampi(size_index, 0, MAP_SIZE_PRESETS.size() - 1)
    var selected_size: Vector2i = MAP_SIZE_PRESETS[map_size_index]
    map_w = selected_size.x
    map_h = selected_size.y
    spawn_cell = Vector2i(map_w / 2, map_h / 2)

    if player.has_method("set_streamed_overworld_depth"):
        player.call("set_streamed_overworld_depth", exact_world_mode)

    world_seed = abs(seed_value)
    if world_seed == 0:
        world_seed = 81102

    await _clear_generated_world()
    # FastNoiseLite belongs only to the old bounded compatibility generator.
    # The exact Java path does not use noise frequency, octaves, or a radial
    # falloff, so do not let those settings affect a normal new world.
    if not exact_world_mode:
        _configure_noise()
    generation_progress.emit(
        0.90 if exact_world_mode else 0.03,
        "Preparing world..." if exact_world_mode else "Creating %dx%d world..." % [map_w, map_h]
    )
    await get_tree().process_frame

    terrain.clear()
    biomes.clear()
    blocked.clear()
    built_house_displaced_blocks.clear()
    built_house_blocks_stale = false
    tall_grass.clear()
    landmarks.clear()
    resource_objects.clear()
    ground_sprites.clear()
    ground_collisions.clear()
    removed_resources.clear()
    terrain_changes.clear()
    built_structures.clear()
    deployed_pokemon.clear()
    build_mode_active = false
    build_selection_index = 0
    build_preview_sprite = null
    source_plant_farms.clear()
    interior_map_cache_key.clear()
    interior_map_bounds_key.clear()
    interior_map_cache = null
    planting_item = ""
    active_field_move = ""
    active_field_species = ""
    active_field_pokemon.clear()
    dig_selection_index = 0
    world_elapsed_seconds = 0.0
    repel_until_elapsed = 0.0
    grass_exclusion.clear()
    flower_cells.clear()
    animated_flowers.clear()
    flower_anim_time = 0.0
    encounter_count = 0
    encounter_grace_remaining = 0.0
    discovered_cells.clear()
    dropped_items().restore({})
    map_art_revision += 1
    wild_pokemon.clear()
    sand_trap_ids.clear()
    wild_eggs.clear()
    next_wild_id = 1
    next_deployed_id = 1
    ecology_accumulator = 0.0
    follower_pokemon.clear()
    follower_sprite = null
    follower_move_tween = null
    follower_walk_phase = 0
    follower_cell = Vector2i(-2147483648, -2147483648)
    field_helper_pokemon.clear()
    field_helper_sprite = null
    field_helper_cell = Vector2i(-2147483648, -2147483648)
    work_trainer_sprite = null
    work_trail.clear()
    player.sprite.visible = true
    if is_instance_valid(fly_shadow):
        fly_shadow.queue_free()
    fly_shadow = null
    if player.has_method("set_field_visual_offset"):
        player.call("set_field_visual_offset", Vector2.ZERO)
    reflection_layer = null
    tide_initialized = false
    low_tide_active = false
    tide_target_low = false
    tide_transition_tiles.clear()
    tide_transition_bands.clear()
    tide_topology_bands.clear()
    tide_transition_band_index = 0
    tide_transition_accumulator = 0.0
    if is_instance_valid(tide_wade_ripple):
        tide_wade_ripple.queue_free()
    tide_wade_ripple = null
    if is_instance_valid(tide_wade_base):
        tide_wade_base.queue_free()
    tide_wade_base = null
    deployed_recall_candidate = Vector2i(-2147483648, -2147483648)
    deployed_recall_candidate_msec = 0
    pending_egg_record.clear()
    burrow_busy = false
    pending_encounter_record.clear()
    pending_battle_context.clear()
    event_progress = {
        "completed": {}, "trainer_defeated": {},
        "keystone_life_force": {}, "regis_caught": [],
        "mewtwo_defeated_day": -1, "fossil_machine_powered": false,
        "biome_first_entries": {}
    }
    event_npcs.clear()
    source_event_collisions.clear()
    ghost_step_countdown = -1
    last_event_day = 0
    biome_centers.clear()
    route_cells.clear()
    source_landmarks.clear()
    source_tiles.clear()
    habitat_routes.clear()
    source_area_entries.clear()
    source_area_rects.clear()
    source_area_layers.clear()
    source_area_origins.clear()
    source_layer_area_ids.clear()
    generated_source_interior_plans.clear()
    interior_interactables.clear()
    source_interior_upper_sprites.clear()
    source_interior_mutations.clear()
    source_mine_pokemon.clear()
    built_house_rooms_seen.clear()
    built_house_interior_cells.clear()
    built_house_paintable_walls.clear()
    built_house_paint_sprites.clear()
    built_house_decoration_sprites.clear()
    built_house_floor_origins.clear()
    built_house_floor_tiles.clear()
    built_house_decorations.clear()
    built_house_void_collisions.clear()
    built_house_room_size = Vector2i.ZERO
    built_house_floor_capacity = 1
    active_built_house_door = Vector2i(-2147483648, -2147483648)
    built_house_interior_origin = Vector2i.ZERO
    built_house_origins.clear()
    built_house_exit_doors.clear()
    respawn_house.clear()
    active_regi_pedestal_cell = Vector2i(-2147483648, -2147483648)
    exact_world = null
    exact_world_bounds = Rect2i()
    area_return_cells.clear()
    active_area_id = "OVERWORLD"
    water_sprites.clear()
    water_anim_time = 0.0
    water_frame = 0
    tide_initialized = false
    low_tide_active = false
    last_tide_message_seconds = -TIDE_MESSAGE_COOLDOWN_SECONDS

    var ground_layer := Node2D.new()
    ground_layer.name = "GroundLayer"
    ground_layer.z_index = -20
    add_child(ground_layer)
    move_child(ground_layer, 0)

    var decor_layer := Node2D.new()
    decor_layer.name = "DecorLayer"
    decor_layer.z_index = 0
    add_child(decor_layer)

    var route_layer := Node2D.new()
    route_layer.name = "RouteLayer"
    route_layer.z_index = -10
    add_child(route_layer)

    var grass_layer := Node2D.new()
    grass_layer.name = "TallGrassLayer"
    grass_layer.z_index = 0
    add_child(grass_layer)

    var grass_front_layer := Node2D.new()
    grass_front_layer.name = "TallGrassFrontLayer"
    grass_front_layer.z_index = 0
    add_child(grass_front_layer)

    var landmark_layer := Node2D.new()
    landmark_layer.name = "LandmarkLayer"
    landmark_layer.z_index = 0
    add_child(landmark_layer)

    var wild_layer := Node2D.new()
    wild_layer.name = "WildPokemonLayer"
    wild_layer.z_index = 0
    add_child(wild_layer)

    var egg_layer := Node2D.new()
    egg_layer.name = "WildEggLayer"
    egg_layer.z_index = 0
    add_child(egg_layer)

    var collision_body := StaticBody2D.new()
    collision_body.name = "WorldCollision"
    collision_body.collision_layer = 1
    collision_body.collision_mask = 1
    add_child(collision_body)

    if exact_world_mode:
        await _generate_exact_live_world(
            world_seed, map_size_index, ground_layer, decor_layer,
            collision_body, prefer_saved_cache
        )
        return

    # M44 routes all world output through the Java-port plan. The migration is
    # intentionally isolated here so unrelated UI/battle/control code remains
    # unchanged while individual generator stages gain parity fixtures.
    generation_progress.emit(0.08, "Running world generator...")
    await get_tree().process_frame
    var source_plan: Dictionary = SourceWorldGenerator.generate(
        map_w, map_h, world_seed, map_size_index
    )
    terrain = source_plan.get("terrain", [])
    biomes = source_plan.get("biomes", [])
    source_tiles = source_plan.get("source_tiles", {})
    habitat_routes = source_plan.get("habitat_routes", {})
    route_cells = source_plan.get("route_cells", {})
    biome_centers = source_plan.get("biome_centers", {})
    source_landmarks = source_plan.get("landmarks", {})
    generated_source_interior_plans = SourceInteriorGenerator.from_source_layers(
        source_plan.get("source_interiors", []),
        source_plan.get("source_interior_pokemon", [])
    )
    generation_progress.emit(0.52, "Source terrain and habitats formed...")
    await get_tree().process_frame

    _find_safe_spawn()
    _reserve_source_world_cells()
    _discover_around(spawn_cell, DISCOVERY_RADIUS)

    # Render only after paths and landmark approaches have been carved.
    for y in range(map_h):
        for x in range(map_w):
            var kind: int = terrain[y][x]
            _add_ground_tile(ground_layer, x, y, kind, String(biomes[y][x]))
            if kind == 0:
                var water_cell := Vector2i(x, y)
                blocked[water_cell] = true
                ground_collisions[water_cell] = _add_block_collision(
                    collision_body, x, y
                )
            else:
                var source_cell := Vector2i(x, y)
                var source_tile: Dictionary = source_tiles.get(source_cell, {})
                if bool(source_tile.get("solid", false)):
                    blocked[source_cell] = true
                    grass_exclusion[source_cell] = true
                    ground_collisions[source_cell] = _add_block_collision(
                        collision_body, x, y
                    )
        if y % 8 == 0:
            generation_progress.emit(
                0.42 + 0.14 * (float(y) / float(map_h)),
                "Rendering source world..."
            )
            await get_tree().process_frame

    _render_routes(route_layer)

    generation_progress.emit(0.60, "Growing forests and tall grass...")
    await get_tree().process_frame

    for y in range(2, map_h - 2):
        for x in range(2, map_w - 2):
            var cell := Vector2i(x, y)
            if terrain[y][x] == 0:
                continue
            if route_cells.has(cell) or grass_exclusion.has(cell):
                continue
            if Vector2(x - spawn_cell.x, y - spawn_cell.y).length() < 6.0:
                continue

            _decorate_source_cell(decor_layer, collision_body, cell)

        if y % 8 == 0:
            generation_progress.emit(
                0.60 + 0.15 * (float(y) / float(map_h)),
                "Growing trees..."
            )
            await get_tree().process_frame

    _generate_tall_grass_patches(grass_layer, grass_front_layer)
    generation_progress.emit(0.84, "Planting tall grass...")
    await get_tree().process_frame

    _place_source_landmarks(landmark_layer, collision_body)
    _place_landmarks(landmark_layer, collision_body)
    await _build_source_interiors(collision_body)
    generation_progress.emit(0.90, "Placing landmarks...")
    await get_tree().process_frame

    _spawn_wild_pokemon()
    # Eggs enter the world through nearby compatible parents, as in Java.
    generation_progress.emit(0.96, "Populating biome habitats...")
    await get_tree().process_frame

    player.position = _cell_center(spawn_cell)
    player.visible = true
    _configure_camera()
    last_player_cell = _player_cell()

    generated = true
    gameplay_enabled = true
    generation_progress.emit(1.0, "World ready!")
    generation_finished.emit()

func _prepare_exact_world(seed_value: int, size_index: int, prefer_saved_cache: bool) -> Dictionary:
    var exact_result: Dictionary = {}
    if prefer_saved_cache:
        generation_progress.emit(0.08, "Loading saved world...")
        await get_tree().process_frame
        var cache_reader := Thread.new()
        var cache_error := cache_reader.start(
            SourceWorldCache.load_result.bind(seed_value, size_index))
        if cache_error == OK:
            while cache_reader.is_alive():
                await get_tree().process_frame
            exact_result = cache_reader.wait_to_finish()
        else:
            push_warning("Saved-world cache worker unavailable; regenerating world.")

    if exact_result.is_empty():
        generation_progress.emit(0.08, "Reproducing GenIsland1 source world...")
        await get_tree().process_frame
        var generation_thread := Thread.new()
        var start_error := generation_thread.start(
            Callable(self, "_run_exact_generation_job").bind(seed_value, size_index)
        )
        if start_error != OK:
            return {"generation_error":"Could not start world generation. Please try again."}
        var pulse := 0.08
        var exact_started_at := Time.get_ticks_msec()
        var expected_seconds: Array[float] = [90.0, 130.0, 180.0, 240.0, 310.0]
        while generation_thread.is_alive():
            var elapsed_seconds := (
                Time.get_ticks_msec() - exact_started_at
            ) / 1000.0
            var expected := expected_seconds[clampi(
                size_index, 0, expected_seconds.size() - 1
            )]
            pulse = 0.08 + 0.80 * minf(elapsed_seconds / expected, 0.99)
            generation_progress.emit(
                pulse,
                "Building the original full landmass... %ds" % int(elapsed_seconds)
            )
            await get_tree().create_timer(0.10).timeout
        exact_result = generation_thread.wait_to_finish()
        if exact_result.has("generation_error"): return exact_result
        if not exact_result.is_empty():
            generation_progress.emit(0.89, "Preparing fast saved-game loading...")
            await get_tree().process_frame
            # Serialization/compression is data-only. Keep the window and
            # Android event loop responsive throughout the first cache write.
            var cache_writer := Thread.new()
            var cache_error := cache_writer.start(
                SourceWorldCache.save_result.bind(seed_value, size_index, exact_result))
            if cache_error == OK:
                while cache_writer.is_alive():
                    await get_tree().process_frame
                cache_writer.wait_to_finish()
            else:
                push_warning("Saved-world cache worker unavailable; cache was not written.")
    if exact_result.is_empty():
        return {"generation_error":"World generation returned no data. Please try again."}
    return exact_result

func _generate_exact_live_world(
        seed_value: int,
        size_index: int,
        ground_layer: Node2D,
        decor_layer: Node2D,
        collision_body: StaticBody2D,
        prefer_saved_cache: bool
    ) -> void:
    var exact_result := _accepted_exact_result
    _accepted_exact_result = {}
    var adapter_job := Thread.new()
    var adapter_work := func(): return SourceExactWorldAdapter.from_generator_result(exact_result, SourceJavaRandom.new(seed_value ^ 0x535041574E))
    if adapter_job.start(adapter_work) == OK:
        while adapter_job.is_alive(): await get_tree().process_frame
        exact_world = adapter_job.wait_to_finish()
    else:
        exact_world = adapter_work.call()
    _repair_orphaned_large_trees()
    exact_world_bounds = exact_world.bounds()
    map_w = exact_world_bounds.size.x
    map_h = exact_world_bounds.size.y
    spawn_cell = exact_world.spawn_cell
    source_tiles = exact_world.tiles
    generated_source_interior_plans = exact_world.interior_plans

    # Put the tracked player at the source-selected spawn before configuring
    # either streamer. Their first visible/collision windows must be centered
    # on the real spawn rather than the scene's temporary origin.
    player.position = _cell_center(spawn_cell)
    if player.has_method("set_streamed_overworld_depth"):
        player.call("set_streamed_overworld_depth", true)

    var base_stream = SOURCE_CHUNK_TILE_LAYER_SCRIPT.new()
    base_stream.name = "ExactBaseTileStream"
    base_stream.z_index = -20
    ground_layer.add_child(base_stream)
    base_stream.configure(source_tiles, player, false, TILE, true, true)
    await base_stream.build_resident_async()
    var upper_stream = SOURCE_CHUNK_TILE_LAYER_SCRIPT.new()
    upper_stream.name = "ExactUpperTileStream"
    upper_stream.z_index = 2
    decor_layer.add_child(upper_stream)
    upper_stream.configure(source_tiles, player, true, TILE, true, true)
    await upper_stream.build_resident_async()
    _setup_normal_grass_front_overlay()
    _setup_savanna_tree_front_overlay()
    if "source_walked_open_gates" in self: get("source_walked_open_gates").clear()
    var canopy := preload("res://scripts/tree_canopy_overlay.gd").new()
    canopy.name = "TreeCanopyOverlay"
    canopy.world = self
    canopy.z_index = 106
    canopy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(canopy)

    reflection_layer = SourceReflectionLayerScript.new()
    reflection_layer.name = "ExactReflectionLayer"
    reflection_layer.z_index = -19
    add_child(reflection_layer)
    reflection_layer.configure(self, exact_world, player)

    var collision_stream := SourceChunkCollisionStreamer.new()
    collision_stream.name = "ExactCollisionStream"
    add_child(collision_stream)
    collision_stream.configure(source_tiles, player, TILE, true, true)
    await collision_stream.build_initial_async()
    SourceTile.resident_changed_cells.clear()
    await _build_source_interiors(collision_body)
    _register_exact_exterior_interactables()
    var source_pokemon_records := exact_world.pokemon_cell_records()
    await _spawn_exact_source_pokemon(source_pokemon_records, true)
    await _spawn_extra_biome_pokemon(source_pokemon_records, true)
    _spawn_exact_burrowed_pokemon(exact_world.burrowed_cell_records())
    _discover_around(spawn_cell, DISCOVERY_RADIUS)

    player.visible = true
    _configure_camera()
    last_player_cell = _player_cell()
    # New worlds seed their first renewable Dig sites immediately. Saved
    # worlds restore their mutations after generation, then refresh for the
    # saved day in _refresh_daily_events(); do not create orphaned sites first.
    if not prefer_saved_cache:
        await _refresh_biome_dig_sites(true)
        SourceForestBoss.install(self)
        await preload("res://scripts/biome_megas.gd").prepare_load(self)
        preload("res://scripts/biome_megas.gd").install(self)
    # Prepare the coast topology before gameplay: the first full-world scan
    # must not block movement or the first focus return after loading.
    _update_tide_state(false, 0.0)
    generated = true
    gameplay_enabled = true
    generation_progress.emit(1.0, "Exact source world ready!")
    generation_finished.emit()

func _run_exact_generation_job(seed_value: int, size_index: int) -> Dictionary:
    return SourceWorldGenerator.generate_exact_source_world(seed_value, size_index)

func _register_exact_exterior_interactables() -> void:
    var unown_generated_signs: Array = []
    for plan in generated_source_interior_plans:
        var layer_index := int(plan.get("layer_index", -1))
        var transitions := plan.get("transitions", {}) as Dictionary
        var bounds: Rect2i = plan.get("source_bounds", Rect2i())
        for raw_local_cell in transitions:
            var transition := transitions[raw_local_cell] as Dictionary
            if not bool(transition.get("exit_overworld", false)):
                continue
            var source_cell: Vector2i = transition.get(
                "source_cell", bounds.position + Vector2i(raw_local_cell)
            )
            var exterior_tile := exact_world.tile_at(source_cell)
            var exterior_name := "" if exterior_tile == null else exterior_tile.name + " " + exterior_tile.name_upper
            if exterior_tile != null and ("stairs" in exterior_name or "door" in exterior_name or "entrance" in exterior_name):
                interior_interactables[source_cell] = "GOTO_SOURCE_LAYER:%d:%d:%d" % [
                    layer_index, source_cell.x, source_cell.y
                ]
    for raw_tile in source_tiles.values():
        var tile := raw_tile as SourceTile
        if tile == null:
            continue
        var cell := SourceWorldData.pixel_to_cell(tile.position)
        if tile.has_item.begins_with("trainer_tips"):
            unown_generated_signs.append(cell)
            var tip_index := posmod(cell.x * 31 + cell.y * 17, SourceEventData.TRAINER_TIPS.size())
            interior_interactables[cell] = "TRAINER_TIP:%d:%d" % [
                tip_index, 1 if tile.has_item == "trainer_tips_unown" else 0
            ]
        elif not tile.has_item.is_empty():
            interior_interactables[cell] = "ITEM:%s:%d" % [
                tile.has_item, tile.has_item_amount
            ]
        if tile.name_upper == "odd_keystone2":
            interior_interactables[cell] = "ODD_KEYSTONE"
        elif tile.name_upper == "pokedoll1":
            interior_interactables[cell] = "POKE_DOLL"
        elif tile.name_upper == "pokedoll1_banette":
            interior_interactables[cell] = "SPECIAL:doll_banette"
        elif tile.name_upper == "pokedoll1_mimikyu":
            interior_interactables[cell] = "SPECIAL:doll_mimikyu"
        elif tile.name_upper == "gravestone2":
            interior_interactables[cell] = "GRAVESTONE"
        if tile.name_upper == "pkmnmansion_ext_locked":
            interior_interactables[cell] = "MANSION_LOCK:%d:%d" % [cell.x, cell.y]
        var target_layer := -1
        if tile.name == "cave1_door1":
            target_layer = 90
        elif tile.name == "pkmnmansion_ext_door" or tile.name_upper == "pkmnmansion_ext_door":
            # The Oasis fossil lab deliberately reuses pkmnmansion exterior
            # artwork. Route identity is therefore required: oasis1 enters the
            # fossil lab, while the large snow/deep-forest Mansion enters the
            # pkmnmansion1 alias. Treating every shared door as MANSION_0 was
            # the source of the small face-like "mansion" regression.
            var exterior_route_name := ""
            if tile.route_belongs_to != null:
                exterior_route_name = tile.route_belongs_to.name.to_lower()
            interior_interactables[cell] = (
                "GOTO_AREA:FOSSIL_LAB"
                if exterior_route_name == "oasis1"
                else "GOTO_AREA:MANSION_0"
            )
            continue
        if target_layer >= 0:
            interior_interactables[cell] = "GOTO_SOURCE_LAYER:%d:%d:%d" % [
                target_layer, cell.x, cell.y
            ]

    _clear_door_fronts()
    if exact_world != null:
        exact_world.set_meta("unown_generated_signs", unown_generated_signs)

## Nothing may stand in front of a door: generation can leave a cliff edge,
## ledge, rock, tree, berry tree or bush there (seen at the mansion), and
## players should never have to think of CUT or DIG to get in. Doors face down
## the screen (the map is flipped from the source's y-up layout), so the tile
## below a door is its front. Every player regenerates the same map, so all
## players make the same change.
func _clear_door_fronts() -> void:
    if exact_world == null:
        return
    for raw_tile in exact_world.tiles.values():
        var door := raw_tile as SourceTile
        if door == null:
            continue
        var names := door.name + " " + door.name_upper
        if "door" not in names and door.name_upper != "pkmnmansion_ext_locked":
            continue
        var door_cell := SourceWorldData.pixel_to_cell(door.position)
        var building := (door.name_upper if not door.name_upper.is_empty() else door.name).get_slice("_", 0)
        var front_cell := door_cell + Vector2i(0, 1)
        var front := exact_world.tile_at(front_cell)
        if front == null or _part_of_building(front, building):
            continue
        var ground := door.name if not door.name.is_empty() and "door" not in door.name else "sand1"
        _clear_door_tile(front, ground)
        # Big trees, berry trees and savanna trees cover more than one tile:
        # remove the rest of anything that still blocks the front tile.
        if exact_world.is_solid(front_cell):
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    var near := exact_world.tile_at(front_cell + Vector2i(dx, dy))
                    if near == null or near == front or near == door or _part_of_building(near, building):
                        continue
                    if near.name_upper.is_empty() and not near.is_solid:
                        continue
                    _clear_door_tile(near, near.name if not (near.is_solid or near.is_ledge or near.is_water or near.is_lava) else ground)

func _part_of_building(tile: SourceTile, building: String) -> bool:
    return not building.is_empty() and (tile.name_upper.begins_with(building) or tile.name.begins_with(building))

func _clear_door_tile(tile: SourceTile, ground: String) -> void:
    var base_blocks := tile.is_ledge or tile.is_water or tile.is_lava or \
        SourceWorldData.is_upper_solid(tile.name) or SourceWorldData.ledge_direction(tile.name) != Vector2i.ZERO
    tile.set_names(ground if base_blocks else tile.name, "")
    if tile.is_solid or tile.is_cuttable or tile.is_headbuttable:
        tile.set_names(ground, "")
    tile.has_item = ""
    tile.has_item_amount = 0

func _spawn_location_npcs() -> void:
    if not exact_world_mode or exact_world == null:
        return
    var layer := get_node_or_null("LandmarkLayer") as Node2D
    var collision_body := get_node_or_null("WorldCollision") as StaticBody2D
    if layer == null or collision_body == null:
        return
    var wanted := ["FOREST", "SAVANNA", "MOUNTAIN", "DESERT", "SNOW", "WOODED_LAKE"]
    var candidates: Dictionary = {}
    for raw_tile in source_tiles.values():
        var tile := raw_tile as SourceTile
        if tile == null or tile.is_solid or tile.is_water or not tile.name_upper.is_empty():
            continue
        var cell := SourceWorldData.pixel_to_cell(tile.position)
        var biome := _source_biome_for_tile(tile)
        if biome == "DEEP_FOREST":
            biome = "FOREST"
        elif biome == "OASIS" or biome == "VOLCANO":
            biome = "DESERT"
        if biome not in wanted or candidates.has(biome):
            continue
        if Vector2(cell - spawn_cell).length_squared() < 900.0:
            continue
        if interior_interactables.has(cell) or exact_world.pokemon.has(tile.position):
            continue
        candidates[biome] = tile
        if candidates.size() == wanted.size():
            break
    for index in range(wanted.size()):
        var biome := String(wanted[index])
        var tile := candidates.get(biome) as SourceTile
        if tile == null:
            continue
        var cell := SourceWorldData.pixel_to_cell(tile.position)
        var trainer_id := "trainer_%s" % biome.to_lower()
        var route_level := 5 if tile.route_belongs_to == null else tile.route_belongs_to.level
        var context := SourceEventData.trainer_spec(biome, route_level, trainer_id)
        var atlas := AtlasTexture.new()
        atlas.atlas = SOURCE_NPC_SHEET
        atlas.region = Rect2((index % 6) * 16, 0, 16, 16)
        var sprite := Sprite2D.new()
        sprite.texture = atlas
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.position = _cell_center(cell)
        sprite.z_as_relative = false
        sprite.z_index = _depth_z(cell, 18)
        layer.add_child(sprite)
        var collision := _add_landmark_collision(collision_body, cell.x, cell.y)
        blocked[cell] = true
        interior_interactables[cell] = "TRAINER:%s" % trainer_id
        event_npcs[trainer_id] = {
            "cell": cell, "sprite": sprite, "collision": collision,
            "context": context
        }

func _find_entry_layer_for_source_cell(
        source_cell: Vector2i, minimum_layer: int, maximum_layer: int
    ) -> int:
    var fallback := -1
    for plan in generated_source_interior_plans:
        var layer_index := int(plan.get("layer_index", -1))
        if layer_index < minimum_layer or layer_index > maximum_layer:
            continue
        if fallback < 0 and not (plan.get("entries", []) as Array).is_empty():
            fallback = layer_index
        var source_to_local := plan.get("source_to_local", {}) as Dictionary
        if source_to_local.has(source_cell):
            return layer_index
    return fallback

func _spawn_exact_source_pokemon(records: Array[Dictionary], spread: bool = false) -> void:
    var spawn_deadline := Time.get_ticks_usec() + 3000
    for record in records:
        if spread and Time.get_ticks_usec() >= spawn_deadline:
            await get_tree().process_frame
            spawn_deadline = Time.get_ticks_usec() + 3000
        var species := String(record.get("name", "")).to_lower()
        var cell: Vector2i = record.get("cell", Vector2i.ZERO)
        if species.is_empty() or not exact_world.contains_cell(cell):
            continue
        var tile := exact_world.tile_at(cell)
        var home_biome := "OCEAN" if tile == null else _source_biome_for_tile(tile)
        _add_wild_pokemon(
            species, int(record.get("level", 2)), cell, home_biome, 0, record
        )

func _spawn_extra_biome_pokemon(_records: Array[Dictionary], spread: bool = false) -> void:
    var spawn_deadline := Time.get_ticks_usec() + 3000
    # New-world companions replace the old partial 50% density pass.
    # Preserve authored encounters and only create valid breeding partners.
    var occupied: Dictionary = {}
    for id in wild_pokemon:
        occupied[wild_pokemon[id].cell] = id
    var initial_ids := wild_pokemon.keys()
    var paired: Dictionary = {}
    var offsets: Array[Vector2i] = []
    for radius in range(1, MATE_BOND_RADIUS + 1):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) == radius:
                    offsets.append(Vector2i(x, y))
    for id in initial_ids:
        if spread and Time.get_ticks_usec() >= spawn_deadline:
            await get_tree().process_frame
            spawn_deadline = Time.get_ticks_usec() + 3000
        if paired.has(id): continue
        var original: Dictionary = wild_pokemon[id]
        var species := String(original.species)
        var groups: Array = original.get("egg_groups", [])
        var gender := String(original.get("gender", "unknown"))
        if groups.has("EGG_NONE") or groups.has("EGG_DITTO") or gender == "unknown" or bool(original.get("burrowed", false)) or bool(original.get("behavior", {}).get("stationary", false)):
            continue
        var origin: Vector2i = original.cell
        # Use an existing adjacent compatible animal before adding another.
        var partner_id := -1
        for offset in offsets:
            var nearby_id := int(occupied.get(origin + offset, -1))
            if nearby_id >= 0 and not paired.has(nearby_id) and PokemonEcology.can_mate(original, wild_pokemon[nearby_id]):
                partner_id = nearby_id
                break
        if partner_id < 0:
            var origin_tile := exact_world.tile_at(origin)
            var route := "" if origin_tile == null or origin_tile.route_belongs_to == null else origin_tile.route_belongs_to.name
            var partner_gender := "male" if gender == "female" else "female"
            var partner_species := ""
            var candidates: Array[String] = [species]
            for candidate_species in SourceRouteData.allowed_pokemon(route):
                if not candidates.has(String(candidate_species)): candidates.append(String(candidate_species))
            for candidate_species in candidates:
                var info := PokemonData.info(candidate_species)
                var ratio := String(info.get("gender_ratio", "GENDER_UNKNOWN"))
                if ratio == "GENDER_UNKNOWN" or (ratio == "GENDER_F0" and partner_gender == "female") or (ratio == "GENDER_F100" and partner_gender == "male"): continue
                if PokemonData.texture(candidate_species, "overworld") == null: continue
                var test_partner := PokemonEcology.ensure_record({"species":candidate_species,"gender":partner_gender}, rng)
                if PokemonEcology.can_mate(original, test_partner):
                    partner_species = candidate_species
                    break
            if partner_species.is_empty(): continue
            for offset in offsets:
                var candidate := origin + offset
                if occupied.has(candidate) or wild_eggs.has(candidate) or deployed_pokemon.has(candidate) or not _pokemon_can_move_between(partner_species, origin, candidate): continue
                var tile := exact_world.tile_at(candidate)
                if tile == null or tile.route_belongs_to == null or tile.route_belongs_to.name != route: continue
                var new_id := next_wild_id
                _add_wild_pokemon(partner_species, int(original.level), candidate, String(original.home_biome), 0, {"gender":partner_gender, "generation":original.get("source_record", {}).get("generation", "")})
                if not wild_pokemon.has(new_id): continue
                occupied[candidate] = new_id
                partner_id = new_id
                break
            if partner_id < 0:
                # An isolated authored cell may have no room for two actors.
                # Find two adjacent cells in the SAME source route, keeping
                # both the terrain and the encounter species list intact.
                for radius in range(1, 17):
                    if partner_id >= 0: break
                    for y in range(-radius, radius + 1):
                        if partner_id >= 0: break
                        for x in range(-radius, radius + 1):
                            if maxi(absi(x), absi(y)) != radius: continue
                            var first := origin + Vector2i(x, y)
                            if occupied.has(first) or wild_eggs.has(first) or deployed_pokemon.has(first) or not _pokemon_can_move_between(species, origin, first): continue
                            var first_tile := exact_world.tile_at(first)
                            if first_tile == null or first_tile.route_belongs_to == null or first_tile.route_belongs_to.name != route: continue
                            for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                                var second: Vector2i = first + direction
                                if occupied.has(second) or wild_eggs.has(second) or deployed_pokemon.has(second) or not _pokemon_can_move_between(partner_species, origin, second): continue
                                var second_tile := exact_world.tile_at(second)
                                if second_tile == null or second_tile.route_belongs_to == null or second_tile.route_belongs_to.name != route: continue
                                var new_id := next_wild_id
                                _add_wild_pokemon(partner_species, int(original.level), second, String(original.home_biome), 0, {"gender":partner_gender, "generation":original.get("source_record", {}).get("generation", "")})
                                if not wild_pokemon.has(new_id): continue
                                occupied.erase(origin)
                                occupied[first] = id
                                occupied[second] = new_id
                                original.cell = first
                                var sprite := original.get("sprite") as Sprite2D
                                if is_instance_valid(sprite): sprite.position = _cell_center(first)
                                partner_id = new_id
                                break
                            if partner_id >= 0: break
        if partner_id >= 0:
            var partner: Dictionary = wild_pokemon[partner_id]
            original["mate_id"] = partner.ecology_id
            partner["mate_id"] = original.ecology_id
            wild_pokemon[id] = original
            wild_pokemon[partner_id] = partner
            paired[id] = true
            paired[partner_id] = true

func _spawn_exact_burrowed_pokemon(records: Array[Dictionary]) -> void:
    for record in records:
        var cell: Vector2i = record.get("cell", Vector2i.ZERO)
        if not exact_world.contains_cell(cell):
            continue
        var tile := exact_world.tile_at(cell)
        var home_biome := "DESERT" if tile == null else _source_biome_for_tile(tile)
        _add_wild_pokemon(
            "trapinch", int(record.get("level", 22)), cell,
            home_biome, 0, record
        )

func _spawn_exact_wild_eggs() -> void:
    # Kept for old fixture callers. Java does not seed unrelated random eggs;
    # eggs are laid by compatible nearby Pokemon during normal ecology upkeep.
    pass

func _configure_noise() -> void:
    terrain_noise.seed = world_seed
    terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    # Slight scale adjustment keeps large worlds from feeling like stretched
    # copies of small ones while retaining the same overall PokeWilds style.
    var size_scale := lerpf(1.10, 0.82, float(map_size_index) / 4.0)
    terrain_noise.frequency = 0.052 * size_scale
    terrain_noise.fractal_octaves = 4
    terrain_noise.fractal_gain = 0.50

    detail_noise.seed = world_seed + 197
    detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    detail_noise.frequency = 0.12 * size_scale
    detail_noise.fractal_octaves = 2

    biome_noise.seed = world_seed + 4099
    biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    biome_noise.frequency = 0.035 * size_scale
    biome_noise.fractal_octaves = 2

    rng.seed = world_seed
    biome_order = WORLD_BIOMES.duplicate()
    for index in range(biome_order.size() - 1, 0, -1):
        var swap_index := rng.randi_range(0, index)
        var held := biome_order[index]
        biome_order[index] = biome_order[swap_index]
        biome_order[swap_index] = held
    biome_regions = WorldParity.build_biome_regions(
        map_w, map_h, biome_order, rng
    )

func _terrain_kind(x: int, y: int) -> int:
    return WorldParity.terrain_kind(
        x, y, map_w, map_h, terrain_noise, detail_noise
    )

func _biome_kind(x: int, y: int, terrain_kind: int) -> String:
    return WorldParity.biome_kind(
        x, y, terrain_kind, map_w, map_h, biome_regions,
        biome_noise, detail_noise
    )

func _add_ground_tile(
        parent: Node2D,
        x: int,
        y: int,
        kind: int,
        biome: String
    ) -> void:
    var sprite := Sprite2D.new()
    sprite.position = _cell_center(Vector2i(x, y))
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

    var source_tile: Dictionary = source_tiles.get(Vector2i(x, y), {})
    var source_texture := SourceWorldData.texture_for(
        String(source_tile.get("base", ""))
    )
    if source_texture != null:
        sprite.texture = source_texture
        sprite.centered = false
        sprite.position = Vector2(x * TILE, y * TILE)
        if source_texture.get_width() > TILE or source_texture.get_height() > TILE:
            sprite.region_enabled = true
            sprite.region_rect = Rect2(0, 0, TILE, TILE)
        parent.add_child(sprite)
        ground_sprites[Vector2i(x, y)] = sprite
        return

    match kind:
        0:
            sprite.texture = WATER
            sprite.region_enabled = true
            sprite.region_rect = Rect2(0, 0, TILE, TILE)
            water_sprites.append(sprite)
        1:
            sprite.texture = SAND
        _:
            sprite.texture = _ground_texture_for_biome(biome)

    parent.add_child(sprite)
    ground_sprites[Vector2i(x, y)] = sprite

func _decorate_source_cell(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    var source_tile: Dictionary = source_tiles.get(cell, {})
    var upper_name := String(source_tile.get("upper", ""))
    if upper_name.is_empty():
        return
    var texture := SourceWorldData.texture_for(upper_name)
    if texture == null:
        return
    # A stool is walked over like any floor tile; A while facing it sits.
    var solid := "stool" not in upper_name and bool(source_tile.get("solid", SourceWorldData.is_upper_solid(upper_name)))
    var resource_kind := ""
    if "tree" in upper_name:
        resource_kind = "tree"
    elif "rock" in upper_name:
        resource_kind = "rock"
    elif "cactus" in upper_name:
        resource_kind = "cactus"
    elif "bush" in upper_name:
        resource_kind = "bush"
    _add_object(
        parent,
        collision_body,
        cell.x,
        cell.y,
        texture,
        solid,
        texture.get_height() > TILE,
        "flower" in upper_name,
        resource_kind
    )
    if not resource_kind.is_empty() and resource_objects.has(cell):
        var resource_data: Dictionary = resource_objects[cell]
        resource_data["source_name"] = upper_name.to_lower().trim_suffix(".png")
        resource_objects[cell] = resource_data

func _ground_texture_for_biome(biome: String) -> Texture2D:
    match biome:
        "SAVANNA":
            return BIOME_SAVANNA
        "MOUNTAIN":
            return BIOME_MOUNTAIN
        "DESERT":
            return BIOME_DESERT
        "SNOW":
            return BIOME_SNOW
        "WOODED_LAKE":
            return BIOME_WOODED_LAKE
        _:
            return GRASS

func _decorate_biome_cell(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    var biome := biome_at(cell)
    var d := detail_noise.get_noise_2d(float(cell.x), float(cell.y))
    var roll := rng.randf()

    match biome:
        "FOREST":
            if d > 0.38 and roll < 0.18 and _tree_has_safe_ground(cell):
                _add_large_tree(parent, collision_body, cell)
            elif d > 0.14 and roll < 0.28:
                _add_bush(parent, collision_body, cell)
            elif d < -0.52 and roll < 0.15:
                _add_rock(parent, collision_body, cell)
            elif roll < 0.035:
                _add_flower_if_clear(parent, collision_body, cell)
        "DEEP_FOREST":
            if d > 0.10 and roll < 0.30 and _tree_has_safe_ground(cell):
                _add_large_tree(parent, collision_body, cell)
            elif roll < 0.38:
                _add_bush(parent, collision_body, cell)
            elif roll < 0.405:
                _add_flower_if_clear(parent, collision_body, cell)
        "SAVANNA":
            if d > 0.22 and roll < 0.055 and _tree_has_safe_ground(cell):
                _add_savanna_tree(parent, collision_body, cell)
            elif roll < 0.095:
                _add_bush(parent, collision_body, cell)
            elif roll < 0.125:
                _add_flower_if_clear(parent, collision_body, cell)
        "MOUNTAIN":
            if roll < 0.15:
                _add_rock(parent, collision_body, cell)
        "DESERT":
            if roll < 0.075:
                _add_object(
                    parent, collision_body, cell.x, cell.y,
                    BIOME_CACTUS, true, false, false, "bush"
                )
            elif roll < 0.145:
                _add_rock(parent, collision_body, cell)
        "SNOW":
            if d > 0.20 and roll < 0.065:
                _add_object(
                    parent, collision_body, cell.x, cell.y,
                    BIOME_TREE_SNOW, true, true, false, "tree"
                )
                # Compatibility tundra trees represent source tree4. Treat
                # them as large-yield trees, but tree4 remains directly CUTtable as in
                # the requested tundra behavior; it still gives the 2-7 LOG yield.
                if resource_objects.has(cell):
                    var snow_tree: Dictionary = resource_objects[cell]
                    snow_tree["large"] = true
                    snow_tree["source_name"] = "tree4"
                    resource_objects[cell] = snow_tree
            elif roll < 0.13:
                _add_rock(parent, collision_body, cell)
        "WOODED_LAKE":
            if d > 0.30 and roll < 0.16 and _tree_has_safe_ground(cell):
                _add_large_tree(parent, collision_body, cell)
            elif roll < 0.27:
                _add_bush(parent, collision_body, cell)
            elif roll < 0.31:
                _add_flower_if_clear(parent, collision_body, cell)

func _add_rock(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    _add_object(
        parent, collision_body, cell.x, cell.y,
        ROCK_1 if rng.randf() < 0.6 else ROCK_3,
        true, false, false, "rock"
    )

func _add_flower_if_clear(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    for yy in range(cell.y - 1, cell.y + 2):
        for xx in range(cell.x - 1, cell.x + 2):
            if flower_cells.has(Vector2i(xx, yy)):
                return
    _add_object(
        parent, collision_body, cell.x, cell.y,
        FLOWER_1 if rng.randf() < 0.6 else FLOWER_3,
        false, false, true, "flower"
    )
    flower_cells[cell] = true

func _add_savanna_tree(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    if blocked.has(cell):
        return
    var sprite := Sprite2D.new()
    sprite.texture = BIOME_TREE_SAVANNA
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.position = Vector2(cell.x * TILE - TILE, (cell.y + 1) * TILE - 48)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    parent.add_child(sprite)
    blocked[cell] = true
    grass_exclusion[cell] = true
    var collision := _add_block_collision(collision_body, cell.x, cell.y)
    resource_objects[cell] = {
        "type": "tree", "sprite": sprite, "collision": collision, "large": true
    }

func _add_bush(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    if blocked.has(cell):
        return

    var sprite := Sprite2D.new()
    sprite.texture = BUSH
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.position = Vector2(cell.x * TILE, cell.y * TILE)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    parent.add_child(sprite)

    blocked[cell] = true
    grass_exclusion[cell] = true
    var bush_collision := _add_block_collision(collision_body, cell.x, cell.y)
    resource_objects[cell] = {
        "type": "bush",
        "sprite": sprite,
        "collision": bush_collision
    }

func _add_object(
        parent: Node2D,
        collision_body: StaticBody2D,
        x: int,
        y: int,
        texture: Texture2D,
        solid: bool,
        tall: bool,
        force_front: bool = false,
        resource_kind: String = ""
    ) -> void:
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false

    var size := texture.get_size()
    if size.x > TILE:
        sprite.region_enabled = true
        sprite.region_rect = Rect2(0, 0, TILE, min(size.y, TILE * 2))
        size = Vector2(TILE, min(size.y, TILE * 2))

    # Bottom-align every sprite to its occupied tile.
    sprite.position = Vector2(
        x * TILE + (TILE - size.x) * 0.5,
        (y + 1) * TILE - size.y
    )

    # Absolute visual order. Flowers are always above both tall-grass layers.
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(Vector2i(x, y), 1 if force_front else 0)

    parent.add_child(sprite)

    if force_front:
        animated_flowers.append(sprite)

    var object_cell := Vector2i(x, y)
    var object_collision: CollisionShape2D = null
    if solid:
        grass_exclusion[object_cell] = true
        if blocked.has(object_cell):
            object_collision = ground_collisions.get(object_cell) as CollisionShape2D
        else:
            blocked[object_cell] = true
            object_collision = _add_block_collision(collision_body, x, y)

    if not resource_kind.is_empty():
        resource_objects[object_cell] = {
            "type": resource_kind,
            "sprite": sprite,
            "collision": object_collision
        }

func _add_tall_grass(
        parent: Node2D,
        front_parent: Node2D,
        cell: Vector2i
    ) -> void:
    # Classic Pokemon depth: the full grass tile is below the player, while
    # only the bottom blade tips render above the player's feet.
    var sprite := Sprite2D.new()
    sprite.texture = TALL_GRASS
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.position = Vector2(cell.x * TILE, cell.y * TILE)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell, -2)
    parent.add_child(sprite)

    var front := Sprite2D.new()
    front.texture = TALL_GRASS_FRONT
    front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    front.centered = false
    front.position = Vector2(cell.x * TILE, cell.y * TILE)
    front.z_as_relative = false
    front.z_index = _depth_z(cell, 2)
    front_parent.add_child(front)

    tall_grass[cell] = {"back": sprite, "front": front}

func _generate_tall_grass_patches(parent: Node2D, front_parent: Node2D) -> void:
    # Dense contiguous fields with no strip gaps.
    var patch_count := maxi(12, int(float(map_w * map_h) / 170.0))

    for _i in range(patch_count):
        var center := Vector2i(
            rng.randi_range(5, map_w - 6),
            rng.randi_range(5, map_h - 6)
        )
        var half_w := rng.randi_range(3, 6)
        var half_h := rng.randi_range(2, 5)

        for y in range(center.y - half_h, center.y + half_h + 1):
            for x in range(center.x - half_w, center.x + half_w + 1):
                var cell := Vector2i(x, y)

                if x < 3 or y < 3 or x >= map_w - 3 or y >= map_h - 3:
                    continue
                if terrain[y][x] != 2:
                    continue

                # Keep object collision cells on plain normal grass. Because the grass
                # overlay itself is transparent, surrounding cells blend naturally.
                if grass_exclusion.has(cell):
                    continue

                if Vector2(x - spawn_cell.x, y - spawn_cell.y).length() < 5.0:
                    continue

                _add_tall_grass(parent, front_parent, cell)

func _tree_has_safe_ground(cell: Vector2i) -> bool:
    # A 16x32 tree visually occupies two vertical tiles. Require its visible
    # footprint and immediate side neighbors to be land, never water/shore.
    var checks := [
        cell,
        cell + Vector2i(0, -1),
        cell + Vector2i(-1, 0),
        cell + Vector2i(1, 0),
        cell + Vector2i(-1, -1),
        cell + Vector2i(1, -1)
    ]
    for c in checks:
        if c.x < 0 or c.y < 0 or c.x >= map_w or c.y >= map_h:
            return false
        if terrain[c.y][c.x] != 2:
            return false
    return true

func _add_large_tree(
        parent: Node2D,
        collision_body: StaticBody2D,
        cell: Vector2i
    ) -> void:
    if blocked.has(cell):
        return

    # Broad rounded canopy tree matching the first reference.
    var sprite := Sprite2D.new()
    sprite.texture = TREE_LARGE
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false

    sprite.position = Vector2(
        cell.x * TILE - 8,
        (cell.y + 1) * TILE - 32
    )
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    parent.add_child(sprite)

    # Keep the existing one-tile trunk collision.
    blocked[cell] = true
    grass_exclusion[cell] = true
    var tree_collision := _add_block_collision(collision_body, cell.x, cell.y)
    resource_objects[cell] = {
        "type": "tree",
        "sprite": sprite,
        "collision": tree_collision,
        "large": true
    }

func _place_landmarks(parent: Node2D, collision_body: StaticBody2D) -> void:
    var candidates := [
        {"offset": Vector2i(8, -5), "type": "sign", "texture": LANDMARK_SIGN},
        {"offset": Vector2i(-10, 6), "type": "campfire", "texture": LANDMARK_CAMP},
        {"offset": Vector2i(13, 7), "type": "item", "texture": LANDMARK_BALL}
    ]

    for entry in candidates:
        var cell: Vector2i = spawn_cell + entry["offset"]
        cell.x = clamp(cell.x, 3, map_w - 4)
        cell.y = clamp(cell.y, 3, map_h - 4)

        # Search nearby until a walkable tile is found.
        if blocked.has(cell):
            for radius in range(1, 6):
                var found := false
                for yy in range(cell.y - radius, cell.y + radius + 1):
                    for xx in range(cell.x - radius, cell.x + radius + 1):
                        var test := Vector2i(xx, yy)
                        if _is_walkable(test):
                            cell = test
                            found = true
                            break
                    if found:
                        break
                if found:
                    break

        var sprite := Sprite2D.new()
        sprite.texture = entry["texture"]
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.centered = false

        var landmark_size := sprite.texture.get_size()
        # Ground the sign exactly on the tile bottom; no floating offset.
        sprite.position = Vector2(
            cell.x * TILE + (TILE - landmark_size.x) * 0.5,
            (cell.y + 1) * TILE - landmark_size.y
        )

        # Sort from the grounded tile, matching the player's foot depth.
        sprite.z_as_relative = false
        sprite.z_index = _depth_z(cell)
        parent.add_child(sprite)

        # Classic Pokemon-style collision:
        # signs, campfires and overworld item balls occupy one solid tile.
        blocked[cell] = true
        var landmark_collision := _add_landmark_collision(
            collision_body, cell.x, cell.y
        )

        landmarks[cell] = {
            "type": entry["type"],
            "sprite": sprite,
            "collision": landmark_collision,
            "used": false
        }

func _reserve_source_world_cells() -> void:
    for raw_cell in route_cells.keys():
        grass_exclusion[raw_cell] = true
    for landmark_name in ["desert_ruins", "fossil_lab", "pokemon_mansion", "regi_dungeon"]:
        if not source_landmarks.has(landmark_name):
            continue
        var descriptor: Dictionary = source_landmarks[landmark_name]
        var anchor: Vector2i = descriptor.get("anchor", Vector2i.ZERO)
        var size: Vector2i = descriptor.get("size", Vector2i.ONE)
        for yy in range(anchor.y, anchor.y + size.y):
            for xx in range(anchor.x, anchor.x + size.x):
                grass_exclusion[Vector2i(xx, yy)] = true
        var entry: Vector2i = descriptor.get("entry", anchor)
        grass_exclusion[entry] = true
        grass_exclusion[entry + Vector2i.DOWN] = true
    for raw_cave in source_landmarks.get("mountain_caves", []):
        var cave: Dictionary = raw_cave
        var cave_anchor: Vector2i = cave.get("anchor", Vector2i.ZERO)
        var cave_size: Vector2i = cave.get("size", Vector2i(3, 3))
        for yy in range(cave_anchor.y, cave_anchor.y + cave_size.y):
            for xx in range(cave_anchor.x, cave_anchor.x + cave_size.x):
                grass_exclusion[Vector2i(xx, yy)] = true
    if source_landmarks.has("house_anchor"):
        var anchor: Vector2i = source_landmarks["house_anchor"]
        for yy in range(anchor.y, anchor.y + 2):
            for xx in range(anchor.x, anchor.x + 2):
                grass_exclusion[Vector2i(xx, yy)] = true
    for key in ["house_door", "cave_door", "route_sign"]:
        if source_landmarks.has(key):
            var cell: Vector2i = source_landmarks[key]
            grass_exclusion[cell] = true
            grass_exclusion[cell + Vector2i.DOWN] = true

func _render_routes(parent: Node2D) -> void:
    for raw_cell in route_cells.keys():
        var cell: Vector2i = raw_cell
        if not _in_bounds(cell):
            continue
        var sprite := Sprite2D.new()
        sprite.texture = SOURCE_PATH_1 if (cell.x + cell.y) % 3 else SOURCE_PATH_2
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.centered = false
        sprite.position = Vector2(cell.x * TILE, cell.y * TILE)
        parent.add_child(sprite)

func _place_source_landmarks(
        parent: Node2D,
        collision_body: StaticBody2D
    ) -> void:
    _place_generated_source_landmarks(parent, collision_body)
    if source_landmarks.has("house_anchor"):
        var anchor: Vector2i = source_landmarks["house_anchor"]
        var house := Sprite2D.new()
        house.texture = SOURCE_HOUSE
        house.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        house.centered = false
        house.position = Vector2(anchor.x * TILE, anchor.y * TILE)
        house.z_as_relative = false
        house.z_index = _depth_z(anchor + Vector2i(1, 1))
        parent.add_child(house)
        var roof := _add_source_sprite(
            parent, SOURCE_HOUSE_ROOF, anchor, 23
        )
        roof.position = Vector2(anchor.x * TILE, anchor.y * TILE)
        var door_cell: Vector2i = source_landmarks["house_door"]
        var door := _add_source_sprite(parent, SOURCE_HOUSE_DOOR, door_cell, 31)
        for yy in range(anchor.y, anchor.y + 2):
            for xx in range(anchor.x, anchor.x + 2):
                var cell := Vector2i(xx, yy)
                blocked[cell] = true
                var collision := _add_landmark_collision(
                    collision_body, cell.x, cell.y
                )
                if cell == door_cell:
                    landmarks[cell] = {
                        "type": "source_house", "sprite": door,
                        "collision": collision, "used": false
                    }

    if source_landmarks.has("cave_door"):
        var cave_cell: Vector2i = source_landmarks["cave_door"]
        var cave := _add_source_sprite(parent, SOURCE_CAVE_DOOR, cave_cell, 31)
        blocked[cave_cell] = true
        var cave_collision := _add_landmark_collision(
            collision_body, cave_cell.x, cave_cell.y
        )
        landmarks[cave_cell] = {
            "type": "source_cave", "sprite": cave,
            "collision": cave_collision, "used": false
        }

    if source_landmarks.has("route_sign"):
        var sign_cell: Vector2i = source_landmarks["route_sign"]
        var sign := _add_source_sprite(parent, SOURCE_SIGN, sign_cell, 31)
        blocked[sign_cell] = true
        var sign_collision := _add_landmark_collision(
            collision_body, sign_cell.x, sign_cell.y
        )
        landmarks[sign_cell] = {
            "type": "source_route_sign", "sprite": sign,
            "collision": sign_collision, "used": false
        }

func _place_generated_source_landmarks(
        parent: Node2D,
        collision_body: StaticBody2D
    ) -> void:
    # SourceWorldGenerator has already merged the real Java-generated exterior
    # layouts into source_tiles.  Only register their entrances here.  The old
    # code painted a rectangular placeholder over every footprint, including
    # complete animation sheets, which is what produced the duplicated Regi
    # rows and buildings nested inside themselves.
    for landmark_name in [
            "desert_ruins", "fossil_lab", "pokemon_mansion", "regi_dungeon"
        ]:
        if not source_landmarks.has(landmark_name):
            continue
        var descriptor: Dictionary = source_landmarks[landmark_name]
        var entry: Vector2i = descriptor.get(
            "entry", descriptor.get("anchor", Vector2i.ZERO)
        )
        if not _in_bounds(entry):
            continue
        var collision := ground_collisions.get(entry) as CollisionShape2D
        if not is_instance_valid(collision):
            collision = _add_landmark_collision(
                collision_body, entry.x, entry.y
            )
            ground_collisions[entry] = collision
        blocked[entry] = true
        grass_exclusion[entry] = true
        landmarks[entry] = {
            "type": "source_area",
            "area": String(descriptor.get("area", "")),
            "sprite": ground_sprites.get(entry),
            "collision": collision,
            "used": false
        }
    for raw_cave in source_landmarks.get("mountain_caves", []):
        var cave: Dictionary = raw_cave
        var cave_anchor: Vector2i = cave.get("anchor", Vector2i.ZERO)
        var cave_size: Vector2i = cave.get("size", Vector2i(3, 3))
        var cave_entry: Vector2i = cave.get("entry", cave_anchor + Vector2i(1, 2))
        for yy in range(cave_size.y):
            for xx in range(cave_size.x):
                var cave_cell := cave_anchor + Vector2i(xx, yy)
                if not _in_bounds(cave_cell):
                    continue
                blocked[cave_cell] = true
                var cave_collision := ground_collisions.get(cave_cell) as CollisionShape2D
                if not is_instance_valid(cave_collision):
                    cave_collision = _add_landmark_collision(
                        collision_body, cave_cell.x, cave_cell.y
                    )
                    ground_collisions[cave_cell] = cave_collision
                if cave_cell == cave_entry:
                    landmarks[cave_cell] = {
                        "type": "source_area",
                        "area": String(cave.get("area", "")),
                        "sprite": null,
                        "collision": cave_collision,
                        "used": false
                    }
    if source_landmarks.has("mansion_key"):
        var key_cell: Vector2i = (source_landmarks["mansion_key"] as Dictionary).get("cell", Vector2i.ZERO)
        if _in_bounds(key_cell):
            var key_sprite := _add_source_sprite(parent, LANDMARK_BALL, key_cell, 31)
            blocked[key_cell] = true
            var key_collision := _add_landmark_collision(collision_body, key_cell.x, key_cell.y)
            landmarks[key_cell] = {
                "type": "source_key", "item": "MANSION KEY",
                "sprite": key_sprite, "collision": key_collision, "used": false
            }

func _add_source_sprite(
        parent: Node2D,
        texture: Texture2D,
        cell: Vector2i,
        z_value: int,
        logical_frame_size: Vector2 = Vector2.ZERO
    ) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    var draw_size := texture.get_size()
    if logical_frame_size != Vector2.ZERO:
        sprite.region_enabled = true
        sprite.region_rect = Rect2(Vector2.ZERO, logical_frame_size)
        draw_size = logical_frame_size
    elif draw_size.x > TILE:
        # Wide source files are animation/variant atlases, not map-sized
        # sprites.  Render one logical frame and never spill the full sheet into
        # neighboring cells.
        sprite.region_enabled = true
        sprite.region_rect = Rect2(
            Vector2.ZERO,
            Vector2(TILE, minf(draw_size.y, TILE * 2.0))
        )
        draw_size = sprite.region_rect.size
    sprite.position = Vector2(
        cell.x * TILE + (TILE - draw_size.x) * 0.5,
        (cell.y + 1) * TILE - draw_size.y
    )
    sprite.z_as_relative = false
    sprite.z_index = z_value if z_value <= 5 else _depth_z(cell, z_value - 16)
    parent.add_child(sprite)
    return sprite

func _refresh_house_structure_depths() -> void:
    if not exact_world_mode: return
    for cell in built_structures:
        var data: Dictionary = built_structures[cell]
        var kind := String(data.get("name", ""))
        # Furniture inside a house is ordered by its row as well. Its depth was
        # only worked out once, from wherever the player stood when it was
        # placed, so a couch could be drawn over the plant in front of it.
        var furniture: bool = built_house_interior_cells.has(cell) and kind != "FLOOR"
        if kind not in ["STATUE", "WALL", "ROOF", "DOOR"] and not furniture: continue
        var sprite := data.get("sprite") as Sprite2D
        if not is_instance_valid(sprite): continue
        if built_house_interior_cells.has(cell):
            sprite.z_index = 0 if kind == "WALL" else _house_piece_z(kind, cell)
        else:
            sprite.z_index = _depth_z(cell)
    if active_area_id != "HOUSE": return
    # Things hung on a wall stay just in front of that wall.
    for hung in [built_house_decoration_sprites, built_house_paint_sprites]:
        for cell in hung:
            var hung_sprite := hung[cell] as Sprite2D
            if is_instance_valid(hung_sprite) and hung_sprite.z_index >= 0:
                hung_sprite.z_index = _depth_z(cell, HOUSE_FURNITURE_Z)

## Depth of a piece inside a house. A row nearer the bottom of the screen is
## in front: someone standing behind a dresser is covered by it, and someone
## standing in front of it covers it.
const HOUSE_FURNITURE_Z := 1

func _house_piece_z(kind: String, cell: Vector2i) -> int:
    if kind == "STAIRS": return HOUSE_STAIRS_Z
    return _depth_z(cell, 0 if kind == "INTERIOR WALL" else HOUSE_FURNITURE_Z)

## Stairs inside a house are part of the floor: over the floor and carpets,
## under furniture, plants and anyone walking on them.
const HOUSE_STAIRS_Z := -3

func _depth_z(cell: Vector2i, offset: int = 0) -> int:
    if exact_world_mode:
        # Source-world cells can be deeply negative. Absolute cell Y placed
        # followers and roaming Pokemon behind the streamed ground layer.
        # Keep actors above both tile streams while preserving local north/
        # south ordering around the player.
        var relative_y := clampi(cell.y - _player_cell().y, -32, 32)
        return clampi(100 + relative_y * 2 + offset, 16, 190)
    return clampi(100 + (cell.y + 1) * TILE + offset, -4096, 4095)

func _setup_normal_grass_front_overlay() -> void:
    # Source grass1 is the normal encounter grass.  Its full tile remains in
    # the normal upper stream, while only the lower blade tips are repeated in
    # front of the player so walking through it has the classic Gen-2 depth.
    # Savanna and every other grass asset intentionally bypass this overlay.
    if normal_grass_front_sprite != null and is_instance_valid(normal_grass_front_sprite):
        normal_grass_front_sprite.queue_free()
    var sprite := Sprite2D.new()
    sprite.name = "NormalEncounterGrassFront"
    sprite.texture = SOURCE_NORMAL_ENCOUNTER_GRASS
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.region_enabled = true
    sprite.region_rect = Rect2(0, 8, TILE, 8)
    sprite.z_as_relative = false
    sprite.z_index = 103
    sprite.visible = false
    add_child(sprite)
    normal_grass_front_sprite = sprite

func _source_tile_key(value: String) -> String:
    var key := value.to_lower().strip_edges()
    if key.ends_with(".png"):
        key = key.trim_suffix(".png")
    return key

func _is_normal_encounter_grass(cell: Vector2i) -> bool:
    if not exact_world_mode or exact_world == null:
        return false
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null:
        return false
    return (
        _source_tile_key(tile.name) == "grass1"
        or _source_tile_key(tile.name_upper) == "grass1"
    )

func _update_normal_grass_front_overlay(cell: Vector2i) -> void:
    if normal_grass_front_sprite == null or not is_instance_valid(normal_grass_front_sprite):
        return
    var show := active_area_id == "OVERWORLD" and _is_normal_encounter_grass(cell)
    normal_grass_front_sprite.visible = show
    if not show:
        return
    normal_grass_front_sprite.position = Vector2(cell.x * TILE, cell.y * TILE + 8)
    normal_grass_front_sprite.z_index = 103

func _setup_savanna_tree_front_overlay() -> void:
    if savanna_tree_front_sprite != null and is_instance_valid(savanna_tree_front_sprite):
        savanna_tree_front_sprite.queue_free()
    var sprite := Sprite2D.new()
    sprite.name = "SavannaTreeFront"
    sprite.texture = SOURCE_SAVANNA_TREE
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.z_as_relative = false
    sprite.z_index = 106
    sprite.visible = false
    add_child(sprite)
    savanna_tree_front_sprite = sprite

func _savanna_tree_anchor_covering(cell: Vector2i) -> Vector2i:
    if not exact_world_mode or exact_world == null:
        return Vector2i(-2147483648, -2147483648)
    # tree_savanna1 is the authored 48x48 source object. Its source anchor draws
    # one tile left and three tiles tall, so test only anchors whose visual
    # footprint can actually cover the player.
    for anchor_y in range(cell.y - 2, cell.y + 1):
        for anchor_x in range(cell.x - 1, cell.x + 2):
            var anchor_cell := Vector2i(anchor_x, anchor_y)
            var tile: SourceTile = exact_world.tile_at(anchor_cell)
            if tile == null:
                continue
            var upper_key := _source_tile_key(tile.name_upper)
            var base_key := _source_tile_key(tile.name)
            if upper_key != "tree_savanna1" and base_key != "tree_savanna1":
                continue
            if cell.x < anchor_x - 1 or cell.x > anchor_x + 1:
                continue
            if cell.y < anchor_y or cell.y > anchor_y + 2:
                continue
            return anchor_cell
    return Vector2i(-2147483648, -2147483648)

func _update_savanna_tree_front_overlay(cell: Vector2i) -> void:
    if savanna_tree_front_sprite == null or not is_instance_valid(savanna_tree_front_sprite):
        return
    if active_area_id != "OVERWORLD":
        savanna_tree_front_sprite.visible = false
        return
    var anchor_cell := _savanna_tree_anchor_covering(cell)
    if anchor_cell.x <= -2147483648:
        savanna_tree_front_sprite.visible = false
        return
    # tree_savanna1 is three tiles high. Only the upper two rows should cover
    # an actor. On the authored bottom/base row the actor's feet are in front;
    # redrawing the whole 48x48 tree there made the player look like they were
    # walking on top of the canopy/edge.
    if cell.y >= anchor_cell.y + 2:
        savanna_tree_front_sprite.visible = false
        return
    savanna_tree_front_sprite.position = Vector2(
        anchor_cell.x * TILE - TILE, anchor_cell.y * TILE)
    savanna_tree_front_sprite.z_index = 106
    savanna_tree_front_sprite.visible = true

func _build_source_interiors(_collision_body: StaticBody2D) -> void:
    var layer := Node2D.new()
    layer.name = "InteriorLayer"
    layer.z_index = -5
    add_child(layer)
    # Player houses share the legacy off-world coordinate range with dungeon
    # planes. Keep generated dungeon collision separate so hidden dungeon walls
    # cannot block movement inside a house (or house walls inside a dungeon).
    var collision_body := StaticBody2D.new()
    collision_body.name = "SourceInteriorCollision"
    layer.add_child(collision_body)
    await _build_generated_source_interiors(layer, collision_body, true)

func _build_generated_source_interiors(
        parent: Node2D,
        collision_body: StaticBody2D,
        cooperative: bool = false
    ) -> void:
    var slice_started := Time.get_ticks_usec()
    var plans := generated_source_interior_plans
    var next_y := 4
    for raw_plan in plans:
        var plan := raw_plan as Dictionary
        var area_id := String(plan.get("id", ""))
        var layer_index := int(plan.get("layer_index", -1))
        var size: Vector2i = plan.get("size", Vector2i.ONE)
        var origin := Vector2i(map_w + 8, next_y)
        source_area_origins[area_id] = origin
        source_layer_area_ids[layer_index] = area_id
        next_y += size.y + 8
    for index in range(plans.size()):
        var plan: Dictionary = plans[index]
        var area_id := String(plan.get("id", "AREA_%d" % index))
        var size: Vector2i = plan.get("size", Vector2i(20, 12))
        var origin: Vector2i = source_area_origins[area_id]
        var area_layer := Node2D.new()
        area_layer.name = area_id
        area_layer.visible = false
        parent.add_child(area_layer)
        source_area_layers[area_id] = area_layer
        var tiles: Dictionary = plan.get("tiles", {})
        var solids: Dictionary = plan.get("solids", {})
        # Tall furniture (statues, shelves, potted plants) reaches up into the
        # row above and shares one draw layer, so the order sprites are added
        # decides which is on top. Add rows top to bottom: a statue standing in
        # front of a plant pot then draws over the pot, not under it.
        var ordered_cells: Array = tiles.keys()
        ordered_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
        for raw_local_cell in ordered_cells:
            if cooperative and Time.get_ticks_usec() - slice_started >= 4000:
                await get_tree().process_frame
                slice_started = Time.get_ticks_usec()
            var local_cell: Vector2i = raw_local_cell
            var world_cell := origin + local_cell
            var tile := tiles[local_cell] as SourceTile
            if tile == null:
                continue
            for upper in [false, true]:
                var spec := SourceWorldData.interior_render_spec(tile, upper)
                if spec.is_empty():
                    continue
                var region: Rect2 = spec["region"]
                var tile_sprite := _add_source_sprite(area_layer, spec["texture"],
                    world_cell, 16 if upper else -4, region.size)
                tile_sprite.region_enabled = true
                tile_sprite.region_rect = region
                tile_sprite.position = Vector2(world_cell * TILE) + Vector2(0, TILE - region.size.y)
                if upper or tile.name in ["cave1_regi1", "cave1_regi2", "cave1_regi3"] or "__on" in tile.name or "__off" in tile.name:
                    source_interior_upper_sprites[world_cell] = tile_sprite
            if solids.has(local_cell) or "stool" in tile.name_upper:
                blocked[world_cell] = true
                var interior_collision := _add_landmark_collision(
                    collision_body, world_cell.x, world_cell.y
                )
                if (
                        tile.name_upper in ["mewtwo_overworld", "volcarona"]
                        or tile.name_upper.begins_with("REGI")
                        or tile.name in ["cave1_regipedistal1", "cave1_regi1", "cave1_regi2", "cave1_regi3"]
                        or "__on" in tile.name or "__off" in tile.name
                        or (tile.name.begins_with("pkmnmansion") and not tile.has_item.is_empty())
                        or (SourceMineRuntime.is_mine_tile(tile) and not tile.has_item.is_empty())
                    ):
                    source_event_collisions[world_cell] = interior_collision
        var entries := plan.get("entries", []) as Array
        var local_entry := Vector2i(size.x / 2, size.y / 2)
        if not entries.is_empty():
            local_entry = Vector2i(plan["source_to_local"][Vector2i(entries[0])])
        var entry := origin + local_entry
        source_area_entries[area_id] = entry
        source_area_rects[area_id] = Rect2i(origin, size)
        area_return_cells["%s_ENTRY" % area_id] = entry
        var transitions := plan.get("transitions", {}) as Dictionary
        for raw_local_cell in transitions:
            var transition_cell := Vector2i(raw_local_cell)
            var transition := transitions[transition_cell] as Dictionary
            var action_cell := origin + transition_cell
            if bool(transition.get("exit_overworld", false)):
                interior_interactables[action_cell] = "EXIT_AREA:%s" % area_id
            else:
                var source_cell: Vector2i = transition.get("source_cell", Vector2i.ZERO)
                interior_interactables[action_cell] = "GOTO_SOURCE_LAYER:%d:%d:%d" % [
                    int(transition.get("target_layer", -1)),
                    source_cell.x,
                    source_cell.y
                ]
        var interactables := plan.get("interactables", {}) as Dictionary
        for raw_local_cell in interactables:
            interior_interactables[origin + Vector2i(raw_local_cell)] = interactables[raw_local_cell]
        var interior_pokemon := plan.get("pokemon", []) as Array
        for raw_spawn in interior_pokemon:
            var spawn := raw_spawn as Dictionary
            var pokemon_cell := origin + Vector2i(spawn.get("cell", Vector2i.ZERO))
            var species := String(spawn.get("name", "")).to_lower()
            if species == "dusclops" and SourceMineRuntime.is_mine_tile(tiles.get(Vector2i(spawn.get("cell", Vector2i.ZERO)))):
                SourceMineRuntime.add(self, area_layer, collision_body, plan, spawn)
                continue
            var pokemon_texture := PokemonData.texture(species, "overworld")
            if pokemon_texture != null:
                _add_source_sprite(area_layer, pokemon_texture, pokemon_cell, 18)
            interior_interactables[pokemon_cell] = "WILD:%s:%d" % [
                species, int(spawn.get("level", 2))
            ]
            blocked[pokemon_cell] = true
            _add_landmark_collision(collision_body, pokemon_cell.x, pokemon_cell.y)
    _register_source_interior_aliases(plans)
    SourceRegiRuntime.sync(self)

func _register_source_interior_aliases(plans: Array[Dictionary]) -> void:
    var aliases := {
        "RUINS_0": {"layer": 99, "route": "ruins1_inner"},
        "MANSION_0": {"layer": 100, "route": "pkmnmansion1"},
        "FOSSIL_LAB": {"layer": 100, "route": "fossil_lab1"},
        "REGI_CHAMBER": {"layer": 90, "route": "regi_cave1"}
    }
    for alias in aliases:
        var wanted := aliases[alias] as Dictionary
        var area_id := String(source_layer_area_ids.get(int(wanted["layer"]), ""))
        if area_id.is_empty():
            continue
        var plan: Dictionary = {}
        for candidate in plans:
            if String(candidate.get("id", "")) == area_id:
                plan = candidate
                break
        var local_entry := _find_route_entry(plan, String(wanted["route"]))
        var origin: Vector2i = source_area_origins[area_id]
        source_area_entries[alias] = origin + local_entry
        source_area_layers[alias] = source_area_layers[area_id]
        source_area_rects[alias] = source_area_rects[area_id]
        area_return_cells["%s_ENTRY" % alias] = origin + local_entry

func _find_route_entry(plan: Dictionary, route_name: String) -> Vector2i:
    if route_name == "regi_cave1":
        for cell in plan.get("transitions", {}):
            if bool(plan.transitions[cell].get("exit_overworld", false)):
                return Vector2i(cell)
    var tiles := plan.get("tiles", {}) as Dictionary
    var fallback := Vector2i.ZERO
    for raw_cell in tiles:
        var cell := Vector2i(raw_cell)
        var tile := tiles[cell] as SourceTile
        if tile == null or tile.route_belongs_to == null:
            continue
        if tile.route_belongs_to.name != route_name or tile.is_solid:
            continue
        fallback = cell
        if "stairs" in tile.name_upper or "rug" in tile.name or "entrance" in tile.name:
            return cell
    return fallback

func _build_house_interior(parent: Node2D, collision_body: StaticBody2D) -> void:
    # Legacy helper retained for compatibility; built houses are generated
    # from their connected exterior footprint by _prepare_built_house_interior.
    var origin := Vector2i(map_w + 8, 4)
    var size := Vector2i(7, 6)
    _draw_built_house_interior(parent, collision_body, origin, size, Vector2i(int(size.x / 2), size.y - 1))

func _built_house_floor_tile_key(
        door_cell: Vector2i, floor_index: int, local_cell: Vector2i
    ) -> String:
    return "%d,%d|%d|%d,%d" % [
        door_cell.x, door_cell.y, floor_index, local_cell.x, local_cell.y
    ]

func _built_house_floor_origin(floor_index: int) -> Vector2i:
    if built_house_floor_origins.has(floor_index):
        return Vector2i(built_house_floor_origins[floor_index])
    return built_house_interior_origin + Vector2i(
        maxi(0, floor_index) * BUILT_HOUSE_FLOOR_STRIDE, 0
    )

func _built_house_floor_index_for_cell(cell: Vector2i) -> int:
    if built_house_room_size.x <= 0 or built_house_room_size.y <= 0:
        return -1
    for raw_index in built_house_floor_origins.keys():
        var floor_index: int = int(raw_index)
        var origin: Vector2i = Vector2i(built_house_floor_origins[raw_index])
        if Rect2i(origin, built_house_room_size).has_point(cell):
            return floor_index
    return -1

func _built_house_local_for_cell(cell: Vector2i) -> Vector2i:
    var floor_index: int = _built_house_floor_index_for_cell(cell)
    if floor_index < 0:
        return Vector2i(-2147483648, -2147483648)
    return cell - _built_house_floor_origin(floor_index)

func _built_house_global_cell(floor_index: int, local_cell: Vector2i) -> Vector2i:
    return _built_house_floor_origin(floor_index) + local_cell

func _built_house_floor_saved(
        floor_index: int, local_cell: Vector2i
    ) -> bool:
    if floor_index <= 0:
        return true
    if active_built_house_door.x <= -2147483648:
        return false
    return built_house_floor_tiles.has(_built_house_floor_tile_key(
        active_built_house_door, floor_index, local_cell
    ))

func _add_built_house_floor_cell(
        floor_index: int, local_cell: Vector2i, persist: bool = true
    ) -> bool:
    if floor_index < 0 or floor_index >= built_house_floor_capacity:
        return false
    if (
            local_cell.x < 0 or local_cell.y < 0
            or local_cell.x >= built_house_room_size.x
            or local_cell.y >= built_house_room_size.y
        ):
        return false
    if (floor_index > 0 or not built_house_footprint.is_empty()) and not built_house_footprint.has(local_cell):
        return false
    if floor_index > 0 and persist:
        built_house_floor_tiles[_built_house_floor_tile_key(
            active_built_house_door, floor_index, local_cell
        )] = true
    var global_cell: Vector2i = _built_house_global_cell(floor_index, local_cell)
    if built_house_interior_cells.has(global_cell):
        return true
    built_house_interior_cells[global_cell] = true
    var layer: Node2D = source_area_layers.get("HOUSE") as Node2D
    if layer != null:
        _add_source_sprite(layer, _structure_display_texture("FLOOR"), global_cell, -5)
    if built_house_void_collisions.has(global_cell):
        var collision: CollisionShape2D = built_house_void_collisions[global_cell] as CollisionShape2D
        if is_instance_valid(collision):
            collision.queue_free()
        built_house_void_collisions.erase(global_cell)
    return true

func _built_house_floor_can_expand(cell: Vector2i) -> bool:
    if active_area_id != "HOUSE":
        return false
    var floor_index: int = _built_house_floor_index_for_cell(cell)
    if floor_index <= 0 or floor_index >= built_house_floor_capacity:
        return false
    var local_cell: Vector2i = cell - _built_house_floor_origin(floor_index)
    if (
            local_cell.x < 0 or local_cell.y < 0
            or local_cell.x >= built_house_room_size.x
            or local_cell.y >= built_house_room_size.y
        ):
        return false
    if built_house_interior_cells.has(cell) or built_structures.has(cell):
        return false
    return built_house_footprint.has(local_cell)

func _place_built_house_floor(cell: Vector2i) -> bool:
    if not _built_house_floor_can_expand(cell):
        world_message.emit("FLOOR needs an empty space within this house.")
        return false
    var floor_index: int = _built_house_floor_index_for_cell(cell)
    var local_cell: Vector2i = cell - _built_house_floor_origin(floor_index)
    if not _add_built_house_floor_cell(floor_index, local_cell, true):
        return false
    # Successful construction is silent.
    return true

func _draw_built_house_upper_floor(
        parent: Node2D, collision_body: StaticBody2D,
        floor_index: int, origin: Vector2i, size: Vector2i
    ) -> void:
    # Source house upper floors start as black void. Stairs carve a clipped
    # 3x3 patch clipped to the exterior footprint; FLOOR fills that footprint.
    for yy in range(size.y):
        for xx in range(size.x):
            var local_cell: Vector2i = Vector2i(xx, yy)
            var cell: Vector2i = origin + local_cell
            if built_house_footprint.has(local_cell) and _built_house_floor_saved(floor_index, local_cell):
                built_house_interior_cells[cell] = true
                _add_source_sprite(parent, _structure_display_texture("FLOOR"), cell, -5)
            else:
                built_house_void_collisions[cell] = _add_landmark_collision(
                    collision_body, cell.x, cell.y
                )
    # Prevent walking off an edge floor tile into the off-map void.
    for xx in range(-1, size.x + 1):
        for yy in [-1, size.y]:
            var edge: Vector2i = origin + Vector2i(xx, yy)
            if not built_house_void_collisions.has(edge):
                built_house_void_collisions[edge] = _add_landmark_collision(
                    collision_body, edge.x, edge.y
                )
    for yy in range(size.y):
        for xx in [-1, size.x]:
            var edge: Vector2i = origin + Vector2i(xx, yy)
            if not built_house_void_collisions.has(edge):
                built_house_void_collisions[edge] = _add_landmark_collision(
                    collision_body, edge.x, edge.y
                )

func _built_house_stair_metadata(cell: Vector2i) -> Dictionary:
    var floor_index: int = _built_house_floor_index_for_cell(cell)
    if floor_index < 0:
        return {}
    var local_cell: Vector2i = cell - _built_house_floor_origin(floor_index)
    return {
        "house_door_x": active_built_house_door.x,
        "house_door_y": active_built_house_door.y,
        "house_floor": floor_index,
        "house_local_x": local_cell.x,
        "house_local_y": local_cell.y
    }

func _stair_belongs_to_active_house(data: Dictionary) -> bool:
    return (
        int(data.get("house_door_x", -2147483648)) == active_built_house_door.x
        and int(data.get("house_door_y", -2147483648)) == active_built_house_door.y
    )

func _remove_generated_house_stair_pairs() -> void:
    var remove_cells: Array[Vector2i] = []
    for raw_cell in built_structures.keys():
        var cell: Vector2i = Vector2i(raw_cell)
        var data: Dictionary = built_structures[cell]
        if not bool(data.get("generated_stair_pair", false)):
            continue
        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            sprite.queue_free()
        var collision: CollisionShape2D = data.get("collision") as CollisionShape2D
        if is_instance_valid(collision):
            collision.queue_free()
        remove_cells.append(cell)
    for cell in remove_cells:
        built_structures.erase(cell)
        blocked.erase(cell)
        grass_exclusion.erase(cell)

func _ensure_house_stair_upper_patch(primary_cell: Vector2i) -> Vector2i:
    if not built_structures.has(primary_cell):
        return Vector2i(-2147483648, -2147483648)
    var data: Dictionary = built_structures[primary_cell]
    if bool(data.get("generated_stair_pair", false)):
        return Vector2i(-2147483648, -2147483648)
    if not _stair_belongs_to_active_house(data):
        return Vector2i(-2147483648, -2147483648)
    var floor_index: int = int(data.get("house_floor", -1))
    var upper_floor: int = floor_index + 1
    if floor_index < 0 or upper_floor >= built_house_floor_capacity:
        return Vector2i(-2147483648, -2147483648)
    var local_cell: Vector2i = Vector2i(
        int(data.get("house_local_x", 0)), int(data.get("house_local_y", 0))
    )
    for yy in range(local_cell.y - 1, local_cell.y + 2):
        for xx in range(local_cell.x - 1, local_cell.x + 2):
            _add_built_house_floor_cell(
                upper_floor, Vector2i(xx, yy), true
            )
    return _built_house_global_cell(upper_floor, local_cell)

func _create_generated_house_stair_pair(primary_cell: Vector2i) -> void:
    if not built_structures.has(primary_cell):
        return
    var data: Dictionary = built_structures[primary_cell]
    var upper_cell: Vector2i = _ensure_house_stair_upper_patch(primary_cell)
    if upper_cell.x <= -2147483648 or built_structures.has(upper_cell):
        return
    var sprite: Sprite2D = Sprite2D.new()
    sprite.texture = SourceWorldData.texture_for("stairs_down1")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.position = Vector2(upper_cell.x * TILE, upper_cell.y * TILE)
    sprite.z_as_relative = false
    sprite.z_index = HOUSE_STAIRS_Z
    var layer: Node2D = get_node_or_null("LandmarkLayer") as Node2D
    if layer != null:
        layer.add_child(sprite)
    built_structures[upper_cell] = {
        "name":"STAIRS", "recipe_name":"STAIRS", "sprite":sprite,
        "collision":null, "solid":false, "bridged_water":false,
        "open":false, "variant":0, "text":"", "last_harvest_day":-1,
        "generated_stair_pair":true,
        "stair_primary_x":primary_cell.x,
        "stair_primary_y":primary_cell.y,
        "house_door_x":int(data.get("house_door_x", active_built_house_door.x)),
        "house_door_y":int(data.get("house_door_y", active_built_house_door.y)),
        "house_floor":int(data.get("house_floor", 0)) + 1,
        "house_local_x":int(data.get("house_local_x", 0)),
        "house_local_y":int(data.get("house_local_y", 0))
    }

func _normalize_active_house_stairs() -> void:
    # Migrate stairs from earlier port saves by inferring their floor/local cell
    # from the current house coordinate bands, then recreate source-like paired
    # landings. Generated pairs themselves are never saved.
    var primaries: Array[Vector2i] = []
    for raw_cell in built_structures.keys():
        var cell: Vector2i = Vector2i(raw_cell)
        var data: Dictionary = built_structures[cell]
        if String(data.get("name", "")) != "STAIRS" or bool(
                data.get("generated_stair_pair", false)):
            continue
        var floor_index: int = _built_house_floor_index_for_cell(cell)
        if floor_index < 0:
            continue
        if not data.has("house_floor"):
            var metadata: Dictionary = _built_house_stair_metadata(cell)
            for key in metadata:
                data[key] = metadata[key]
            built_structures[cell] = data
        if _stair_belongs_to_active_house(data):
            primaries.append(cell)
    for primary in primaries:
        _create_generated_house_stair_pair(primary)

func _set_active_built_house_floor(floor_index: int) -> void:
    var clamped: int = clampi(floor_index, 0, maxi(0, built_house_floor_capacity - 1))
    var origin: Vector2i = _built_house_floor_origin(clamped)
    source_area_rects["HOUSE"] = Rect2i(origin, built_house_room_size)
    source_area_origins["HOUSE"] = origin
    _configure_camera()

func _draw_built_house_interior(
        parent: Node2D, collision_body: StaticBody2D, origin: Vector2i,
        size: Vector2i, exit_local: Vector2i, exterior_doors: Dictionary = {},
        footprint_only: bool = false
    ) -> void:
    if size.x <= 0 or size.y <= 0:
        return
    var clamped_exit := Vector2i(
        clampi(exit_local.x, 0, size.x - 1),
        clampi(exit_local.y, 0, size.y - 1)
    )

    # Use the source interior floor for the entire connected exterior footprint.
    # The doorway gets the source red entry rug, matching the actual house maps.
    # As in the Java game, a piece cut out of the outside of the house takes
    # its tile of the room with it: that tile is black and cannot be walked on.
    for yy in range(size.y):
        for xx in range(size.x):
            var cell := origin + Vector2i(xx, yy)
            if footprint_only and not built_house_footprint.has(Vector2i(xx, yy)):
                built_house_void_collisions[cell] = _add_landmark_collision(
                    collision_body, cell.x, cell.y
                )
                continue
            built_house_interior_cells[cell] = true
            _add_source_sprite(parent, _structure_display_texture("FLOOR"), cell, -5)

    var exits: Dictionary = {}
    var requested_exits := exterior_doors.duplicate()
    if requested_exits.is_empty():
        requested_exits[clamped_exit] = Vector2i(-2147483648, -2147483648)
    for raw_local in requested_exits:
        var local_exit := Vector2i(raw_local)
        # Map the exterior door to the nearest room edge. Side/back exterior doors
        # therefore remain real side/back exits rather than being forced to the front.
        var edge := "BOTTOM"
        if local_exit.y == 0:
            edge = "TOP"
        elif local_exit.y == size.y - 1:
            edge = "BOTTOM"
        elif local_exit.x == 0:
            edge = "LEFT"
        elif local_exit.x == size.x - 1:
            edge = "RIGHT"

        var door_cell := origin + Vector2i(local_exit.x, size.y)
        var rug_cell := origin + Vector2i(local_exit.x, size.y - 1)
        if edge == "TOP":
            door_cell = origin + Vector2i(local_exit.x, -1)
            rug_cell = origin + Vector2i(local_exit.x, 0)
        elif edge == "LEFT":
            door_cell = origin + Vector2i(-1, local_exit.y)
            rug_cell = origin + Vector2i(0, local_exit.y)
        elif edge == "RIGHT":
            door_cell = origin + Vector2i(size.x, local_exit.y)
            rug_cell = origin + Vector2i(size.x - 1, local_exit.y)

        exits[door_cell] = rug_cell
        built_house_interior_cells[door_cell] = true
        var exterior: Vector2i = requested_exits[raw_local]
        if exterior.x > -2147483648:
            built_house_exit_doors[door_cell] = exterior
        if local_exit == clamped_exit:
            area_return_cells["HOUSE_ENTRY"] = rug_cell

    # Classic source-room presentation: a finished back wall, solid side edges,
    # an open foreground boundary, and a real rug/door pair instead of four rows
    # of repeated crate-looking wall tiles around the entire room.
    for xx in range(size.x):
        var top_wall := origin + Vector2i(xx, -1)
        if not exits.has(top_wall):
            _add_source_sprite(parent, SOURCE_HOUSE5_WALL, top_wall, 0)
            _add_landmark_collision(collision_body, top_wall.x, top_wall.y)
            built_house_paintable_walls[top_wall] = true

        var bottom_wall := origin + Vector2i(xx, size.y)
        if not exits.has(bottom_wall):
            _add_landmark_collision(collision_body, bottom_wall.x, bottom_wall.y)

    for yy in range(size.y):
        var left_wall := origin + Vector2i(-1, yy)
        var right_wall := origin + Vector2i(size.x, yy)
        if not exits.has(left_wall):
            # The source player-built interior has one visible back wall only.
            # Keep invisible side-boundary collision so the room size/collision
            # does not change, but do not draw or make the sides paintable.
            _add_landmark_collision(collision_body, left_wall.x, left_wall.y)
        if not exits.has(right_wall):
            _add_landmark_collision(collision_body, right_wall.x, right_wall.y)

    # Every connected entrance belongs to this room and has its own outside exit.
    for door_cell in exits:
        _add_source_sprite(parent, SOURCE_HOUSE5_RUG, exits[door_cell], 2)
        _add_source_sprite(parent, SOURCE_HOUSE5_DOOR, door_cell, 18)
        interior_interactables[door_cell] = "EXIT_HOUSE"
    source_area_rects["HOUSE"] = Rect2i(origin, size)
    source_area_origins["HOUSE"] = origin

func _prepare_built_house_interior(door_cell: Vector2i, house_state: Dictionary) -> void:
    # Clear the previous house runtime while preserving persistent floor expansion
    # records and player-built structures. Generated stair-pair mirrors are rebuilt.
    _restore_displaced_house_blocks()
    built_house_blocks_stale = true
    _remove_generated_house_stair_pairs()
    built_house_exit_doors.clear()
    for raw_cell in built_house_interior_cells.keys():
        interior_interactables.erase(Vector2i(raw_cell))
    built_house_interior_cells.clear()
    built_house_paintable_walls.clear()
    built_house_paint_sprites.clear()
    built_house_decoration_sprites.clear()
    built_house_floor_origins.clear()
    built_house_void_collisions.clear()
    var old_layer := get_node_or_null("BuiltHouseInterior")
    if old_layer != null:
        remove_child(old_layer)
        old_layer.queue_free()
    var old_body := get_node_or_null("BuiltHouseCollision")
    if old_body != null:
        remove_child(old_body)
        old_body.queue_free()

    var exterior_cells: Array = house_state.get("cells", [])
    if exterior_cells.is_empty():
        return

    var min_cell := Vector2i(2147483647, 2147483647)
    var max_cell := Vector2i(-2147483648, -2147483648)
    for raw_cell in exterior_cells:
        var exterior_cell := Vector2i(raw_cell)
        min_cell.x = mini(min_cell.x, exterior_cell.x)
        min_cell.y = mini(min_cell.y, exterior_cell.y)
        max_cell.x = maxi(max_cell.x, exterior_cell.x)
        max_cell.y = maxi(max_cell.y, exterior_cell.y)
    var room_size := max_cell - min_cell + Vector2i.ONE
    room_size.x = maxi(room_size.x, 1)
    room_size.y = maxi(room_size.y, 1)

    built_house_footprint.clear()
    for raw_cell in exterior_cells:
        built_house_footprint[Vector2i(raw_cell) - min_cell] = true
    active_built_house_door = _canonical_house_door(door_cell)
    built_house_interior_origin = _house_origin_for(door_cell)
    built_house_room_size = room_size
    built_house_rooms_seen[built_house_interior_origin.y] = [min_cell, room_size]
    built_house_floor_capacity = maxi(1, int(house_state.get("floor_count", 1)))
    for floor_index in range(built_house_floor_capacity):
        built_house_floor_origins[floor_index] = (
            built_house_interior_origin
            + Vector2i(floor_index * BUILT_HOUSE_FLOOR_STRIDE, 0)
        )
    var exit_local := door_cell - min_cell
    var exterior_doors: Dictionary = {}
    for raw_cell in exterior_cells:
        var exterior := Vector2i(raw_cell)
        var piece: Dictionary = built_structures.get(exterior, {})
        if String(piece.get("name", "")) == "DOOR" and not bool(piece.get("gate", false)):
            exterior_doors[exterior - min_cell] = exterior

    var layer := Node2D.new()
    layer.name = "BuiltHouseInterior"
    layer.visible = false
    add_child(layer)
    var collision := StaticBody2D.new()
    collision.name = "BuiltHouseCollision"
    add_child(collision)
    source_area_layers["HOUSE"] = layer

    _draw_built_house_interior(
        layer, collision, built_house_interior_origin, room_size, exit_local, exterior_doors, true
    )
    for floor_index in range(1, built_house_floor_capacity):
        _draw_built_house_upper_floor(
            layer, collision, floor_index,
            _built_house_floor_origin(floor_index), room_size
        )
    _normalize_active_house_stairs()
    _restore_house_rear_walls()
    _restore_built_house_paintings()
    _restore_house_decorations()
    for furniture_cell in built_house_interior_cells:
        if built_structures.has(furniture_cell): _refresh_shell_attachment(furniture_cell)
    _set_active_built_house_floor(0)

func _restore_displaced_house_blocks() -> void:
    for cell in built_house_displaced_blocks:
        blocked[cell] = true
    built_house_displaced_blocks.clear()

## Sets aside every blocked mark on this house's floors, and on the wall row
## above each, that does not come from something built in the house.
func _displace_foreign_house_blocks() -> void:
    built_house_blocks_stale = false
    for raw_index in built_house_floor_origins:
        var origin := _built_house_floor_origin(int(raw_index))
        for yy in range(-1, built_house_room_size.y):
            for xx in range(built_house_room_size.x):
                var cell := origin + Vector2i(xx, yy)
                if not blocked.has(cell) or built_structures.has(cell): continue
                if _couch_anchor_at(cell) != Vector2i(2147483647,2147483647): continue
                built_house_displaced_blocks[cell] = true
                blocked.erase(cell)

func _built_house_paint_key(cell: Vector2i) -> String:
    if active_built_house_door.x <= -2147483648:
        return ""
    var floor_index: int = _built_house_floor_index_for_cell(cell)
    if floor_index < 0:
        floor_index = _built_house_rear_wall_floor(cell)
    var local_cell: Vector2i = (
        cell - _built_house_floor_origin(floor_index)
        if floor_index >= 0 else cell - built_house_interior_origin
    )
    if floor_index <= 0:
        return "%d,%d|%d,%d" % [
            active_built_house_door.x, active_built_house_door.y,
            local_cell.x, local_cell.y
        ]
    return "%d,%d|F%d|%d,%d" % [
        active_built_house_door.x, active_built_house_door.y,
        floor_index, local_cell.x, local_cell.y
    ]

func _set_built_house_paint_sprite(cell: Vector2i, index: int) -> bool:
    var path := "res://assets/source_0_8_11/tiles/buildings/house_picture%d.png" % index
    if not ResourceLoader.exists(path):
        return false
    if built_house_paint_sprites.has(cell):
        var old_sprite := built_house_paint_sprites[cell] as Sprite2D
        if is_instance_valid(old_sprite):
            old_sprite.queue_free()
    var layer := source_area_layers.get("HOUSE") as Node2D
    if layer == null:
        return false
    var sprite := Sprite2D.new()
    sprite.texture = load(path) as Texture2D
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.position = Vector2(cell.x * TILE, cell.y * TILE)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell, HOUSE_FURNITURE_Z)
    layer.add_child(sprite)
    built_house_paint_sprites[cell] = sprite
    return true

func _restore_built_house_paintings() -> void:
    if active_built_house_door.x <= -2147483648:
        return
    for raw_cell in built_house_paintable_walls.keys():
        var cell := Vector2i(raw_cell)
        var key := _built_house_paint_key(cell)
        if key.is_empty() or not built_house_paintings.has(key):
            continue
        _set_built_house_paint_sprite(cell, clampi(int(built_house_paintings[key]), 1, 20))

func apply_paint(picture_index: int, cell: Vector2i) -> bool:
    if active_area_id != "HOUSE" or active_field_species != "smeargle":
        world_message.emit("PAINT can only be used by SMEARGLE on an inside house wall.")
        return false
    if not built_house_paintable_walls.has(cell):
        world_message.emit("Face an inside house wall to PAINT it.")
        return false
    var index := clampi(picture_index, 1, 20)
    var key := _built_house_paint_key(cell)
    if key.is_empty() or not _set_built_house_paint_sprite(cell, index):
        return false
    built_house_paintings[key] = index
    play_source_sound("craft1")
    world_message.emit("SMEARGLE painted PICTURE %d." % index)
    return true


func _build_cave_interior(parent: Node2D, collision_body: StaticBody2D) -> void:
    var origin := Vector2i(map_w + 8, 20)
    var size := Vector2i(20, 12)
    var exit_cell := origin + Vector2i(10, 10)
    for yy in range(size.y):
        for xx in range(size.x):
            var cell := origin + Vector2i(xx, yy)
            _add_source_sprite(parent, SOURCE_CAVE_FLOOR, cell, -5)
            var boundary := xx == 0 or yy == 0 or xx == size.x - 1 or yy == size.y - 1
            if boundary and cell != exit_cell:
                _add_source_sprite(parent, SOURCE_CAVE_STONE, cell, 16)
                _add_landmark_collision(collision_body, cell.x, cell.y)
    _add_source_sprite(parent, SOURCE_CAVE_RAMP, exit_cell, 3)
    for rock_offset in [Vector2i(4, 3), Vector2i(15, 3), Vector2i(7, 7)]:
        var rock_cell: Vector2i = origin + rock_offset
        _add_source_sprite(parent, SOURCE_CAVE_STONE, rock_cell, 16)
        _add_landmark_collision(collision_body, rock_cell.x, rock_cell.y)
    interior_interactables[exit_cell] = "EXIT_CAVE"
    area_return_cells["CAVE_ENTRY"] = origin + Vector2i(10, 9)

var held_emote_refresh_remaining := 0.0
var window_display_cache: Dictionary = {}

func _process(delta: float) -> void:
    if active_area_id == "HOUSE":
        if built_house_blocks_stale: _displace_foreign_house_blocks()
    elif not built_house_displaced_blocks.is_empty():
        _restore_displaced_house_blocks()
    held_emote_refresh_remaining -= delta
    if held_emote_refresh_remaining <= 0.0:
        held_emote_refresh_remaining = 0.1
        for resident in deployed_pokemon.values():
            preload("res://scripts/held_item_emote.gd").refresh(resident)
    if generated:
        var coordinator=get_parent().get("coop_game")
        if is_instance_valid(coordinator) and coordinator.active and coordinator.session.trusted:
            world_elapsed_seconds=coordinator.world_time(delta)
        else:world_elapsed_seconds += delta
        SourceForestBoss.update_visibility(self)
        preload("res://scripts/biome_megas.gd").update(self)
        if gameplay_enabled and encounter_grace_remaining > 0.0:
            encounter_grace_remaining = maxf(
                0.0, encounter_grace_remaining - delta
            )
        _update_tide_state(false, delta)
        _update_tidal_wade_visual()
        var current_day := _world_day_index()
        if current_day != last_event_day:
            last_event_day = current_day
            ghost_step_countdown = rng.randi_range(500, 999)
            _refresh_daily_events(true)
        # Decorative pink flowers sway one pixel left/right in place.
        flower_anim_time += delta
        var flower_offset := int(round(sin(flower_anim_time * 4.0)))
        for flower in animated_flowers:
            if is_instance_valid(flower):
                flower.offset.x = flower_offset

        water_anim_time += delta
        if water_anim_time >= WATER_FRAME_TIME:
            water_anim_time = 0.0
            water_frame = 1 - water_frame

            for sprite in water_sprites:
                if is_instance_valid(sprite):
                    sprite.region_rect = Rect2(water_frame * TILE, 0, TILE, TILE)

        if sleeping_bag_sprite != null and is_instance_valid(sleeping_bag_sprite):
            sleeping_bag_anim_time += delta
            if bed_rest_active:
                sleeping_bag_sprite.visible = true
                player.visible = false
            elif sleeping_bag_anim_time < 0.30:
                sleeping_bag_sprite.visible = false
                player.visible = true
                player.set("facing", Vector2.RIGHT)
                if player.has_method("_update_sprite_frame"):
                    player.call("_update_sprite_frame", false)
            elif sleeping_bag_anim_time < 0.72:
                sleeping_bag_sprite.visible = true
                sleeping_bag_sprite.texture = SOURCE_SLEEPING_BAG
                player.visible = true
                player.set("facing", Vector2.LEFT)
                if player.has_method("_update_sprite_frame"):
                    player.call("_update_sprite_frame", false)
            else:
                sleeping_bag_sprite.visible = true
                sleeping_bag_sprite.texture = (
                    sleeping_bag_rest_texture
                    if sleeping_bag_rest_texture != null
                    else SOURCE_SLEEPING_BAG
                )
                player.visible = false
            for mark_index in range(sleeping_bag_sleep_marks.size()):
                var mark := sleeping_bag_sleep_marks[mark_index]
                if is_instance_valid(mark):
                    var phase := fmod(sleeping_bag_anim_time + mark_index * 0.45, 1.35)
                    mark.visible = sleeping_bag_anim_time >= 0.72 and phase < 0.92
                    mark.position.y = -12.0 - mark_index * 5.0 - phase * 4.0

        if not field_helper_pokemon.is_empty() and is_instance_valid(field_helper_sprite):
            _place_field_helper_live()
        if active_field_move == "FLY":
            _set_fly_shadow_active(true)
            _update_fly_shadow()
        elif active_field_move == "RIDE":
            var ride_jumping := player.has_method("is_ledge_jump_active") and \
                bool(player.call("is_ledge_jump_active"))
            _set_fly_shadow_active(ride_jumping)
            if ride_jumping:
                _update_fly_shadow()
        elif is_instance_valid(fly_shadow):
            fly_shadow.visible = false
        if build_mode_active:
            _update_build_preview()

    _update_house_pokemon(delta)
    if not generated or not gameplay_enabled:
        return

    _update_sand_traps(delta)
    if not gameplay_enabled:
        return
    var cell := _player_cell()
    if active_field_move in ["FLY", "SURF"]:
        _clamp_flying_player_to_world()
        if not gameplay_enabled:
            return
        cell = _player_cell()

    _update_normal_grass_front_overlay(cell)
    _update_savanna_tree_front_overlay(cell)

    if active_area_id != "OVERWORLD":
        SourceMineRuntime.update(self, delta)
        if not gameplay_enabled:
            return
        if cell != last_player_cell:
            _advance_follower(last_player_cell, cell)
            last_player_cell = cell
            _refresh_house_structure_depths()
            _spawn_puddle_step_effect(cell)
            player_stepped.emit()
            if _try_step_transition(cell):
                return
            if (
                    not encounter_grace_active()
                    and not _repel_blocks(_level_for_cell(cell))
                    and rng.randi_range(1, 100) < SOURCE_INTERIOR_ENCOUNTER_RATE
                ):
                _request_source_area_encounter()
        return

    _update_ecology(delta)
    _update_deployed_pokemon(delta)
    _update_wild_pokemon(delta)

    if cell != last_player_cell:
        _advance_follower(last_player_cell, cell)
        preload("res://scripts/source_footprints.gd").leave(self, last_player_cell, cell)
        last_player_cell = cell
        _refresh_house_structure_depths()
        _spawn_puddle_step_effect(cell)
        if active_field_move == "SURF" and terrain_kind_at(cell) != 0:
            clear_active_field_move(false)
        _discover_around(cell, 9 if _flash_is_active() else DISCOVERY_RADIUS)
        _handle_biome_entry(cell)
        if active_field_move != "FLY":
            player_stepped.emit()
            preload("res://scripts/rare_forest_mew.gd").on_step(self, cell)
            preload("res://scripts/rare_biome_legendaries.gd").on_step(self, cell)
        if active_field_move == "FLY":
            return
        if _check_trainer_sight(cell):
            return
        if _try_step_transition(cell):
            return

        var wild_id := _wild_id_at_cell(cell)
        if active_field_move != "SURF" and wild_id >= 0 and not encounter_grace_active():
            # Visible overworld Pokemon are solid/contact actors, not grass-like
            # encounter triggers. Battles from angry Pokemon still start through
            # their pursuit/contact path below; hidden burrowed encounters keep
            # their authored step trigger.
            var stepped_wild: Dictionary = wild_pokemon.get(wild_id, {})
            var wild_repelled := _repel_blocks(int(stepped_wild.get("level", 1)))
            if bool(stepped_wild.get("burrowed", false)) and not wild_repelled:
                _trigger_burrowed_pokemon(wild_id)
                return

        if (
                active_field_move != "SURF"
                and not encounter_grace_active()
                and _is_tall_grass_cell(cell)
                and not _repel_blocks(_level_for_cell(cell))
            ):
            # Source PkmnMap rolls 1..100 and starts a grass encounter at
            # <= 75. Keep the source rate so encounter grass cannot appear dead.
            if rng.randi_range(1, 100) <= SOURCE_GRASS_ENCOUNTER_RATE:
                encounter_count += 1
                _request_random_encounter()

func try_walk_into_door(position: Vector2, movement: Vector2) -> bool:
    if not generated or not gameplay_enabled or build_mode_active or \
            active_field_move == "FLY" or movement.length_squared() < 0.0001:
        return false
    var direction := Vector2i(0, (1 if movement.y > 0.0 else -1 if movement.y < 0.0 else 0))
    if absf(movement.x) > absf(movement.y):
        direction = Vector2i((1 if movement.x > 0.0 else -1 if movement.x < 0.0 else 0), 0)
    # Probe just beyond the player's existing 10x10 collision body (offset Y=3).
    # Solid doors stop the body before its centre can reach a step trigger.
    var probe := position + Vector2(0, 3) + Vector2(direction) * 6.0
    var target := Vector2i((probe / float(TILE)).floor())
    if target == Vector2i((position / float(TILE)).floor()):
        return false
    var data: Dictionary = built_structures.get(target, {})
    if String(data.get("name", "")) == "DOOR" and not bool(data.get("gate", false)):
        if active_area_id == "OVERWORLD":
            var outward := _house_door_outward(target)
            if outward == Vector2i.ZERO or direction != -outward or not _house_exit_clear(target + outward):
                return false
            var state := _built_house_state(target)
            if not bool(state.get("ready", false)):
                return false
            _prepare_built_house_interior(target, state)
            _enter_source_area("HOUSE", target + outward)
            return true
        if not bool(data.get("open", false)):
            _toggle_structure_door(target)
        return false
    if active_area_id != "OVERWORLD" or direction != Vector2i.UP:
        return false
    var landmark: Dictionary = landmarks.get(target, {})
    var kind := String(landmark.get("type", ""))
    if kind in ["source_house", "source_cave", "source_area"]:
        var area := "HOUSE" if kind == "source_house" else "CAVE"
        if kind == "source_area":
            area = String(landmark.get("area", ""))
        _enter_source_area(area, target + Vector2i.DOWN)
        return true
    return _try_step_transition(target)


func _try_step_transition(cell: Vector2i) -> bool:
    # Built-house stairs are entered by stepping onto them, matching the source
    # house flow. A-button interaction remains available as a redundant route.
    if active_area_id == "HOUSE" and built_structures.has(cell):
        var built_data: Dictionary = built_structures[cell]
        if String(built_data.get("name", "")) == "STAIRS" and \
                _stair_belongs_to_active_house(built_data):
            _use_linked_stairs(cell)
            return true
    var action := String(interior_interactables.get(cell, ""))
    if not (
            action.begins_with("GOTO_SOURCE_LAYER:")
            or action.begins_with("EXIT_AREA:")
            or action.begins_with("GOTO_AREA:")
            or action == "EXIT_HOUSE"
            or action == "EXIT_CAVE"
        ):
        return false
    _use_interior_interactable(action, cell)
    return true

func _check_trainer_sight(player_cell: Vector2i) -> bool:
    var defeated := event_progress.get("trainer_defeated", {}) as Dictionary
    for raw_id in event_npcs.keys():
        var trainer_id := String(raw_id)
        if bool(defeated.get(trainer_id, false)):
            continue
        var npc := event_npcs[raw_id] as Dictionary
        var npc_cell: Vector2i = npc.get("cell", Vector2i.ZERO)
        var offset := player_cell - npc_cell
        if not (offset.x == 0 or offset.y == 0):
            continue
        var distance := absi(offset.x) + absi(offset.y)
        if distance <= 0 or distance > 5:
            continue
        var direction := Vector2i(signi(offset.x), signi(offset.y))
        var clear_line := true
        for step in range(1, distance):
            var check := npc_cell + direction * step
            if not _is_walkable(check) or interior_interactables.has(check):
                clear_line = false
                break
        if not clear_line:
            continue
        var context := (npc.get("context", {}) as Dictionary).duplicate(true)
        context["cell_x"] = npc_cell.x
        context["cell_y"] = npc_cell.y
        pending_battle_context = context.duplicate(true)
        world_message.emit("!")
        battle_requested.emit(context)
        return true
    return false

func _unhandled_input(event: InputEvent) -> void:
    if not generated or not gameplay_enabled:
        return

    if not planting_item.is_empty() and event.is_action_pressed("cancel"):
        planting_item = ""
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("shoulder_left"):
        if active_field_move == "BUILD":
            _cycle_build_selection(-1)
            get_viewport().set_input_as_handled()
            return
        if active_field_move == "DIG":
            _cycle_dig_selection(-1)
            get_viewport().set_input_as_handled()
            return
        if active_field_move == "PAINT":
            _cycle_paint_selection(-1)
            get_viewport().set_input_as_handled()
            return
        if active_field_move == "TELEPORT":
            _cycle_travel_selection(-1)
            get_viewport().set_input_as_handled()
            return

    if event.is_action_pressed("shoulder_right"):
        if active_field_move == "BUILD":
            _cycle_build_selection(1)
            get_viewport().set_input_as_handled()
            return
        if active_field_move == "DIG":
            _cycle_dig_selection(1)
            get_viewport().set_input_as_handled()
            return
        if active_field_move == "PAINT":
            _cycle_paint_selection(1)
            get_viewport().set_input_as_handled()
            return
        if active_field_move == "TELEPORT":
            _cycle_travel_selection(1)
            get_viewport().set_input_as_handled()
            return

    if not active_field_move.is_empty() and event.is_action_pressed("cancel"):
        if active_field_move == "FLY" and not _valid_fly_landing(_player_cell()):
            world_message.emit("You cannot land here.")
            get_viewport().set_input_as_handled()
            return
        clear_active_field_move()
        get_viewport().set_input_as_handled()
        return

    if event.is_action_pressed("cancel") and active_field_move.is_empty():
        var direction := _facing_cell()
        if _try_push_fenced_pokemon(_player_cell() + direction, direction, false):
            get_viewport().set_input_as_handled()
            return

    if event.is_action_pressed("confirm"):
        _interact_in_front()
        get_viewport().set_input_as_handled()

func set_active_field_move(pokemon_data: Dictionary, move: String) -> bool:
    if int(pokemon_data.get("hp", 1)) <= 0:
        world_message.emit("A fainted POKEMON cannot use a Field Move.")
        return false
    if active_field_move == "FLY" and not _valid_fly_landing(_player_cell()):
        world_message.emit("Land on safe ground before changing field moves.")
        return false
    clear_active_field_move(false)
    active_field_pokemon = pokemon_data.duplicate(true)
    active_field_species = String(pokemon_data.get("species", "")).to_lower()
    active_field_move = move.to_upper()
    if active_field_move == "FLY" and "FLY" not in FieldMoveData.field_moves_for(active_field_species):
        world_message.emit("This Pokemon cannot use FLY.")
        active_field_move = ""
        active_field_species = ""
        active_field_pokemon.clear()
        return false
    if active_field_move == "PAINT" and active_field_species != "smeargle":
        world_message.emit("Only SMEARGLE can use PAINT.")
        active_field_move = ""
        active_field_species = ""
        active_field_pokemon.clear()
        return false
    if active_field_move == "SURF":
        var target := _player_cell() + _facing_cell()
        if active_area_id != "OVERWORLD" or terrain_kind_at(target) != 0:
            world_message.emit("Face open water to use SURF.")
            active_field_move = ""
            active_field_species = ""
            active_field_pokemon.clear()
            return false
    if active_field_move == "FLY" and active_area_id != "OVERWORLD":
        world_message.emit("FLY cannot be used indoors.")
        active_field_move = ""
        active_field_species = ""
        active_field_pokemon.clear()
        return false
    if active_field_move == "TELEPORT" and _travel_destinations(false).is_empty():
        world_message.emit("Place a BEACON before using TELEPORT.")
        active_field_move = ""
        active_field_species = ""
        active_field_pokemon.clear()
        return false
    var placed := set_follower(pokemon_data, false) if active_field_move in ["FOLLOW", "FLASH", "POWER"] \
        else _set_field_helper(pokemon_data)
    if not placed:
        active_field_move = ""
        active_field_species = ""
        active_field_pokemon.clear()
        return false
    build_mode_active = active_field_move in ["BUILD", "PAINT"]
    if active_field_move == "RIDE":
        if player.has_method("set_field_speed_multiplier"):
            player.call("set_field_speed_multiplier", 1.80)
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -9))
        _set_fly_shadow_active(false)
    if active_field_move == "FLY":
        field_previous_collision_mask = player.collision_mask
        player.collision_mask = 0
        if player.has_method("set_field_speed_multiplier"):
            player.call("set_field_speed_multiplier", 1.9)
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -10))
        _set_fly_shadow_active(true)
        world_message.emit("FLY is active. Move freely; press B over safe ground to land.")
    if active_field_move == "SURF":
        _set_water_collision_enabled(false)
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -5))
    if active_field_move == "REPEL":
        repel_until_elapsed = 0.0
        world_message.emit("REPEL is active.")
    elif active_field_move == "BUILD":
        _position_build_helper()
        set_build_preview_active(true)
        _show_current_build_selection()
    elif active_field_move == "DIG":
        _show_current_dig_selection()
    elif active_field_move == "PAINT":
        _show_current_paint_selection()
    elif active_field_move == "TELEPORT":
        travel_selection_index = 0
        teleport_map_requested.emit(_travel_destinations(false))
    return true

func clear_active_field_move(show_message: bool = true) -> void:
    var previous_move := active_field_move
    if active_field_move == "FLY":
        player.collision_mask = field_previous_collision_mask
        _set_fly_shadow_active(false)
    if active_field_move == "SURF":
        _set_water_collision_enabled(true)
    if active_field_move in ["RIDE", "SURF", "FLY"] and \
            player.has_method("set_field_visual_offset"):
        player.call("set_field_visual_offset", Vector2.ZERO)
    if active_field_move == "RIDE":
        _set_fly_shadow_active(false)
    if player.has_method("set_field_speed_multiplier"):
        player.call("set_field_speed_multiplier", 1.0)
    active_field_move = ""
    active_field_species = ""
    active_field_pokemon.clear()
    repel_until_elapsed = 0.0
    build_mode_active = false
    set_build_preview_active(false)
    clear_field_helper()
    if previous_move in ["FOLLOW", "FLASH", "POWER"]:
        clear_follower()
    # Field moves stop silently.

func _set_fly_shadow_active(active: bool) -> void:
    if active:
        if not is_instance_valid(fly_shadow):
            fly_shadow = Polygon2D.new()
            fly_shadow.name = "FlyShadow"
            fly_shadow.polygon = PackedVector2Array([
                Vector2(-6, 0), Vector2(-5, -2), Vector2(-3, -3),
                Vector2(3, -3), Vector2(5, -2), Vector2(6, 0),
                Vector2(5, 2), Vector2(3, 3), Vector2(-3, 3),
                Vector2(-5, 2)
            ])
            fly_shadow.color = Color(0.02, 0.02, 0.02, 0.92)
            fly_shadow.antialiased = false
            fly_shadow.z_as_relative = false
            add_child(fly_shadow)
        fly_shadow.visible = true
        _update_fly_shadow()
    elif is_instance_valid(fly_shadow):
        fly_shadow.visible = false

func _update_fly_shadow() -> void:
    if not is_instance_valid(fly_shadow):
        return
    # The CharacterBody remains on the logical map coordinate while only the
    # displayed player is lifted. This keeps smooth unrestricted FLY movement
    # and leaves the source-style oval shadow directly beneath the character.
    var travel_offset := Vector2.ZERO
    if active_field_move == "RIDE" and player.has_method("ledge_jump_travel_offset"):
        travel_offset = Vector2(player.call("ledge_jump_travel_offset"))
    fly_shadow.global_position = (
        player.global_position + travel_offset
    ).round() + Vector2(0, 5)
    fly_shadow.z_index = player.z_index - 2

func _repel_blocks(opponent_level: int) -> bool:
    if active_field_move == "REPEL":
        return _effective_wild_level(opponent_level) < maxi(
            1, int(active_field_pokemon.get("level", 1))
        )
    return world_elapsed_seconds < repel_until_elapsed

func _effective_wild_level(source_level: int) -> int:
    # Main owns the current party and its adaptive encounter rule. Keep raw
    # levels for isolated World fixtures and startup states with no party.
    var main := get_parent()
    if main != null and main.has_method("wild_level_for_player"):
        var party = main.get("caught_pokemon")
        if typeof(party) == TYPE_ARRAY and not (party as Array).is_empty():
            return int(main.call("wild_level_for_player", source_level))
    return source_level

func set_follower(
        pokemon_data: Dictionary, show_message: bool = true
    ) -> bool:
    var species := String(pokemon_data.get("species", "")).to_lower()
    var texture := PokemonData.record_texture(pokemon_data, "overworld")
    if texture == null:
        texture = FARM_POKEMON_TEXTURES.get(species) as Texture2D
    if texture == null:
        if show_message:
            world_message.emit("That Pokemon cannot follow here.")
        return false
    var behavior: Dictionary = PokemonData.info(species).get("overworld_behavior", {})
    # Mega Gyarados rears up out of the water and follows on land as well;
    # wild ones still keep to the water.
    if bool(behavior.get("swim_only", false)) and species != "mega_gyarados" and terrain_kind_at(_player_cell()) != 0:
        if show_message:
            world_message.emit("%s can only follow while swimming." % PokemonData.battle_display_name(species))
        return false

    clear_follower()
    follower_pokemon = PokemonEcology.ensure_record(
        pokemon_data, rng, "follower:%s" % species
    )
    follower_pokemon["behavior"] = behavior
    follower_sprite = Sprite2D.new()
    follower_sprite.texture = texture
    follower_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    follower_sprite.z_as_relative = false
    follower_sprite.physics_interpolation_mode = \
        Node.PHYSICS_INTERPOLATION_MODE_OFF
    _configure_overworld_sprite(follower_sprite)
    var layer := get_node_or_null("LandmarkLayer") as Node2D
    if layer == null:
        follower_pokemon.clear()
        follower_sprite = null
        return false
    layer.add_child(follower_sprite)
    preload("res://scripts/shiny_sparkles.gd").attach(follower_sprite, pokemon_data)
    _sync_follower_to_player()
    if show_message:
        world_message.emit("%s is following you." % PokemonData.battle_display_name(species))
    return true

func clear_follower() -> void:
    if follower_move_tween != null and follower_move_tween.is_valid():
        follower_move_tween.kill()
    follower_move_tween = null
    if is_instance_valid(follower_sprite):
        follower_sprite.queue_free()
    follower_sprite = null
    follower_pokemon.clear()
    follower_cell = Vector2i(-2147483648, -2147483648)

func _set_field_helper(pokemon_data: Dictionary) -> bool:
    var species := String(pokemon_data.get("species", "")).to_lower()
    var texture := PokemonData.record_texture(pokemon_data, "overworld")
    if texture == null:
        texture = FARM_POKEMON_TEXTURES.get(species) as Texture2D
    if texture == null:
        return false
    if active_field_move in ["CUT", "BUILD", "DIG", "HEADBUTT", "SMASH"]:
        var front := _player_cell() + _facing_cell()
        var clear := _is_built_house_floor_cell(front) and not blocked.has(front) and not built_structures.has(front) and not deployed_pokemon.has(front)
        clear = clear or _field_helper_cell_is_clear(front)
        if not clear or (active_field_move in ["CUT", "HEADBUTT"] and (_is_cuttable_grass_cell(front) or _cut_helper_tree_cell(front))) or (active_field_move == "SMASH" and _smash_helper_rock_cell(front)):
            world_message.emit("Leave one clear tile ahead for your POKEMON.")
            return false
    clear_field_helper()
    field_helper_pokemon = PokemonEcology.ensure_record(
        pokemon_data, rng, "field:%s" % species)
    field_helper_sprite = Sprite2D.new()
    field_helper_sprite.texture = texture
    field_helper_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    field_helper_sprite.z_as_relative = false
    field_helper_sprite.physics_interpolation_mode = \
        Node.PHYSICS_INTERPOLATION_MODE_OFF
    _configure_overworld_sprite(field_helper_sprite)
    if species in ["aexeggutor", "exeggutor_alolan"]:
        field_helper_sprite.hframes = 6
        field_helper_sprite.vframes = 1
        field_helper_sprite.set_meta("alolan_exeggutor_walk", true)
    var layer := get_node_or_null("LandmarkLayer") as Node2D
    if layer == null:
        field_helper_pokemon.clear()
        field_helper_sprite = null
        return false
    layer.add_child(field_helper_sprite)
    preload("res://scripts/shiny_sparkles.gd").attach(field_helper_sprite, pokemon_data)
    _place_field_helper_live()
    return true

func clear_field_helper() -> void:
    if is_instance_valid(work_trainer_sprite):
        work_trainer_sprite.queue_free()
    work_trainer_sprite = null
    work_trail.clear()
    if is_instance_valid(player) and is_instance_valid(player.sprite):
        player.sprite.visible = true
    if is_instance_valid(field_helper_sprite):
        field_helper_sprite.queue_free()
    field_helper_sprite = null
    field_helper_pokemon.clear()
    field_helper_cell = Vector2i(-2147483648, -2147483648)

func present_field_move_pokemon() -> void:
    # Field-move users appear directly in front of the player before settling
    # into the normal follower cadence. There is no rotation or spin effect.
    var sprite := follower_sprite if active_field_move == "FOLLOW" else field_helper_sprite
    if not is_instance_valid(sprite):
        return
    if active_field_move == "FOLLOW":
        _place_follower_live()
    else:
        _place_field_helper_live()
    var source_sound := String({
        "BUILD":"move_object", "CUT":"cut1", "FLY":"fly_takingoff1",
        "SURF":"swim1", "DIG":"dig1", "RIDE":"ride1",
        "SMASH":"strength1", "TELEPORT":"teleport_start1",
        "FLASH":"ap1", "CHARM":"fanfare1"
    }.get(active_field_move, ""))
    if not source_sound.is_empty():
        play_source_sound(source_sound)

func _position_build_helper() -> void:
    if (
            active_field_move != "BUILD"
            or field_helper_pokemon.is_empty()
            or not is_instance_valid(field_helper_sprite)
        ):
        return
    _place_field_helper_live()

func _place_follower_live() -> void:
    if follower_pokemon.is_empty() or not is_instance_valid(follower_sprite):
        return
    if follower_move_tween != null and follower_move_tween.is_valid():
        follower_move_tween.kill()
    follower_move_tween = null
    var facing := _facing_cell()
    var offset := -facing
    var target_cell := _player_cell() + offset
    if active_area_id == "OVERWORLD":
        var can_use_target := _pokemon_can_enter(
            String(follower_pokemon.get("species", "")), target_cell)
        if not can_use_target or deployed_pokemon.has(target_cell) or \
                _wild_id_at_cell(target_cell) >= 0 or wild_eggs.has(target_cell):
            target_cell = _player_cell()
            offset = Vector2i.ZERO
    follower_cell = target_cell
    follower_sprite.visible = true
    follower_sprite.position = (
        player.position + Vector2(offset) * float(TILE)
    )
    follower_sprite.z_index = _depth_z(target_cell)
    _set_overworld_motion_frame(follower_sprite, facing, int(player.walk_phase))
    follower_sprite.offset = Vector2(0, -16) if follower_sprite.has_meta("alolan_exeggutor_walk") else Vector2.ZERO

func _place_field_helper_live() -> void:
    if field_helper_pokemon.is_empty() or not is_instance_valid(field_helper_sprite):
        return
    var facing := _facing_cell()
    if active_field_move in ["RIDE", "SURF", "FLY"]:
        # Mount field moves use the Pokemon as the mount, not a follower one tile
        # in front. Follow the player's rendered position so RIDE jump arcs and
        # FLY elevation stay visually locked together without per-frame path or
        # collision queries.
        var visual_offset := Vector2.ZERO
        if player.has_method("mount_visual_offset"):
            visual_offset = Vector2(player.call("mount_visual_offset"))
        var mount_offset := Vector2(0, 3)
        if active_field_move == "SURF":
            mount_offset = Vector2(0, 3)
        elif active_field_move == "FLY":
            mount_offset = Vector2(0, 2)
        field_helper_cell = _player_cell()
        field_helper_sprite.visible = true
        field_helper_sprite.position = (
            player.position + visual_offset + mount_offset
        ).round()
        field_helper_sprite.z_index = player.z_index - 1
        var moving := player.velocity.length_squared() > 0.01 or \
            (player.has_method("is_ledge_jump_active") and \
            bool(player.call("is_ledge_jump_active")))
        var phase := int(preload("res://scripts/game_clock.gd").ticks_msec() / 180) % 2 if moving else 0
        _set_overworld_motion_frame(field_helper_sprite, facing, phase)
        field_helper_sprite.offset = Vector2.ZERO
        return

    if active_field_move in ["CUT", "BUILD", "DIG", "HEADBUTT", "SMASH"]:
        _place_controlled_work_pokemon(facing)
        return

    # Other work helpers stand in the tile directly in front of the player.
    # They are visual actors and have no collision body, so an occupied work tile
    # is valid: CUT can stand on the tree/grass work point, BUILD on its preview,
    # DIG on the ground, etc. Never move a helper to a side or behind the player.
    var target_cell := _player_cell() + facing
    field_helper_cell = target_cell
    field_helper_sprite.visible = true
    field_helper_sprite.position = (
        player.position + Vector2(facing) * float(TILE)
    ).round()
    field_helper_sprite.z_index = _depth_z(target_cell) + 1
    if active_field_move == "CUT":
        _set_cut_helper_facing(facing, int(player.walk_phase))
    else:
        _set_overworld_motion_frame(field_helper_sprite, facing, int(player.walk_phase))
    field_helper_sprite.offset = Vector2(0, -16) if field_helper_sprite.has_meta("alolan_exeggutor_walk") else Vector2.ZERO

func _place_controlled_work_pokemon(facing: Vector2i) -> void:
    if not is_instance_valid(work_trainer_sprite):
        work_trainer_sprite = Sprite2D.new()
        work_trainer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        work_trainer_sprite.z_as_relative = false
        field_helper_sprite.get_parent().add_child(work_trainer_sprite)
        # Keep the trainer where activation occurred; the controlled Pokemon
        # begins in the clear adjacent tile, not on top of the trainer.
        var start: Vector2 = player.position
        if active_field_move == "DIG":
            start = _cell_center(_player_cell())
            player.position = start
        player.position += Vector2(facing) * TILE
        work_trail.assign([start, player.position] if start != player.position else [start])
        work_trainer_position = start
        work_trainer_sprite.position = start.round()
        work_trainer_facing = facing
        work_trainer_walking = false
    player.sprite.visible = false
    field_helper_cell = _player_cell()
    field_helper_sprite.position = player.position.round()
    field_helper_sprite.z_index = _depth_z(field_helper_cell)
    field_helper_sprite.visible = true
    if active_field_move in ["CUT", "DIG"]:
        _set_cut_helper_facing(facing, int(player.walk_phase))
    else:
        _set_overworld_motion_frame(field_helper_sprite, facing, int(player.walk_phase))
    field_helper_sprite.offset = Vector2(0, -16) if field_helper_sprite.has_meta("alolan_exeggutor_walk") else Vector2.ZERO
    var leader_moved := work_trail[-1].distance_to(player.position) > 0.001
    if leader_moved:
        if work_trail[-1].distance_to(player.position) > TILE * 2:
            work_trail.assign([player.position])
        else:
            work_trail.append(player.position)
    var remaining := float(TILE)
    var trainer_position: Vector2 = work_trail[0]
    for index in range(work_trail.size() - 1, 0, -1):
        var segment := work_trail[index].distance_to(work_trail[index - 1])
        if segment >= remaining:
            trainer_position = work_trail[index].move_toward(work_trail[index - 1], remaining)
            if index > 1:
                work_trail = work_trail.slice(index - 1)
            break
        remaining -= segment
    var trainer_motion := trainer_position - work_trainer_position
    if leader_moved:
        work_trainer_walking = trainer_motion.length_squared() > 0.001
    work_trainer_position = trainer_position
    if trainer_motion.length_squared() > 0.001:
        work_trainer_facing = Vector2i(int(signf(trainer_motion.x)), 0) if absf(trainer_motion.x) > absf(trainer_motion.y) else Vector2i(0, int(signf(trainer_motion.y)))
    work_trainer_sprite.position = trainer_position.round()
    work_trainer_sprite.texture = player.sprite.texture
    work_trainer_sprite.hframes = 8
    work_trainer_sprite.vframes = 1
    var base := 1 if work_trainer_facing.y < 0 else (0 if work_trainer_facing.y > 0 else (2 if work_trainer_facing.x < 0 else 3))
    work_trainer_sprite.frame = base + (4 if player.walk_phase and work_trainer_walking else 0)
    work_trainer_sprite.flip_h = player.walk_phase and player.source_alternate_step and work_trainer_facing.y != 0
    work_trainer_sprite.z_index = _depth_z(Vector2i(floori(trainer_position.x / TILE), floori(trainer_position.y / TILE)))

func _set_cut_helper_facing(facing: Vector2i, phase: int = 0) -> void:
    # Most bundled sheets are side/back/front pairs. Krabby and Kingler's
    # authored sheets instead contain front/side/back pairs.
    var species := String(field_helper_pokemon.get("species", "")).to_lower()
    if species in ["krabby", "kingler"] and field_helper_sprite.hframes >= 6:
        field_helper_sprite.frame = (4 if facing.y < 0 else (0 if facing.y > 0 else 2)) + phase
        field_helper_sprite.flip_h = facing.x > 0
    else:
        _set_overworld_motion_frame(field_helper_sprite, facing, phase)


func _field_helper_can_use_work_target(cell: Vector2i) -> bool:
    if deployed_pokemon.has(cell) or wild_eggs.has(cell) or \
            _wild_id_at_cell(cell) >= 0:
        return false

    if active_field_move == "CUT":
        if not house_wall_decoration_at(cell).is_empty():
            return true
        if built_structures.has(cell):
            var built_name: String = String((built_structures[cell] as Dictionary).get(
                "name", ""))
            return built_name not in ["GRAVE", "STATUE"]
        if _is_cuttable_grass_cell(cell):
            return true
        var cut_exact: Vector2i = _exact_resource_anchor(cell)
        if cut_exact.x > -2147483648:
            return _exact_resource_kind(cut_exact) in ["tree", "bush"]
        var cut_resource: Vector2i = _resource_object_anchor(cell)
        if cut_resource.x > -2147483648:
            return String((resource_objects[cut_resource] as Dictionary).get(
                "type", "")) in ["tree", "bush"]
        return false

    if active_field_move == "HEADBUTT":
        var head_exact: Vector2i = _exact_resource_anchor(cell)
        if head_exact.x > -2147483648 and exact_world != null:
            var head_tile: SourceTile = exact_world.tile_at(head_exact)
            return head_tile != null and (
                head_tile.is_headbuttable or _exact_resource_kind(head_exact) == "rock"
            )
        var head_resource: Vector2i = _resource_object_anchor(cell)
        if head_resource.x > -2147483648:
            return String((resource_objects[head_resource] as Dictionary).get(
                "type", "")) in ["tree", "bush", "cactus", "rock"]
        return false

    if active_field_move == "SMASH":
        if built_structures.has(cell):
            return String((built_structures[cell] as Dictionary).get(
                "name", "")) in ["GRAVE", "STATUE"]
        var smash_exact: Vector2i = _exact_resource_anchor(cell)
        if smash_exact.x > -2147483648:
            return _exact_resource_kind(smash_exact) == "rock"
        var smash_resource: Vector2i = _resource_object_anchor(cell)
        return smash_resource.x > -2147483648 and String((
            resource_objects[smash_resource] as Dictionary).get("type", "")) == "rock"

    if active_field_move == "DIG":
        if active_area_id == "HOUSE":
            return _is_built_house_floor_cell(cell) and not blocked.has(cell) and not built_structures.has(cell) and not interior_interactables.has(cell)
        if built_structures.has(cell) or landmarks.has(cell) or resource_objects.has(cell):
            return false
        if exact_world_mode and exact_world != null:
            var dig_tile: SourceTile = exact_world.tile_at(cell)
            if dig_tile == null or dig_tile.is_water:
                return false
            var dig_names: String = (dig_tile.name + " " + dig_tile.name_upper).to_lower()
            var diggable_mountain: bool = "mountain" in dig_names or "ledges3" in dig_names
            return (not dig_tile.is_solid and not dig_tile.is_ledge) or diggable_mountain
        return _in_bounds(cell) and terrain_kind_at(cell) != 0 and not blocked.has(cell)

    if active_field_move == "PAINT":
        return active_area_id == "HOUSE" and built_house_paintable_walls.has(cell)
    return false

func _field_helper_target_cell(move: String) -> Vector2i:
    if active_field_move != move or field_helper_pokemon.is_empty():
        return Vector2i(-2147483648, -2147483648)
    if field_helper_cell.x <= -2147483648:
        return Vector2i(-2147483648, -2147483648)
    # SMASH works on what the Pokemon faces, like the other moves. It used to
    # work only on the tile the Pokemon stood on, so a GRAVE or STATUE, which
    # cannot be stood on, could never be smashed.
    var target := field_helper_cell + _facing_cell() if move in ["CUT", "BUILD", "DIG", "HEADBUTT", "SMASH"] else field_helper_cell
    if move == "SMASH" and not _field_helper_can_use_work_target(target) and _field_helper_can_use_work_target(field_helper_cell):
        target = field_helper_cell
    if not _field_helper_can_use_work_target(target):
        return Vector2i(-2147483648, -2147483648)
    return target

func _field_move_action_cell(default_cell: Vector2i, move: String) -> Vector2i:
    if move == "DIG" and active_field_move == "DIG":
        # The controlled body is the Pokemon. A cached helper cell can still
        # describe its previous physics position when an action arrives.
        return _player_cell() + _facing_cell()
    var helper_target: Vector2i = _field_helper_target_cell(move)
    return helper_target if helper_target.x > -2147483648 else default_cell

func _cut_helper_target_cell() -> Vector2i:
    if active_field_move != "CUT" or field_helper_pokemon.is_empty():
        return Vector2i(-2147483648, -2147483648)
    _place_field_helper_live()
    var target := field_helper_cell + _facing_cell()
    if _field_helper_can_use_work_target(target):
        return target
    # The controlled body is 10px wide and can contact an adjacent row before
    # its center changes cells. Resolve only cells touched by its forward edge.
    var facing := Vector2(_facing_cell())
    var tangent := Vector2(-facing.y, facing.x)
    var body_shape := player.get_node("CollisionShape2D") as CollisionShape2D
    var body_center: Vector2 = player.position + body_shape.position
    for offset in [0.0, -4.9, 4.9]:
        var point: Vector2 = body_center + facing * 6.0 + tangent * float(offset)
        var contact := Vector2i(floori(point.x / TILE), floori(point.y / TILE))
        if _field_helper_can_use_work_target(contact): return contact
    return Vector2i(-2147483648, -2147483648)

func _smash_helper_rock_cell(cell: Vector2i) -> bool:
    if String(built_structures.get(cell, {}).get("name", "")) in ["GRAVE", "STATUE"]:
        return true
    var exact_anchor := _exact_resource_anchor(cell)
    if exact_anchor.x > -2147483648 and _exact_resource_kind(exact_anchor) == "rock":
        return true
    var anchor := _resource_object_anchor(cell)
    return anchor.x > -2147483648 and String(resource_objects[anchor].get("type", "")) == "rock"

func _cut_helper_tree_cell(cell: Vector2i) -> bool:
    var exact_anchor := _exact_resource_anchor(cell)
    if exact_anchor.x > -2147483648 and _exact_resource_kind(exact_anchor) in ["tree", "bush"]:
        return true
    var anchor := _resource_object_anchor(cell)
    return anchor.x > -2147483648 and String(resource_objects[anchor].get("type", "")) in ["tree", "bush"]

func _field_helper_cell_is_clear(cell: Vector2i) -> bool:
    if not _pokemon_can_enter(active_field_species, cell):
        return false
    return (
        not built_structures.has(cell)
        and not landmarks.has(cell)
        and not resource_objects.has(cell)
        and not deployed_pokemon.has(cell)
        and not wild_eggs.has(cell)
        and _wild_id_at_cell(cell) < 0
    )

func _sync_follower_to_player() -> void:
    if follower_pokemon.is_empty() or not is_instance_valid(follower_sprite):
        return
    _place_follower_live()

func _advance_follower(previous_player_cell: Vector2i, _new_player_cell: Vector2i) -> void:
    if follower_pokemon.is_empty() or not is_instance_valid(follower_sprite):
        return
    if previous_player_cell.x <= -2147483648:
        _place_follower_live()
        return
    var direction := previous_player_cell - follower_cell
    if direction == Vector2i.ZERO:
        direction = _facing_cell()
    follower_cell = previous_player_cell
    follower_walk_phase = 1 - follower_walk_phase
    _set_overworld_motion_frame(
        follower_sprite, Vector2(direction), follower_walk_phase)
    follower_sprite.z_index = _depth_z(follower_cell)
    if follower_move_tween != null and follower_move_tween.is_valid():
        follower_move_tween.kill()
    follower_move_tween = create_tween()
    follower_move_tween.set_trans(Tween.TRANS_LINEAR)
    follower_move_tween.tween_property(
        follower_sprite, "position", _cell_center(follower_cell), 0.18)
    follower_move_tween.tween_callback(func() -> void:
        if is_instance_valid(follower_sprite):
            _set_overworld_motion_frame(follower_sprite, Vector2(direction), 0)
    )

func _interact_follower() -> void:
    if follower_pokemon.is_empty():
        return
    var species := PokemonData.battle_display_name(String(follower_pokemon.get("species", "POKEMON")))
    var happiness := int(follower_pokemon.get("happiness", 70))
    if happiness >= 200:
        world_message.emit("%s is delighted to travel with you!" % species)
        _show_ecology_emote(follower_sprite, "heart")
    elif happiness >= 100:
        world_message.emit("%s is happily following your footsteps." % species)
        _show_ecology_emote(follower_sprite, "happy")
    else:
        world_message.emit("%s is watching the habitat closely." % species)
        _show_ecology_emote(follower_sprite, "question")

func feed_pokemon_in_front(item_name: String) -> bool:
    if not PokemonEcology.is_food(item_name):
        return false
    var target := _player_cell() + _facing_cell()
    var happiness_gain := PokemonEcology.food_happiness(item_name)
    if not follower_pokemon.is_empty() and target in [follower_cell, _player_cell()]:
        _feed_ecology_record(follower_pokemon, happiness_gain)
        if (
                String(active_field_pokemon.get("party_ecology_id", ""))
                == String(follower_pokemon.get("party_ecology_id", ""))
            ):
            active_field_pokemon["happiness"] = int(follower_pokemon["happiness"])
            active_field_pokemon["friendship"] = int(follower_pokemon["friendship"])
        pokemon_ecology_changed.emit(follower_pokemon.duplicate(true))
        _show_ecology_emote(follower_sprite, "heart")
        world_message.emit("%s enjoyed the %s." % [
            PokemonData.battle_display_name(String(follower_pokemon.get("species", "POKEMON"))), item_name
        ])
        return true
    if deployed_pokemon.has(target):
        var deployed: Dictionary = deployed_pokemon[target]
        _feed_ecology_record(deployed, happiness_gain)
        deployed_pokemon[target] = deployed
        _show_ecology_emote(deployed.get("sprite") as Sprite2D, "heart")
        world_message.emit("%s enjoyed the %s." % [
            PokemonData.battle_display_name(String(deployed.get("species", "POKEMON"))), item_name
        ])
        return true
    var wild_id := _wild_id_at_cell(target)
    if wild_id >= 0:
        var wild: Dictionary = wild_pokemon[wild_id]
        if bool(wild.get("burrowed", false)):
            return false
        _feed_ecology_record(wild, happiness_gain)
        wild["fed_until"] = world_elapsed_seconds + 8.0
        wild["aggro_player"] = false
        wild["warned"] = false
        wild_pokemon[wild_id] = wild
        _show_ecology_emote(wild.get("sprite") as Sprite2D, "heart")
        world_message.emit("Wild %s is eating the %s." % [
            PokemonData.battle_display_name(String(wild.get("species", "POKEMON"))), item_name
        ])
        return true
    return false

func _feed_ecology_record(data: Dictionary, happiness_gain: int) -> void:
    data["happiness"] = mini(
        PokemonEcology.MAX_HAPPINESS,
        int(data.get("happiness", 70)) + happiness_gain
    )
    data["friendship"] = int(data["happiness"])

func _set_water_collision_enabled(enabled: bool) -> void:
    if exact_world_mode:
        var stream := get_node_or_null("ExactCollisionStream") as SourceChunkCollisionStreamer
        if stream != null:
            stream.set_allow_water(not enabled)
        return
    for key in ground_collisions.keys():
        var cell: Vector2i = key
        if not _in_bounds(cell) or terrain[cell.y][cell.x] != 0:
            continue
        var collision: CollisionShape2D = ground_collisions.get(cell) as CollisionShape2D
        if is_instance_valid(collision):
            collision.set_deferred("disabled", not enabled)

func _interact_in_front() -> void:
    var target := _player_cell() + _facing_cell()
    if dropped_items().collect(target): return
    if not planting_item.is_empty():
        var item := planting_item
        var main := get_parent()
        if int(main.inventory.get(item,0)) <= 0:
            planting_item = ""
            return
        if await plants().plant(target,item):
            if not main.coop_game.active:main._consume_inventory_item(item)
            if int(main.inventory.get(item,0)) <= 0: planting_item = ""
        return

    # BUILD owns A while its preview is active. Dungeon interaction records
    # share off-world coordinates with houses and must not swallow this action.
    if active_field_move == "BUILD":
        var build_name := _current_build_name()
        if not build_name.is_empty():
            build_requested.emit(build_name, get_build_execution_cell())
        return

    if active_field_move.is_empty() and not built_structures.has(target):
        var source_seat := _source_interior_tile_at_world_cell(target)
        if source_seat != null and "stool" in source_seat.name_upper:
            _sit_on_stool(target)
            return
    var couch_anchor := _couch_anchor_at(target)
    if couch_anchor != Vector2i(2147483647,2147483647):
        if active_field_move.is_empty():
            _interact_built_structure(couch_anchor)
            return
        if active_field_move == "CUT":
            structure_removal_requested.emit(couch_anchor, "CUT")
            return
    if active_field_move.is_empty() and _interact_house_window(target):
        return
    if active_field_move.is_empty() and String(built_structures.get(target + Vector2i.DOWN, {}).get("name", "")) == "BED":
        _interact_built_structure(target + Vector2i.DOWN)
        return
    if interior_interactables.has(target):
        _use_interior_interactable(
            String(interior_interactables[target]), target
        )
        return

    if wild_eggs.has(target):
        if active_field_move == "ATTACK":
            _attack_wild_egg(target)
        else:
            _show_ecology_emote(wild_eggs[target].get("sprite") as Sprite2D, "...")
            egg_pickup_prompt_requested.emit(target)
        return

    # A is the explicit action button for active CUT and BUILD. Resolve these
    # before follower interaction so pressing A uses the move instead of
    # talking to the helper Pokemon standing beside the player.
    if active_field_move == "CUT":
        var cut_target := _cut_helper_target_cell()
        if cut_target.x > -2147483648:
            _try_cut_target(cut_target)
        return
    if active_field_move == "BUILD":
        var build_name := _current_build_name()
        if not build_name.is_empty():
            build_requested.emit(build_name, get_build_execution_cell())
        return
    if active_field_move == "DIG":
        _use_dig(_field_move_action_cell(target, "DIG"))
        return
    if active_field_move == "SMASH":
        target = _field_move_action_cell(target, "SMASH")
        if built_structures.has(target) and String(
                (built_structures[target] as Dictionary).get("name", "")) in \
                ["GRAVE", "STATUE"]:
            structure_removal_requested.emit(target, "SMASH")
        elif exact_world_mode and not _exact_resource_kind(target).is_empty():
            _harvest_exact_resource(target, "SMASH")
        elif resource_objects.has(target):
            _harvest_resource_with_move(target, "SMASH")
        else:
            world_message.emit("There is nothing here that SMASH can break.")
        return
    if active_field_move == "HEADBUTT":
        _use_headbutt(_field_move_action_cell(target, "HEADBUTT"))
        return
    if active_field_move == "TELEPORT":
        teleport_map_requested.emit(_travel_destinations(false))
        return
    if active_field_move == "FLY":
        world_message.emit("Fly to safe ground, then press B to land.")
        return
    if active_field_move == "PAINT":
        paint_requested.emit(paint_selection_index + 1, _field_move_action_cell(target, "PAINT"))
        return
    if active_field_move == "SURF":
        var aquatic_id := _wild_id_at_cell(target)
        if aquatic_id >= 0:
            _interact_wild_pokemon(aquatic_id)
            return
        if deployed_pokemon.has(target):
            _interact_deployed_pokemon(target)
            return
    if active_field_move in ["POWER", "FLASH", "REPEL", "SURF"]:
        world_message.emit({
            "POWER":"There is no machine here that can receive POWER.",
            "FLASH":"FLASH lights the surrounding area.",
            "REPEL":"Wild Pokemon below level %d are being repelled." % maxi(
                1, int(active_field_pokemon.get("level", 1))),
            "SURF":"SURF lets you cross water. Press B to stop."
        }[active_field_move])
        return
    if active_field_move == "RIDE":
        if exact_world_mode and exact_world != null:
            var ride_tile := exact_world.tile_at(target)
            if ride_tile != null and ride_tile.is_ledge:
                _ride_jump_over(target)
                return
        world_message.emit("RIDE increases speed and can jump low ledges or fences.")
        return

    if target == follower_cell and not follower_pokemon.is_empty():
        _interact_follower()
        return

    var wild_id := _wild_id_at_cell(target)
    if wild_id >= 0:
        _interact_wild_pokemon(wild_id)
        return

    if deployed_pokemon.has(target) and (not deployed_pokemon[target].has("house_door") or _house_pokemon_visible(deployed_pokemon[target])):
        if active_field_move == "ATTACK":
            _attack_deployed_pokemon(target)
        else:
            _interact_deployed_pokemon(target)
        return

    if landmarks.has(target):
        var data: Dictionary = landmarks[target]
        var kind: String = String(data.get("type", ""))
        if kind == "sign":
            world_message.emit("A weathered sign: WILD POKEMON LIVE IN TALL GRASS.")
        elif kind == "source_route_sign":
            var route_name := String(route_cells.get(
                WorldParity.nearest_route_cell(target, route_cells), "forest1"
            )).replace("_", " ").to_upper()
            world_message.emit("ROUTE: %s" % route_name)
        elif kind == "source_house":
            _enter_source_area("HOUSE", target + Vector2i.DOWN)
        elif kind == "source_cave":
            _enter_source_area("CAVE", target + Vector2i.DOWN)
        elif kind == "source_area":
            _enter_source_area(
                String(data.get("area", "")),
                target + Vector2i.DOWN
            )
        elif kind == "source_key":
            if bool(data.get("used", false)):
                world_message.emit("There is nothing else here.")
                return
            var coordinator = get_parent().get("coop_game")
            if is_instance_valid(coordinator) and coordinator.active and not coordinator.hosting:
                # A guest takes a key of their own and the key stays where it
                # is: the world's key belongs to the host, so a guest cannot
                # walk in, take it and leave with it.
                if int(get_parent().inventory.get("SECRET KEY", 0)) > 0:
                    world_message.emit("You already have the MANSION KEY.")
                    return
                item_collected.emit(String(data.get("item", "MANSION KEY")))
                world_message.emit("You found the MANSION KEY!")
                return
            if is_instance_valid(coordinator) and coordinator.active:
                # The host's key is recorded with the world, so it stays taken
                # for the host. Guests still find a key there for themselves.
                if await coordinator.building.share_tile_change(target, {"kind": "MANSION_KEY_TAKEN"}, {"SECRET KEY": 1}):
                    _take_mansion_key(target)
                    world_message.emit("You found the MANSION KEY!")
                else:
                    world_message.emit("Try again in a moment.")
                return
            data["used"] = true
            landmarks[target] = data
            var key_sprite: Sprite2D = data.get("sprite") as Sprite2D
            if is_instance_valid(key_sprite):
                key_sprite.visible = false
            var key_collision: CollisionShape2D = data.get("collision") as CollisionShape2D
            if is_instance_valid(key_collision):
                key_collision.queue_free()
            blocked.erase(target)
            item_collected.emit(String(data.get("item", "MANSION KEY")))
            world_message.emit("You found the MANSION KEY!")
        elif kind == "campfire":
            crafting_station_requested.emit("CAMPFIRE")
        elif kind == "item":
            if bool(data.get("used", false)):
                world_message.emit("There is nothing else here.")
                return
            data["used"] = true
            landmarks[target] = data
            var sprite: Sprite2D = data.get("sprite") as Sprite2D
            if is_instance_valid(sprite):
                sprite.visible = false
            var collision: CollisionShape2D = data.get("collision") as CollisionShape2D
            if is_instance_valid(collision):
                collision.queue_free()
            blocked.erase(target)
            item_collected.emit("POTION")
            world_message.emit("You found a POTION!")
        return

    # Built-object destruction follows PokeWilds field-move rules while normal
    # interaction continues to open stations/furniture.
    if built_structures.has(target):
        var built_data: Dictionary = built_structures[target]
        var built_name := String(built_data.get("name", ""))
        if active_field_move == "RIDE" and built_name == "FENCE":
            _ride_jump_over(target)
            return
        if active_field_move == "CUT" and built_name not in ["GRAVE", "STATUE"]:
            structure_removal_requested.emit(target, "CUT")
            return
        if active_field_move == "SMASH" and built_name in ["GRAVE", "STATUE"]:
            structure_removal_requested.emit(target, "SMASH")
            return
        _interact_built_structure(target)
        return

    if active_field_move.is_empty() and is_empty_planting_hole(target):
        structure_action.emit("PLANT_HOLE:%d:%d" % [target.x, target.y])
        return

    if active_field_move.is_empty() and _can_prompt_shore_surf(target):
        structure_action.emit("SHORE_SURF")
        return

    if active_field_move.is_empty():
        var berry_anchor := _exact_resource_anchor(target)
        if berry_anchor.x > -2147483648 and not _exact_berry_name(berry_anchor).is_empty():
            _pick_exact_berry_tree(berry_anchor)
            return

    # Active field moves get first claim on environmental actions.
    match active_field_move:
        "CUT":
            var helper_cut_target := _cut_helper_target_cell()
            if helper_cut_target.x > -2147483648:
                _try_cut_target(helper_cut_target)
            return
        "SMASH":
            target = _field_move_action_cell(target, "SMASH")
            if exact_world_mode and not _exact_resource_kind(target).is_empty():
                _harvest_exact_resource(target, "SMASH")
                return
            if resource_objects.has(target):
                _harvest_resource_with_move(target, "SMASH")
                return
        "DIG":
            _use_dig(_field_move_action_cell(target, "DIG"))
            return
        "BUILD":
            var build_name := _current_build_name()
            if not build_name.is_empty():
                build_requested.emit(build_name, get_build_execution_cell())
            return
        "HEADBUTT":
            _use_headbutt(_field_move_action_cell(target, "HEADBUTT"))
            return
        "TELEPORT":
            teleport_map_requested.emit(_travel_destinations(false))
            return
        "FLY":
            world_message.emit("Fly to safe ground, then press B to land.")
            return
        "PAINT":
            paint_requested.emit(paint_selection_index + 1, _field_move_action_cell(target, "PAINT"))
            return
        "POWER":
            world_message.emit("There is no machine here that can receive POWER.")
            return
        "FLASH":
            world_message.emit("FLASH lights the surrounding area.")
            return
        "CHARM":
            world_message.emit("CHARM suppresses hostile Pokemon below %s's level while active." % PokemonData.battle_display_name(active_field_species))
            return
        "ATTACK":
            world_message.emit("Face a wild Pokemon to command ATTACK.")
            return
        "REPEL":
            world_message.emit("Wild Pokemon below level %d are being repelled." % maxi(1, int(active_field_pokemon.get("level", 1))))
            return
        "SURF":
            world_message.emit("SURF lets you cross water. Press B to stop.")
            return
        "RIDE":
            if exact_world_mode and exact_world != null:
                var ride_tile := exact_world.tile_at(target)
                if ride_tile != null and ride_tile.is_ledge:
                    _ride_jump_over(target)
                    return
            world_message.emit("RIDE increases speed and can jump low ledges or fences.")
            return

    if _is_cuttable_grass_cell(target) or \
            _resource_object_anchor(target).x > -2147483648 or \
            _exact_resource_anchor(target).x > -2147483648:
        var cut_resource := _resource_object_anchor(target)
        var cut_exact := _exact_resource_anchor(target)
        var cuttable := _is_cuttable_grass_cell(target) or _exact_resource_kind(cut_exact) in ["tree", "bush"]
        cuttable = cuttable or String((resource_objects.get(cut_resource, {}) as Dictionary).get("type", "")) in ["tree", "bush"]
        if not cuttable:
            return

func _try_cut_target(cell: Vector2i) -> bool:
    if built_structures.has(cell):
        var build_name := String((built_structures[cell] as Dictionary).get(
            "name", ""
        ))
        if build_name not in ["GRAVE", "STATUE"]:
            structure_removal_requested.emit(cell, "CUT")
            return true
    if _is_cuttable_grass_cell(cell):
        _cut_tall_grass(cell)
        return true
    var exact_anchor := _exact_resource_anchor(cell)
    if exact_anchor.x > -2147483648:
        _harvest_exact_resource(exact_anchor, "CUT")
        return true
    var resource_anchor := _resource_object_anchor(cell)
    if resource_anchor.x > -2147483648:
        _harvest_resource_with_move(resource_anchor, "CUT")
        return true
    return false

func _interact_wild_pokemon(wild_id: int) -> void:
    if not wild_pokemon.has(wild_id):
        return
    var data: Dictionary = wild_pokemon[wild_id]
    var species := PokemonData.battle_display_name(String(data.get("species", "POKEMON")))
    if bool(data.get("burrowed", false)):
        world_message.emit("The sand shifts slightly, then goes still.")
        return
    if active_field_move == "ATTACK":
        _begin_wild_encounter(wild_id, true)
        return
    var behavior: Dictionary = data.get("behavior", {})
    if active_field_move == "CHARM":
        if _charm_suppresses(data):
            data["charmed"] = true
            wild_pokemon[wild_id] = data
            _show_ecology_emote(data.get("sprite") as Sprite2D, "heart")
            world_message.emit("Wild %s is soothed while CHARM is active." % species)
            return
        elif int(behavior.get("aggression", 1)) >= 2:
            world_message.emit("Wild %s is too aggressive for CHARM." % species)

    if int(behavior.get("aggression", 1)) <= 0:
        _show_ecology_emote(data.get("sprite") as Sprite2D, "happy")
        wild_pokemon_prompt_requested.emit(wild_id, species, "FRIENDLY")
        return

    # Source wild behavior is a two-interaction state: the first A only warns.
    # It must close completely before a second A on that same live Pokemon can
    # provoke it. `warned` persists on the wild record but does not imply chase.
    if not bool(data.get("warned", false)):
        _show_ecology_emote(data.get("sprite") as Sprite2D, "alert")
        wild_pokemon_prompt_requested.emit(wild_id, species, "PROVOKE_WARNING")
        return
    _show_ecology_emote(data.get("sprite") as Sprite2D, "angry")
    wild_pokemon_prompt_requested.emit(wild_id, species, "PROVOKED")

func mark_wild_provocation_warning(wild_id: int) -> void:
    if not wild_pokemon.has(wild_id):
        return
    var data: Dictionary = wild_pokemon[wild_id]
    if PokemonEcology.wild_interaction_kind(String(data.get("species", ""))) != "AGGRESSIVE":
        return
    data["warned"] = true
    wild_pokemon[wild_id] = data

func _wild_chases_when_provoked(data: Dictionary) -> bool:
    var behavior: Dictionary = data.get("behavior", {})
    if bool(behavior.get("lunge", false)) or int(behavior.get("aggression", 1)) >= 2:
        return true
    # GenIsland1 also marks specific authored overworld spawns as aggressive
    # (for example Drapion/Froslass/Primeape/Sharpedo and Lower-Ruins Dusclops).
    # Preserve that source record instead of reducing pursuit to the database's
    # generic species behavior table.
    var source_record: Dictionary = data.get("source_record", {})
    return bool(source_record.get("aggressive", false))

func confirm_wild_provocation(wild_id: int) -> void:
    if not wild_pokemon.has(wild_id):
        return
    var data: Dictionary = wild_pokemon[wild_id]
    if PokemonEcology.wild_interaction_kind(String(data.get("species", ""))) != "AGGRESSIVE":
        return
    data["warned"] = true
    data["aggro_player"] = true
    data["source_aggro_emote_seconds"] = 32.0 / 60.0
    data["move_timer"] = 32.0 / 60.0
    data["provocation_count"] = int(data.get("provocation_count", 0)) + 1
    wild_pokemon[wild_id] = data
    # The provocation interaction has finished. Start the battle immediately,
    # independent of idle clocks, grace, SURF or Repel.
    _begin_wild_encounter(wild_id)


func take_friendly_wild(wild_id: int) -> Dictionary:
    if not wild_pokemon.has(wild_id):
        return {}
    var data: Dictionary = wild_pokemon[wild_id]
    var behavior: Dictionary = data.get("behavior", {})
    if PokemonEcology.wild_interaction_kind(String(data.get("species", ""))) != "FRIENDLY" or bool(data.get("burrowed", false)):
        return {}
    var result := _serializable_ecology_record(
        data, Vector2i(data.get("cell", Vector2i.ZERO))
    )
    var source_record := data.get("source_record", {}) as Dictionary
    for property in source_record.keys():
        if not result.has(property):
            result[property] = source_record[property]
    result["species"] = String(data.get("species", "pidgey")).to_lower()
    result["level"] = maxi(1, int(data.get("level", 2)))
    _show_ecology_emote(data.get("sprite") as Sprite2D, "happy")
    _remove_wild_pokemon(wild_id)
    return result

func _exact_resource_kind(cell: Vector2i) -> String:
    if not exact_world_mode or exact_world == null:
        return ""
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return ""
    var key := (tile.name + " " + tile.name_upper).to_lower()
    if "aloe_large1" in key:
        return "tree"
    if "cactus" in key:
        return "cactus"
    if "berrytree_" in key or "bush" in key:
        return "bush"
    if "tree" in key:
        return "tree"
    if "rock" in key or "stone" in key:
        return "rock"
    return ""

func _exact_savanna_tree_anchor(cell: Vector2i) -> Vector2i:
    if not exact_world_mode or exact_world == null:
        return Vector2i(-2147483648, -2147483648)
    # tree_savanna1 is a 48x48 upper-layer sprite anchored one tile to the
    # right of its visual left edge. Resolve every visible 3x3 footprint cell
    # back to that authored anchor so CUT works from any side like other big
    # trees.
    for y_offset in [0, -1, -2]:
        for x_offset in [-1, 0, 1]:
            var candidate: Vector2i = cell + Vector2i(int(x_offset), int(y_offset))
            var tile: SourceTile = exact_world.tile_at(candidate)
            if tile == null:
                continue
            if tile.name_upper.to_lower().trim_suffix(".png") != "tree_savanna1":
                continue
            var visual_left: int = candidate.x - 1
            var visual_top: int = candidate.y
            if cell.x >= visual_left and cell.x <= visual_left + 2 and \
                    cell.y >= visual_top and cell.y <= visual_top + 2:
                return candidate
    return Vector2i(-2147483648, -2147483648)

func _exact_resource_anchor(cell: Vector2i) -> Vector2i:
    if not exact_world_mode or exact_world == null:
        return Vector2i(-2147483648, -2147483648)
    var savanna_anchor: Vector2i = _exact_savanna_tree_anchor(cell)
    if savanna_anchor.x > -2147483648:
        return savanna_anchor
    if not _exact_resource_kind(cell).is_empty():
        return cell
    # Resolve either visible half of a tall exact-world resource back to the
    # actual authored tile. Source assets use more than one vertical anchor
    # convention, so checking both neighbors avoids tree4/palm dead zones.
    for candidate in [cell + Vector2i.UP, cell + Vector2i.DOWN]:
        if _exact_resource_kind(candidate).is_empty():
            continue
        var tile: SourceTile = exact_world.tile_at(candidate)
        if tile == null:
            continue
        var spec: Dictionary = SourceWorldData.render_spec(tile, true, 0, 0)
        var size: Vector2 = spec.get("size", Vector2.ZERO)
        var origin := Vector2(candidate * TILE) + Vector2(spec.get("offset", Vector2.ZERO))
        if size.y > float(TILE) and Rect2(origin, size).has_point(_cell_center(cell)):
            return candidate
    return Vector2i(-2147483648, -2147483648)

func _resource_object_anchor(cell: Vector2i) -> Vector2i:
    if resource_objects.has(cell):
        return cell
    # Tall compatibility/source-plan resources may expose either half as the
    # cell the player is facing. Resolve both vertical neighbors back to the
    # authored resource anchor. This is required for 16x32 tree4 tundra trees
    # and also makes palm/berry interaction independent of approach side.
    for candidate in [cell + Vector2i.DOWN, cell + Vector2i.UP]:
        if not resource_objects.has(candidate):
            continue
        var data: Dictionary = resource_objects[candidate]
        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        if is_instance_valid(sprite) and sprite.texture != null and \
                sprite.texture.get_height() > TILE:
            return candidate
    return Vector2i(-2147483648, -2147483648)

func _exact_berry_name(cell: Vector2i) -> String:
    if not exact_world_mode or exact_world == null:
        return ""
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return ""
    var upper := tile.name_upper.to_lower()
    if not upper.begins_with("berrytree_") or "full" not in upper:
        return ""
    var parts := upper.split("_")
    if parts.size() < 2:
        return ""
    return "%s BERRY" % String(parts[1]).to_upper()

func _pick_exact_berry_tree(cell: Vector2i) -> void:
    var berry_name := _exact_berry_name(cell)
    if berry_name.is_empty():
        world_message.emit("There are no ripe BERRIES here.")
        return
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return
    if tile.route_belongs_to != null and not tile.route_belongs_to.stored_pokemon.is_empty():
        var record: Dictionary = tile.route_belongs_to.stored_pokemon.pop_front().duplicate(true)
        pending_encounter_record = record
        play_source_sound("ledge2")
        world_message.emit("The tree became agitated and attacked!")
        encounter_requested.emit(String(record.get("name",record.get("species","sudowoodo"))).to_lower(),int(record.get("level",1)))
        _clear_agitated_berry_tree(cell,tile)
        return
    item_collected.emit(berry_name)
    play_source_sound("Berry_Get")
    tile.set_names(tile.name, tile.name_upper.replace("_full", "_empty"))
    plants().store(cell,tile)
    source_interior_mutations[_cell_key(cell)] = {
        "kind":"BERRY_EMPTY", "upper":tile.name_upper
    }
    _refresh_exact_pickup_cell(cell)
    world_message.emit("You picked a %s." % berry_name)

func _clear_agitated_berry_tree(cell: Vector2i, tile: SourceTile) -> void:
    await get_tree().create_timer(400.0/60.0).timeout
    if exact_world == null or exact_world.tile_at(cell) != tile: return
    tile.set_names(tile.name, "")
    source_plant_farms.erase(_cell_key(cell))
    source_interior_mutations[_cell_key(cell)]={"kind":"TILE_NAMES","base":tile.name,"upper":""}
    _refresh_exact_streams()


func _exact_tile_is_large_tree(cell: Vector2i) -> bool:
    if not exact_world_mode or exact_world == null:
        return false
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return false
    var key := (tile.name + " " + tile.name_upper).to_lower()
    # Part 5 parity: the authored giant forest tree, the 16x32 tundra tree4,
    # and the full savanna tree all use the evolved-CUT / large-tree yield.
    # Ordinary tree5/tree6 and aloe tiles remain small-resource vegetation.
    return (
        "tree_large1" in key or "tree_large2" in key
        or "tree_large3" in key or "tree_large4" in key
        or "tree_savanna1" in key or "tree4" in key
    )

## A giant tree is one visible tile and three invisible ones that only block.
## The original generator turns any incomplete giant tree into a bush, and
## runs that check again after placing the Regi cave. Here the cave (and the
## mansion) can also be placed by a later fallback with no check after it,
## which left invisible blocking tiles round the cave showing the sky. This
## gives those the original's result, a bush, in worlds old and new.
func _repair_orphaned_large_trees() -> void:
    if exact_world == null:
        return
    for raw_tile in exact_world.tile_list():
        var tile := raw_tile as SourceTile
        if tile == null or tile.name != "tree_large1_noSprite":
            continue
        var rooted := false
        for offset in [Vector2i(-16, 0), Vector2i(0, -16), Vector2i(-16, -16)]:
            var anchor := exact_world.tiles.get(tile.position + offset) as SourceTile
            if anchor != null and anchor.name == "tree_large1":
                rooted = true
                break
        if not rooted:
            tile.color = true
            tile.set_names("bush1", "")

func _exact_large_tree1_anchor(cell: Vector2i) -> Vector2i:
    if not exact_world_mode or exact_world == null:
        return Vector2i(-2147483648, -2147483648)
    # GenForest2 stores the visible giant-tree anchor plus three noSprite
    # collision cells at +X, +Y and +X+Y. Resolve any quadrant back to the
    # visible anchor so one CUT removes the complete 2x2 object.
    var anchor_offsets: Array[Vector2i] = [
        Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)
    ]
    var part_offsets: Array[Vector2i] = [
        Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1)
    ]
    for offset in anchor_offsets:
        var candidate: Vector2i = cell + offset
        var tile: SourceTile = exact_world.tile_at(candidate)
        if tile == null:
            continue
        if tile.name.to_lower().trim_suffix(".png") != "tree_large1":
            continue
        var complete := true
        for part_offset in part_offsets:
            var part: SourceTile = exact_world.tile_at(candidate + part_offset)
            if part == null:
                complete = false
                break
            var part_name := part.name.to_lower().trim_suffix(".png")
            if part_offset == Vector2i.ZERO:
                complete = complete and part_name == "tree_large1"
            else:
                complete = complete and part_name == "tree_large1_nosprite"
        if complete:
            return candidate
    return Vector2i(-2147483648, -2147483648)

## The Game Boy CUT effect, as CutTreeAnim.java draws it: the tree is sliced
## down the middle, the halves sit two pixels apart, then step outward three
## times with a blink before each step. It is only a picture laid over the
## cell. The tile itself is cut at once, so nothing waits for it.
func _show_cut_halves(cell: Vector2i) -> void:
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return
    var spec: Dictionary = SourceWorldData.render_spec(tile, true)
    if spec.is_empty() or spec.get("texture") == null:
        # The giant tree keeps its whole picture on the base of its first part.
        if "tree_large1" not in tile.name.to_lower():
            return
        spec = SourceWorldData.render_spec(tile, false)
        if spec.is_empty() or spec.get("texture") == null:
            return
    var region: Rect2 = spec["region"]
    var half := floorf(region.size.x / 2.0)
    var corner: Vector2 = _cell_center(cell) - Vector2(TILE, TILE) / 2.0 + (spec.get("offset", Vector2.ZERO) as Vector2)
    var holder := Node2D.new()
    holder.z_index = 2
    var over := get_node_or_null("DecorLayer")
    (over if over != null else self).add_child(holder)
    var halves: Array[Sprite2D] = []
    for side in range(2):
        var piece := Sprite2D.new()
        piece.texture = spec["texture"]
        piece.centered = false
        piece.region_enabled = true
        piece.region_rect = Rect2(region.position.x + half * side, region.position.y,
            half if side == 0 else region.size.x - half, region.size.y)
        piece.position = corner + Vector2(half * side + (-2.0 if side == 0 else 2.0), 0)
        holder.add_child(piece)
        halves.append(piece)
    var steps := holder.create_tween()
    steps.tween_interval(17.0 / 60.0)
    for step in range(3):
        steps.tween_callback(func(): holder.visible = false)
        steps.tween_interval(2.0 / 60.0)
        steps.tween_callback(func():
            halves[0].position.x -= 2.0
            halves[1].position.x += 2.0
            holder.visible = true)
        steps.tween_interval(2.0 / 60.0)
    steps.tween_callback(holder.queue_free)
    # Online, the other players see the same split. `collecting` is set only
    # while this player's own cut is being carried out.
    var coop = get_parent().get("coop_game") if get_parent() != null else null
    if is_instance_valid(coop) and coop.active and coop.building.collecting:
        coop.visuals.effect({"fx":"cut", "x":cell.x, "y":cell.y})

func _cut_exact_large_tree1_component(anchor: Vector2i) -> void:
    var part_offsets: Array[Vector2i] = [
        Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1)
    ]
    for offset in part_offsets:
        var part_cell: Vector2i = anchor + offset
        var part: SourceTile = exact_world.tile_at(part_cell)
        if part == null:
            continue
        var replacement := _contextual_ground_name(part_cell, part.biome)
        if replacement.is_empty() or replacement.begins_with("grass"):
            replacement = "green1"
        part.set_names(replacement, "")
        source_interior_mutations[_cell_key(part_cell)] = {
            "kind":"TILE_NAMES", "base":replacement, "upper":""
        }
        blocked.erase(part_cell)

func _harvest_exact_resource(cell: Vector2i, move: String) -> void:
    if move == "CUT" and plants().harvest(cell):
        return
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return
    var kind := _exact_resource_kind(cell)
    if move == "CUT" and kind not in ["tree", "bush"]:
        world_message.emit("CUT can't be used on that.")
        return
    var exact_resource_key := (tile.name + " " + tile.name_upper).to_lower()
    if move == "CUT" and kind == "tree" and _exact_tile_is_large_tree(cell) and \
            "tree4" not in exact_resource_key and \
            not FieldMoveData.is_fully_evolved(active_field_species):
        world_message.emit("This tree needs a fully evolved Pokemon to CUT it.")
        return
    if move in ["SMASH", "HEADBUTT"] and kind != "rock":
        world_message.emit("%s can't be used on that." % move)
        return

    var key := exact_resource_key
    var smash_encounter: Dictionary = {}
    var smash_bonus_item := ""
    if move in ["SMASH", "HEADBUTT"] and tile.route_belongs_to != null and \
            not tile.route_belongs_to.stored_pokemon.is_empty():
        var raw_smash = tile.route_belongs_to.stored_pokemon[0]
        if typeof(raw_smash) == TYPE_DICTIONARY:
            smash_encounter = (raw_smash as Dictionary).duplicate(true)
    play_source_sound("cut1" if move == "CUT" else ("headbutt1" if move == "HEADBUTT" else "strength1"))

    # Source-parity CUT rewards. Logical palm tree5 renders with tree6 art;
    # both identities are seed-only and must never leak into the LOG path.
    if move == "CUT" and "berrytree_" in key:
        material_collected.emit("BERRY SEED", 2)
    elif move == "CUT" and ("tree5" in key or "tree6" in key):
        material_collected.emit("MIRACLE SEED", 1)
    elif move == "CUT" and kind == "bush" and (
            String(tile.biome).to_upper() in ["SNOW", "TUNDRA", "SAVANNA"]
            or "bush_savanna1" in key
        ):
        # Savannah bushes are the source's simple LOG + GRASS resource, with
        # no Apricorn roll. Tundra keeps its existing identical bundle.
        material_bundle_collected.emit({"GRASS":1, "LOG":1})
    elif move == "CUT" and "bush2_color" in key:
        var apricorn := String(CraftingData.APRICORNS[
            rng.randi_range(0, CraftingData.APRICORNS.size() - 1)])
        material_bundle_collected.emit({"LOG":1, apricorn:1})
    else:
        var material := "HARD STONE" if kind == "rock" else "LOG"
        var amount := 1
        if kind == "tree" and _exact_tile_is_large_tree(cell):
            amount = rng.randi_range(2, 7)
        material_collected.emit(material, amount)
        if move == "SMASH" and kind == "rock" and \
                _source_biome_for_tile(tile) == "MOUNTAIN" and \
                rng.randi_range(0, 15) == 0:
            smash_bonus_item = "MOON STONE"
            material_collected.emit(smash_bonus_item, 1)
        if move == "CUT" and "aloe_large1" in key:
            material_collected.emit("MIRACLE SEED", 1)

    var giant_anchor := _exact_large_tree1_anchor(cell) if move == "CUT" else Vector2i(-2147483648, -2147483648)
    if move == "CUT":
        _show_cut_halves(giant_anchor if giant_anchor.x > -2147483648 else cell)
    if giant_anchor.x > -2147483648:
        _cut_exact_large_tree1_component(giant_anchor)
    else:
        var replacement: Dictionary = _exact_cut_resource_replacement(tile, cell)
        tile.set_names(String(replacement.get("base", tile.name)),
            String(replacement.get("upper", "")))
        source_interior_mutations[_cell_key(cell)] = {
            "kind":"TILE_NAMES", "base":tile.name, "upper":tile.name_upper
        }
        _unblock_ground(cell)
    _refresh_exact_tile_streams()
    # The source acquisition popup is the receipt for berry/Apricorn CUT loot.
    # Do not add a second bottom dialogue box for those two cases.
    if move in ["SMASH", "HEADBUTT"]:
        if smash_encounter.is_empty():
            if move == "SMASH" and not smash_bonus_item.is_empty():
                world_message.emit(
                    "SMASH! You gathered HARD STONE and found a %s." % smash_bonus_item
                )
            else:
                world_message.emit("%s! You gathered HARD STONE." % move)
        else:
            pending_encounter_record = smash_encounter.duplicate(true)
            world_message.emit("%s! A Pokemon jumped out of the rock!" % move)
            encounter_requested.emit(
                String(smash_encounter.get("name", "geodude")).to_lower(),
                int(smash_encounter.get("level", _level_for_cell(cell)))
            )

func _exact_cut_resource_replacement(tile: SourceTile, cell: Vector2i) -> Dictionary:
    var base := tile.name
    var upper := tile.name_upper
    var key := (base + " " + upper).to_lower()
    # Palm grows on sand and must expose sand when removed.
    if "tree5" in key or "tree6" in key:
        return {"base":"sand1", "upper":""}
    # Objects authored as an upper layer already have the correct biome floor.
    if not upper.is_empty():
        return {"base":base, "upper":""}
    var contextual := _contextual_ground_name(cell, tile.biome)
    if not contextual.is_empty():
        return {"base":contextual, "upper":""}
    if "tree_large" in key or "tree5" in key:
        return {"base":"green1", "upper":""}
    if "aloe" in key or "cactus" in key:
        return {"base":"desert4", "upper":""}
    return {"base":base, "upper":""}

func _contextual_ground_name(cell: Vector2i, biome_hint: String = "") -> String:
    if not exact_world_mode or exact_world == null:
        return ""
    var counts: Dictionary = {}
    for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
            Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
        var nearby := exact_world.tile_at(cell + offset)
        if nearby == null or nearby.is_water or nearby.is_solid or nearby.is_ledge:
            continue
        if not biome_hint.is_empty() and not String(nearby.biome).is_empty() and \
                String(nearby.biome) != biome_hint:
            continue
        var name := nearby.name
        var clean := name.to_lower().trim_suffix(".png")
        if clean.begins_with("grass") or clean.begins_with("green") or \
                clean.begins_with("sand") or clean.begins_with("desert") or \
                clean.begins_with("snow") or clean.begins_with("soot"):
            counts[name] = int(counts.get(name, 0)) + 1
    var best := ""
    var best_count := 0
    for raw_name in counts.keys():
        if int(counts[raw_name]) > best_count:
            best = String(raw_name)
            best_count = int(counts[raw_name])
    return best

func _harvest_resource_with_move(cell: Vector2i, move: String) -> void:
    if not resource_objects.has(cell):
        return
    var data: Dictionary = resource_objects[cell]
    var kind := String(data.get("type", ""))
    if move == "CUT":
        if kind not in ["tree", "bush"]:
            world_message.emit("CUT can't be used on that.")
            return
        var source_name := _resource_source_name(data)
        if kind == "tree" and bool(data.get("large", false)) and \
                source_name != "tree4" and \
                not FieldMoveData.is_fully_evolved(active_field_species):
            world_message.emit("This tree needs a fully evolved Pokemon to CUT it.")
            return
        _harvest_resource(cell, move)
        return
    if move in ["SMASH", "HEADBUTT"]:
        if kind != "rock":
            world_message.emit("%s can't be used on that." % move)
            return
        _harvest_resource(cell, move)

func _cycle_dig_selection(direction: int) -> void:
    dig_selection_index = wrapi(dig_selection_index + direction, 0, DIG_CHOICES.size())
    _show_current_dig_selection()

func _show_current_dig_selection() -> void:
    world_message.emit("DIG: %s" % DIG_CHOICES[dig_selection_index])

func _show_current_build_selection() -> void:
    if CraftingData.build_recipes().is_empty():
        return
    var build_name := _current_build_name()
    var recipe := CraftingData.build_recipe(build_name)
    world_message.emit("BUILD: %s\n%s" % [CraftingData.build_display_name(build_name), CraftingData.format_cost(recipe.get("cost", {}))])

func _use_dig(cell: Vector2i) -> void:
    if not _in_bounds(cell):
        return
    # PlayerStanding gives an item tile priority while DIG is selected.  The
    # ball is collected in-place instead of being left above the new ground.
    if exact_world_mode and exact_world != null:
        var item_tile := exact_world.tile_at(cell)
        if item_tile != null and not item_tile.has_item.is_empty():
            var action := String(interior_interactables.get(cell, ""))
            if not action.begins_with("ITEM:"):
                action = "ITEM:%s:%d" % [
                    item_tile.has_item, maxi(1, item_tile.has_item_amount)
                ]
            _use_interior_interactable(action, cell)
            return
    if DIG_CHOICES[dig_selection_index] == "HOLE":
        _dig_surface(cell)
        return
    var choice := String(DIG_CHOICES[dig_selection_index])
    var info: Dictionary = FieldMoveData.dig_choice_info(choice)
    var material := String(info.get("material", "GRASS"))
    dig_requested.emit(choice, cell, material)

func apply_dig_choice(cell: Vector2i, choice: String) -> bool:
    return _apply_dig_choice(cell, choice)

func _dig_surface(cell: Vector2i) -> void:
    var exact_tile: SourceTile = null
    var diggable_mountain := false
    if exact_world_mode and exact_world != null:
        exact_tile = exact_world.tile_at(cell)
        if exact_tile != null:
            var mountain_names := (exact_tile.name + " " +
                exact_tile.name_upper).to_lower()
            diggable_mountain = "mountain" in mountain_names or \
                "ledges3" in mountain_names
    if (blocked.has(cell) and not diggable_mountain) or \
            built_structures.has(cell) or landmarks.has(cell) or \
            resource_objects.has(cell):
        world_message.emit("DIG can't break that tile.")
        return
    var material := "GRASS"
    var loot: Array = []
    if exact_world_mode and exact_world != null:
        var tile := exact_tile
        if tile == null or tile.is_water or \
                ((tile.is_solid or tile.is_ledge) and not diggable_mountain):
            world_message.emit("DIG can't break that tile.")
            return
        var route_name := "" if tile.route_belongs_to == null else tile.route_belongs_to.name
        material = FieldMoveData.dig_material(tile.name, tile.name_upper, tile.biome, route_name)
        var is_dig_site := "_cracked" in tile.name.to_lower() or \
            "_cracked" in tile.name_upper.to_lower()
        var low_tide_wash := (
            low_tide_active
            and _is_beach_tidal_tile(tile)
            and "_tidaloff" in tile.name.to_lower()
        )
        if is_dig_site or low_tide_wash:
            loot = FieldMoveData.biome_dig_loot(
                _source_biome_for_tile(tile), route_name
            )
            if loot.is_empty():
                loot = FieldMoveData.cracked_loot(tile.name)
            if loot.is_empty():
                loot = FieldMoveData.cracked_loot(tile.name_upper)
        if diggable_mountain:
            material = "HARD STONE"
        # A volcano floor held between lava and water is PokeWilds' renewable
        # Ashen Soil generator. DIG harvests it without consuming the contact
        # tile, so the same source boundary can be harvested again.
        if _is_renewable_ashen_contact(cell):
            material_collected.emit("ASHEN SOIL", 1)
            play_source_sound("dig1")
            world_message.emit("DIG! You gathered ASHEN SOIL.")
            return
        # Low-tide beach digging searches the exposed wash without destroying
        # its tidal identity; otherwise the next high tide could never cover
        # that cell again. The authored beach2 route supplies the washed-up
        # item pool while the exposed sand supplies SOFT SAND.
        if low_tide_wash:
            material_collected.emit(material, 1)
            play_source_sound("dig1")
            var washed_up := ""
            if not loot.is_empty():
                washed_up = String(loot[rng.randi_range(0, loot.size() - 1)])
                material_collected.emit(washed_up, 1)
            world_message.emit("DIG! You gathered %s%s." % [
                material,
                " and found %s" % washed_up if not washed_up.is_empty() else ""
            ])
            return
        var replacement_ground := tile.name if is_dig_site else \
            _contextual_ground_name(cell, tile.biome)
        if replacement_ground.is_empty():
            var dig_biome := _source_biome_for_tile(tile)
            match dig_biome:
                "SNOW":
                    replacement_ground = "snow1"
                "BEACH":
                    replacement_ground = "sand1"
                "DESERT":
                    replacement_ground = "desert4"
                "MOUNTAIN":
                    replacement_ground = "mountain1"
                "VOLCANO":
                    replacement_ground = "volcano1"
                "GRAVEYARD":
                    replacement_ground = "green12"
                "DEEP_FOREST":
                    replacement_ground = "green_deepforest"
                "WOODED_LAKE":
                    replacement_ground = "green_woodedlake"
                "SAVANNA":
                    replacement_ground = "green_savanna1"
                _:
                    replacement_ground = "green1"
        _set_exact_tile_names(cell, replacement_ground, "")
        # Exact-world DIG persists the authored replacement tile itself. Using
        # the compatibility terrain integer here used to reload every dug cell
        # as generic green ground and destroyed biome-specific soil.
        source_interior_mutations[_cell_key(cell)] = {
            "kind":"TILE_NAMES", "base":replacement_ground, "upper":""
        }
        terrain_changes.erase(_cell_key(cell))
    else:
        if terrain_kind_at(cell) == 0:
            world_message.emit("DIG can't break water.")
            return
        material = "SOFT SAND" if terrain_kind_at(cell) == 1 else "GRASS"
        terrain[cell.y][cell.x] = 2
        terrain_changes[_cell_key(cell)] = 2
        var sprite := ground_sprites.get(cell) as Sprite2D
        if is_instance_valid(sprite):
            sprite.texture = GRASS
    material_collected.emit(material, 1)
    play_source_sound("dig1")
    var found := ""
    if not loot.is_empty():
        found = String(loot[rng.randi_range(0, loot.size() - 1)])
        material_collected.emit(found, 1)
    world_message.emit("DIG! You gathered %s%s." % [material, " and found %s" % found if not found.is_empty() else ""])

func _apply_dig_choice(cell: Vector2i, choice: String) -> bool:
    if blocked.has(cell) or built_structures.has(cell) or resource_objects.has(cell) or landmarks.has(cell):
        world_message.emit("DIG can't change that tile.")
        return false
    if choice == "HOLE":
        _dig_surface(cell)
        return true
    var info: Dictionary = FieldMoveData.dig_choice_info(choice)
    if info.is_empty():
        return false
    if tall_grass.has(cell):
        _remove_resource(cell, false)
    var base_name := String(info.get("base", "green1"))
    var upper_name := String(info.get("upper", ""))
    if exact_world_mode:
        _set_exact_tile_names(cell, base_name, upper_name)
        source_interior_mutations[_cell_key(cell)] = {
            "kind":"TILE_NAMES", "base":base_name, "upper":upper_name
        }
        terrain_changes.erase(_cell_key(cell))
        _refresh_exact_streams()
    else:
        # Compatibility worlds approximate source surfaces with the closest
        # existing ground type; the exact world remains authoritative.
        terrain[cell.y][cell.x] = 1 if "sand" in base_name else 2
        terrain_changes[_cell_key(cell)] = terrain[cell.y][cell.x]
        var sprite := ground_sprites.get(cell) as Sprite2D
        if is_instance_valid(sprite):
            sprite.texture = SAND if terrain[cell.y][cell.x] == 1 else GRASS
    play_source_sound("dig1")
    world_message.emit("DIG changed the ground to %s." % choice)
    return true

func _teleport_to_any_beacon() -> void:
    for key in built_structures.keys():
        var cell: Vector2i = key
        var data: Dictionary = built_structures[cell]
        if String(data.get("name", "")) == "BEACON":
            player.position = _cell_center(cell + Vector2i(0, 1))
            _sync_follower_to_player()
            world_message.emit("TELEPORT brought you to a WARP TILE.")
            return
    world_message.emit("There are no WARP TILES to TELEPORT to.")

func teleport_destinations() -> Array[Dictionary]:
    return _travel_destinations(false)

func teleport_to_destination(index: int) -> bool:
    var destinations := _travel_destinations(false)
    if destinations.is_empty():
        return false
    travel_selection_index = clampi(index, 0, destinations.size() - 1)
    _travel_to_selected_destination(false)
    return true

func set_structure_beacon_label(cell: Vector2i, value: String) -> void:
    if not built_structures.has(cell):
        return
    var data: Dictionary = built_structures[cell]
    if String(data.get("name", "")) != "BEACON":
        return
    data["label"] = value.strip_edges().left(32)
    built_structures[cell] = data
    if String(data["label"]).is_empty():
        world_message.emit("The BEACON name was cleared.")
    else:
        world_message.emit("BEACON named %s." % String(data["label"]))

func _travel_destinations(include_spawn: bool) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    # The Java source exposes warp_tile1 as the outdoor teleport build tile.
    # BEACON remains only as the internal save-compatible key for older saves.
    for key in built_structures.keys():
        var cell: Vector2i = key
        var data: Dictionary = built_structures[cell]
        if String(data.get("name", "")) == "BEACON":
            result.append({
                "name":String(data.get("label", "BEACON")),
                "cell":cell + Vector2i.DOWN
            })
    if not include_spawn:
        return result

    result.push_front({"name":"STARTING AREA", "cell":spawn_cell})
    for raw_name in source_landmarks.keys():
        var raw_value = source_landmarks[raw_name]
        var landmark_cell := Vector2i(-2147483648, -2147483648)
        if typeof(raw_value) == TYPE_VECTOR2I:
            landmark_cell = raw_value
        elif typeof(raw_value) == TYPE_DICTIONARY and (raw_value as Dictionary).has("cell"):
            landmark_cell = Vector2i((raw_value as Dictionary).get("cell", landmark_cell))
        if landmark_cell.x <= -2147483648 or not discovered_cells.has(_cell_key(landmark_cell)):
            continue
        var landing := _nearest_walkable_cell(landmark_cell, 4)
        if landing.x <= -2147483648:
            continue
        result.append({"name":String(raw_name).replace("_", " ").to_upper(), "cell":landing})
    return result

func _clamp_flying_player_to_world() -> void:
    var bounds := get_map_bounds()
    if bounds.size.x <= 0 or bounds.size.y <= 0:
        return
    var main := get_parent()
    if main != null and main.has_method("check_flying_map_edge"):
        main.check_flying_map_edge()


func _valid_fly_landing(cell: Vector2i) -> bool:
    if not _in_bounds(cell) or terrain_kind_at(cell) == 0 or blocked.has(cell):
        return false
    if built_structures.has(cell) or landmarks.has(cell) or resource_objects.has(cell) or deployed_pokemon.has(cell) or wild_eggs.has(cell) or _wild_id_at_cell(cell) >= 0:
        return false
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        return tile != null and not exact_world.is_solid(cell) and not tile.is_ledge and not tile.is_bottom_mtn_layer
    return true

func _nearest_walkable_cell(origin: Vector2i, radius: int) -> Vector2i:
    if _is_walkable(origin):
        return origin
    for distance in range(1, radius + 1):
        for y in range(origin.y - distance, origin.y + distance + 1):
            for x in range(origin.x - distance, origin.x + distance + 1):
                var cell := Vector2i(x, y)
                if maxi(absi(x - origin.x), absi(y - origin.y)) == distance and _is_walkable(cell):
                    return cell
    return Vector2i(-2147483648, -2147483648)

func _show_current_travel_selection() -> void:
    var destinations := _travel_destinations(active_field_move == "FLY")
    if destinations.is_empty():
        world_message.emit("No known destination can be reached.")
        return
    travel_selection_index = wrapi(travel_selection_index, 0, destinations.size())
    world_message.emit("%s: %s (L/R selects, A confirms)" % [active_field_move, String(destinations[travel_selection_index].get("name", "DESTINATION"))])

func _cycle_travel_selection(direction: int) -> void:
    var destinations := _travel_destinations(active_field_move == "FLY")
    if destinations.is_empty():
        return
    travel_selection_index = wrapi(travel_selection_index + direction, 0, destinations.size())
    _show_current_travel_selection()

func _travel_to_selected_destination(include_spawn: bool) -> void:
    var destinations := _travel_destinations(include_spawn)
    if destinations.is_empty():
        world_message.emit("No known destination can be reached.")
        return
    travel_selection_index = wrapi(travel_selection_index, 0, destinations.size())
    var destination := destinations[travel_selection_index]
    active_area_id = "OVERWORLD"
    player.position = _cell_center(Vector2i(destination.get("cell", spawn_cell)))
    _sync_follower_to_player()
    _configure_camera()
    play_source_sound("fly_takingoff1" if active_field_move == "FLY" else "teleport1")
    world_message.emit("%s brought you to %s." % [active_field_move, String(destination.get("name", "the destination"))])

func _cycle_paint_selection(direction: int) -> void:
    paint_selection_index = wrapi(paint_selection_index + direction, 0, PAINT_CHOICES.size())
    _show_current_paint_selection()

func _show_current_paint_selection() -> void:
    world_message.emit("PAINT: %s (L/R selects)" % PAINT_CHOICES[paint_selection_index])

func _use_headbutt(cell: Vector2i) -> void:
    var exact_anchor := _exact_resource_anchor(cell)
    if exact_anchor.x > -2147483648 and _exact_resource_kind(exact_anchor) == "rock":
        _harvest_exact_resource(exact_anchor, "HEADBUTT")
        return
    # Tall palms/cacti can be faced through either visible half. Resolve that
    # visual cell back to the authored SourceTile so its stored encounter route
    # (including occasional Exeggutor/Exeggcute/Maractus) is not skipped.
    var exact_headbutt_cell := cell
    if exact_anchor.x > -2147483648:
        exact_headbutt_cell = exact_anchor
    var resource_anchor := _resource_object_anchor(cell)
    if resource_anchor.x > -2147483648 and \
            String((resource_objects[resource_anchor] as Dictionary).get("type", "")) == "rock":
        _harvest_resource_with_move(resource_anchor, "HEADBUTT")
        return
    var headbuttable := false
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(exact_headbutt_cell)
        headbuttable = tile != null and tile.is_headbuttable
        if headbuttable and tile.route_belongs_to != null and not tile.route_belongs_to.stored_pokemon.is_empty():
            var record := (tile.route_belongs_to.stored_pokemon[0] as Dictionary).duplicate(true)
            pending_encounter_record = record.duplicate(true)
            play_source_sound("headbutt1")
            encounter_requested.emit(String(record.get("name", "pidgey")).to_lower(), int(record.get("level", _level_for_cell(exact_headbutt_cell))))
            world_message.emit("HEADBUTT! A Pokemon fell from the tree!")
            return
    elif resource_anchor.x > -2147483648:
        headbuttable = String((resource_objects[resource_anchor] as Dictionary).get(
            "type", "")) in ["tree", "bush", "cactus"]
    if not headbuttable:
        world_message.emit("There is nothing to HEADBUTT here.")
        return
    play_source_sound("headbutt1")
    world_message.emit("HEADBUTT! The tree shook, but nothing fell.")

func _ride_jump_over(obstacle: Vector2i) -> void:
    var jump_direction := _facing_cell()
    if exact_world_mode and exact_world != null:
        var obstacle_tile := exact_world.tile_at(obstacle)
        if obstacle_tile != null and obstacle_tile.is_ledge:
            var ledge_key: String = (obstacle_tile.name + " " + obstacle_tile.name_upper).to_lower()
            var strict_brown_drop: bool = "ledge_grass_down" in ledge_key
            if strict_brown_drop or active_field_move != "RIDE":
                var permitted := _permitted_ledge_direction(obstacle_tile)
                if permitted != jump_direction:
                    world_message.emit("That ledge can only be crossed downhill.")
                    return
    var landing := obstacle + jump_direction
    if not _in_bounds(landing) or not _is_walkable(landing) or built_structures.has(landing):
        world_message.emit("There is no room to land beyond it.")
        return
    player.position = _cell_center(landing)
    last_player_cell = landing
    _sync_follower_to_player()
    play_source_sound("ride1")
    world_message.emit("RIDE cleared the obstacle!")

func _cycle_build_selection(direction: int) -> void:
    if CraftingData.build_recipes().is_empty():
        return
    set_build_selection_index(build_selection_index + direction)
    var build_name := _current_build_name()
    var recipe := CraftingData.build_recipe(build_name)
    world_message.emit("BUILD: %s\n%s" % [CraftingData.build_display_name(build_name), CraftingData.format_cost(recipe.get("cost", {}))])

func _current_build_name() -> String:
    if CraftingData.build_recipes().is_empty():
        return ""
    var recipe: Dictionary = CraftingData.build_recipes()[build_selection_index]
    return String(recipe.get("name", ""))

func get_build_selection_index() -> int:
    return build_selection_index

func set_build_selection_index(index: int) -> void:
    if CraftingData.build_recipes().is_empty():
        build_selection_index = 0
        return
    var normalized := wrapi(index, 0, CraftingData.build_recipes().size())
    var changed := normalized != build_selection_index
    build_selection_index = normalized
    _update_build_preview()
    if changed:
        build_selection_changed.emit(build_selection_index)

func set_build_preview_active(active: bool) -> void:
    build_mode_active = active and active_field_move == "BUILD"
    if not build_mode_active:
        if build_preview_sprite != null and is_instance_valid(build_preview_sprite):
            build_preview_sprite.queue_free()
        build_preview_sprite = null
        return
    if build_preview_sprite == null or not is_instance_valid(build_preview_sprite):
        build_preview_sprite = Sprite2D.new()
        build_preview_sprite.name = "BuildPlacementPreview"
        build_preview_sprite.centered = true
        build_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        build_preview_sprite.z_as_relative = false
        var layer := get_node_or_null("LandmarkLayer") as Node2D
        if layer != null:
            layer.add_child(build_preview_sprite)
        else:
            add_child(build_preview_sprite)
    _update_build_preview()

func _is_built_house_floor_cell(cell: Vector2i) -> bool:
    return (
        active_area_id == "HOUSE"
        and built_house_interior_cells.has(cell)
        and not interior_interactables.has(cell)
    )

func _build_snap_piece_name(build_name: String) -> String:
    return _house_piece_name(build_name).to_upper()

func _build_piece_is_grid_snapped(build_name: String) -> bool:
    return _build_snap_piece_name(build_name) in [
        "WALL", "ROOF", "DOOR", "INTERIOR WALL"
    ]

func _build_snap_cell_available(cell: Vector2i) -> bool:
    var in_house: bool = _is_built_house_floor_cell(cell)
    if not _in_bounds(cell) and not in_house:
        return false
    if (
            built_structures.has(cell) or landmarks.has(cell)
            or resource_objects.has(cell) or deployed_pokemon.has(cell)
            or wild_eggs.has(cell) or interior_interactables.has(cell)
            or _wild_id_at_cell(cell) >= 0
        ):
        return false
    if _is_tall_grass_cell(cell):
        return false
    if in_house:
        return true
    return terrain_kind_at(cell) != 0 and not blocked.has(cell)

func _build_snap_connection_score(build_name: String, cell: Vector2i) -> int:
    var piece: String = _build_snap_piece_name(build_name)
    var desired_style: String = _house_style_for_recipe(build_name)
    var compatible: Array[String] = ["WALL", "ROOF", "DOOR", "WINDOW", "CHIMNEY", "INTERIOR WALL"]
    var score: int = 0
    for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
        var neighbor: Vector2i = cell + direction
        if not built_structures.has(neighbor):
            continue
        var data: Dictionary = built_structures[neighbor]
        var neighbor_name: String = String(data.get("name", "")).to_upper()
        if neighbor_name not in compatible:
            continue
        # Styled exterior shells stay with their selected family. Interior
        # walls can attach to the finished shell of any of the three styles.
        if piece != "INTERIOR WALL" and desired_style != "DEFAULT":
            var neighbor_style: String = String(data.get("house_style", "DEFAULT"))
            if neighbor_style not in [desired_style, "DEFAULT"]:
                continue
        score += 1
    return score

## An interior wall takes windows, clocks and paint wherever it stands in the
## room: on a floor tile, or on the old row just above the room.
## The window or clock hanging on this house wall, or "" when it is bare.
func house_wall_decoration_at(cell: Vector2i) -> String:
    if active_area_id != "HOUSE" or not built_house_paintable_walls.has(cell):
        return ""
    var hung := String(built_house_decorations.get(_built_house_paint_key(cell), {}).get("name", ""))
    return hung if hung == "CLOCK" or _is_window_recipe(hung) else ""

## CUT takes a window or clock off its wall and leaves the wall standing. The
## room's own rear wall is not a built piece and could never be cut, so
## without this nothing hung on it could ever be removed.
func remove_house_wall_decoration(cell: Vector2i, refund: bool) -> bool:
    var hung := house_wall_decoration_at(cell)
    if hung.is_empty():
        return false
    built_house_decorations.erase(_built_house_paint_key(cell))
    var decoration := built_house_decoration_sprites.get(cell) as Sprite2D
    if is_instance_valid(decoration):
        decoration.queue_free()
    built_house_decoration_sprites.erase(cell)
    play_source_sound("cut1")
    if refund:
        build_refund_requested.emit((CraftingData.build_recipe(hung).get("cost", {}) as Dictionary).duplicate(true))
    return true

func _is_house_wall_cell(cell: Vector2i) -> bool:
    return _built_house_rear_wall_floor(cell) >= 0 or _built_house_floor_index_for_cell(cell) >= 0

func _built_house_rear_wall_floor(cell: Vector2i) -> int:
    for raw_index in built_house_floor_origins:
        var floor_index := int(raw_index)
        var origin := _built_house_floor_origin(floor_index)
        if cell.y == origin.y - 1 and cell.x >= origin.x and cell.x < origin.x + built_house_room_size.x:
            return floor_index
    return -1

func _snap_build_cell(build_name: String, desired: Vector2i) -> Vector2i:
    if (build_name == "CLOCK" or _is_window_recipe(build_name)) and active_area_id == "HOUSE":
        # It goes on the wall piece being faced. Interior walls now stand on
        # the room's own floor tiles; the old row above the northernmost floor
        # tile is only used by rooms that still have their wall there. Facing
        # open floor, it goes on the first wall straight ahead to the north.
        if built_house_paintable_walls.has(desired):
            return desired
        var origin: Vector2i = source_area_origins.get("HOUSE", built_house_interior_origin)
        var floor_index := _built_house_floor_index_for_cell(_player_cell())
        if floor_index >= 0:
            origin = _built_house_floor_origin(floor_index)
        for y in range(desired.y - 1, origin.y - 2, -1):
            if built_house_paintable_walls.has(Vector2i(desired.x, y)):
                return Vector2i(desired.x, y)
        return desired
    # Other pieces retain their exact aimed grid cell.
    return desired

func _restore_house_rear_walls() -> void:
    # Keep saved partitions on their original floor and cell. Older rear-wall
    # pieces remain where they were saved; loading never relocates a wall.
    for cell in built_structures:
        if String(built_structures[cell].get("name", "")) != "INTERIOR WALL": continue
        if _is_house_wall_cell(cell):
            built_house_paintable_walls[cell] = true
        _refresh_connected_structures_around(cell)

func get_build_preview_cell() -> Vector2i:
    # The tile immediately ahead of the controlled work Pokemon.
    var desired: Vector2i = _player_cell() + _facing_cell()
    return _snap_build_cell(_current_build_name(), desired)

func get_build_execution_cell() -> Vector2i:
    # The controlled body is the leading Pokemon. Build at its preview target,
    # never underneath it; both input paths share this snapped destination.
    return get_build_preview_cell()

func _update_build_preview() -> void:
    if not build_mode_active or build_preview_sprite == null or not is_instance_valid(build_preview_sprite):
        return
    if is_instance_valid(field_helper_sprite) and active_field_move == "BUILD":
        _position_build_helper()
    var build_name := _current_build_name()
    var target := get_build_preview_cell()
    var texture := _structure_display_texture(build_name)
    build_preview_sprite.texture = texture
    if texture == null:
        build_preview_sprite.visible = false
        return
    build_preview_sprite.visible = true
    # Display the item on the actual placement tile.
    var display_cell := target
    # Use the identical bottom-anchored pixel origin as place_structure.
    build_preview_sprite.centered = false
    build_preview_sprite.position = Vector2(display_cell.x * TILE, display_cell.y * TILE - maxi(0, int(texture.get_height()) - TILE))
    build_preview_sprite.offset = Vector2.ZERO
    build_preview_sprite.z_index = _depth_z(display_cell)
    if build_name == "CHIMNEY":
        # Match the actual roof attachment position.
        build_preview_sprite.centered = false
        build_preview_sprite.offset = Vector2.ZERO
        var shell := (built_structures.get(target, {}) as Dictionary).get("sprite") as Sprite2D
        build_preview_sprite.position = (shell.position if is_instance_valid(shell) else Vector2(target) * float(TILE)) + Vector2(0, -16)
    if is_instance_valid(field_helper_sprite) and active_field_move == "BUILD":
        var helper_rect := field_helper_sprite.get_rect()
        helper_rect.position += field_helper_sprite.position
        var preview_rect := build_preview_sprite.get_rect()
        preview_rect.position += build_preview_sprite.position
        # Tall artwork may extend beyond its tile. Keep the Pokemon visible
        # without moving the preview away from the tile that will be built.
        if preview_rect.intersects(helper_rect):
            build_preview_sprite.z_index = mini(build_preview_sprite.z_index, field_helper_sprite.z_index - 1)
    # Source BUILD preview is an opaque sprite, not a translucent ghost.
    build_preview_sprite.modulate = Color.WHITE

func _resource_source_name(data: Dictionary) -> String:
    var source_name := String(data.get("source_name", "")).to_lower().trim_suffix(".png")
    if not source_name.is_empty():
        return source_name
    var sprite := data.get("sprite") as Sprite2D
    if is_instance_valid(sprite) and sprite.texture != null:
        var path := String(sprite.texture.resource_path).to_lower()
        if not path.is_empty():
            return path.get_file().trim_suffix(".png")
    return ""

func _harvest_resource(cell: Vector2i, source_move: String = "") -> void:
    if not resource_objects.has(cell):
        return
    var data: Dictionary = resource_objects[cell]
    var kind := String(data.get("type", ""))
    var move := source_move.to_upper()

    if kind == "tree":
        play_source_sound("cut1")
        var log_amount := rng.randi_range(2, 7) if bool(
            data.get("large", false)) else 1
        var source_name := _resource_source_name(data)
        if source_name in ["tree5", "tree6"] or "tree5" in source_name or "tree6" in source_name:
            # Palm CUT is seed-only and leaves source-style beach sand behind.
            # Do this in the compatibility path too so both renderers agree.
            material_collected.emit("MIRACLE SEED", 1)
            if _in_bounds(cell):
                terrain[cell.y][cell.x] = 1
                terrain_changes[_cell_key(cell)] = 1
                var ground_sprite := ground_sprites.get(cell) as Sprite2D
                if is_instance_valid(ground_sprite):
                    ground_sprite.texture = SAND
        else:
            material_collected.emit("LOG", log_amount)
            if rng.randf() < 0.35:
                var apricorn := String(CraftingData.APRICORNS[
                    rng.randi_range(0, CraftingData.APRICORNS.size() - 1)])
                material_collected.emit(apricorn, 1)
    elif kind == "bush":
        play_source_sound("cut1")
        if biome_at(cell) == "SNOW":
            material_bundle_collected.emit({"GRASS":1, "LOG":1})
        elif biome_at(cell) == "SAVANNA":
            material_bundle_collected.emit({"GRASS":1, "LOG":1})
        else:
            var apricorn := String(CraftingData.APRICORNS[
                rng.randi_range(0, CraftingData.APRICORNS.size() - 1)
            ])
            material_bundle_collected.emit({"LOG":1, apricorn:1})
    elif kind == "rock":
        play_source_sound("headbutt1" if move == "HEADBUTT" else "strength1")
        material_collected.emit("HARD STONE", 1)
        var found_moon_stone := (
            move == "SMASH" and biome_at(cell) == "MOUNTAIN"
            and rng.randi_range(0, 15) == 0
        )
        if found_moon_stone:
            material_collected.emit("MOON STONE", 1)
            world_message.emit("SMASH! You gathered HARD STONE and found a MOON STONE.")
        else:
            world_message.emit("%s! You gathered HARD STONE." % (
                "HEADBUTT" if move == "HEADBUTT" else "SMASH"))
    elif kind == "flower":
        material_collected.emit("FLOWERS", 1)
        if move != "CUT":
            world_message.emit("You gathered FLOWERS.")
    else:
        return

    _remove_resource(cell, true)

func _remove_resource(cell: Vector2i, remember: bool) -> void:
    if resource_objects.has(cell):
        var data: Dictionary = resource_objects[cell]
        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        var collision: CollisionShape2D = data.get("collision") as CollisionShape2D
        if is_instance_valid(sprite):
            sprite.queue_free()
        if is_instance_valid(collision):
            collision.queue_free()
        resource_objects.erase(cell)
        blocked.erase(cell)
        grass_exclusion.erase(cell)
        flower_cells.erase(cell)
    elif tall_grass.has(cell):
        var grass_data = tall_grass[cell]
        if typeof(grass_data) == TYPE_DICTIONARY:
            var back: Sprite2D = grass_data.get("back") as Sprite2D
            var front: Sprite2D = grass_data.get("front") as Sprite2D
            if is_instance_valid(back):
                back.queue_free()
            if is_instance_valid(front):
                front.queue_free()
        tall_grass.erase(cell)

    if remember:
        removed_resources[_cell_key(cell)] = true

func _cut_tall_grass(cell: Vector2i) -> void:
    if not _is_cuttable_grass_cell(cell):
        return
    if exact_world_mode and plants().harvest(cell):
        return
    const GRASS_AMOUNT := 1
    material_collected.emit("GRASS", GRASS_AMOUNT)
    play_source_sound("cut1")
    if exact_world_mode:
        var tile := exact_world.tile_at(cell)
        if tile != null:
            var old_base := tile.name.to_lower().trim_suffix(".png")
            # Preserve the source grass2 Miracle Seed bonus; the harvested
            # GRASS material itself is always exactly x1 for every grass tile.
            if old_base == "grass2" and rng.randi_range(0, 255) < 64:
                material_collected.emit("MIRACLE SEED", 1)
            var replacement := _cuttable_grass_replacement(tile, cell)
            tile.set_names(String(replacement.get("base", tile.name)),
                String(replacement.get("upper", "")))
            source_interior_mutations[_cell_key(cell)] = {
                "kind":"TILE_NAMES", "base":tile.name, "upper":tile.name_upper
            }
            _unblock_ground(cell)
            # CUT changes this tile; update resident neighbors without scanning
            # collision revisions for the entire world after every grass tuft.
            _refresh_exact_tile_streams()
        return
    if rng.randf() < 0.22:
        material_collected.emit("MIRACLE SEED", 1)
    _remove_resource(cell, true)

func _set_exact_tile_names(cell: Vector2i, base_name: String, upper_name: String) -> void:
    if exact_world == null:
        return
    var tile := exact_world.tile_at(cell)
    if tile == null:
        return
    tile.set_names(base_name, upper_name)
    _refresh_exact_streams()

var restoring_saved_tiles := false
var restored_tiles_need_refresh := false

func _refresh_exact_pickup_cell(cell: Vector2i) -> void:
    _refresh_exact_pickup_cells([cell])

func _refresh_exact_pickup_cells(cells: Array) -> void:
    # Pickups mutate one tile. Never scan the whole resident world for them.
    map_art_revision += 1
    for path in ["GroundLayer/ExactBaseTileStream", "DecorLayer/ExactUpperTileStream"]:
        var stream := get_node_or_null(path)
        if stream == null: continue
        if stream.has_method("refresh_changed_tiles"):
            stream.refresh_changed_tiles(cells)
        else:
            stream.invalidate_tiles()
    var collision_stream := get_node_or_null("ExactCollisionStream") as SourceChunkCollisionStreamer
    if collision_stream != null: collision_stream.refresh_cells(cells)
    if is_instance_valid(reflection_layer) and reflection_layer.has_method("refresh_cells"):
        reflection_layer.refresh_cells(cells)
    var canopy := get_node_or_null("TreeCanopyOverlay")
    if canopy != null: canopy.queue_redraw()

func _refresh_exact_streams() -> void:
    if restoring_saved_tiles:
        restored_tiles_need_refresh = true
        return
    map_art_revision += 1
    if is_instance_valid(reflection_layer) and reflection_layer.has_method("refresh_cells"):
        var cells: Array=[]
        for key in SourceTile.resident_changed_cells: cells.append(Vector2i(key/TILE))
        reflection_layer.refresh_cells(cells)
    var base_stream := get_node_or_null("GroundLayer/ExactBaseTileStream")
    var upper_stream := get_node_or_null("DecorLayer/ExactUpperTileStream")
    if base_stream != null:
        base_stream.invalidate_tiles()
    if upper_stream != null:
        upper_stream.invalidate_tiles()
    var collision_stream := get_node_or_null("ExactCollisionStream") as SourceChunkCollisionStreamer
    if collision_stream != null:
        collision_stream.refresh_now()
    var canopy := get_node_or_null("TreeCanopyOverlay")
    if canopy != null: canopy.queue_redraw()

func _set_exact_overworld_streaming(enabled: bool) -> void:
    if not exact_world_mode:
        return
    var collision_stream := get_node_or_null("ExactCollisionStream") as SourceChunkCollisionStreamer
    if collision_stream != null:
        collision_stream.set_streaming_enabled(enabled)

func _dig_sand(cell: Vector2i) -> void:
    if not _in_bounds(cell) or terrain_kind_at(cell) != 1:
        return
    material_collected.emit("SOFT SAND", 1)
    if exact_world_mode:
        _set_exact_tile_names(cell, "green1", "")
        terrain_changes[_cell_key(cell)] = 2
        world_message.emit("DIG! You gathered SOFT SAND.")
        return
    terrain[cell.y][cell.x] = 2
    terrain_changes[_cell_key(cell)] = 2
    var sprite: Sprite2D = ground_sprites.get(cell) as Sprite2D
    if is_instance_valid(sprite):
        sprite.texture = GRASS
    world_message.emit("DIG! You gathered SOFT SAND.")

const SourceHouseStyles = preload("res://scripts/source_house_styles.gd")

func _house_style_for_recipe(build_name: String) -> String:
    for style in SourceHouseStyles.STYLES:
        if build_name.begins_with(style + " "): return style
    if build_name.begins_with("SAVANNA "):
        return "SAVANNA"
    if build_name.begins_with("TUNDRA "):
        return "TUNDRA"
    return "DEFAULT"

func _house_piece_name(build_name: String) -> String:
    if build_name in ["COUCH 2", "COUCH 3", "COUCH 4", "COUCH 5", "PLANT 2", "VANITY 2"]:
        return build_name.get_slice(" ", 0)
    for style in SourceHouseStyles.STYLES:
        if build_name.begins_with(style + " "): return build_name.trim_prefix(style + " ")
    if build_name.begins_with("SAVANNA "):
        return build_name.trim_prefix("SAVANNA ")
    if build_name.begins_with("TUNDRA "):
        return build_name.trim_prefix("TUNDRA ")
    return build_name

func _styled_house_piece_texture(build_name: String) -> Texture2D:
    var style := _house_style_for_recipe(build_name)
    var piece := _house_piece_name(build_name)
    if SourceHouseStyles.STYLES.has(style):
        return SourceHouseStyles.texture(style, piece)
    if style == "DEFAULT":
        return null
    if piece == "ROOF":
        return SOURCE_HOUSE8_ROOF if style == "SAVANNA" else SOURCE_HOUSE12_ROOF
    if piece == "DOOR":
        return SOURCE_HOUSE8_DOOR if style == "SAVANNA" else SOURCE_HOUSE12_DOOR
    if piece != "WALL":
        return null
    # The alternate source house facades are complete 3-column sheets. Their
    # middle 16x16 wall cell is the authored repeatable material tile.
    var atlas := AtlasTexture.new()
    atlas.atlas = SOURCE_HOUSE8_WALL_SHEET if style == "SAVANNA" else SOURCE_HOUSE12_WALL_SHEET
    atlas.region = Rect2(16, 16, 16, 16)
    return atlas

func can_place_structure(
        build_name: String,
        cell: Vector2i,
        ignore_indoor_requirement: bool = false
    ) -> bool:
    var recipe: Dictionary = CraftingData.build_recipe(build_name)
    if recipe.is_empty():
        return false
    # The pieces of a house's outside, and fences, are only kept on the open
    # map. One built inside a house or a cave was lost on the next load, and
    # online it ended the session for the other players, who could not place
    # it. They are refused indoors; INTERIOR WALL is the wall for a room.
    if not ignore_indoor_requirement and active_area_id != "OVERWORLD" and _house_piece_name(build_name) in ["FENCE", "WALL", "ROOF", "DOOR"]:
        world_message.emit("%s can only be built outside." % build_name)
        return false
    if not ignore_indoor_requirement:
        if String(built_structures.get(cell + Vector2i.DOWN, {}).get("name", "")) == "BED": return false
        if _couch_anchor_at(cell) != Vector2i(2147483647,2147483647): return false
        if _house_piece_name(build_name) == "COUCH":
            for occupied in _couch_footprint(build_name, cell):
                if not _is_built_house_floor_cell(occupied) or built_structures.has(occupied) or interior_interactables.has(occupied) or deployed_pokemon.has(occupied) or wild_eggs.has(occupied) or blocked.has(occupied): return false
    if build_name == "BED" and not ignore_indoor_requirement:
        var head_cell := cell + Vector2i.UP
        if not _is_built_house_floor_cell(head_cell) or built_structures.has(head_cell) or interior_interactables.has(head_cell) or deployed_pokemon.has(head_cell) or wild_eggs.has(head_cell):
            return false
    if _is_window_recipe(build_name) and active_area_id == "OVERWORLD":
        var wall: Dictionary = built_structures.get(cell, {})
        return String(wall.get("name", "")) == "WALL" and not bool(wall.get("window", false))
    # A torch goes on the ground or, as in the source game, on a wall.
    if build_name == "TORCH" and not ignore_indoor_requirement and _torch_wall_at(cell):
        var torch_wall: Dictionary = built_structures[cell]
        return not bool(torch_wall.get("torch", false)) and not bool(torch_wall.get("window", false))
    if _is_house_decoration(build_name) and not (build_name == "CLOCK" and ignore_indoor_requirement):
        if active_area_id != "HOUSE": return false
        var on_wall := _is_window_recipe(build_name) or build_name == "CLOCK"
        if on_wall and not built_house_paintable_walls.has(cell): return false
        if not on_wall and not (_is_built_house_floor_cell(cell) or _built_house_floor_can_expand(cell)): return false
        return String(built_house_decorations.get(_built_house_paint_key(cell), {}).get("name", "")) != build_name
    if build_name in ["WINDOW", "CHIMNEY"] and active_area_id == "OVERWORLD" and not ignore_indoor_requirement:
        var shell: Dictionary = built_structures.get(cell, {})
        var required := "WALL" if build_name == "WINDOW" else "ROOF"
        return active_area_id == "OVERWORLD" and String(shell.get("name", "")) == required and not bool(shell.get(build_name.to_lower(), false))
    if not ignore_indoor_requirement and String(built_structures.get(cell + Vector2i.DOWN, {}).get("name", "")) == "BED":
        return false
    if build_name == "FLOOR" and active_area_id == "HOUSE":
        return _built_house_floor_can_expand(cell)
    var in_built_house: bool = _is_built_house_floor_cell(cell)
    if build_name == "STAIRS" and active_area_id == "HOUSE" and not ignore_indoor_requirement:
        var stair_floor: int = _built_house_floor_index_for_cell(cell)
        if stair_floor < 0 or stair_floor >= built_house_floor_capacity - 1:
            world_message.emit("This house needs to be taller.")
            return false
        var stair_local: Vector2i = cell - _built_house_floor_origin(stair_floor)
        var upper_cell: Vector2i = _built_house_global_cell(stair_floor + 1, stair_local)
        if built_structures.has(upper_cell):
            world_message.emit("The floor above is blocked.")
            return false
    # Saved indoor structures live in the generated house coordinate space,
    # outside overworld bounds. Permit only an indoor recipe on restore there.
    var restoring_indoor: bool = (
        ignore_indoor_requirement and (bool(recipe.get("indoors", false)) or build_name in ["TORCH", "STORAGE BOX", "PRIVATE CHEST", "SIGN", "STATUE", "PLANT", "GRAVE", "FLOWERS", "CAMPFIRE"])
        and not _in_bounds(cell)
    )
    if not _in_bounds(cell) and not in_built_house and not restoring_indoor:
        return false
    if (
            built_structures.has(cell)
            or landmarks.has(cell)
            or resource_objects.has(cell)
            or deployed_pokemon.has(cell)
            or wild_eggs.has(cell)
            or interior_interactables.has(cell)
            or _wild_id_at_cell(cell) >= 0
        ):
        return false
    if _is_tall_grass_cell(cell) and not (build_name == "BRIDGE" and _bridge_surface_at(cell)):
        return false

    if (
            bool(recipe.get("indoors", false))
            and not ignore_indoor_requirement
            and not _is_cell_indoors(cell)
        ):
        world_message.emit("That must be built indoors.")
        return false

    # Every recorded built-house interior cell is authored floor. It is valid
    # for indoor furniture and linked stairs even though it is off the overworld.
    if in_built_house or restoring_indoor:
        return true

    if build_name == "BRIDGE":
        return _bridge_surface_at(cell)
    if terrain_kind_at(cell) == 0:
        return false
    return not blocked.has(cell)

func _bridge_surface_at(cell: Vector2i) -> bool:
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        return tile != null and ("water" in tile.name or "_tidal" in tile.name or "lava" in tile.name) and not "bridge" in tile.name
    return _in_bounds(cell) and terrain_kind_at(cell) == 0

func place_structure(build_name: String, cell: Vector2i, restoring: bool = false, restored_state: Dictionary = {}, committed_online: bool = false) -> bool:
    map_art_revision += 1
    if not restoring:
        cell = _snap_build_cell(build_name, cell)
    # Persisted exterior pieces are authoritative. Reconstructed terrain,
    # regrowth and actors must not silently delete walls/roofs during loading.
    # Keep ordinary placement validation for newly built pieces.
    var saved_exterior := restoring and _house_piece_name(build_name) in ["FENCE", "WALL", "ROOF", "DOOR"]
    if saved_exterior:
        if not _in_bounds(cell) or built_structures.has(cell):
            return false
    elif not committed_online and not can_place_structure(build_name, cell, restoring):
        return false
    if _is_window_recipe(build_name) and active_area_id == "OVERWORLD" and not restoring:
        built_structures[cell]["window"] = true
        built_structures[cell]["window_recipe"] = build_name
        built_structures[cell]["window_variant"] = 0
        _refresh_shell_attachment(cell)
        return true
    if build_name == "TORCH" and not restoring and _torch_wall_at(cell):
        built_structures[cell]["torch"] = true
        _refresh_shell_attachment(cell)
        return true
    if _is_house_decoration(build_name) and not (build_name == "CLOCK" and restoring):
        if build_name.begins_with("CARPET ") and not built_house_interior_cells.has(cell):
            var floor_index := _built_house_floor_index_for_cell(cell)
            if not _add_built_house_floor_cell(floor_index, cell - _built_house_floor_origin(floor_index), true): return false
        built_house_decorations[_built_house_paint_key(cell)] = {"name":build_name, "variant":0}
        _draw_house_decoration(cell)
        if build_name.begins_with("CARPET "):
            for bed_cell in [cell, cell + Vector2i.DOWN]:
                var bed: Dictionary = built_structures.get(bed_cell, {})
                if String(bed.get("name", "")) != "BED": continue
                bed["bed_carpet"] = int(build_name.get_slice(" ", 1))
                var bed_sprite := bed.get("sprite") as Sprite2D
                if is_instance_valid(bed_sprite): bed_sprite.texture = _colored_bed_texture(int(bed.bed_carpet))
        return true
    if build_name in ["WINDOW", "CHIMNEY"] and active_area_id == "OVERWORLD" and not restoring:
        built_structures[cell][build_name.to_lower()] = true
        _refresh_shell_attachment(cell)
        pass # Successful construction is silent.
        return true
    if build_name == "FLOOR" and active_area_id == "HOUSE" and not restoring:
        return _place_built_house_floor(cell)

    var recipe := CraftingData.build_recipe(build_name)
    var requested_name := build_name
    var house_style := String(restored_state.get("house_style", _house_style_for_recipe(requested_name)))
    var structure_name := String(restored_state.get("name", _house_piece_name(requested_name)))
    if restoring and restored_state.has("recipe_name"):
        requested_name = String(restored_state.get("recipe_name", requested_name))
        house_style = String(restored_state.get("house_style", _house_style_for_recipe(requested_name)))
        structure_name = String(restored_state.get("name", _house_piece_name(requested_name)))
    var sprite := Sprite2D.new()
    var display_recipe_name := requested_name
    if restoring and house_style != "DEFAULT" and structure_name in ["WALL", "ROOF", "DOOR"]:
        display_recipe_name = "%s %s" % [house_style, structure_name]
    # Player-placed stairs use the normal source STAIRS artwork (`stairs_up1`);
    # only the automatically generated landing on the floor above uses the
    # source house down-stair artwork. This mirrors the direction of travel.
    sprite.texture = _structure_display_texture(
        display_recipe_name, int(restored_state.get("variant", 0))
    )
    if structure_name == "BED" and int(restored_state.get("bed_carpet", 0)) > 0:
        sprite.texture = _colored_bed_texture(int(restored_state.bed_carpet))
    if sprite.texture == null:
        return false
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.position = Vector2(cell.x * TILE, cell.y * TILE - maxi(0, int(sprite.texture.get_height()) - TILE))
    sprite.z_as_relative = false
    # A beacon is a floor tile that is stood on, like a bridge.
    sprite.z_index = 10 if structure_name in ["BRIDGE", "BEACON"] else _depth_z(cell)

    var layer := get_node_or_null("LandmarkLayer") as Node2D
    if layer == null:
        return false
    layer.add_child(sprite)

    var collision: CollisionShape2D = null
    var solid := bool(recipe.get("solid", false))
    var bridged_water := false

    if structure_name == "BRIDGE" and _bridge_surface_at(cell):
        bridged_water = true
        if exact_world_mode:
            var exact_collision := get_node_or_null("ExactCollisionStream") as SourceChunkCollisionStreamer
            if exact_collision != null:
                exact_collision.set_cell_passable(cell, true)
        var water_collision: CollisionShape2D = ground_collisions.get(cell) as CollisionShape2D
        if is_instance_valid(water_collision):
            water_collision.queue_free()
        ground_collisions.erase(cell)
        blocked.erase(cell)
    elif solid:
        var body := get_node_or_null("WorldCollision") as StaticBody2D
        if body != null:
            collision = _add_block_collision(body, cell.x, cell.y)
            blocked[cell] = true

    grass_exclusion[cell] = true
    var structure_state := restored_state.duplicate(true)
    for runtime_key in ["sprite", "collision", "solid", "bridged_water", "x", "y"]:
        structure_state.erase(runtime_key)
    structure_state.merge({
        "name": structure_name,
        "recipe_name": requested_name,
        "house_style": house_style,
        "sprite": sprite,
        "collision": collision,
        "solid": solid,
        "bridged_water": bridged_water,
        "open": bool(structure_state.get("open", false)),
        "variant": int(structure_state.get("variant", 0)),
        "text": String(structure_state.get("text", "")),
        "last_harvest_day": int(structure_state.get("last_harvest_day", -1))
    }, true)
    if structure_name == "STAIRS" and active_area_id == "HOUSE" and not restoring:
        var stair_metadata: Dictionary = _built_house_stair_metadata(cell)
        for key in stair_metadata:
            structure_state[key] = stair_metadata[key]
        structure_state["generated_stair_pair"] = false
    built_structures[cell] = structure_state
    if structure_name == "COUCH":
        var footprint := _couch_footprint(requested_name, cell)
        for occupied in footprint: blocked[occupied] = true
        if is_instance_valid(collision):
            var width := 32 if requested_name == "COUCH" else 16
            var height := 16 if requested_name in ["COUCH", "COUCH 3", "COUCH 5"] else 32
            (collision.shape as RectangleShape2D).size = Vector2(width,height)
            collision.position = Vector2(cell * TILE) + Vector2(width/2, TILE-height/2)
    if structure_name == "INTERIOR WALL" and _is_house_wall_cell(cell):
        built_house_paintable_walls[cell] = true

    if structure_name == "STAIRS" and active_area_id == "HOUSE" and not restoring:
        _create_generated_house_stair_pair(cell)
    if structure_name == "DOOR":
        var door_open := bool(structure_state.get("open", false))
        _set_structure_solid(cell, not door_open)
        sprite.visible = not door_open
    elif structure_name == "TORCH":
        sprite.modulate = Color.WHITE if bool(structure_state.get("lit", true)) else Color(0.45, 0.45, 0.45)

    if structure_name == "FLOWERS":
        flower_cells[cell] = true

    # Successful construction is silent.
    _refresh_connected_structures_around(cell)
    _refresh_shell_attachment(cell)
    return true

func _structure_display_texture(build_name: String, variant: int = 0) -> Texture2D:
    if build_name == "INTERIOR WALL":
        return SOURCE_HOUSE5_WALL
    if build_name in ["PICHU DOLL", "DUSKULL DOLL", "SKITTY DOLL", "JIGGLYPUFF DOLL"]:
        return load("res://assets/source_0_8_11/tiles/buildings/house_plush%s.png" % build_name.get_slice(" ", 0).to_lower())
    if build_name == "FLOWERS":
        var flower := AtlasTexture.new()
        flower.atlas = FLOWER_1
        flower.region = Rect2(0, 0, 16, 16)
        return flower
    if build_name == "WALL":
        return SOURCE_HOUSE5_WALL_MIDDLE
    if build_name == "TORCH":
        return environment_structure_texture("TORCH", variant)
    if build_name == "ROOF":
        return preload("res://assets/source_0_8_11/tiles/buildings/house5_roof_middle1.png")
    if build_name in ["COUCH 2", "COUCH 3", "COUCH 4", "COUCH 5", "PLANT 2", "VANITY 2"]:
        var authored: Texture2D = load("res://assets/source_0_8_11/tiles/buildings/house_%s%s.png" % [build_name.get_slice(" ", 0).to_lower(), build_name.get_slice(" ", 1)])
        if authored.get_height() == 31:
            # Source selects a 16x32 region even for these 31px couch PNGs.
            var framed := AtlasTexture.new()
            framed.atlas = authored
            framed.region = Rect2(0,0,16,31)
            framed.margin = Rect2(0,0,0,1)
            return framed
        return authored
    if build_name == "WINDOW":
        if active_area_id == "HOUSE":
            return _structure_display_texture("INDOOR WINDOW 1",variant)
        if not window_display_cache.has("normal_exterior"):
            var pixels := preload("res://assets/source_0_8_11/tiles/buildings/exteriorwindows1.png").get_image()
            pixels.convert(Image.FORMAT_RGBA8)
            pixels.fill_rect(Rect2i(0, 8, pixels.get_width(), pixels.get_height() - 8), Color.TRANSPARENT)
            window_display_cache["normal_exterior"] = ImageTexture.create_from_image(pixels)
        return window_display_cache["normal_exterior"]
    if build_name.begins_with("CARPET ") or build_name.begins_with("INDOOR WINDOW "):
        if build_name == "INDOOR WINDOW 1" and active_area_id == "HOUSE":
            variant = 0
        var file := "house_carpet" if build_name.begins_with("CARPET ") else "house_window"
        var texture: Texture2D = load("res://assets/source_0_8_11/tiles/buildings/%s%d.png" % [file, int(build_name.get_slice(" ", 1 if file == "house_carpet" else 2))])
        var frame := AtlasTexture.new()
        frame.atlas = texture
        frame.region = Rect2(wrapi(variant, 0, int(texture.get_width()) / 16) * 16, 0, 16, 16)
        if file == "house_window":
            # Authored windows occupy the upper ten pixels. The six rows below
            # are source wall backing; let the actual supporting wall show.
            var cache_key := build_name + ":" + str(frame.region.position.x)
            if not window_display_cache.has(cache_key):
                var window_pixels := frame.get_image()
                window_pixels.fill_rect(Rect2i(0, 10, 16, 6), Color.TRANSPARENT)
                window_display_cache[cache_key] = ImageTexture.create_from_image(window_pixels)
            return window_display_cache[cache_key]
        return frame
    var styled := _styled_house_piece_texture(build_name)
    if styled != null:
        return styled
    var source := structure_textures.get(build_name) as Texture2D
    if source == null:
        return null
    if build_name == "PRIVATE CHEST":
        return _private_chest_texture(source)
    if build_name == "STORAGE BOX":
        # chest1.png's top-left 16x16 cell is transparent. The authored closed
        # storage-box frame used for placement starts on the second row.
        var chest_frame := AtlasTexture.new()
        chest_frame.atlas = source
        chest_frame.region = Rect2(0, 16, 16, 16)
        return chest_frame
    var source_size := source.get_size()
    var display_width := 64 if build_name == "CHIMNEY" else 32 if build_name == "COUCH" else mini(16, int(source_size.x))
    var display_height := 24 if build_name == "KILN" else 32 if build_name in ["STATUE", "PLANT", "BED", "SHELF", "DRESSER", "VANITY", "BEACON", "CHIMNEY"] else 20 if build_name == "CAMPFIRE" else mini(16, int(source_size.y))
    if int(source_size.x) <= display_width and int(source_size.y) <= display_height:
        return source
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    var frames_x := maxi(1, int(source_size.x) / display_width)
    var frame := wrapi(variant, 0, frames_x)
    atlas.region = Rect2(frame * display_width, 0, display_width, mini(display_height, int(source_size.y)))
    return atlas

func _colored_bed_texture(carpet_index: int) -> Texture2D:
    # DynamicTextures.cacheColoredHouseBed: carpet at (0,12), then bed frame.
    var image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
    var carpet := (load("res://assets/source_0_8_11/tiles/buildings/house_carpet%d.png" % clampi(carpet_index,1,8)) as Texture2D).get_image()
    var frame := preload("res://assets/source_0_8_11/tiles/buildings/house_bed1_colorbase.png").get_image()
    image.blend_rect(carpet, Rect2i(0,0,16,16), Vector2i(0,12))
    image.blend_rect(frame, Rect2i(0,0,16,32), Vector2i.ZERO)
    return ImageTexture.create_from_image(image)

func _interact_built_structure(cell: Vector2i) -> void:
    if not built_structures.has(cell):
        return
    var data: Dictionary = built_structures[cell]
    var build_name := String(data.get("name", ""))

    var recipe := CraftingData.build_recipe(build_name)
    var station := String(recipe.get("station", ""))
    if not station.is_empty():
        crafting_station_requested.emit(station)
        return

    if build_name == "DRESSER":
        structure_action.emit("DRESSER")
    elif build_name == "VANITY":
        structure_action.emit("VANITY")
    elif build_name == "BED":
        structure_action.emit("BED:%d:%d" % [cell.x, cell.y])
    elif build_name in ["STORAGE BOX","PRIVATE CHEST"]:
        structure_action.emit("STORAGE:%s" % _cell_key(cell))
    elif build_name == "BEACON":
        structure_action.emit("BEACON_EDIT:%d:%d:%s" % [
            cell.x, cell.y, String(data.get("label", ""))
        ])
    elif build_name == "SIGN":
        var sign_text := String(data.get("text", ""))
        if sign_text.is_empty():
            structure_action.emit("SIGN_EDIT:%d:%d:" % [cell.x, cell.y])
        else:
            world_message.emit(sign_text)
    elif build_name == "DOOR":
        if bool(data.get("gate", false)):
            return # Source gates are passable; walking through requires no prompt.
        if active_area_id == "OVERWORLD":
            var house_state: Dictionary = _built_house_state(cell)
            if bool(house_state.get("ready", false)):
                var outward := _house_door_outward(cell)
                if outward == Vector2i.ZERO or not _house_exit_clear(cell + outward):
                    world_message.emit("This entrance needs a clear outside tile.")
                    return
                _prepare_built_house_interior(cell, house_state)
                _enter_source_area("HOUSE", cell + outward)
            else:
                world_message.emit(String(house_state.get(
                    "message", "This house needs a completed roof.")))
        else:
            _toggle_structure_door(cell)
    elif build_name == "WINDOW":
        data["variant"] = wrapi(int(data.get("variant", 0)) + 1, 0, 3)
        built_structures[cell] = data
        var window_sprite := data.get("sprite") as Sprite2D
        if is_instance_valid(window_sprite):
            window_sprite.texture = _structure_display_texture("WINDOW", int(data["variant"]))
        world_message.emit("You adjusted the WINDOW.")
    elif build_name == "PLANT":
        var day := _world_day_index()
        if int(data.get("last_harvest_day", -1)) < day:
            data["last_harvest_day"] = day
            built_structures[cell] = data
            material_collected.emit("MIRACLE SEED", 1)
            world_message.emit("The PLANT yielded a MIRACLE SEED.")
        else:
            world_message.emit("The PLANT needs another day to grow.")
    elif build_name == "CLOCK":
        var day_fraction := fmod(world_elapsed_seconds, WORLD_DAY_SECONDS) / WORLD_DAY_SECONDS
        var total_minutes := int(floor(day_fraction * 24.0 * 60.0))
        world_message.emit("The CLOCK reads %02d:%02d on day %d." % [total_minutes / 60, total_minutes % 60, _world_day_index() + 1])
    elif build_name == "STOOL":
        _sit_on_stool(cell)
    elif build_name == "COUCH":
        _sit_on_stool(cell)
    elif build_name.ends_with(" DOLL"):
        world_message.emit("A %s. Cute!" % build_name.to_lower())
    elif build_name == "TABLE":
        crafting_station_requested.emit("WORK TABLE")
    elif build_name == "TRASH CAN":
        world_message.emit("The TRASH CAN is empty.")
    elif build_name == "SHELF":
        world_message.emit("A sturdy SHELF for displaying supplies.")
    elif build_name == "STAIRS":
        _use_linked_stairs(cell)
    elif build_name == "TORCH":
        data["lit"] = not bool(data.get("lit", true))
        built_structures[cell] = data
        var torch_sprite := data.get("sprite") as Sprite2D
        if is_instance_valid(torch_sprite):
            torch_sprite.modulate = Color.WHITE if bool(data["lit"]) else Color(0.45, 0.45, 0.45)
        world_message.emit("The TORCH is now %s." % ("lit" if bool(data["lit"]) else "out"))
    else:
        world_message.emit("You inspect the %s." % build_name)

func _couch_footprint(recipe: String, cell: Vector2i) -> Array[Vector2i]:
    if recipe in ["COUCH 3", "COUCH 5"]:
        return [cell]
    return [cell, cell + (Vector2i.RIGHT if recipe == "COUCH" else Vector2i.UP)]

func _couch_anchor_at(cell: Vector2i) -> Vector2i:
    for candidate in [cell, cell + Vector2i.DOWN, cell + Vector2i.LEFT]:
        var data: Dictionary = built_structures.get(candidate, {})
        if String(data.get("name", "")) == "COUCH" and cell in _couch_footprint(String(data.get("recipe_name", "COUCH")), candidate):
            return candidate
    return Vector2i(2147483647,2147483647)

func _sit_on_stool(cell: Vector2i) -> void:
    if is_instance_valid(stool_seated_sprite):
        return
    var main := get_parent()
    if main == null or not main.has_method("_player_sitting_texture"):
        return
    clear_active_field_move(false)
    stool_seated_sprite = Sprite2D.new()
    var recipe := String(built_structures.get(cell, {}).get("recipe_name", "STOOL"))
    var couch_side := recipe in ["COUCH 2", "COUCH 3", "COUCH 4", "COUCH 5"]
    stool_seated_sprite.texture = main._player_sitting_texture(2 if couch_side else 0)
    stool_seated_sprite.flip_h = recipe in ["COUCH 2", "COUCH 3"]
    stool_seated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    stool_seated_sprite.position = _cell_center(cell)
    # Player.Sitting source offsets, with Java Y-up converted to Godot Y-down.
    if recipe == "COUCH": stool_seated_sprite.position += Vector2(0,-3)
    elif couch_side: stool_seated_sprite.position += Vector2(3 if stool_seated_sprite.flip_h else -3,-5)
    stool_seated_sprite.z_as_relative = false
    var stool := built_structures.get(cell, {}).get("sprite") as Sprite2D
    stool_seated_sprite.z_index = stool.z_index + 1 if is_instance_valid(stool) else _depth_z(cell, 25)
    add_child(stool_seated_sprite)
    player.sprite.visible = false
    player.velocity = Vector2.ZERO
    set_gameplay_enabled(false)

func turn_seated_player(action: String) -> void:
    if not is_instance_valid(stool_seated_sprite): return
    var frame := 1 if action == "move_up" else 0 if action == "move_down" else 2
    stool_seated_sprite.texture = get_parent()._player_sitting_texture(frame)
    stool_seated_sprite.flip_h = action == "move_right"

func end_stool_sitting() -> void:
    if not is_instance_valid(stool_seated_sprite):
        return
    stool_seated_sprite.queue_free()
    stool_seated_sprite = null
    player.sprite.visible = true
    set_gameplay_enabled(true)

func set_structure_sign_text(cell: Vector2i, value: String) -> void:
    if not built_structures.has(cell):
        return
    var data: Dictionary = built_structures[cell]
    if String(data.get("name", "")) != "SIGN":
        return
    data["text"] = value.strip_edges().left(64)
    built_structures[cell] = data
    world_message.emit("The SIGN now reads: %s" % String(data["text"]))

func _set_structure_solid(cell: Vector2i, solid: bool) -> void:
    if not built_structures.has(cell):
        return
    var data: Dictionary = built_structures[cell]
    var collision := data.get("collision") as CollisionShape2D
    if solid and not is_instance_valid(collision):
        var body := get_node_or_null("WorldCollision") as StaticBody2D
        if body != null:
            collision = _add_block_collision(body, cell.x, cell.y)
            blocked[cell] = true
    elif not solid and is_instance_valid(collision):
        collision.queue_free()
        collision = null
        blocked.erase(cell)
    data["collision"] = collision
    data["solid"] = solid
    built_structures[cell] = data

func _built_house_state(door_cell: Vector2i) -> Dictionary:
    # Source smart-building follows connected house pieces from the door. It
    # does not impose M73's invented minimum counts/height. A connected door
    # with a roof and structural body is a completed enterable house.
    var house_names: Array[String] = ["WALL", "ROOF", "DOOR", "WINDOW", "CHIMNEY"]
    var visited: Dictionary = {}
    var queue: Array[Vector2i] = [door_cell]
    var queue_index := 0
    var has_door := false
    var has_roof := false
    var has_body := false
    var wall_rows: Dictionary = {}
    var cells: Array[Vector2i] = []
    var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
    while queue_index < queue.size():
        var current: Vector2i = queue[queue_index]
        queue_index += 1
        if visited.has(current) or not built_structures.has(current):
            continue
        var name := String((built_structures[current] as Dictionary).get("name", ""))
        if name not in house_names:
            continue
        visited[current] = true
        cells.append(current)
        has_door = has_door or name == "DOOR"
        has_roof = has_roof or name in ["ROOF", "CHIMNEY"]
        has_body = has_body or name in ["WALL", "WINDOW", "DOOR"]
        if name in ["WALL", "WINDOW"]:
            wall_rows[current.y] = true
        for direction in directions:
            var neighbor: Vector2i = current + direction
            if not visited.has(neighbor):
                queue.append(neighbor)
    if not has_door or not has_body:
        return {"ready":false, "message":"This house still needs connected walls and a door.", "cells":cells}
    if not has_roof:
        return {"ready":false, "message":"This house still needs a connected roof.", "cells":cells}
    var door_style := "DEFAULT"
    if built_structures.has(door_cell):
        door_style = String((built_structures[door_cell] as Dictionary).get("house_style", "DEFAULT"))
    # Source house height rule: every exterior wall row permits one interior
    # floor. A basic one-row house therefore has only its ground floor; stairs
    # require another wall row before the roof.
    var floor_count: int = maxi(1, wall_rows.size())
    return {
        "ready":true, "message":"", "cells":cells,
        "house_style":door_style, "floor_count":floor_count
    }

func _toggle_structure_door(cell: Vector2i) -> void:
    var data: Dictionary = built_structures[cell]
    var is_open := not bool(data.get("open", false))
    data["open"] = is_open
    built_structures[cell] = data
    _set_structure_solid(cell, not is_open)
    var sprite := data.get("sprite") as Sprite2D
    if is_instance_valid(sprite):
        sprite.visible = not is_open
    world_message.emit("The DOOR opened." if is_open else "The DOOR closed.")

func _built_house_stair_landing(stair: Vector2i) -> Vector2i:
    for direction in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
        var cell: Vector2i = stair + direction
        if not built_house_interior_cells.has(cell):
            continue
        if interior_interactables.has(cell) or built_structures.has(cell) or \
                wild_eggs.has(cell) or deployed_pokemon.has(cell):
            continue
        if _wild_id_at_cell(cell) >= 0:
            continue
        return cell
    # A 1-cell room can only land on the stair itself.
    if built_house_interior_cells.has(stair):
        return stair
    return Vector2i(-2147483648, -2147483648)

func _use_linked_stairs(source: Vector2i) -> void:
    if house_transition_active: return
    if not built_structures.has(source):
        return
    var source_data: Dictionary = built_structures[source]
    if active_area_id == "HOUSE" and _stair_belongs_to_active_house(source_data):
        var source_floor: int = int(source_data.get("house_floor", -1))
        var destination: Vector2i = Vector2i(-2147483648, -2147483648)
        var destination_floor: int = source_floor
        if bool(source_data.get("generated_stair_pair", false)):
            var primary: Vector2i = Vector2i(
                int(source_data.get("stair_primary_x", -2147483648)),
                int(source_data.get("stair_primary_y", -2147483648))
            )
            if built_structures.has(primary):
                destination = primary
                destination_floor = source_floor - 1
        else:
            var local_cell: Vector2i = Vector2i(
                int(source_data.get("house_local_x", 0)),
                int(source_data.get("house_local_y", 0))
            )
            destination_floor = source_floor + 1
            if destination_floor < built_house_floor_capacity:
                destination = _built_house_global_cell(destination_floor, local_cell)
                if not built_structures.has(destination):
                    _create_generated_house_stair_pair(source)
        if destination.x <= -2147483648 or not built_structures.has(destination):
            world_message.emit("This house needs to be taller.")
            return
        var landing: Vector2i = _built_house_stair_landing(destination)
        if landing.x <= -2147483648:
            world_message.emit("The connected STAIRS need a clear landing.")
            return
        await _house_door_transition("enter" if destination_floor > source_floor else "exit", func() -> void:
            _set_active_built_house_floor(destination_floor)
            player.position = _cell_center(landing)
            last_player_cell = landing
            _sync_follower_to_player()
        )
        return

    # Compatibility behavior for any old non-house linked stair builds.
    var candidates: Array[Vector2i] = []
    for raw_cell in built_structures.keys():
        var cell: Vector2i = raw_cell
        if cell == source or String((built_structures[cell] as Dictionary).get(
                "name", "")) != "STAIRS":
            continue
        candidates.append(cell)
    if candidates.is_empty():
        world_message.emit("These STAIRS need a second staircase to connect to.")
        return
    candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        return a.distance_squared_to(source) < b.distance_squared_to(source))
    var destination: Vector2i = candidates[0] + Vector2i.DOWN
    await _house_door_transition("enter", func() -> void:
        player.position = _cell_center(destination)
        last_player_cell = destination
        _sync_follower_to_player()
    )

func _house_connection_piece(cell: Vector2i) -> String:
    var data: Dictionary = built_structures.get(cell, {})
    var name := String(data.get("name", ""))
    if name != "DOOR" or bool(data.get("gate", false)): return name
    var left := String(built_structures.get(cell + Vector2i.LEFT, {}).get("name", ""))
    var right := String(built_structures.get(cell + Vector2i.RIGHT, {}).get("name", ""))
    var up := String(built_structures.get(cell + Vector2i.UP, {}).get("name", ""))
    var down := String(built_structures.get(cell + Vector2i.DOWN, {}).get("name", ""))
    # PkmnMap.adjustTile: roof-sandwiched doors become roof with a north rug.
    if left in ["ROOF", "DOOR"] and right in ["ROOF", "DOOR"] and (left == "ROOF" or right == "ROOF"):
        return "ROOF"
    if up in ["WALL", "ROOF", "DOOR"] and down in ["WALL", "ROOF", "DOOR"] and (up != "DOOR" or down != "DOOR"):
        return "ROOF" if left == "ROOF" or right == "ROOF" else "WALL"
    return name

func _house_connection_style(cell: Vector2i) -> String:
    var data: Dictionary = built_structures.get(cell, {})
    var style := String(data.get("house_style", "DEFAULT"))
    if String(data.get("name", "")) == "DOOR" and style == "DEFAULT":
        for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            var neighbor: Dictionary = built_structures.get(cell + direction, {})
            if String(neighbor.get("name", "")) in ["ROOF", "WALL"]:
                return String(neighbor.get("house_style", "DEFAULT"))
    return style

func _house_exit_clear(cell: Vector2i) -> bool:
    if built_structures.has(cell) or blocked.has(cell) or resource_objects.has(cell) or landmarks.has(cell): return false
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        return tile != null and not tile.is_solid and not tile.is_water and not tile.is_lava
    return _in_bounds(cell) and terrain_kind_at(cell) != 0

func _house_door_outward(cell: Vector2i) -> Vector2i:
    var left := String(built_structures.get(cell + Vector2i.LEFT, {}).get("name", ""))
    var right := String(built_structures.get(cell + Vector2i.RIGHT, {}).get("name", ""))
    if left in ["ROOF", "DOOR"] and right in ["ROOF", "DOOR"] and (left == "ROOF" or right == "ROOF"):
        return Vector2i.UP
    if _house_connection_piece(cell) in ["WALL", "ROOF"]:
        if _house_exit_clear(cell + Vector2i.LEFT): return Vector2i.LEFT
        if _house_exit_clear(cell + Vector2i.RIGHT): return Vector2i.RIGHT
        return Vector2i.ZERO
    return Vector2i.DOWN

func _refresh_connected_structures_around(center: Vector2i) -> void:
    var refresh_cells: Array[Vector2i] = [center, center + Vector2i.LEFT, center + Vector2i.RIGHT, center + Vector2i.UP, center + Vector2i.DOWN]
    # Source desert roof inner corners also depend on diagonal neighbors.
    for offset in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
        if _house_connection_style(center+offset) == "DESERT" and _house_connection_piece(center+offset) == "ROOF":
            refresh_cells.append(center+offset)
    for cell in refresh_cells:
        if not built_structures.has(cell):
            continue
        var data: Dictionary = built_structures[cell]
        var name := String(data.get("name", ""))
        if name == "DOOR":
            var horizontal_gate := _is_fence_cell(cell + Vector2i.LEFT) and _is_fence_cell(cell + Vector2i.RIGHT)
            var vertical_gate := _is_fence_cell(cell + Vector2i.UP) and _is_fence_cell(cell + Vector2i.DOWN)
            data["gate"] = horizontal_gate or vertical_gate
            var door_sprite := data.get("sprite") as Sprite2D
            if is_instance_valid(door_sprite):
                door_sprite.visible = true
                var door_recipe := String(data.get("recipe_name", "DOOR"))
                if String(data.get("house_style", "DEFAULT")) == "DEFAULT" and not data.gate:
                    for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
                        var neighbor: Dictionary = built_structures.get(cell + direction, {})
                        if String(neighbor.get("name", "")) == "WALL":
                            var neighbor_style := String(neighbor.get("house_style", "DEFAULT"))
                            if neighbor_style != "DEFAULT": door_recipe = neighbor_style + " DOOR"
                            break
                door_sprite.texture = SourceWorldData.texture_for("fence1gate1_NS" if vertical_gate else "fence1gate1") if data.gate else _structure_display_texture(door_recipe)
                door_sprite.rotation = 0.0
                door_sprite.position = Vector2(cell * TILE) - Vector2(0, maxi(0, int(door_sprite.texture.get_height()) - TILE))
                door_sprite.z_index = _depth_z(cell) + (0 if data.gate else 1)
                _set_structure_solid(cell, false if data.gate else not bool(data.get("open", false)))
            built_structures[cell] = data
            var old_rug := door_sprite.get_node_or_null("SideEntrance") if is_instance_valid(door_sprite) else null
            if is_instance_valid(old_rug):
                door_sprite.remove_child(old_rug)
                old_rug.queue_free()
            name = _house_connection_piece(cell)
            if name == "DOOR": continue
            if is_instance_valid(door_sprite):
                if name == "WALL":
                    var style := _house_connection_style(cell)
                    door_sprite.texture = SOURCE_HOUSE5_WALL_MIDDLE if style == "DEFAULT" else _structure_display_texture(style + " WALL")
                var outward := _house_door_outward(cell)
                if outward != Vector2i.ZERO and _house_exit_clear(cell + outward):
                    var rug := Sprite2D.new()
                    rug.name = "SideEntrance"
                    rug.texture = SourceWorldData.texture_for("rug2_right" if outward == Vector2i.LEFT else "rug2_left" if outward == Vector2i.RIGHT else "rug2")
                    rug.centered = false
                    rug.position = Vector2(outward * TILE)
                    rug.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                    # It is floor. As the door's child it took the door's depth
                    # and was drawn over anyone standing on it; put it at ground
                    # level, where a bridge sits, under players and Pokemon.
                    rug.z_as_relative = false
                    rug.z_index = 10
                    door_sprite.add_child(rug)
        if name == "INTERIOR WALL":
            var wall_suffix := ""
            for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.RIGHT,Vector2i.LEFT]:
                var neighbor: Vector2i = cell + direction
                var joined := String(built_structures.get(neighbor,{}).get("name","")) == "INTERIOR WALL"
                if direction == Vector2i.UP:
                    joined = joined or _built_house_rear_wall_floor(neighbor) >= 0
                elif direction.x != 0 and _is_built_house_floor_cell(cell):
                    joined = joined or not _is_built_house_floor_cell(neighbor)
                if joined: wall_suffix += "N" if direction == Vector2i.UP else "S" if direction == Vector2i.DOWN else "E" if direction == Vector2i.RIGHT else "W"
            var wall_sprite := data.get("sprite") as Sprite2D
            if is_instance_valid(wall_sprite):
                wall_sprite.texture = SOURCE_HOUSE5_WALL
                wall_sprite.position = Vector2(cell*TILE)
                wall_sprite.rotation = 0.0
                wall_sprite.z_index = _depth_z(cell)
            data["wall_connections"] = wall_suffix
            built_structures[cell] = data
            continue
        if name not in ["FENCE", "WALL", "INTERIOR WALL", "ROOF", "TABLE"]:
            continue
        var connection_names: Array[String] = [name]
        if name in ["WALL", "INTERIOR WALL"]:
            connection_names = ["WALL", "INTERIOR WALL", "DOOR", "WINDOW"]
        elif name == "ROOF":
            connection_names = ["ROOF", "CHIMNEY"]
        elif name == "FENCE":
            connection_names = ["FENCE", "DOOR"]
        var north := _house_connection_piece(cell + Vector2i.UP) in connection_names
        var south := _house_connection_piece(cell + Vector2i.DOWN) in connection_names
        var east := _house_connection_piece(cell + Vector2i.RIGHT) in connection_names
        var west := _house_connection_piece(cell + Vector2i.LEFT) in connection_names
        var source_style := _house_connection_style(cell)
        if SourceHouseStyles.STYLES.has(source_style):
            north = north and (String(built_structures.get(cell+Vector2i.UP,{}).get("name","")) == "DOOR" or String(built_structures.get(cell+Vector2i.UP,{}).get("house_style","")) == source_style)
            south = south and (String(built_structures.get(cell+Vector2i.DOWN,{}).get("name","")) == "DOOR" or String(built_structures.get(cell+Vector2i.DOWN,{}).get("house_style","")) == source_style)
            east = east and (String(built_structures.get(cell+Vector2i.RIGHT,{}).get("name","")) == "DOOR" or String(built_structures.get(cell+Vector2i.RIGHT,{}).get("house_style","")) == source_style)
            west = west and (String(built_structures.get(cell+Vector2i.LEFT,{}).get("name","")) == "DOOR" or String(built_structures.get(cell+Vector2i.LEFT,{}).get("house_style","")) == source_style)
        var horizontal := east or west
        var vertical := north or south
        data["connections"] = (1 if horizontal else 0) | (2 if vertical else 0)
        built_structures[cell] = data
        var sprite := data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            var suffix := ("N" if north else "") + ("S" if south else "") + ("E" if east else "") + ("W" if west else "")
            var connected_path := ""
            if name == "FENCE":
                # Single vertical ends use the authored NS tile too. Rotating
                # a non-centered horizontal sprite swings it into the next cell.
                if vertical and not horizontal:
                    suffix = "NS"
                connected_path = "res://assets/source_0_8_11/tiles/fence1%s.png" % (
                    "" if suffix in ["", "E", "W", "EW"] else "_" + suffix)
            elif name == "TABLE":
                var table_part: String = {"":"default", "E":"left1", "W":"right1", "EW":"middle1", "NS":"middle2", "N":"down1", "S":"up1"}.get(suffix, suffix)
                connected_path = "res://assets/source_0_8_11/tiles/buildings/house_table1_%s.png" % table_part
            var house_style := source_style
            if name == "ROOF" and house_style == "DEFAULT" and suffix.length() >= 2:
                connected_path = "res://assets/source_0_8_11/tiles/buildings/house5_roof_%s.png" % suffix
            elif name == "WALL" and house_style == "DEFAULT" and horizontal:
                connected_path = "res://assets/source_0_8_11/tiles/buildings/%s" % (
                    "house5_middle1.png" if east and west else "house5_left1.png" if east else "house5_right1.png"
                )
            if name == "ROOF" or (SourceHouseStyles.STYLES.has(house_style) and name == "WALL"):
                # Java north is screen-up for player-built shells.
                var ext := suffix
                if name == "WALL":
                    if house_style != "STILT":
                        if east and west and not north and not south: ext = "NEW"
                        if ext.length() <= 1: ext += "N"
                    elif ext.is_empty(): ext = "S"
                elif house_style != "STILT":
                    if ext.is_empty(): ext = "middle1"
                    if east and west and not north and not south: ext = "middle1"
                    elif (north or south) and not east and not west: ext = "NSEW"
                    elif ext.length() == 1: ext = "right1" if west else "left1" if east else ""
                    if house_style == "DESERT" and suffix.length() >= 3:
                        for corner in ["SE", "SW", "NE", "NW"]:
                            var offset := Vector2i(1 if "E" in corner else -1, -1 if "N" in corner else 1)
                            if corner[0] in suffix and corner[1] in suffix and _house_connection_piece(cell+offset) != "ROOF":
                                ext = corner + "inner"
                                break
                sprite.texture = SourceHouseStyles.roof_texture(house_style, ext) if name == "ROOF" else SourceHouseStyles.texture(house_style, name, ext)
                sprite.rotation_degrees = 0
                sprite.position.y = cell.y * TILE - maxi(0, int(sprite.texture.get_height()) - TILE)
                if bool(data.get("window", false)): _refresh_shell_attachment(cell)
                continue
            if not connected_path.is_empty() and ResourceLoader.exists(connected_path):
                sprite.texture = load(connected_path)
                sprite.rotation_degrees = 0.0
            else:
                var display_name := name
                if house_style != "DEFAULT" and name in ["WALL", "ROOF", "DOOR"]:
                    display_name = "%s %s" % [house_style, name]
                sprite.texture = _structure_display_texture(display_name, int(data.get("variant", 0)))
                sprite.rotation_degrees = 90.0 if vertical and not horizontal and name not in ["WALL", "INTERIOR WALL", "ROOF", "BRIDGE"] else 0.0
            if bool(data.get("window", false)):
                _refresh_shell_attachment(cell)
    _refresh_bridge_support(center)
    _refresh_bridge_support(center+Vector2i.UP)

func _refresh_bridge_support(cell: Vector2i) -> void:
    var data: Dictionary = built_structures.get(cell,{})
    if String(data.get("name","")) != "BRIDGE": return
    var deck := data.get("sprite") as Sprite2D
    if not is_instance_valid(deck): return
    deck.z_index = 10
    deck.rotation = 0.0
    var lower := deck.get_node_or_null("SourceBridgeSupport") as Sprite2D
    var below := cell+Vector2i.DOWN
    var visible_support := not built_structures.has(below) and _bridge_surface_at(below)
    if lower == null and visible_support:
        lower = Sprite2D.new()
        lower.name = "SourceBridgeSupport"
        lower.texture = preload("res://assets/source_0_8_11/tiles/bridge1_lower.png")
        lower.centered = false
        lower.position = Vector2(0,TILE)
        lower.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        deck.add_child(lower)
    if lower != null: lower.visible = visible_support

## The connected pieces of a house reached from `start`, as if the piece at
## `without` were already gone.
func _house_pieces_from(start: Vector2i, without: Vector2i) -> Array[Vector2i]:
    var pieces: Array[Vector2i] = []
    var seen: Dictionary = {}
    var queue: Array[Vector2i] = [start]
    var index := 0
    while index < queue.size():
        var current: Vector2i = queue[index]
        index += 1
        if seen.has(current) or current == without or not built_structures.has(current):
            continue
        if String(built_structures[current].get("name", "")) not in ["WALL", "ROOF", "DOOR", "WINDOW", "CHIMNEY"]:
            continue
        seen[current] = true
        pieces.append(current)
        for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            queue.append(current + direction)
    return pieces

## What is built inside a house on the tile behind one piece of its outside,
## on every floor. Cutting the piece cuts these with it, and nothing else:
## whatever stands elsewhere in the house stays, reachable or not, for when
## the way to it is rebuilt. A door is a piece like any other. Empty for a
## piece that is not part of a house, and for a house nobody has been inside.
func house_interior_cells_behind(cell: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if active_area_id != "OVERWORLD":
        return result
    var house: Array[Vector2i] = _house_pieces_from(cell, Vector2i(2147483647, 2147483647))
    if house.is_empty():
        return result
    var origin_y := -1
    var corner := Vector2i(2147483647, 2147483647)
    var far_corner := Vector2i(-2147483648, -2147483648)
    for piece in house:
        corner.x = mini(corner.x, piece.x)
        corner.y = mini(corner.y, piece.y)
        far_corner.x = maxi(far_corner.x, piece.x)
        far_corner.y = maxi(far_corner.y, piece.y)
        if origin_y < 0 and String(built_structures[piece].get("name", "")) == "DOOR" and built_house_origins.has(_cell_key(piece)):
            origin_y = int(built_house_origins[_cell_key(piece)])
    # The first cut into a house fixes where its room is measured from, so
    # that cutting away its corner does not move every later tile along by one.
    if origin_y >= 0 and not built_house_rooms_seen.has(origin_y):
        built_house_rooms_seen[origin_y] = [corner, far_corner - corner + Vector2i.ONE]
    # The room as it was last walked into decides which tile is behind the
    # piece. Joined pieces alone cannot: a piece cut off from the door belongs
    # to no house by that test, and a house whose corner has been cut away
    # measures from a different place than its room was drawn from.
    for seen_origin in built_house_rooms_seen:
        var seen: Array = built_house_rooms_seen[seen_origin]
        if Rect2i(seen[0], seen[1]).has_point(cell) and (origin_y < 0 or int(seen_origin) == origin_y):
            origin_y = int(seen_origin)
            corner = seen[0]
            break
    if origin_y < 0:
        return result
    var behind := cell - corner
    for raw_cell in built_structures:
        var built_cell := Vector2i(raw_cell)
        var offset := built_cell - Vector2i(map_w + 9, origin_y)
        if offset.x < 0 or offset.y != behind.y or offset.x % BUILT_HOUSE_FLOOR_STRIDE != behind.x:
            continue
        if not bool(built_structures[built_cell].get("generated_stair_pair", false)):
            result.append(built_cell)
    return result

func _remove_structure(cell: Vector2i, refund: bool) -> void:
    map_art_revision += 1
    if not built_structures.has(cell):
        return
    # As in the Java game, a piece cut out of the outside of a house takes its
    # tile of the room with it, and whatever was built on that tile.
    for inside_cell in house_interior_cells_behind(cell):
        if built_structures.has(inside_cell):
            _remove_structure(inside_cell, refund)
    if active_area_id == "HOUSE" and String(built_structures[cell].get("name","")) == "INTERIOR WALL":
        var key := _built_house_paint_key(cell)
        var hung := String(built_house_decorations.get(key,{}).get("name",""))
        # A wall on a floor tile takes its window or clock with it, and the
        # bare floor left behind is no longer somewhere to hang one.
        var on_floor := _built_house_floor_index_for_cell(cell) >= 0
        if _is_window_recipe(hung) or (on_floor and hung == "CLOCK"):
            built_house_decorations.erase(key)
            var window := built_house_decoration_sprites.get(cell) as Sprite2D
            if is_instance_valid(window): window.queue_free()
            built_house_decoration_sprites.erase(cell)
        if on_floor:
            built_house_paintable_walls.erase(cell)
    var data: Dictionary = built_structures[cell]
    var build_name := String(data.get("name", ""))
    if build_name == "STAIRS" and active_area_id == "HOUSE" and \
            _stair_belongs_to_active_house(data):
        var primary_cell: Vector2i = cell
        if bool(data.get("generated_stair_pair", false)):
            primary_cell = Vector2i(
                int(data.get("stair_primary_x", -2147483648)),
                int(data.get("stair_primary_y", -2147483648))
            )
            if not built_structures.has(primary_cell):
                primary_cell = cell
        # Remove the generated mirror first; it is not a separately paid build.
        var pair_cells: Array[Vector2i] = []
        for raw_pair in built_structures.keys():
            var pair_cell: Vector2i = Vector2i(raw_pair)
            var pair_data: Dictionary = built_structures[pair_cell]
            if bool(pair_data.get("generated_stair_pair", false)) and \
                    int(pair_data.get("stair_primary_x", -1)) == primary_cell.x and \
                    int(pair_data.get("stair_primary_y", -1)) == primary_cell.y:
                pair_cells.append(pair_cell)
        for pair_cell in pair_cells:
            var pair_data: Dictionary = built_structures[pair_cell]
            var pair_sprite: Sprite2D = pair_data.get("sprite") as Sprite2D
            if is_instance_valid(pair_sprite):
                pair_sprite.queue_free()
            built_structures.erase(pair_cell)
        if cell != primary_cell and built_structures.has(primary_cell):
            cell = primary_cell
            data = built_structures[cell]
            build_name = "STAIRS"
    var sprite: Sprite2D = data.get("sprite") as Sprite2D
    var collision: CollisionShape2D = data.get("collision") as CollisionShape2D
    if is_instance_valid(sprite):
        sprite.queue_free()
    if is_instance_valid(collision):
        collision.queue_free()

    if build_name == "COUCH":
        for occupied in _couch_footprint(String(data.get("recipe_name", "COUCH")), cell):
            if occupied == cell or not built_structures.has(occupied): blocked.erase(occupied)
    if bool(data.get("solid", false)):
        blocked.erase(cell)
    if bool(data.get("bridged_water", false)):
        if exact_world_mode:
            var stream := get_node_or_null("ExactCollisionStream") as SourceChunkCollisionStreamer
            if stream != null: stream.set_cell_passable(cell, false)
        else:
            var body := get_node_or_null("WorldCollision") as StaticBody2D
            if body != null:
                blocked[cell] = true
                ground_collisions[cell] = _add_block_collision(body, cell.x, cell.y)

    built_structures.erase(cell)
    # A restored shell can cover regenerated grass. Cutting that shell must
    # leave its previously cleared building ground usable for a new doorway.
    if build_name in ["WALL", "ROOF", "DOOR"] and active_area_id == "OVERWORLD" and exact_world_mode and exact_world != null:
        var underneath := exact_world.tile_at(cell)
        if underneath != null and underneath.is_grass:
            var cleared := _cuttable_grass_replacement(underneath, cell)
            underneath.set_names(String(cleared.base), String(cleared.upper))
            source_interior_mutations[_cell_key(cell)] = {
                "kind":"TILE_NAMES", "base":underneath.name, "upper":underneath.name_upper
            }
            _refresh_exact_streams()
    grass_exclusion.erase(cell)
    flower_cells.erase(cell)
    _refresh_connected_structures_around(cell)

    if refund:
        var refund_name := String(data.get("recipe_name", build_name))
        var recipe := CraftingData.build_recipe(refund_name)
        var cost: Dictionary = recipe.get("cost", {})
        build_refund_requested.emit(cost.duplicate(true))

func remove_structure_with_field_move(cell: Vector2i, move: String) -> bool:
    if not built_structures.has(cell):
        return false
    var build_name := String((built_structures[cell] as Dictionary).get("name", ""))
    if move == "CUT" and build_name in ["GRAVE", "STATUE"]:
        return false
    if move == "SMASH" and build_name not in ["GRAVE", "STATUE"]:
        return false
    _remove_structure(cell, true)
    if build_name == "GRAVE" and rng.randi_range(0, 8) == 0:
        var spooky_pool := ["gastly", "misdreavus", "duskull", "shuppet"]
        var spooky := String(spooky_pool[rng.randi_range(0, spooky_pool.size() - 1)])
        world_message.emit("Something rose from the shattered GRAVE!")
        encounter_requested.emit(spooky, 22)
    return true

func _teleport_to_other_beacon(source: Vector2i) -> void:
    for key in built_structures.keys():
        var cell: Vector2i = key
        if cell == source:
            continue
        var data: Dictionary = built_structures[cell]
        if String(data.get("name", "")) == "BEACON":
            player.position = _cell_center(cell + Vector2i(0, 1))
            _sync_follower_to_player()
            world_message.emit("The WARP TILE bends space around you.")
            return
    world_message.emit("There is no other WARP TILE to travel to.")

func _is_cell_indoors(cell: Vector2i) -> bool:
    if active_area_id != "OVERWORLD":
        return true
    var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
    for direction in directions:
        var boundary_found := false
        for step in range(1, 13):
            var test: Vector2i = cell + Vector2i(direction) * step
            if not _in_bounds(test):
                break
            if built_structures.has(test):
                var data: Dictionary = built_structures[test]
                var name := String(data.get("name", ""))
                if name in ["WALL", "INTERIOR WALL", "DOOR"]:
                    boundary_found = true
                break
        if not boundary_found:
            return false
    return true

func deploy_pokemon(pokemon_data: Dictionary) -> bool:
    var cell := _player_cell() + _facing_cell()
    var indoors := active_area_id == "HOUSE"
    if (not _house_pokemon_cell_allowed(cell) if indoors else not _pokemon_drop_ground_allowed(pokemon_data, cell)):
        world_message.emit("There is no room to leave that Pokemon here.")
        return false
    if (
            deployed_pokemon.has(cell)
            or built_structures.has(cell)
            or (not indoors and landmarks.has(cell))
            or (not indoors and resource_objects.has(cell))
            or wild_eggs.has(cell)
            or (not indoors and _wild_id_at_cell(cell) >= 0)
            or cell == follower_cell
            or cell == field_helper_cell
        ):
        return false

    var species := String(pokemon_data.get("species", "")).to_lower()
    if bool(pokemon_data.get("is_egg", false)):
        var egg := pokemon_data.duplicate(true)
        egg["dropped_party_egg"] = true
        if indoors:
            egg["house_door"] = _cell_key(active_built_house_door)
            egg["house_floor"] = _built_house_floor_index_for_cell(cell)
        _add_wild_egg(species, cell, egg)
        return wild_eggs.has(cell)
    var pokemon_texture: Texture2D = PokemonData.record_texture(pokemon_data, "overworld")
    if pokemon_texture == null:
        pokemon_texture = FARM_POKEMON_TEXTURES.get(species) as Texture2D
    if pokemon_texture == null:
        world_message.emit("That Pokemon's overworld sprite is not available yet.")
        return false

    var sprite := Sprite2D.new()
    sprite.texture = pokemon_texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = _cell_center(cell)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    _configure_overworld_sprite(sprite)
    var layer := _house_pokemon_layer() if indoors else get_node_or_null("LandmarkLayer") as Node2D
    if layer == null:
        return false
    layer.add_child(sprite)
    preload("res://scripts/shiny_sparkles.gd").attach(sprite, pokemon_data)

    var stored := PokemonEcology.ensure_record(
        pokemon_data, rng, "owned:%d" % next_deployed_id
    )
    next_deployed_id += 1
    if indoors:
        stored["house_door"] = _cell_key(active_built_house_door)
        stored["house_floor"] = _built_house_floor_index_for_cell(cell)
    stored["x"] = cell.x
    stored["y"] = cell.y
    stored["cell"] = cell
    stored["move_timer"] = _wild_move_delay(species)
    stored["anim_phase"] = 0
    stored["behavior"] = PokemonData.info(species).get("overworld_behavior", {})
    stored["sprite"] = sprite
    stored = _refresh_record_habitat(stored, cell)
    deployed_pokemon[cell] = stored
    return true

func _recall_deployed_pokemon(cell: Vector2i, data: Dictionary) -> void:
    # Capacity is checked before items, ownership, sprites or world records change.
    var main := get_parent()
    if main == null or not main.has_method("_can_receive_overworld_pokemon") or not main._can_receive_overworld_pokemon():
        world_message.emit("Your party and storage are full.")
        return
    var species := String(data.get("species", "")).to_lower()
    var carried_item := String(data.get("held_item", ""))
    if not carried_item.is_empty():
        material_collected.emit(carried_item, 1)
    var recalled := data.duplicate(true)
    if not carried_item.is_empty():
        recalled["harvest_progress"] = 0.0
    for runtime_key in [
            "x", "y", "cell", "ready_at", "ready_at_elapsed",
            "last_harvest_day", "sprite", "move_timer", "anim_phase",
            "behavior", "ecology_id", "mate_id", "friend_id",
            "in_habitat", "in_shelter", "nearby_pokemon",
            "held_item", "can_lay_egg",
            "missing_habitats", "manured", "house_door", "house_floor"
        ]:
        recalled.erase(runtime_key)
    var sprite: Sprite2D = data.get("sprite") as Sprite2D
    if is_instance_valid(sprite):
        sprite.queue_free()
    deployed_pokemon.erase(cell)
    deployed_recall_candidate = Vector2i(-2147483648, -2147483648)
    deployed_recall_candidate_msec = 0
    pokemon_recalled.emit(recalled)

func _deployed_recall_hint(message: String) -> void:
    if deployed_pokemon.has(deployed_recall_candidate):
        var record: Dictionary = deployed_pokemon[deployed_recall_candidate]
        deployed_recall_requested.emit(deployed_recall_candidate, String(record.get("species", "")), message)

func _interact_deployed_pokemon(cell: Vector2i) -> void:
    if not deployed_pokemon.has(cell):
        return
    var data: Dictionary = deployed_pokemon[cell]
    var species := String(data.get("species", "")).to_lower()
    var now := preload("res://scripts/game_clock.gd").ticks_msec()

    deployed_recall_candidate = cell
    deployed_recall_candidate_msec = now

    var held_item := String(data.get("held_item", ""))
    if not held_item.is_empty():
        var amount := rng.randi_range(3,5) if held_item=="ANCIENTPOWDER" and preload("res://scripts/rare_biome_legendaries.gd").HABITATS.has(species) else 1
        material_collected.emit(held_item, amount)
        data["held_item"] = ""
        data["harvest_progress"] = 0.0
        deployed_pokemon[cell] = data
        _show_ecology_emote(data.get("sprite") as Sprite2D,
            "uncomfortable" if not bool(data.get("in_habitat", false)) else (
            "heart" if not String(data.get("mate_id", "")).is_empty() else "happy"))
        world_message.emit("%s produced %s!" % [PokemonState.display_name(data).to_upper(), held_item])
        return

    if not bool(data.get("in_habitat", false)):
        var missing: Array = data.get("missing_habitats", [])
        var need := "the right habitat" if missing.is_empty() else String(missing[0]).replace("|", " or ")
        _deployed_recall_hint("%s is uncomfortable. It needs %s nearby." % [
            PokemonState.display_name(data).to_upper(), need.to_upper()])
        _show_ecology_emote(data.get("sprite") as Sprite2D, "uncomfortable")
        return
    if not String(data.get("mate_id", "")).is_empty():
        _deployed_recall_hint("%s is happy with its mate." % PokemonState.display_name(data).to_upper())
        _show_ecology_emote(data.get("sprite") as Sprite2D, "heart")
        return
    if not String(data.get("friend_id", "")).is_empty():
        _deployed_recall_hint("%s is enjoying time with a friend." % PokemonState.display_name(data).to_upper())
        _show_ecology_emote(data.get("sprite") as Sprite2D, "happy")
        return
    if bool(data.get("in_shelter", false)):
        _deployed_recall_hint("%s is happy and sheltered here." % PokemonState.display_name(data).to_upper())
    else:
        _deployed_recall_hint("%s looks happy in this habitat." % PokemonState.display_name(data).to_upper())
    _show_ecology_emote(data.get("sprite") as Sprite2D, "happy")

func _habitat_satisfied(cell: Vector2i, habitat: String) -> bool:
    var group := habitat.to_lower()
    for y in range(cell.y - PokemonEcology.HABITAT_RADIUS, cell.y + PokemonEcology.HABITAT_RADIUS + 1):
        for x in range(cell.x - PokemonEcology.HABITAT_RADIUS, cell.x + PokemonEcology.HABITAT_RADIUS + 1):
            var names := _ecology_names_at(Vector2i(x, y))
            for raw_option in group.split("|"):
                if String(raw_option) in names:
                    return true
    return false

func _refresh_record_habitat(
        data: Dictionary, cell: Vector2i, ecology_name_cache: Dictionary = {}
    ) -> Dictionary:
    var species := String(data.get("species", ""))
    # Build the seven-by-seven habitat window once. The old implementation
    # rebuilt the same strings once per required type and then again for
    # shelter, multiplying work across hundreds of exact-world Pokemon.
    var nearby_names: Array[String] = []
    var fence_count := 0
    var roof_count := 0
    for y in range(cell.y - PokemonEcology.HABITAT_RADIUS, cell.y + PokemonEcology.HABITAT_RADIUS + 1):
        for x in range(cell.x - PokemonEcology.HABITAT_RADIUS, cell.x + PokemonEcology.HABITAT_RADIUS + 1):
            var habitat_cell := Vector2i(x, y)
            var names := ""
            if ecology_name_cache.has(habitat_cell):
                names = String(ecology_name_cache[habitat_cell])
            else:
                names = _ecology_names_at(habitat_cell)
                ecology_name_cache[habitat_cell] = names
            nearby_names.append(names)
            if "fence" in names:
                fence_count += 1
            elif "roof" in names:
                roof_count += 1
    var missing: Array[String] = []
    for raw_group in PokemonEcology.habitat_groups(species):
        var group := String(raw_group)
        var satisfied := false
        for names in nearby_names:
            for raw_option in group.to_lower().split("|"):
                if String(raw_option) in names:
                    satisfied = true
                    break
            if satisfied:
                break
        if not satisfied:
            missing.append(group)
    if PokemonEcology.requires_night(species) and not _is_night_time():
        missing.append("night")
    data["missing_habitats"] = missing
    data["in_habitat"] = missing.is_empty()
    data["in_shelter"] = roof_count >= 3 and fence_count >= 2
    return data

func _is_night_time() -> bool:
    var day_fraction := fmod(world_elapsed_seconds, WORLD_DAY_SECONDS) / WORLD_DAY_SECONDS
    return day_fraction >= NIGHT_START_FRACTION

func source_time_of_day() -> String:
    return "night" if _is_night_time() else "day"

func _maybe_spawn_night_ghost(cell: Vector2i) -> bool:
    if not _is_night_time():
        return false
    if _flash_is_active() or _ghost_warded_at(cell):
        return false
    var biome := biome_at(cell)
    if biome not in ["DEEP_FOREST", "GRAVEYARD", "WOODED_LAKE"]:
        return false
    if ghost_step_countdown < 0:
        ghost_step_countdown = rng.randi_range(500, 999)
    ghost_step_countdown -= 1
    if ghost_step_countdown > 0:
        return false
    ghost_step_countdown = rng.randi_range(1000, 2999)
    var ghost_species := String(SourceEventData.GHOST_SPECIES[
        rng.randi_range(0, SourceEventData.GHOST_SPECIES.size() - 1)
    ])
    _request_event_battle("ghost", cell, {
        "id": "ghost_%d" % int(world_elapsed_seconds),
        "party": [{"species": ghost_species, "level": 21}],
        "requires_silph_scope": true,
        "clear_on_capture": false,
        "clear_on_defeat": false
    })
    return true

func _ghost_warded_at(cell: Vector2i) -> bool:
    for raw_cell in built_structures.keys():
        var structure_cell := Vector2i(raw_cell)
        if Vector2(structure_cell - cell).length_squared() > 64.0:
            continue
        var structure := built_structures[raw_cell] as Dictionary
        if String(structure.get("name", "")) == "CAMPFIRE" or bool(structure.get("torch", false)) or (
                String(structure.get("name", "")) == "TORCH"
                and bool(structure.get("lit", true))
            ):
            return true
    return false

func respawn_after_whiteout() -> void:
    if not respawn_house.is_empty():
        var door := Vector2i(int(respawn_house.x), int(respawn_house.y))
        var state := _built_house_state(door)
        if bool(state.get("ready", false)):
            if source_area_layers.has(active_area_id):
                (source_area_layers[active_area_id] as CanvasItem).hide()
            _prepare_built_house_interior(door, state)
            _enter_source_area_now("HOUSE", respawn_cell)
            var floor_index := clampi(int(respawn_house.floor), 0, built_house_floor_capacity - 1)
            _set_active_built_house_floor(floor_index)
            var target := _built_house_floor_origin(floor_index) + Vector2i(int(respawn_house.local_x), int(respawn_house.local_y))
            if _house_sleep_cell_clear(target): player.position = _cell_center(target)
            last_player_cell = _player_cell()
            _sync_follower_to_player()
            return
    # Whiteouts always return to the exterior overworld. Hide whatever source
    # interior was active and restore exterior streaming before moving the player.
    var old_area: String = active_area_id
    if source_area_layers.has(old_area):
        (source_area_layers[old_area] as CanvasItem).visible = false
    active_area_id = "OVERWORLD"
    _set_exact_overworld_streaming(true)
    var target := respawn_cell if respawn_cell.x > -2147483648 else spawn_cell
    player.position = _cell_center(target)
    last_player_cell = target
    _sync_follower_to_player()
    _discover_around(target, DISCOVERY_RADIUS)
    _configure_camera()
    _refresh_exact_tile_streams()

func _ecology_names_at(cell: Vector2i) -> String:
    if active_area_id == "HOUSE" and built_house_interior_cells.has(cell):
        return "house_floor " + String((built_structures.get(cell, {}) as Dictionary).get("name", "")).to_lower()
    if not _in_bounds(cell):
        return ""
    var names: Array[String] = []
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        if tile != null:
            names.append(tile.name.to_lower())
            names.append(tile.name_upper.to_lower())
    elif source_tiles.has(cell):
        var source_data: Dictionary = source_tiles.get(cell, {})
        names.append(String(source_data.get("base", source_data.get("name", ""))).to_lower())
        names.append(String(source_data.get("upper", source_data.get("name_upper", ""))).to_lower())
        names.append(String(source_data.get("biome", "")).to_lower())
    if not exact_world_mode:
        if terrain_kind_at(cell) == 0:
            names.append("water")
        elif terrain_kind_at(cell) == 1:
            names.append_array(["sand", "desert"])
        else:
            names.append("green")
        names.append(biome_at(cell).to_lower())
    if _is_tall_grass_cell(cell):
        names.append("grass")
    if flower_cells.has(cell):
        names.append("flower")
    if resource_objects.has(cell):
        names.append(String((resource_objects[cell] as Dictionary).get("type", "")).to_lower())
    if built_structures.has(cell):
        var built_name := String((built_structures[cell] as Dictionary).get("name", "")).to_lower()
        names.append(built_name)
        if built_name == "flowers":
            names.append("flower")
        elif built_name == "plant":
            names.append("potted")
        elif built_name == "grave":
            names.append("gravestone")
    if landmarks.has(cell):
        names.append(String((landmarks[cell] as Dictionary).get("type", "")).to_lower())
    if bool(terrain_changes.get("ice:%s" % _cell_key(cell), false)):
        names.append("snow")
    return " ".join(names)

func _update_ecology(delta: float) -> void:
    ecology_accumulator += delta
    if ecology_accumulator < PokemonEcology.HABITAT_CHECK_SECONDS:
        return
    var ecology_delta := ecology_accumulator
    ecology_accumulator = fmod(
        ecology_accumulator, PokemonEcology.HABITAT_CHECK_SECONDS
    )
    _refresh_ecology_relationships()
    _release_old_eggs()

    for raw_cell in deployed_pokemon.keys():
        var cell: Vector2i = raw_cell
        if not deployed_pokemon.has(cell):
            continue
        var data: Dictionary = deployed_pokemon[cell]
        if (
                bool(data.get("in_habitat", false))
                and String(data.get("held_item", "")).is_empty()
            ):
            var shelter_multiplier := 2.0 if bool(data.get("in_shelter", false)) else 1.0
            data["harvest_progress"] = float(data.get("harvest_progress", 0.0)) + ecology_delta * shelter_multiplier
            var harvest_max := PokemonEcology.harvest_seconds(String(data.get("species", "")))
            if float(data["harvest_progress"]) >= harvest_max:
                var choices := PokemonEcology.harvest_items(String(data.get("species", "")))
                if not choices.is_empty():
                    data["held_item"] = choices[rng.randi_range(0, choices.size() - 1)]
        data = _advance_breeding_clock(data, ecology_delta)
        deployed_pokemon[cell] = data

    var active_center := _player_cell()
    for raw_id in wild_pokemon.keys():
        if not wild_pokemon.has(raw_id):
            continue
        var data: Dictionary = wild_pokemon[raw_id]
        var wild_cell: Vector2i = data.get("cell", Vector2i.ZERO)
        if (
                not bool(data.get("burrowed", false))
                and _wild_ecology_is_active(wild_cell, active_center)
            ):
            data = _advance_breeding_clock(data, ecology_delta, true)
        wild_pokemon[raw_id] = data

func _advance_breeding_clock(
        data: Dictionary, delta: float, allow_wild_crowding: bool = false
    ) -> Dictionary:
    var population_ok := allow_wild_crowding or int(data.get("nearby_pokemon", 0)) < 3
    if (
            bool(data.get("can_lay_egg", false))
            and bool(data.get("in_habitat", false))
            and bool(data.get("mate_nearby", false))
            and population_ok
            and float(data.get("lay_egg_seconds", PokemonEcology.LAY_EGG_SECONDS)) > 0.0
        ):
        data["lay_egg_seconds"] = maxf(
            0.0,
            float(data.get("lay_egg_seconds", PokemonEcology.LAY_EGG_SECONDS)) - delta
        )
    if (
            not String(data.get("friend_id", "")).is_empty()
            and float(data.get("friend_seconds", PokemonEcology.FRIEND_SECONDS)) > 0.0
        ):
        data["friend_seconds"] = maxf(
            0.0,
            float(data.get("friend_seconds", PokemonEcology.FRIEND_SECONDS)) - delta
        )
    return data

func _refresh_ecology_relationships() -> void:
    var records: Array[Dictionary] = []
    # Habitat windows heavily overlap. Cache each cell's ecology string for this
    # refresh so the 1.6-second relationship pass does not repeatedly resolve
    # the same tile/biome dozens of times and hitch while the player is running.
    var ecology_name_cache: Dictionary = {}
    for raw_cell in deployed_pokemon.keys():
        var cell: Vector2i = raw_cell
        records.append({
            "kind": "deployed", "key": cell, "cell": cell,
            "data": deployed_pokemon[cell]
        })
    var active_center := _player_cell()
    for raw_id in wild_pokemon.keys():
        var wild_data: Dictionary = wild_pokemon[raw_id]
        if bool(wild_data.get("burrowed", false)):
            continue
        var wild_cell: Vector2i = wild_data.get("cell", Vector2i.ZERO)
        if not _wild_ecology_is_active(wild_cell, active_center):
            continue
        records.append({
            "kind": "wild", "key": raw_id,
            "cell": wild_cell,
            "data": wild_data
        })

    var index_by_id: Dictionary = {}
    var cell_indices: Dictionary = {}
    for index in range(records.size()):
        var descriptor: Dictionary = records[index]
        var data: Dictionary = descriptor["data"]
        data["previous_mate_id"] = String(data.get("mate_id", ""))
        data["mate_id"] = ""
        data["friend_id"] = ""
        data["can_lay_egg"] = false
        data["mate_nearby"] = false
        data["nearby_pokemon"] = 0
        data = _refresh_record_habitat(
            data, descriptor["cell"], ecology_name_cache)
        descriptor["data"] = data
        records[index] = descriptor
        var ecology_id := String(data.get("ecology_id", ""))
        if not ecology_id.is_empty():
            index_by_id[ecology_id] = index
        var record_cell: Vector2i = descriptor["cell"]
        if not cell_indices.has(record_cell):
            cell_indices[record_cell] = []
        (cell_indices[record_cell] as Array).append(index)

    # Keep an established compatible pair bonded while it wanders a few tiles
    # apart. The old pass erased both IDs every refresh, so natural-looking
    # separation accidentally dissolved the pair before it could return.
    for index in range(records.size()):
        var first_descriptor: Dictionary = records[index]
        var first: Dictionary = first_descriptor["data"]
        var former_mate_id := String(first.get("previous_mate_id", ""))
        if former_mate_id.is_empty() or not index_by_id.has(former_mate_id):
            continue
        var mate_index := int(index_by_id[former_mate_id])
        if mate_index <= index:
            continue
        var second_descriptor: Dictionary = records[mate_index]
        var second: Dictionary = second_descriptor["data"]
        if String(second.get("previous_mate_id", "")) != \
                String(first.get("ecology_id", "")):
            continue
        var first_cell: Vector2i = first_descriptor["cell"]
        var second_cell: Vector2i = second_descriptor["cell"]
        var separation := maxi(
            absi(first_cell.x - second_cell.x),
            absi(first_cell.y - second_cell.y))
        if separation > MATE_BOND_RADIUS or not PokemonEcology.can_mate(first, second):
            continue
        first["mate_id"] = String(second.get("ecology_id", ""))
        second["mate_id"] = String(first.get("ecology_id", ""))
        first_descriptor["data"] = first
        second_descriptor["data"] = second
        records[index] = first_descriptor
        records[mate_index] = second_descriptor
    var nearby_indices: Array = []
    for index in range(records.size()):
        var descriptor: Dictionary = records[index]
        var center: Vector2i = descriptor["cell"]
        var nearby := 0
        var candidates: Array[int] = []
        for y in range(center.y - PokemonEcology.HABITAT_RADIUS, center.y + PokemonEcology.HABITAT_RADIUS + 1):
            for x in range(center.x - PokemonEcology.HABITAT_RADIUS, center.x + PokemonEcology.HABITAT_RADIUS + 1):
                var test := Vector2i(x, y)
                if cell_indices.has(test):
                    for raw_candidate_index in cell_indices[test]:
                        var candidate_index := int(raw_candidate_index)
                        if candidate_index != index:
                            nearby += 1
                            candidates.append(candidate_index)
                if wild_eggs.has(test):
                    nearby += 1
        # Preserve the former record-order choice when more than one mate or
        # friend is nearby while avoiding a scan of the whole world.
        candidates.sort()
        nearby_indices.append(candidates)
        var data: Dictionary = descriptor["data"]
        data["nearby_pokemon"] = nearby
        descriptor["data"] = data
        records[index] = descriptor

    for index in range(records.size()):
        var first_descriptor: Dictionary = records[index]
        var first: Dictionary = first_descriptor["data"]
        if not String(first.get("mate_id", "")).is_empty():
            continue
        for raw_candidate_index in nearby_indices[index]:
            var candidate_index := int(raw_candidate_index)
            if candidate_index <= index:
                continue
            var second_descriptor: Dictionary = records[candidate_index]
            var second: Dictionary = second_descriptor["data"]
            if not String(second.get("mate_id", "")).is_empty():
                continue
            if not PokemonEcology.can_mate(first, second):
                continue
            first["mate_id"] = String(second.get("ecology_id", ""))
            second["mate_id"] = String(first.get("ecology_id", ""))
            first["friend_id"] = ""
            second["friend_id"] = ""
            first_descriptor["data"] = first
            second_descriptor["data"] = second
            records[index] = first_descriptor
            records[candidate_index] = second_descriptor
            break

    for index in range(records.size()):
        var first_descriptor: Dictionary = records[index]
        var first: Dictionary = first_descriptor["data"]
        if (
                not String(first.get("mate_id", "")).is_empty()
                or not String(first.get("friend_id", "")).is_empty()
            ):
            continue
        for raw_candidate_index in nearby_indices[index]:
            var candidate_index := int(raw_candidate_index)
            if candidate_index <= index:
                continue
            var second_descriptor: Dictionary = records[candidate_index]
            var second: Dictionary = second_descriptor["data"]
            if (
                    not String(second.get("mate_id", "")).is_empty()
                    or not String(second.get("friend_id", "")).is_empty()
                    or not PokemonEcology.can_be_friends(first, second)
                ):
                continue
            first["friend_id"] = String(second.get("ecology_id", ""))
            second["friend_id"] = String(first.get("ecology_id", ""))
            first_descriptor["data"] = first
            second_descriptor["data"] = second
            records[index] = first_descriptor
            records[candidate_index] = second_descriptor
            break

    for index in range(records.size()):
        var descriptor: Dictionary = records[index]
        var data: Dictionary = descriptor["data"]
        var mate_id := String(data.get("mate_id", ""))
        if not mate_id.is_empty() and index_by_id.has(mate_id):
            var mate_descriptor: Dictionary = records[int(index_by_id[mate_id])]
            var mate: Dictionary = mate_descriptor["data"]
            var groups: Array = data.get("egg_groups", [])
            data["can_lay_egg"] = (
                String(data.get("gender", "")) == "female"
                or (
                    groups.has("EGG_DITTO")
                    and String(mate.get("gender", "")) == "male"
                )
            )
            var own_cell: Vector2i = descriptor["cell"]
            var mate_cell: Vector2i = mate_descriptor["cell"]
            data["mate_nearby"] = maxi(
                absi(own_cell.x - mate_cell.x),
                absi(own_cell.y - mate_cell.y)
            ) <= PokemonEcology.HABITAT_RADIUS
        if (
                not mate_id.is_empty()
                and mate_id != String(data.get("previous_mate_id", ""))
            ):
            _show_ecology_emote(data.get("sprite") as Sprite2D, "heart")
        data.erase("previous_mate_id")
        descriptor["data"] = data
        records[index] = descriptor
        _store_ecology_descriptor(descriptor)

func _wild_ecology_is_active(
        cell: Vector2i, active_center: Vector2i
    ) -> bool:
    if (
            absi(cell.x - active_center.x) <= ECOLOGY_ACTIVE_RADIUS
            and absi(cell.y - active_center.y) <= ECOLOGY_ACTIVE_RADIUS
        ):
        return true
    # Player-owned habitat populations keep their nearby wild interactions
    # even while the player is elsewhere; unrelated offscreen wild Pokemon do
    # not need per-frame behavior or relationship scans.
    for raw_cell in deployed_pokemon.keys():
        var deployed_cell := Vector2i(raw_cell)
        if (
                absi(cell.x - deployed_cell.x) <= PokemonEcology.HABITAT_RADIUS
                and absi(cell.y - deployed_cell.y) <= PokemonEcology.HABITAT_RADIUS
            ):
            return true
    return false

func _store_ecology_descriptor(descriptor: Dictionary) -> void:
    var data: Dictionary = descriptor["data"]
    if String(descriptor.get("kind", "")) == "deployed":
        var cell: Vector2i = descriptor["key"]
        if deployed_pokemon.has(cell):
            deployed_pokemon[cell] = data
    else:
        var wild_id = descriptor["key"]
        if wild_pokemon.has(wild_id):
            wild_pokemon[wild_id] = data

func _update_deployed_pokemon(delta: float) -> void:
    var directions: Array[Vector2i] = [
        Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
        Vector2i.UP, Vector2i.DOWN
    ]
    for raw_cell in deployed_pokemon.keys():
        var old_cell: Vector2i = raw_cell
        if not deployed_pokemon.has(old_cell):
            continue
        var data: Dictionary = deployed_pokemon[old_cell]
        data["move_timer"] = float(data.get("move_timer", 0.0)) - delta
        if float(data["move_timer"]) > 0.0:
            deployed_pokemon[old_cell] = data
            continue
        data["move_timer"] = _wild_move_delay(String(data.get("species", "")))
        data = _try_create_parent_egg(data, old_cell)
        # A wall or roof can land on a Pokemon's tile when two players act at
        # the same moment. It is then shut inside the piece: hidden for some
        # players, standing on the roof for others, and out of reach. Step it
        # out onto the nearest free ground.
        if not data.has("house_door") and bool(built_structures.get(old_cell, {}).get("solid", false)):
            var exit_cell := _resolve_egg_ground_cell(old_cell)
            if exit_cell.x > -2147483648 and exit_cell != old_cell:
                deployed_pokemon.erase(old_cell)
                data["cell"] = exit_cell
                data["x"] = exit_cell.x
                data["y"] = exit_cell.y
                var trapped: Sprite2D = data.get("sprite") as Sprite2D
                if is_instance_valid(trapped):
                    trapped.position = _cell_center(exit_cell)
                    trapped.z_index = _depth_z(exit_cell)
                deployed_pokemon[exit_cell] = data
                continue
        var behavior: Dictionary = data.get("behavior", {})
        if bool(behavior.get("stationary", false)):
            deployed_pokemon[old_cell] = data
            continue
        if not String(data.get("held_item", "")).is_empty():
            var dance_sprite: Sprite2D = data.get("sprite") as Sprite2D
            data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
            if is_instance_valid(dance_sprite):
                _set_overworld_motion_frame(
                    dance_sprite, Vector2.DOWN, int(data["anim_phase"])
                )
            deployed_pokemon[old_cell] = data
            continue

        var direction := directions[rng.randi_range(0, directions.size() - 1)]
        var friend_id := String(data.get("friend_id", ""))
        var friend_reunion := (
            not friend_id.is_empty()
            and float(data.get("friend_seconds", PokemonEcology.FRIEND_SECONDS)) <= 0.0
        )
        var companion_id := friend_id
        if friend_reunion:
            data["friend_seconds"] = PokemonEcology.FRIEND_SECONDS
            _show_friend_reunion(data, friend_id)
        elif companion_id.is_empty() or rng.randf() < 0.18:
            companion_id = String(data.get("mate_id", companion_id))
        if not companion_id.is_empty() and (friend_reunion or rng.randf() < 0.20):
            var companion_cell := _ecology_cell_by_id(companion_id)
            if companion_cell.x > -2147483648:
                direction = _cardinal_direction(companion_cell - old_cell, false)
        direction = _paired_wander_direction(data, old_cell, direction)
        var target := old_cell + direction
        if (
                direction == Vector2i.ZERO
                or not _pokemon_can_move_between(String(data.get("species", "")), old_cell, target)
                or target == _player_cell()
                or target == follower_cell
                or target == field_helper_cell
                or deployed_pokemon.has(target)
                or _wild_id_at_cell(target) >= 0
                or wild_eggs.has(target)
            ):
            deployed_pokemon[old_cell] = data
            continue

        deployed_pokemon.erase(old_cell)
        data["cell"] = target
        data["x"] = target.x
        data["y"] = target.y
        data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            _set_overworld_motion_frame(sprite, direction, int(data["anim_phase"]))
            sprite.z_index = _depth_z(target)
            create_tween().tween_property(
                sprite, "position", _cell_center(target), 0.20
            ).set_trans(Tween.TRANS_LINEAR)
        deployed_pokemon[target] = data

func _egg_ground_cell_is_valid(cell: Vector2i, ignored_wild_id: int = -1) -> bool:
    if not _in_bounds(cell):
        return false
    if (
            wild_eggs.has(cell) or deployed_pokemon.has(cell)
            or _wild_id_at_cell(cell, ignored_wild_id) >= 0
            or built_structures.has(cell) or landmarks.has(cell)
            or resource_objects.has(cell) or blocked.has(cell)
        ):
        return false
    # Reject the full visible footprint of exact resources, especially the
    # 48x48 Savanna tree whose authored anchor is only one tile.
    if _exact_resource_anchor(cell).x > -2147483648:
        return false
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null or tile.is_water or tile.is_solid or tile.is_ledge:
            return false
    elif terrain_kind_at(cell) == 0:
        return false
    return true

func _resolve_egg_ground_cell(preferred: Vector2i, ignored_wild_id: int = -1) -> Vector2i:
    # Search the complete source habitat radius, nearest ring first, while
    # consuming no RNG. The old short 13-cell list could fail in a healthy
    # wandering colony even when plenty of valid habitat ground was nearby.
    # Full deterministic rings keep both parents alive and moving and make the
    # authored breeding clock reliably produce a visible egg when room exists.
    if _egg_ground_cell_is_valid(preferred, ignored_wild_id):
        return preferred
    var preferred_offsets: Array[Vector2i] = [
        Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP
    ]
    for offset in preferred_offsets:
        var nearby := preferred + offset
        if _egg_ground_cell_is_valid(nearby, ignored_wild_id):
            return nearby
    for radius in range(1, PokemonEcology.HABITAT_RADIUS + 1):
        for y_offset in range(-radius, radius + 1):
            for x_offset in range(-radius, radius + 1):
                if maxi(absi(x_offset), absi(y_offset)) != radius:
                    continue
                var offset := Vector2i(x_offset, y_offset)
                if preferred_offsets.has(offset):
                    continue
                var candidate := preferred + offset
                if _egg_ground_cell_is_valid(candidate, ignored_wild_id):
                    return candidate
    return Vector2i(-2147483648, -2147483648)

func _try_create_parent_egg(
        data: Dictionary, egg_cell: Vector2i, ignored_wild_id: int = -1
    ) -> Dictionary:
    if (
            float(data.get("lay_egg_seconds", PokemonEcology.LAY_EGG_SECONDS)) > 0.0
            or not bool(data.get("can_lay_egg", false))
        ):
        return data
    var partner := _ecology_record_by_id(String(data.get("mate_id", "")))
    if partner.is_empty():
        return data
    var partner_cell := _ecology_cell_by_id(String(data.get("mate_id", "")))
    if (
            partner_cell.x <= -2147483648
            or maxi(absi(partner_cell.x - egg_cell.x), absi(partner_cell.y - egg_cell.y)) > \
                PokemonEcology.HABITAT_RADIUS
            or not bool(data.get("in_habitat", false))
            or not bool(partner.get("in_habitat", false))
            or not PokemonEcology.can_mate(data, partner)
        ):
        return data
    # Nothing hatches or removes a habitat egg for days (see _release_old_eggs),
    # so an undisturbed couple would otherwise bury its habitat in eggs. Wait a
    # full cycle before checking again rather than holding the pair together.
    if _couple_egg_count(
            String(data.get("ecology_id", "")), String(partner.get("ecology_id", ""))
        ) >= PokemonEcology.MAX_EGGS_PER_COUPLE:
        data["lay_egg_seconds"] = PokemonEcology.LAY_EGG_SECONDS
        return data
    # The parent occupies egg_cell by definition. Do not reject its own tile;
    # resolve the egg onto the nearest free authored ground cell instead. This
    # fixes the deployed-parent path that could never lay and keeps both parents
    # alive/free to continue their normal paired wandering.
    var resolved_cell := _resolve_egg_ground_cell(egg_cell, ignored_wild_id)
    if resolved_cell.x <= -2147483648:
        return data
    var egg := PokemonEcology.egg_record(data, partner, rng)
    _add_wild_egg_record(egg, resolved_cell, ignored_wild_id)
    data["lay_egg_seconds"] = PokemonEcology.LAY_EGG_SECONDS
    _show_ecology_emote(data.get("sprite") as Sprite2D, "heart")
    var partner_sprite: Sprite2D = partner.get("sprite") as Sprite2D
    _show_ecology_emote(partner_sprite, "heart")
    return data

func _may_release_egg(_egg: Dictionary) -> bool:
    return true

func _release_old_eggs() -> void:
    # A habitat egg left alone is released into the wild: it simply leaves the
    # overworld. Eggs a player set down are theirs and stay. An egg from before
    # this rule starts its count when it is first seen.
    var lifetime := PokemonEcology.EGG_RELEASE_DAYS * WORLD_DAY_SECONDS
    for raw_cell in wild_eggs.keys():
        var egg: Dictionary = wild_eggs[raw_cell]
        if bool(egg.get("dropped_party_egg", false)) or not _may_release_egg(egg):
            continue
        if not egg.has("laid_at") or float(egg["laid_at"]) > world_elapsed_seconds:
            egg["laid_at"] = world_elapsed_seconds
            continue
        if world_elapsed_seconds - float(egg["laid_at"]) < lifetime:
            continue
        var egg_sprite: Sprite2D = egg.get("sprite") as Sprite2D
        if is_instance_valid(egg_sprite):
            egg_sprite.queue_free()
        wild_eggs.erase(raw_cell)

func _couple_egg_count(first_id: String, second_id: String) -> int:
    if first_id.is_empty() or second_id.is_empty():
        return 0
    var count := 0
    for egg in wild_eggs.values():
        if bool((egg as Dictionary).get("dropped_party_egg", false)):
            continue
        var parents = (egg as Dictionary).get("parent_ids", [])
        if parents is Array and parents.has(first_id) and parents.has(second_id):
            count += 1
    return count

func _ecology_record_by_id(ecology_id: String) -> Dictionary:
    if ecology_id.is_empty():
        return {}
    for data in deployed_pokemon.values():
        if String((data as Dictionary).get("ecology_id", "")) == ecology_id:
            return data as Dictionary
    for data in wild_pokemon.values():
        if String((data as Dictionary).get("ecology_id", "")) == ecology_id:
            return data as Dictionary
    return {}

func _ecology_cell_by_id(ecology_id: String) -> Vector2i:
    for raw_cell in deployed_pokemon.keys():
        var data: Dictionary = deployed_pokemon[raw_cell]
        if String(data.get("ecology_id", "")) == ecology_id:
            return Vector2i(raw_cell)
    for data in wild_pokemon.values():
        var record := data as Dictionary
        if String(record.get("ecology_id", "")) == ecology_id:
            return Vector2i(record.get("cell", Vector2i.ZERO))
    return Vector2i(-2147483648, -2147483648)

func _paired_wander_direction(
        data: Dictionary, origin: Vector2i, fallback: Vector2i
    ) -> Vector2i:
    var mate_id := String(data.get("mate_id", ""))
    if mate_id.is_empty():
        return fallback
    var mate_cell := _ecology_cell_by_id(mate_id)
    if mate_cell.x <= -2147483648:
        return fallback
    var delta := mate_cell - origin
    var distance := maxi(absi(delta.x), absi(delta.y))
    var egg_ready := bool(data.get("can_lay_egg", false)) and \
        float(data.get("lay_egg_seconds", PokemonEcology.LAY_EGG_SECONDS)) <= 0.0

    # Do not glue paired parents together. They are free to wander throughout
    # the source 7x7 habitat square; only pull them back at its edge. When an
    # egg is actually ready, converge the pair so the existing egg rule still
    # succeeds without changing fertility, timers, inheritance, or egg odds.
    if egg_ready and distance > 1:
        return _cardinal_direction(delta, false)
    if distance > PokemonEcology.HABITAT_RADIUS:
        return _cardinal_direction(delta, false)
    if distance == PokemonEcology.HABITAT_RADIUS and rng.randf() < 0.25:
        return _cardinal_direction(delta, false)
    if distance <= 1 and rng.randf() < 0.22:
        return _cardinal_direction(delta, true)
    return fallback

const WATER_FLOAT_OFFSETS := {"lapras": 5.0, "anorith": 2.0, "araichu": 7.0, "raichu_alolan": 7.0, "mantine": 4.0, "sharpedo": 2.0}
var water_pokemon_materials: Dictionary = {}

func _source_pokemon_in_water(cell: Vector2i) -> bool:
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        return tile != null and "water" in tile.name and not "_tidal" in tile.name
    return terrain_kind_at(cell) == 0

func _update_pokemon_water_visual(data: Dictionary) -> void:
    var sprite := data.get("sprite") as Sprite2D
    if not is_instance_valid(sprite) or bool(data.get("burrowed", false)):
        return
    var cell := Vector2i(floori(sprite.position.x / TILE), floori(sprite.position.y / TILE))
    var in_water := _source_pokemon_in_water(cell)
    if not in_water:
        if sprite.has_meta("water_visual"):
            sprite.material = null
            sprite.remove_meta("water_visual")
        return
    var species := String(data.get("species", ""))
    var extra := float(WATER_FLOAT_OFFSETS.get(species, 0.0))
    var height := float(sprite.texture.get_height()) / sprite.vframes
    if species == "mega_sharpedo": extra = 8.0 - height / 2.0
    # Half of this tall sprite under water left only its horns and eyes
    # showing. It rides higher: the whole face and upper body are seen.
    if species == "mega_gyarados": extra = 8.0 - roundf(height * 0.28)
    var key := Vector2(extra, height)
    if not water_pokemon_materials.has(key):
        var shader := Shader.new()
        shader.code = """shader_type canvas_item;
uniform float extra = 0.0;
uniform float frame_height = 16.0;
void vertex() {
    float bob = step(40.0, mod(TIME * 60.0, 80.0));
    VERTEX.y += 4.0 - extra - bob;
}
void fragment() {
    float bob = step(40.0, mod(TIME * 60.0, 80.0));
    if (UV.y * frame_height >= frame_height - 8.0 + extra + bob) { discard; }
}
"""
        var material := ShaderMaterial.new()
        material.shader = shader
        material.set_shader_parameter("extra", extra)
        material.set_shader_parameter("frame_height", height)
        water_pokemon_materials[key] = material
    sprite.material = water_pokemon_materials[key]
    sprite.set_meta("water_visual", true)

func _pokemon_can_move_between(species: String, origin: Vector2i, target: Vector2i) -> bool:
    if exact_world_mode and exact_world != null:
        var destination := exact_world.tile_at(target)
        var current := exact_world.tile_at(origin)
        # Pokemon.java Move/Wander reject ledges even when player-passable.
        if destination == null or destination.is_ledge:
            return false
        if current != null and current.is_ledge and _permitted_ledge_direction(current) == Vector2i.UP and target.y < origin.y:
            return false
    if not _source_pokemon_in_water(origin):
        return _pokemon_can_enter(species, target)
    if not _in_bounds(target) or blocked.has(target):
        return false
    var structure: Dictionary = built_structures.get(target, {})
    if String(structure.get("name", "")) == "FENCE" or bool(structure.get("gate", false)):
        return false
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(target)
        if tile == null or "fence" in tile.name_upper or "fence" in tile.name:
            return false
        var near_shore := false
        var target_near_shore := false
        for y in range(-1, 2):
            for x in range(-1, 2):
                var direction := Vector2i(x, y)
                var shore := exact_world.tile_at(origin + direction)
                var target_shore := exact_world.tile_at(target + direction)
                near_shore = near_shore or (shore != null and not "water" in shore.name)
                target_near_shore = target_near_shore or (target_shore != null and not "water" in target_shore.name)
        if near_shore and (not target_near_shore or not "water" in tile.name):
            return false
        var only_swim := bool(PokemonData.info(species).get("overworld_behavior", {}).get("swim_only", false))
        return tile.is_water if only_swim else (tile.is_water or not tile.is_solid)
    return _pokemon_can_enter(species, target)

## Clearing what grew on a tile unblocks the ground, but not a wall or roof
## that has since been built there, nor an item lying on it. Without this, a
## roof over ground where grass was once cut stopped blocking every time the
## world loaded, and Pokemon walked onto the house.
func _unblock_ground(cell: Vector2i) -> void:
    if bool(built_structures.get(cell, {}).get("solid", false)):
        return
    if blocked.get(cell) is String:
        return
    blocked.erase(cell)

func _pokemon_can_enter(species: String, cell: Vector2i) -> bool:
    if not _in_bounds(cell) or blocked.has(cell):
        return false
    var structure: Dictionary = built_structures.get(cell, {})
    if String(structure.get("name", "")) == "FENCE" or \
            bool(structure.get("gate", false)):
        return false
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile != null and (tile.is_ledge or "fence" in tile.name.to_lower() or \
                "fence" in tile.name_upper.to_lower()):
            return false
    var behavior: Dictionary = PokemonData.info(species).get("overworld_behavior", {})
    if bool(behavior.get("swim_only", false)):
        return terrain_kind_at(cell) == 0
    return _is_walkable(cell) and terrain_kind_at(cell) != 0

func get_crafting_save_state() -> Dictionary:
    var structures: Array = []
    for key in built_structures.keys():
        var cell: Vector2i = key
        var data: Dictionary = built_structures[cell]
        if bool(data.get("generated_stair_pair", false)):
            continue
        var saved_structure := data.duplicate(true)
        for runtime_key in ["sprite", "collision", "solid", "bridged_water"]:
            saved_structure.erase(runtime_key)
        saved_structure["name"] = String(data.get("name", ""))
        saved_structure["x"] = cell.x
        saved_structure["y"] = cell.y
        structures.append(saved_structure)

    var farms: Array = []
    for key in deployed_pokemon.keys():
        var cell: Vector2i = key
        var data: Dictionary = deployed_pokemon[cell]
        farms.append(_serializable_ecology_record(data, cell))

    var saved_wild_pokemon: Array = []
    for raw_id in wild_pokemon.keys():
        var data: Dictionary = wild_pokemon[raw_id]
        var cell: Vector2i = data.get("cell", Vector2i.ZERO)
        var saved_wild := _serializable_ecology_record(data, cell)
        saved_wild["id"] = int(raw_id)
        saved_wild_pokemon.append(saved_wild)

    var saved_eggs: Array = []
    for raw_cell in wild_eggs.keys():
        var cell: Vector2i = raw_cell
        var data: Dictionary = wild_eggs[cell]
        var saved_egg := data.duplicate(true)
        saved_egg.erase("sprite")
        saved_egg.erase("cell")
        saved_egg["x"] = cell.x
        saved_egg["y"] = cell.y
        saved_eggs.append(saved_egg)

    var saved_follower: Dictionary = {}
    if not follower_pokemon.is_empty():
        saved_follower = follower_pokemon.duplicate(true)
        saved_follower.erase("sprite")

    return {
        "removed_resources": removed_resources.keys(),
        "terrain_changes": terrain_changes.duplicate(true),
        "source_plant_farms": plants().snapshot(),
        "structures": structures,
        "deployed_pokemon": farms,
        "wild_pokemon": saved_wild_pokemon,
        "wild_eggs": saved_eggs,
        "follower_pokemon": saved_follower,
        "active_field_move": active_field_move,
        "active_field_pokemon": active_field_pokemon.duplicate(true),
        "build_selection_index": build_selection_index,
        "next_deployed_id": next_deployed_id,
        "source_interior_mutations": source_interior_mutations.duplicate(true),
        "mine_pokemon": SourceMineRuntime.snapshot(self),
        "built_house_paintings": built_house_paintings.duplicate(true),
        "built_house_floor_tiles": built_house_floor_tiles.keys(),
        "built_house_decorations": built_house_decorations.duplicate(true),
        "built_house_origins": built_house_origins.duplicate(true),
        "event_progress": event_progress.duplicate(true),
        "ghost_step_countdown": ghost_step_countdown,
        "dropped_items": dropped_items().snapshot(),
        "discovered_cells": discovered_cells.keys(),
        "world_elapsed_seconds": world_elapsed_seconds,
        "repel_until_elapsed": repel_until_elapsed,
        "active_area_id": active_area_id,
        "source_interior_layout_version": 1,
        "source_return_x": Vector2i(area_return_cells.get("%s_RETURN" % active_area_id, spawn_cell)).x,
        "source_return_y": Vector2i(area_return_cells.get("%s_RETURN" % active_area_id, spawn_cell)).y,
        # Preserve enough built-house context to reconstruct the same floor
        # before Main restores the raw player position. Generated stair mirrors
        # are rebuilt from the saved primary stairs and are never serialized.
        "active_built_house_door_x": (
            active_built_house_door.x if active_area_id == "HOUSE" else -2147483648
        ),
        "active_built_house_door_y": (
            active_built_house_door.y if active_area_id == "HOUSE" else -2147483648
        ),
        "active_built_house_floor": (
            _built_house_floor_index_for_cell(_player_cell())
            if active_area_id == "HOUSE" else 0
        ),
        "camera_zoom_level": camera_zoom_level,
        "respawn_house": respawn_house.duplicate(true),
        "respawn_x": respawn_cell.x,
        "respawn_y": respawn_cell.y
    }

func _serializable_ecology_record(data: Dictionary, cell: Vector2i) -> Dictionary:
    var saved := data.duplicate(true)
    for runtime_key in [
            "sprite", "burrow_whirl_sprite", "burrow_sand_sprite",
            "behavior", "cell",
            "previous_mate_id", "ball_move_tween", "ball_reserved", "ball_facing"
        ]:
        saved.erase(runtime_key)
    var source_record = saved.get("source_record", {})
    if typeof(source_record) == TYPE_DICTIONARY:
        var serializable_source := (source_record as Dictionary).duplicate(true)
        serializable_source.erase("position")
        saved["source_record"] = serializable_source
    saved["x"] = cell.x
    saved["y"] = cell.y
    return saved

func restore_crafting_save_state(state: Dictionary) -> void:
    if state.is_empty():
        return
    var prior_gameplay := gameplay_enabled
    gameplay_enabled = false
    var restore_deadline := Time.get_ticks_usec() + 4000
    restoring_saved_tiles = true
    restored_tiles_need_refresh = false
    dropped_items().clear_actors()
    world_elapsed_seconds = float(state.get("world_elapsed_seconds", world_elapsed_seconds))
    last_event_day = _world_day_index()
    ghost_step_countdown = int(state.get("ghost_step_countdown", -1))
    var saved_event_progress = state.get("event_progress", {})
    if typeof(saved_event_progress) == TYPE_DICTIONARY:
        var restored_progress := (saved_event_progress as Dictionary).duplicate(true)
        for required_key in [
                "completed", "trainer_defeated", "keystone_life_force",
                "regis_caught", "mewtwo_defeated_day",
                "fossil_machine_powered", "biome_first_entries"
            ]:
            if not restored_progress.has(required_key):
                restored_progress[required_key] = (
                    [] if required_key == "regis_caught"
                    else -1 if required_key == "mewtwo_defeated_day"
                    else false if required_key == "fossil_machine_powered"
                    else {}
                )
        event_progress = restored_progress
    repel_until_elapsed = float(state.get("repel_until_elapsed", 0.0))
    built_house_paintings.clear()
    built_house_floor_tiles.clear()
    built_house_decorations.clear()
    built_house_origins = (state.get("built_house_origins", {}) as Dictionary).duplicate(true)
    built_house_decorations = state.get("built_house_decorations", {}).duplicate(true)
    var saved_house_floors = state.get("built_house_floor_tiles", [])
    if typeof(saved_house_floors) == TYPE_ARRAY:
        for raw_floor_key in saved_house_floors:
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            built_house_floor_tiles[String(raw_floor_key)] = true
    var saved_house_paintings = state.get("built_house_paintings", {})
    if typeof(saved_house_paintings) == TYPE_DICTIONARY:
        for raw_key in (saved_house_paintings as Dictionary).keys():
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            var picture_index := clampi(int((saved_house_paintings as Dictionary)[raw_key]), 1, 20)
            built_house_paintings[String(raw_key)] = picture_index
    set_build_selection_index(int(state.get("build_selection_index", 0)))
    active_area_id = String(state.get("active_area_id", "OVERWORLD"))
    if (
            active_area_id not in ["OVERWORLD", "HOUSE", "CAVE"]
            and not source_area_entries.has(active_area_id)
        ):
        active_area_id = "OVERWORLD"
    if active_area_id not in ["OVERWORLD", "HOUSE", "CAVE"]:
        area_return_cells["%s_RETURN" % active_area_id] = (
            Vector2i(int(state["source_return_x"]), int(state["source_return_y"]))
            if state.has("source_return_x") and state.has("source_return_y")
            else _recover_source_dungeon_return(active_area_id))
    if source_area_layers.has(active_area_id):
        (source_area_layers[active_area_id] as CanvasItem).visible = true
    _set_exact_overworld_streaming(active_area_id == "OVERWORLD")
    camera_zoom_level = clampf(
        float(state.get("camera_zoom_level", 1.0)) if preload("res://scripts/game_options.gd").enabled("zoom") else 1.0,
        CAMERA_ZOOM_MIN,
        CAMERA_ZOOM_MAX
    )
    respawn_cell = Vector2i(
        int(state.get("respawn_x", -2147483648)),
        int(state.get("respawn_y", -2147483648))
    )
    respawn_house = (state.get("respawn_house", {}) as Dictionary).duplicate(true)
    call_deferred("_configure_camera")
    next_deployed_id = maxi(1, int(state.get("next_deployed_id", 1)))

    if state.has("discovered_cells"):
        discovered_cells.clear()
        var saved_discovery = state.get("discovered_cells", [])
        # An online player's record keeps this packed into squares.
        if typeof(saved_discovery) == TYPE_DICTIONARY:
            saved_discovery = preload("res://scripts/coop_world_snapshot.gd").unpacked_discovery(saved_discovery)
        if typeof(saved_discovery) == TYPE_ARRAY:
            for raw_key in saved_discovery:
                if Time.get_ticks_usec() >= restore_deadline:
                    await get_tree().process_frame
                    restore_deadline = Time.get_ticks_usec() + 4000
                var key := String(raw_key)
                var cell := _cell_from_key(key)
                if _in_bounds(cell):
                    discovered_cells[key] = true

    var saved_terrain = state.get("terrain_changes", {})
    if typeof(saved_terrain) == TYPE_DICTIONARY:
        for key in saved_terrain.keys():
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            var cell := _cell_from_key(String(key))
            if _in_bounds(cell):
                var kind := int(saved_terrain[key])
                terrain_changes[String(key)] = kind
                if exact_world_mode:
                    _set_exact_tile_names(
                        cell, "sand1" if kind == 1 else "green1", ""
                    )
                    continue
                terrain[cell.y][cell.x] = kind
                var sprite: Sprite2D = ground_sprites.get(cell) as Sprite2D
                if is_instance_valid(sprite):
                    sprite.texture = GRASS if kind == 2 else SAND

    var removed = state.get("removed_resources", [])
    if typeof(removed) == TYPE_ARRAY:
        for raw_key in removed:
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            var key := String(raw_key)
            var cell := _cell_from_key(key)
            if exact_world_mode and exact_world != null:
                var tile := exact_world.tile_at(cell)
                if tile != null:
                    tile.set_names(tile.name, "")
                    _refresh_exact_streams()
            else:
                _remove_resource(cell, false)
            removed_resources[key] = true

    var saved_structures = state.get("structures", [])
    if typeof(saved_structures) == TYPE_ARRAY:
        for raw in saved_structures:
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var entry: Dictionary = raw
            var cell := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
            if String(entry.get("name", "")) == "WINDOW" and _in_bounds(cell):
                entry = entry.duplicate(true)
                entry["name"] = "WALL"
                entry["recipe_name"] = "WALL"
                entry["window"] = true
            place_structure(String(entry.get("recipe_name", entry.get("name", ""))), cell, true, entry)

        # Resolve connections and attachments against the complete restored
        # shell, independently of the order in which its pieces were saved.
        for raw_cell in built_structures.keys():
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            _refresh_connected_structures_around(raw_cell)
            _refresh_shell_attachment(raw_cell)

    # Reconstruct a saved player-built house only after its exterior and
    # primary stairs have been restored. This recreates the interior layer,
    # generated stair mirrors, void collisions, and the selected upper floor
    # before Main restores the saved player coordinates.
    if active_area_id == "HOUSE":
        var saved_house_door: Vector2i = Vector2i(
            int(state.get("active_built_house_door_x", -2147483648)),
            int(state.get("active_built_house_door_y", -2147483648))
        )
        var saved_house_floor: int = maxi(0, int(state.get("active_built_house_floor", 0)))
        var valid_saved_house: bool = (
            saved_house_door.x > -2147483648
            and built_structures.has(saved_house_door)
            and String((built_structures[saved_house_door] as Dictionary).get("name", "")) == "DOOR"
        )
        if valid_saved_house:
            var saved_house_state: Dictionary = _built_house_state(saved_house_door)
            if bool(saved_house_state.get("ready", false)):
                _prepare_built_house_interior(saved_house_door, saved_house_state)
                _set_active_built_house_floor(saved_house_floor)
                var restored_house_layer: CanvasItem = get_node_or_null("BuiltHouseInterior") as CanvasItem
                if restored_house_layer != null:
                    restored_house_layer.visible = true
                _set_exact_overworld_streaming(false)
            else:
                active_area_id = "OVERWORLD"
        else:
            active_area_id = "OVERWORLD"
        if active_area_id == "OVERWORLD":
            _set_exact_overworld_streaming(true)

    var saved_farms = state.get("deployed_pokemon", [])
    if typeof(saved_farms) == TYPE_ARRAY:
        for raw in saved_farms:
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            if typeof(raw) != TYPE_DICTIONARY:
                continue
            var entry: Dictionary = raw
            var cell := Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1)))
            _restore_deployed_pokemon(entry, cell)

    if state.has("wild_pokemon"):
        var saved_wild = state.get("wild_pokemon", [])
        # Early port saves wrote an empty array here, which erased every
        # source-generated overworld Pokemon on load. Preserve the freshly
        # reconstructed source population for those saves.
        if typeof(saved_wild) == TYPE_ARRAY and (not saved_wild.is_empty() or bool(state.get("coop_authoritative_population", false))):
            _clear_wild_pokemon()
            for raw in saved_wild:
                if Time.get_ticks_usec() >= restore_deadline:
                    await get_tree().process_frame
                    restore_deadline = Time.get_ticks_usec() + 4000
                if typeof(raw) != TYPE_DICTIONARY:
                    continue
                var entry: Dictionary = raw
                var cell := Vector2i(
                    int(entry.get("x", -1)), int(entry.get("y", -1))
                )
                _add_wild_pokemon(
                    String(entry.get("species", "pidgey")),
                    int(entry.get("level", 2)),
                    cell,
                    String(entry.get("home_biome", biome_at(cell))),
                    int(entry.get("id", 0)),
                    entry.get("source_record", {}) as Dictionary,
                    entry
                )
    if not bool(state.get("coop_authoritative_population", false)):
        _ensure_overworld_pokemon_population()

    if state.has("wild_eggs"):
        _clear_wild_eggs()
        var saved_eggs = state.get("wild_eggs", [])
        if typeof(saved_eggs) == TYPE_ARRAY:
            for raw in saved_eggs:
                if Time.get_ticks_usec() >= restore_deadline:
                    await get_tree().process_frame
                    restore_deadline = Time.get_ticks_usec() + 4000
                if typeof(raw) != TYPE_DICTIONARY:
                    continue
                var entry: Dictionary = raw
                _add_wild_egg(
                    String(entry.get("species", "pidgey")),
                    Vector2i(int(entry.get("x", -1)), int(entry.get("y", -1))),
                    entry
                )

    # Field moves are momentary actions, not saved-game startup state. Loading
    # never auto-deploys a follower or silently starts BUILD/FOLLOW.
    clear_active_field_move(false)

    var saved_interior_mutations = state.get("source_interior_mutations", {})
    if typeof(saved_interior_mutations) == TYPE_DICTIONARY:
        source_interior_mutations.clear()
        for raw_key in saved_interior_mutations:
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            var key := String(raw_key)
            var mutation = saved_interior_mutations[raw_key]
            if typeof(mutation) != TYPE_DICTIONARY:
                continue
            var cell := _cell_from_key(key)
            if int(state.get("source_interior_layout_version", 0)) == 0:
                cell = _legacy_source_interior_cell(cell)
                key = _cell_key(cell)
            source_interior_mutations[key] = (mutation as Dictionary).duplicate(true)
            _apply_source_interior_mutation(cell, mutation as Dictionary)
    SourceRegiRuntime.sync(self)
    source_plant_farms = state.get("source_plant_farms", {}).duplicate(true)
    SourceMineRuntime.restore(self, state.get("mine_pokemon", {}))
    plants().restore()
    if exact_world != null:
        var repaired_roof_cells := exact_world.repair_mansion_roof_grass()
        for cell in repaired_roof_cells:
            if Time.get_ticks_usec() >= restore_deadline:
                await get_tree().process_frame
                restore_deadline = Time.get_ticks_usec() + 4000
            source_interior_mutations.erase(_cell_key(cell))
            source_plant_farms.erase(_cell_key(cell))
        if not repaired_roof_cells.is_empty():
            _refresh_exact_streams()
    if not has_meta("gen3_art_refresh"):
        await _refresh_daily_events(true)
    SourceForestBoss.install(self)
    await preload("res://scripts/biome_megas.gd").prepare_load(self)
    preload("res://scripts/biome_megas.gd").install(self)

    dropped_items().restore(state.get("dropped_items", {}))
    map_art_revision += 1
    restoring_saved_tiles = false
    if restored_tiles_need_refresh:
        restored_tiles_need_refresh = false
        _refresh_exact_streams()
    gameplay_enabled = prior_gameplay

func _clear_wild_pokemon() -> void:
    for raw_id in wild_pokemon.keys():
        var data: Dictionary = wild_pokemon[raw_id]
        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            sprite.queue_free()
        var whirl_sprite: Sprite2D = data.get("burrow_whirl_sprite") as Sprite2D
        if is_instance_valid(whirl_sprite):
            whirl_sprite.queue_free()
        var sand_sprite: Sprite2D = data.get("burrow_sand_sprite") as Sprite2D
        if is_instance_valid(sand_sprite):
            sand_sprite.queue_free()
    wild_pokemon.clear()
    sand_trap_ids.clear()
    next_wild_id = 1

func _clear_wild_eggs() -> void:
    for raw_cell in wild_eggs.keys():
        var data: Dictionary = wild_eggs[raw_cell]
        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            sprite.queue_free()
    wild_eggs.clear()

func _restore_deployed_pokemon(entry: Dictionary, cell: Vector2i) -> void:
    var indoors := entry.has("house_door")
    if not indoors and not _in_bounds(cell):
        return
    # One Pokemon, one tile: a second copy of one already standing is not
    # placed, and whatever stood on this tile goes, sprite included. Without
    # this a doubled entry left a frozen sprite behind with nothing under it.
    var restored_id := String(entry.get("ecology_id", ""))
    if not restored_id.is_empty():
        for other_cell in deployed_pokemon:
            if other_cell != cell and String(deployed_pokemon[other_cell].get("ecology_id", "")) == restored_id:
                return
    if deployed_pokemon.has(cell):
        var replaced = deployed_pokemon[cell].get("sprite")
        if is_instance_valid(replaced):
            replaced.queue_free()
        deployed_pokemon.erase(cell)
    var species := String(entry.get("species", "")).to_lower()
    var pokemon_texture: Texture2D = PokemonData.record_texture(entry, "overworld")
    if pokemon_texture == null:
        pokemon_texture = FARM_POKEMON_TEXTURES.get(species) as Texture2D
    if pokemon_texture == null:
        return
    var sprite := Sprite2D.new()
    sprite.texture = pokemon_texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = _cell_center(cell)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    _configure_overworld_sprite(sprite)
    var layer := _house_pokemon_layer() if indoors else get_node_or_null("LandmarkLayer") as Node2D
    if layer == null:
        return
    layer.add_child(sprite)
    preload("res://scripts/shiny_sparkles.gd").attach(sprite, entry)
    var ecology_id := String(entry.get("ecology_id", ""))
    if ecology_id.is_empty():
        ecology_id = "owned:%d" % next_deployed_id
        next_deployed_id += 1
    elif ecology_id.begins_with("owned:"):
        next_deployed_id = maxi(next_deployed_id, int(ecology_id.trim_prefix("owned:")) + 1)
    var stored := PokemonEcology.ensure_record(entry, rng, ecology_id)
    stored["cell"] = cell
    stored["x"] = cell.x
    stored["y"] = cell.y
    stored["behavior"] = PokemonData.info(species).get("overworld_behavior", {})
    stored["move_timer"] = float(stored.get("move_timer", _wild_move_delay(species)))
    stored["sprite"] = sprite
    deployed_pokemon[cell] = stored
    if indoors:
        sprite.visible = _house_pokemon_visible(stored)

func _cell_key(cell: Vector2i) -> String:
    return "%d,%d" % [cell.x, cell.y]

func _cell_from_key(key: String) -> Vector2i:
    var parts := key.split(",")
    if parts.size() != 2:
        return Vector2i(-1, -1)
    return Vector2i(int(parts[0]), int(parts[1]))

func _in_bounds(cell: Vector2i) -> bool:
    if exact_world_mode and exact_world != null:
        return exact_world.contains_cell(cell)
    return cell.x >= 0 and cell.y >= 0 and cell.x < map_w and cell.y < map_h

func _spawn_wild_pokemon() -> void:
    var candidates: Array[Vector2i] = []
    for y in range(3, map_h - 3):
        for x in range(3, map_w - 3):
            var cell := Vector2i(x, y)
            if not _is_walkable(cell) or Vector2(cell - spawn_cell).length() < 7.0:
                continue
            candidates.append(cell)
            # Tall-grass habitat receives extra source-style spawn weight.
            if tall_grass.has(cell):
                candidates.append(cell)
                candidates.append(cell)

    var target_count := maxi(6, int(float(map_w * map_h) / 300.0))
    var attempts := 0
    while wild_pokemon.size() < target_count and attempts < target_count * 80:
        attempts += 1
        if candidates.is_empty():
            break
        var cell := candidates[rng.randi_range(0, candidates.size() - 1)]
        if _wild_id_at_cell(cell) >= 0 or wild_eggs.has(cell):
            continue
        var biome := biome_at(cell)
        var species := _random_land_species_for_cell(cell)
        _add_wild_pokemon(species, _level_for_cell(cell), cell, biome)

func _ensure_overworld_pokemon_population() -> void:
    if not wild_pokemon.is_empty():
        return
    if exact_world_mode and exact_world != null:
        var source_records := exact_world.pokemon_cell_records()
        _spawn_exact_source_pokemon(source_records)
        _spawn_extra_biome_pokemon(source_records)
        _spawn_exact_burrowed_pokemon(exact_world.burrowed_cell_records())
        return
    _spawn_wild_pokemon()

func _spawn_wild_eggs() -> void:
    # Compatibility entry point. Eggs are produced by ecology parents.
    pass

func _add_wild_pokemon(
        species: String,
        level: int,
        cell: Vector2i,
        home_biome: String,
        requested_id: int = 0,
        source_record: Dictionary = {},
        saved_state: Dictionary = {}
    ) -> void:
    if not _in_bounds(cell) or _wild_id_at_cell(cell) >= 0:
        return
    # When the party has outgrown the authored route level, rerun the source
    # evolution checks against the adaptive encounter level. This preserves the
    # biome's species family while allowing the higher stages documented by
    # PokeWilds to appear for a sufficiently high-level party. Saved roaming
    # records keep their already-resolved species.
    if saved_state.is_empty() and not bool(source_record.get("is_trapping", false)) and exact_world_mode and exact_world != null:
        var adaptive_level := _effective_wild_level(level)
        if adaptive_level > level:
            # Keep adaptive evolution deterministic per world/cell and do not
            # consume World.rng, which other runtime ecology systems share.
            var evolution_rng := RandomNumberGenerator.new()
            evolution_rng.seed = (
                int(world_seed) * 1000003
                + cell.x * 73856093
                + cell.y * 19349663
                + adaptive_level * 83492791
                + species.hash()
            )
            var evolved_species := PokemonData.adaptive_source_evolution(
                species, adaptive_level, evolution_rng
            )
            var source_tile: SourceTile = exact_world.tile_at(cell)
            var source_route_name := ""
            var source_is_water := false
            if source_tile != null:
                source_is_water = source_tile.is_water
                if source_tile.route_belongs_to != null:
                    source_route_name = source_tile.route_belongs_to.name
            var route_allows_evolution := (
                source_route_name.is_empty()
                or PokemonData.source_route_species_allowed(
                    evolved_species, source_route_name, source_is_water
                )
            )
            if route_allows_evolution and \
                    PokemonData.texture(evolved_species, "overworld") != null:
                species = evolved_species
    var ecology_source := (
        saved_state.duplicate(true)
        if not saved_state.is_empty()
        else source_record.duplicate(true)
    )
    ecology_source["species"] = species.to_lower()
    ecology_source["level"] = level
    PokemonState.ensure_shiny(ecology_source, rng)
    var is_burrowed := bool(source_record.get("is_trapping", false))
    var texture: Texture2D = TRAPINCH_BURROW if is_burrowed else PokemonData.record_texture(ecology_source, "overworld")
    if texture == null:
        return
    var layer := get_node_or_null("WildPokemonLayer") as Node2D
    if layer == null:
        return

    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = _cell_center(cell)
    if species.to_lower() in ["aexeggutor", "exeggutor_alolan"]:
        sprite.scale = Vector2.ONE
        sprite.offset = Vector2(0, -16)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    if is_burrowed:
        sprite.hframes = 2
        sprite.vframes = 1
        sprite.frame = 0
        sprite.visible = false
    else:
        _configure_overworld_sprite(sprite)
        if species.to_lower() in ["aexeggutor", "exeggutor_alolan"]:
            sprite.hframes = 6
            sprite.vframes = 1
            sprite.frame = 4
            sprite.set_meta("alolan_exeggutor_walk", true)
    layer.add_child(sprite)
    preload("res://scripts/shiny_sparkles.gd").attach(sprite, ecology_source)

    var whirl_sprite: Sprite2D = null
    var sand_sprite: Sprite2D = null
    if is_burrowed:
        whirl_sprite = Sprite2D.new()
        whirl_sprite.texture = DESERT_WHIRLPOOL
        whirl_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        whirl_sprite.hframes = 2
        whirl_sprite.position = _cell_center(cell)
        whirl_sprite.z_as_relative = false
        whirl_sprite.z_index = _depth_z(cell) - 1
        whirl_sprite.visible = false
        layer.add_child(whirl_sprite)
        sand_sprite = Sprite2D.new()
        sand_sprite.texture = DESERT_BURROW_SAND
        sand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sand_sprite.hframes = 2
        sand_sprite.vframes = 2
        sand_sprite.frame = 0
        sand_sprite.position = _cell_center(cell) + Vector2(0, 6)
        sand_sprite.z_as_relative = false
        sand_sprite.z_index = _depth_z(cell) + 1
        sand_sprite.visible = false
        layer.add_child(sand_sprite)

    var wild_id := requested_id if requested_id > 0 else next_wild_id
    next_wild_id = maxi(next_wild_id, wild_id + 1)
    var stored := PokemonEcology.ensure_record(
        ecology_source, rng, "wild:%d" % wild_id
    )
    if saved_state.is_empty():
        # Keep the original two-minute repeat cycle, but stagger a new world's
        # first eligible egg so players can actually encounter wild eggs.
        stored["lay_egg_seconds"] = rng.randf_range(
            0.0, WILD_INITIAL_EGG_SECONDS
        )
    stored["id"] = wild_id
    stored["cell"] = cell
    stored["home_biome"] = home_biome
    if is_burrowed:
        sand_trap_ids[wild_id] = true
    stored["burrowed"] = is_burrowed
    stored["burrow_active"] = false
    stored["burrow_tick"] = 0
    stored["burrow_time"] = 0.0
    stored["burrow_whirl_tick"] = 0
    stored["move_timer"] = float(stored.get(
        "move_timer", _wild_move_delay(species, stored)
    ))
    stored["anim_phase"] = 0
    stored["behavior"] = PokemonData.info(species).get("overworld_behavior", {})
    stored["source_record"] = source_record.duplicate(true)
    stored["sprite"] = sprite
    stored["burrow_whirl_sprite"] = whirl_sprite
    stored["burrow_sand_sprite"] = sand_sprite
    # Source aggression affects how quickly a Pokemon becomes provoked; it is
    # not permission to force a battle on the first click or spawn frame.
    stored["aggro_player"] = bool(stored.get("aggro_player", source_record.get("aggressive", false)))
    stored["fed_until"] = float(stored.get("fed_until", 0.0))
    stored["flee_steps"] = int(stored.get("flee_steps", 0))
    wild_pokemon[wild_id] = stored
    _update_pokemon_water_visual(stored)

func _wild_move_delay(species: String, data: Dictionary = {}) -> float:
    if bool(data.get("burrowed", false)):
        return 999999.0
    var normalized := species.to_lower()
    if normalized in ["diglett", "dugtrio", "sharpedo"]:
        return rng.randf_range(0.35, 0.8)
    if bool(PokemonData.info(normalized).get("overworld_behavior", {}).get("lunge", false)):
        return rng.randf_range(0.35, 0.8)
    return rng.randf_range(WILD_MOVE_MIN, WILD_MOVE_MAX)

func _random_land_species_for_biome(biome: String) -> String:
    var species := "pidgey"
    for _attempt in range(12):
        species = PokemonData.random_species_for_biome(biome, rng)
        var behavior: Dictionary = PokemonData.info(species).get(
            "overworld_behavior", {}
        )
        if not bool(behavior.get("swim_only", false)):
            return species
    return species

func _random_land_species_for_cell(cell: Vector2i) -> String:
    var route_name := String(habitat_routes.get(cell, ""))
    var is_dungeon := SourceRouteData.is_dungeon(route_name)
    if exact_world_mode and exact_world != null:
        var source_route := exact_world.route_at(cell)
        route_name = "" if source_route == null else source_route.name
        is_dungeon = source_route != null and source_route.is_dungeon
    var allowed := SourceRouteData.allowed_pokemon(route_name)
    if not is_dungeon:
        allowed = _day_night_eligible_pokemon(allowed)
    if not allowed.is_empty():
        for _attempt in range(allowed.size() * 2):
            var species := String(allowed[rng.randi_range(0, allowed.size() - 1)])
            if PokemonData.texture(species, "overworld") != null:
                var behavior: Dictionary = PokemonData.info(species).get(
                    "overworld_behavior", {}
                )
                if not bool(behavior.get("swim_only", false)):
                    return species
    return _random_land_species_for_biome(biome_at(cell))

func _day_night_eligible_pokemon(source: Array) -> Array:
    var result: Array = []
    var excluded := (
        SourceRouteData.day_pokemon()
        if _is_night_time()
        else SourceRouteData.night_pokemon()
    )
    for raw_species in source:
        var species := String(raw_species).to_lower()
        if species not in excluded:
            result.append(raw_species)
    return result

func _is_tall_grass_cell(cell: Vector2i) -> bool:
    # Encounter grass and CUT-harvest grass are separate roles. Compatibility
    # snow/tundra grass is the harvestable GRASS source; other tall grass is
    # encounter habitat and must never disappear to CUT.
    if tall_grass.has(cell):
        return biome_at(cell) != "SNOW"
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        if tile != null and tile.is_tidal and _source_biome_for_tile(tile) != "BEACH":
            return false
        # grass1 is the source's normal encounter grass. Check its authored
        # identity directly as well as the cached flag so a stale/rewritten
        # SourceTile flag can never make a visibly normal grass field inert.
        if _is_normal_encounter_grass(cell):
            return true
        # Grass remains encounter habitat until CUT actually replaces the tile.
        # Being harvestable must not silently disable its encounter role.
        return tile != null and tile.is_grass
    return false

func _is_source_grass_name(asset_name: String) -> bool:
    var key := asset_name.to_lower().trim_suffix(".png")
    # Logical grass assets include the biome-specific variants. Do not match
    # ledge_grass_* because those are structural ledges rather than grass tufts.
    return key.begins_with("grass") and not key.begins_with("ledge_grass")

func _is_cuttable_grass_cell(cell: Vector2i) -> bool:
    if tall_grass.has(cell):
        return true
    if not exact_world_mode or exact_world == null:
        return false
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null:
        return false
    return _is_source_grass_name(tile.name) or _is_source_grass_name(tile.name_upper)

func _cuttable_grass_replacement(tile: SourceTile, cell: Vector2i) -> Dictionary:
    var base := tile.name
    var upper := tile.name_upper
    var base_key := base.to_lower().trim_suffix(".png")
    var upper_key := upper.to_lower().trim_suffix(".png")
    # Grass authored as an upper sprite simply clears to its already-authored
    # floor, regardless of biome variant.
    if _is_source_grass_name(upper_key):
        return {"base":base, "upper":""}
    # Base-layer encounter grass is visually a tuft over a source-specific
    # floor. Prefer neighboring authored floor so CUT never paints a foreign
    # square into the biome.
    var contextual := _contextual_ground_name(cell, tile.biome)
    if not contextual.is_empty() and not _is_source_grass_name(contextual):
        return {"base":contextual, "upper":""}
    match base_key:
        "grass1", "grass2", "grass4", "grass_fairy1", "grass_fairy2", "grass_fairy3", "grass_safari", "grass_short2", "grass_short3", "grass_planted":
            return {"base":"green1", "upper":""}
        "grass3":
            return {"base":"snow1", "upper":""}
        "grass_sand1", "grass_sand2":
            return {"base":"sand1", "upper":""}
        "grass_sand3":
            return {"base":"desert4", "upper":""}
        "grass_graveyard1":
            return {"base":"green11", "upper":""}
        "grass_savanna1", "grass_savanna2":
            return {"base":"savanna1", "upper":""}
        "grass_desert1":
            return {"base":"desert4", "upper":""}
    # Do not leave an unknown authored grass tile visually unchanged after CUT.
    # Fall back to the native floor family for its biome rather than inventing
    # a foreign green square. This covers future/source grass variants while
    # preserving the explicit mappings above.
    match _source_biome_for_tile(tile):
        "SNOW":
            return {"base":"snow1", "upper":""}
        "BEACH":
            return {"base":"sand1", "upper":""}
        "DESERT":
            return {"base":"desert4", "upper":""}
        "SAVANNA":
            return {"base":"savanna1", "upper":""}
        "GRAVEYARD":
            return {"base":"green11", "upper":""}
        _:
            return {"base":"green1", "upper":""}

func _add_wild_egg(
        species: String, cell: Vector2i, egg_record: Dictionary = {},
        ignored_wild_id: int = -1
    ) -> void:
    if not bool(egg_record.get("dropped_party_egg", false)):
        cell = _resolve_egg_ground_cell(cell, ignored_wild_id)
    if cell.x <= -2147483648:
        return
    var layer := _house_pokemon_layer() if egg_record.has("house_door") else get_node_or_null("WildEggLayer") as Node2D
    if layer == null:
        return
    var sprite := Sprite2D.new()
    sprite.texture = POKEMON_EGG
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = _cell_center(cell)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell)
    layer.add_child(sprite)
    var stored := egg_record.duplicate(true)
    stored["species"] = species.to_lower()
    stored["egg_species"] = String(stored.get("egg_species", species)).to_lower()
    stored["base_species"] = String(stored.get(
        "base_species", PokemonEcology.base_species_for(species)
    ))
    stored["egg_groups"] = stored.get(
        "egg_groups", PokemonData.info(species).get("egg_groups", ["EGG_NONE", "EGG_NONE"])
    )
    stored["is_egg"] = true
    stored["hatch_cycles"] = maxi(1, int(stored.get(
        "hatch_cycles", PokemonData.info(species).get("egg_cycles", 20)
    )))
    stored["hatch_steps"] = int(stored.get(
        "hatch_steps", int(stored["hatch_cycles"]) * PokemonEcology.EGG_STEP_INTERVAL
    ))
    stored["cell"] = cell
    stored["sprite"] = sprite
    if bool(stored.get("dropped_party_egg", false)) and egg_record.has("hatch_cycles"):
        stored["hatch_cycles"] = int(egg_record["hatch_cycles"])
    if stored.has("house_door"):
        sprite.visible = _house_pokemon_visible(stored)
    wild_eggs[cell] = stored

func _add_wild_egg_record(
        egg_record: Dictionary, cell: Vector2i, ignored_wild_id: int = -1
    ) -> void:
    _add_wild_egg(
        String(egg_record.get("species", "pidgey")), cell, egg_record,
        ignored_wild_id
    )

func _configure_overworld_sprite(sprite: Sprite2D) -> void:
    if sprite.texture == null:
        return
    var size := sprite.texture.get_size()
    if sprite.texture.has_meta("alolan_exeggutor_walk"):
        sprite.hframes = 6
        sprite.vframes = 1
        sprite.frame = 4
        sprite.offset = Vector2(0, -16)
        sprite.set_meta("alolan_exeggutor_walk", true)
    elif sprite.texture.has_meta("mega_gengar_walk"):
        sprite.hframes = 6
        sprite.vframes = 1
        sprite.frame = 4
        sprite.offset = sprite.texture.get_meta("overworld_feet_offset", Vector2.ZERO)
    elif int(size.y) == TILE and int(size.x) >= TILE * 6:
        sprite.hframes = int(size.x) / TILE
        sprite.vframes = 1
        sprite.frame = 4
    else:
        sprite.hframes = 1
        sprite.vframes = 1
        sprite.frame = 0

func _horizontal_visible_center_offset(
        texture: Texture2D,
        horizontal_frames: int = 1,
        vertical_frames: int = 1,
        frame_index: int = 0,
        cache_key: String = ""
    ) -> Vector2:
    if texture == null:
        return Vector2.ZERO
    horizontal_frames = maxi(1, horizontal_frames)
    vertical_frames = maxi(1, vertical_frames)
    var resolved_key := "%s:%d:%d:%d" % [
        cache_key, horizontal_frames, vertical_frames, frame_index
    ]
    if not cache_key.is_empty() and horizontal_sprite_center_cache.has(resolved_key):
        return horizontal_sprite_center_cache[resolved_key] as Vector2

    var image := texture.get_image()
    if texture is AtlasTexture:
        var atlas_texture := texture as AtlasTexture
        if atlas_texture.atlas != null:
            var atlas_image := atlas_texture.atlas.get_image()
            var region := Rect2i(atlas_texture.region)
            if atlas_image != null and not atlas_image.is_empty() and region.has_area():
                image = atlas_image.get_region(region)
    if image == null or image.is_empty():
        return Vector2.ZERO

    var frame_width := int(image.get_width() / horizontal_frames)
    var frame_height := int(image.get_height() / vertical_frames)
    if frame_width <= 0 or frame_height <= 0:
        return Vector2.ZERO
    var normalized_frame := posmod(
        frame_index, horizontal_frames * vertical_frames
    )
    var frame_x := (normalized_frame % horizontal_frames) * frame_width
    var frame_y := floori(
        float(normalized_frame) / float(horizontal_frames)
    ) * frame_height
    var left := frame_width
    var right := -1
    for y in range(frame_y, frame_y + frame_height):
        for x in range(frame_x, frame_x + frame_width):
            if image.get_pixel(x, y).a8 <= 0:
                continue
            left = mini(left, x - frame_x)
            right = maxi(right, x - frame_x)
    var result := Vector2.ZERO
    if right >= left:
        var visible_center := float(left + right + 1) * 0.5
        result.x = roundf(float(frame_width) * 0.5 - visible_center)
    if not cache_key.is_empty():
        horizontal_sprite_center_cache[resolved_key] = result
    return result

func _show_ecology_emote(sprite: Sprite2D, emote_name: String) -> void:
    if not is_instance_valid(sprite) or sprite.get_parent() == null:
        return
    # Original Pokemon.Emote/Player.Emote atlas order, 60 source ticks.
    # ?, bolt, sleep and fish are defined in the source atlas but have no
    # local gameplay call sites in the original 0.8.11 JAR.
    var frames := {"!": 0, "alert": 0, "?": 1, "question": 1,
        "happy": 2, "skull": 3, "angry": 3, "heart": 4,
        "bolt": 5, "sleep": 6, "fish": 7, "uncomfortable": 8,
        "sad": 8, "...": 9}
    if not frames.has(emote_name):
        return
    var previous := sprite.get_node_or_null("SourceEmote")
    if is_instance_valid(previous):
        sprite.remove_child(previous)
        previous.queue_free()
    var emote := Sprite2D.new()
    emote.name = "SourceEmote"
    emote.texture = preload("res://scripts/emote_style.gd").sheet()
    emote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    emote.hframes = 10
    emote.frame = int(frames[emote_name])
    emote.position = Vector2(0, -16)
    emote.z_index = 20
    sprite.add_child(emote)
    emote.add_to_group("styled_source_emotes")
    var tween := create_tween().bind_node(emote)
    tween.tween_interval(60.0 / 60.0)
    tween.tween_callback(emote.queue_free)

func _set_overworld_motion_frame(
        sprite: Sprite2D,
        direction: Vector2i,
        phase: int
    ) -> void:
    if sprite.has_meta("alolan_exeggutor_walk"):
        sprite.frame = (3 - phase) if direction.y < 0 else ((4 + phase) if direction.y > 0 else (1 - phase))
        sprite.flip_h = direction.x > 0
        return
    if sprite.hframes < 6:
        return
    sprite.flip_h = false
    if direction.y < 0:
        sprite.frame = 2 + phase
    elif direction.y > 0:
        sprite.frame = 4 + phase
    else:
        sprite.frame = phase
        sprite.flip_h = direction.x > 0

func _pokemon_has_field_move(pokemon_data: Dictionary, move_name: String) -> bool:
    var species := String(pokemon_data.get("species", "")).to_lower()
    return not species.is_empty() and FieldMoveData.field_moves_for(species).has(move_name)

func _flash_is_active() -> bool:
    # FLASH is passive while its Pokemon follows and remains active if that
    # same Pokemon is using another field move (RIDE/FLY/etc.).
    if active_field_move == "FLASH":
        return true
    if not active_field_pokemon.is_empty() and _pokemon_has_field_move(active_field_pokemon, "FLASH"):
        return true
    if not follower_pokemon.is_empty() and _pokemon_has_field_move(follower_pokemon, "FLASH"):
        return true
    return false

func _charm_suppresses(data: Dictionary) -> bool:
    if active_field_move != "CHARM":
        return false
    var behavior: Dictionary = data.get("behavior", {})
    # aggression 2 is the source's always-angry behavior and ignores CHARM.
    if int(behavior.get("aggression", 1)) >= 2:
        return false
    return int(active_field_pokemon.get("level", 1)) > _effective_wild_level(
        int(data.get("level", 1)))

func _update_wild_pokemon(delta: float) -> void:
    var directions: Array[Vector2i] = [
        Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
        Vector2i.UP, Vector2i.DOWN
    ]
    var player_cell := _player_cell()
    for raw_id in wild_pokemon.keys():
        var wild_id := int(raw_id)
        if not wild_pokemon.has(wild_id):
            continue
        var data: Dictionary = wild_pokemon[wild_id]
        if bool(data.get("burrowed", false)):
            continue
        var old_cell: Vector2i = data.get("cell", Vector2i.ZERO)
        if not _wild_ecology_is_active(old_cell, player_cell):
            continue
        var active_sprite := data.get("sprite") as Sprite2D
        if is_instance_valid(active_sprite):
            active_sprite.visible = true
            active_sprite.z_index = _depth_z(old_cell)
        var was_charmed := bool(data.get("charmed", false))
        var is_charmed := _charm_suppresses(data)
        data["charmed"] = is_charmed
        if is_charmed and not was_charmed:
            _show_ecology_emote(data.get("sprite") as Sprite2D, "heart")
        data["move_timer"] = float(data.get("move_timer", 0.0)) - delta
        if float(data["move_timer"]) > 0.0:
            wild_pokemon[wild_id] = data
            continue
        data["move_timer"] = _wild_move_delay(String(data.get("species", "")), data)
        data = _try_create_parent_egg(data, old_cell, wild_id)
        var behavior: Dictionary = data.get("behavior", {})
        if bool(behavior.get("stationary", false)):
            wild_pokemon[wild_id] = data
            continue

        var player_delta := player_cell - old_cell
        var pursuing := bool(data.get("aggro_player", false)) and not is_charmed
        if world_elapsed_seconds < float(data.get("fed_until", 0.0)):
            var eating_sprite: Sprite2D = data.get("sprite") as Sprite2D
            data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
            if is_instance_valid(eating_sprite):
                _set_overworld_motion_frame(
                    eating_sprite, Vector2.DOWN, int(data["anim_phase"])
                )
            wild_pokemon[wild_id] = data
            continue
        if (
                pursuing
                and active_field_move != "SURF"
                and player_delta.length_squared() <= 1
                and not encounter_grace_active()
                and not _repel_blocks(int(data.get("level", 1)))
            ):
            _begin_wild_encounter(wild_id)
            return
        var direction := directions[rng.randi_range(0, directions.size() - 1)]
        if bool(behavior.get("flee", false)) and player_delta.length_squared() <= 16:
            direction = _cardinal_direction(player_delta, true)
        elif pursuing and player_delta.length_squared() <= 64:
            direction = _cardinal_direction(player_delta, false)
        else:
            var friend_id := String(data.get("friend_id", ""))
            var friend_reunion := (
                not friend_id.is_empty()
                and float(data.get("friend_seconds", PokemonEcology.FRIEND_SECONDS)) <= 0.0
            )
            var companion_id := friend_id
            if friend_reunion:
                data["friend_seconds"] = PokemonEcology.FRIEND_SECONDS
                _show_friend_reunion(data, friend_id)
            elif companion_id.is_empty() or rng.randf() < 0.18:
                companion_id = String(data.get("mate_id", companion_id))
            if not companion_id.is_empty() and (friend_reunion or rng.randf() < 0.20):
                var companion_cell := _ecology_cell_by_id(companion_id)
                if companion_cell.x > -2147483648:
                    direction = _cardinal_direction(companion_cell - old_cell, false)
            elif rng.randf() < 0.12:
                var same_species_cell := _nearby_same_base_species_cell(data, old_cell)
                if same_species_cell.x > -2147483648:
                    direction = _cardinal_direction(same_species_cell - old_cell, false)
        direction = _paired_wander_direction(data, old_cell, direction)
        var target := old_cell + direction
        if (
                direction == Vector2i.ZERO
                or not _pokemon_can_move_between(String(data.get("species", "")), old_cell, target)
                or target == player_cell
                or target == follower_cell
                or target == field_helper_cell
                or _wild_id_at_cell(target, wild_id) >= 0
                or wild_eggs.has(target)
                or deployed_pokemon.has(target)
            ):
            wild_pokemon[wild_id] = data
            continue

        var sprite: Sprite2D = data.get("sprite") as Sprite2D
        var phase := 1 - int(data.get("anim_phase", 0))
        data["anim_phase"] = phase
        data["cell"] = target
        if is_instance_valid(sprite):
            _set_overworld_motion_frame(sprite, direction, phase)
            sprite.z_index = _depth_z(target)
            create_tween().tween_property(
                sprite, "position", _cell_center(target), 0.20
            ).set_trans(Tween.TRANS_LINEAR)
        if bool(behavior.get("flee", false)):
            data["flee_steps"] = int(data.get("flee_steps", 0)) + 1
            if int(data["flee_steps"]) >= 3 and _is_tall_grass_cell(target):
                _remove_wild_pokemon(wild_id)
                continue
        wild_pokemon[wild_id] = data

func _show_friend_reunion(data: Dictionary, friend_id: String) -> void:
    _show_ecology_emote(data.get("sprite") as Sprite2D, "happy")
    var friend := _ecology_record_by_id(friend_id)
    if not friend.is_empty():
        _show_ecology_emote(friend.get("sprite") as Sprite2D, "happy")

func _nearby_same_base_species_cell(
        data: Dictionary, center: Vector2i
    ) -> Vector2i:
    var base_species := String(data.get("base_species", ""))
    var own_id := int(data.get("id", -1))
    for raw_id in wild_pokemon.keys():
        if int(raw_id) == own_id:
            continue
        var candidate: Dictionary = wild_pokemon[raw_id]
        if String(candidate.get("base_species", "")) != base_species:
            continue
        var candidate_cell: Vector2i = candidate.get("cell", Vector2i.ZERO)
        if (
                absi(candidate_cell.x - center.x) <= PokemonEcology.HABITAT_RADIUS
                and absi(candidate_cell.y - center.y) <= PokemonEcology.HABITAT_RADIUS
            ):
            return candidate_cell
    return Vector2i(-2147483648, -2147483648)

func _remove_wild_pokemon(wild_id: int) -> void:
    if not wild_pokemon.has(wild_id):
        return
    sand_trap_ids.erase(wild_id)
    var data: Dictionary = wild_pokemon[wild_id]
    if bool(data.get("burrowed", false)) and exact_world != null:
        var tile := exact_world.tile_at(Vector2i(data.get("cell", Vector2i.ZERO)))
        if tile != null:
            tile.items.erase("trapinch")
    var sprite: Sprite2D = data.get("sprite") as Sprite2D
    if is_instance_valid(sprite):
        sprite.queue_free()
    var whirl_sprite: Sprite2D = data.get("burrow_whirl_sprite") as Sprite2D
    if is_instance_valid(whirl_sprite):
        whirl_sprite.queue_free()
    var sand_sprite: Sprite2D = data.get("burrow_sand_sprite") as Sprite2D
    if is_instance_valid(sand_sprite):
        sand_sprite.queue_free()
    wild_pokemon.erase(wild_id)

func _cardinal_direction(delta: Vector2i, away: bool) -> Vector2i:
    var direction := Vector2i.ZERO
    if absi(delta.x) >= absi(delta.y):
        direction = Vector2i(signi(delta.x), 0)
    else:
        direction = Vector2i(0, signi(delta.y))
    return -direction if away else direction

func _wild_id_at_cell(cell: Vector2i, ignored_id: int = -1) -> int:
    for raw_id in wild_pokemon.keys():
        var wild_id := int(raw_id)
        if wild_id == ignored_id:
            continue
        var data: Dictionary = wild_pokemon[raw_id]
        if Vector2i(data.get("cell", Vector2i(-1, -1))) == cell:
            return wild_id
    return -1

func _egg_at_cell(cell: Vector2i) -> Vector2i:
    return cell if wild_eggs.has(cell) else Vector2i(-1, -1)

func _attack_wild_egg(cell: Vector2i) -> void:
    if not wild_eggs.has(cell):
        return
    var data: Dictionary = wild_eggs[cell]
    var species := String(data.get("species", "pidgey")).to_lower()
    var member := data.duplicate(true)
    member.erase("sprite")
    member.erase("cell")
    member["species"] = species
    member["level"] = maxi(1, int(member.get("level", 5)))
    var context := {
        "id":"attack_egg_%d_%d" % [cell.x, cell.y],
        "kind":"attack_egg",
        "intro":"The EGG contains %s!" % PokemonData.battle_display_name(species),
        "can_run":true, "can_catch":false,
        "cell_x":cell.x, "cell_y":cell.y,
        "party":[member]
    }
    pending_battle_context = context.duplicate(true)
    battle_requested.emit(context)

func _attack_deployed_pokemon(cell: Vector2i) -> void:
    if not deployed_pokemon.has(cell):
        return
    var data: Dictionary = deployed_pokemon[cell]
    var member := data.duplicate(true)
    for runtime_key in ["sprite", "cell", "x", "y", "move_timer", "anim_phase", "behavior"]:
        member.erase(runtime_key)
    var species := String(member.get("species", "pidgey")).to_lower()
    member["species"] = species
    member["level"] = maxi(1, int(member.get("level", 5)))
    var context := {
        "id":"attack_deployed_%d_%d" % [cell.x, cell.y],
        "kind":"attack_deployed",
        "intro":"You challenged your own %s!" % PokemonData.battle_display_name(species),
        "can_run":true, "can_catch":true,
        "cell_x":cell.x, "cell_y":cell.y,
        "party":[member]
    }
    pending_battle_context = context.duplicate(true)
    battle_requested.emit(context)

func _begin_wild_encounter(wild_id: int, field_attack: bool = false) -> void:
    if bool(wild_pokemon.get(wild_id, {}).get("ball_reserved", false)): return
    # Java Pokemon pursuit/contact encounters explicitly exclude FLY.
    if active_field_move == "FLY" or not wild_pokemon.has(wild_id):
        return
    var data: Dictionary = wild_pokemon[wild_id]
    pending_encounter_record = _serializable_ecology_record(
        data, Vector2i(data.get("cell", Vector2i.ZERO))
    )
    if field_attack:
        pending_encounter_record["field_attack"] = true
    var source_record := data.get("source_record", {}) as Dictionary
    for property in source_record.keys():
        if not pending_encounter_record.has(property):
            pending_encounter_record[property] = source_record[property]
    _remove_wild_pokemon(wild_id)
    encounter_count += 1
    if not String(source_record.get("rare_legendary", "")).is_empty():
        var context := preload("res://scripts/rare_biome_legendaries.gd").context(String(data.species), pending_encounter_record)
        pending_battle_context = context.duplicate(true)
        battle_requested.emit(context)
        return
    if bool(source_record.get("rare_forest_mew",false)):
        var context := {"id":"rare_forest_mew","kind":"wild","fixed_level":true,
            "can_run":true,"can_catch":true,"party":[{"species":"mew","level":70}]}
        pending_battle_context = context.duplicate(true)
        battle_requested.emit(context)
        return
    if field_attack:
        # ATTACK starts the battle on the player's terms. Keep enough of the
        # overworld record to put the Pokemon back, calm, if the player runs.
        var context := {
            "id":"field_attack_wild_%d" % wild_id,
            "kind":"wild",
            "can_run":true,
            "can_catch":true,
            "field_attack":true,
            "field_attack_record":pending_encounter_record.duplicate(true),
            "party":[{
                "species":String(data.get("species", "pidgey")),
                "level":int(data.get("level", 2))
            }]
        }
        pending_battle_context = context.duplicate(true)
        battle_requested.emit(context)
        return
    encounter_requested.emit(
        String(data.get("species", "pidgey")),
        int(data.get("level", 2))
    )

func begin_encounter_grace(seconds: float = ENCOUNTER_GRACE_SECONDS) -> void:
    encounter_grace_remaining = maxf(encounter_grace_remaining, seconds)

func encounter_grace_active() -> bool:
    return encounter_grace_remaining > 0.0

func take_pending_encounter_record() -> Dictionary:
    var result := pending_encounter_record.duplicate(true)
    pending_encounter_record.clear()
    return result

func take_pending_egg_record() -> Dictionary:
    var result := pending_egg_record.duplicate(true)
    pending_egg_record.clear()
    return result

func confirm_wild_egg_pickup(cell: Vector2i) -> void:
    _collect_wild_egg(cell)

func _collect_wild_egg(cell: Vector2i) -> void:
    if not wild_eggs.has(cell):
        return
    var data: Dictionary = wild_eggs[cell]
    if bool(data.get("dropped_party_egg", false)) and not get_parent()._can_receive_overworld_pokemon():
        world_message.emit("Your party and storage are full.")
        return
    var species := String(data.get("species", "pidgey"))
    var sprite: Sprite2D = data.get("sprite") as Sprite2D
    if is_instance_valid(sprite):
        sprite.queue_free()
    pending_egg_record = data.duplicate(true)
    pending_egg_record.erase("sprite")
    pending_egg_record.erase("cell")
    wild_eggs.erase(cell)
    if bool(data.get("dropped_party_egg", false)):
        egg_collected.emit(species)
        return
    var anger_count := 0
    for raw_id in wild_pokemon.keys():
        var wild_id := int(raw_id)
        var pokemon: Dictionary = wild_pokemon[wild_id]
        if bool(pokemon.get("burrowed", false)):
            continue
        var pokemon_cell: Vector2i = pokemon.get("cell", Vector2i.ZERO)
        if (
                absi(pokemon_cell.x - cell.x) > PokemonEcology.PARENT_ALERT_RADIUS
                or absi(pokemon_cell.y - cell.y) > PokemonEcology.PARENT_ALERT_RADIUS
                or not PokemonEcology.is_egg_parent_match(pokemon, data)
            ):
            continue
        pokemon["aggro_player"] = true
        pokemon["warned"] = true
        wild_pokemon[wild_id] = pokemon
        _show_ecology_emote(pokemon.get("sprite") as Sprite2D, "alert")
        anger_count += 1
    egg_collected.emit(species)

func _trigger_burrowed_pokemon(wild_id: int) -> void:
    if active_field_move == "FLY" or encounter_grace_active() or not wild_pokemon.has(wild_id):
        return
    var data: Dictionary = wild_pokemon[wild_id]
    if bool(data.get("burrowed", false)):
        data["burrow_active"] = true

func _update_sand_traps(delta: float) -> void:
    if active_area_id != "OVERWORLD":
        return
    for wild_id in sand_trap_ids.keys():
        var data: Dictionary = wild_pokemon[wild_id]
        if not bool(data.get("burrowed", false)):
            continue
        var cell: Vector2i = data["cell"]
        var on_trap := _player_cell() == cell and active_field_move != "FLY"
        if on_trap and not encounter_grace_active() and not _repel_blocks(int(data.get("level", 22))):
            _trigger_burrowed_pokemon(wild_id)
        var remainder := float(data.get("burrow_time", 0.0)) + delta * 60.0
        var steps := int(remainder)
        data["burrow_time"] = remainder - steps
        if not bool(data.get("burrow_active", false)):
            # Hidden idle traps only need their source phase clock advanced.
            # Avoid rewriting three invisible sprites for every trap each frame.
            data["burrow_whirl_tick"] = (int(data.get("burrow_whirl_tick", 0)) + steps) % 80
            continue
        for step in range(steps):
            data["burrow_whirl_tick"] = (int(data.get("burrow_whirl_tick", 0)) + 1) % 80
            if not bool(data.get("burrow_active", false)):
                continue
            var tick := int(data.get("burrow_tick", 0))
            if tick < 66 or not on_trap:
                tick += 1
            data["burrow_tick"] = tick
            if (tick < 50 or (tick >= 120 and tick < 156)) and tick % 8 == 0:
                play_source_sound("move_object")
            if tick == 34 and get_parent().has_method("_play_pokemon_cry"):
                get_parent().call("_play_pokemon_cry", data)
            if tick >= 152:
                data["burrow_active"] = false
                data["burrow_tick"] = 0
            if tick >= 63 and on_trap and not encounter_grace_active():
                _begin_wild_encounter(wild_id)
                return
        var tick := int(data.get("burrow_tick", 0))
        var height := clampi((tick - 50) * 4, 0, 12)
        if tick >= 141:
            height = maxi(0, 12 - (tick - 140))
        var sprite := data.get("sprite") as Sprite2D
        var whirl := data.get("burrow_whirl_sprite") as Sprite2D
        var sand := data.get("burrow_sand_sprite") as Sprite2D
        if is_instance_valid(sprite):
            sprite.visible = height > 0
            sprite.hframes = 1
            sprite.region_enabled = true
            var frame := 0 if tick < 52 else 1
            if tick >= 120:
                frame = 0 if tick % 8 < 4 else 1
            sprite.region_rect = Rect2(frame * 16, 0, 16, height)
            sprite.position = _cell_center(cell) + Vector2(0, 2.0 - float(height) / 2.0)
        if is_instance_valid(whirl):
            whirl.visible = tick > 0
            whirl.frame = 0 if int(data.get("burrow_whirl_tick", 0)) < 40 else 1
        if is_instance_valid(sand):
            sand.visible = tick >= 50 and tick < 66
            sand.frame = 0 if tick < 58 else 1
            sand.position = _cell_center(cell) + Vector2(0, -6)

func _level_for_cell(cell: Vector2i) -> int:
    if exact_world_mode and exact_world != null:
        var route := exact_world.route_at(cell)
        return clampi(2 if route == null else route.level, 2, 100)
    if source_tiles.has(cell):
        return clampi(int((source_tiles[cell] as Dictionary).get("level", 2)), 2, 100)
    var distance := Vector2(cell - spawn_cell).length()
    var maximum := maxf(1.0, Vector2(float(map_w), float(map_h)).length())
    return clampi(2 + int(round(distance / maximum * 22.0)), 2, 24)

func _adaptive_grass_encounter_species(
        species: String, cell: Vector2i, source_level: int
    ) -> String:
    if species.is_empty() or not exact_world_mode or exact_world == null:
        return species
    var encounter_level: int = _effective_wild_level(source_level)
    if encounter_level <= source_level:
        return species
    var evolved: String = PokemonData.adaptive_source_evolution(
        species, encounter_level, rng
    )
    if evolved == species:
        return species
    var tile: SourceTile = exact_world.tile_at(cell)
    var route_name: String = ""
    var source_is_water: bool = false
    if tile != null:
        source_is_water = tile.is_water
        if tile.route_belongs_to != null:
            route_name = tile.route_belongs_to.name
    if not route_name.is_empty() and not PokemonData.source_route_species_allowed(
            evolved, route_name, source_is_water):
        return species
    if PokemonData.texture(evolved, "front") == null:
        return species
    return evolved

func _emit_source_grass_encounter(species: String, level: int, fixed_level: bool = false) -> void:
    # PlayerStanding: replace only rolled walking encounters, not fishing/actors.
    if preload("res://scripts/source_unown_event.gd").active(self):
        battle_requested.emit(preload("res://scripts/source_unown_event.gd").encounter(self, true))
        return
    if fixed_level:
        battle_requested.emit({"id":"mansion_grass", "kind":"wild",
            "fixed_level":true, "can_run":true, "can_catch":true,
            "party":[{"species":species,"level":level}]})
        return
    encounter_requested.emit(species, level)

func _request_random_encounter() -> void:
    var cell := _player_cell()
    var species := _random_land_species_for_cell(cell)
    if species.is_empty():
        return
    var level := _level_for_cell(cell)
    species = _adaptive_grass_encounter_species(species, cell, level)
    _emit_source_grass_encounter(species, level)

func _request_source_area_encounter() -> void:
    if active_area_id == "HOUSE":
        return
    var source_tile := _source_interior_tile_at_world_cell(_player_cell())
    if SourceMineRuntime.is_mine_tile(source_tile):
        # Java PlayerStanding: route + 0..2, encounter floors only, no
        # dungeon evolution escalation or party-level scaling in this mine.
        if source_tile.is_grass:
            var pool := SourceRouteData.allowed_pokemon("ruins1_inner")
            var species := String(pool[rng.randi_range(0, pool.size() - 1)])
            battle_requested.emit({"id":"mine_grass", "kind":"wild",
                "fixed_level":true, "can_run":true, "can_catch":true,
                "party":[{"species":species,"level":source_tile.route_belongs_to.level + rng.randi_range(0,2)}]})
        return
    if source_tile != null and source_tile.route_belongs_to != null and source_tile.route_belongs_to.name == "pkmnmansion1":
        if source_tile.is_grass:
            var encounter := SourceMansionRuntime.encounter(source_tile.route_belongs_to.level, rng)
            _emit_source_grass_encounter(encounter.species, encounter.level, true)
        return
    var route_name := ""
    var base_level := 12
    if active_area_id.begins_with("MANSION"):
        # Source requires an encounter floor with a route; rugs/props do not roll.
        return
    elif active_area_id.begins_with("RUINS"):
        return # No source encounter tile means no mine encounter.
    elif active_area_id == "REGI_CHAMBER":
        route_name = "regi_cave1"
        base_level = 35
    elif active_area_id.begins_with("INTERIOR_"):
        var route_data := _active_source_interior_route()
        route_name = String(route_data.get("name", ""))
        base_level = int(route_data.get("level", 12))
    if route_name.is_empty():
        return
    var allowed := SourceRouteData.allowed_pokemon(route_name)
    if allowed.is_empty():
        return
    for _attempt in range(allowed.size() * 2):
        var species := String(allowed[rng.randi_range(0, allowed.size() - 1)])
        if PokemonData.texture(species, "front") != null:
            var last_part := active_area_id.get_slice(
                "_", active_area_id.get_slice_count("_") - 1
            )
            var floor_number := int(last_part) if last_part.is_valid_int() else 0
            _emit_source_grass_encounter(species, clampi(base_level + floor_number * 3, 2, 100))
            return

func _active_source_interior_route() -> Dictionary:
    var tile := _source_interior_tile_at_world_cell(_player_cell())
    if tile == null or tile.route_belongs_to == null:
        return {}
    return {"name": tile.route_belongs_to.name, "level": tile.route_belongs_to.level}

func request_fishing_encounter(rod_name: String) -> void:
    var beside_water := false
    var player_cell: Vector2i = _player_cell()
    var directions: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
    ]
    for direction in directions:
        var target: Vector2i = player_cell + direction
        if _in_bounds(target) and terrain_kind_at(target) == 0:
            beside_water = true
            break
    if not beside_water:
        world_message.emit("Use the %s while facing water." % rod_name)
        return
    var water_species := ["magikarp", "tentacool", "goldeen"]
    if rod_name == "GOOD ROD":
        water_species.append_array(["poliwag", "krabby", "shellder"])
    elif rod_name == "SUPER ROD":
        water_species.append_array(["gyarados", "lapras", "dratini"])
    var species: String = water_species[rng.randi_range(0, water_species.size() - 1)]
    battle_requested.emit({"id": "wild", "kind": "wild", "can_run": true,
        "can_catch": true, "source_player_alert": true,
        "party": [{"species": species, "level": rng.randi_range(3, 18)}]})

var house_transition_active := false

func _enter_source_area(area_id: String, return_cell: Vector2i) -> void:
    if house_transition_active: return
    if area_id == "HOUSE" and generated and gameplay_enabled and (source_area_entries.has(area_id) or area_return_cells.has("HOUSE_ENTRY")):
        _house_door_transition("enter", func(): _enter_source_area_now(area_id, return_cell))
    else:
        _enter_source_area_now(area_id, return_cell)

func _enter_source_area_now(area_id: String, return_cell: Vector2i) -> void:
    if area_id.is_empty() or not source_area_entries.has(area_id) and not area_return_cells.has("%s_ENTRY" % area_id):
        world_message.emit("That entrance is not ready.")
        return
    active_area_id = area_id
    _set_exact_overworld_streaming(false)
    if source_area_layers.has(area_id):
        (source_area_layers[area_id] as CanvasItem).visible = true
    area_return_cells["%s_RETURN" % area_id] = return_cell
    var entry_key := "%s_ENTRY" % area_id
    var entry: Vector2i = area_return_cells.get(entry_key, spawn_cell)
    player.position = _cell_center(entry)
    last_player_cell = entry
    _sync_follower_to_player()
    _configure_camera()

func _leave_source_area() -> void:
    if house_transition_active: return
    if active_area_id == "HOUSE" and generated and gameplay_enabled:
        _house_door_transition("exit", _leave_source_area_now)
    else:
        _leave_source_area_now()

func _leave_source_area_now() -> void:
    var old_area := active_area_id
    if source_area_layers.has(old_area):
        (source_area_layers[old_area] as CanvasItem).visible = false
    var fallback := spawn_cell
    if old_area == "HOUSE" and source_landmarks.has("house_door"):
        fallback = Vector2i(source_landmarks["house_door"]) + Vector2i.DOWN
    elif old_area == "CAVE" and source_landmarks.has("cave_door"):
        fallback = Vector2i(source_landmarks["cave_door"]) + Vector2i.DOWN
    var return_cell: Vector2i = area_return_cells.get(
        "%s_RETURN" % old_area, fallback
    )
    if old_area == "HOUSE" and not _house_exit_clear(return_cell):
        # Older saves stored door+DOWN even for side/back entrances.
        for door in [return_cell + Vector2i.UP, active_built_house_door]:
            if String(built_structures.get(door, {}).get("name", "")) != "DOOR": continue
            var outward := _house_door_outward(door)
            if outward != Vector2i.ZERO and _house_exit_clear(door + outward):
                return_cell = door + outward
                break
        if not _house_exit_clear(return_cell):
            if source_area_layers.has(old_area):
                (source_area_layers[old_area] as CanvasItem).show()
            world_message.emit("The outside entrance is blocked.")
            return
    active_area_id = "OVERWORLD"
    _set_exact_overworld_streaming(true)
    player.position = _cell_center(return_cell)
    last_player_cell = return_cell
    _sync_follower_to_player()
    _discover_around(return_cell, DISCOVERY_RADIUS)
    _configure_camera()
    # Interior travel moves the shared player far outside the overworld stream
    # window. Force both exact tile streams back onto the exterior immediately
    # so the mansion cannot appear to vanish after exiting it.
    _refresh_exact_tile_streams()

func _use_interior_interactable(action: String, action_cell: Vector2i = Vector2i.ZERO) -> void:
    if action.begins_with("MINE_POKEMON:"):
        SourceMineRuntime.begin_battle(self, action.trim_prefix("MINE_POKEMON:"))
        return
    if action == "MANSION_SWITCH":
        if _facing_cell() == Vector2i.UP:
            structure_action.emit("MANSION_SWITCH:%d:%d" % [action_cell.x, action_cell.y])
        return
    if action.begins_with("SPECIAL:"):
        _request_event_battle(action.trim_prefix("SPECIAL:"), action_cell)
        return
    if action.begins_with("TRAINER:"):
        var trainer_id := action.trim_prefix("TRAINER:")
        var defeated := event_progress.get("trainer_defeated", {}) as Dictionary
        if bool(defeated.get(trainer_id, false)):
            var old_context := (event_npcs.get(trainer_id, {}) as Dictionary).get("context", {}) as Dictionary
            world_message.emit(String(old_context.get("victory_text", "We already battled.")))
            return
        var npc := event_npcs.get(trainer_id, {}) as Dictionary
        var trainer_context := (npc.get("context", {}) as Dictionary).duplicate(true)
        if not trainer_context.is_empty():
            trainer_context["cell_x"] = action_cell.x
            trainer_context["cell_y"] = action_cell.y
            pending_battle_context = trainer_context.duplicate(true)
            battle_requested.emit(trainer_context)
        return
    if action.begins_with("TRAINER_TIP:"):
        var tip_parts := action.split(":")
        if tip_parts.size() >= 2:
            var tip_index := clampi(int(tip_parts[1]), 0, SourceEventData.TRAINER_TIPS.size() - 1)
            var tip := String(SourceEventData.TRAINER_TIPS[tip_index])
            if preload("res://scripts/source_unown_event.gd").read_sign(self, action_cell):
                environment_system.start_unown_music()
                unown_message.emit(tip.to_upper())
            else:
                trainer_tip_message.emit("TRAINER TIPS! " + tip)
        return
    if action == "GRAVESTONE":
        world_message.emit("The text is too faded to make out...")
        if rng.randi_range(0, 127) == 0:
            _show_mystery_npc(action_cell)
        return
    if action == "ODD_KEYSTONE":
        var keystone_amounts := event_progress.get("keystone_life_force", {}) as Dictionary
        var amount := int(keystone_amounts.get(_cell_key(action_cell), 0))
        structure_action.emit("ODD_KEYSTONE:%d:%d:%d" % [
            action_cell.x, action_cell.y, maxi(0, 107 - amount)
        ])
        return
    if action == "POKE_DOLL":
        item_collected.emit("POKE DOLL")
        world_message.emit("Found a POKE DOLL!")
        _clear_event_cell(action_cell, "pokedoll")
        return
    if action == "REGI_RIGHT":
        SourceRegiRuntime.right_half_action(self, action_cell)
        return
    if action == "REGIGIGAS_GATE":
        var statue := _source_interior_tile_at_world_cell(action_cell)
        if statue != null and statue.name == "cave1_regi1":
            return
        var caught_regis := event_progress.get("regis_caught", []) as Array
        if not SourceEventData.REGI_SPECIES.all(func(s): return caught_regis.has(s)):
            world_message.emit("...")
        else:
            _request_event_battle("regigigas", action_cell)
        return
    if action.begins_with("ITEM:"):
        var item_parts := action.split(":")
        if item_parts.size() == 3:
            var item_name := String(item_parts[1]).to_upper()
            var amount := maxi(1, int(item_parts[2]))
            for _item_index in range(amount):
                item_collected.emit(item_name)
            if item_name != "POKE BALL":
                world_message.emit("You found %s x%d!" % [item_name, amount])
            interior_interactables.erase(action_cell)
            source_interior_mutations[_cell_key(action_cell)] = {"kind": "COLLECTED"}
            SourceMansionRuntime.clear_collected_item(self, action_cell)
            SourceMineRuntime.clear_collected_item(self, action_cell)
            var item_sprite := source_interior_upper_sprites.get(action_cell) as Sprite2D
            if is_instance_valid(item_sprite):
                item_sprite.queue_free()
            source_interior_upper_sprites.erase(action_cell)
            if exact_world_mode and exact_world != null and exact_world.contains_cell(action_cell):
                var exterior_item_tile := exact_world.tile_at(action_cell)
                if exterior_item_tile != null:
                    exterior_item_tile.has_item = ""
                    exterior_item_tile.has_item_amount = 0
                    exterior_item_tile.set_names(exterior_item_tile.name, "")
                    _refresh_exact_pickup_cell(action_cell)
        return
    if action.begins_with("LEGENDARY:"):
        var parts := action.split(":")
        if parts.size() == 3:
            var legacy_context := SourceEventData.event_spec(String(parts[1]))
            if legacy_context.is_empty():
                encounter_requested.emit(String(parts[1]), int(parts[2]))
            else:
                _request_event_battle(String(parts[1]), action_cell)
        return
    if action.begins_with("WILD:"):
        var wild_parts := action.split(":")
        if wild_parts.size() == 3:
            encounter_requested.emit(String(wild_parts[1]), int(wild_parts[2]))
        return
    if action == "FOSSIL_MACHINE":
        if not bool(event_progress.get("fossil_machine_powered", false)) and active_field_move != "POWER":
            world_message.emit("The machine needs an Electric POKEMON using POWER.")
            return
        if not bool(event_progress.get("fossil_machine_powered", false)):
            event_progress["fossil_machine_powered"] = true
            world_message.emit("Electricity surges through the FOSSIL REVIVER!")
        crafting_station_requested.emit("FOSSIL REVIVER")
        return
    if action == "REGI_FORGE":
        active_regi_pedestal_cell = action_cell
        crafting_station_requested.emit("REGI FORGE")
        return
    if action.begins_with("MANSION_LOCK:"):
        structure_action.emit(action)
        return
    if action.begins_with("EXIT_AREA:"):
        _leave_source_area()
        return
    if action.begins_with("GOTO_SOURCE_LAYER:"):
        var transition_parts := action.split(":")
        if transition_parts.size() != 4:
            return
        var target_layer := int(transition_parts[1])
        var source_cell := Vector2i(
            int(transition_parts[2]), int(transition_parts[3])
        )
        var destination := String(source_layer_area_ids.get(target_layer, ""))
        if destination.is_empty():
            world_message.emit("The way forward is blocked.")
            return
        var destination_plan: Dictionary = {}
        for candidate in generated_source_interior_plans:
            if int(candidate.get("layer_index", -1)) == target_layer:
                destination_plan = candidate
                break
        var source_to_local := destination_plan.get("source_to_local", {}) as Dictionary
        if not source_to_local.has(source_cell):
            var closest_entry := Vector2i(2147483647, 2147483647)
            var closest_distance := 2147483647
            for raw_entry in destination_plan.get("entries", []) as Array:
                var entry_source := Vector2i(raw_entry)
                var distance := absi(entry_source.x - source_cell.x) + absi(entry_source.y - source_cell.y)
                if distance < closest_distance and source_to_local.has(entry_source):
                    closest_entry = entry_source
                    closest_distance = distance
            if closest_entry.x == 2147483647:
                world_message.emit("The entrance does not connect to this floor.")
                return
            source_cell = closest_entry
        var outside_return: Vector2i = (_player_cell() if active_area_id == "OVERWORLD"
            else area_return_cells.get("%s_RETURN" % active_area_id, spawn_cell))
        if source_area_layers.has(active_area_id):
            (source_area_layers[active_area_id] as CanvasItem).visible = false
        active_area_id = destination
        _set_exact_overworld_streaming(false)
        if source_area_layers.has(destination):
            (source_area_layers[destination] as CanvasItem).visible = true
        area_return_cells["%s_RETURN" % destination] = outside_return
        var destination_origin: Vector2i = source_area_origins[destination]
        var destination_cell := destination_origin + Vector2i(source_to_local[source_cell])
        player.position = _cell_center(destination_cell)
        last_player_cell = destination_cell
        _sync_follower_to_player()
        _configure_camera()
        return
    if action.begins_with("GOTO_AREA:"):
        var destination := action.trim_prefix("GOTO_AREA:")
        if not source_area_entries.has(destination):
            world_message.emit("The way forward is blocked.")
            return
        var outside_return: Vector2i = (_player_cell() if active_area_id == "OVERWORLD"
            else area_return_cells.get("%s_RETURN" % active_area_id, spawn_cell))
        if source_area_layers.has(active_area_id):
            (source_area_layers[active_area_id] as CanvasItem).visible = false
        active_area_id = destination
        _set_exact_overworld_streaming(false)
        if source_area_layers.has(destination):
            (source_area_layers[destination] as CanvasItem).visible = true
        area_return_cells["%s_RETURN" % destination] = outside_return
        var entry: Vector2i = source_area_entries[destination]
        player.position = _cell_center(entry)
        last_player_cell = entry
        _sync_follower_to_player()
        _configure_camera()
        world_message.emit("You entered %s." % destination.replace("_", " "))
        return
    match action:
        "EXIT_HOUSE", "EXIT_CAVE":
            if action == "EXIT_HOUSE" and built_house_exit_doors.has(action_cell):
                var exterior: Vector2i = built_house_exit_doors[action_cell]
                area_return_cells["HOUSE_RETURN"] = exterior + _house_door_outward(exterior)
            _leave_source_area()
        "BED":
            structure_action.emit("BED")
        "TABLE":
            crafting_station_requested.emit("WORK TABLE")
        "PLANT":
            world_message.emit("A healthy house plant is growing here.")

func _request_event_battle(
        event_id: String,
        action_cell: Vector2i,
        overrides: Dictionary = {}
    ) -> void:
    var completed := event_progress.get("completed", {}) as Dictionary
    if bool(completed.get(event_id, false)):
        world_message.emit("The presence here has faded.")
        return
    var context := SourceEventData.event_spec(event_id)
    if context.is_empty():
        return
    if preload("res://scripts/biome_megas.gd").is_mega(event_id):
        context = preload("res://scripts/biome_megas.gd").context(self, event_id, context)
    context.merge(overrides, true)
    context["cell_x"] = action_cell.x
    context["cell_y"] = action_cell.y
    pending_battle_context = context.duplicate(true)
    battle_requested.emit(context)

func take_pending_battle_context() -> Dictionary:
    var result := pending_battle_context.duplicate(true)
    pending_battle_context.clear()
    return result

func complete_battle_event(result: Dictionary) -> void:
    preload("res://scripts/source_unown_event.gd").complete(self, result)
    var context := result.get("context", {}) as Dictionary
    if context.has("mine_pokemon_id"):
        SourceMineRuntime.complete(self, String(context.mine_pokemon_id), result)
        return
    if context.is_empty():
        return
    var event_id := String(context.get("id", ""))
    var kind := String(context.get("kind", "wild"))
    var outcome := String(result.get("outcome", ""))
    var cell := Vector2i(
        int(context.get("cell_x", -2147483648)),
        int(context.get("cell_y", -2147483648))
    )
    if kind == "attack_egg":
        # Running leaves the egg untouched. Defeating it destroys the egg.
        if outcome == "defeated" and wild_eggs.has(cell):
            var egg_data: Dictionary = wild_eggs[cell]
            var egg_sprite: Sprite2D = egg_data.get("sprite") as Sprite2D
            if is_instance_valid(egg_sprite):
                egg_sprite.queue_free()
            wild_eggs.erase(cell)
            world_message.emit("The EGG was destroyed.")
        return
    if kind == "attack_deployed":
        if outcome in ["captured", "defeated"] and deployed_pokemon.has(cell):
            var deployed: Dictionary = deployed_pokemon[cell]
            var deployed_sprite: Sprite2D = deployed.get("sprite") as Sprite2D
            if is_instance_valid(deployed_sprite):
                deployed_sprite.queue_free()
            deployed_pokemon.erase(cell)
            blocked.erase(cell)
        return
    if kind == "trainer":
        if outcome == "victory":
            var defeated := event_progress.get("trainer_defeated", {}) as Dictionary
            defeated[event_id] = true
            event_progress["trainer_defeated"] = defeated
            world_message.emit(String(context.get("victory_text", "Trainer defeated!")))
        return
    if kind == "wild":
        if outcome == "defeated" and preload("res://scripts/rare_biome_legendaries.gd").HABITATS.has(String(context.get("rare_legendary",""))):
            material_collected.emit("ANCIENTPOWDER", rng.randi_range(3,5))
        if outcome == "captured":
            preload("res://scripts/rare_biome_legendaries.gd").captured(self, String(context.get("rare_legendary", "")))
        if outcome == "ran" and (context.has("overworld_record") or context.has("field_attack_record")):
            var restored = context.get("overworld_record", context.get("field_attack_record", {}))
            if typeof(restored) == TYPE_DICTIONARY:
                var record := (restored as Dictionary).duplicate(true)
                var restore_cell := Vector2i(
                    int(record.get("x", -1)), int(record.get("y", -1))
                )
                if _in_bounds(restore_cell):
                    # Preserve the overworld identity and pursuit state after escaping.
                    if bool(context.get("field_attack", false)):
                        record["aggro_player"] = false
                        record["warned"] = false
                        record["charmed"] = false
                    _add_wild_pokemon(
                        String(record.get("species", "pidgey")),
                        int(record.get("level", 2)),
                        restore_cell,
                        String(record.get("home_biome", biome_at(restore_cell))),
                        int(record.get("id", 0)),
                        record.get("source_record", {}) as Dictionary,
                        record
                    )
        return
    if kind in ["ghost", "fossil"]:
        return
    if outcome not in ["captured", "defeated"]:
        return
    if bool(context.get("regi", false)):
        if outcome != "captured":
            world_message.emit("%s returned to the pedestal." % event_id.to_upper())
            return
        _complete_regi_capture(event_id.to_upper(), cell)
        return
    if event_id == "mewtwo" and outcome == "defeated":
        event_progress["mewtwo_defeated_day"] = _world_day_index()
        source_interior_mutations[_cell_key(cell)] = {
            "kind": "EVENT_COOLDOWN", "event_id": event_id,
            "day": _world_day_index()
        }
        _hide_event_cell(cell)
        world_message.emit("MEWTWO fled. It may return after recovering.")
        return
    var should_clear := (
        outcome == "captured" and bool(context.get("clear_on_capture", true))
    ) or (
        outcome == "defeated" and bool(context.get("clear_on_defeat", true))
    )
    if should_clear:
        var completed := event_progress.get("completed", {}) as Dictionary
        completed[event_id] = true
        event_progress["completed"] = completed
        _clear_event_cell(cell, event_id)

func _complete_regi_capture(species: String, cell: Vector2i) -> void:
    var caught := event_progress.get("regis_caught", []) as Array
    if not caught.has(species):
        caught.append(species)
    event_progress["regis_caught"] = caught
    world_message.emit(String(SourceEventData.REGI_LORE.get(species, "%s was caught." % species)))
    _hide_event_cell(cell)
    if caught.size() < SourceEventData.REGI_SPECIES.size():
        source_interior_mutations[_cell_key(cell)] = {"kind": "REGI_PEDESTAL"}
        _restore_regi_pedestal(cell)
        world_message.emit("A voice whispers: I desire more...")
    else:
        source_interior_mutations[_cell_key(cell)] = {
            "kind": "EVENT_CLEARED", "event_id": "regi_pedestal"
        }
        world_message.emit("My work is complete... REGIGIGAS awakened!")
    SourceRegiRuntime.sync(self)

func _clear_event_cell(cell: Vector2i, event_id: String) -> void:
    if preload("res://scripts/biome_megas.gd").is_mega(event_id):
        preload("res://scripts/biome_megas.gd").captured(self, event_id, cell)
        return
    if event_id == "mega_gengar" and event_progress.has(SourceForestBoss.SAVE_KEY):
        _hide_event_cell(cell)
        return
    source_interior_mutations[_cell_key(cell)] = {
        "kind": "EVENT_CLEARED", "event_id": event_id
    }
    _hide_event_cell(cell)
    if exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
        var tile := exact_world.tile_at(cell)
        if tile != null:
            tile.set_names(tile.name, "")
            tile.has_item = ""
            tile.has_item_amount = 0
            _refresh_exact_streams()

func _hide_event_cell(cell: Vector2i) -> void:
    interior_interactables.erase(cell)
    var sprite := source_interior_upper_sprites.get(cell) as Sprite2D
    if is_instance_valid(sprite):
        sprite.queue_free()
    source_interior_upper_sprites.erase(cell)
    var collision := source_event_collisions.get(cell) as CollisionShape2D
    if is_instance_valid(collision):
        collision.queue_free()
    source_event_collisions.erase(cell)
    blocked.erase(cell)

func _restore_regi_pedestal(cell: Vector2i) -> void:
    interior_interactables[cell] = "REGI_FORGE"
    blocked[cell] = true
    var body := get_node_or_null("InteriorLayer/SourceInteriorCollision") as StaticBody2D
    if body != null:
        var collision := _add_landmark_collision(body, cell.x, cell.y)
        source_event_collisions[cell] = collision
    var area_layer := _source_area_layer_at(cell)
    var texture := SourceWorldData.texture_for("cave1_regipedistal1")
    if area_layer != null and texture != null:
        source_interior_upper_sprites[cell] = _add_source_sprite(
            area_layer, texture, cell, 16
        )

func add_keystone_life_force(cell: Vector2i, available: int) -> int:
    if available <= 0:
        return 0
    var amounts := event_progress.get("keystone_life_force", {}) as Dictionary
    var key := _cell_key(cell)
    var old_amount := clampi(int(amounts.get(key, 0)), 0, 107)
    var used := mini(available, 107 - old_amount)
    var new_amount := old_amount + used
    amounts[key] = new_amount
    event_progress["keystone_life_force"] = amounts
    source_interior_mutations[key] = {
        "kind": "KEYSTONE", "amount": new_amount
    }
    if new_amount >= 107:
        interior_interactables[cell] = "SPECIAL:spiritomb"
        var tile := exact_world.tile_at(cell) if exact_world != null else null
        if tile != null:
            tile.set_names(tile.name, "spiritomb")
            _refresh_exact_streams()
        _show_event_pokemon_sprite(cell, "spiritomb")
        world_message.emit("Yulaaah! The spirits formed SPIRITOMB!")
    else:
        world_message.emit("The spirits entered the keystone... %d remain." % (107 - new_amount))
    return used

func _show_event_pokemon_sprite(cell: Vector2i, species: String) -> void:
    var old_sprite := source_interior_upper_sprites.get(cell) as Sprite2D
    if is_instance_valid(old_sprite):
        old_sprite.queue_free()
    var layer := get_node_or_null("LandmarkLayer") as Node2D
    var texture := PokemonData.texture(species, "overworld")
    if layer == null or texture == null:
        return
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = _cell_center(cell)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(cell, 18)
    _configure_overworld_sprite(sprite)
    layer.add_child(sprite)
    source_interior_upper_sprites[cell] = sprite

func _show_mystery_npc(gravestone_cell: Vector2i) -> void:
    var layer := get_node_or_null("LandmarkLayer") as Node2D
    if layer == null:
        return
    var target := gravestone_cell + Vector2i.DOWN * 2
    if not _is_walkable(target):
        target = gravestone_cell + Vector2i.RIGHT
    var sprite := Sprite2D.new()
    sprite.texture = SOURCE_MYSTERY_NPC
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = _cell_center(target)
    sprite.z_as_relative = false
    sprite.z_index = _depth_z(target, 18)
    layer.add_child(sprite)
    world_message.emit("For a moment, someone is standing beyond the grave...")
    var tween := create_tween()
    tween.tween_interval(1.25)
    tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
    tween.tween_callback(sprite.queue_free)

func _refresh_biome_dig_sites(spread: bool = false) -> void:
    if not exact_world_mode or exact_world == null:
        return
    var day := _world_day_index()
    var identity := exact_world
    var slice_started := Time.get_ticks_usec()
    # Remove only untouched dynamic sites from an older day. A site that was
    # dug already became a normal TILE_NAMES mutation and is never restored.
    for raw_key in source_interior_mutations.keys().duplicate():
        var key := String(raw_key)
        var mutation := source_interior_mutations.get(key, {}) as Dictionary
        if String(mutation.get("kind", "")) != "BIOME_DIG_SITE":
            continue
        if int(mutation.get("day", -1)) == day:
            continue
        var old_cell := _cell_from_key(key)
        var old_tile := exact_world.tile_at(old_cell)
        if old_tile != null and "_cracked" in old_tile.name_upper.to_lower():
            old_tile.set_names(
                String(mutation.get("base", old_tile.name)),
                String(mutation.get("original_upper", ""))
            )
        source_interior_mutations.erase(key)

    var candidates: Dictionary = {}
    for crack_name in FieldMoveData.CRACKED_LOOT:
        candidates[crack_name] = []
    for raw_tile in exact_world.tile_list():
        if spread and Time.get_ticks_usec()-slice_started>=1000:
            await get_tree().process_frame
            if exact_world!=identity or _world_day_index()!=day: return
            slice_started=Time.get_ticks_usec()
        var tile := raw_tile as SourceTile
        if tile == null or tile.is_water or tile.is_lava or tile.is_solid or \
                tile.is_ledge or tile.is_grass or not tile.name_upper.is_empty():
            continue
        var crack := FieldMoveData.dig_site_name(tile)
        if not candidates.has(crack):
            continue
        var cell := SourceWorldData.pixel_to_cell(tile.position)
        if built_structures.has(cell) or landmarks.has(cell) or \
                resource_objects.has(cell) or blocked.has(cell):
            continue
        (candidates[crack] as Array).append(cell)

    var daily_rng := RandomNumberGenerator.new()
    daily_rng.seed = int(world_seed) * 1000003 + day * 9176 + 0xB10E
    for biome_name in candidates.keys():
        var cells := candidates[biome_name] as Array
        if cells.is_empty():
            continue
        # Keep sites sparse but reliably present in every eligible biome.
        var target_count := clampi(int(ceil(float(cells.size()) / 350.0)), 2, 12)
        target_count = mini(target_count, cells.size())
        for _index in range(target_count):
            if cells.is_empty():
                break
            var pick := daily_rng.randi_range(0, cells.size() - 1)
            var cell := cells.pop_at(pick) as Vector2i
            var key := _cell_key(cell)
            if source_interior_mutations.has(key):
                continue
            var tile := exact_world.tile_at(cell)
            if tile == null:
                continue
            var original_upper := tile.name_upper
            var original_base := tile.name
            var crack := FieldMoveData.dig_site_name(tile)
            tile.set_names(original_base, crack)
            source_interior_mutations[key] = {
                "kind":"BIOME_DIG_SITE", "day":day,
                "base":original_base, "original_upper":original_upper, "crack":crack
            }
    _refresh_exact_tile_streams()

func _world_day_index() -> int:
    return int(floor(world_elapsed_seconds / WORLD_DAY_SECONDS))

func _refresh_sand_traps(spread: bool = false) -> void:
    if not exact_world_mode or exact_world == null or get_node_or_null("WildPokemonLayer") == null:
        return
    var day := _world_day_index()
    var identity := exact_world
    var slice_started := Time.get_ticks_usec()
    if int(event_progress.get("sand_trap_refresh_day", -1)) == day:
        return
    event_progress["sand_trap_refresh_day"] = day
    # CycleDayNight scans x=-4..4 and y=-4..3 around authored desert2 markers.
    # Keep source's maximum three traps and 32/256 chance per eligible cell.
    for raw_tile in exact_world.tile_list():
        if spread and Time.get_ticks_usec()-slice_started>=1000:
            await get_tree().process_frame
            if exact_world!=identity or _world_day_index()!=day: return
            slice_started=Time.get_ticks_usec()
        var marker := raw_tile as SourceTile
        if marker == null or marker.name != "desert2_trapinch_spawn":
            continue
        var center := SourceWorldData.pixel_to_cell(marker.position)
        var found := 0
        var candidates: Array[Vector2i] = []
        for yy in range(-4, 4):
            for xx in range(-4, 5):
                var cell := center + Vector2i(xx, yy)
                var tile := exact_world.tile_at(cell)
                if tile == null or not "desert2" in tile.name:
                    continue
                var id := _wild_id_at_cell(cell)
                if id >= 0 and bool(wild_pokemon[id].get("burrowed", false)):
                    found += 1
                elif id < 0 and not built_structures.has(cell) and not deployed_pokemon.has(cell) and not wild_eggs.has(cell):
                    candidates.append(cell)
        for cell in candidates:
            if found >= 3:
                break
            if rng.randi_range(0, 255) >= 32:
                continue
            _add_wild_pokemon("trapinch", 22, cell, "DESERT", 0, {"name":"trapinch", "is_trapping":true, "level":22, "position":cell * TILE})
            if _wild_id_at_cell(cell) >= 0:
                exact_world.tile_at(cell).items["trapinch"] = 1
                found += 1

func _refresh_daily_events(spread: bool = false) -> void:
    var identity := exact_world
    await _refresh_sand_traps(spread)
    if exact_world!=identity: return
    await _refresh_biome_dig_sites(spread)
    if exact_world!=identity: return
    var defeated_day := int(event_progress.get("mewtwo_defeated_day", -1))
    if defeated_day < 0 or _world_day_index() <= defeated_day:
        return
    event_progress["mewtwo_defeated_day"] = -1
    for raw_key in source_interior_mutations.keys():
        var mutation := source_interior_mutations[raw_key] as Dictionary
        if String(mutation.get("kind", "")) != "EVENT_COOLDOWN":
            continue
        var cell := _cell_from_key(String(raw_key))
        source_interior_mutations.erase(raw_key)
        interior_interactables[cell] = "SPECIAL:mewtwo"
        blocked[cell] = true
        var area_layer := _source_area_layer_at(cell)
        var texture := PokemonData.texture("mewtwo", "overworld")
        if area_layer != null and texture != null:
            source_interior_upper_sprites[cell] = _add_source_sprite(
                area_layer, texture, cell, 18
            )
        var body := get_node_or_null("InteriorLayer/SourceInteriorCollision") as StaticBody2D
        if body != null:
            source_event_collisions[cell] = _add_landmark_collision(
                body, cell.x, cell.y
            )
        world_message.emit("A psychic presence has returned to the mansion.")

func complete_regi_forge(species_name: String) -> bool:
    if active_regi_pedestal_cell.x == -2147483648:
        return false
    var species := species_name.strip_edges().to_upper()
    if species not in ["REGISTEEL", "REGIROCK", "REGICE", "REGIDRAGO", "REGIELEKI"]:
        return false
    var caught := event_progress.get("regis_caught", []) as Array
    if caught.has(species):
        world_message.emit("%s has already answered the pedestal." % species)
        return false
    var cell := active_regi_pedestal_cell
    var mutation := {
        "kind": "REGI", "species": species
    }
    source_interior_mutations[_cell_key(cell)] = mutation
    _apply_source_interior_mutation(cell, mutation)
    SourceRegiRuntime.sync(self)
    active_regi_pedestal_cell = Vector2i(-2147483648, -2147483648)
    _show_ecology_emote(player.sprite, "!")
    world_message.emit("%s awakened on the pedestal!" % species)
    return true

func can_awaken_regi(species_name: String) -> bool:
    var species := species_name.strip_edges().to_upper()
    return (
        active_regi_pedestal_cell.x != -2147483648
        and species in SourceEventData.REGI_SPECIES
        and not (event_progress.get("regis_caught", []) as Array).has(species)
    )

## Takes the mansion key off the map for the player who picked it up: in a
## shared world, the host. Guests each take a key of their own and it stays.
func _take_mansion_key(cell: Vector2i) -> void:
    var data: Dictionary = landmarks.get(cell, {})
    if String(data.get("type", "")) != "source_key":
        return
    data["used"] = true
    landmarks[cell] = data
    var key_sprite := data.get("sprite") as Sprite2D
    if is_instance_valid(key_sprite):
        key_sprite.visible = false
    var key_collision := data.get("collision") as CollisionShape2D
    if is_instance_valid(key_collision):
        key_collision.queue_free()
    blocked.erase(cell)
    source_interior_mutations[_cell_key(cell)] = {"kind": "MANSION_KEY_TAKEN"}

func unlock_mansion_door(cell: Vector2i) -> bool:
    if not exact_world_mode or exact_world == null:
        return false
    var tile := exact_world.tile_at(cell)
    if tile == null or tile.name_upper != "pkmnmansion_ext_locked":
        return false
    tile.set_names("pkmnmansion_ext_door", "")
    interior_interactables[cell] = "GOTO_AREA:MANSION_0"
    source_interior_mutations[_cell_key(cell)] = {"kind": "MANSION_DOOR"}
    _refresh_exact_streams()
    return true

func _apply_source_interior_mutation(cell: Vector2i, mutation: Dictionary) -> void:
    var kind := String(mutation.get("kind", ""))
    if kind == "BIOME_DIG_SITE":
        if exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
            var dig_tile := exact_world.tile_at(cell)
            if dig_tile != null:
                dig_tile.set_names(
                    String(mutation.get("base", dig_tile.name)),
                    String(mutation.get("crack", FieldMoveData.dig_site_name(
                        dig_tile, _source_biome_for_tile(dig_tile))))
                )
                _refresh_exact_streams()
        return
    if kind == "TILE_NAMES":
        if exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
            var changed_tile: SourceTile = exact_world.tile_at(cell)
            if changed_tile != null:
                changed_tile.set_names(
                    String(mutation.get("base", changed_tile.name)),
                    String(mutation.get("upper", changed_tile.name_upper)))
                _unblock_ground(cell)
                _refresh_exact_streams()
        return
    if kind == "BERRY_EMPTY":
        if exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
            var berry_tile := exact_world.tile_at(cell)
            if berry_tile != null:
                berry_tile.set_names(
                    berry_tile.name,
                    String(mutation.get("upper", berry_tile.name_upper)).replace(
                        "_full", "_empty")
                )
                _refresh_exact_streams()
        return
    if kind == "MANSION_GATE":
        SourceMansionRuntime.set_gate(self, cell, String(mutation.get("name", "")))
        return
    if kind == "COLLECTED":
        # The host taking the mansion key leaves a key for each guest.
        var key_owner = get_parent().get("coop_game")
        if is_instance_valid(key_owner) and key_owner.active and not key_owner.hosting \
                and exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
            var key_tile := exact_world.tile_at(cell)
            if key_tile != null and key_tile.name_upper == "pokemon_mansion_key":
                return
        SourceMansionRuntime.clear_collected_item(self, cell)
        SourceMineRuntime.clear_collected_item(self, cell)
        interior_interactables.erase(cell)
        var collected_sprite := source_interior_upper_sprites.get(cell) as Sprite2D
        if is_instance_valid(collected_sprite):
            collected_sprite.queue_free()
        source_interior_upper_sprites.erase(cell)
        if exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
            var collected_tile := exact_world.tile_at(cell)
            if collected_tile != null:
                collected_tile.has_item = ""
                collected_tile.has_item_amount = 0
                collected_tile.set_names(collected_tile.name, "")
                _refresh_exact_streams()
        return
    if kind == "MANSION_KEY_TAKEN":
        # Only the host's own key is gone. Guests always find a key there.
        var coordinator = get_parent().get("coop_game")
        if not (is_instance_valid(coordinator) and coordinator.active and not coordinator.hosting):
            _take_mansion_key(cell)
        return
    if kind == "MANSION_DOOR":
        var locked_tile := exact_world.tile_at(cell) if exact_world != null else null
        if locked_tile != null:
            locked_tile.set_names("pkmnmansion_ext_door", "")
            interior_interactables[cell] = "GOTO_AREA:MANSION_0"
            _refresh_exact_streams()
        return
    if kind == "EVENT_CLEARED":
        _hide_event_cell(cell)
        if exact_world_mode and exact_world != null and exact_world.contains_cell(cell):
            var cleared_tile := exact_world.tile_at(cell)
            if cleared_tile != null:
                cleared_tile.set_names(cleared_tile.name, "")
                cleared_tile.has_item = ""
                cleared_tile.has_item_amount = 0
                _refresh_exact_streams()
        return
    if kind == "EVENT_COOLDOWN":
        _hide_event_cell(cell)
        return
    if kind == "REGI_PEDESTAL":
        _hide_event_cell(cell)
        _restore_regi_pedestal(cell)
        return
    if kind == "KEYSTONE":
        var amount := int(mutation.get("amount", 0))
        if amount >= 107:
            interior_interactables[cell] = "SPECIAL:spiritomb"
            var keystone_tile := exact_world.tile_at(cell) if exact_world != null else null
            if keystone_tile != null:
                keystone_tile.set_names(keystone_tile.name, "spiritomb")
                _refresh_exact_streams()
            _show_event_pokemon_sprite(cell, "spiritomb")
        else:
            interior_interactables[cell] = "ODD_KEYSTONE"
        return
    if kind != "REGI":
        return
    var species := String(mutation.get("species", "")).to_upper()
    interior_interactables[cell] = "SPECIAL:%s" % species.to_lower()
    var old_sprite := source_interior_upper_sprites.get(cell) as Sprite2D
    if is_instance_valid(old_sprite):
        old_sprite.queue_free()
    var area_layer := _source_area_layer_at(cell)
    var regi_texture := _regi_overworld_texture(species)
    if area_layer != null and regi_texture != null:
        source_interior_upper_sprites[cell] = _add_source_sprite(
            area_layer, regi_texture, cell, 18
        )

func _source_area_layer_at(cell: Vector2i) -> Node2D:
    for raw_area_id in source_area_rects:
        var area_id := String(raw_area_id)
        var rect: Rect2i = source_area_rects[raw_area_id]
        if rect.has_point(cell):
            return source_area_layers.get(area_id) as Node2D
    return null

func _regi_overworld_texture(species: String) -> Texture2D:
    var region_x: int = {
        "REGIDRAGO": 16, "REGIELEKI": 32, "REGICE": 48,
        "REGIROCK": 64, "REGISTEEL": 80
    }.get(species, -1)
    if region_x < 0:
        return null
    var sheet := load("res://assets/source_0_8_11/tiles/cave1/overworld2.png") as Texture2D
    if sheet == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = sheet
    atlas.region = Rect2(region_x, 0, 16, 16)
    return atlas

func use_escape_rope() -> bool:
    if active_area_id != "OVERWORLD":
        _leave_source_area()
        world_message.emit("The ESCAPE ROPE returned you outside.")
        return true
    var origin: Vector2i = _player_cell()
    var nearest: Vector2i = Vector2i(-1, -1)
    var nearest_distance: int = 1000000
    var directions: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
    ]
    if exact_world_mode and exact_world != null:
        for radius in range(1, 513):
            for offset in range(-radius, radius + 1):
                for cell in [
                        origin + Vector2i(offset, -radius),
                        origin + Vector2i(offset, radius),
                        origin + Vector2i(-radius, offset),
                        origin + Vector2i(radius, offset)
                    ]:
                    if not _is_walkable(cell):
                        continue
                    for direction in directions:
                        if terrain_kind_at(cell + direction) == 0:
                            player.position = _cell_center(cell)
                            _sync_follower_to_player()
                            world_message.emit("The ESCAPE ROPE took you to a nearby shore.")
                            return true
        world_message.emit("There is no reachable shore nearby.")
        return false
    for y in range(map_h):
        for x in range(map_w):
            var cell: Vector2i = Vector2i(x, y)
            if not _is_walkable(cell):
                continue
            var touches_water := false
            for direction in directions:
                var neighbor: Vector2i = cell + direction
                if _in_bounds(neighbor) and int(terrain[neighbor.y][neighbor.x]) == 0:
                    touches_water = true
                    break
            if not touches_water:
                continue
            var distance: int = absi(cell.x - origin.x) + absi(cell.y - origin.y)
            if distance < nearest_distance:
                nearest = cell
                nearest_distance = distance
    if nearest.x < 0:
        world_message.emit("There is no reachable shore nearby.")
        return false
    player.position = _cell_center(nearest)
    _sync_follower_to_player()
    world_message.emit("The ESCAPE ROPE took you to a nearby shore.")
    return true

func _house_sleep_cell_clear(cell: Vector2i) -> bool:
    if not _is_built_house_floor_cell(cell) or deployed_pokemon.has(cell) or wild_eggs.has(cell):
        return false
    if String(built_structures.get(cell + Vector2i.DOWN, {}).get("name", "")) == "BED":
        return false
    var piece := String(built_structures.get(cell, {}).get("name", ""))
    return piece.is_empty() or piece == "FLOOR" or piece.begins_with("CARPET ")

func begin_sleeping_bag(rest_texture: Texture2D = null) -> bool:
    if not active_field_move.is_empty():
        world_message.emit("You cannot set up the SLEEPING BAG while using a Field Move.")
        return false
    if sleeping_bag_sprite != null and is_instance_valid(sleeping_bag_sprite):
        return false

    var context := environment_context()
    if active_area_id != "HOUSE" and bool(context.get("dungeon", false)):
        world_message.emit("It is too dangerous to sleep here.")
        return false

    var cell := _player_cell()
    var right := cell + Vector2i.RIGHT
    var has_room := _house_sleep_cell_clear(cell) and _house_sleep_cell_clear(right) if active_area_id == "HOUSE" else _is_walkable(right)
    if not has_room:
        world_message.emit("There is not enough room for the SLEEPING BAG.")
        return false

    var terrain_names := _ecology_names_at(cell)
    var right_names := _ecology_names_at(right)
    var harsh_words := ["water", "lava", "volcano", "stairs", "snow", "ice", "desert", "sand"]
    for harsh_word in harsh_words:
        if harsh_word in terrain_names or harsh_word in right_names:
            world_message.emit("The terrain is too harsh to sleep here.")
            return false
    if active_area_id != "HOUSE" and (_is_tall_grass_cell(cell) or _is_tall_grass_cell(right)):
        world_message.emit("The grass is too thick to set up the SLEEPING BAG.")
        return false

    for raw_wild in wild_pokemon.values():
        var wild := raw_wild as Dictionary
        var wild_cell: Vector2i = wild.get("cell", Vector2i.ZERO)
        if maxi(absi(wild_cell.x - cell.x), absi(wild_cell.y - cell.y)) <= 2:
            world_message.emit("A wild POKEMON is too close to sleep safely.")
            return false

    respawn_cell = cell
    respawn_house.clear()
    if active_area_id == "HOUSE":
        var floor_index := _built_house_floor_index_for_cell(cell)
        var local := cell - _built_house_floor_origin(floor_index)
        respawn_house = {"x":active_built_house_door.x,"y":active_built_house_door.y,"floor":floor_index,"local_x":local.x,"local_y":local.y}
        respawn_cell = area_return_cells.get("HOUSE_RETURN", active_built_house_door + _house_door_outward(active_built_house_door))
    sleeping_bag_rest_texture = rest_texture
    sleeping_bag_sprite = Sprite2D.new()
    sleeping_bag_sprite.texture = SOURCE_SLEEPING_BAG
    sleeping_bag_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sleeping_bag_sprite.position = _cell_center(cell) + Vector2(4.0, 0.0)
    sleeping_bag_sprite.z_as_relative = false
    sleeping_bag_sprite.z_index = _depth_z(cell) + 2
    add_child(sleeping_bag_sprite)
    sleeping_bag_anim_time = 0.0
    sleeping_bag_sleep_marks.clear()
    for mark_index in range(3):
        var mark := Label.new()
        mark.text = "Z"
        mark.add_theme_font_override("font", SOURCE_PIXEL_FONT)
        mark.add_theme_font_size_override("font_size", 7)
        mark.add_theme_color_override("font_color", Color(0.08, 0.10, 0.08, 1.0))
        mark.position = Vector2(5.0 + mark_index * 3.0, -12.0 - mark_index * 5.0)
        mark.z_index = 3 + mark_index
        sleeping_bag_sprite.add_child(mark)
        sleeping_bag_sleep_marks.append(mark)
    player.visible = true
    set_gameplay_enabled(false)
    play_source_sound("healbed_jingle")
    world_message.emit("You settled into the SLEEPING BAG.")
    return true

func begin_bed_rest(cell: Vector2i) -> bool:
    if active_area_id != "HOUSE" or String(built_structures.get(cell, {}).get("name", "")) != "BED" or is_instance_valid(sleeping_bag_sprite):
        return false
    clear_active_field_move(false)
    bed_rest_active = true
    sleeping_bag_anim_time = 0.0
    sleeping_bag_sprite = Sprite2D.new()
    var head := AtlasTexture.new()
    head.atlas = player.walk_texture
    head.region = Rect2(0, 0, 16, 6)
    sleeping_bag_sprite.texture = head
    sleeping_bag_sprite.centered = false
    sleeping_bag_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sleeping_bag_sprite.position = Vector2(cell * TILE) + Vector2(0, -12)
    sleeping_bag_sprite.z_as_relative = false
    # Interior furniture receives its final depth in _refresh_shell_attachment.
    # Keep the source six-pixel head above the actual bed, not its old depth.
    var bed_sprite := built_structures[cell].get("sprite") as Sprite2D
    sleeping_bag_sprite.z_index = bed_sprite.z_index + 1 if is_instance_valid(bed_sprite) else _depth_z(cell, 25)
    add_child(sleeping_bag_sprite)
    for i in range(3):
        var mark := Label.new()
        mark.text = "Z"
        mark.add_theme_font_override("font", SOURCE_PIXEL_FONT)
        mark.add_theme_font_size_override("font_size", 7)
        mark.add_theme_color_override("font_color", Color(0.08,0.1,0.08))
        mark.position = Vector2(5 + i * 3, -12 - i * 5)
        sleeping_bag_sprite.add_child(mark)
        sleeping_bag_sleep_marks.append(mark)
    player.visible = false
    set_gameplay_enabled(false)
    return true

func end_sleeping_bag() -> void:
    bed_rest_active = false
    for mark in sleeping_bag_sleep_marks:
        if is_instance_valid(mark):
            mark.queue_free()
    sleeping_bag_sleep_marks.clear()
    if sleeping_bag_sprite != null and is_instance_valid(sleeping_bag_sprite):
        sleeping_bag_sprite.queue_free()
    sleeping_bag_sprite = null
    sleeping_bag_rest_texture = null
    sleeping_bag_anim_time = 0.0
    player.visible = true
    player.set("facing", Vector2.DOWN)
    if player.has_method("_update_sprite_frame"):
        player.call("_update_sprite_frame", false)
    set_gameplay_enabled(true)

func _spawn_puddle_step_effect(cell: Vector2i) -> void:
    if active_area_id != "OVERWORLD" or not exact_world_mode or exact_world == null:
        return
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null or _source_biome_for_tile(tile) != "BEACH":
        return
    var high_tide: bool = "_tidalwater" in tile.name.to_lower()
    var puddle_name: String = tile.name if "_puddle1" in tile.name else tile.name_upper
    if not high_tide:
        if "_puddle1" not in puddle_name or "_tidaloff" not in puddle_name:
            return
        # Low-tide puddle physics follows the same authored per-pixel water
        # mask as the locked reflection system. Stepping on the dry portion of
        # a puddle tile must not create a water splash.
        var local_feet: Vector2i = Vector2i(8, 10)
        if not SourceWorldData.puddle_reflects_at(puddle_name, local_feet):
            return

    var frames: SpriteFrames = SpriteFrames.new()
    frames.add_animation("splash")
    frames.set_animation_loop("splash", false)
    frames.set_animation_speed("splash", 7.0 if high_tide else 5.0)
    for frame_index in range(3):
        var frame: AtlasTexture = AtlasTexture.new()
        frame.atlas = SOURCE_PUDDLE_SPLASH
        frame.region = Rect2(frame_index * TILE, 0, TILE, TILE)
        frames.add_frame("splash", frame)

    var splash: AnimatedSprite2D = AnimatedSprite2D.new()
    splash.sprite_frames = frames
    splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    splash.position = _cell_center(cell) + Vector2(0.0, 4.0)
    splash.z_as_relative = false
    splash.z_index = _depth_z(cell) + 3
    add_child(splash)
    splash.animation_finished.connect(splash.queue_free)
    splash.play("splash")

func _update_tidal_wade_visual() -> void:
    var show_wade: bool = false
    var cell: Vector2i = _player_cell()
    var tile: SourceTile = null
    if active_area_id == "OVERWORLD" and exact_world_mode and exact_world != null:
        tile = exact_world.tile_at(cell)
        if tile != null:
            show_wade = (
                active_field_move not in ["FLY", "SURF"]
                and "_tidalwater" in tile.name.to_lower()
            )
    if not show_wade:
        if is_instance_valid(tide_wade_base):
            tide_wade_base.visible = false
        if is_instance_valid(tide_wade_ripple):
            tide_wade_ripple.visible = false
        return

    # Source-style wading: the actor itself stays fully visible and only the
    # shallow-water foreground crosses the feet/lower legs. Repainting the base
    # beach tile in front of the actor caused the disappearing/covered player.
    if is_instance_valid(tide_wade_base):
        tide_wade_base.visible = false
    if not is_instance_valid(tide_wade_ripple):
        tide_wade_ripple = Sprite2D.new()
        tide_wade_ripple.name = "TideWadeWater"
        tide_wade_ripple.centered = false
        tide_wade_ripple.region_enabled = true
        tide_wade_ripple.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tide_wade_ripple.z_as_relative = false
        add_child(tide_wade_ripple)

    var base_stream: Node = get_node_or_null("GroundLayer/ExactBaseTileStream")
    var animation_tick: int = int(floor(world_elapsed_seconds * 60.0))
    if base_stream != null:
        animation_tick = int(base_stream.get("source_animation_tick"))
    const WADE_FRONT_HEIGHT := 8
    var wade_source_y := TILE - WADE_FRONT_HEIGHT
    var tide_frame: int = posmod(int(animation_tick / 19), 2)
    tide_wade_ripple.texture = SOURCE_TIDAL_WATER
    tide_wade_ripple.region_rect = Rect2(
        tide_frame * TILE, wade_source_y, TILE, WADE_FRONT_HEIGHT)
    tide_wade_ripple.position = Vector2(
        cell.x * TILE, cell.y * TILE + wade_source_y)
    tide_wade_ripple.modulate = Color(1, 1, 1, 0.50)
    tide_wade_ripple.z_index = player.z_index + 5
    tide_wade_ripple.visible = true
    player.visible = true

func set_gameplay_enabled(enabled: bool) -> void:
    gameplay_enabled = enabled and not is_instance_valid(stool_seated_sprite)
    player.set_physics_process(gameplay_enabled)
    # The player also moves from _process when locked to drawn frames.
    player.set_process(gameplay_enabled)

func set_environment_battle_active(active: bool) -> void:
    if environment_system != null and is_instance_valid(environment_system):
        environment_system.set_battle_suspended(active)

func play_source_sound(sound_name: String) -> void:
    if environment_system != null and is_instance_valid(environment_system):
        environment_system.play_source_sound(sound_name)

func environment_day_seconds() -> float:
    return WORLD_DAY_SECONDS

func environment_player_position() -> Vector2:
    return player.position

func environment_camera_center() -> Vector2:
    var camera := player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        return camera.get_screen_center_position()
    return player.position

func environment_context() -> Dictionary:
    if active_area_id == "HOUSE":
        return {"area_id":"HOUSE", "indoors":true, "dungeon":false, "route_name":"", "route_type":"", "biome":"INTERIOR"}
    var cell := _player_cell()
    var route_name := ""
    var dungeon := false
    if active_area_id == "OVERWORLD":
        if exact_world_mode and exact_world != null:
            var route := exact_world.route_at(cell)
            if route != null:
                route_name = route.name
                dungeon = route.is_dungeon
        else:
            route_name = String(habitat_routes.get(cell, ""))
            dungeon = SourceRouteData.is_dungeon(route_name)
    else:
        var route_data := _active_source_interior_route()
        route_name = String(route_data.get("name", ""))
        dungeon = SourceRouteData.is_dungeon(route_name)
    return {
        "area_id": active_area_id,
        "indoors": active_area_id != "OVERWORLD",
        "dungeon": dungeon,
        "route_name": route_name,
        "route_type": SourceRouteData.route_type(route_name),
        "biome": biome_at(cell) if active_area_id == "OVERWORLD" else "INTERIOR"
    }

func environment_tile_flags() -> Dictionary:
    var cell := _player_cell()
    var result := {
        "tidal": false,
        "dry_tidal": false,
        "puddle": false,
        "sand": terrain_kind_at(cell) == 1
    }
    if String(built_structures.get(cell, {}).get("name", "")) == "BRIDGE": return result
    if active_area_id != "OVERWORLD":
        return result
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        if tile != null:
            var beach_surface := _is_beach_tidal_tile(tile) or (
                _source_biome_for_tile(tile) in ["BEACH", "BEACH_BLACKSAND"]
            )
            result["tidal"] = _is_beach_tidal_tile(tile) and "_tidalwater" in tile.name
            result["dry_tidal"] = _is_beach_tidal_tile(tile) and "_tidaloff" in tile.name
            result["puddle"] = "puddle1" in tile.name
            result["sand"] = (
                "sand" in tile.name
                or "desert" in tile.name
                or "beach" in tile.biome
            )
    return result

func environment_nearby_lava_cells(radius: int = 12) -> Array:
    var result: Array = []
    if (
            active_area_id != "OVERWORLD"
            or not exact_world_mode
            or exact_world == null
        ):
        return result
    var center := _player_cell()
    for y in range(center.y - radius, center.y + radius + 1):
        for x in range(center.x - radius, center.x + radius + 1):
            var cell := Vector2i(x, y)
            var tile := exact_world.tile_at(cell)
            if tile != null and (
                    tile.is_lava
                    or "lava" in tile.name
                    or "lava" in tile.name_upper
                ):
                result.append(cell)
    return result

func environment_structure_texture(
        build_name: String, frame: int
    ) -> Texture2D:
    var source := structure_textures.get(build_name) as Texture2D
    if source == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    if build_name == "CAMPFIRE":
        atlas.region = Rect2(posmod(frame, 2) * 16, 0, 16, 20)
    elif build_name == "TORCH":
        atlas.region = Rect2(posmod(frame, 2) * 16, 60, 16, 20)
    elif build_name == "CHIMNEY":
        atlas.region = Rect2(
            posmod(frame, 4) * 64,
            0,
            64,
            minf(32.0, source.get_height())
        )
    else:
        return _structure_display_texture(build_name, frame)
    return atlas

func environment_debug_snapshot() -> Dictionary:
    if environment_system == null or not is_instance_valid(environment_system):
        return {}
    var result := environment_system.debug_snapshot()
    result["low_tide"] = low_tide_active
    result["day"] = _world_day_index()
    return result

func _is_beach_tidal_tile(tile: SourceTile) -> bool:
    if tile == null:
        return false
    var route_name := "" if tile.route_belongs_to == null else \
        tile.route_belongs_to.name.to_lower()
    var biome := _source_biome_for_tile(tile)
    var beach_identity := biome in ["BEACH", "BEACH_BLACKSAND"] or \
        route_name.begins_with("beach")
    var tile_name := tile.name.to_lower()
    var authored_tide := "_tidalwater" in tile_name or "_tidaloff" in tile_name
    if not authored_tide:
        return false
    # The original generator also uses *_tidalwater for non-ocean systems
    # (mountain-bottom water and wooded-lake shores).  Ocean tide must therefore
    # remain tied to an authored beach biome/route; accepting an untagged suffix
    # caused the inland pale squares and tide fingers seen in the screenshots.
    return beach_identity

func _handle_biome_entry(cell: Vector2i) -> void:
    if active_area_id != "OVERWORLD":
        return
    var biome := biome_at(cell)
    if biome != "DESERT":
        return
    var entries := event_progress.get("biome_first_entries", {}) as Dictionary
    if bool(entries.get("DESERT", false)):
        return
    entries["DESERT"] = true
    event_progress["biome_first_entries"] = entries
    _show_ecology_emote(player.sprite, "!")
    world_message.emit("The desert is dangerous. Be careful as you explore.")

func _is_renewable_ashen_contact(cell: Vector2i) -> bool:
    if not exact_world_mode or exact_world == null:
        return false
    var center := exact_world.tile_at(cell)
    if center == null or _source_biome_for_tile(center) != "VOLCANO":
        return false
    if center.is_water or center.is_lava:
        return false
    var has_lava := false
    var has_water := false
    for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
        var neighbor := exact_world.tile_at(cell + offset)
        if neighbor == null:
            continue
        has_lava = has_lava or neighbor.is_lava or "lava" in neighbor.name.to_lower()
        has_water = has_water or (neighbor.is_water and not neighbor.is_lava)
    return has_lava and has_water

func _is_low_tide_time() -> bool:
    var fraction := fmod(world_elapsed_seconds, WORLD_DAY_SECONDS) / WORLD_DAY_SECONDS
    return (
        (fraction >= LOW_TIDE_START_1 and fraction < LOW_TIDE_END_1)
        or fraction >= LOW_TIDE_START_2
    )

func _tide_cell_adjoins_permanent_water(cell: Vector2i) -> bool:
    if exact_world == null:
        return false
    # Tide fronts advance from true shoreline contact. Diagonal-only contact
    # seeded isolated inland cells and produced the checkerboard/patchy look.
    var offsets: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
    ]
    for offset in offsets:
        var neighbor: SourceTile = exact_world.tile_at(cell + offset)
        if neighbor == null:
            continue
        if neighbor.is_water and not _is_beach_tidal_tile(neighbor):
            return true
    return false

func _nearest_native_ground_name(cell: Vector2i) -> String:
    if exact_world == null:
        return ""
    for radius in range(1, 6):
        for yy in range(cell.y - radius, cell.y + radius + 1):
            for xx in range(cell.x - radius, cell.x + radius + 1):
                if maxi(absi(xx - cell.x), absi(yy - cell.y)) != radius:
                    continue
                var candidate: SourceTile = exact_world.tile_at(Vector2i(xx, yy))
                if candidate == null or candidate.is_water or candidate.is_lava:
                    continue
                var candidate_name := candidate.name.to_lower()
                if "_tidalwater" in candidate_name or "_tidaloff" in candidate_name:
                    continue
                if candidate.is_solid or candidate.is_ledge or candidate.name.is_empty():
                    continue
                return candidate.name
    return ""

func _redraw_exact_tide_streams(changed_cells: Array = []) -> void:
    # Tide changes alter visual/source identities, not the player's collision
    # window. Queue one redraw for the current frame instead of force-rebuilding
    # both streamed layers and hundreds of collision shapes for every tide band.
    for node_path in [
            "GroundLayer/ExactBaseTileStream",
            "DecorLayer/ExactUpperTileStream"]:
        var stream := get_node_or_null(node_path)
        if stream != null:
            if changed_cells.is_empty(): stream.invalidate_tiles()
            else: stream.queue_tide_refresh(changed_cells)
    for cell in changed_cells:
        SourceTile.resident_changed_cells.erase(cell*TILE)
    # Beach tidal suffixes change shallow-water visuals, not solid/water
    # collision flags. Keep the already resident collision cells untouched.
    if is_instance_valid(reflection_layer):
        reflection_layer.queue_redraw()

func _build_tide_transition_bands(lowering: bool) -> Array:
    tide_transition_tiles.clear()
    if not tide_topology_bands.is_empty():
        # Retain the cached cell lists. Resolve and validate cells as each small
        # portion changes, rather than rescanning every beach on one frame.
        var ordered: Array = []
        for i in range(tide_topology_bands.size()):
            var at := tide_topology_bands.size()-1-i if lowering else i
            if not tide_topology_bands[at].is_empty(): ordered.append(tide_topology_bands[at])
        return ordered

    var tidal_cells: Dictionary = {}
    var changing_cells: Dictionary = {}
    var restored_non_beach_tide := false
    var restored_ground_cells: Array[Vector2i] = []
    for raw_tile in exact_world.tile_list():
        var tile: SourceTile = raw_tile as SourceTile
        if tile == null:
            continue
        # *_tidaloff is runtime-only; the 0.8.11 generator emits water-state
        # tidal identities. Older port builds could incorrectly include untagged
        # cells in the ocean tide. sand4_tidal* is specifically the generated
        # ocean-beach family, so an untagged/non-beach sand4 cell is contamination
        # and must become the nearby native ground (this removes the pale inland
        # squares). sand3_tidal* is also used by legitimate mountain/wooded-lake
        # shore systems, so a stale dry sand3 cell is restored to water instead.
        var tile_name_lower := tile.name.to_lower()
        var is_beach_tide := _is_beach_tidal_tile(tile)
        var cell: Vector2i = SourceWorldData.pixel_to_cell(tile.position)
        if not is_beach_tide and "sand4_tidal" in tile_name_lower:
            var native_ground := _nearest_native_ground_name(cell)
            if not native_ground.is_empty():
                tile.set_names(native_ground, tile.name_upper)
                restored_ground_cells.append(cell)
                restored_non_beach_tide = true
            continue
        if not is_beach_tide and "_tidaloff" in tile_name_lower:
            tile.set_names(tile.name.replace("_tidaloff", "_tidalwater"), tile.name_upper)
            restored_non_beach_tide = true
            continue
        if not is_beach_tide:
            continue
        tidal_cells[cell] = tile
        var needs_change: bool = (
            (lowering and "_tidalwater" in tile.name)
            or (not lowering and "_tidaloff" in tile.name)
        )
        if needs_change:
            changing_cells[cell] = tile
            tide_transition_tiles.append(tile)
    if not restored_ground_cells.is_empty():
        _recoastify_exact_cells(restored_ground_cells)
    if restored_non_beach_tide:
        _redraw_exact_tide_streams()

    # The source footage shows every tidal beach beginning its transition at
    # the same time, while each individual beach still advances as a coherent
    # shoreline. Build connected tidal components, normalize each component's
    # ocean distance into the same set of phases, then merge equal phases.
    # This prevents a distant beach with a larger inland depth from delaying
    # the water movement around the player.
    # Connected beach water must stay edge-connected while the tide moves.
    # Cardinal propagation prevents diagonal checkerboard islands.
    var offsets: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
    ]
    var phase_bands: Array = []
    var topology_bands: Array = []
    for _phase_index in range(TIDE_TRANSITION_STEPS):
        phase_bands.append([])
        topology_bands.append([])
    var cleanup_cells: Array[Vector2i] = []

    var unvisited: Dictionary = {}
    for raw_cell in tidal_cells.keys():
        unvisited[raw_cell] = true

    while not unvisited.is_empty():
        var remaining: Array = unvisited.keys()
        var start_cell: Vector2i = Vector2i(remaining[0])
        var component: Array[Vector2i] = []
        var component_queue: Array[Vector2i] = [start_cell]
        var component_lookup: Dictionary = {}
        unvisited.erase(start_cell)
        component_lookup[start_cell] = true

        var component_index: int = 0
        while component_index < component_queue.size():
            var component_cell: Vector2i = component_queue[component_index]
            component_index += 1
            component.append(component_cell)
            for offset in offsets:
                var neighbor_cell: Vector2i = component_cell + offset
                if not tidal_cells.has(neighbor_cell) or component_lookup.has(neighbor_cell):
                    continue
                component_lookup[neighbor_cell] = true
                unvisited.erase(neighbor_cell)
                component_queue.append(neighbor_cell)

        var distances: Dictionary = {}
        var distance_queue: Array[Vector2i] = []
        for component_cell in component:
            if _tide_cell_adjoins_permanent_water(component_cell):
                distances[component_cell] = 0
                distance_queue.append(component_cell)
        if distance_queue.is_empty():
            # A tidal beach must be cardinally connected to permanent source
            # water. A stale disconnected *_tidaloff cell is still rendered as
            # pale beach sand, which produced the white checkerboard patches seen
            # inland. Remove the entire orphan tidal component by restoring a
            # nearby native non-tidal ground identity instead of merely drying it.
            for component_cell in component:
                var orphan_tile: SourceTile = tidal_cells.get(component_cell) as SourceTile
                if orphan_tile == null:
                    continue
                var native_ground := _nearest_native_ground_name(component_cell)
                if native_ground.is_empty():
                    continue
                orphan_tile.set_names(native_ground, orphan_tile.name_upper)
                cleanup_cells.append(component_cell)
            continue

        var distance_index: int = 0
        var max_distance: int = 0
        while distance_index < distance_queue.size():
            var distance_cell: Vector2i = distance_queue[distance_index]
            distance_index += 1
            var next_distance: int = int(distances[distance_cell]) + 1
            for offset in offsets:
                var neighbor_cell: Vector2i = distance_cell + offset
                if not component_lookup.has(neighbor_cell) or distances.has(neighbor_cell):
                    continue
                distances[neighbor_cell] = next_distance
                max_distance = maxi(max_distance, next_distance)
                distance_queue.append(neighbor_cell)

        for component_cell in component:
            var distance: int = int(distances.get(component_cell, 0))
            var normalized: float = (
                0.0 if max_distance <= 0
                else float(distance) / float(max_distance)
            )
            var incoming_band_index: int = clampi(
                roundi(normalized * float(TIDE_TRANSITION_STEPS - 1)),
                0, TIDE_TRANSITION_STEPS - 1
            )
            (topology_bands[incoming_band_index] as Array).append(component_cell)
            if not changing_cells.has(component_cell):
                continue
            var band_index := (
                TIDE_TRANSITION_STEPS - 1 - incoming_band_index
                if lowering else incoming_band_index
            )
            (phase_bands[band_index] as Array).append(changing_cells[component_cell])

    if not cleanup_cells.is_empty():
        _recoastify_exact_cells(cleanup_cells)
        _redraw_exact_tide_streams()
    tide_topology_bands = topology_bands
    var bands: Array = []
    for raw_band in phase_bands:
        var band: Array = raw_band as Array
        if not band.is_empty():
            bands.append(band)
    return bands

func _apply_tide_band(band: Array, lowering: bool) -> Array[Vector2i]:
    var changed_cells: Array[Vector2i] = []
    for raw_tile in band:
        var tile: SourceTile = exact_world.tile_at(raw_tile) if raw_tile is Vector2i else raw_tile as SourceTile
        if tile == null or not _is_beach_tidal_tile(tile):
            continue
        var next_name: String = tile.name
        if lowering and "_tidalwater" in next_name:
            next_name = next_name.replace("_tidalwater", "_tidaloff")
        elif not lowering and "_tidaloff" in next_name:
            next_name = next_name.replace("_tidaloff", "_tidalwater")
        else:
            continue
        tile.set_names(next_name, tile.name_upper)
        changed_cells.append(SourceWorldData.pixel_to_cell(tile.position))
    if not changed_cells.is_empty():
        # The suffix swap changes only tidal surface state. Shoreline activity is
        # derived live from neighboring cells, so rebuilding 3x3 coast metadata
        # for every transition band is redundant and caused the tide hitch.
        _redraw_exact_tide_streams(changed_cells)
    return changed_cells

func _update_tide_state(force: bool = false, delta: float = 0.0) -> void:
    if not exact_world_mode or exact_world == null:
        tide_initialized = true
        low_tide_active = false
        if is_instance_valid(tide_wade_base):
            tide_wade_base.visible = false
        if is_instance_valid(tide_wade_ripple):
            tide_wade_ripple.visible = false
        return
    var desired_low_tide: bool = _is_low_tide_time()
    var frontier_seconds := TIDE_RETREAT_FRONTIER_SECONDS if desired_low_tide else TIDE_FRONTIER_SECONDS
    var was_initialized: bool = tide_initialized
    if force or not tide_initialized or desired_low_tide != tide_target_low:
        tide_target_low = desired_low_tide
        tide_transition_bands = _build_tide_transition_bands(desired_low_tide)
        # Defensive invariant: transition tiles are beach-tidal only. The band
        # builder already enforces this; keep the guard here too so no future
        # caller can accidentally expand tide physics beyond the beach.
        for tile in tide_transition_tiles:
            if not _is_beach_tidal_tile(tile):
                continue
        tide_transition_band_index = 0
        tide_band_cursor = 0
        tide_transition_accumulator = frontier_seconds if force else 0.0
    low_tide_active = desired_low_tide
    tide_initialized = true
    if tide_transition_band_index >= tide_transition_bands.size():
        return

    tide_transition_accumulator += delta
    if not force and tide_band_cursor == 0 and tide_transition_accumulator < frontier_seconds:
        return

    var first_changed_band: bool = tide_transition_band_index == 0
    if force:
        while tide_transition_band_index < tide_transition_bands.size():
            _apply_tide_band(
                tide_transition_bands[tide_transition_band_index] as Array,
                desired_low_tide
            )
            tide_transition_band_index += 1
        tide_transition_accumulator = 0.0
    else:
        if tide_band_cursor == 0:
            tide_transition_accumulator = maxf(0.0,tide_transition_accumulator-frontier_seconds)
        var band: Array = tide_transition_bands[tide_transition_band_index]
        var deadline := Time.get_ticks_usec()+1200
        while tide_band_cursor < band.size():
            var end := mini(tide_band_cursor+24,band.size())
            _apply_tide_band(band.slice(tide_band_cursor,end),desired_low_tide)
            tide_band_cursor=end
            if Time.get_ticks_usec()>=deadline: break
        if tide_band_cursor>=band.size():
            tide_band_cursor=0
            tide_transition_band_index+=1

    if gameplay_enabled and not restoring_saved_tiles and is_visible_in_tree() and bool(get_parent().get("started")) and not bool(get_parent().get("generating")) and first_changed_band and was_initialized and not force and \
            world_elapsed_seconds - last_tide_message_seconds >= \
            TIDE_MESSAGE_COOLDOWN_SECONDS:
        last_tide_message_seconds = world_elapsed_seconds
        world_message.emit(
            "The tide is receding." if desired_low_tide
            else "The tide is coming in."
        )

func _tide_tile_is_frontier(tile: SourceTile, lowering: bool) -> bool:
    var offsets: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
    if not lowering:
        offsets.append_array([
            Vector2i(-1, -1), Vector2i(1, -1),
            Vector2i(-1, 1), Vector2i(1, 1)])
    var cell := SourceWorldData.pixel_to_cell(tile.position)
    for offset in offsets:
        var neighbor := exact_world.tile_at(cell + offset)
        if neighbor == null:
            continue
        if lowering:
            if not neighbor.is_water and not neighbor.is_tidal:
                return true
        elif neighbor.name == "water2" or _is_beach_tidal_tile(neighbor):
            return true
    return false

func _refresh_exact_tile_streams() -> void:
    map_art_revision += 1
    var changed_cells: Array = []
    for key in SourceTile.resident_changed_cells:
        if source_tiles.has(key): changed_cells.append(Vector2i(key / TILE))
    var base_stream := get_node_or_null(
        "GroundLayer/ExactBaseTileStream")
    var upper_stream := get_node_or_null(
        "DecorLayer/ExactUpperTileStream")
    if base_stream != null:
        if base_stream.has_method("refresh_now"):
            base_stream.call("refresh_changed_tiles", changed_cells)
        else:
            base_stream.invalidate_tiles()
    if upper_stream != null:
        if upper_stream.has_method("refresh_now"):
            upper_stream.call("refresh_changed_tiles", changed_cells)
        else:
            upper_stream.invalidate_tiles()
    if is_instance_valid(reflection_layer):
        reflection_layer.queue_redraw()
    var collision_stream := get_node_or_null(
        "ExactCollisionStream") as SourceChunkCollisionStreamer
    if collision_stream != null:
        collision_stream.refresh_cells(changed_cells)
    if is_instance_valid(reflection_layer) and reflection_layer.has_method("refresh_cells"):
        reflection_layer.refresh_cells(changed_cells)
    SourceTile.resident_changed_cells.clear()
    var canopy := get_node_or_null("TreeCanopyOverlay")
    if canopy != null: canopy.queue_redraw()

func _recoastify_exact_cells(changed_cells: Array[Vector2i]) -> void:
    var targets: Dictionary = {}
    for changed in changed_cells:
        for y in range(changed.y - 1, changed.y + 2):
            for x in range(changed.x - 1, changed.x + 2):
                targets[Vector2i(x, y)] = true
    for raw_cell in targets.keys():
        var cell := raw_cell as Vector2i
        var tile := exact_world.tile_at(cell)
        if tile == null:
            continue
        tile.shore_ocean = ""
        tile.shore_tidal = ""
        if tile.is_water or "ledges" in tile.name_upper or tile.name == "ice2" or \
                "bridge" in tile.name or "waterfall" in tile.name:
            continue
        var names := ["W", "E", "S", "N", "SW", "NE", "SE", "NW"]
        var offsets := [
            Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
            Vector2i(-1, -1), Vector2i(1, 1),
            Vector2i(1, -1), Vector2i(-1, 1)]
        var ocean := ""
        var tidal := ""
        for index in range(offsets.size()):
            var neighbor := exact_world.tile_at(cell + offsets[index])
            if neighbor == null or neighbor.name == "water6":
                continue
            var direction := String(names[index])
            if not tile.is_tidal and neighbor.is_tidal:
                if not _shore_diagonal_already_present(tidal, direction):
                    tidal += "[" + direction + "]"
                continue
            if not neighbor.is_water or \
                    _shore_diagonal_already_present(ocean, direction):
                continue
            ocean += "[" + direction + "]"
            tidal += "[" + direction + "]"
        tile.shore_ocean = ocean
        tile.shore_tidal = tidal

func _shore_diagonal_already_present(existing: String, direction: String) -> bool:
    if direction.length() < 2:
        return false
    for index in range(direction.length()):
        if "[" + direction.substr(index, 1) + "]" in existing:
            return true
    return false

func _permitted_ledge_direction(tile: SourceTile) -> Vector2i:
    if tile == null:
        return Vector2i.ZERO
    # The brown horizontal grass ledge is a one-way drop: screen-down is legal
    # and screen-up is blocked.  Keep this explicit instead of mirroring its
    # `_down` source suffix back upward.
    var ledge_key: String = (tile.name + " " + tile.name_upper).to_lower()
    if "ledge_grass_down" in ledge_key:
        return Vector2i.DOWN
    # The exact world deliberately preserves Java's Y-up cell coordinates on
    # Godot's Y-down canvas. Mirror only vertical movement directions here so
    # an authored downhill "up" edge is crossed toward screen-down, and vice
    # versa. Horizontal directions require no conversion.
    return {
        "up":Vector2i.DOWN, "down":Vector2i.UP,
        "left":Vector2i.LEFT, "right":Vector2i.RIGHT
    }.get(tile.ledge_dir, Vector2i.ZERO) as Vector2i

func try_pre_move_field_jump(before: Vector2, movement_direction: Vector2):
    if active_field_move != "RIDE" or not exact_world_mode or \
            exact_world == null or active_area_id != "OVERWORLD":
        return null
    if player.has_method("is_ledge_jump_active") and \
            bool(player.call("is_ledge_jump_active")):
        return null
    var direction := Vector2i.ZERO
    if absf(movement_direction.x) > absf(movement_direction.y):
        direction = Vector2i(1 if movement_direction.x > 0.0 else -1, 0)
    elif absf(movement_direction.y) > 0.01:
        direction = Vector2i(0, 1 if movement_direction.y > 0.0 else -1)
    if direction == Vector2i.ZERO:
        return null
    var start_cell := Vector2i(
        floori(before.x / float(TILE)), floori(before.y / float(TILE)))
    var obstacle_cell := start_cell + direction
    var obstacle: SourceTile = exact_world.tile_at(obstacle_cell)
    if obstacle == null or not (obstacle.is_ledge or obstacle.is_bottom_mtn_layer):
        return null
    if obstacle.is_ledge:
        var obstacle_key := (obstacle.name + " " + obstacle.name_upper).to_lower()
        if "ledge_grass_down" in obstacle_key:
            var permitted := _permitted_ledge_direction(obstacle)
            if permitted == Vector2i.ZERO or direction != permitted:
                return null
    # Source RIDE hops a low edge as one continuous motion. Mountain rims can be
    # wider than one source cell, so take the first ordinary clear landing up to
    # three cells ahead instead of colliding and leaving the mount in front.
    for distance in range(2, 4):
        var landing_cell := start_cell + direction * distance
        if not _ledge_jump_landing_is_clear(landing_cell):
            continue
        var landing_position := _cell_center(landing_cell)
        if player.has_method("begin_ledge_jump_visual"):
            player.call("begin_ledge_jump_visual", before - landing_position)
        _set_fly_shadow_active(true)
        play_source_sound("ledge1")
        return landing_position
    return null

func _ledge_jump_landing_is_clear(cell: Vector2i) -> bool:
    if not _is_walkable(cell):
        return false
    var tile := exact_world.tile_at(cell) if exact_world != null else null
    if tile == null or tile.is_water or tile.is_ledge:
        return false
    return (
        not built_structures.has(cell)
        and not landmarks.has(cell)
        and not resource_objects.has(cell)
        and not deployed_pokemon.has(cell)
        and not wild_eggs.has(cell)
        and _wild_id_at_cell(cell) < 0
    )

func constrain_player_motion(before: Vector2, after: Vector2) -> Vector2:
    var before_cell := Vector2i(floori(before.x / TILE), floori(before.y / TILE))
    var after_cell := Vector2i(floori(after.x / TILE), floori(after.y / TILE))
    # Holes block ground movement, including DIG's terrain bypass.
    if active_field_move != "FLY" and before_cell != after_cell:
        if active_area_id == "HOUSE" and bool(built_house_decorations.get(_built_house_paint_key(after_cell), {}).get("dig_hole", false)):
            return before
        if active_area_id == "OVERWORLD" and exact_world != null:
            var hole_tile: SourceTile = exact_world.tile_at(after_cell)
            # Empty outdoor holes use their visible outline in the physics layer.
            if hole_tile != null and hole_tile.name_upper.begins_with("hole1") and not hole_tile.has_item.is_empty():
                return before
    if active_field_move == "DIG" and before_cell != after_cell:
        if active_area_id in ["OVERWORLD", "HOUSE"]:
            if not _is_walkable(after_cell): return before
        else:
            var interior_dig_tile := _source_interior_tile_at_world_cell(after_cell)
            if interior_dig_tile == null or interior_dig_tile.is_solid or interior_dig_tile.is_ledge or not interior_dig_tile.has_item.is_empty(): return before
        if exact_world != null and active_area_id == "OVERWORLD":
            var dig_tile: SourceTile = exact_world.tile_at(after_cell)
            if dig_tile == null or dig_tile.is_ledge or not dig_tile.has_item.is_empty(): return before
    if active_field_move in ["CUT", "BUILD", "DIG", "HEADBUTT", "SMASH"] and before_cell != after_cell:
        var structure: Dictionary = built_structures.get(after_cell, {})
        if bool(structure.get("solid", false)) or String(structure.get("name", "")) in ["ROOF", "WALL", "INTERIOR WALL"]:
            return before
    if active_field_move != "FLY" and before_cell != after_cell:
        if String(built_structures.get(after_cell, {}).get("name", "")) == "BED" or String(built_structures.get(after_cell + Vector2i.DOWN, {}).get("name", "")) == "BED":
            return before
    if before_cell != after_cell and active_area_id not in ["OVERWORLD", "HOUSE", "CAVE"]:
        # Source PlayerMoving cannot enter a missing interior tile. Sparse maze
        # plans have empty space between corridors, not additional floor.
        if _source_interior_tile_at_world_cell(after_cell) == null:
            return before
    # Wild eggs are solid overworld objects. Walking/RIDE may approach from any
    # side but may never enter the egg's cell; interaction remains face-it + A.
    # FLY keeps its existing terrain/object bypass semantics.
    if active_field_move != "FLY" and before_cell != after_cell and \
            wild_eggs.has(after_cell):
        return before
    # Visible overworld Pokemon are solid actors. Walking/RIDE into their
    # sprite must stop at the occupied cell instead of starting a contact battle.
    # Burrowed Pokemon remain hidden step encounters and grass encounters are
    # handled separately by the unchanged grass encounter path.
    if active_field_move != "FLY" and before_cell != after_cell:
        if deployed_pokemon.has(after_cell):
            var resident: Dictionary = deployed_pokemon[after_cell]
            if not resident.has("house_door") or _house_pokemon_visible(resident):
                _try_push_fenced_pokemon(after_cell, after_cell - before_cell)
                return before
        if active_field_move in ["CUT", "HEADBUTT"] and (_is_cuttable_grass_cell(after_cell) or _cut_helper_tree_cell(after_cell)):
            return before
        # A SMASH Pokemon stops against a rock, tombstone or statue as a CUT
        # Pokemon stops against a tree, so that A then smashes what it faces.
        if active_field_move == "SMASH" and _smash_helper_rock_cell(after_cell):
            return before
        var blocking_wild_id := _wild_id_at_cell(after_cell)
        if blocking_wild_id >= 0:
            var blocking_wild: Dictionary = wild_pokemon.get(blocking_wild_id, {})
            if not bool(blocking_wild.get("burrowed", false)):
                _try_push_fenced_pokemon(after_cell, after_cell - before_cell)
                return before
    # FLY is the sole terrain bypass. RIDE still moves faster, but it may not
    # climb back up a one-way cliff or mountain edge.
    if active_field_move == "FLY" or not exact_world_mode or \
            exact_world == null or active_area_id != "OVERWORLD":
        return after
    if before_cell == after_cell:
        return after
    var movement := after - before
    # The direction is the sign of the step, however small. Rounding the step
    # to a whole pixel first turned a short one (a light push on the stick, or
    # sliding along the edge) into "no direction", and the ledge refused the
    # jump: sometimes it let the player down and sometimes it did not.
    var direction := Vector2i.ZERO
    if absf(movement.x) > absf(movement.y):
        direction = Vector2i((1 if movement.x > 0.0 else -1 if movement.x < 0.0 else 0), 0)
    else:
        direction = Vector2i(0, (1 if movement.y > 0.0 else -1 if movement.y < 0.0 else 0))
    var from_tile := exact_world.tile_at(before_cell)
    var to_tile := exact_world.tile_at(after_cell)

    var crosses_one_way_edge := (
        (from_tile != null and (from_tile.is_ledge or from_tile.is_bottom_mtn_layer))
        or (to_tile != null and (to_tile.is_ledge or to_tile.is_bottom_mtn_layer))
    )
    # Do not assume screen-UP is uphill. The source tile's authored ledge_dir
    # determines the legal downhill direction for every mountain edge.

    # Diagonal input remains valid on open ground, but cannot cut across the
    # corner of a one-way edge and bypass its cardinal direction.
    var crossed_cells := after_cell - before_cell
    if crosses_one_way_edge and absi(crossed_cells.x) + absi(crossed_cells.y) > 1:
        return before

    # Entering a directional ledge automatically performs the source-style
    # two-cell hop. The far cell must be ordinary, unoccupied ground.
    if to_tile != null and to_tile.is_ledge:
        var permitted := _permitted_ledge_direction(to_tile)
        var to_ledge_key: String = (to_tile.name + " " + to_tile.name_upper).to_lower()
        var strict_brown_drop: bool = "ledge_grass_down" in to_ledge_key
        if (strict_brown_drop or active_field_move != "RIDE") and \
                (permitted == Vector2i.ZERO or direction != permitted):
            return before
        var landing_cell := after_cell + direction
        if not _ledge_jump_landing_is_clear(landing_cell):
            return before
        var landing_position := _cell_center(landing_cell)
        if player.has_method("begin_ledge_jump_visual"):
            player.call(
                "begin_ledge_jump_visual", before - landing_position
            )
        play_source_sound("ledge1")
        return landing_position

    for tile in [from_tile, to_tile]:
        if tile == null or not tile.is_ledge:
            continue
        var permitted := _permitted_ledge_direction(tile)
        var ledge_key: String = (String(tile.name) + " " + String(tile.name_upper)).to_lower()
        var strict_brown_drop_edge: bool = "ledge_grass_down" in ledge_key
        if (strict_brown_drop_edge or active_field_move != "RIDE") and \
                permitted != Vector2i.ZERO and direction != permitted:
            return before
    return after

func _player_cell() -> Vector2i:
    return Vector2i(
        int(floor(player.position.x / TILE)),
        int(floor(player.position.y / TILE))
    )

func _facing_cell() -> Vector2i:
    var facing: Vector2 = player.get("facing")
    if abs(facing.x) > abs(facing.y):
        return Vector2i(1 if facing.x > 0.0 else -1, 0)
    return Vector2i(0, 1 if facing.y > 0.0 else -1)

func _find_safe_spawn() -> void:
    var largest_component := _largest_land_component()
    var candidates_by_biome: Dictionary = {}
    for cell in largest_component:
        var biome := biome_at(cell)
        # Never begin a new save on a shoreline or a tiny isolated patch.
        if biome in ["BEACH", "OCEAN", "RIVER"]:
            continue
        if not _has_spawn_clearance(cell, 2):
            continue
        var open_neighbors := 0
        for direction in [
                Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
            ]:
            if _is_spawn_walkable(cell + direction):
                open_neighbors += 1
        if open_neighbors < 3:
            continue
        if not candidates_by_biome.has(biome):
            candidates_by_biome[biome] = []
        (candidates_by_biome[biome] as Array).append(cell)

    var available_biomes: Array[String] = []
    for desired in WORLD_BIOMES + ["DEEP_FOREST", "GRAVEYARD", "OASIS"]:
        if candidates_by_biome.has(desired):
            available_biomes.append(desired)

    if not available_biomes.is_empty():
        starting_biome = available_biomes[
            rng.randi_range(0, available_biomes.size() - 1)
        ]
        var candidates: Array = candidates_by_biome[starting_biome]
        spawn_cell = candidates[rng.randi_range(0, candidates.size() - 1)]
        return

    if not largest_component.is_empty():
        spawn_cell = largest_component[
            rng.randi_range(0, largest_component.size() - 1)
        ]
        starting_biome = biome_at(spawn_cell)
        return

    spawn_cell = Vector2i(map_w / 2, map_h / 2)
    starting_biome = biome_at(spawn_cell)

func _largest_land_component() -> Array[Vector2i]:
    var visited: Dictionary = {}
    var largest: Array[Vector2i] = []
    var directions: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
    ]
    for y in range(2, map_h - 2):
        for x in range(2, map_w - 2):
            var start := Vector2i(x, y)
            if visited.has(start) or not _is_spawn_walkable(start):
                continue
            var component: Array[Vector2i] = []
            var queue: Array[Vector2i] = [start]
            var queue_index := 0
            visited[start] = true
            while queue_index < queue.size():
                var cell := queue[queue_index]
                queue_index += 1
                component.append(cell)
                for direction in directions:
                    var neighbor := cell + direction
                    if (
                            not _in_bounds(neighbor)
                            or visited.has(neighbor)
                            or not _is_spawn_walkable(neighbor)
                        ):
                        continue
                    visited[neighbor] = true
                    queue.append(neighbor)
            if component.size() > largest.size():
                largest = component
    return largest

func _has_spawn_clearance(cell: Vector2i, radius: int) -> bool:
    if (
            cell.x < radius + 2
            or cell.y < radius + 2
            or cell.x >= map_w - radius - 2
            or cell.y >= map_h - radius - 2
        ):
        return false
    for y in range(cell.y - radius, cell.y + radius + 1):
        for x in range(cell.x - radius, cell.x + radius + 1):
            if not _is_spawn_walkable(Vector2i(x, y)):
                return false
    return true

func _is_spawn_walkable(cell: Vector2i) -> bool:
    if not _in_bounds(cell) or terrain[cell.y][cell.x] == 0:
        return false
    var source_tile: Dictionary = source_tiles.get(cell, {})
    return not bool(source_tile.get("solid", false))

func biome_at(cell: Vector2i) -> String:
    if exact_world_mode and exact_world != null:
        var source_tile := exact_world.tile_at(cell)
        return "OCEAN" if source_tile == null else _source_biome_for_tile(source_tile)
    if not _in_bounds(cell) or biomes.is_empty():
        return "OCEAN"
    return String(biomes[cell.y][cell.x])

func _canonical_source_biome(raw_biome: String) -> String:
    var key := raw_biome.strip_edges().to_upper().replace("-", "_")
    if SOURCE_BIOME_ALIASES.has(key):
        return String(SOURCE_BIOME_ALIASES[key])
    return key.replace(" ", "_")

func _source_biome_for_tile(tile: SourceTile) -> String:
    var raw_biome := _canonical_source_biome(tile.biome)
    var route_name := ""
    if tile.route_belongs_to != null:
        route_name = tile.route_belongs_to.name.to_lower()

    # Rivers reuse wooded_lake_water1 in the Java source. Wooded-lake cells
    # carry their explicit biome while river cuts keep the biome they crossed,
    # so this distinction is recoverable without changing generator output.
    if tile.is_water and route_name == "wooded_lake_water1":
        if raw_biome == "WOODED_LAKE":
            return "WOODED_LAKE"
        return "RIVER"

    if not raw_biome.is_empty():
        return raw_biome

    # Route fallbacks cover source tiles that intentionally have no biome tag.
    # Check authored water/sub-biome routes before generic water so beach and
    # river ambience/ecology do not collapse into OCEAN.
    if not route_name.is_empty():
        if route_name == "ocean1" or "ocean" in route_name:
            return "OCEAN"
        if "beach" in route_name or "tidal" in route_name:
            return "BEACH"
        if "wooded_lake" in route_name:
            return "WOODED_LAKE"
        if "graveyard" in route_name:
            return "GRAVEYARD"
        if "volcano" in route_name:
            return "VOLCANO"
        if "oasis" in route_name:
            return "OASIS"
        if "desert" in route_name or "ruins" in route_name or "sand_pit" in route_name:
            return "DESERT"
        if "snow" in route_name or "tundra" in route_name:
            return "SNOW"
        if "mountain" in route_name or "cave" in route_name:
            return "MOUNTAIN"
        if "savanna" in route_name:
            return "SAVANNA"
        if "deep" in route_name:
            return "DEEP_FOREST"
        if "forest" in route_name:
            return "FOREST"
    if tile.is_water:
        return "OCEAN"
    return "FOREST"

func is_cell_discovered(cell: Vector2i) -> bool:
    if active_area_id != "OVERWORLD" and source_area_rects.has(active_area_id):
        return get_map_bounds().has_point(cell)
    return discovered_cells.has(_cell_key(cell))

func reveal_player_area() -> void:
    if active_area_id != "OVERWORLD":
        return
    last_player_cell = _player_cell()
    _sync_follower_to_player()
    _discover_around(last_player_cell, DISCOVERY_RADIUS)

func _discover_around(cell: Vector2i, radius: int) -> void:
    for y in range(cell.y - radius, cell.y + radius + 1):
        for x in range(cell.x - radius, cell.x + radius + 1):
            var test := Vector2i(x, y)
            if not _in_bounds(test):
                continue
            if Vector2(test - cell).length_squared() <= float(radius * radius + 2):
                discovered_cells[_cell_key(test)] = true

func map_color_for_cell(cell: Vector2i) -> Color:
    if not _in_bounds(cell):
        return Color.BLACK
    var terrain_kind := terrain_kind_at(cell)
    if terrain_kind == 0:
        return Color(0.27, 0.55, 0.78, 1.0)
    if terrain_kind == 1:
        return Color(0.82, 0.78, 0.56, 1.0)

    # Preserve small-scale source-map detail instead of painting every land
    # cell as a biome-only blob. Object/upper-tile colors intentionally sit
    # over the terrain color, matching the visual hierarchy of the world.
    if exact_world_mode and exact_world != null:
        var map_tile := exact_world.tile_at(cell)
        if map_tile != null:
            var map_key := (map_tile.name + " " + map_tile.name_upper).to_lower()
            if "fence" in map_key or "gate" in map_key:
                return Color(0.40, 0.25, 0.10, 1.0)
            if "gravestone" in map_key or "grave" in map_key:
                return Color(0.34, 0.36, 0.38, 1.0)
            if "rock" in map_key or "stone" in map_key or "mountain" in map_key or "ledge" in map_key:
                return Color(0.45, 0.43, 0.39, 1.0)
            if "tree" in map_key:
                return Color(0.08, 0.34, 0.08, 1.0)
            if "bush" in map_key or "grass2" in map_key or "grass3" in map_key or "grass4" in map_key:
                return Color(0.18, 0.49, 0.12, 1.0)
            if "flower" in map_key:
                return Color(0.82, 0.36, 0.56, 1.0)
            if "house" in map_key or "building" in map_key or "door" in map_key:
                return Color(0.62, 0.37, 0.18, 1.0)

    if built_structures.has(cell):
        return Color(0.62, 0.37, 0.18, 1.0)
    match biome_at(cell):
        "DEEP_FOREST":
            return Color(0.10, 0.31, 0.10, 1.0)
        "GRAVEYARD":
            return Color(0.30, 0.38, 0.27, 1.0)
        "FOREST":
            return Color(0.22, 0.52, 0.18, 1.0)
        "SAVANNA":
            return Color(0.58, 0.69, 0.18, 1.0)
        "MOUNTAIN":
            return Color(0.47, 0.36, 0.18, 1.0)
        "VOLCANO":
            return Color(0.40, 0.24, 0.19, 1.0)
        "DESERT", "OASIS":
            return Color(0.91, 0.76, 0.29, 1.0)
        "BEACH":
            return Color(0.88, 0.82, 0.53, 1.0)
        "SNOW":
            return Color(0.86, 0.94, 0.98, 1.0)
        "WOODED_LAKE":
            return Color(0.37, 0.68, 0.29, 1.0)
        "RIVER":
            return Color(0.27, 0.55, 0.78, 1.0)
        _:
            return Color(0.30, 0.62, 0.22, 1.0)

func _is_walkable(cell: Vector2i) -> bool:
    if String(built_structures.get(cell, {}).get("name", "")) == "BRIDGE":
        return not blocked.has(cell)
    if active_area_id == "HOUSE":
        var coordinator=get_parent().get("coop_game")
        var online_wild=is_instance_valid(coordinator) and coordinator.active and coordinator.wild.simulating
        if not online_wild:return built_house_interior_cells.has(cell) and not blocked.has(cell) and String(built_structures.get(cell + Vector2i.DOWN, {}).get("name", "")) != "BED"
    if exact_world_mode and exact_world != null:
        return exact_world.contains_cell(cell) and not exact_world.is_solid(cell) and not blocked.has(cell)
    if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
        return false
    return terrain[cell.y][cell.x] != 0 and not blocked.has(cell)

func terrain_kind_at(cell: Vector2i) -> int:
    if String(built_structures.get(cell, {}).get("name", "")) == "BRIDGE":
        return 2
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        if tile == null or tile.is_water or SourceWorldData.is_water(tile.name):
            return 0
        if "sand" in tile.name or "desert" in tile.name or "beach" in tile.biome:
            return 1
        return 2
    if not _in_bounds(cell) or terrain.is_empty():
        return 0
    return int(terrain[cell.y][cell.x])

func get_map_bounds() -> Rect2i:
    if active_area_id != "OVERWORLD" and source_area_rects.has(active_area_id):
        return _interior_map_bounds()
    if exact_world_mode and exact_world != null:
        return exact_world_bounds
    return Rect2i(Vector2i.ZERO, Vector2i(map_w, map_h))

func battle_terrain_at(cell: Vector2i) -> String:
    var kind := terrain_kind_at(cell)
    if kind == 0:
        return "AQUATIC"
    if kind == 1:
        return "SANDY"
    return "GRASSY"

func _add_block_collision(body: StaticBody2D, x: int, y: int) -> CollisionShape2D:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(TILE, TILE)

    var node := CollisionShape2D.new()
    node.shape = shape
    node.position = _cell_center(Vector2i(x, y))
    body.add_child(node)
    return node

func _add_landmark_collision(
        body: StaticBody2D,
        x: int,
        y: int
    ) -> CollisionShape2D:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(TILE, TILE)

    var node := CollisionShape2D.new()
    node.shape = shape
    node.position = _cell_center(Vector2i(x, y))
    body.add_child(node)
    return node

func _cell_center(cell: Vector2i) -> Vector2:
    return Vector2(
        cell.x * TILE + TILE * 0.5,
        cell.y * TILE + TILE * 0.5
    )

func _configure_camera() -> void:
    # Apply on entry, exit, floor changes, load and whiteout without moving any
    # saved house/furniture coordinates or changing the player's collision mask.
    var dungeon_body := get_node_or_null("InteriorLayer/SourceInteriorCollision") as StaticBody2D
    if dungeon_body != null:
        dungeon_body.collision_layer = 0 if active_area_id == "HOUSE" else 1
    var house_body := get_node_or_null("BuiltHouseCollision") as StaticBody2D
    if house_body != null:
        house_body.collision_layer = 1 if active_area_id == "HOUSE" else 0
    var camera := player.get_node_or_null("Camera2D") as Camera2D
    if camera == null:
        return

    if player.has_method("set_streamed_overworld_depth"):
        player.call(
            "set_streamed_overworld_depth",
            # A built house orders its furniture round the player the same
            # way the open map does; without this the player was simply
            # drawn over everything in the room.
            exact_world_mode and active_area_id in ["OVERWORLD", "HOUSE"]
        )

    if active_area_id == "HOUSE" or active_field_move == "BUILD":
        camera.limit_left = -10000000
        camera.limit_top = -10000000
        camera.limit_right = 10000000
        camera.limit_bottom = 10000000
        camera.offset = Vector2.ZERO
    elif (
            exact_world_mode
            and exact_world != null
            and active_area_id == "OVERWORLD"
        ):
        # GenIsland1 is centered around Java pixel coordinate (0, 0), so its
        # renderer cells extend into negative X and Y. The compatibility map
        # starts at (0, 0), but applying those old limits here clamps the camera
        # away from a valid negative-coordinate spawn and leaves only the clear
        # canvas visible after generation.
        camera.limit_left = exact_world_bounds.position.x * TILE
        camera.limit_top = exact_world_bounds.position.y * TILE
        camera.limit_right = exact_world_bounds.end.x * TILE
        camera.limit_bottom = exact_world_bounds.end.y * TILE
    elif active_area_id == "FOSSIL_LAB":
        # The lab shares a sparse plane with the mansion. Plane-edge camera
        # clamping pushes this tiny room off-screen. Follow the actor here.
        camera.limit_left = -10000000
        camera.limit_top = -10000000
        camera.limit_right = 10000000
        camera.limit_bottom = 10000000
    elif source_area_rects.has(active_area_id):
        var area_rect: Rect2i = source_area_rects[active_area_id]
        camera.limit_left = area_rect.position.x * TILE
        camera.limit_top = area_rect.position.y * TILE
        camera.limit_right = area_rect.end.x * TILE
        camera.limit_bottom = area_rect.end.y * TILE
    elif active_area_id == "HOUSE":
        camera.limit_left = (map_w + 8) * TILE
        camera.limit_top = 4 * TILE
        camera.limit_right = (map_w + 28) * TILE
        camera.limit_bottom = 16 * TILE
    elif active_area_id == "CAVE":
        camera.limit_left = (map_w + 8) * TILE
        camera.limit_top = 20 * TILE
        camera.limit_right = (map_w + 28) * TILE
        camera.limit_bottom = 32 * TILE
    else:
        camera.limit_left = 0
        camera.limit_top = 0
        camera.limit_right = map_w * TILE
        camera.limit_bottom = map_h * TILE
    # The source game follows the player on exact pixels. Smoothing a
    # nearest-neighbour scene introduces visible cadence judder while walking.
    camera.position_smoothing_enabled = false
    camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE if bool(player.get("frame_locked")) else Camera2D.CAMERA2D_PROCESS_PHYSICS
    camera.zoom = _pixel_exact_zoom(camera_zoom_level)

## The chosen zoom, nudged so one tile covers a whole number of screen pixels.
## At 45% on a 1080p screen a tile is 43.2 pixels wide; the leftover fraction
## shows up as thin stray lines between tiles, most visibly over open water.
## The nudge is under one percent and cannot be seen.
func _pixel_exact_zoom(level: float) -> Vector2:
    var screen_scale := get_viewport().get_stretch_transform().get_scale().x if is_inside_tree() else 0.0
    if screen_scale <= 0.0:
        return Vector2(level, level)
    var exact := maxf(1.0, roundf(float(TILE) * level * screen_scale)) / (float(TILE) * screen_scale)
    return Vector2(exact, exact)

func adjust_camera_zoom(direction: int) -> int:
    if not preload("res://scripts/game_options.gd").enabled("zoom"):
        return roundi(camera_zoom_level * 100.0)
    camera_zoom_level = clampf(
        camera_zoom_level + float(direction) * CAMERA_ZOOM_STEP,
        CAMERA_ZOOM_MIN,
        CAMERA_ZOOM_MAX
    )
    var camera := player.get_node_or_null("Camera2D") as Camera2D
    if camera != null:
        camera.zoom = _pixel_exact_zoom(camera_zoom_level)
    return roundi(camera_zoom_level * 100.0)

func _clear_generated_world() -> void:
    for name in [
            "GroundLayer", "DecorLayer", "TallGrassLayer",
            "TallGrassFrontLayer", "LandmarkLayer", "WildPokemonLayer",
            "WildEggLayer", "InteriorLayer", "WorldCollision", "RouteLayer",
            "ExactCollisionStream", "ExactReflectionLayer", "TreeCanopyOverlay"
        ]:
        var node := get_node_or_null(name)
        if node != null:
            node.queue_free()

    # Let queued children disappear before repopulating.
    await get_tree().process_frame

func _legacy_source_interior_cell(cell: Vector2i) -> Vector2i:
    for area_id in source_area_rects:
        if not String(area_id).begins_with("INTERIOR_"): continue
        var rect: Rect2i = source_area_rects[area_id]
        if rect.has_point(cell):
            return Vector2i(cell.x, rect.position.y + rect.end.y - 1 - cell.y)
    return cell

func migrate_source_interior_position(position_value: Vector2, state: Dictionary) -> Vector2:
    if exact_world != null and not exact_world.regi_relocated_cells.is_empty():
        var return_key := "%s_RETURN" % active_area_id
        var old_return: Vector2i = area_return_cells.get(return_key, spawn_cell)
        if exact_world.regi_relocated_cells.has(old_return):
            area_return_cells[return_key] = exact_world.regi_relocated_cells[old_return]
        if active_area_id == "OVERWORLD":
            var old_cell := Vector2i((position_value / float(TILE)).floor())
            if exact_world.regi_relocated_cells.has(old_cell):
                return position_value + Vector2(Vector2i(exact_world.regi_relocated_cells[old_cell]) - old_cell) * TILE
    if active_area_id == "HOUSE" and not state.has("built_house_origins"):
        return position_value + Vector2(built_house_interior_origin - Vector2i(map_w + 9, 5)) * TILE
    if int(state.get("source_interior_layout_version", 0)) > 0 or active_area_id in ["OVERWORLD", "HOUSE", "CAVE"]:
        return position_value
    var cell := Vector2i(floori(position_value.x / TILE), floori(position_value.y / TILE))
    var converted := _legacy_source_interior_cell(cell)
    if not state.has("source_return_x"):
        area_return_cells["%s_RETURN" % active_area_id] = _recover_source_dungeon_return(active_area_id, converted)
    return position_value + Vector2((converted - cell) * TILE)

func _source_interior_tile_at_world_cell(cell: Vector2i) -> SourceTile:
    for plan in generated_source_interior_plans:
        var area_id := String(plan["id"])
        if not source_area_origins.has(area_id): continue
        var local_cell: Vector2i = cell - Vector2i(source_area_origins[area_id])
        if (plan["tiles"] as Dictionary).has(local_cell):
            return plan["tiles"][local_cell] as SourceTile
    return null

func _recover_source_dungeon_return(area_id: String, interior_cell: Vector2i = Vector2i(-2147483648, -2147483648)) -> Vector2i:
    var tile := _source_interior_tile_at_world_cell(interior_cell)
    var route_name := ""
    if tile != null and tile.route_belongs_to != null:
        route_name = tile.route_belongs_to.name
    var wanted: Array[String] = []
    if route_name == "regi_cave1" or area_id == "REGI_CHAMBER":
        wanted = ["GOTO_SOURCE_LAYER:90:"]
    elif route_name == "fossil_lab1" or area_id == "FOSSIL_LAB":
        wanted = ["GOTO_AREA:FOSSIL_LAB"]
    elif route_name == "ruins1_inner" or area_id == "RUINS_0":
        wanted = ["GOTO_SOURCE_LAYER:99:"]
    elif route_name == "pkmnmansion1" or area_id == "MANSION_0":
        wanted = ["MANSION_LOCK:", "GOTO_AREA:MANSION_0"]
    for cell in interior_interactables:
        if exact_world == null or not exact_world.contains_cell(cell): continue
        var action := String(interior_interactables[cell])
        var matches := false
        for prefix in wanted:
            if action.begins_with(prefix): matches = true
        if not matches: continue
        for offset in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
            var outside: Vector2i = cell + offset
            if not exact_world.is_solid(outside) and not interior_interactables.has(outside):
                return outside
    return spawn_cell

# Both map views use the active floor's actual rendered source sprites.
# Revealing an interior never modifies the overworld discovery dictionary.
var interior_map_cache_key: Array = []
var interior_map_cache: Image
var interior_map_bounds_key: Array = []
var interior_map_bounds_cache := Rect2i()

func _interior_map_bounds() -> Rect2i:
    var plane: Rect2i = source_area_rects[active_area_id]
    if active_area_id == "HOUSE":
        return plane.grow(1)
    var here := _source_interior_tile_at_world_cell(_player_cell())
    var route: SourceRoute = here.route_belongs_to if here != null else null
    # Authored pickup/door cells can have no route. Keep the current floor's
    # map bounds while crossing them, rather than showing the shared plane.
    if route == null and interior_map_bounds_key.size() == 3 and interior_map_bounds_key[0] == active_area_id and interior_map_bounds_key[1] == plane:
        return interior_map_bounds_cache
    if route == null:
        var nearest_distance := INF
        for plan in generated_source_interior_plans:
            var origin: Vector2i = source_area_origins.get(String(plan.id), Vector2i.ZERO)
            if origin != plane.position: continue
            for local_cell in plan.tiles:
                var candidate: SourceTile = plan.tiles[local_cell]
                if candidate.route_belongs_to == null: continue
                var distance := Vector2(origin+Vector2i(local_cell)-_player_cell()).length_squared()
                if distance < nearest_distance:
                    nearest_distance = distance
                    route = candidate.route_belongs_to
    var key: Array = [active_area_id, plane, route.name if route != null else ""]
    if key == interior_map_bounds_key:
        return interior_map_bounds_cache
    var result := Rect2i()
    for plan in generated_source_interior_plans:
        var origin: Vector2i = source_area_origins.get(String(plan.id), Vector2i.ZERO)
        if origin != plane.position:
            continue
        for local_cell in plan.tiles:
            var tile: SourceTile = plan.tiles[local_cell]
            if route != null and (tile.route_belongs_to == null or tile.route_belongs_to.name != route.name):
                continue
            var cell: Vector2i = origin + Vector2i(local_cell)
            result = Rect2i(cell, Vector2i.ONE) if result.size == Vector2i.ZERO else result.merge(Rect2i(cell, Vector2i.ONE))
    interior_map_bounds_key = key
    interior_map_bounds_cache = result if result.size != Vector2i.ZERO else plane
    return interior_map_bounds_cache

func interior_map_image(bounds: Rect2i) -> Image:
    if active_area_id == "OVERWORLD" or not source_area_layers.has(active_area_id):
        return null
    var key: Array = [active_area_id, bounds, built_structures.hash(),
        built_house_floor_tiles.size(), source_interior_mutations.hash()]
    if key == interior_map_cache_key and interior_map_cache != null:
        return interior_map_cache
    var image := Image.create(bounds.size.x * 4, bounds.size.y * 4, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.025, 0.035, 0.03, 1.0))
    var layer: Node2D = source_area_layers[active_area_id]
    var sprites := layer.find_children("*", "Sprite2D", true, false)
    for cell in built_structures:
        if bounds.has_point(Vector2i(cell)):
            var structure_sprite = built_structures[cell].get("sprite")
            if is_instance_valid(structure_sprite) and structure_sprite is Sprite2D and not sprites.has(structure_sprite):
                sprites.append(structure_sprite)
    sprites.sort_custom(func(a: Node, b: Node) -> bool: return a.z_index < b.z_index)
    var previews: Dictionary = {}
    for raw_sprite in sprites:
        var sprite := raw_sprite as Sprite2D
        if not sprite.visible or sprite.texture == null:
            continue
        var rect := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
        var position_value := to_local(sprite.global_position) + sprite.offset
        if sprite.centered:
            position_value -= rect.size * sprite.scale * 0.5
        var destination := Vector2i(((position_value - Vector2(bounds.position * TILE)) / 4.0).round())
        var size := Vector2i((rect.size * sprite.scale.abs() / 4.0).round())
        if size.x <= 0 or size.y <= 0 or not Rect2i(Vector2i.ZERO, image.get_size()).intersects(Rect2i(destination, size)):
            continue
        var preview_key: Array = [sprite.texture, rect, size, sprite.flip_h, sprite.flip_v]
        if not previews.has(preview_key):
            var preview := sprite.texture.get_image().get_region(Rect2i(rect))
            if sprite.flip_h: preview.flip_x()
            if sprite.flip_v: preview.flip_y()
            preview.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
            previews[preview_key] = preview
        image.blend_rect(previews[preview_key], Rect2i(Vector2i.ZERO, size), destination)
    interior_map_cache_key = key
    interior_map_cache = image
    return image


func _canonical_house_door(door: Vector2i) -> Vector2i:
    var cells: Array = _built_house_state(door).get("cells", [])
    # Origin records retain creation order even when a door is cut/rebuilt.
    # Looking through structure order instead can rename the saved house.
    for raw_key in built_house_origins:
        var saved_door := _cell_from_key(String(raw_key))
        if saved_door in cells and String(built_structures.get(saved_door, {}).get("name", "")) == "DOOR":
            return saved_door
    for raw_cell in built_structures:
        var cell := Vector2i(raw_cell)
        if cell in cells and String(built_structures[cell].get("name", "")) == "DOOR":
            return cell
    return door

## Where to mark, on the map of the open world, someone standing at `at`
## (in tiles). The inside of a built house is kept far off to the east of the
## map, so a player indoors was marked at the map's edge; they are marked at
## that house's door instead. Anywhere else is returned unchanged.
func outdoor_map_position(at: Vector2) -> Vector2:
    if active_area_id != "OVERWORLD" or at.x < float(map_w + 8) or built_house_origins.is_empty():
        return at
    var door_key := ""
    var nearest := -2147483648
    for key in built_house_origins:
        var origin_y := int(built_house_origins[key])
        if float(origin_y - 2) <= at.y and origin_y > nearest:
            nearest = origin_y
            door_key = String(key)
    if door_key.is_empty():
        return at
    return Vector2(_cell_from_key(door_key)) + Vector2(0.5, 0.5)

func _house_origin_for(door: Vector2i) -> Vector2i:
    var canonical := _canonical_house_door(door)
    var key := _cell_key(canonical)
    if not built_house_origins.has(key):
        var next_y := 5
        for existing in built_house_origins.values():
            next_y = maxi(next_y, int(existing) + map_h + BUILT_HOUSE_FLOOR_STRIDE)
        built_house_origins[key] = next_y
    var origin_y := int(built_house_origins[key])
    for raw_cell in _built_house_state(door).get("cells", []):
        var cell := Vector2i(raw_cell)
        if String(built_structures.get(cell, {}).get("name", "")) == "DOOR":
            built_house_origins[_cell_key(cell)] = origin_y
    return Vector2i(map_w + 9, origin_y)

func _try_push_fenced_pokemon(cell: Vector2i, direction: Vector2i, require_fence: bool = true) -> bool:
    if active_area_id not in ["OVERWORLD", "HOUSE"] or not active_field_move.is_empty() or absi(direction.x) + absi(direction.y) != 1:
        return false
    if preload("res://scripts/game_clock.gd").ticks_msec() - last_pokemon_push_msec < 500: return false
    var near_fence := false
    for y in range(-4, 5):
        for x in range(-4, 5):
            if _is_fence_cell(cell + Vector2i(x,y)):
                near_fence = true
                break
        if near_fence: break
    if require_fence and not near_fence: return false
    var owned := deployed_pokemon.has(cell)
    var wild_id := _wild_id_at_cell(cell)
    var data: Dictionary = deployed_pokemon.get(cell, {}) if owned else wild_pokemon.get(wild_id, {})
    if data.is_empty() or bool(data.get("burrowed", false)) or bool(data.get("behavior", {}).get("stationary", false)): return false
    var target := cell + direction
    # The logical destination is reserved before a walking tween finishes.
    # Check the visible position as well, so pushing cannot overlap its origin.
    for resident in deployed_pokemon.values() + wild_pokemon.values():
        var other := resident.get("sprite") as Sprite2D
        if resident == data or not is_instance_valid(other) or not other.visible: continue
        if other.position.distance_to(_cell_center(target)) < TILE - 0.01: return false
    if active_area_id != "HOUSE" and blocked.has(target): return false
    if active_area_id == "HOUSE" and not _house_pokemon_cell_allowed(target): return false
    if active_area_id == "OVERWORLD" and exact_world != null:
        var ground: SourceTile = exact_world.tile_at(target)
        if ground == null or ground.is_solid or "roof" in ground.name + ground.name_upper: return false
    if built_structures.has(target) or deployed_pokemon.has(target) or wild_eggs.has(target) or target == follower_cell or target == field_helper_cell:
        return false
    if active_area_id != "HOUSE" and (landmarks.has(target) or resource_objects.has(target) or _wild_id_at_cell(target) >= 0):
        return false
    if target == _player_cell(): return false
    if active_area_id == "OVERWORLD" and not _pokemon_can_move_between(String(data.get("species", "")), cell, target): return false
    var sprite := data.get("sprite") as Sprite2D
    if not is_instance_valid(sprite) or sprite.position.distance_to(_cell_center(cell)) > 1.5: return false
    data["cell"] = target
    data["x"] = target.x
    data["y"] = target.y
    data["move_timer"] = 1.0
    data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
    _set_overworld_motion_frame(sprite, Vector2(direction), int(data.anim_phase))
    sprite.position = _cell_center(target)
    sprite.z_index = _depth_z(target)
    if owned:
        deployed_pokemon.erase(cell)
        deployed_pokemon[target] = data
    else:
        wild_pokemon[wild_id] = data
    last_pokemon_push_msec = preload("res://scripts/game_clock.gd").ticks_msec()
    return true

func _is_fence_cell(cell: Vector2i) -> bool:
    var structure: Dictionary = built_structures.get(cell, {})
    if String(structure.get("name", "")) == "FENCE" or bool(structure.get("gate", false)):
        return true
    if exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        return tile != null and ("fence" in tile.name or "fence" in tile.name_upper)
    return false

func is_empty_planting_hole(cell: Vector2i) -> bool:
    if active_area_id != "OVERWORLD" or exact_world == null: return false
    var tile: SourceTile = exact_world.tile_at(cell)
    return tile != null and tile.name_upper.begins_with("hole1") and tile.has_item.is_empty() and not tile.is_water and not tile.is_lava

func _refresh_shell_attachment(cell: Vector2i) -> void:
    var data: Dictionary = built_structures.get(cell, {})
    var shell := data.get("sprite") as Sprite2D
    if not is_instance_valid(shell): return
    if built_house_interior_cells.has(cell) and String(data.get("name", "")) not in ["INTERIOR WALL", "WALL", "ROOF", "FLOOR"]:
        shell.z_index = _house_piece_z(String(data.get("name", "")), cell)
    var wall_torch := shell.get_node_or_null("TORCH") as Sprite2D
    if bool(data.get("torch", false)) and shell.texture != null:
        if wall_torch == null:
            wall_torch = Sprite2D.new()
            wall_torch.name = "TORCH"
            wall_torch.centered = false
            wall_torch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            shell.add_child(wall_torch)
        wall_torch.texture = environment_structure_texture("TORCH", 0)
        # Hung on the face of the wall, a little above the ground.
        wall_torch.position = Vector2(0, shell.texture.get_height() - 24)
    elif wall_torch != null:
        shell.remove_child(wall_torch)
        wall_torch.queue_free()
    for kind in ["WINDOW", "CHIMNEY"]:
        if not bool(data.get(kind.to_lower(), false)): continue
        var part := shell.get_node_or_null(kind) as Sprite2D
        if part == null:
            part = Sprite2D.new()
            part.name = kind
            part.centered = false
            shell.add_child(part)
        part.texture = _structure_display_texture(kind)
        if kind == "WINDOW":
            var window_recipe := String(data.get("window_recipe", "WINDOW"))
            part.hide()
            var facade := shell.texture.get_image()
            var window_pixels := preload("res://assets/source_0_8_11/tiles/buildings/exteriorwindows1.png").get_image()
            if window_recipe == "INDOOR WINDOW 1":
                window_pixels = preload("res://assets/source_0_8_11/tiles/buildings/exteriorwindows1-revertme.png").get_image()
            elif window_recipe == "INDOOR WINDOW 2":
                window_pixels = _structure_display_texture(window_recipe, int(data.get("window_variant",0))).get_image()
            var wall_neighbors: Array[String] = ["WALL", "INTERIOR WALL", "DOOR", "WINDOW"]
            var east := String(built_structures.get(cell + Vector2i.RIGHT, {}).get("name", "")) in wall_neighbors
            var west := String(built_structures.get(cell + Vector2i.LEFT, {}).get("name", "")) in wall_neighbors
            var source_style := String(data.get("house_style", "DEFAULT"))
            if SourceHouseStyles.STYLES.has(source_style):
                east = east and (String(built_structures.get(cell+Vector2i.RIGHT,{}).get("name","")) == "DOOR" or String(built_structures.get(cell+Vector2i.RIGHT,{}).get("house_style","")) == source_style)
                west = west and (String(built_structures.get(cell+Vector2i.LEFT,{}).get("name","")) == "DOOR" or String(built_structures.get(cell+Vector2i.LEFT,{}).get("house_style","")) == source_style)
            for x in range(mini(16, facade.get_width())):
                for y in range(mini(8, facade.get_height())):
                    if (x < 8 and not east) or (x >= 8 and not west) or (east and west):
                        facade.set_pixel(x, y, window_pixels.get_pixel(x, y))
            shell.texture = ImageTexture.create_from_image(facade)
        else:
            var colors: Array[Color] = []
            var roof := shell.texture.get_image()
            for y in range(roof.get_height()):
                for x in range(roof.get_width()):
                    var color := roof.get_pixel(x,y)
                    if color.a == 0 or color in [Color.BLACK,Color.WHITE,Color8(0,251,0)]: continue
                    if not colors.has(color): colors.append(color)
                    if colors.size() == 2: break
                if colors.size() == 2: break
            if colors.size() == 2:
                colors.sort_custom(func(a: Color,b: Color): return a.r+a.g+a.b > b.r+b.g+b.b)
                var smoke := (structure_textures["CHIMNEY"] as Texture2D).get_image()
                for y in range(smoke.get_height()):
                    for x in range(smoke.get_width()):
                        var value := smoke.get_pixel(x,y).to_rgba32()
                        if value == 4285786111: smoke.set_pixel(x,y,colors[0])
                        elif value == 4280921599: smoke.set_pixel(x,y,colors[1])
                var colored := ImageTexture.create_from_image(smoke)
                part.set_meta("chimney_atlas", colored)
                part.texture = part.texture.duplicate()
                (part.texture as AtlasTexture).atlas = colored
            part.position = Vector2(0, -16)
        part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _can_prompt_shore_surf(target: Vector2i) -> bool:
    if active_area_id != "OVERWORLD" or active_field_move == "SURF":
        return false
    if built_structures.has(target) or _wild_id_at_cell(target) >= 0 or deployed_pokemon.has(target):
        return false
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(target)
        return tile != null and tile.is_water
    return _in_bounds(target) and terrain_kind_at(target) == 0

func _is_house_decoration(build_name: String) -> bool:
    return build_name == "CLOCK" or build_name.begins_with("CARPET ") or _is_window_recipe(build_name)

func _torch_wall_at(cell: Vector2i) -> bool:
    return String(built_structures.get(cell, {}).get("name", "")) in ["WALL", "INTERIOR WALL"]

func _is_window_recipe(build_name: String) -> bool:
    return build_name == "WINDOW" or build_name.begins_with("INDOOR WINDOW ")

func _draw_house_decoration(cell: Vector2i) -> void:
    var data: Dictionary = built_house_decorations.get(_built_house_paint_key(cell), {})
    if data.is_empty(): return
    var layer := source_area_layers.get("HOUSE") as Node2D
    if not is_instance_valid(layer): return
    var sprite := built_house_decoration_sprites.get(cell) as Sprite2D
    if not is_instance_valid(sprite):
        sprite = Sprite2D.new()
        sprite.centered = false
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.z_as_relative = false
        layer.add_child(sprite)
        built_house_decoration_sprites[cell] = sprite
    sprite.position = Vector2(cell * TILE)
    if String(data.name) == "DIG GROUND":
        var tile := SourceTile.new("green1", Vector2i.ZERO)
        FieldMoveData.apply_dig_terrain(tile, String(data.get("dig_choice", "FOREST")))
        var original_base := String(data.get("dig_base_name", ""))
        sprite.texture = _structure_display_texture("FLOOR") if original_base == "FLOOR" else _structure_display_texture(original_base, int(data.get("variant", 0))) if not original_base.is_empty() else SourceWorldData.texture_for(tile.name)
        sprite.z_index = -4
        var hole := sprite.get_node_or_null("DigHole") as Sprite2D
        if bool(data.get("dig_hole", false)):
            if hole == null:
                hole = Sprite2D.new();hole.name = "DigHole";hole.centered = false;sprite.add_child(hole)
            hole.texture = SourceWorldData.texture_for("hole1")
        elif is_instance_valid(hole):
            sprite.remove_child(hole);hole.queue_free()
        return
    var old_hole := sprite.get_node_or_null("DigHole")
    if is_instance_valid(old_hole): sprite.remove_child(old_hole);old_hole.queue_free()
    sprite.texture = _structure_display_texture(String(data.name), int(data.get("variant",0)))
    sprite.z_index = -4 if String(data.name).begins_with("CARPET ") else _depth_z(cell, HOUSE_FURNITURE_Z)

func _restore_house_decorations() -> void:
    for cell in built_house_interior_cells: _draw_house_decoration(cell)
    for cell in built_house_paintable_walls: _draw_house_decoration(cell)

func _interact_house_window(cell: Vector2i) -> bool:
    if active_area_id == "OVERWORLD":
        var wall: Dictionary = built_structures.get(cell, {})
        var kind := String(wall.get("window_recipe", ""))
        if not bool(wall.get("window", false)) or not kind.begins_with("INDOOR WINDOW "):
            return false
        wall["window_variant"] = wrapi(int(wall.get("window_variant", 0)) + 1, 0, 3 if kind.ends_with("1") else 2)
        _refresh_shell_attachment(cell)
        play_source_sound("seed1")
        return true
    if active_area_id != "HOUSE": return false
    var key := _built_house_paint_key(cell)
    var data: Dictionary = built_house_decorations.get(key,{})
    var build_name := String(data.get("name",""))
    if not _is_window_recipe(build_name): return false
    if build_name == "INDOOR WINDOW 1": return true
    data.variant = wrapi(int(data.get("variant",0))+1,0,2 if build_name.ends_with("2") else 3)
    built_house_decorations[key] = data
    _draw_house_decoration(cell)
    play_source_sound("seed1")
    return true


func _house_door_transition(action: String, change_area: Callable) -> void:
    # EnterBuilding.java: 18 frames, area change at frame 6 under opaque white.
    house_transition_active = true
    set_gameplay_enabled(false)
    player.velocity = Vector2.ZERO
    var overlay := CanvasLayer.new()
    overlay.layer = 90
    add_child(overlay)
    var flash := ColorRect.new()
    flash.name = "HouseDoorFlash"
    flash.color = Color(1, 1, 1, 0)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(flash)
    play_source_sound(action + "1")
    var elapsed := 0.0
    var changed := false
    while elapsed < 18.0 / 60.0:
        var frame := int(elapsed * 60.0)
        flash.color.a = _house_flash_alpha(frame)
        if frame >= 6 and not changed:
            # Always cover the actual room swap, including a slow rendering frame.
            flash.color.a = 1.0
            change_area.call()
            changed = true
        await get_tree().process_frame
        elapsed += get_process_delta_time()
    if not changed: change_area.call()
    overlay.queue_free()
    house_transition_active = false
    set_gameplay_enabled(true)

func _house_flash_alpha(frame: int) -> float:
    if frame < 2: return 0.0
    if frame < 4: return 0.25
    if frame < 6: return 0.5
    if frame < 12: return 1.0
    if frame < 14: return 0.75
    if frame < 16: return 0.5
    if frame < 18: return 0.25
    return 0.0


# House residents use a persistent layer: rebuilding the active room must not
# delete their actors. House identity and floor are serialized with each record.
func _house_pokemon_layer() -> Node2D:
    var layer := get_node_or_null("HousePokemonLayer") as Node2D
    if layer == null:
        layer = Node2D.new()
        layer.name = "HousePokemonLayer"
        add_child(layer)
    return layer

func _house_pokemon_visible(data: Dictionary) -> bool:
    return active_area_id == "HOUSE" and String(data.get("house_door", "")) == _cell_key(active_built_house_door) and int(data.get("house_floor", -1)) == _built_house_floor_index_for_cell(_player_cell())

func _house_pokemon_cell_allowed(cell: Vector2i) -> bool:
    if String(built_structures.get(cell + Vector2i.DOWN, {}).get("name", "")) == "BED":
        return false
    return active_area_id == "HOUSE" and built_house_interior_cells.has(cell) and not built_structures.has(cell) and _couch_anchor_at(cell) == Vector2i(2147483647,2147483647) and String(interior_interactables.get(cell,"")) != "EXIT_HOUSE" and _built_house_floor_index_for_cell(cell) == _built_house_floor_index_for_cell(_player_cell())

func _update_house_pokemon(delta: float) -> void:
    for egg in wild_eggs.values():
        if egg.has("house_door") and is_instance_valid(egg.get("sprite")):
            egg.sprite.visible = _house_pokemon_visible(egg)
    for old_cell in deployed_pokemon.keys():
        var data: Dictionary = deployed_pokemon[old_cell]
        if not data.has("house_door"):
            continue
        var sprite := data.get("sprite") as Sprite2D
        var visible_here := _house_pokemon_visible(data)
        if is_instance_valid(sprite):
            sprite.visible = visible_here
            sprite.z_index = _depth_z(old_cell)
        if not visible_here or not generated or not gameplay_enabled:
            continue
        data["move_timer"] = float(data.get("move_timer", 0.0)) - delta
        if float(data.move_timer) > 0.0:
            continue
        data["move_timer"] = _wild_move_delay(String(data.get("species", "")))
        if bool(data.get("behavior", {}).get("stationary", false)):
            continue
        var direction: Vector2i = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT][rng.randi_range(0,3)]
        var target: Vector2i = old_cell + direction
        if not _house_pokemon_cell_allowed(target) or deployed_pokemon.has(target) or wild_eggs.has(target) or target == _player_cell() or target == follower_cell or target == field_helper_cell:
            continue
        deployed_pokemon.erase(old_cell)
        data["cell"] = target
        data["x"] = target.x
        data["y"] = target.y
        data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
        deployed_pokemon[target] = data
        if is_instance_valid(sprite):
            _set_overworld_motion_frame(sprite,direction,int(data.anim_phase))
            sprite.z_index = _depth_z(target)
            create_tween().tween_property(sprite,"position",_cell_center(target),0.20)

func _pokemon_drop_ground_allowed(pokemon: Dictionary, cell: Vector2i) -> bool:
    if not _in_bounds(cell): return false
    var water := _source_pokemon_in_water(cell)
    if exact_world_mode and exact_world != null:
        var tile := exact_world.tile_at(cell)
        if tile == null or tile.is_ledge or (tile.is_solid and not water): return false
        if SourceWorldData.is_upper_solid(tile.name_upper): return false
    if not water: return _is_walkable(cell)
    if bool(pokemon.get("is_egg",false)): return false
    # DrawPokemonMenu.java DROP: Water type or one of its explicit exceptions.
    var species := String(pokemon.get("species","")).to_lower()
    return "WATER" in PokemonData.info(species).get("types",[]) or species in ["azurill","dratini","dragonair","dragonite","anorith","armaldo","lileep","cradily","araichu"]

func _update_source_aggro_audio(data: Dictionary, cell: Vector2i, player_cell: Vector2i, delta: float) -> void:
    # Pokemon.Wander: nearby, uncharmed pursuit cries once per 241 source
    # ticks, with ride1 shuffles at ticks 8, 16 and 24. Delta is game-scaled.
    if not bool(data.get("aggro_player",false)) or bool(data.get("charmed",false)) or Vector2(cell-player_cell).length_squared() >= 56.25:
        data.erase("aggro_audio_tick")
        return
    var before := float(data.get("aggro_audio_tick",-1.0))
    var after := maxf(0.0,before) + delta * 60.0
    if before < 0.0 or after >= 241.0:
        if get_parent().has_method("_play_pokemon_cry"):
            get_parent().call("_play_pokemon_cry",data,0.2 if String(data.get("species",""))=="dusclops" else 1.0)
        if after >= 241.0: after = fmod(after,241.0)
        before = 0.0
    for tick in [8.0,16.0,24.0]:
        if before < tick and after >= tick and is_instance_valid(environment_system):
            environment_system._play_environment_sound("ride1",linear_to_db(0.5))
    data["aggro_audio_tick"] = after

var coop_private_chest_cache:Dictionary={}
func _private_chest_texture(source:Texture2D)->Texture2D:
    var key=source.get_instance_id()
    if not coop_private_chest_cache.has(key):
        var source_image=source.get_image()
        if source_image.is_compressed():source_image.decompress()
        var image=source_image.get_region(Rect2i(0,16,16,16))
        for y in range(16):
            for x in range(16):
                var pixel=image.get_pixel(x,y)
                if pixel.a<=0 or maxf(pixel.r,maxf(pixel.g,pixel.b))<0.15:continue
                var light=clampf(pixel.get_luminance()*1.5,0,1)
                var purple=Color(0.24,0.10,0.36).lerp(Color(0.84,0.58,1.0),light)
                purple.a=pixel.a;image.set_pixel(x,y,purple)
        coop_private_chest_cache[key]=ImageTexture.create_from_image(image)
    return coop_private_chest_cache[key]
