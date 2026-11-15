extends "res://scripts/world_base_m74_3_9_14.gd"

signal dig_reward_collected(items: Dictionary)

func _attack_wild_egg(cell:Vector2i)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        coordinator.population_battles.begin(cell,"wild_eggs")
        return
    super._attack_wild_egg(cell)

func _attack_deployed_pokemon(cell:Vector2i)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        coordinator.population_battles.begin(cell,"deployed_pokemon")
        return
    super._attack_deployed_pokemon(cell)

func _collect_wild_egg(cell:Vector2i)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        coordinator.population.recall(cell,"wild_eggs")
        return
    super._collect_wild_egg(cell)

func _update_ecology(delta:float)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        if not coordinator.population.authority() and not coordinator.population.authority(coordinator.population.local_scope()):return
        if ecology_accumulator+delta<PokemonEcology.HABITAT_CHECK_SECONDS:
            ecology_accumulator+=delta
            return
        # Only advance records simulated by this peer, while retaining the
        # original habitat, relationship and breeding calculations.
        var all_deployed=deployed_pokemon
        var all_wild=wild_pokemon
        deployed_pokemon={}
        for cell in all_deployed:
            if coordinator.population.authority(preload("res://scripts/coop_population_records.gd").record_scope(all_deployed[cell])):deployed_pokemon[cell]=all_deployed[cell]
        if not coordinator.population.authority():wild_pokemon={}
        super._update_ecology(delta)
        all_deployed.merge(deployed_pokemon,true)
        deployed_pokemon=all_deployed;wild_pokemon=all_wild
        return
    super._update_ecology(delta)

func _may_release_egg(egg:Dictionary)->bool:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        return coordinator.population.authority(preload("res://scripts/coop_population_records.gd").record_scope(egg))
    return true

func _update_house_pokemon(delta:float)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.population.authority(coordinator.population.local_scope()):
        for data in deployed_pokemon.values():
            if data.has("house_door") and is_instance_valid(data.get("sprite")):data.sprite.visible=_house_pokemon_visible(data)
        return
    super._update_house_pokemon(delta)

func _interact_deployed_pokemon(cell:Vector2i)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not String(deployed_pokemon.get(cell,{}).get("held_item","")).is_empty():
        deployed_recall_candidate=cell
        deployed_recall_candidate_msec=preload("res://scripts/game_clock.gd").ticks_msec()
        coordinator.population.harvest(cell)
        return
    super._interact_deployed_pokemon(cell)

func _recall_deployed_pokemon(cell:Vector2i,data:Dictionary)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.population.applying:
        coordinator.population.recall(cell)
        return
    super._recall_deployed_pokemon(cell,data)

func _remove_wild_pokemon(wild_id:int)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and coordinator.wild.authority() and not coordinator.wild.applying:
        coordinator.wild.mark_motion(wild_id)
    super._remove_wild_pokemon(wild_id)

func _begin_wild_encounter(wild_id:int,field_attack:bool=false)->void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.wild.applying:
        coordinator.wild.begin_encounter(wild_id,field_attack)
        return
    super._begin_wild_encounter(wild_id,field_attack)

func _add_wild_pokemon(species:String,level:int,cell:Vector2i,home_biome:String,requested_id:int=0,source_record:Dictionary={},saved_state:Dictionary={})->void:
    var coordinator=get_parent().get("coop_game")
    var publish=requested_id==0 and is_instance_valid(coordinator) and coordinator.wild.source_spawn_enabled()
    if publish:
        requested_id=coordinator.wild.allocate_id()
        if requested_id==0:
            coordinator.end_session("ENCOUNTER IDENTIFIER COULD NOT BE CREATED.")
            return
    super._add_wild_pokemon(species,level,cell,home_biome,requested_id,source_record,saved_state)
    if publish:coordinator.wild.source_added(requested_id)

func _harvest_exact_resource(cell:Vector2i,move:String)->void:
    var coordinator=get_parent().get("coop_game")
    if move in ["SMASH","HEADBUTT"] and is_instance_valid(coordinator) and coordinator.active and not coordinator.building.collecting:
        coordinator.building.cut(cell,move)
        return
    super._harvest_exact_resource(cell,move)

func _harvest_resource_with_move(cell:Vector2i,move:String)->void:
    var coordinator=get_parent().get("coop_game")
    if move in ["SMASH","HEADBUTT"] and is_instance_valid(coordinator) and coordinator.active and not coordinator.building.collecting:
        coordinator.building.cut(cell,move)
        return
    super._harvest_resource_with_move(cell,move)

func _try_cut_target(cell:Vector2i)->bool:
    # A window or clock comes off before the wall it hangs on.
    if not house_wall_decoration_at(cell).is_empty():
        structure_removal_requested.emit(cell,"CUT")
        return true
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.building.collecting and not built_structures.has(cell):
        var available=_is_cuttable_grass_cell(cell) or _exact_resource_anchor(cell).x>-2147483648 or _resource_object_anchor(cell).x>-2147483648
        if not available:return false
        coordinator.building.cut(cell)
        return true
    return super._try_cut_target(cell)

# M74.3.9.21 compatibility layer. The base is the known-working 9.14 world script.
# Only world behaviors intentionally changed after 9.14 are overridden here.
const M921_SOURCE_SAVANNA_GRASS1 = preload("res://assets/source_0_8_11/tiles/grass_savanna1.png")
const M921_SOURCE_SAVANNA_GRASS2 = preload("res://assets/source_0_8_11/tiles/grass_savanna2.png")
const M3922_SOURCE_FLY_SHADOW = preload("res://assets/source_exact/global/shadow1.png")
const SOURCE_TIDAL_FRONT_SPLASH = preload("res://assets/source_exact/global/splash_anim4.png")
const M3922_FLY_TAKEOFF_SECONDS = 96.0 / 60.0
const M3922_FLY_LANDING_SECONDS = 80.0 / 60.0
const M3922_FLY_HOVER_HEIGHTS = [29.0, 30.0, 31.0, 32.0, 33.0, 32.0, 31.0, 30.0]
var m3922_fly_shadow_sprite: Sprite2D
var m3922_fly_phase: String = ""
var m3922_fly_phase_elapsed: float = 0.0
var m3922_fly_height: float = 0.0
var m3922_fly_landing_start_height: float = 0.0
var m3922_fly_landing_show_message: bool = true
var m3922_ice_slide_direction: Vector2 = Vector2.ZERO
var ice_blocked_direction := Vector2.ZERO
var tidal_front_splash_frames: SpriteFrames
var tidal_front_splash_phase_known := false
var tidal_front_splash_last_phase := false


var tidal_puddle_splashes: Array[AnimatedSprite2D] = []
var tidal_puddle_shader: Shader
var m257_frame_delta := 1.0 / 60.0
var m257_grass_fronts: Array[Sprite2D] = []

var source_night_events
var roaming_ghosts
var source_dig_water_elapsed := 0.0

var camera_build_centered := false

var _watched_wild_ids: Array = []
var _watched_wild_at := -100000
var _near_wild_ids: Array = []
var _near_wild_at := -100000

## Wild Pokemon within sight or earshot of this player, refreshed twice a
## second. Per-frame work that only matters near the player (idle animation,
## pursuit sounds) uses this instead of visiting every Pokemon in the world.
func nearby_wild_ids() -> Array:
    var now_msec := Time.get_ticks_msec()
    if now_msec - _near_wild_at >= 500:
        _near_wild_at = now_msec
        _near_wild_ids.clear()
        var here := _player_cell()
        for raw_id in wild_pokemon:
            var at = wild_pokemon[raw_id].get("cell", Vector2i.ZERO)
            if absi(at.x - here.x) <= 44 and absi(at.y - here.y) <= 44:
                _near_wild_ids.append(raw_id)
    return _near_wild_ids
## Planned escape routes of Pokemon running from a failed catch, by wild id.
var _flee_routes := {}
var _flee_started := {}
## How near the player has to be for a frightened Pokemon to keep running:
## well past the edge of the screen, so it is not found waiting just out of view.
const FLEE_RANGE_TILES := 28
const FLEE_LOOK_AHEAD := 14
const FLEE_SEARCH_TILES := 180
const FLEE_REPLAN_STEPS := 5

## The next step for a Pokemon running from `threat`. It searches every tile it
## could walk to within FLEE_LOOK_AHEAD steps and heads for the one furthest
## from the player, keeping to that route for a few steps before looking again.
## One step at a time (always the tile furthest away) left it pacing back and
## forth in front of any wall or pond, which made it easy to catch.
func _flee_direction(wild_id: int, species: String, origin: Vector2i, threat: Vector2i, free_step: Callable) -> Vector2i:
    var route: Array = _flee_routes.get(wild_id, [])
    if not route.is_empty():
        var planned: Vector2i = route[0]
        if (
                (planned - origin).length_squared() == 1
                and (threat - planned).length_squared() > 2
                and _pokemon_can_move_between(species, origin, planned)
                and free_step.call(planned)
            ):
            route.pop_front()
            _flee_routes[wild_id] = route
            return planned - origin
    var came := {origin: origin}
    var depth := {origin: 0}
    var queue: Array[Vector2i] = [origin]
    var head := 0
    var goal := origin
    var goal_score := float((threat - origin).length_squared())
    while head < queue.size() and queue.size() < FLEE_SEARCH_TILES:
        var cell := queue[head]
        head += 1
        if int(depth[cell]) >= FLEE_LOOK_AHEAD:
            continue
        for option in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var step: Vector2i = cell + option
            # Never plan a way that brushes past the player.
            if came.has(step) or (threat - step).length_squared() <= 2:
                continue
            if not _pokemon_can_move_between(species, cell, step):
                continue
            if cell == origin and not free_step.call(step):
                continue
            came[step] = cell
            depth[step] = int(depth[cell]) + 1
            queue.append(step)
            # Further from the player is better; between equals, the nearer one.
            var score := float((threat - step).length_squared()) - 0.05 * float(depth[step])
            if score > goal_score:
                goal = step
                goal_score = score
    route = []
    while goal != origin:
        route.push_front(goal)
        goal = came[goal]
    if route.is_empty():
        _flee_routes.erase(wild_id)
        return Vector2i.ZERO
    var first: Vector2i = route.pop_front()
    _flee_routes[wild_id] = route.slice(0, FLEE_REPLAN_STEPS)
    return first - origin

func _process(delta: float) -> void:
    var building := active_field_move == "BUILD"
    if generated and building != camera_build_centered:
        camera_build_centered = building
        _configure_camera()
    m257_frame_delta = delta
    super._process(delta)
    if generated and gameplay_enabled:
        source_dig_water_elapsed += delta
        if source_dig_water_elapsed >= 61.0 / 60.0:
            source_dig_water_elapsed = fmod(source_dig_water_elapsed, 61.0 / 60.0)
            _fill_source_dig_holes()
    if source_night_events == null:
        source_night_events = preload("res://scripts/source_night_events.gd").new()
        source_night_events.configure(self)
    source_night_events.update(delta)
    if roaming_ghosts == null:
        roaming_ghosts = preload("res://scripts/source_roaming_ghosts.gd").new()
        roaming_ghosts.world = self
    roaming_ghosts.update(delta)
    plants().update()
    for index in range(tidal_puddle_splashes.size() - 1, -1, -1):
        var splash = tidal_puddle_splashes[index]
        if not is_instance_valid(splash):
            tidal_puddle_splashes.remove_at(index)
            continue
        var tick := int(floor(world_elapsed_seconds * 60.0))
        var stream = get_node_or_null("GroundLayer/ExactBaseTileStream")
        if stream != null:
            tick = int(stream.get("source_animation_tick"))
        splash.material.set_shader_parameter("water_frame", posmod(int(tick / 19), 2))
    if generated and gameplay_enabled:
        _update_overworld_idle_sprites(delta)

func _update_overworld_idle_sprites(delta: float) -> void:
    var sprites: Array[Sprite2D] = []
    var animated: Array = deployed_pokemon.values()
    for near_id in nearby_wild_ids():
        if wild_pokemon.has(near_id): animated.append(wild_pokemon[near_id])
    for data in animated:
        if bool(data.get("burrowed", false)) or bool(data.get("is_egg", false)):
            continue
        var sprite := data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            sprites.append(sprite)
    if is_instance_valid(follower_sprite):
        sprites.append(follower_sprite)
    var camera := get_viewport().get_camera_2d()
    var zoom := Vector2.ONE if camera == null else camera.zoom
    var half_view := get_viewport_rect().size / zoom * 0.5 + Vector2(64, 64)
    for sprite in sprites:
        var distance := sprite.global_position - player.global_position
        if absf(distance.x) > half_view.x or absf(distance.y) > half_view.y:
            continue
        if not sprite.visible or sprite.hframes < 2:
            continue
        var previous: Vector2 = sprite.get_meta("idle_last_position", sprite.position)
        sprite.set_meta("idle_last_position", sprite.position)
        if not previous.is_equal_approx(sprite.position):
            sprite.set_meta("idle_seconds", 0.0)
            continue
        var elapsed := float(sprite.get_meta("idle_seconds", 0.0)) + delta
        sprite.set_meta("idle_seconds", elapsed)
        # Retain the facing pair and use the source standing/dance cadence.
        if elapsed >= 16.0 / 60.0:
            sprite.set_meta("idle_seconds", fmod(elapsed, 16.0 / 60.0))
            var next_frame := sprite.frame ^ 1
            if next_frame < sprite.hframes:
                sprite.frame = next_frame

func _apply_tidal_puddle_surface(splash: AnimatedSprite2D) -> void:
    if tidal_puddle_shader == null:
        tidal_puddle_shader = Shader.new()
        tidal_puddle_shader.code = """
shader_type canvas_item;
uniform sampler2D water_texture : filter_nearest, repeat_enable;
uniform int water_frame = 0;
varying vec2 world_pixel;
void vertex() { world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
    vec4 ripple = texture(TEXTURE, UV);
    vec2 p = mod(floor(world_pixel), vec2(16.0));
    vec4 water = texture(water_texture, (p + vec2(float(water_frame) * 16.0, 0.0) + 0.5) / vec2(32.0, 16.0));
    COLOR = vec4(mix(ripple.rgb, water.rgb, water.a * 0.5), ripple.a);
}
"""
    var material := ShaderMaterial.new()
    material.shader = tidal_puddle_shader
    material.set_shader_parameter("water_texture", SOURCE_TIDAL_WATER)
    splash.material = material
    tidal_puddle_splashes.append(splash)

func _setup_normal_grass_front_overlay() -> void:
    # One live foreground sprite mirrors the exact source tile already rendered
    # under the player. Normal encounter grass uses the full 16px tile;
    # Savannah uses only the lower 8px. No independent grass animation exists.
    if normal_grass_front_sprite != null and is_instance_valid(normal_grass_front_sprite):
        normal_grass_front_sprite.queue_free()
    var sprite = Sprite2D.new()
    sprite.name = "NormalEncounterGrassFront"
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.centered = false
    sprite.region_enabled = true
    sprite.z_as_relative = false
    sprite.visible = false
    add_child(sprite)
    normal_grass_front_sprite = sprite

func _update_normal_grass_front_overlay(_cell: Vector2i) -> void:
    if not is_instance_valid(normal_grass_front_sprite):
        return
    normal_grass_front_sprite.hide()
    for front in m257_grass_fronts:
        if is_instance_valid(front):
            front.hide()
    if active_area_id != "OVERWORLD" or not exact_world_mode or exact_world == null:
        return
    if active_field_move in ["FLY", "RIDE", "SURF"]:
        return
    # DrawPlayerLower/Upper splits the 16px actor at row 8. Grass is between
    # those two parts: preserve the head, cover the lower half with source art.
    var center := to_local(player.sprite.global_position.round())
    var lower_half := Rect2(center + Vector2(-8, 0), Vector2(16, 8))
    var first := Vector2i(floori(lower_half.position.x / TILE), floori(lower_half.position.y / TILE))
    var last := Vector2i(floori((lower_half.end.x - 1) / TILE), floori((lower_half.end.y - 1) / TILE))
    var index := 0
    for y in range(first.y, last.y + 1):
        for x in range(first.x, last.x + 1):
            var cell := Vector2i(x, y)
            var tile := exact_world.tile_at(cell)
            if tile == null:
                continue
            var base := _source_tile_key(tile.name)
            var upper := _source_tile_key(tile.name_upper)
            if base not in ["grass1", "grass2", "grass3", "grass4", "grass_sand1", "grass_sand2", "grass_sand3", "grass_graveyard1", "grass_savanna1", "grass_savanna2"] and upper not in ["grass1", "grass2_over", "grass3_over", "grass4_over", "grass5_over", "grass6_over", "grass_savanna1", "grass_savanna2"]:
                continue
            var tick := int(world_elapsed_seconds * 60.0)
            var stream = get_node_or_null("DecorLayer/ExactUpperTileStream")
            if stream != null:
                tick = int(stream.source_animation_tick)
            var spec := SourceWorldData.render_spec(tile, true, 0, tick)
            if spec.is_empty() and base in ["grass_savanna1", "grass_savanna2"]:
                spec = SourceWorldData.render_spec(tile, false, 0, tick)
            if spec.is_empty():
                continue
            var region: Rect2 = spec.get("region", Rect2(0,0,16,16))
            var origin := Vector2(cell * TILE) + Vector2(spec.get("offset",Vector2.ZERO))
            var clipped := Rect2(origin, region.size).intersection(lower_half)
            if not clipped.has_area():
                continue
            var front := normal_grass_front_sprite
            if index > 0:
                while m257_grass_fronts.size() < index:
                    var extra := Sprite2D.new()
                    extra.centered = false
                    extra.region_enabled = true
                    extra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
                    extra.z_as_relative = false
                    add_child(extra)
                    m257_grass_fronts.append(extra)
                front = m257_grass_fronts[index - 1]
            front.texture = spec.get("texture")
            front.region_rect = Rect2(region.position + clipped.position - origin, clipped.size)
            front.position = clipped.position
            front.z_index = player.z_index + 1
            front.show()
            index += 1

func set_active_field_move(pokemon_data: Dictionary, move: String, ball_landing: bool = false) -> bool:
    if is_instance_valid(sleeping_bag_sprite):
        world_message.emit("Get up before using a Field Move.")
        return false
    if int(pokemon_data.get("hp", 1)) <= 0:
        world_message.emit("A fainted POKEMON cannot use a Field Move.")
        return false
    if active_field_move == "SURF" and terrain_kind_at(_player_cell()) == 0:
        world_message.emit("Reach dry land before changing field moves.")
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
        var target = _player_cell() if ball_landing else _player_cell() + _facing_cell()
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
    var placed = (
        set_follower(pokemon_data, false)
        if active_field_move in ["FOLLOW", "FLASH", "POWER"]
        else _set_field_helper(pokemon_data)
    )
    if not placed:
        active_field_move = ""
        active_field_species = ""
        active_field_pokemon.clear()
        return false
    # A party member has one live actor: activating its helper replaces its
    # follower, while a different party member may keep following normally.
    if is_instance_valid(field_helper_sprite) and same_party_actor(pokemon_data, follower_pokemon):
        clear_follower()
    build_mode_active = active_field_move in ["BUILD", "PAINT"]
    if active_field_move == "RIDE":
        if player.has_method("set_field_rider_visual_lock"):
            player.call("set_field_rider_visual_lock", true)
        if player.has_method("set_field_fixed_speed_pixels_per_frame"):
            player.call("set_field_fixed_speed_pixels_per_frame", 2.0)
        if player.has_method("set_field_visual_offset"):
            # Correct mount composition: the rider overlaps the Pokemon instead
            # of floating a full sprite-height above it.
            player.call("set_field_visual_offset", Vector2(0, -3))
        _set_fly_shadow_active(false)
    if active_field_move == "FLY":
        if player.has_method("set_field_rider_visual_lock"):
            player.call("set_field_rider_visual_lock", true)
        field_previous_collision_mask = player.collision_mask
        player.collision_mask = 0
        if player.has_method("set_field_fixed_speed_pixels_per_frame"):
            player.call("set_field_fixed_speed_pixels_per_frame", 2.0)
        m3922_fly_phase = "TAKEOFF"
        m3922_fly_phase_elapsed = 0.0
        m3922_fly_height = 0.0
        m3922_fly_landing_start_height = 0.0
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -3))
        _set_fly_shadow_active(true)
        world_message.emit("FLY is active. Move freely; press B over safe ground to land.")
    if active_field_move == "SURF":
        if player.has_method("set_field_rider_visual_lock"):
            player.call("set_field_rider_visual_lock", true)
        _set_water_collision_enabled(false)
        # SURF uses the same fixed source-speed rider path as RIDE.
        if player.has_method("set_field_fixed_speed_pixels_per_frame"):
            player.call("set_field_fixed_speed_pixels_per_frame", 2.0)
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -3))
    if active_field_move == "REPEL":
        repel_until_elapsed = 0.0
        world_message.emit("REPEL is active.")
    elif active_field_move == "BUILD":
        _position_build_helper()
        set_build_preview_active(true)
        _show_current_build_selection()
    elif active_field_move == "DIG":
        dig_step_active = false
        dig_action_pending = false
        dig_return_position = work_trainer_position
        _show_current_dig_selection()
    elif active_field_move == "PAINT":
        _show_current_paint_selection()
    elif active_field_move == "TELEPORT":
        travel_selection_index = 0
        teleport_map_requested.emit(_travel_destinations(false))
    planting_item = ""
    return true

func same_party_actor(first: Dictionary, second: Dictionary) -> bool:
    var identity = str(first.get("party_ecology_id", ""))
    return not identity.is_empty() and identity == str(second.get("party_ecology_id", ""))

var dig_return_position := Vector2.ZERO
var dig_step_active := false
var dig_step_target := Vector2.ZERO
var dig_step_direction := Vector2.ZERO
var dig_action_pending := false

func tick_dig_motion(input_direction: Vector2, speed: float, delta: float) -> void:
    var before := player.position
    if not dig_step_active and input_direction != Vector2.ZERO:
        var direction := Vector2(_facing_cell())
        var destination := _cell_center(_player_cell() + Vector2i(direction))
        # Check the whole stride before leaving its center. DIG keeps normal
        # physical collision, including mountain edges and buried rewards.
        # The body's lower edge rests exactly on the tile line, so a solid
        # tile below the path (water under the last shore tile) counted as a
        # hit. Test one pixel higher: touching is not being in the way.
        if constrain_player_motion(before, destination) == destination and \
                not player.test_move(player.transform.translated(Vector2.UP), destination - before):
            dig_step_direction = direction
            dig_step_target = destination
            dig_step_active = true
    if dig_step_active:
        player.facing = dig_step_direction
        var next := player.position.move_toward(dig_step_target, speed * delta)
        player.velocity = dig_step_direction * speed
        var coordinator=get_parent().get("coop_game")
        if is_instance_valid(coordinator) and coordinator.active:
            next=coordinator.visuals.constrain_motion(player.position,next)
        # The stride was checked before it began; moving by collision would
        # stop a hair short of a tile it only touches and never arrive.
        player.position = next
        if player.position.distance_squared_to(dig_step_target) < 0.000001:
            player.position = dig_step_target
            dig_step_active = false
    else:
        player.velocity = Vector2.ZERO
    field_motion_completed(before, player.position, dig_step_direction)
    _place_field_helper_live()
    if not dig_step_active and dig_action_pending:
        dig_action_pending = false
        _use_dig(_player_cell() + _facing_cell())

func clear_active_field_move(show_message: bool = true) -> void:
    dig_step_active = false
    dig_action_pending = false
    if active_field_move == "DIG" and not _is_walkable(_player_cell()):
        var landing := _nearest_walkable_cell(_player_cell(), 4)
        player.position = _cell_center(landing) if landing.x > -2147483648 else dig_return_position

    if active_field_move == "SURF" and show_message and terrain_kind_at(_player_cell()) == 0:
        world_message.emit("Reach dry land before getting off.")
        return
    # User-requested FLY cancellation plays the authored landing sequence. Internal
    # cleanup (show_message=false) remains immediate so battles/map transitions
    # cannot be delayed by a field-move animation.
    if active_field_move == "FLY" and show_message and m3922_fly_phase != "LANDING":
        if not _valid_fly_landing(_player_cell()):
            world_message.emit("You cannot land here.")
            return
        player.position = _cell_center(_player_cell())
        m3922_fly_phase = "LANDING"
        m3922_fly_phase_elapsed = 0.0
        m3922_fly_landing_start_height = m3922_fly_height
        m3922_fly_landing_show_message = show_message
        if player.has_method("set_field_fixed_speed_pixels_per_frame"):
            player.call("set_field_fixed_speed_pixels_per_frame", 0.0)
        play_source_sound("fly_landing1")
        return

    var previous_move = active_field_move
    if active_field_move == "FLY":
        player.collision_mask = field_previous_collision_mask
        _set_fly_shadow_active(false)
        m3922_fly_phase = ""
        m3922_fly_phase_elapsed = 0.0
        m3922_fly_height = 0.0
    if active_field_move == "SURF":
        _set_water_collision_enabled(true)
    if (
            active_field_move in ["RIDE", "SURF", "FLY"]
            and player.has_method("set_field_visual_offset")
        ):
        player.call("set_field_visual_offset", Vector2.ZERO)
    if active_field_move == "RIDE":
        _set_fly_shadow_active(false)
    if player.has_method("set_field_rider_visual_lock"):
        player.call("set_field_rider_visual_lock", false)
    if player.has_method("set_field_speed_multiplier"):
        player.call("set_field_speed_multiplier", 1.0)
    if player.has_method("set_field_fixed_speed_pixels_per_frame"):
        player.call("set_field_fixed_speed_pixels_per_frame", 0.0)
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

func _place_field_helper_live() -> void:
    if field_helper_pokemon.is_empty() or not is_instance_valid(field_helper_sprite):
        return
    if active_field_move not in ["RIDE", "FLY"]:
        super._place_field_helper_live()
        if active_field_move == "SURF": preload("res://scripts/mount_layers.gd").apply(self)
        if active_field_move == "BUILD":
            var phase := int(player.walk_phase) if player.velocity.length_squared() > 0.01 else 0
            _set_overworld_motion_frame(field_helper_sprite, _facing_cell(), phase)
        return

    var facing = _facing_cell()
    var visual_offset = Vector2.ZERO
    if player.has_method("mount_visual_offset"):
        visual_offset = Vector2(player.call("mount_visual_offset"))
    var mount_lift = 0.0
    var rider_lift = 3.0

    if active_field_move == "FLY":
        m3922_fly_phase_elapsed += m257_frame_delta
        if m3922_fly_phase == "TAKEOFF":
            var takeoff_progress = clampf(m3922_fly_phase_elapsed / M3922_FLY_TAKEOFF_SECONDS, 0.0, 1.0)
            m3922_fly_height = 32.0 * takeoff_progress
            if takeoff_progress >= 1.0:
                m3922_fly_phase = "HOVER"
                m3922_fly_phase_elapsed = 0.0
        elif m3922_fly_phase == "LANDING":
            var landing_progress = clampf(m3922_fly_phase_elapsed / M3922_FLY_LANDING_SECONDS, 0.0, 1.0)
            m3922_fly_height = lerpf(m3922_fly_landing_start_height, 0.0, landing_progress)
            if landing_progress >= 1.0:
                # Phase is already LANDING, so this call performs final cleanup
                # instead of recursively starting another landing.
                clear_active_field_move(m3922_fly_landing_show_message)
                return
        else:
            m3922_fly_phase = "HOVER"
            # Player.Flying updates height every four source ticks and resets
            # its counter at 255. Keep the existing rider/mount offsets intact.
            var tick := posmod(int(floor(m3922_fly_phase_elapsed * 60.0 + 0.000001)), 255)
            var phase := posmod(tick, 32)
            m3922_fly_height = float([32, 31, 30, 29, 30, 31, 32, 33][phase / 4])
            if phase == 31:
                m3922_fly_height = 32.0
        mount_lift = m3922_fly_height
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -mount_lift - rider_lift))
    else:
        # RIDE keeps the player seated into the mount rather than 12 pixels above.
        if player.has_method("set_field_visual_offset"):
            player.call("set_field_visual_offset", Vector2(0, -rider_lift))

    field_helper_cell = _player_cell()
    field_helper_sprite.visible = true
    field_helper_sprite.position = (
        player.position + visual_offset + Vector2(0, -mount_lift + 2.0)
    ).round()
    field_helper_sprite.z_index = player.z_index - 1
    var moving = player.velocity.length_squared() > 0.01 or (
        player.has_method("is_ledge_jump_active")
        and bool(player.call("is_ledge_jump_active"))
    )
    var phase = int(preload("res://scripts/game_clock.gd").ticks_msec() / 180) % 2 if moving or active_field_move == "FLY" else 0
    _set_overworld_motion_frame(field_helper_sprite, facing, phase)
    field_helper_sprite.offset = Vector2.ZERO
    preload("res://scripts/mount_layers.gd").apply(self)

func _set_fly_shadow_active(active: bool) -> void:
    # Use the authored PokeWilds shadow1 asset instead of the fabricated polygon.
    if active:
        if not is_instance_valid(m3922_fly_shadow_sprite):
            m3922_fly_shadow_sprite = Sprite2D.new()
            m3922_fly_shadow_sprite.name = "SourceFlyShadow"
            m3922_fly_shadow_sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
            m3922_fly_shadow_sprite.texture = M3922_SOURCE_FLY_SHADOW
            m3922_fly_shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            m3922_fly_shadow_sprite.z_as_relative = false
            add_child(m3922_fly_shadow_sprite)
        m3922_fly_shadow_sprite.visible = true
        _update_fly_shadow()
    elif is_instance_valid(m3922_fly_shadow_sprite):
        m3922_fly_shadow_sprite.visible = false
    if is_instance_valid(fly_shadow):
        fly_shadow.visible = false

func _update_fly_shadow() -> void:
    if not is_instance_valid(m3922_fly_shadow_sprite):
        return
    m3922_fly_shadow_sprite.global_position = (player.global_position + Vector2(0, 7)).round()
    m3922_fly_shadow_sprite.z_index = player.z_index - 2

func field_movement_direction(input_direction: Vector2) -> Vector2:
    if active_field_move == "FLY" and m3922_fly_phase in ["TAKEOFF", "LANDING"]:
        return Vector2.ZERO
    if active_field_move in ["CUT", "BUILD", "DIG", "HEADBUTT", "SMASH"] and input_direction.length_squared() > 0.0001:
        # Work Pokemon steer on the same cardinal axes as D-pad input.
        # Retain the current axis near a diagonal to prevent stick jitter.
        var horizontal := absf(input_direction.x)
        var vertical := absf(input_direction.y)
        if horizontal > vertical * 1.20:
            input_direction = Vector2(signf(input_direction.x), 0)
        elif vertical > horizontal * 1.20:
            input_direction = Vector2(0, signf(input_direction.y))
        elif player.facing.x != 0:
            input_direction = Vector2(signf(input_direction.x), 0)
        else:
            input_direction = Vector2(0, signf(input_direction.y))
    # Source ice is continuous sliding: once a direction is committed on ice,
    # releasing/turning the stick does not stop or turn the player until the
    # slide leaves ice or meets an obstruction.
    if not exact_world_mode or exact_world == null or active_area_id != "OVERWORLD" or active_field_move in ["FLY", "DIG"]:
        m3922_ice_slide_direction = Vector2.ZERO
        return input_direction
    var cell = _player_cell()
    var tile = exact_world.tile_at(cell)
    var on_ice = tile != null and _source_tile_key(tile.name) == "ice2"
    if not on_ice:
        m3922_ice_slide_direction = Vector2.ZERO
        ice_blocked_direction = Vector2.ZERO
        return input_direction
    if ice_blocked_direction != Vector2.ZERO:
        if input_direction.dot(ice_blocked_direction) > 0.7:
            return Vector2.ZERO
        ice_blocked_direction = Vector2.ZERO
    if m3922_ice_slide_direction == Vector2.ZERO:
        if input_direction.length_squared() <= 0.0001:
            return input_direction
        if absf(input_direction.x) > absf(input_direction.y):
            m3922_ice_slide_direction = Vector2(1 if input_direction.x > 0.0 else -1, 0)
        else:
            m3922_ice_slide_direction = Vector2(0, 1 if input_direction.y > 0.0 else -1)
    return m3922_ice_slide_direction

func field_motion_completed(before: Vector2, after: Vector2, movement_direction: Vector2) -> void:
    if active_field_move == "DIG" and _is_walkable(_player_cell()):
        dig_return_position = _cell_center(_player_cell())
    _animate_walked_gates(before, after)
    _update_source_surf_wake(before, after, movement_direction)
    if m3922_ice_slide_direction == Vector2.ZERO or exact_world == null:
        return
    var after_cell = Vector2i(floori(after.x / TILE), floori(after.y / TILE))
    var after_tile = exact_world.tile_at(after_cell)
    var still_on_ice = after_tile != null and _source_tile_key(after_tile.name) == "ice2"
    var stopped := before.distance_squared_to(after) < 0.0025 and movement_direction.length_squared() > 0.0001
    if not stopped and still_on_ice:
        _align_ice_slide(after_cell)
    for index in range(player.get_slide_collision_count()):
        if player.get_slide_collision(index).get_normal().dot(m3922_ice_slide_direction) < -0.5:
            stopped = true
    if stopped: ice_blocked_direction = m3922_ice_slide_direction
    if not still_on_ice or stopped:
        m3922_ice_slide_direction = Vector2.ZERO

## Slides on ice run along a row or column of tiles, as in the source game,
## where the player is always on one tile. Here a player can be a pixel or two
## off the middle of a row, and a slide along the foot of a wall then caught
## the corner of the next tile of that wall and stopped dead on open ice. The
## sideways offset is taken out a little at a time while sliding, never
## through anything solid.
func _align_ice_slide(cell: Vector2i) -> void:
    var centre := _cell_center(cell)
    var offset := Vector2(0.0, centre.y - player.position.y) if m3922_ice_slide_direction.x != 0.0 else Vector2(centre.x - player.position.x, 0.0)
    if offset.length_squared() < 0.0001:
        return
    var step := offset.limit_length(1.0)
    if not player.test_move(player.transform, step):
        player.position += step

func _ride_jump_over(obstacle: Vector2i) -> void:
    if active_field_move == "RIDE" and exact_world_mode and exact_world != null and active_area_id == "OVERWORLD":
        var tile = exact_world.tile_at(obstacle)
        if tile != null and (tile.is_bottom_mtn_layer or "ledges3" in (String(tile.name) + " " + String(tile.name_upper))):
            var landing = try_pre_move_field_jump(player.position, Vector2(_facing_cell()))
            if typeof(landing) == TYPE_VECTOR2:
                player.position = landing
                last_player_cell = _player_cell()
                _sync_follower_to_player()
            return
    super._ride_jump_over(obstacle)

func try_pre_move_field_jump(before: Vector2, movement_direction: Vector2):
    if active_field_move != "RIDE" or not exact_world_mode or exact_world == null or active_area_id != "OVERWORLD":
        return null
    if player.has_method("is_ledge_jump_active") and bool(player.call("is_ledge_jump_active")):
        return null
    var direction = Vector2i.ZERO
    if absf(movement_direction.x) > absf(movement_direction.y):
        direction = Vector2i(1 if movement_direction.x > 0.0 else -1, 0)
    elif absf(movement_direction.y) > 0.01:
        direction = Vector2i(0, 1 if movement_direction.y > 0.0 else -1)
    if direction == Vector2i.ZERO:
        return null
    var start_cell = Vector2i(floori(before.x / float(TILE)), floori(before.y / float(TILE)))
    var obstacle_cell = start_cell + direction
    var obstacle = exact_world.tile_at(obstacle_cell)
    if obstacle == null:
        return null
    var obstacle_key = (String(obstacle.name) + " " + String(obstacle.name_upper)).to_lower()
    var fence := String(obstacle.name_upper) in ["fence1", "fence2", "fence1_NS", "fence2_NS"] or String((built_structures.get(obstacle_cell, {}) as Dictionary).get("name", "")) == "FENCE"
    if fence:
        var fence_axis := Vector2i.LEFT if "_NS" in String(obstacle.name_upper) else Vector2i.DOWN
        if built_structures.has(obstacle_cell):
            var vertical := false
            var horizontal := false
            for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
                if String((built_structures.get(obstacle_cell + offset, {}) as Dictionary).get("name", "")) == "FENCE":
                    vertical = vertical or offset.y != 0
                    horizontal = horizontal or offset.x != 0
            if vertical and horizontal:
                return null
            fence_axis = Vector2i.LEFT if vertical else Vector2i.DOWN
        if direction != fence_axis and direction != -fence_axis:
            return null
        var fence_landing = start_cell + direction * 2
        if not _ledge_jump_landing_is_clear(fence_landing):
            return null
        var fence_position = _cell_center(fence_landing)
        player.call("begin_ledge_jump_visual", before - fence_position)
        _set_fly_shadow_active(true)
        play_source_sound("ledge1")
        return fence_position
    var current_tile = exact_world.tile_at(start_cell)
    var mountain_edge := bool(obstacle.is_bottom_mtn_layer) or "ledges3" in obstacle_key
    var leaving_mountain := current_tile != null and (bool(current_tile.is_bottom_mtn_layer) or "ledges3" in (String(current_tile.name) + " " + String(current_tile.name_upper)))
    if mountain_edge or leaving_mountain:
        # Mountain RIDE advances to the adjacent grid cell, never searches
        # across multiple rim layers for a distant plateau.
        if obstacle.is_water or obstacle.is_lava or built_structures.has(obstacle_cell) or landmarks.has(obstacle_cell) or resource_objects.has(obstacle_cell) or deployed_pokemon.has(obstacle_cell) or wild_eggs.has(obstacle_cell) or _wild_id_at_cell(obstacle_cell) >= 0:
            return null
        if mountain_edge:
            # Only bypass the mountain edge itself, not objects on that edge.
            if not String(obstacle.name_upper).is_empty() and not "ledges3" in String(obstacle.name_upper):
                return null
        elif not _ledge_jump_landing_is_clear(obstacle_cell):
            return null
        var mountain_position = _cell_center(obstacle_cell)
        player.call("begin_ledge_jump_visual", before - mountain_position)
        _set_fly_shadow_active(true)
        play_source_sound("ledge1")
        return mountain_position
    if not (bool(obstacle.is_ledge) or bool(obstacle.is_bottom_mtn_layer) or "ledges3" in obstacle_key):
        return null
    if bool(obstacle.is_ledge) and "ledge_grass_down" in obstacle_key:
        var permitted = _permitted_ledge_direction(obstacle)
        if permitted == Vector2i.ZERO or direction != permitted:
            return null
    # Mountain rims can span several authored edge cells. Continue across the
    # contiguous rim and land on the first ordinary clear plateau/ground cell.
    for distance in range(2, 8):
        var landing_cell = start_cell + direction * distance
        if not _ledge_jump_landing_is_clear(landing_cell):
            continue
        var landing_position = _cell_center(landing_cell)
        if player.has_method("begin_ledge_jump_visual"):
            player.call("begin_ledge_jump_visual", before - landing_position)
        _set_fly_shadow_active(true)
        play_source_sound("ledge1")
        return landing_position
    return null

func _build_piece_is_grid_snapped(build_name: String) -> bool:
    return not _build_snap_piece_name(build_name).is_empty()

func _build_snap_connection_score(build_name: String, cell: Vector2i) -> int:
    var piece = _build_snap_piece_name(build_name)
    var desired_style = _house_style_for_recipe(build_name)
    var compatible = ["WALL", "ROOF", "DOOR", "WINDOW", "CHIMNEY", "INTERIOR WALL"]
    var score = 0
    for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
        var neighbor = cell + direction
        if not built_structures.has(neighbor):
            continue
        var data = built_structures[neighbor]
        var neighbor_name = String(data.get("name", "")).to_upper()
        if piece in compatible:
            if neighbor_name not in compatible:
                continue
            if piece != "INTERIOR WALL" and desired_style != "DEFAULT":
                var neighbor_style = String(data.get("house_style", "DEFAULT"))
                if neighbor_style not in [desired_style, "DEFAULT"]:
                    continue
        # Non-shell BUILD items also snap to cardinal built neighbors.
        score += 1
    return score

func _update_friendly_passby(_data: Dictionary, _cell: Vector2i, _owned: bool) -> void:
    # Proximity alone does not trigger CHARM's heart effect.
    pass

func _update_deployed_pokemon(delta: float) -> void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.population.authority():return
    var directions = [
        Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
        Vector2i.UP, Vector2i.DOWN
    ]
    for raw_cell in deployed_pokemon.keys():
        var old_cell = raw_cell
        if not deployed_pokemon.has(old_cell):
            continue
        var data = deployed_pokemon[old_cell]
        if data.has("house_door"):
            continue
        _update_pokemon_water_visual(data)
        _update_friendly_passby(data, old_cell, true)
        data["move_timer"] = float(data.get("move_timer", 0.0)) - delta
        if float(data["move_timer"]) > 0.0:
            deployed_pokemon[old_cell] = data
            continue
        data["move_timer"] = _wild_move_delay(String(data.get("species", "")))
        data = _try_create_parent_egg(data, old_cell)
        var behavior = data.get("behavior", {})
        if bool(behavior.get("stationary", false)):
            deployed_pokemon[old_cell] = data
            continue
        if not String(data.get("held_item", "")).is_empty():
            var dance_sprite = data.get("sprite") as Sprite2D
            data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
            if is_instance_valid(dance_sprite):
                _set_overworld_motion_frame(
                    dance_sprite, Vector2.DOWN, int(data["anim_phase"])
                )
            deployed_pokemon[old_cell] = data
            continue

        var direction = directions[rng.randi_range(0, directions.size() - 1)]
        var friend_id = String(data.get("friend_id", ""))
        var friend_reunion = (
            not friend_id.is_empty()
            and float(data.get("friend_seconds", PokemonEcology.FRIEND_SECONDS)) <= 0.0
        )
        var companion_id = friend_id
        if friend_reunion:
            data["friend_seconds"] = PokemonEcology.FRIEND_SECONDS
            _show_friend_reunion(data, friend_id)
        elif companion_id.is_empty() or rng.randf() < 0.18:
            companion_id = String(data.get("mate_id", companion_id))
        if not companion_id.is_empty() and (friend_reunion or rng.randf() < 0.20):
            var companion_cell = _ecology_cell_by_id(companion_id)
            if companion_cell.x > -2147483648:
                direction = _cardinal_direction(companion_cell - old_cell, false)
        direction = _paired_wander_direction(data, old_cell, direction)
        var target = old_cell + direction
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
        var sprite = data.get("sprite") as Sprite2D
        if is_instance_valid(sprite):
            _set_overworld_motion_frame(sprite, direction, int(data["anim_phase"]))
            sprite.z_index = _depth_z(target)
            var move_seconds = 0.20
            if bool(behavior.get("flee", false)):
                move_seconds = 16.0 / (2.0 * 60.0)
            create_tween().tween_property(
                sprite, "position", _cell_center(target), move_seconds
            ).set_trans(Tween.TRANS_LINEAR)
        deployed_pokemon[target] = data


func _interact_wild_pokemon(wild_id: int) -> void:
    if not wild_pokemon.has(wild_id):
        return
    var data: Dictionary = wild_pokemon[wild_id]
    var species = PokemonData.battle_display_name(String(data.get("species", "POKEMON")))
    if bool(data.get("burrowed", false)):
        world_message.emit("The sand shifts slightly, then goes still.")
        return
    if bool(data.get("source_record",{}).get("rare_forest_mew",false)) or not String(data.get("source_record",{}).get("rare_legendary", "")).is_empty():
        _begin_wild_encounter(wild_id)
        return
    if active_field_move == "ATTACK":
        _begin_wild_encounter(wild_id, true)
        return
    var sprite = data.get("sprite") as Sprite2D
    if is_instance_valid(sprite):
        _set_overworld_motion_frame(sprite, -_facing_cell(), 0)
    var kind = PokemonEcology.wild_interaction_kind(String(data.get("species", "")))
    var warned = bool(data.get("warned",false))
    # It stays where it was reached while the player is talking to it.
    data["move_timer"] = maxf(float(data.get("move_timer", 0.0)), 1.5)
    set_gameplay_enabled(false)
    await get_tree().create_timer(20.0/60.0).timeout
    if not wild_pokemon.has(wild_id):
        set_gameplay_enabled(true)
        return
    # One still shaken by a failed catch can be befriended, but is not glad of it.
    var frightened = kind == "FRIENDLY" and world_elapsed_seconds < float(data.get("ball_flee_until", 0.0))
    _show_ecology_emote(sprite, "sad" if frightened else "happy" if kind=="FRIENDLY" else "skull" if kind=="AGGRESSIVE" and not warned else "alert")
    await get_tree().create_timer(20.0/60.0).timeout
    get_parent()._play_pokemon_cry({"species":String(data.get("species",""))})
    if kind == "SKITTISH":
        _begin_wild_encounter(wild_id)
    elif kind == "FRIENDLY":
        wild_pokemon_prompt_requested.emit(wild_id, species, "FRIGHTENED" if frightened else "FRIENDLY")
    elif not warned:
        wild_pokemon_prompt_requested.emit(wild_id, species, "PROVOKE_WARNING")
    else:
        await get_tree().create_timer(10.0/60.0).timeout
        confirm_wild_provocation(wild_id)
        # Battle entry owns the gameplay lock after explicit provocation.

func _wild_record_is_mean(data: Dictionary) -> bool:
    var behavior = data.get("behavior", {})
    var source_record = data.get("source_record", {})
    return (
        bool(source_record.get("aggressive", false))
        or bool(behavior.get("lunge", false))
        or int(behavior.get("aggression", 1)) >= 1
        or bool(data.get("aggro_player", false))
        or bool(data.get("warned", false))
    )

func _mean_ecology_emote(data: Dictionary) -> String:
    var behavior = data.get("behavior", {})
    var source_record = data.get("source_record", {})
    if (
            bool(source_record.get("aggressive", false))
            or bool(behavior.get("lunge", false))
            or int(behavior.get("aggression", 1)) >= 2
            or bool(data.get("aggro_player", false))
            or bool(data.get("warned", false))
        ):
        return "skull"
    return "alert"

func _show_friend_reunion(data: Dictionary, friend_id: String) -> void:
    super._show_friend_reunion(data, friend_id)

func _charm_suppresses(data: Dictionary) -> bool:
    if float(data.get("ball_charm_until", 0.0)) > world_elapsed_seconds:
        return true
    if active_field_move != "CHARM":
        return false
    return int(active_field_pokemon.get("level", 1)) >= _effective_wild_level(
        int(data.get("level", 1)))

func _update_wild_pokemon(delta: float) -> void:
    var coordinator=get_parent().get("coop_game")
    var online=is_instance_valid(coordinator) and coordinator.active
    if online and not coordinator.wild.authority():return
    if online:coordinator.wild.refresh_players()
    var directions = [
        Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT,
        Vector2i.UP, Vector2i.DOWN
    ]
    var player_cell = _player_cell()
    # Most wild Pokemon in a big world are nowhere near anyone. Settle that
    # with a few comparisons before the per-Pokemon work below, which for
    # hundreds of them every frame was a third of the host's frame time.
    # The zones are the same ones _wild_ecology_is_active tests.
    var zones: Array = []
    if online:
        for watcher in coordinator.wild.players.values():
            zones.append([int(watcher.x), int(watcher.y), ECOLOGY_ACTIVE_RADIUS])
    else:
        zones.append([player_cell.x, player_cell.y, ECOLOGY_ACTIVE_RADIUS])
    for habitat_cell in deployed_pokemon.keys():
        zones.append([habitat_cell.x, habitat_cell.y, PokemonEcology.HABITAT_RADIUS])
    # Which Pokemon are inside a zone is worked out twice a second, not every
    # frame: with hundreds in the world, just asking each one cost 3-4 ms a
    # frame. One that wanders in or spawns is picked up within half a second.
    var now_msec := Time.get_ticks_msec()
    if now_msec - _watched_wild_at >= 500:
        _watched_wild_at = now_msec
        _watched_wild_ids.clear()
        for raw_id in wild_pokemon:
            var at = wild_pokemon[raw_id].get("cell", Vector2i.ZERO)
            for zone in zones:
                if absi(at.x - zone[0]) <= zone[2] + 2 and absi(at.y - zone[1]) <= zone[2] + 2:
                    _watched_wild_ids.append(int(raw_id))
                    break
    for raw_id in _watched_wild_ids.duplicate():
        var wild_id = int(raw_id)
        if not wild_pokemon.has(wild_id):
            continue
        var data = wild_pokemon[wild_id]
        if bool(data.get("ball_reserved", false)): continue
        if bool(data.get("burrowed", false)):
            continue
        var old_cell = data.get("cell", Vector2i.ZERO)
        var local_target=true
        var target_player:Dictionary={}
        if online:
            target_player=coordinator.wild.target_for(data,old_cell)
            if target_player.is_empty():continue
            player_cell=Vector2i(target_player.x,target_player.y)
            local_target=target_player.actor==coordinator.session.actor
        if not _wild_ecology_is_active(old_cell, player_cell):
            continue
        var active_sprite = data.get("sprite") as Sprite2D
        if is_instance_valid(active_sprite):
            active_sprite.visible = true
            active_sprite.z_index = _depth_z(old_cell)
        _update_pokemon_water_visual(data)
        if local_target:_update_friendly_passby(data, old_cell, false)
        var was_charmed = bool(data.get("charmed", false))
        var is_charmed = _charm_suppresses(data) if local_target else coordinator.wild.remote_charm(data,target_player)
        data["charmed"] = is_charmed
        if not online:_update_source_aggro_audio(data, old_cell, player_cell, delta)
        if is_charmed and not was_charmed:
            _show_ecology_emote(data.get("sprite") as Sprite2D, "heart")
        if bool(data.get("aggro_player", false)):
            data["source_aggro_emote_seconds"] = float(data.get("source_aggro_emote_seconds", 0.0)) - delta
            if float(data["source_aggro_emote_seconds"]) <= 0.0:
                _show_ecology_emote(data.get("sprite") as Sprite2D, "skull")
                data["source_aggro_emote_seconds"] = 241.0 / 60.0
        data["move_timer"] = float(data.get("move_timer", 0.0)) - delta
        # One that has just broken out of a ball bolts at once; it does not
        # first wait out whatever pause its wandering had left.
        var flee_until = float(data.get("ball_flee_until", 0.0))
        var bolting = world_elapsed_seconds < flee_until and float(_flee_started.get(wild_id, -1.0)) != flee_until
        if bolting:
            _flee_started[wild_id] = flee_until
        elif float(data["move_timer"]) > 0.0:
            wild_pokemon[wild_id] = data
            continue
        data["move_timer"] = _wild_move_delay(String(data.get("species", "")), data)
        data = _try_create_parent_egg(data, old_cell, wild_id)
        var behavior = data.get("behavior", {})
        if bool(behavior.get("stationary", false)):
            wild_pokemon[wild_id] = data
            continue

        var player_delta = player_cell - old_cell
        var pursuing = bool(data.get("aggro_player", false)) and not is_charmed
        if world_elapsed_seconds < float(data.get("fed_until", 0.0)):
            var eating_sprite = data.get("sprite") as Sprite2D
            data["anim_phase"] = 1 - int(data.get("anim_phase", 0))
            if is_instance_valid(eating_sprite):
                _set_overworld_motion_frame(
                    eating_sprite, Vector2.DOWN, int(data["anim_phase"])
                )
            wild_pokemon[wild_id] = data
            continue
        if (
                pursuing
                and local_target
                and active_field_move not in ["SURF", "FLY"]
                and player_delta.length_squared() <= 1
                and not encounter_grace_active()
                and not _repel_blocks(int(data.get("level", 1)))
            ):
            _begin_wild_encounter(wild_id)
            return
        var direction = directions[rng.randi_range(0, directions.size() - 1)]
        # Timid species keep their distance; one that just broke out of a ball
        # runs from the player for a while, from further off.
        var scared = world_elapsed_seconds < float(data.get("ball_flee_until", 0.0))
        var fleeing = (bool(behavior.get("flee", false)) and player_delta.length_squared() <= 16) or \
            (scared and player_delta.length_squared() <= FLEE_RANGE_TILES * FLEE_RANGE_TILES)
        if fleeing:
            direction = _cardinal_direction(player_delta, true)
        elif pursuing and player_delta.length_squared() <= 64:
            direction = _cardinal_direction(player_delta, false)
        else:
            var friend_id = String(data.get("friend_id", ""))
            var friend_reunion = (
                not friend_id.is_empty()
                and float(data.get("friend_seconds", PokemonEcology.FRIEND_SECONDS)) <= 0.0
            )
            var companion_id = friend_id
            if friend_reunion:
                data["friend_seconds"] = PokemonEcology.FRIEND_SECONDS
                _show_friend_reunion(data, friend_id)
            elif companion_id.is_empty() or rng.randf() < 0.18:
                companion_id = String(data.get("mate_id", companion_id))
            if not companion_id.is_empty() and (friend_reunion or rng.randf() < 0.20):
                var companion_cell = _ecology_cell_by_id(companion_id)
                if companion_cell.x > -2147483648:
                    direction = _cardinal_direction(companion_cell - old_cell, false)
            elif rng.randf() < 0.12:
                var same_species_cell = _nearby_same_base_species_cell(data, old_cell)
                if same_species_cell.x > -2147483648:
                    direction = _cardinal_direction(same_species_cell - old_cell, false)
        if not pursuing and not fleeing:
            direction = _paired_wander_direction(data, old_cell, direction)
        if not scared:
            _flee_routes.erase(wild_id)
            _flee_started.erase(wild_id)
        elif fleeing:
            # Running from a failed catch: follow a route planned several steps
            # ahead (see _flee_direction), so walls, water and dead ends are
            # gone around rather than paced in front of.
            var runner = String(data.get("species", ""))
            var free_step = func(step: Vector2i) -> bool:
                return not (
                    step == player_cell or step == follower_cell or step == field_helper_cell
                    or (online and coordinator.wild.occupied(step))
                    or _wild_id_at_cell(step, wild_id) >= 0
                    or wild_eggs.has(step) or deployed_pokemon.has(step)
                )
            direction = _flee_direction(wild_id, runner, old_cell, player_cell, free_step)
        var target = old_cell + direction
        if bool(data.get("source_record", {}).get("rare_forest_mew", false)) and not preload("res://scripts/rare_forest_mew.gd").deep_forest(self,target):
            wild_pokemon[wild_id] = data
            continue
        var rare_species := String(data.get("source_record", {}).get("rare_legendary", ""))
        if not rare_species.is_empty() and not preload("res://scripts/rare_biome_legendaries.gd").habitat(self, rare_species, target):
            wild_pokemon[wild_id] = data
            continue
        if (
                direction == Vector2i.ZERO
                or not _pokemon_can_move_between(String(data.get("species", "")), old_cell, target)
                or target == player_cell
                or target == follower_cell
                or target == field_helper_cell
                or (online and coordinator.wild.occupied(target))
                or _wild_id_at_cell(target, wild_id) >= 0
                or wild_eggs.has(target)
                or deployed_pokemon.has(target)
            ):
            wild_pokemon[wild_id] = data
            continue

        var sprite = data.get("sprite") as Sprite2D
        var phase = 1 - int(data.get("anim_phase", 0))
        data["anim_phase"] = phase
        data["cell"] = target
        if online:coordinator.wild.mark_motion(wild_id)
        if is_instance_valid(sprite):
            _set_overworld_motion_frame(sprite, direction, phase)
            sprite.z_index = _depth_z(target)
            var move_seconds = 0.20
            if bool(behavior.get("flee", false)) or (scared and fleeing):
                move_seconds = 16.0 / (2.0 * 60.0)
            elif pursuing:
                move_seconds = 16.0 / (1.5 * 60.0)
            data["ball_facing"] = Vector2(direction)
            var movement = create_tween()
            data["ball_move_tween"] = movement
            movement.tween_property(sprite, "position", _cell_center(target), move_seconds).set_trans(Tween.TRANS_LINEAR)
            if pursuing or fleeing:
                data["move_timer"] = move_seconds
        if bool(behavior.get("flee", false)):
            data["flee_steps"] = int(data.get("flee_steps", 0)) + 1
            if int(data["flee_steps"]) >= 3 and _is_tall_grass_cell(target):
                _remove_wild_pokemon(wild_id)
                continue
        wild_pokemon[wild_id] = data

func request_fishing_encounter(rod_name: String) -> void:
    if rod_name not in ["OLD ROD", "GOOD ROD", "SUPER ROD"] or not active_field_move.is_empty():
        world_message.emit("Stop the field move before fishing.")
        return
    var target := _player_cell() + _facing_cell()
    var tile: SourceTile = exact_world.tile_at(target) if exact_world != null else null
    if tile == null or not ("water" in tile.name or tile.name == "desert2"):
        world_message.emit("Use the %s while facing water." % rod_name)
        return
    set_gameplay_enabled(false)
    var owner_game := get_parent()
    owner_game.field_item_busy = true
    var fishing_sprite := Sprite2D.new()
    var model: String = owner_game.PLAYER_MODEL_NAMES[owner_game.player_model_index]
    var path := "res://assets/source_exact/player/red/fishing.png" if model == "red" else "res://assets/source_exact/player/%s-fishing.png" % model
    fishing_sprite.texture = owner_game._recolor_texture(load(path), owner_game.PLAYER_MODEL_REPLACE_COLORS[owner_game.player_model_index], owner_game.PLAYER_COLOR_VALUES[owner_game.player_color_index], "fishing:%d:%d" % [owner_game.player_model_index,owner_game.player_color_index])
    fishing_sprite.centered = false
    fishing_sprite.region_enabled = true
    var facing := _facing_cell()
    fishing_sprite.region_rect = Rect2(0 if facing.y < 0 else 16, 0, 16, 24) if facing.y else Rect2(32,0,24,16)
    fishing_sprite.flip_h = facing.x < 0
    fishing_sprite.position = player.position - Vector2(8,8) + Vector2(-8 if facing.x < 0 else 0,-8 if facing.y < 0 else 0)
    fishing_sprite.z_index = player.z_index
    fishing_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(fishing_sprite)
    player.sprite.hide()
    play_source_sound("rod1")
    await get_tree().create_timer(120.0 / 60.0).timeout
    var hooked := rng.randi_range(0, 1) == 0
    if not hooked:
        owner_game._show_trainer_tip_message("Not even a nibble...")
        while owner_game.trainer_tip_open: await get_tree().process_frame
        fishing_sprite.queue_free()
        player.sprite.show()
        owner_game.field_item_busy = false
        set_gameplay_enabled(true)
        return
    var choices := _source_fishing_species(tile, rod_name)
    var species: String = choices[rng.randi_range(0, choices.size() - 1)]
    var level := 10 if rod_name == "OLD ROD" else 20 if rod_name == "GOOD ROD" else 30
    # Tile.java rolls each evolution at the rod's fixed encounter level.
    var visited: Dictionary = {}
    while not visited.has(species):
        visited[species] = true
        var next_species := ""
        for evo in PokemonData.info(species).get("evolutions", []):
            var level_evo: bool = String(evo.get("method", "")) == "EVOLVE_LEVEL"
            if level_evo and int(evo.get("parameter", 101)) > level: continue
            if rng.randi_range(0, 255) < (128 if level_evo else 192): continue
            next_species = String(evo.get("species", "")).to_lower()
            break
        if next_species.is_empty(): break
        species = next_species
    var fishing_position := fishing_sprite.position
    for tick in range(64):
        fishing_sprite.position.y = fishing_position.y + (1 if tick % 4 < 2 else 0)
        await get_tree().create_timer(1.0 / 60.0).timeout
    fishing_sprite.position = fishing_position
    _show_ecology_emote(fishing_sprite, "!")
    owner_game._show_trainer_tip_message("A bite!")
    while owner_game.trainer_tip_open: await get_tree().process_frame
    set_gameplay_enabled(false)
    await get_tree().create_timer(30.0 / 60.0).timeout
    fishing_sprite.queue_free()
    player.sprite.show()
    owner_game.field_item_busy = false
    battle_requested.emit({
        "id":"fishing", "kind":"wild", "can_run":true, "can_catch":true,
        "fishing":true, "terrain":"AQUATIC", "_wild_level_scaled":true,
        "party":[{"species":species, "level":level}]
    })

func _source_fishing_species(tile: SourceTile, rod_name: String) -> Array:
    var route_name := tile.route_belongs_to.name if tile.route_belongs_to != null else ""
    var fishing_route := "oasis_pond1" if route_name == "oasis1" else "wooded_lake_fishing1" if route_name == "wooded_lake_water1" else "sea1" if tile.name == "water2" else "sand_fishing1" if tile.name == "desert2" else "river1"
    var choices := SourceRouteData.allowed_pokemon(fishing_route)
    if rod_name != "SUPER ROD":
        for species in SourceRouteData.SUPER_ROD_POKEMON: choices.erase(species)
    if rod_name == "OLD ROD":
        for species in SourceRouteData.GOOD_ROD_POKEMON: choices.erase(species)
    return choices

func _spawn_puddle_step_effect(cell: Vector2i) -> void:
    if active_field_move == "FLY":
        return
    if active_area_id != "OVERWORLD" or not exact_world_mode or exact_world == null:
        return
    var tile = exact_world.tile_at(cell)
    if tile == null or _source_biome_for_tile(tile) != "BEACH":
        return
    var high_tide = "_tidalwater" in tile.name.to_lower()
    var puddle_name = tile.name if "_puddle1" in tile.name else tile.name_upper
    if not high_tide:
        if "_puddle1" not in puddle_name or "_tidaloff" not in puddle_name:
            return
        # Low-tide puddle physics follows the same authored per-pixel water
        # mask as the locked reflection system. Stepping on the dry portion of
        # a puddle tile must not create a water splash.
        var local_feet = Vector2i(8, 10)
        if not SourceWorldData.puddle_reflects_at(puddle_name, local_feet):
            return

    var frames = SpriteFrames.new()
    frames.add_animation("splash")
    frames.set_animation_loop("splash", false)
    frames.set_animation_speed("splash", 60.0)
    for frame_index in range(3):
        var frame = AtlasTexture.new()
        frame.atlas = SOURCE_PUDDLE_SPLASH
        frame.region = Rect2(frame_index * TILE, 0, TILE, TILE)
        frames.add_frame("splash", frame, 13.0 if frame_index == 2 else 12.0)

    var splash = AnimatedSprite2D.new()
    splash.sprite_frames = frames
    splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    splash.name = "PuddleStepSplash"
    splash.position = to_local(player.sprite.global_position.round()) + Vector2(0.0, 0.0 if high_tide else 4.0)
    splash.z_as_relative = false
    splash.z_index = player.z_index - 1
    if high_tide:
        _apply_tidal_puddle_surface(splash)
    add_child(splash)
    splash.animation_finished.connect(splash.queue_free)
    splash.play("splash")
    _spawn_tidal_front_splash(high_tide)

func _update_tidal_wade_visual() -> void:
    var show_wade = false
    var tile = null
    if active_area_id == "OVERWORLD" and exact_world_mode and exact_world != null:
        if active_field_move not in ["FLY", "SURF"]:
            # A walking sprite overlaps more than one tile at an edge. Keep
            # the wade visible while its lower edge still touches tide water.
            for foot_x in [-6.0, 0.0, 6.0]:
                var foot_cell := Vector2i(
                    floori((player.position.x + foot_x) / TILE),
                    floori((player.position.y + 6.0) / TILE))
                var foot_tile: SourceTile = exact_world.tile_at(foot_cell)
                if foot_tile != null and _is_beach_tidal_tile(foot_tile) and \
                        foot_tile.name.to_lower().contains("_tidalwater"):
                    tile = foot_tile
                    show_wade = true
                    break
    if not show_wade:
        tidal_front_splash_phase_known = false
        if is_instance_valid(tide_wade_base):
            tide_wade_base.visible = false
        if is_instance_valid(tide_wade_ripple):
            tide_wade_ripple.visible = false
        return

    # The foreground must match the pale composite tide surface behind the
    # actor. Water2 alone painted a dark purple bar over the lower body.
    if not is_instance_valid(tide_wade_base):
        tide_wade_base = Sprite2D.new()
        tide_wade_base.name = "TideWadeGround"
        tide_wade_base.centered = false
        tide_wade_base.region_enabled = true
        tide_wade_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tide_wade_base.z_as_relative = false
        add_child(tide_wade_base)
    if not is_instance_valid(tide_wade_ripple):
        tide_wade_ripple = Sprite2D.new()
        tide_wade_ripple.name = "TideWadeWater"
        tide_wade_ripple.centered = false
        tide_wade_ripple.region_enabled = true
        tide_wade_ripple.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tide_wade_ripple.z_as_relative = false
        add_child(tide_wade_ripple)

    var base_stream = get_node_or_null("GroundLayer/ExactBaseTileStream")
    var animation_tick = int(floor(world_elapsed_seconds * 60.0))
    if base_stream != null:
        animation_tick = int(base_stream.get("source_animation_tick"))
    # In the recording the surface crosses the lower four sprite pixels.
    # Position it from the pixel-locked sprite, never from the tile origin.
    const WADE_FRONT_HEIGHT = 4
    var wade_source_y = TILE - WADE_FRONT_HEIGHT
    var tide_frame = posmod(int(animation_tick / 19), 2)
    var ground_spec: Dictionary = SourceWorldData.render_spec(
        tile, false, 0, animation_tick)
    var ground_texture := ground_spec.get("texture") as Texture2D
    var ground_region: Rect2 = ground_spec.get(
        "region", Rect2(0, 0, TILE, TILE))
    var sprite_center: Vector2 = to_local(player.sprite.global_position.round())
    var wade_position := sprite_center + Vector2(-TILE * 0.5, TILE * 0.5 - WADE_FRONT_HEIGHT)
    if ground_texture != null:
        tide_wade_base.texture = ground_texture
        tide_wade_base.region_rect = Rect2(
            ground_region.position.x,
            ground_region.position.y + wade_source_y,
            TILE, WADE_FRONT_HEIGHT)
        tide_wade_base.position = wade_position
        tide_wade_base.modulate = Color(1, 1, 1, 0.75)
        tide_wade_base.z_index = player.z_index + 4
        tide_wade_base.visible = true
    else:
        tide_wade_base.visible = false
    tide_wade_ripple.texture = SOURCE_TIDAL_WATER
    tide_wade_ripple.region_rect = Rect2(
        tide_frame * TILE, wade_source_y, TILE, WADE_FRONT_HEIGHT)
    tide_wade_ripple.position = wade_position
    tide_wade_ripple.modulate = Color(1, 1, 1, 0.50)
    tide_wade_ripple.z_index = player.z_index + 5
    tide_wade_ripple.visible = true
    player.visible = true

func _spawn_tidal_front_splash(high_tide: bool = true) -> void:
    # The source has a separate three-frame splash_anim4 effect. puddle3 is
    # the oval ground ripple and is intentionally kept on its existing path.
    if tidal_front_splash_frames == null:
        tidal_front_splash_frames = SpriteFrames.new()
        tidal_front_splash_frames.add_animation("splash")
        tidal_front_splash_frames.set_animation_loop("splash", false)
        tidal_front_splash_frames.set_animation_speed("splash", 60.0)
        for frame_index in range(3):
            var frame := AtlasTexture.new()
            frame.atlas = SOURCE_TIDAL_FRONT_SPLASH
            frame.region = Rect2(frame_index * TILE, 0, TILE, TILE)
            tidal_front_splash_frames.add_frame("splash", frame, [4.0, 1.0, 5.0][frame_index])
    var splash := AnimatedSprite2D.new()
    splash.name = "TidalFrontSplash"
    splash.sprite_frames = tidal_front_splash_frames
    splash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    splash.z_as_relative = true
    splash.z_index = 7
    # Java player art is at y+4; WaterSplash is at y+3 (+4 in tides).
    # Convert the difference to Godot's downward-positive screen coordinates.
    splash.position = Vector2(0.0, -3.0 if high_tide else 1.0)
    player.sprite.add_child(splash)
    splash.frame_changed.connect(_update_tidal_front_splash_frame.bind(splash))
    splash.animation_finished.connect(splash.queue_free)
    splash.play("splash")
    _update_tidal_front_splash_frame(splash)

func _update_tidal_front_splash_frame(splash: AnimatedSprite2D) -> void:
    splash.offset = Vector2.ZERO

func _pokemon_can_enter(species: String, cell: Vector2i) -> bool:
    if species.to_lower() in [
            "araichu", "raichu_alolan", "aexeggutor", "exeggutor_alolan"] and \
            exact_world_mode and exact_world != null and not blocked.has(cell):
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile != null and tile.is_water and not tile.is_solid:
            var route_name := "" if tile.route_belongs_to == null else \
                tile.route_belongs_to.name.to_lower()
            if (species.to_lower() in ["araichu", "raichu_alolan"] and \
                    route_name == "beach2_water") or \
                    (route_name == "beach2" and _is_beach_tidal_tile(tile)):
                return true
    return super._pokemon_can_enter(species, cell)

func _ensure_overworld_pokemon_population() -> void:
    super._ensure_overworld_pokemon_population()
    if not exact_world_mode or exact_world == null:
        return
    # Older saves persisted the roaming population before these source aliases
    # had visible textures. Restore only authored Alolan records absent from
    # that saved population; never invent a spawn or alter another species.
    var present := {"araichu": false, "aexeggutor": false}
    for raw_data in wild_pokemon.values():
        var species := String((raw_data as Dictionary).get("species", "")).to_lower()
        if species == "raichu_alolan":
            species = "araichu"
        elif species == "exeggutor_alolan":
            species = "aexeggutor"
        if present.has(species):
            present[species] = true
    for record in exact_world.pokemon_cell_records():
        var species := String(record.get("name", "")).to_lower()
        if not present.has(species) or bool(present[species]):
            continue
        var cell: Vector2i = record.get("cell", Vector2i.ZERO)
        if _wild_id_at_cell(cell) >= 0:
            continue
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null:
            continue
        _add_wild_pokemon(
            species, int(record.get("level", 2)), cell,
            _source_biome_for_tile(tile), 0, record)
        present[species] = true

# M74.3.9.24 â€” DIG scope only.  Keep the frozen base implementation for every
# other field move; DIG explicitly recognizes authored soil/fossil surfaces so
# collision bookkeeping cannot make valid ground impossible to dig.
func _m3924_dig_tile_is_fossil_site(tile: SourceTile) -> bool:
    if tile == null:
        return false
    var names: String = (tile.name + " " + tile.name_upper).to_lower()
    return "_cracked" in names

func _m3924_dig_tile_is_surface(tile: SourceTile) -> bool:
    if tile == null or tile.is_water or tile.is_lava:
        return false
    if _m3924_dig_tile_is_fossil_site(tile):
        return true
    var names: String = (tile.name + " " + tile.name_upper).to_lower()
    if "_tidaloff" in names:
        return true
    # These are the authored DIG terrain bases already defined by FieldMoveData.
    for raw_info in FieldMoveData.DIG_TERRAIN.values():
        var info: Dictionary = raw_info
        var authored_base: String = String(info.get("base", "")).to_lower()
        if not authored_base.is_empty() and tile.name.to_lower() == authored_base:
            return true
    # Ordinary non-solid ground remains diggable. Mountain/cliff authored ground
    # is also legal even when its collision flag describes the ledge edge.
    if not tile.is_solid and not tile.is_ledge:
        return true
    return "mountain" in names or "ledges3" in names

func _field_helper_can_use_work_target(cell: Vector2i) -> bool:
    if active_field_move != "DIG":
        return super._field_helper_can_use_work_target(cell)
    if deployed_pokemon.has(cell) or wild_eggs.has(cell) or _wild_id_at_cell(cell) >= 0:
        return false
    if built_structures.has(cell) or landmarks.has(cell) or resource_objects.has(cell):
        return false
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null:
            return false
        # Visible exact-world resources keep ownership of their tile; fossil
        # cracks are ground overlays and intentionally do not resolve as resources.
        if not _m3924_dig_tile_is_fossil_site(tile) and not tile.name_upper.begins_with("hole1"):
            var resource_anchor: Vector2i = _exact_resource_anchor(cell)
            if resource_anchor.x > -2147483648:
                return false
        return _m3924_dig_tile_is_surface(tile) or _dig_target_accepts_soil(cell)
    return _in_bounds(cell) and terrain_kind_at(cell) != 0 and not blocked.has(cell)

func _m3924_refresh_dig_farms(changed_cell: Vector2i) -> void:
    # Deployed-Pokemon farming/habitat records use a 7x7 neighborhood. Refresh
    # only records whose habitat window includes the changed soil cell.
    var ecology_name_cache: Dictionary = {}
    for raw_cell in deployed_pokemon.keys():
        var farm_cell: Vector2i = raw_cell
        if absi(farm_cell.x - changed_cell.x) > 3 or absi(farm_cell.y - changed_cell.y) > 3:
            continue
        var data: Dictionary = deployed_pokemon[farm_cell]
        deployed_pokemon[farm_cell] = _refresh_record_habitat(
            data, farm_cell, ecology_name_cache)
    # Habitat data is stored back into deployed_pokemon above; no party-ecology
    # signal is emitted because that signal carries a specific Pokemon record.

func _m3924_dig_material_at(cell: Vector2i) -> String:
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null:
            return ""
        var route_name: String = ""
        if tile.route_belongs_to != null:
            route_name = tile.route_belongs_to.name
        return FieldMoveData.dig_material(tile.name, tile.name_upper, tile.biome, route_name)
    if not _in_bounds(cell) or terrain_kind_at(cell) == 0:
        return ""
    return "SOFT SAND" if terrain_kind_at(cell) == 1 else "GRASS"

func _m3924_dig_surface_name_at(cell: Vector2i) -> String:
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null:
            return "GROUND"
        if _m3924_dig_tile_is_fossil_site(tile):
            return "FOSSIL SOIL"
        var biome_name: String = _source_biome_for_tile(tile).replace("_", " ")
        if not biome_name.is_empty():
            return biome_name
    var material: String = _m3924_dig_material_at(cell)
    return material if not material.is_empty() else "GROUND"

func _dig_target_accepts_soil(cell: Vector2i) -> bool:
    if active_area_id == "HOUSE":
        return bool(built_house_decorations.get(_built_house_paint_key(cell), {}).get("dig_hole", false))
    if not exact_world_mode or exact_world == null:
        return false
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null:
        return false
    # Player.updateBuildTiles / DrawBuildTile: terrain placement is only for
    # a hole, water2/water5, or lava. Intact ground always selects currDigTile.
    return "hole" in tile.name_upper or "water2" in tile.name or \
        "water5" in tile.name or "lava" in tile.name

func _dig_action_choice(cell: Vector2i) -> String:
    if exact_world_mode and not _dig_target_accepts_soil(cell):
        return "HOLE"
    # Retain the approved palette selection for the next fillable target.
    # Source currDigTile is automatic on intact ground, never a fill choice.
    return String(DIG_CHOICES[maxi(1, dig_selection_index)])

func _cycle_dig_selection(direction: int) -> void:
    var target := _field_move_action_cell(_player_cell() + _facing_cell(), "DIG")
    # PlayerStanding ignores terrain-selection input while currDigTile is active.
    if exact_world_mode and not _dig_target_accepts_soil(target):
        return
    dig_selection_index = 1 + wrapi(maxi(1, dig_selection_index) - 1 + direction, 0, DIG_CHOICES.size() - 1)
    _show_current_dig_selection()

func get_dig_hud_state() -> Dictionary:
    var target: Vector2i = _field_move_action_cell(
        _player_cell() + _facing_cell(), "DIG")
    var choice := _dig_action_choice(target)
    if choice == "HOLE":
        var material: String = _m3924_dig_material_at(target)
        var fossil_site: bool = false
        if exact_world_mode and exact_world != null:
            fossil_site = _m3924_dig_tile_is_fossil_site(exact_world.tile_at(target))
        return {
            "choice": choice,
            "left": "DIG\n%s" % _m3924_dig_surface_name_at(target),
            "right": "GET\n%s  x1%s" % [
                material if not material.is_empty() else "--",
                "\nFOSSIL SITE" if fossil_site else ""
            ],
            "target": target,
            "diggable": _field_helper_can_use_work_target(target)
        }
    var info: Dictionary = FieldMoveData.dig_choice_info(choice)
    var needed: String = String(info.get("material", ""))
    return {
        "choice": choice,
        "left": "DIG\n%s" % choice,
        "right": "NEED\n%s  x1" % needed,
        "target": target,
        "diggable": _field_helper_can_use_work_target(target)
    }

func _show_current_dig_selection() -> void:
    # The persistent two-box DIG HUD is authoritative; do not stack a transient
    # message box over it every time L/R changes the selected soil.
    pass

func _save_source_dig_tile(cell: Vector2i) -> void:
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null: return
    source_interior_mutations[_cell_key(cell)] = {
        "kind":"TILE_NAMES", "base":tile.name, "upper":tile.name_upper,
        "dig_item":tile.has_item, "dig_item_amount":tile.has_item_amount,
        "dig_biome":tile.biome,
        "dig_route":tile.route_belongs_to.name if tile.route_belongs_to != null else "",
        "dig_route_level":tile.route_belongs_to.level if tile.route_belongs_to != null else 0}

func _leave_source_dig_hole(cell: Vector2i, tile: SourceTile) -> void:
    tile.set_names(tile.name, "hole1")
    terrain_changes.erase(_cell_key(cell))
    _save_source_dig_tile(cell)
    _connect_source_dig_holes(cell)
    _refresh_exact_tile_streams()

func _dig_is_mountain(tile: SourceTile) -> bool:
    return tile != null and ("mountain" in tile.name or "ledges3" in tile.name or "ledges3" in tile.name_upper)

func _dig_mountain_ground(cell: Vector2i, tile: SourceTile) -> SourceTile:
    # A cliff over ordinary soil already has its correct underlying ground.
    if not "mountain" in tile.name and not "ledges3" in tile.name:
        return tile
    # Look outward only until the closest ring containing natural ground.
    # Never copy neighboring structures, trees, holes, water or mountain faces.
    var extent := exact_world.top_right_cell - exact_world.bottom_left_cell
    for radius in range(1, maxi(extent.x, extent.y) + 2):
        var choices: Dictionary = {}
        var samples: Dictionary = {}
        for step in range(-radius, radius):
            for offset in [Vector2i(step, -radius), Vector2i(radius, step), Vector2i(-step, radius), Vector2i(-radius, -step)]:
                var nearby := exact_world.tile_at(cell + offset)
                if nearby == null or _dig_is_mountain(nearby) or nearby.is_water or nearby.is_lava or nearby.is_solid or nearby.is_ledge: continue
                if nearby.name_upper.begins_with("hole1"): continue
                var ground := nearby.name
                if not (ground.begins_with("green") or ground.begins_with("sand") or ground.begins_with("desert") or ground.begins_with("snow") or ground.begins_with("volcano") or ground.begins_with("soot")): continue
                choices[ground] = int(choices.get(ground, 0)) + 1
                samples[ground] = nearby
        if not choices.is_empty():
            var best: String = choices.keys()[0]
            for name in choices:
                if int(choices[name]) > int(choices[best]): best = name
            return samples[best]
    # No surrounding land exists (isolated all-mountain test/custom worlds).
    return SourceTile.new("green1", tile.position)

func _clear_dug_mountain(cell: Vector2i, tile: SourceTile) -> void:
    var ground := _dig_mountain_ground(cell, tile)
    tile.set_names(ground.name, "")
    tile.biome = ground.biome
    tile.route_belongs_to = ground.route_belongs_to
    tile.is_bottom_mtn_layer = false
    tile.shore_ocean = ""
    tile.shore_tidal = ""
    blocked.erase(cell)
    terrain_changes.erase(_cell_key(cell))
    _save_source_dig_tile(cell)
    source_interior_mutations[_cell_key(cell)]["dig_mountain_cleared"] = true
    _recoastify_exact_cells([cell])
    _refresh_exact_tile_streams()

func _dig_connects(cell: Vector2i, diagonal: bool = false) -> bool:
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null: return false
    var names := tile.name + " " + tile.name_upper
    if diagonal:
        return "water" in names or "hole" in tile.name_upper
    return "hole" in names or "water" in names or "lava" in names

func _connect_source_dig_holes(changed: Vector2i) -> void:
    # Java map coordinates are retained: north is +Y in this adapter.
    var dirs := {"N":Vector2i(0,1), "S":Vector2i(0,-1), "E":Vector2i(1,0), "W":Vector2i(-1,0)}
    for dy in range(-1,2):
        for dx in range(-1,2):
            var cell := changed + Vector2i(dx,dy)
            var tile: SourceTile = exact_world.tile_at(cell)
            if tile == null or not tile.name_upper.begins_with("hole1"): continue
            var suffix := ""
            for direction in ["N", "S", "E", "W"]:
                if _dig_connects(cell + dirs[direction]): suffix += direction
            var name := "hole1" + ("_" + suffix if not suffix.is_empty() else "")
            for corner in ["NE", "SE", "SW", "NW"]:
                if corner[0] in suffix and corner[1] in suffix and _dig_connects(cell + dirs[corner[0]] + dirs[corner[1]], true):
                    name += "[" + corner + "]"
            tile.set_names(tile.name, name)
            _save_source_dig_tile(cell)

func _fill_source_dig_holes() -> void:
    if not exact_world_mode or exact_world == null or active_area_id != "OVERWORLD": return
    var replacements := {}
    # Inspect only edited cells, never scan the full world each frame. Collect
    # before applying so a water pulse advances one hole at a time.
    for key in source_interior_mutations:
        var parts := String(key).split(",")
        if parts.size() != 2: continue
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null or not tile.name_upper.begins_with("hole1"): continue
        var water := false
        var lava := false
        for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var neighbor: SourceTile = exact_world.tile_at(cell + direction)
            if neighbor == null: continue
            var names := neighbor.name + " " + neighbor.name_upper
            if "water" in names: water = true
            elif "lava" in names: lava = true
        if water or lava: replacements[cell] = "soot1" if water and lava else "water2" if water else "lava1"
    for cell in replacements:
        var tile: SourceTile = exact_world.tile_at(cell)
        tile.set_names(replacements[cell], "")
        if tile.is_lava:
            # PkmnMap.adjustTile selects the source lava-sheet variant.
            var suffix := "_"
            if rng.randi_range(0, 2) != 0:
                if rng.randi_range(0, 1) == 1:
                    suffix += ["S", "", "N"][rng.randi_range(0, 2)]
                    suffix += ["W", "", "E"][posmod(cell.x, 3)]
                else:
                    suffix += ["S", "", "N"][posmod(cell.y, 3)]
                    suffix += ["W", "", "E"][rng.randi_range(0, 2)]
            tile.set_names("lava1" + suffix, "")
        _save_source_dig_tile(cell)
    for cell in replacements: _connect_source_dig_holes(cell)
    if not replacements.is_empty():
        var coast_cells: Array[Vector2i] = []
        coast_cells.assign(replacements.keys())
        _recoastify_exact_cells(coast_cells)
        _refresh_exact_tile_streams()
        play_source_sound("sand1")

func _collect_source_dig_item(cell: Vector2i) -> bool:
    var mutation: Dictionary = source_interior_mutations.get(_cell_key(cell), {})
    var item := String(mutation.get("dig_item", ""))
    if item.is_empty(): return false
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null: return false
    var amount := maxi(1, int(mutation.get("dig_item_amount", 1)))
    tile.has_item = ""
    tile.has_item_amount = 0
    interior_interactables.erase(cell)
    _save_source_dig_tile(cell)
    _refresh_exact_tile_streams()
    dig_reward_collected.emit({item:amount})
    return true

func _use_dig(cell: Vector2i) -> void:
    if active_field_move == "DIG" and dig_step_active:
        dig_action_pending = true
        return
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.building.collecting:
        coordinator.building.dig(cell)
        return
    if active_area_id == "HOUSE":
        if not _house_dig_target_allowed(cell): return
        if _dig_target_accepts_soil(cell):
            var choice := _dig_action_choice(cell)
            dig_requested.emit(choice, cell, String(FieldMoveData.dig_choice_info(choice).get("material", "GRASS")))
        else:
            var key := _built_house_paint_key(cell)
            var previous: Dictionary = built_house_decorations.get(key, {})
            var old_choice := String(previous.get("dig_choice", "FOREST"))
            var material := String(FieldMoveData.dig_choice_info(old_choice).get("material", "GRASS"))
            built_house_decorations[key] = {"name":"DIG GROUND", "dig_choice":old_choice, "dig_hole":true, "dig_base_name":String(previous.get("name", "FLOOR")) if String(previous.get("name", "")) != "DIG GROUND" else String(previous.get("dig_base_name", "")), "variant":int(previous.get("variant", 0))}
            _draw_house_decoration(cell)
            play_source_sound("dig1")
            dig_reward_collected.emit({material:1})
        return
    if not _in_bounds(cell): return
    if _collect_source_dig_item(cell): return
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile != null and not tile.has_item.is_empty():
            # Preserve the existing source item-pickup priority.
            super._use_dig(cell)
            return
        if _dig_is_mountain(tile):
            _dig_surface(cell)
            return
    var choice := _dig_action_choice(cell)
    if choice == "HOLE":
        _dig_surface(cell)
        return
    var info := FieldMoveData.dig_choice_info(choice)
    dig_requested.emit(choice, cell, String(info.get("material", "GRASS")))

func _use_interior_interactable(action: String, cell: Vector2i = Vector2i.ZERO) -> void:
    var coordinator=get_parent().get("coop_game")
    if action.to_upper().begins_with("ITEM:SECRET KEY:") and is_instance_valid(coordinator) and coordinator.active and not coordinator.hosting:
        # A guest takes a key of their own and the key stays where it is: the
        # world's key belongs to the host, so a guest cannot take it from them.
        if int(get_parent().inventory.get("SECRET KEY", 0)) > 0:
            world_message.emit("You already have the MANSION KEY.")
        else:
            item_collected.emit("SECRET KEY")
            world_message.emit("You found the MANSION KEY!")
        return
    if action.begins_with("ITEM:") and is_instance_valid(coordinator) and coordinator.active and not coordinator.building.collecting:
        coordinator.building.collect_item(action,cell)
        return
    if action.begins_with("ITEM:") and _collect_source_dig_item(cell): return
    super._use_interior_interactable(action, cell)

func _pick_exact_berry_tree(cell: Vector2i) -> void:
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active and not coordinator.building.collecting:
        coordinator.building.pick_berry(cell)
        return
    super._pick_exact_berry_tree(cell)

func _finish_shared_agitated_tree(cell:Vector2i,mutation:Dictionary)->void:
    var original_world=exact_world
    var delay=maxf(0.0,float(mutation.get("clear_at",0.0))-world_elapsed_seconds)
    if delay>0.0:await get_tree().create_timer(delay).timeout
    if source_interior_mutations.get(_cell_key(cell),{})!=mutation:return
    if exact_world==null or exact_world!=original_world:return
    var tile:SourceTile=exact_world.tile_at(cell)
    if tile==null:return
    tile.set_names(String(mutation.get("base",tile.name)),"")
    source_plant_farms.erase(_cell_key(cell))
    _refresh_exact_pickup_cell(cell)

func _apply_source_interior_mutation(cell: Vector2i, mutation: Dictionary) -> void:
    if mutation.get("kind")=="BERRY_AGITATED":
        _finish_shared_agitated_tree(cell,mutation.duplicate(true))
        return
    super._apply_source_interior_mutation(cell, mutation)
    if String(mutation.get("kind", "")) == "TILE_NAMES" and mutation.has("dig_item") and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile != null:
            tile.has_item = String(mutation.dig_item)
            tile.has_item_amount = int(mutation.get("dig_item_amount", 0))
            if not tile.has_item.is_empty():
                interior_interactables[cell] = "ITEM:%s:%d" % [tile.has_item, tile.has_item_amount]
            elif String(interior_interactables.get(cell, "")).begins_with("ITEM:"):
                interior_interactables.erase(cell)
    if String(mutation.get("kind", "")) == "TILE_NAMES" and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile != null and mutation.has("dig_biome"):
            tile.biome = String(mutation.dig_biome)
            var route_name := String(mutation.get("dig_route", ""))
            tile.route_belongs_to = null if route_name.is_empty() else SourceRoute.new(
                route_name, int(mutation.get("dig_route_level", 22)))
            if bool(mutation.get("dig_mountain_cleared", false)):
                tile.is_bottom_mtn_layer = false
                blocked.erase(cell)
        elif tile != null and tile.name in ["green_woodedlake", "green_deepforest"]:
            # These were palette identifiers saved as ground by older DIG code.
            # Their intended soil is unambiguous; preserve any dug upper/item.
            var saved_upper := tile.name_upper
            FieldMoveData.apply_dig_terrain(tile,
                "WOODED LAKE" if tile.name == "green_woodedlake" else "DEEP FOREST")
            tile.set_names(tile.name, saved_upper)
            _save_source_dig_tile(cell)
        # Reconnect edited ground and remove pre-edit shoreline on saved water.
        _connect_source_dig_holes(cell)
        _recoastify_exact_cells([cell])

func _dig_surface(cell: Vector2i) -> void:
    var exact_tile: SourceTile = null
    if exact_world_mode and exact_world != null:
        exact_tile = exact_world.tile_at(cell)
    if _collect_source_dig_item(cell): return
    if exact_tile != null and exact_tile.name_upper.begins_with("hole1") and not _dig_is_mountain(exact_tile):
        world_message.emit("There's already a hole here.")
        return
    if built_structures.has(cell) or landmarks.has(cell) or resource_objects.has(cell):
        world_message.emit("DIG can't break that tile.")
        return
    if exact_world_mode and exact_world != null:
        if exact_tile == null or not _m3924_dig_tile_is_surface(exact_tile):
            world_message.emit("DIG can't break that tile.")
            return
        if not _m3924_dig_tile_is_fossil_site(exact_tile):
            var exact_resource: Vector2i = _exact_resource_anchor(cell)
            if exact_resource.x > -2147483648:
                world_message.emit("DIG can't break that tile.")
                return
    elif blocked.has(cell):
        world_message.emit("DIG can't break that tile.")
        return

    var material: String = "GRASS"
    var loot: Array = []
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_tile
        var route_name: String = "" if tile.route_belongs_to == null else tile.route_belongs_to.name
        material = FieldMoveData.dig_material(tile.name, tile.name_upper, tile.biome, route_name)
        loot = FieldMoveData.cracked_loot(tile.name_upper)
        if not loot.is_empty():
            tile.has_item = String(loot[rng.randi_range(0, loot.size() - 1)])
            tile.has_item_amount = 1
            interior_interactables[cell] = "ITEM:%s:1" % tile.has_item
        loot = [] # Source leaves buried loot for the next interaction.
        if _dig_is_mountain(tile):
            _clear_dug_mountain(cell, tile)
        else:
            _leave_source_dig_hole(cell, tile)
    else:
        if terrain_kind_at(cell) == 0:
            world_message.emit("DIG can't break water.")
            return
        material = "SOFT SAND" if terrain_kind_at(cell) == 1 else "GRASS"
        terrain[cell.y][cell.x] = 2
        terrain_changes[_cell_key(cell)] = 2
        var sprite: Sprite2D = ground_sprites.get(cell) as Sprite2D
        if is_instance_valid(sprite):
            sprite.texture = GRASS
    var rewards := {material:1}
    play_source_sound("dig1")
    var found: String = ""
    if not loot.is_empty():
        found = String(loot[rng.randi_range(0, loot.size() - 1)])
        rewards[found] = int(rewards.get(found, 0)) + 1
    dig_reward_collected.emit(rewards)
    _m3924_refresh_dig_farms(cell)

func _apply_dig_choice(cell: Vector2i, choice: String) -> bool:
    if active_area_id == "HOUSE":
        if not _house_dig_target_allowed(cell) or not _dig_target_accepts_soil(cell): return false
        if not FieldMoveData.DIG_TERRAIN.has(choice): return false
        built_house_decorations[_built_house_paint_key(cell)] = {"name":"DIG GROUND", "dig_choice":choice, "dig_hole":false}
        _draw_house_decoration(cell)
        play_source_sound("dig1")
        return true
    if _collect_source_dig_item(cell): return false
    if built_structures.has(cell) or resource_objects.has(cell) or landmarks.has(cell):
        world_message.emit("DIG can't change that tile.")
        return false
    if choice == "HOLE":
        _dig_surface(cell)
        return true
    if exact_world_mode and not _dig_target_accepts_soil(cell):
        world_message.emit("DIG can't change that tile.")
        return false
    var info: Dictionary = FieldMoveData.dig_choice_info(choice)
    if info.is_empty():
        return false
    if exact_world_mode and exact_world != null:
        var tile: SourceTile = exact_world.tile_at(cell)
        if tile == null or not (_m3924_dig_tile_is_surface(tile) or _dig_target_accepts_soil(cell)):
            world_message.emit("DIG can't change that tile.")
            return false
        if not _m3924_dig_tile_is_fossil_site(tile) and not tile.name_upper.begins_with("hole1"):
            var exact_resource: Vector2i = _exact_resource_anchor(cell)
            if exact_resource.x > -2147483648:
                world_message.emit("DIG can't change that tile.")
                return false
    elif blocked.has(cell):
        world_message.emit("DIG can't change that tile.")
        return false
    if tall_grass.has(cell):
        _remove_resource(cell, false)
    var base_name: String = String(info.get("base", "green1"))
    if exact_world_mode:
        var tile: SourceTile = exact_world.tile_at(cell)
        FieldMoveData.apply_dig_terrain(tile, choice)
        if choice == "CLIFF": FieldMoveData.adjust_dig_cliff(tile, exact_world.tiles)
        _save_source_dig_tile(cell)
        terrain_changes.erase(_cell_key(cell))
        _connect_source_dig_holes(cell)
        _recoastify_exact_cells([cell])
        _refresh_exact_tile_streams()
    else:
        terrain[cell.y][cell.x] = 1 if "sand" in base_name else 2
        terrain_changes[_cell_key(cell)] = terrain[cell.y][cell.x]
        var sprite: Sprite2D = ground_sprites.get(cell) as Sprite2D
        if is_instance_valid(sprite):
            sprite.texture = SAND if terrain[cell.y][cell.x] == 1 else GRASS
    _m3924_refresh_dig_farms(cell)
    play_source_sound("dig1")
    world_message.emit("DIG changed the ground to %s." % choice)
    return true

func _house_dig_target_allowed(cell: Vector2i) -> bool:
    return _is_built_house_floor_cell(cell) and not built_structures.has(cell) and not interior_interactables.has(cell) and not deployed_pokemon.has(cell) and not wild_eggs.has(cell) and not blocked.has(cell)

var source_surf_wake_distance := 16.0
var source_surf_wake_direction := Vector2.ZERO
var source_surf_wake_frames: Dictionary = {}

func _update_source_surf_wake(before: Vector2, after: Vector2, direction: Vector2) -> void:
    if active_field_move != "SURF" or active_area_id != "OVERWORLD" or exact_world == null:
        source_surf_wake_distance = 16.0
        source_surf_wake_direction = Vector2.ZERO
        return
    var distance := before.distance_to(after)
    if distance <= 0.001:
        return
    var cell := Vector2i(floori(before.x / TILE), floori(before.y / TILE))
    var tile: SourceTile = exact_world.tile_at(cell)
    if tile == null or not tile.is_water:
        return
    var facing := Vector2(signf(direction.x), 0.0) if absf(direction.x) > absf(direction.y) else Vector2(0.0, signf(direction.y))
    if source_surf_wake_direction != facing:
        source_surf_wake_distance = 16.0
    source_surf_wake_direction = facing
    if source_surf_wake_distance >= 16.0:
        source_surf_wake_distance = fmod(source_surf_wake_distance, 16.0)
        _spawn_source_surf_wake(before, facing)
    source_surf_wake_distance += distance

func _spawn_source_surf_wake(anchor: Vector2, facing: Vector2) -> AnimatedSprite2D:
    var vertical := facing.y != 0.0
    var texture: Texture2D = preload("res://assets/source_exact/global/wake2.png") if vertical else preload("res://assets/source_exact/global/wake1.png")
    if not source_surf_wake_frames.has(vertical):
        var frames := SpriteFrames.new()
        frames.add_animation("wake")
        frames.set_animation_loop("wake", false)
        frames.set_animation_speed("wake", 60.0)
        for index in range(3):
            var frame := AtlasTexture.new()
            frame.atlas = texture
            frame.region = Rect2(index * 16, 0, 16, 16)
            frames.add_frame("wake", frame, 13.0 if index == 2 else 12.0)
        source_surf_wake_frames[vertical] = frames
    var wake := AnimatedSprite2D.new()
    wake.name = "SourceSurfWake"
    wake.sprite_frames = source_surf_wake_frames[vertical]
    wake.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    wake.position = anchor.round() + Vector2(0.0, 0.0 if vertical else 4.0)
    wake.flip_h = facing.x > 0.0
    wake.flip_v = facing.y < 0.0
    wake.z_as_relative = false
    wake.z_index = player.z_index - 2
    add_child(wake)
    wake.animation_finished.connect(wake.queue_free)
    wake.play("wake")
    return wake


var walked_open_gates: Dictionary = {}

func _animate_walked_gates(before: Vector2, after: Vector2) -> void:
    # PlayerMoving.java removes the gate overlay after six pixels of approach
    # and restores it eleven pixels into the departure, with gate1/gate2 sounds.
    _animate_source_gates(before, after)
    var nearby: Dictionary = walked_open_gates.duplicate()
    var origin := Vector2i((after / float(TILE)).floor())
    if active_field_move != "FLY":
        for y in range(-1, 2):
            for x in range(-1, 2):
                var cell := origin + Vector2i(x, y)
                if bool(built_structures.get(cell, {}).get("gate", false)):
                    nearby[cell] = true
    for raw_cell in nearby:
        var cell: Vector2i = raw_cell
        var data: Dictionary = built_structures.get(cell, {})
        var sprite := data.get("sprite") as Sprite2D
        if not is_instance_valid(sprite) or not bool(data.get("gate", false)):
            walked_open_gates.erase(cell)
            continue
        var center := _cell_center(cell)
        var closest := Geometry2D.get_closest_point_to_segment(center, before, after)
        var open := walked_open_gates.has(cell)
        if not open and active_field_move != "FLY" and closest.distance_to(center) <= 10.0:
            walked_open_gates[cell] = true
            sprite.hide()
            play_source_sound("gate1")
        elif open and (active_field_move == "FLY" or after.distance_to(center) >= 11.0):
            walked_open_gates.erase(cell)
            sprite.show()
            play_source_sound("gate2")

var source_walked_open_gates: Dictionary = {}
func _animate_source_gates(before: Vector2, after: Vector2) -> void:
    var nearby := source_walked_open_gates.duplicate()
    var origin := Vector2i((after / float(TILE)).floor())
    if active_area_id == "OVERWORLD" and exact_world != null and active_field_move != "FLY":
        for y in range(-1,2):
            for x in range(-1,2):
                var cell := origin + Vector2i(x,y)
                var tile: SourceTile = exact_world.tile_at(cell)
                if tile != null and "gate" in tile.name + tile.name_upper and not built_structures.has(cell): nearby[cell] = true
    for cell in nearby:
        var center := _cell_center(cell)
        var closest := Geometry2D.get_closest_point_to_segment(center,before,after)
        var is_open := source_walked_open_gates.has(cell)
        if not is_open and active_area_id == "OVERWORLD" and active_field_move != "FLY" and closest.distance_to(center) <= 10.0:
            source_walked_open_gates[cell] = true
            play_source_sound("gate1")
        elif is_open and (active_area_id != "OVERWORLD" or active_field_move == "FLY" or after.distance_to(center) >= 11.0):
            source_walked_open_gates.erase(cell)
            play_source_sound("gate2")
        else: continue
        for path in ["GroundLayer/ExactBaseTileStream","DecorLayer/ExactUpperTileStream"]:
            var stream := get_node_or_null(path)
            if stream != null:
                stream.open_gate_cells = source_walked_open_gates.duplicate()
                stream.invalidate_tiles()

func constrain_player_motion(before:Vector2,after:Vector2)->Vector2:
    var result:Vector2=super.constrain_player_motion(before,after)
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        var past:Vector2=coordinator.visuals.constrain_motion(before,result)
        # Easing round another player moves sideways; the ground must allow it.
        if past!=result and past!=before:past=super.constrain_player_motion(before,past)
        result=past
    return result

func _ledge_jump_landing_is_clear(cell:Vector2i)->bool:
    if not super._ledge_jump_landing_is_clear(cell):return false
    var coordinator=get_parent().get("coop_game")
    if is_instance_valid(coordinator) and coordinator.active:
        var target=_cell_center(cell)
        # Reached in several small steps, so compared with a little slack: an
        # exact match failed at random and the jump was refused.
        return coordinator.visuals.constrain_motion(player.position,target).distance_to(target)<0.5
    return true
