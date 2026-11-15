class_name SourceMansionRuntime
extends RefCounted

# Tile.onPressA / FlipDoorTile: a statue toggles its linked doors one plane below.
static func press_switch(world, cell: Vector2i, changed: Dictionary = {}) -> int:
    var statue = world._source_interior_tile_at_world_cell(cell)
    if statue == null or statue.name != "pkmnmansion_statue1":
        return 0
    var level := -1
    for plan in world.generated_source_interior_plans:
        var origin: Vector2i = world.source_area_origins.get(plan.id, Vector2i.ZERO)
        if plan.tiles.get(cell - origin) == statue:
            level = int(plan.layer_index) - 1
            break
    var count := 0
    for plan in world.generated_source_interior_plans:
        if int(plan.layer_index) != level:
            continue
        var origin: Vector2i = world.source_area_origins[plan.id]
        for position in statue.door_tiles:
            var source_cell := SourceWorldData.pixel_to_cell(position)
            if not plan.source_to_local.has(source_cell):
                continue
            var local_cell: Vector2i = plan.source_to_local[source_cell]
            var tile: SourceTile = plan.tiles[local_cell]
            var name: String = tile.name
            if "__on" in name: name = name.replace("__on", "__off")
            elif "__off" in name: name = name.replace("__off", "__on")
            else: continue
            var target := origin + local_cell
            set_gate(world, target, name)
            world.source_interior_mutations[world._cell_key(target)] = {"kind":"MANSION_GATE", "name":name}
            changed[target] = {"kind":"MANSION_GATE", "name":name}
            count += 1
    return count

static func set_gate(world, cell: Vector2i, name: String) -> void:
    var tile = world._source_interior_tile_at_world_cell(cell)
    if tile == null or not ("__on" in tile.name or "__off" in tile.name):
        return
    if name.trim_suffix("__on").trim_suffix("__off") != tile.name.trim_suffix("__on").trim_suffix("__off"):
        return
    tile.name = name
    tile.is_solid = name.ends_with("__on")
    var sprite = world.source_interior_upper_sprites.get(cell)
    if is_instance_valid(sprite):
        sprite.texture = SourceWorldData.texture_for(name)
    var collision = world.source_event_collisions.get(cell)
    if tile.is_solid:
        world.blocked[cell] = true
        if not is_instance_valid(collision):
            var body = world.get_node_or_null("InteriorLayer/SourceInteriorCollision")
            if body != null:
                collision = world._add_landmark_collision(body, cell.x, cell.y)
                world.source_event_collisions[cell] = collision
        if is_instance_valid(collision): collision.set_deferred("disabled", false)
    else:
        world.blocked.erase(cell)
        if is_instance_valid(collision): collision.set_deferred("disabled", true)
    world.interior_map_cache_key = []

static func clear_collected_item(world, cell: Vector2i) -> void:
    var tile = world._source_interior_tile_at_world_cell(cell)
    if tile == null or not tile.name.begins_with("pkmnmansion"):
        return
    tile.has_item = ""
    tile.has_item_amount = 0
    tile.set_names(tile.name, "")
    world.blocked.erase(cell)
    var collision = world.source_event_collisions.get(cell)
    if is_instance_valid(collision): collision.set_deferred("disabled", true)

# PlayerStanding.checkWildEncounter: dungeon route level + 0..2, evolution
# checks with +10 per stage, then +10 actual levels for each successful stage.
static func encounter(base_level: int, rng: RandomNumberGenerator) -> Dictionary:
    var pool := SourceRouteData.allowed_pokemon("pkmnmansion1")
    var species := String(pool[rng.randi_range(0, pool.size() - 1)])
    var level := base_level + rng.randi_range(0, 2)
    var evolved := 0
    while evolved < 4:
        var selected := ""
        for evolution in PokemonData._java_evolution_order(PokemonData.info(species).get("evolutions", [])):
            var parameter := String(evolution.get("parameter", ""))
            if parameter.is_valid_int():
                if int(parameter) <= level + 10 * (evolved + 1) and rng.randi_range(0,255) >= 128:
                    selected = String(evolution.species)
                    break
            elif rng.randi_range(0,255) >= 192:
                selected = String(evolution.species)
                break
        if selected.is_empty() or selected == species: break
        species = selected
        evolved += 1
    return {"species":species, "level":clampi(level + 10 * evolved,2,100)}
