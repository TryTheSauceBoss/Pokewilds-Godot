extends RefCounted
const Paths=preload("res://scripts/game_data_paths.gd")
static func token() -> String:
    var path:=Paths.path("coop_identity.cfg")
    var config:=ConfigFile.new()
    if config.load(path)==OK:
        var existing:=String(config.get_value("player","token",""))
        if existing.length()==64 and existing.is_valid_hex_number():return existing
        return "" # Never silently replace a damaged identity and lose its online saves.
    if FileAccess.file_exists(path):return ""
    var value:=preload("res://scripts/coop_random.gd").hex(32)
    config.set_value("player","token",value)
    if config.save(path+".pending")!=OK:return ""
    if DirAccess.rename_absolute(path+".pending",path)!=OK:return ""
    return value

static func mods() -> Dictionary:
    var packs=load("res://scripts/native_mod_pack.gd")
    if not packs.last_error.is_empty():return {"error":"Resolve mod loading errors before joining."}
    var entries: Array=[]
    for row in packs.library():
        if not row.get("enabled",false):continue
        var path:=String(row.get("path",""))
        if not FileAccess.file_exists(path):return {"error":"An enabled mod package is missing."}
        # Pictures, sounds and shiny colours are only drawn on this player's own
        # screen; everyone else sees their own art. Only changes to how the game
        # plays must match the host, so art-only mods join anyone, even players
        # with no mods at all.
        var play:=_gameplay_changes(packs._manifest(path))
        if play.is_empty():continue
        entries.append({"id":String(row.id),"changes":play})
    # In load order: a later mod wins where two change the same thing.
    return {"entries":entries,"digest":JSON.stringify(entries,"",true,true).sha256_text()}

const LOOKS:=["mod_name","front","back","overworld","front_shiny","back_shiny","overworld_shiny","cry"]

static func _gameplay_changes(manifest:Dictionary)->Dictionary:
    var result:={}
    var species=manifest.get("species",{})
    if not species is Dictionary:return result
    for name in species:
        var patch=species[name]
        if not patch is Dictionary:continue
        var kept:={}
        for field in patch:
            if not field in LOOKS:kept[field]=patch[field]
        if not kept.is_empty():result[name]=kept
    return result
