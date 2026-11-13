extends RefCounted
## Authored normal and shiny sheets. GEN3 artwork remains unchanged.
static var cache := {}
static func texture(species: String, kind: String, shiny: bool = false) -> Texture2D:
    if preload("res://scripts/gen3_overhaul.gd").enabled: return null
    if species not in ["mega_gengar", "mega_charizard_x", "mega_charizard_y", "mega_blastoise", "mega_venusaur", "mega_gyarados", "mega_kangaskhan", "mega_sharpedo"]: return null
    if kind not in ["overworld", "menu"]: return null
    var original := "res://assets/community_mega_gengar/princess_phoenix_sheet.png" if species=="mega_gengar" else str(PokemonData.info(species).get("overworld",""))
    if preload("res://scripts/gen3_overhaul.gd").user_paths.has(original): return null
    var key := species + "-" + kind + ("-shiny" if shiny else "")
    if not cache.has(key):
        var result: Texture2D = load("res://assets/divinakra_megas/" + key + ".png")
        if kind == "overworld": result.set_meta("mega_gengar_walk", true)
        # Mega Gyarados is drawn at 50x50, larger than the other 32x32 sheets.
        # Lift it so it stands on its tile as they do instead of hanging below it.
        if kind == "overworld" and result.get_height() > 32: result.set_meta("overworld_feet_offset", Vector2(0, -(result.get_height() - 32) / 2.0))
        cache[key] = result
    return cache[key]
