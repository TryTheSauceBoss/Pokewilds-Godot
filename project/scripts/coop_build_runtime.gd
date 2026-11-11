extends Node
## All players submit their existing placement result to the host's atomic journal.
## Geometry and snapping still come from World.place_structure.
const Delta=preload("res://scripts/coop_world_delta.gd")
const Transaction=preload("res://scripts/coop_build_transaction.gd")
const GROUPS=["structures","built_house_floor_tiles","built_house_paintings",
    "built_house_decorations","built_house_origins","source_interior_mutations","source_plant_farms","removed_resources","terrain_changes"]
var game:Node
var busy:=false
var last_result:Dictionary={}
var collecting:=false
var field_rewards:Dictionary={}
var field_choice:=""
var field_encounter:Dictionary={}

## One change to one tile that every player must share, such as the host
## taking the mansion key or any player opening the mansion door. It goes to
## the host like a dig, and the host refuses it if that tile was changed
## first by someone else. `rewards` are granted by the host.
func share_tile_change(cell:Vector2i,mutation:Dictionary,rewards:Dictionary={})->bool:
    if busy or game._request_busy:last_result={"ok":false,"reason":"busy"};return false
    busy=true
    var world=game.main.world
    var key:String=world._cell_key(cell)
    var before=Delta.flatten(capture_cut([cell]))
    var previous=world.source_interior_mutations.get(key)
    world.source_interior_mutations[key]=mutation.duplicate(true)
    var after=Delta.flatten(capture_cut([cell]))
    if previous==null:world.source_interior_mutations.erase(key)
    else:world.source_interior_mutations[key]=previous
    var patches=Delta.diff(before,after)
    var known:Dictionary=game.state.records if game.hosting else game.shared_records
    for change in patches:
        change["before"]=game.state.fingerprint(known.get("world/"+game._area()+"/"+String(change.key),Delta.encode(null)))
    var result:Dictionary=await game.command("field_dig",{"area":game._area(),"patches":patches,"rewards":rewards,"choice":""})
    last_result=result.duplicate(true)
    busy=false
    if not result.get("ok",false):return false
    if not rewards.is_empty():game.main._on_dig_reward_collected(rewards,false)
    return true

func collect(items:Dictionary)->bool:
    if not collecting:return false
    for item in items:field_rewards[item]=int(field_rewards.get(item,0))+int(items[item])
    return true

func configure(coordinator:Node)->void:game=coordinator

static func is_build_key(key:String)->bool:
    return key.begins_with("world/") and key.get_slice("/",2) in GROUPS

func capture()->Dictionary:
    var world=game.main.world
    var records:Array=[]
    for cell in world.built_structures:
        var piece:Dictionary=world.built_structures[cell]
        if piece.get("generated_stair_pair",false):continue
        var saved=piece.duplicate(true)
        for key in ["sprite","collision","solid","bridged_water"]:saved.erase(key)
        # Match get_crafting_save_state exactly. Dot assignment introduces
        # StringName keys, whose binary fingerprints differ from String keys.
        saved["name"]=String(piece.get("name",""))
        saved["x"]=cell.x;saved["y"]=cell.y;records.append(saved)
    return {"structures":records,"built_house_floor_tiles":world.built_house_floor_tiles.keys(),
        "built_house_paintings":world.built_house_paintings.duplicate(true),
        "built_house_decorations":world.built_house_decorations.duplicate(true),
        "built_house_origins":world.built_house_origins.duplicate(true),
        "source_interior_mutations":world.source_interior_mutations.duplicate(true),
        "source_plant_farms":world.source_plant_farms.duplicate(true),
        "terrain_changes":world.terrain_changes.duplicate(true),
        "removed_resources":world.removed_resources.keys()}

func model():
    var value=Delta.new();value.state=game.state
    value.can_publish=game.service.areas.can_publish
    return value

func seed(area:String,shared:Dictionary)->bool:
    var delta=model()
    if not game.state.records.get("world_ready/"+area,false):return delta.seed(game.session.actor,area,shared)
    # Full snapshots can spend time in flight. Only reconcile entries which
    # still match the sender's baseline; never overwrite a newer accepted build.
    if not shared.get("_coop_build_base") is Dictionary:return true
    var baseline:Dictionary=shared._coop_build_base
    var current=known(area,game.state.records)
    var next=Delta.flatten(shared)
    var keys=current.keys()
    for key in next:
        if String(key).get_slice("/",0) in GROUPS and key not in keys:keys.append(key)
    var patches:Array=[];var empty=Delta.encode(null)
    for key in keys:
        var old=current.get(key,empty)
        if old!=baseline.get(key,empty):continue
        var value=next.get(key,empty)
        if value!=old:patches.append({"key":key,"before":game.state.fingerprint(old),"after":value})
    while not patches.is_empty():
        var batch=patches.slice(0,Delta.MAX_PATCHES);patches=patches.slice(Delta.MAX_PATCHES)
        var prepared:Dictionary=delta.prepare_changes(area,batch)
        if not prepared.get("ok",false):return false
        var result=game.state.transact(game.session.actor,"buildsync/"+game._id(),prepared.changes)
        if not result.get("ok",false):return false
        game._committed(result)
    return true

static func known(area:String,records:Dictionary)->Dictionary:
    var result:Dictionary={};var prefix="world/"+area+"/"
    for key in records:
        if is_build_key(String(key)) and String(key).begins_with(prefix):result[String(key).trim_prefix(prefix)]=records[key]
    return result

static func overlay(area:String,shared:Dictionary,records:Dictionary)->Dictionary:
    var flat=Delta.flatten(shared)
    flat.merge(known(area,records),true)
    return Delta.inflate(flat,shared)

func build(recipe:String,cell:Vector2i)->void:
    if busy or game._request_busy:return
    busy=true
    var area=game._area()
    var before=Delta.flatten(capture())
    var world=game.main.world
    var target:Vector2i=world._snap_build_cell(recipe,cell)
    if not world.place_structure(recipe,cell):busy=false;return
    var patches=Delta.diff(before,Delta.flatten(capture()))
    var result:Dictionary=await game.command("build",{"area":area,"recipe":recipe,
        "x":target.x,"y":target.y,"patches":patches})
    if not result.get("ok",false) and game.active:
        # The host returns the current records, not the loser's old preview.
        # That keeps a simultaneous winner's construction intact on this client.
        if result.has("authoritative"):apply_records(area,result.authoritative)
        else:game.end_session("BUILD COULD NOT BE SAVED. REJOIN THE WORLD.")
    busy=false

func execute(actor:String,id:String,args:Dictionary)->Dictionary:
    var area=String(args.area)
    var transaction=Transaction.new()
    transaction.state=game.state;transaction.areas=game.service.areas;transaction.world_delta=model()
    var result:Dictionary
    if args.get("field_dig",false):
        result=transaction.dig(actor,id,area,args.patches,args.rewards,String(args.choice),String(args.profile_hash))
    elif args.get("field_cut",false):
        result=transaction.cut(actor,id,area,args.patches,args.rewards,String(args.profile_hash),String(args.get("move","CUT")))
    elif args.get("paint",false):
        result=transaction.paint(actor,id,area,args.patches,String(args.profile_hash))
    elif args.get("remove",false) and args.get("decoration",false):
        result=transaction.remove_decoration(actor,id,area,args.patches,String(args.profile_hash))
    elif args.get("remove",false):
        # Only the host may cut the last public box and empty the world's storage.
        result=transaction.remove(actor,id,area,Vector2i(int(args.x),int(args.y)),String(args.move),args.patches,String(args.profile_hash),
            args.get("wipe_public",false)==true and actor==game.session.actor)
    else:
        result=transaction.commit(actor,id,String(game.state.authority.get(area,"")),area,
            int(game.service.areas.epochs.get(area,0)),String(args.recipe),Vector2i(int(args.x),int(args.y)),
            args.patches,String(args.profile_hash))
    if not result.get("ok",false):
        var authoritative:Array=[]
        for patch in args.patches:
            if not patch is Dictionary or not patch.get("key") is String:continue
            if String(patch.key).get_slice("/",0) not in GROUPS or not Delta.valid_key(patch.key):continue
            authoritative.append({"key":patch.key,"value":Delta.decode(game.state.records.get("world/"+area+"/"+patch.key,Delta.encode(null)))})
        result["authoritative"]=authoritative
    return result

func cut(cell:Vector2i,move:String="CUT")->void:
    if busy or game._request_busy:return
    busy=true
    var area=game._area()
    var cells=cut_cells(cell)
    var before=Delta.flatten(capture_cut(cells))
    var original_tiles:Dictionary={}
    if game.main.world.exact_world!=null:
        for at in cells:
            var tile=game.main.world.exact_world.tile_at(at)
            if tile!=null:original_tiles[game.main.world._cell_key(at)]=[tile.name,tile.name_upper]
    var prior_encounter:Dictionary=game.main.world.pending_encounter_record.duplicate(true)
    field_rewards={};field_encounter={};collecting=true
    if move=="CUT":game.main.world._try_cut_target(cell)
    elif game.main.world.exact_world_mode:game.main.world._harvest_exact_resource(cell,move)
    else:game.main.world._harvest_resource_with_move(cell,move)
    collecting=false
    var encounter=field_encounter.duplicate(true)
    game.main.world.pending_encounter_record=prior_encounter
    var rewards=field_rewards.duplicate(true)
    var patches=Delta.diff(before,Delta.flatten(capture_cut(cells)))
    if patches.is_empty():busy=false;return
    var result:Dictionary=await game.command("field_cut",{"area":area,"patches":patches,"rewards":rewards,"move":move})
    last_result=result.duplicate(true)
    if result.get("ok",false):
        game.main._on_build_refund_requested(rewards,false)
        if not encounter.is_empty():
            game.main.world.pending_encounter_record=encounter.record
            game.main.world.encounter_requested.emit(encounter.species,int(encounter.level))
    elif game.active:
        var recoverable=result.has("authoritative")
        for record in result.get("authoritative",[]):
            if record.value==null and String(record.key).begins_with("source_interior_mutations/") and not original_tiles.has(String(record.key).get_slice("/",1).uri_decode()):recoverable=false
            if record.value==null and String(record.key).begins_with("removed_resources/"):recoverable=false
        if recoverable:
            apply_records(area,result.authoritative)
            for record in result.authoritative:
                if record.value!=null or not String(record.key).begins_with("source_interior_mutations/"):continue
                var key=String(record.key).get_slice("/",1).uri_decode()
                var names:Array=original_tiles[key]
                game.main.world._set_exact_tile_names(game.main.world._cell_from_key(key),names[0],names[1])
            if result.get("reason")!="conflict":game.main._show_message("FIELD ACTION COULD NOT BE SAVED.")
        else:game.end_session("FIELD ACTION COULD NOT BE SAVED. REJOIN THE WORLD.")
    busy=false

func plant(cell:Vector2i,item:String,animate:bool=true)->bool:
    if busy or game._request_busy:return false
    if int(game.main.inventory.get(item,0))<1:return false
    var world=game.main.world
    if world.exact_world==null:return false
    var tile=world.exact_world.tile_at(cell)
    if not world.plants().valid(tile,item):return false
    busy=true
    var before=Delta.flatten(capture_cut(dig_cells(cell)))
    var original=[tile.name,tile.name_upper]
    collecting=true
    var planted:bool=await world.plants().plant(cell,item,false)
    collecting=false
    if not planted:busy=false;return false
    var upper:String=tile.name_upper
    var patches=Delta.diff(before,Delta.flatten(capture_cut(dig_cells(cell))))
    # Say what the tile was by the shared records. A plant grows in each game
    # by itself and its record drifts (the fruit it will give is random), so
    # the host refused manure on a grown bush and the manure vanished again.
    var known:Dictionary=game.state.records if game.hosting else game.shared_records
    for patch in patches:
        patch["before"]=game.state.fingerprint(known.get("world/"+game._area()+"/"+String(patch.key),Delta.encode(null)))
    var result:Dictionary=await game.command("field_dig",{"area":game._area(),"patches":patches,"rewards":{},"choice":"PLANT:"+item})
    last_result=result.duplicate(true)
    if not result.get("ok",false):
        if game.active and result.has("authoritative"):
            apply_records(game._area(),result.authoritative)
            var key="source_plant_farms/"+world._cell_key(cell).uri_encode()
            var changed_ground=false
            for record in result.authoritative:
                if record.key=="source_interior_mutations/"+world._cell_key(cell).uri_encode() and record.value!=null:changed_ground=true
            for record in result.authoritative:
                if record.key==key and record.value==null and not changed_ground:world._set_exact_tile_names(cell,original[0],original[1])
        busy=false;return false
    if animate and item not in ["MANURE","MIRACLE SEED"]:await world.plants().animate_planted(cell,tile,upper,false)
    busy=false
    return true

func pick_berry(cell:Vector2i)->void:
    if busy or game._request_busy:return
    var world=game.main.world
    var berry:String=world._exact_berry_name(cell)
    if berry.is_empty():return
    var key:String=world._cell_key(cell)
    if world.source_interior_mutations.get(key,{}).get("kind")=="BERRY_AGITATED":return
    var tile=world.exact_world.tile_at(cell)
    var before=Delta.flatten(capture_cut([cell]));var after=before.duplicate(true)
    var encounter:Dictionary={};var rewards:Dictionary={}
    if tile.route_belongs_to!=null and not tile.route_belongs_to.stored_pokemon.is_empty():
        encounter=tile.route_belongs_to.stored_pokemon[0].duplicate(true)
        after["source_interior_mutations/"+key.uri_encode()]=Delta.encode({"kind":"BERRY_AGITATED","base":tile.name,"clear_at":world.world_elapsed_seconds+400.0/60.0})
        after["source_plant_farms/"+key.uri_encode()]=Delta.encode(null)
    else:
        var upper:String=tile.name_upper.replace("_full","_empty")
        after["source_interior_mutations/"+key.uri_encode()]=Delta.encode({"kind":"BERRY_EMPTY","upper":upper})
        after["source_plant_farms/"+key.uri_encode()]=Delta.encode({"base":tile.name,"upper":upper,"day":world.plants().day(),"rewards":{}})
        rewards[berry]=1
    busy=true
    var result:Dictionary=await game.command("field_dig",{"area":game._area(),"patches":Delta.diff(before,after),"rewards":rewards,"choice":""},true)
    last_result=result.duplicate(true)
    if result.get("ok",false):
        if encounter.is_empty():
            world.play_source_sound("Berry_Get")
            game.main._on_dig_reward_collected(rewards,false)
        else:
            if tile.route_belongs_to!=null and not tile.route_belongs_to.stored_pokemon.is_empty():tile.route_belongs_to.stored_pokemon.pop_front()
            world.pending_encounter_record=encounter
            world.play_source_sound("ledge2")
            world.world_message.emit("The tree became agitated and attacked!")
            world.encounter_requested.emit(String(encounter.get("name",encounter.get("species","sudowoodo"))).to_lower(),int(encounter.get("level",1)))
    elif game.active and result.has("authoritative"):apply_records(game._area(),result.authoritative)
    busy=false

func collect_item(action:String,cell:Vector2i)->void:
    if busy or game._request_busy:return
    var parts=action.split(":")
    if parts.size()!=3:return
    var world=game.main.world
    var key:String=world._cell_key(cell)
    var before=Delta.flatten(capture_cut([cell]))
    var mutation:Dictionary=world.source_interior_mutations.get(key,{})
    var tile=world.exact_world.tile_at(cell) if world.exact_world!=null else null
    if String(world.interior_interactables.get(cell,""))!=action and (tile==null or String(tile.has_item).is_empty()):return
    # Keep the ground and hole of an excavated item. Ordinary source pickups
    # use COLLECTED, exactly as the original interaction does.
    var item=String(mutation.get("dig_item",parts[1])).to_upper()
    if item.is_empty():item=String(parts[1]).to_upper()
    var amount=maxi(1,int(mutation.get("dig_item_amount",parts[2])))
    var next=mutation.duplicate(true) if not String(mutation.get("dig_item","")).is_empty() else {"kind":"COLLECTED"}
    if next.get("kind")=="TILE_NAMES":
        next["dig_item"]="";next["dig_item_amount"]=0
        if String(next.get("upper","")).begins_with("hole1"):next["upper"]="hole1"
    var after=before.duplicate(true)
    after["source_interior_mutations/"+key.uri_encode()]=Delta.encode(next)
    var patches=Delta.diff(before,after)
    if patches.is_empty():return
    busy=true
    var rewards={item:amount}
    var result:Dictionary=await game.command("field_dig",{"area":game._area(),"patches":patches,"rewards":rewards,"choice":""})
    last_result=result.duplicate(true)
    if result.get("ok",false):game.main._on_dig_reward_collected(rewards,false)
    elif game.active and result.has("authoritative"):apply_records(game._area(),result.authoritative)
    busy=false

func dig_cells(cell:Vector2i)->Array:
    var cells:Array=[]
    for y in range(-1,2):
        for x in range(-1,2):cells.append(cell+Vector2i(x,y))
    return cells

func capture_dig(cell:Vector2i)->Dictionary:
    var world=game.main.world
    var cells=dig_cells(cell)
    var result=capture_cut(cells)
    result["terrain_changes"]={};result["built_house_decorations"]={}
    for at in cells:
        var key:String=world._cell_key(at)
        if world.terrain_changes.has(key):result.terrain_changes[key]=world.terrain_changes[key]
        if world.active_area_id=="HOUSE":
            var house_key:String=world._built_house_paint_key(at)
            if world.built_house_decorations.has(house_key):result.built_house_decorations[house_key]=world.built_house_decorations[house_key].duplicate(true)
    return result

func dig(cell:Vector2i,choice:String="")->void:
    if busy or game._request_busy:return
    if choice.is_empty() and game.main.world.exact_world!=null:
        var item_tile=game.main.world.exact_world.tile_at(cell)
        if item_tile!=null and not String(item_tile.has_item).is_empty():
            await collect_item("ITEM:%s:%d"%[String(item_tile.has_item).to_upper(),maxi(1,int(item_tile.has_item_amount))],cell)
            return
    busy=true
    var world=game.main.world;var area=game._area()
    var before=Delta.flatten(capture_dig(cell))
    var originals:Dictionary={}
    if world.exact_world!=null:
        for at in dig_cells(cell):
            var tile=world.exact_world.tile_at(at)
            if tile!=null:
                originals[world._cell_key(at)]={"base":tile.name,"upper":tile.name_upper,"biome":tile.biome,
                    "route":tile.route_belongs_to,"item":tile.has_item,"amount":tile.has_item_amount,
                    "mountain":tile.is_bottom_mtn_layer,"ocean":tile.shore_ocean,"tidal":tile.shore_tidal}
    field_rewards={};field_choice="";collecting=true
    if choice.is_empty():world._use_dig(cell)
    else:game.main._on_dig_requested(choice,cell,String(preload("res://scripts/field_move_data.gd").dig_choice_info(choice).get("material","")))
    collecting=false
    var rewards=field_rewards.duplicate(true)
    var patches=Delta.diff(before,Delta.flatten(capture_dig(cell)))
    if patches.is_empty():busy=false;return
    # Say what each tile was by the shared records, not by this game's own
    # copy. The two can drift apart (daily dig sites are tidied locally), and
    # the host then refused the fill as a conflict: the hole stayed although
    # the game had already said the ground was changed.
    var known:Dictionary=game.state.records if game.hosting else game.shared_records
    for patch in patches:
        patch["before"]=game.state.fingerprint(known.get("world/"+area+"/"+String(patch.key),Delta.encode(null)))
    var result:Dictionary=await game.command("field_dig",{"area":area,"patches":patches,"rewards":rewards,"choice":field_choice})
    last_result=result.duplicate(true)
    if result.get("ok",false):
        if not rewards.is_empty():game.main._on_dig_reward_collected(rewards,false)
    elif game.active:
        var recoverable=result.has("authoritative")
        for record in result.get("authoritative",[]):
            var group=String(record.key).get_slice("/",0)
            var key=String(record.key).get_slice("/",1).uri_decode()
            if record.value==null and group in ["source_interior_mutations","terrain_changes","removed_resources"]:
                if not originals.has(key) or not String(originals[key].item).is_empty():recoverable=false
        if recoverable:
            apply_records(area,result.authoritative)
            for record in result.authoritative:
                var group=String(record.key).get_slice("/",0)
                if record.value!=null or group not in ["source_interior_mutations","terrain_changes"]:continue
                var key=String(record.key).get_slice("/",1).uri_decode()
                var saved:Dictionary=originals[key]
                var at:Vector2i=world._cell_from_key(key)
                var tile=world.exact_world.tile_at(at)
                tile.set_names(saved.base,saved.upper);tile.biome=saved.biome;tile.route_belongs_to=saved.route
                tile.has_item=saved.item;tile.has_item_amount=saved.amount;tile.is_bottom_mtn_layer=saved.mountain
                tile.shore_ocean=saved.ocean;tile.shore_tidal=saved.tidal
            world._refresh_exact_tile_streams()
            if result.get("reason")!="conflict":game.main._show_message("FIELD ACTION COULD NOT BE SAVED.")
        else:game.end_session("FIELD ACTION COULD NOT BE SAVED. REJOIN THE WORLD.")
    busy=false

func cut_cells(cell:Vector2i)->Array:
    var world=game.main.world
    var cells:Array=[cell]
    var anchor:Vector2i=world._exact_resource_anchor(cell)
    if anchor.x<=-2147483648:anchor=world._resource_object_anchor(cell)
    if anchor.x>-2147483648 and anchor not in cells:cells.append(anchor)
    if world.exact_world_mode:
        var giant:Vector2i=world._exact_large_tree1_anchor(anchor if anchor.x>-2147483648 else cell)
        if giant.x>-2147483648:
            for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1)]:
                if giant+offset not in cells:cells.append(giant+offset)
    return cells

func capture_cut(cells:Array)->Dictionary:
    # CUT edits its target or the source's four-part giant tree. Do not scan
    # every building, farm and previous terrain edit on every grass cut.
    var world=game.main.world
    var result={"source_interior_mutations":{},"source_plant_farms":{},"removed_resources":[]}
    for cell in cells:
        var key:String=world._cell_key(cell)
        for group in ["source_interior_mutations","source_plant_farms"]:
            var records:Dictionary=world.get(group)
            if records.has(key):result[group][key]=records[key].duplicate(true)
        if world.removed_resources.has(key):result.removed_resources.append(key)
    return result

func paint(picture:int,cell:Vector2i)->void:
    if busy or game._request_busy:return
    busy=true
    var area=game._area()
    var before=Delta.flatten(capture())
    if not game.main.world.apply_paint(picture,cell):busy=false;return
    var patches=Delta.diff(before,Delta.flatten(capture()))
    if patches.is_empty():busy=false;return
    var result:Dictionary=await game.command("paint",{"area":area,"patches":patches})
    last_result=result.duplicate(true)
    if not result.get("ok",false) and game.active:
        if result.has("authoritative"):apply_records(area,result.authoritative)
        else:game.end_session("FIELD ACTION COULD NOT BE SAVED. REJOIN THE WORLD.")
    busy=false

func remove(cell:Vector2i,move:String,wipe_public:bool=false)->void:
    if busy or game._request_busy:return
    var world=game.main.world
    var piece:Dictionary=world.built_structures.get(cell,{})
    if piece.is_empty():return
    if piece.get("generated_stair_pair",false):
        cell=Vector2i(int(piece.stair_primary_x),int(piece.stair_primary_y))
        piece=world.built_structures.get(cell,{})
        if piece.is_empty():return
    var name=String(piece.get("name",""))
    if (move=="CUT" and name in ["GRAVE","STATUE"]) or (move=="SMASH" and name not in ["GRAVE","STATUE"]):return
    busy=true
    var area=game._area();var before=Delta.flatten(capture())
    var original_ground:Array=[]
    if world.exact_world!=null:
        var tile=world.exact_world.tile_at(cell)
        if tile!=null:original_ground=[tile.name,tile.name_upper]
    world._remove_structure(cell,false)
    var patches=Delta.diff(before,Delta.flatten(capture()))
    var request:={"area":area,"remove":true,"move":move,"x":cell.x,"y":cell.y,"patches":patches}
    if wipe_public:request["wipe_public"]=true
    var result:Dictionary=await game.command("remove_build",request)
    last_result=result.duplicate(true)
    if result.get("ok",false):
        game.main._on_build_refund_requested(result.get("refund",{}),false)
        if name=="GRAVE" and world.rng.randi_range(0,8)==0:
            var pool=["gastly","misdreavus","duskull","shuppet"]
            var species=pool[world.rng.randi_range(0,3)]
            world.world_message.emit("Something rose from the shattered GRAVE!")
            world.encounter_requested.emit(species,22)
    elif game.active:
        if result.get("reason")=="last_box":
            game.main._show_message("Sorry, a guest cannot cut the last public box in a world." if not game.hosting else "The last STORAGE BOX in this world cannot be cut this way.")
        if result.has("authoritative"):
            apply_records(area,result.authoritative)
            var terrain_key="source_interior_mutations/"+world._cell_key(cell).uri_encode()
            for record in result.authoritative:
                if record.key==terrain_key and record.value==null and original_ground.size()==2:
                    world._set_exact_tile_names(cell,original_ground[0],original_ground[1])
        else:game.end_session("FIELD ACTION COULD NOT BE SAVED. REJOIN THE WORLD.")
    busy=false

## Takes a window or clock off a house wall; the host refunds its materials.
func remove_decoration(cell:Vector2i)->void:
    if busy or game._request_busy:return
    var world=game.main.world
    if String(world.house_wall_decoration_at(cell)).is_empty():return
    busy=true
    var area=game._area();var before=Delta.flatten(capture())
    world.remove_house_wall_decoration(cell,false)
    var patches=Delta.diff(before,Delta.flatten(capture()))
    var result:Dictionary=await game.command("remove_build",{"area":area,"remove":true,"decoration":true,"move":"CUT",
        "x":cell.x,"y":cell.y,"patches":patches})
    last_result=result.duplicate(true)
    if result.get("ok",false):game.main._on_build_refund_requested(result.get("refund",{}),false)
    elif game.active:
        if result.has("authoritative"):apply_records(area,result.authoritative)
        else:game.end_session("FIELD ACTION COULD NOT BE SAVED. REJOIN THE WORLD.")
    busy=false

func committed(changes:Array)->void:
    var area=game._area();var prefix="world/"+area+"/"
    var records:Array=[]
    for change in changes:
        if is_build_key(String(change.key)) and String(change.key).begins_with(prefix):
            records.append({"key":String(change.key).trim_prefix(prefix),"value":Delta.decode(String(change.after))})
    if not records.is_empty():apply_records(area,records)

func sync_current()->void:
    var area=game._area()
    var current=Delta.flatten(capture())
    var authoritative=known(area,game.state.records if game.hosting else game.shared_records)
    var changes:Array=[]
    for key in authoritative:
        if current.get(key,Delta.encode(null))!=authoritative[key]:changes.append({"key":key,"value":Delta.decode(authoritative[key])})
    if not changes.is_empty():apply_records(area,changes,true)

func apply_records(area:String,records:Array,arriving:bool=false)->void:
    if area!=game._area() or not game.main.world.generated:return
    if not arriving and (game.main.generating or game.main.edge_travel_busy):return
    var world=game.main.world
    var house_changed=false
    var structures:Array=[]
    var was_restoring:bool=world.restoring_saved_tiles
    var refresh_pending:bool=world.restored_tiles_need_refresh
    var changed_cells:Dictionary={}
    var decorated:Dictionary={}
    world.restoring_saved_tiles=true
    for record in records:
        var group=String(record.key).get_slice("/",0)
        var key=String(record.key).get_slice("/",1).uri_decode()
        if group=="structures":structures.append(record);continue
        if group not in GROUPS:continue
        if group in ["source_interior_mutations","source_plant_farms","terrain_changes","removed_resources"]:
            var center:Vector2i=world._cell_from_key(key)
            for y in range(-2,3):
                for x in range(-2,3):changed_cells[center+Vector2i(x,y)]=true
        var dictionary:Dictionary=world.get(group)
        if record.value==null:dictionary.erase(key)
        else:dictionary[key]=true if group in ["built_house_floor_tiles","removed_resources"] else record.value
        if group=="removed_resources":
            if record.value!=null:world._remove_resource(world._cell_from_key(key),false)
            continue
        if group=="terrain_changes":
            if record.value!=null:
                var at:Vector2i=world._cell_from_key(key)
                if world.exact_world_mode:world._set_exact_tile_names(at,"sand1" if int(record.value)==1 else "green1","")
                elif world._in_bounds(at):
                    world.terrain[at.y][at.x]=int(record.value)
                    var sprite=world.ground_sprites.get(at)
                    if is_instance_valid(sprite):sprite.texture=world.SAND if int(record.value)==1 else world.GRASS
            continue
        if group=="source_plant_farms":
            if record.value is Dictionary and world.exact_world!=null:
                world._set_exact_tile_names(world._cell_from_key(key),String(record.value.base),String(record.value.upper))
            continue
        if group=="source_interior_mutations":
            if record.value is Dictionary:world._apply_source_interior_mutation(world._cell_from_key(key),record.value)
            continue
        # A floor tile added upstairs is laid on its own. Rebuilding the whole
        # inside of the house for each one made every floor blink black.
        if group=="built_house_floor_tiles" and record.value!=null:
            var parts=key.split("|")
            if parts.size()==3 and world.active_area_id=="HOUSE":
                var door=parts[0].split(",");var local=parts[2].split(",")
                if door.size()==2 and local.size()==2 and Vector2i(int(door[0]),int(door[1]))==world.active_built_house_door:
                    if world._add_built_house_floor_cell(int(parts[1]),Vector2i(int(local[0]),int(local[1])),false):continue
                else:continue
            elif world.active_area_id!="HOUSE":continue
        # A carpet, clock or window is drawn or taken away on its own as well.
        if group=="built_house_decorations":
            if world.active_area_id!="HOUSE":continue
            var pieces=key.split("|")
            var door_at=pieces[0].split(",");var local_at=pieces[pieces.size()-1].split(",")
            if pieces.size() not in [2,3] or door_at.size()!=2 or local_at.size()!=2:house_changed=true;continue
            if Vector2i(int(door_at[0]),int(door_at[1]))!=world.active_built_house_door:continue
            var storey:int=int(String(pieces[1]).trim_prefix("F")) if pieces.size()==3 else 0
            decorated[world._built_house_global_cell(storey,Vector2i(int(local_at[0]),int(local_at[1])))]=record.value!=null
            continue
        house_changed=true
    world.restoring_saved_tiles=was_restoring
    if not was_restoring:
        world.restored_tiles_need_refresh=refresh_pending
        if not changed_cells.is_empty():world._refresh_exact_pickup_cells(changed_cells.keys())
    for record in structures:
        var parts=String(record.key).get_slice("/",1).uri_decode().split(",")
        var cell=Vector2i(int(parts[0]),int(parts[1]))
        var existing:Dictionary=world.built_structures.get(cell,{})
        if record.value==null:
            if not existing.is_empty():world._remove_structure(cell,false)
            continue
        var value:Dictionary=record.value
        if existing.is_empty():
            if not world.place_structure(String(value.get("recipe_name",value.name)),cell,true,value,true):
                # An outside piece recorded somewhere that is not on the open map
                # (built inside a house by an older version) can never be placed.
                # It is passed over; it used to end the session for everyone.
                if String(value.get("name","")) in ["FENCE","WALL","ROOF","DOOR"] and not world._in_bounds(cell):continue
                game.end_session("SHARED BUILD COULD NOT LOAD. REJOIN THE WORLD.");return
        else:
            for key in value:
                if key not in ["sprite","collision","solid","bridged_water","x","y"]:existing[key]=value[key]
            if is_instance_valid(existing.get("sprite")):
                var texture=world._structure_display_texture(String(value.get("recipe_name",value.name)),int(value.get("variant",0)))
                if value.name=="BED" and int(value.get("bed_carpet",0))>0:texture=world._colored_bed_texture(int(value.bed_carpet))
                existing.sprite.texture=texture
            world._refresh_connected_structures_around(cell)
            world._refresh_shell_attachment(cell)
        if value.name=="STAIRS":house_changed=true
    if not house_changed and world.active_area_id=="HOUSE":
        for at in decorated:
            if decorated[at]:world._draw_house_decoration(at)
            else:
                var hung=world.built_house_decoration_sprites.get(at)
                if is_instance_valid(hung):hung.queue_free()
                world.built_house_decoration_sprites.erase(at)
    if house_changed and world.active_area_id=="HOUSE":
        var floor_index:int=world._built_house_floor_index_for_cell(world._player_cell())
        var house:Dictionary=world._built_house_state(world.active_built_house_door)
        if house.get("ready",false):
            world._prepare_built_house_interior(world.active_built_house_door,house)
            world._set_active_built_house_floor(maxi(0,floor_index))
            var layer=world.get_node_or_null("BuiltHouseInterior")
            if layer!=null:layer.visible=true
    world.map_art_revision+=1
