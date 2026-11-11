extends Node
## Live scene coordinator. Local gameplay never enters this adapter unless ONLINE is selected.
const Session=preload("res://scripts/coop_session.gd")
const Identity=preload("res://scripts/coop_identity.gd")
const State=preload("res://scripts/coop_state.gd")
const Store=preload("res://scripts/coop_store.gd")
const Saves=preload("res://scripts/coop_game_saves.gd")
const Areas=preload("res://scripts/coop_area_service.gd")
const Snapshot=preload("res://scripts/coop_world_snapshot.gd")
const Players=preload("res://scripts/coop_players.gd")
const Commands=preload("res://scripts/coop_commands.gd")
const Cache=preload("res://scripts/source_world_cache.gd")
const Paths=preload("res://scripts/game_data_paths.gd")
const Network=preload("res://scripts/coop_network.gd")
const Lobby=preload("res://scripts/coop_lobby.gd")
const Patch=preload("res://scripts/coop_patch.gd")
const PrivateBox=preload("res://scripts/coop_private_box.gd")
var main:Node
var session:Node
var visuals:Node
var service:Node
var commands:Node
var interaction_ui:Control
var pings:Control
var rest:Node
var storage:Node
var beacons:Node
var building:Node
var state=State.new()
var store=Store.new()
var saves=Saves.new()
var active:=false
var new_setup_pending:=false
var join_setup_code:=""
var lobby:Node
var lobby_private:=false
var lobby_password:=""
var lobby_salt:=""
var lobby_name:=""
var join_lobby:Dictionary={}
var join_password:=""
var notice:=""
var hosting:=false
var world_id:=""
var pending_game:Dictionary={}
var _guest_game:Dictionary={}
var _loading:=false
var _publishing:=false
var endpoints:Array[Dictionary]=[]
var endpoint_index:=0
var profile_base:=""
var _replies:Dictionary={}
var _request_busy:=false
var _last_checkpoint:=0
var _last_full_checkpoint:=0
var _saved_stamp:Array=[]
## How often a player who is only walking has their record brought up to date.
## Each one gathers, compares and fingerprints the whole character record
## (party, bag, Pokedex, explored map), on that player's device and again on
## the host: tens of milliseconds, felt as a small stall. Other players see
## movement through the live position updates, not through this, and a changed
## party or bag is still saved on the 0.75 s beat, so this can be unhurried.
const POSITION_CHECKPOINT_MS:=30000
const REST_CHECKPOINT_MS:=6000
## The journal is replayed in full on the next load. Folding it into a world
## save at this size keeps loading quick however long a session lasts.
const JOURNAL_COMPACT_BYTES:=24*1024*1024
var _journal_checked:=0
## Creature movement is not journaled, so a world save also runs this often
## while there is movement to keep; a crash loses at most this much wandering.
const MOTION_SAVE_MS:=10*60*1000
var _world_saved_at:=0
var _choosing:=false
var shared_records:Dictionary={}
var _picking:Dictionary={}
static var ended_reason:=""
var clock_seconds:=0.0
var clock_speed:=1.0
var _clock_received:=0
var _clock_sent:=0
var _checkpoint_running:=false
var pvp:Node
var wild:Node
var population:Node
var hordes:Control
var raids:Node
var population_battles:Node
var events:Node
var _profile_write_busy:=false
var area_authority:=""
var area_epoch:=0
var _travel_target:=""
var _travel_offer:Dictionary={}
var _travel_token:=""
var _entry_reply:Dictionary={}
var _area_flushes:Dictionary={}

func _flush_area(area:String)->bool:
    var owner=String(state.authority.get(area,""))
    if owner.is_empty():return true
    if owner==session.actor:
        while _publishing:await get_tree().process_frame
        return await publish_current()
    var target=-1
    for peer in session.players:
        if session.players[peer].actor==owner:target=peer
    if target<0:return false
    var id=_id()
    if session.send_to(target,{"kind":"area_flush","id":id,"area":area})!=OK:return false
    var deadline=Time.get_ticks_msec()+120000
    while session.players.has(target) and Time.get_ticks_msec()<deadline:
        if _area_flushes.has(id):
            var result:bool=_area_flushes[id];_area_flushes.erase(id);return result
        await get_tree().process_frame
    return false

func prepare_travel(grid:Vector2i)->Dictionary:
    while building.busy or population.busy or population.motion_busy or wild.motion_busy or _request_busy or _checkpoint_running or not wild.pending_spawns.is_empty():
        await get_tree().process_frame
        if not session.trusted:return {"error":"ONLINE CONNECTION CLOSED"}
    if wild.authority():await wild.publish_motion()
    if population.authority() or population.authority(population.local_scope()):await population.publish_motion()
    if not await checkpoint_player() or not await publish_current():return {"error":"ONLINE SAVE FAILED"}
    _area_discovery[_area()]=Snapshot.packed_discovery(main.world)
    _travel_target="%d,%d"%[grid.x,grid.y];_travel_offer={};_travel_token=""
    if hosting:service.request(session.actor,_travel_target)
    else:session.send_host({"kind":"area_request","area":_travel_target})
    # The area may be one that another player is generating at this moment:
    # the answer then comes only once their game has made it and sent it in,
    # which takes minutes for a large world. Say so, and wait that long. The
    # wait used to end after two minutes with nothing on screen.
    var asked:=Time.get_ticks_msec()
    var deadline=asked+600000
    var told:=false
    while session.trusted and _travel_offer.is_empty() and Time.get_ticks_msec()<deadline:
        if not told and Time.get_ticks_msec()-asked>=3000:
            told=true
            main.generation_status.text="ANOTHER PLAYER IS\nCREATING THIS AREA.\nPLEASE WAIT..."
            main.generation_panel.show()
        await get_tree().process_frame
    if _travel_offer.is_empty():
        if told:main.generation_panel.hide()
        _travel_target="";return {"error":"ONLINE AREA DID NOT RESPOND"}
    session.set_loading(true)
    await get_tree().process_frame
    return _travel_offer

## What each area's map looked like when this player last left it, for this
## session. A player's record holds one explored map, and it was carried into
## whichever area they went to next: an area someone else had made arrived
## already "explored" in the shape of the area just left.
var _area_discovery:Dictionary={}

## This player's own state on arriving in `area`: as it is now, but with that
## area's explored map, or none if they have not been there this session.
func _arrival_personal(area:String)->Dictionary:
    var personal:Dictionary=Snapshot.capture_personal(main.world)
    if _area_discovery.has(area):personal["discovered_cells"]=_area_discovery[area]
    else:personal["discovered_cells"]={}
    return personal

func finish_travel()->bool:
    if not _travel_token.is_empty():
        main.generation_status.text="Saving new area...";main.generation_panel.show()
        var parts=Snapshot.split(main.world.get_crafting_save_state())
        var bytes=Snapshot.encode(main.world.world_seed,main.world.map_size_index,FileAccess.get_file_as_bytes(Cache.cache_path(main.world.world_seed,main.world.map_size_index)),parts.shared)
        var result:Dictionary
        if hosting:result=await service.generated(session.actor,_travel_target,_travel_token,{"seed":main.world.world_seed,"size":main.world.map_size_index},bytes)
        else:result=await service.upload(_travel_target,_travel_token,0,bytes)
        if not result.get("ok",false):return false
    _entry_reply={}
    if hosting:
        _entry_reply=service.areas.enter(session.actor,_travel_target)
        _broadcast_authority()
    else:session.send_host({"kind":"entered","area":_travel_target})
    var deadline=Time.get_ticks_msec()+15000
    while session.trusted and _entry_reply.is_empty() and Time.get_ticks_msec()<deadline:await get_tree().process_frame
    if not _entry_reply.get("ok",false):return false
    area_authority=String(_entry_reply.authority);area_epoch=int(_entry_reply.epoch)
    visuals.set_area(_travel_target);_travel_target="";_travel_token="";_travel_offer={}
    building.sync_current()
    wild.request_sync()
    population.sync_pending=true
    _refresh_drops()
    rest.apply_on_entry()
    if hosting and not save_checkpoint(main._capture_game_save()):return false
    return await checkpoint_player()

func _generation_requested(actor:String,area:String,token:String)->void:
    if actor==session.actor:
        if area==_travel_target:_travel_token=token;_travel_offer={"new":true}
        return
    for peer in session.players:
        if session.players[peer].actor==actor:session.send_to(peer,{"kind":"area_generate","area":area,"token":token})

func _install_cache(decoded:Dictionary)->bool:
    var path=Cache.cache_path(decoded.seed,decoded["size"])
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))!=OK:return false
    var file=FileAccess.open(path+".pending",FileAccess.WRITE)
    if file==null:return false
    file.store_buffer(decoded.cache);file.flush();var error=file.get_error();file.close()
    return error==OK and DirAccess.rename_absolute(path+".pending",path)==OK

func drop_item(item:String,amount:int,cell:Vector2i,thrown:bool=false)->bool:
    var drops=main.world.dropped_items()
    # A thrown ball may land on a pile of the same ball.
    var same_pile:bool=thrown and drops.records.has(drops.key(cell)) and drops.records[drops.key(cell)].get("item")==item
    if not same_pile and not drops.can_drop(cell):return false
    var request:={"item":item,"amount":amount,"area":scope(),"x":cell.x,"y":cell.y}
    if thrown:request["thrown"]=true
    var result:Dictionary=await command("drop",request)
    if result.get("ok",false):main.world.play_source_sound("seed1");return true
    return false

func pickup_item(record:Dictionary)->void:
    var id=String(record.get("coop_id",""))
    if id.is_empty() or _picking.has(id):return
    _picking[id]=true
    var result:Dictionary=await command("pickup",{"key":id})
    _picking.erase(id)
    if result.get("ok",false):main.world.world_message.emit("Picked up %s x%d!"%[record.item,int(record.amount)])

func _refresh_drops()->void:
    if not main.world.generated:return
    var manager=main.world.dropped_items()
    for key in manager.records.keys():
        if manager.records[key].has("coop_id"):manager.records.erase(key)
    for key in shared_records:
        if not String(key).begins_with("drop/"):continue
        var item:Dictionary=shared_records[key]
        if item.get("area")!=scope():continue
        var cell=Vector2i(int(item.x),int(item.y))
        manager.records[manager.key(cell)]={"scope":manager.scope(),"x":cell.x,"y":cell.y,"item":item.item,"amount":int(item.amount),"coop_id":key}
    manager.rebuild()

func join_code()->String:
    if endpoints.is_empty():return "UNAVAILABLE"
    return String(endpoints[endpoint_index].code)

func cycle_endpoint(direction:int)->void:
    if not endpoints.is_empty():endpoint_index=wrapi(endpoint_index+direction,0,endpoints.size())

func cancel_join()->void:
    if hosting or main.started:return
    main._set_join_layout(false)
    join_setup_code="";main.world_edit.editable=true
    preload("res://scripts/crafting_data.gd").online_enabled=false
    active=false;_loading=false;pending_game={};_guest_game={}
    session.stop();Network.join_close();Cache.online_namespace=""
    if is_instance_valid(service):service.queue_free();service=null

func configure(game:Node)->void:
    preload("res://scripts/crafting_data.gd").online_enabled=false
    main=game;process_mode=Node.PROCESS_MODE_ALWAYS
    if not ended_reason.is_empty():main.menu_status.text=ended_reason;notice=ended_reason;ended_reason=""
    lobby=Lobby.new();add_child(lobby)
    session=Session.new();add_child(session)
    session.admitted.connect(_admitted)
    session.blocked=func(actor,device):return hosting and (state.records.has("blocked/"+String(actor)) or (String(device)!=session.NO_DEVICE and state.records.has("blocked_device/"+String(device))))
    session.rejected.connect(_failure)
    session.session_ready.connect(_ready_session)
    session.message.connect(_message)
    session.connection_lost.connect(_connection_lost)
    session.departed.connect(func(_peer,_actor):_broadcast_authority.call_deferred())
    session.departed.connect(func(peer,_actor):_player_notice(peer,"","left"))
    visuals=Players.new();add_child(visuals);visuals.configure(main,session,state)
    visuals.presence_received.connect(_presence)
    commands=Commands.new();add_child(commands);commands.bind(session,state)
    commands.interactions.battle_item_rules=main.BATTLE_ITEM_RULES
    commands.changed.connect(_committed)
    commands.reply.connect(_interaction_reply)
    interaction_ui=preload("res://scripts/coop_interaction_ui.gd").new()
    main.get_node("UI").add_child(interaction_ui);interaction_ui.configure(main,self)
    pvp=preload("res://scripts/coop_pvp_runtime.gd").new();add_child(pvp);pvp.configure(self)
    interaction_ui.battle_accepted.connect(pvp.receive)
    pings=preload("res://scripts/coop_pings.gd").new()
    main.get_node("UI").add_child(pings);pings.configure(self)
    rest=preload("res://scripts/coop_rest.gd").new();add_child(rest);rest.configure(self)
    storage=preload("res://scripts/coop_storage.gd").new();add_child(storage);storage.configure(self)
    beacons=preload("res://scripts/coop_beacons.gd").new();add_child(beacons);beacons.configure(self)
    building=preload("res://scripts/coop_build_runtime.gd").new();add_child(building);building.configure(self)
    commands.build_action=building.execute
    wild=preload("res://scripts/coop_wild_runtime.gd").new();add_child(wild);wild.configure(self)
    commands.wild_action=wild.execute
    population=preload("res://scripts/coop_population_runtime.gd").new();add_child(population);population.configure(self)
    commands.population_action=population.execute
    hordes=preload("res://scripts/coop_horde_runtime.gd").new()
    main.get_node("UI").add_child(hordes);hordes.configure(self)
    commands.horde_action=hordes.execute
    raids=preload("res://scripts/coop_raid_runtime.gd").new();add_child(raids);raids.configure(self)
    commands.raid_action=raids.execute
    population_battles=preload("res://scripts/coop_population_battles.gd").new();add_child(population_battles);population_battles.configure(self)
    commands.population_battle_action=population_battles.execute
    events=preload("res://scripts/coop_special_events.gd").new();add_child(events);events.configure(self)
    commands.event_action=events.execute

func handle_input(event:InputEvent)->bool:
    if interaction_ui.visible:interaction_ui.handle(event);return true
    if not active or not session.trusted or not main.started or main.generating or main._field_ui_blocks_gameplay():return false
    if not event.is_action_pressed("confirm"):return false
    if main.world.active_area_id=="OVERWORLD" and main.world.built_structures.get(main.world._player_cell(),{}).get("name")=="BEACON":
        beacons.open();return true
    # Players can now stand shoulder to shoulder, so the one being faced is
    # found by where they stand, not by which tile they are counted in.
    var here:Vector2=main.world.player.position
    var facing:=Vector2(main.world._facing_cell())
    for actor in visuals.last_packets:
        if actor==session.actor:continue
        var packet:Dictionary=visuals.last_packets[actor]
        if packet.get("area")!=_area() or packet.get("layer")!=visuals._layer():continue
        var away:Vector2=Vector2(float(packet.get("body_x",int(packet.get("cell_x",-999999))*16+8)),float(packet.get("body_y",int(packet.get("cell_y",-999999))*16+8)))-here
        var ahead:=away.dot(facing)
        if ahead<4.0 or ahead>24.0 or absf(away.dot(Vector2(facing.y,facing.x)))>10.0:continue
        if packet.get("battle",false):main._show_message("That player is in a battle.")
        else:interaction_ui.open_for(actor)
        return true
    return false

func _interaction_reply(actor:String,_request:String,result:Dictionary)->void:
    if not hosting or not result.get("ok",false):return
    var recipients:Array=[]
    if result.get("session") is Dictionary:
        recipients=[result.session.a,result.session.b]
    elif result.get("kind")=="closed":recipients=[result.a,result.b]
    elif result.get("kind")=="trade_complete":
        for change in result.get("changes",[]):
            if String(change.key).begins_with("player/"):recipients.append(String(change.key).trim_prefix("player/"))
    else:return
    for recipient in recipients:
        var visible=Commands.visible_result(result,String(recipient))
        if recipient==session.actor:interaction_ui.update(visible)
        else:
            for peer in session.players:
                if session.players[peer].actor==recipient:session.send_to(peer,{"kind":"interaction_update","result":visible})

func _presence(actor:String,packet:Dictionary)->void:
    commands.presence[actor]={"area":String(packet.area)+"|"+String(packet.layer),
        "x":int(packet.get("cell_x",0)),"y":int(packet.get("cell_y",0)),
        "fx":int(packet.visual.get("fx",0)),"fy":int(packet.visual.get("fy",1)),
        "battle":bool(packet.get("battle",false)),"helper_slot":int(packet.get("helper_slot",-1)),"population_scope":String(packet.get("population_scope","OVERWORLD"))}
    if actor==session.actor:
        for i in range(main.caught_pokemon.size()):
            if main._storage_is_active(main.caught_pokemon[i]):commands.presence[actor]["helper_slot"]=i;break

func scope()->String:return _area()+"|"+visuals._layer()

func _personal_profile()->Dictionary:
    if is_instance_valid(events) and events.active and not events.finishing:return events.original_profile.duplicate(true)
    if is_instance_valid(population_battles) and not population_battles.claim.is_empty() and not population_battles.finishing:return population_battles.original_profile.duplicate(true)
    if is_instance_valid(raids) and raids.active and not raids.finishing:return raids.original_profile.duplicate(true)
    if is_instance_valid(wild) and not wild.encounter.is_empty() and not wild.finishing:return wild.original_profile.duplicate(true)
    var data:Dictionary=main._capture_game_save(2,true)
    var party:Array=main.caught_pokemon
    var inventory:Dictionary=main.inventory
    if is_instance_valid(pvp) and pvp.active:
        party=pvp.original_party;inventory=pvp.original_inventory
        data["caught_pokemon"]=party.duplicate(true);data["inventory"]=inventory.duplicate(true)
    data.erase("adjacent_worlds");data.erase("pokemon_storage")
    data["coop_respawn"]=rest.record.duplicate(true)
    data["coop_pending_pokemon"]=storage.pending.duplicate(true)
    data["crafting_state"]=Snapshot.split(data.crafting_state).personal
    return {"party":party.duplicate(true),"inventory":inventory.duplicate(true),"save":data}

func checkpoint_player()->bool:
    while _profile_write_busy:
        await get_tree().process_frame
        if not session.trusted:return false
    _profile_write_busy=true
    var success:bool=await _checkpoint_player_now()
    _profile_write_busy=false
    return success

func _checkpoint_player_now()->bool:
    if not active or not session.trusted:return false
    var profile=_personal_profile()
    var sent_pending:Array=profile.save.coop_pending_pokemon.duplicate(true)
    if hosting:
        var key="player/"+session.actor
        var changes=_only_what_changed(storage.profile_changes(session.actor,profile),key)
        changes.append(state.change("clock",{"seconds":clock_seconds}))
        var result=state.transact(session.actor,"profile/"+_id(),changes,"",not _walking_only(changes,key))
        if result.get("ok",false):
            # The stored record is the reference from now on, not this copy.
            profile_base=state.print_of(key,{});storage.settle(sent_pending,profile.save.coop_pending_pokemon)
            storage.broadcast_profile_storage(result)
        else:print("ONLINE host player record not saved: ",result.get("reason","unknown")," ",result.get("key",""))
        return bool(result.get("ok",false))
    # Send what changed since the record the host last confirmed. The whole
    # record goes only the first time, or after the host could not use edits.
    var request:={"kind":"profile_checkpoint","id":_id(),"base":profile_base}
    var confirmed:Dictionary=shared_records.get("player/"+session.actor,{})
    if _send_whole_profile or confirmed.is_empty():request["profile"]=profile
    else:
        var edits:=Patch.diff(confirmed,profile)
        if edits.is_empty():return true
        request["edits"]=edits
    var response:Dictionary=await _rpc(request)
    _send_whole_profile=not response.get("ok",false)
    if response.get("ok",false):
        profile_base=String(response.base)
        profile.save.coop_pending_pokemon=response.get("pending",[]).duplicate(true)
        shared_records["player/"+session.actor]=profile.duplicate(true)
        _berry_profile_base=profile_base
        storage.settle(sent_pending,response.get("pending",[]));return true
    return false

var _berry_profile_base:=""
var _send_whole_profile:=false
var _private_box_synced:=false

## On entering a world, offer the private box this device carries. Until that
## has happened the device copy is not touched: this world may hold an old one.
func _travelling_box_enter()->void:
    _private_box_synced=false
    var key:String="private_box/"+session.actor
    var device:Dictionary=PrivateBox.read()
    if not device.exists:
        # First world since the box began travelling: start from what is here.
        var here:Array=(state.records if hosting else shared_records).get(key,[])
        _private_box_synced=PrivateBox.write(here,[])==OK
        return
    var deadline:=Time.get_ticks_msec()+30000
    while active and session.trusted and Time.get_ticks_msec()<deadline:
        var result:Dictionary=await command("private_sync",{"entries":device.entries,"removed":device.removed})
        if result.get("ok",false):
            _private_box_synced=true
            # Record the box as this world now holds it. If the host's update
            # has not reached this device yet, it is mirrored when it arrives.
            PrivateBox.mirror((state.records if hosting else shared_records).get(key,[]))
            return
        if result.get("reason","")!="busy":
            print("ONLINE private box could not be brought into this world: ",result.get("reason","unknown"));return
        await get_tree().process_frame

## What changes just by walking about. A checkpoint that holds nothing else is
## kept in memory and reaches the disk with the next world save; writing the
## clock and a position to the journal every second was a regular small stall
## on the host. Party, bag, storage and everything else are still written at once.
const WALKING:=[["save","player_x"],["save","player_y"],["save","friendship_step_timer"],["save","egg_step_timer"],
    ["save","crafting_state","active_field_pokemon"],["save","crafting_state","discovered_cells"],
    ["save","crafting_state","follower_pokemon"],["save","crafting_state","source_return_x"],["save","crafting_state","source_return_y"]]

func _walking_only(changes:Array,player_key:String)->bool:
    for change in changes:
        var key:=String(change.get("key",""))
        if key=="clock":continue
        if key!=player_key or not change.has("edits"):return false
        for edit in change.edits:
            var path:Array=edit[1]
            # The countdowns of an egg in the party: ["party", slot, "hatch_steps"], and
            # "hatch_cycles", which drops by one every sixteen steps.
            var walking:bool=path.size()==3 and String(path[0])=="party" and String(path[2]) in ["hatch_steps","hatch_cycles"]
            for known in WALKING:
                if path.size()>=known.size() and path.slice(0,known.size())==known:walking=true;break
            if not walking:return false
    return true

## Replaces a whole-record change with edits to the stored record, and drops
## it when nothing in the record changed.
func _only_what_changed(changes:Array,key:String)->Array:
    var result:Array=[]
    for change in changes:
        if String(change.get("key",""))!=key or not change.has("after") or not state.records.has(key):
            result.append(change);continue
        var slim:Dictionary=state.change_edits(key,change.after)
        if not slim.is_empty():result.append(slim)
    return result

## True when the party and bag are as they were at the last saved checkpoint.
## Compared with a stamp of the live data rather than with the stored record:
## a record read back from a save holds the same numbers in another form, and
## never compared equal, which put a full checkpoint on every beat.
func _party_and_bag_saved()->bool:
    return _saved_stamp==_party_and_bag_stamp()

func _party_and_bag_stamp()->Array:
    # An egg being carried counts down its steps on every step taken. That is
    # walking, not a change to the party: left in, it made a full save run on
    # every beat for as long as the player walked with an egg, a stall of
    # about 40 ms three times every two seconds.
    var party:Array=[]
    for entry in main.caught_pokemon:
        if entry is Dictionary and entry.has("hatch_steps"):
            var steady:Dictionary=entry.duplicate()
            steady.erase("hatch_steps");steady.erase("hatch_cycles")
            party.append(steady.hash())
        else:party.append(hash(entry))
    return [party,main.inventory.hash()]

func _berry_profile_is_current()->bool:
    # A berry grants inventory only. Reuse the last durable profile when its
    # party/inventory still match; movement is saved by the regular checkpoint.
    # Any local party or inventory edit still takes the normal checkpoint path.
    var profile:Dictionary=(state.records if hosting else shared_records).get("player/"+session.actor,{})
    return not profile.is_empty() and profile.get("party",[])==main.caught_pokemon and profile.get("inventory",{})==main.inventory and (state.print_of("player/"+session.actor,{})==profile_base if hosting else _berry_profile_base==profile_base)

func command(operation:String,args:Dictionary,berry_pickup:bool=false)->Dictionary:
    if _request_busy or not active or not session.trusted:return {"ok":false,"reason":"busy"}
    _request_busy=true
    while _checkpoint_running:
        await get_tree().process_frame
        if not session.trusted:_request_busy=false;return {"ok":false,"reason":"disconnected"}
    var reuse_berry_profile:=berry_pickup and operation=="field_dig" and _berry_profile_is_current()
    if not reuse_berry_profile and operation not in ["trade_offer","trade_confirm","battle_action","battle_done","cancel","wild_finish","wild_namespace","wild_motion","wild_spawn","population_motion","raid_damage","raid_finish","population_finish","event_motion","event_finish"] and not await checkpoint_player():
        print("ONLINE command not sent: ",operation," (player record could not be saved)")
        _request_busy=false;return {"ok":false,"reason":"save_failed"}
    var cell:Vector2i=main.world._player_cell()
    var packet={"kind":"command","id":_id(),"op":operation,"args":args}
    if operation in ["build","remove_build","paint","field_cut","field_dig"]:args["profile_hash"]=profile_base
    if operation=="deploy":args["base"]=profile_base
    var result:Dictionary
    if hosting:
        commands.presence[session.actor]={"area":scope(),"x":cell.x,"y":cell.y,"battle":main.battle_active,"fx":int(main.world.player.facing.x),"fy":int(main.world.player.facing.y),"population_scope":population.local_scope()}
        for index in range(main.caught_pokemon.size()):
            if main._storage_is_active(main.caught_pokemon[index]):commands.presence[session.actor]["helper_slot"]=index;break
        result=commands.execute(session.actor,packet)
    else:result=await _rpc(packet)
    _request_busy=false
    # Refusals are otherwise silent: the action just visibly undoes itself.
    if not result.get("ok",false):print("ONLINE command refused: ",operation," reason=",result.get("reason","unknown")," key=",result.get("key",""))
    return result

func _id()->String:return preload("res://scripts/coop_random.gd").hex(16)

func _rpc(packet:Dictionary)->Dictionary:
    var id=String(packet.id)
    var deadline=Time.get_ticks_msec()+15000
    var error:Error=session.send_host(packet)
    if error!=OK:return {"ok":false,"reason":"connection_busy"}
    var retry_at=Time.get_ticks_msec()+3000
    while session.trusted and Time.get_ticks_msec()<deadline:
        if _replies.has(id):
            var response:Dictionary=_replies[id];_replies.erase(id);return response
        if Time.get_ticks_msec()>=retry_at and packet.get("kind") in ["command","profile_checkpoint"]:
            # Reuse the transaction ID: a delayed response must never spend,
            # withdraw or grant the same thing twice.
            session.send_host(packet);retry_at=Time.get_ticks_msec()+3000
        await get_tree().process_frame
    return {"ok":false,"reason":"disconnected"}

func _checkpoint_request(peer:int,actor:String,packet:Dictionary)->void:
    if not packet.get("id") is String or packet.id.length()>48:return
    var whole:=packet.get("profile") is Dictionary
    if not whole and not Patch.valid(packet.get("edits")):return
    var key="player/"+actor
    var result:Dictionary
    var previous:Dictionary=state.outcomes.get(actor+"/profile/"+String(packet.id),{})
    if not previous.is_empty():
        var current:Dictionary=state.records.get(key,{})
        result={"ok":true,"base":state.print_of(key,{}),"pending":current.get("save",{}).get("coop_pending_pokemon",[])}
    elif String(packet.get("base",""))!=state.print_of(key,{}):
        result={"ok":false,"reason":"profile_changed"}
    else:
        # Either the whole record, or edits to the one the player last had confirmed.
        var profile=packet.profile if whole else Patch.apply(state.records.get(key,{}),packet.edits)
        if not _profile_shape_ok(profile):
            if whole:return
            result={"ok":false,"reason":"edits_do_not_fit"}
        else:
            var changes:=_only_what_changed(storage.profile_changes(actor,profile),key)
            result=state.transact(actor,"profile/"+String(packet.id),changes,"",not _walking_only(changes,key)) if not changes.is_empty() else {"ok":true}
            if result.get("ok",false):
                if result.has("changes"):storage.broadcast_profile_storage(result)
                var stored:Dictionary=state.records.get(key,{})
                result={"ok":true,"base":state.print_of(key,{}),"pending":stored.get("save",{}).get("coop_pending_pokemon",[])}
    session.send_to(peer,{"kind":"profile_result","id":packet.id,"result":result})

func _profile_shape_ok(profile:Variant)->bool:
    if not profile is Dictionary:return false
    if not profile.get("party") is Array or profile.party.size()>6 or not profile.get("inventory") is Dictionary or profile.inventory.size()>1024:return false
    return profile.get("save") is Dictionary

func _committed(commit:Dictionary)->void:
    for peer in session.players:
        if peer==1:continue
        var actor=String(session.players[peer].actor)
        var visible=Commands.visible_result(commit,actor)
        # A player's own record goes to them as what changed, not whole.
        var own_edits=commit.get("player_edits",{}).get("player/"+actor)
        if own_edits is Array:
            for change in visible.get("changes",[]):
                if String(change.get("key",""))=="player/"+actor and change.has("after"):
                    change.erase("after");change["edits"]=own_edits
        visible.erase("player_edits")
        visible["profile_base"]=state.print_of("player/"+actor,{})
        session.send_to(peer,{"kind":"shared_commit","result":visible})
    var own:Dictionary=Commands.visible_result(commit,session.actor)
    own["profile_base"]=state.print_of("player/"+session.actor,{})
    _apply_visible(own)

func _apply_visible(result:Dictionary)->void:
    if result.get("resync",false) and not hosting:session.send_host({"kind":"state_request"})
    # This player's own record arrives as edits to the copy held here.
    for change in result.get("changes",[]):
        if change is Dictionary and change.has("edits") and not change.has("after"):
            var held=shared_records.get(String(change.get("key","")))
            var edited=Patch.apply(held,change.edits) if held is Dictionary and Patch.valid(change.edits) else null
            if edited==null:
                # The copies have drifted apart: ask the host for everything again.
                if not hosting:session.send_host({"kind":"state_request"})
                return
            change["after"]=edited
    var drops_changed=false
    var storage_changed=false
    for change in result.get("changes",[]):
        var key=String(change.key)
        if key.begins_with("drop/"):drops_changed=true
        if key.begins_with("box/") or key.begins_with("chest/") or key.begins_with("private_box/"):storage_changed=true
        if change.after==null:
            if shared_records.erase(key):shared_epoch+=1
        else:
            if not shared_records.has(key):shared_epoch+=1
            shared_records[key]=change.after
        if key=="private_box/"+session.actor and _private_box_synced:
            PrivateBox.mirror(change.after if change.after is Array else [])
        if key=="player/"+session.actor and change.after is Dictionary:
            # Keep the saved comparison separate from mutable party records.
            shared_records[key]=change.after.duplicate(true)
            if is_instance_valid(pvp) and pvp.active:
                pvp.original_party=change.after.get("party",[]).duplicate(true)
                pvp.original_inventory=change.after.get("inventory",{}).duplicate(true)
            else:
                main.caught_pokemon.assign(change.after.get("party",[]))
                main.inventory=change.after.get("inventory",{}).duplicate(true)
            profile_base=String(result.get("profile_base",State.fingerprint(change.after)))
            _berry_profile_base=profile_base
    if drops_changed:_refresh_drops()
    if storage_changed:storage.refresh()
    building.committed(result.get("changes",[]))
    wild.committed(result.get("changes",[]),String(result.get("actor","")),String(result.get("id","")))
    population.committed(result.get("changes",[]),String(result.get("actor","")),String(result.get("id","")))
    events.committed(result.get("changes",[]),String(result.get("actor","")),String(result.get("id","")))

## True once the host has answered a join. A connection that dies before then
## never carried anything from this player to the host, which is what an
## isolated guest Wi-Fi network does: say so instead of blaming the host.
var _host_answered:=false
const UNREACHABLE:="COULD NOT REACH THE HOST.\nTRY AGAIN, OR CHECK THE WI-FI."

## The records whose key starts with `prefix`, without walking all of them
## each time. A long-played world holds thousands of records; several systems
## used to scan every one two to four times a second, which showed as a small
## regular hitch on the host. The list is rebuilt only when a record has been
## added or removed since it was made.
var shared_epoch:=0
var _key_lists:Dictionary={}
var _key_lists_epoch:=-1
var _key_lists_hosting:=false
var _key_lists_state:=0

func record_keys(prefix:String)->Array:
    var epoch:int=state.key_epoch if hosting else shared_epoch
    if epoch!=_key_lists_epoch or hosting!=_key_lists_hosting or state.get_instance_id()!=_key_lists_state:
        _key_lists.clear();_key_lists_epoch=epoch;_key_lists_hosting=hosting;_key_lists_state=state.get_instance_id()
    if not _key_lists.has(prefix):
        var found:Array=[]
        for key in (state.records if hosting else shared_records):
            if String(key).begins_with(prefix):found.append(key)
        _key_lists[prefix]=found
    return _key_lists[prefix]

func _connection_lost()->void:
    if not active or hosting:return
    # A host that only went quiet is not one that left: the two read differently.
    if not _host_answered:end_session(UNREACHABLE)
    elif String(session.transport.last_disconnect_reason)=="receive_timeout":end_session("THE HOST STOPPED RESPONDING.\nTRY AGAIN.")
    else:end_session("HOST DISCONNECTED.\nSESSION ENDED.")

func end_session(reason:String)->void:
    print("ONLINE session ended: ",reason," (transport: ",session.transport.last_disconnect_reason,")")
    preload("res://scripts/crafting_data.gd").online_enabled=false
    main.world.set_gameplay_enabled(false)
    active=false;ended_reason=reason
    lobby.stop_advertise();Network.host_close();Network.join_close()
    session.stop();Cache.online_namespace=""
    get_tree().call_deferred("reload_current_scene")

func world_time(delta:float)->float:
    if hosting:return clock_seconds
    if _clock_received==0:return main.world.world_elapsed_seconds+delta
    return clock_seconds+minf(2.0,float(Time.get_ticks_msec()-_clock_received)/1000.0)*clock_speed

var _area_cleanup:Thread

## Removes the area files this world no longer uses; see the snapshot store.
func _clean_up_area_files()->void:
    if _area_cleanup!=null:return
    var in_use:Array=[]
    for key in state.records:
        if not String(key).begins_with("area/"):continue
        var metadata=state.records[key]
        if metadata is Dictionary and metadata.get("sha256") is String:in_use.append(metadata.sha256)
    if in_use.is_empty():return
    var home:=ProjectSettings.globalize_path(Paths.path("online_worlds").path_join(world_id))
    _area_cleanup=Thread.new()
    if _area_cleanup.start(preload("res://scripts/coop_snapshot_store.gd").clean_up.bind(home.path_join("snapshots"),home,in_use))!=OK:_area_cleanup=null

func _process(delta:float)->void:
    if _area_cleanup!=null and not _area_cleanup.is_alive():
        var removed:int=_area_cleanup.wait_to_finish();_area_cleanup=null
        if removed>0:print("ONLINE removed ",removed," area files no longer in use")
    if not active or not session.trusted or not main.started:return
    session.set_loading(main.generating or main.edge_travel_busy)
    var now=Time.get_ticks_msec()
    if hosting:
        clock_seconds+=delta
        if now-_clock_sent>=250:
            _clock_sent=now
            for peer in session.players:
                if peer!=1:session.send_to(peer,{"kind":"world_clock","seconds":clock_seconds,"speed":Engine.time_scale})
    if hosting and now-_journal_checked>=20000 and not _checkpoint_running and not _request_busy and not _publishing and not interaction_ui.visible and not main.generating and not main.edge_travel_busy and not main.battle_active:
        _journal_checked=now
        if _world_saved_at==0:_world_saved_at=now
        var fold:bool=State.journal_enabled and (store.journal_size()>JOURNAL_COMPACT_BYTES or (state.loose>0 and now-_world_saved_at>=MOTION_SAVE_MS))
        var captured:Dictionary=main._capture_game_save() if fold else {}
        if fold and not save_checkpoint(captured):
            print("ONLINE journal could not be folded into a world save")
    if now-_last_checkpoint>=750 and not _checkpoint_running and not _request_busy and not interaction_ui.visible and not main.generating and not main.edge_travel_busy:
        _last_checkpoint=now
        # The full record is large, and position updates share its connection.
        # A changed party or bag is still saved on this 0.75 s beat; when only
        # the player's position moved, every few seconds is enough.
        # Resting in a bed heals the party a little on every beat. Saving each
        # step of that was a small stall every 0.75 s all night; every few
        # seconds is plenty, and the rest is saved in full on waking.
        var resting:bool=bool(main.world.get("bed_rest_active")) and now-_last_full_checkpoint<REST_CHECKPOINT_MS
        if now-_last_full_checkpoint<POSITION_CHECKPOINT_MS and (resting or _party_and_bag_saved()):return
        _last_full_checkpoint=now;_checkpoint_running=true
        var stamp:=_party_and_bag_stamp()
        var saved:bool=await checkpoint_player()
        if saved:_saved_stamp=stamp
        _checkpoint_running=false

func _identity()->bool:
    var token=Identity.token()
    var mods=Identity.mods()
    if token.is_empty() or mods.has("error"):
        _failure(String(mods.get("error","PLAYER ID COULD NOT LOAD")));return false
    return session.configure(token,String(mods.digest),{"name":main.player_model_name.text,
        "model":main.player_model_index,"color":main.player_color_index})

func _restore_latest_host_area()->bool:
    var area="%d,%d"%[int(pending_game.get("world_grid_x",0)),int(pending_game.get("world_grid_y",0))]
    var metadata:Dictionary=state.records.get("area/"+area,{})
    if metadata.is_empty():return false
    var reader=preload("res://scripts/coop_snapshot_store.gd").new();add_child(reader)
    if reader.configure(Paths.path("online_worlds").path_join(world_id).path_join("snapshots"))!=OK:
        reader.queue_free();return false
    var loaded:Dictionary=await reader.load_bytes(String(metadata.get("sha256","")))
    reader.queue_free()
    if not loaded.get("ok",false):return false
    var decoded=Snapshot.decode(loaded.bytes)
    if decoded.is_empty() or decoded.seed!=metadata.get("seed") or decoded["size"]!=metadata.get("size"):return false
    var previous_namespace=Cache.online_namespace
    Cache.online_namespace=world_id
    var installed=_install_cache(decoded)
    Cache.online_namespace=previous_namespace
    if not installed:return false
    var personal:Dictionary=Snapshot.split(pending_game.get("crafting_state",{})).personal
    pending_game["crafting_state"]=Snapshot.merge(wild.overlay(area,population.overlay(area,building.overlay(area,decoded.shared,state.records),state.records),state.records),personal)
    pending_game["world_seed"]=decoded.seed;pending_game["world_size"]=decoded["size"]
    return true

func _mode_label(text:String)->void:
    main.menu_status.text=text

func _lobby_record()->Dictionary:
    if not active or not hosting:return {}
    return {"name":lobby_name,"host":String(session.profile.get("name","PLAYER")),"private":lobby_private,
        "players":session.players.size(),"max":4,"salt":lobby_salt,"protocol":Session.PROTOCOL,"mods":session.mod_digest}

func choose(action:String,value:String)->void:
    # Starting or joining a world takes time; a second press must not start
    # another one on top of it.
    if action in ["NEW","LOAD","JOIN"]:
        if _choosing:return
        _choosing=true
        if action=="LOAD":
            main.coop_menu.show_loading()
            await get_tree().process_frame
            await get_tree().process_frame
        await _choose(action,value)
        _choosing=false
        main.coop_menu.loading_finished(main.menu_status.text)
        return
    if _choosing:return
    await _choose(action,value)

func _choose(action:String,value:String)->void:
    if action=="SOLO":
        cancel_join()
        new_setup_pending=false;join_setup_code="";join_lobby={};main.world_edit.editable=true
        main.coop_menu.close();_mode_label("SINGLE PLAYER")
        main.menu_row=main.MENU_ROW_MODE;main.menu_col=0 if main.selected_mode=="NEW" else 1
        main.menu_status.text="SINGLE PLAYER"
        main._update_classic_menu_labels();main._update_menu_cursor()
        return
    if action=="JOIN_SETUP":
        _mode_label("JOIN GAME")
        join_setup_code=value
        new_setup_pending=false
        main.world_edit.editable=false
        main.coop_menu.close()
        main.menu_row=main.MENU_ROW_COLOR;main.menu_col=0
        main._set_join_layout(true)
        main.menu_status.text="CHOOSE YOUR PLAYER, THEN GO"
        main._update_classic_menu_labels();main._update_menu_cursor()
        return
    if action=="SETUP":
        _mode_label("MULTIPLAYER")
        join_setup_code=""
        main.world_edit.editable=true
        new_setup_pending=true
        main.coop_menu.close()
        main.selected_mode="NEW"
        main.menu_row=main.MENU_ROW_WORLD_NAME;main.menu_col=0
        main._update_classic_menu_labels();main._update_menu_cursor()
        return
    if action=="LIST":
        var token=Identity.token()
        if token.is_empty():_failure("PLAYER ID COULD NOT LOAD");return
        main.coop_menu.show_saves(saves.entries(token.sha256_text()));return
    if not _identity():return
    if action=="JOIN":
        main.coop_menu.show_connecting("CONNECTING...")
        preload("res://scripts/crafting_data.gd").online_enabled=true
        active=true;hosting=false;_loading=true
        Network.start()
        var deadline=Time.get_ticks_msec()+120000
        while active and Network.status().state!="ready":
            var current:Dictionary=Network.status()
            if current.state=="error" or Time.get_ticks_msec()>deadline:
                _failure("MULTIPLAYER NETWORK UNAVAILABLE" if String(current.message).is_empty() else String(current.message));return
            main.coop_menu.connecting_text(Network.status_text())
            await get_tree().process_frame
        if not active:return
        main.coop_menu.connecting_text("CONNECTING TO\n%s..."%String(join_lobby.get("name","HOST")).to_upper())
        var endpoint:Dictionary=Network.join_endpoint(value)
        if endpoint.is_empty():_failure("COULD NOT OPEN A CONNECTION");return
        session.access_proof=Lobby.proof(String(join_lobby.get("salt","")),join_password) if bool(join_lobby.get("private",false)) else ""
        _host_answered=false
        var error:Error=session.join_address(String(endpoint.address),int(endpoint.port))
        if error!=OK:_failure(error_string(error))
        return
    if action not in ["NEW","LOAD"]:return
    new_setup_pending=false
    join_setup_code="";main.world_edit.editable=true
    world_id=preload("res://scripts/coop_random.gd").hex(16) if action=="NEW" else value
    if not Store.valid_id(world_id):_failure("INVALID ONLINE WORLD");return
    pending_game={} if action=="NEW" else saves.load_host(world_id,session.actor)
    if action=="LOAD" and pending_game.is_empty():_failure("ONLINE SAVE COULD NOT LOAD");return
    if store.open(world_id)!=OK:_failure("ONLINE SAVE COULD NOT OPEN");return
    if action=="LOAD":store.backup()
    state=State.new();commands.state=state;commands.items.state=state;commands.interactions.state=state;visuals.state=state
    if action=="LOAD" and store.load_state(state).is_empty():_failure("ONLINE WORLD STATE COULD NOT LOAD");return
    if action=="LOAD":_clean_up_area_files()
    if action=="LOAD":
        var latest:Dictionary=state.records.get("player/"+session.actor,{})
        var personal:Dictionary=latest.get("save",{})
        if not personal.is_empty():
            var old_shared:Dictionary=Snapshot.split(pending_game.get("crafting_state",{})).shared
            var storage:Dictionary=pending_game.get("pokemon_storage",{})
            pending_game.merge(personal,true)
            pending_game["caught_pokemon"]=latest.get("party",pending_game.get("caught_pokemon",[])).duplicate(true)
            pending_game["inventory"]=latest.get("inventory",pending_game.get("inventory",{})).duplicate(true)
            pending_game["pokemon_storage"]=storage
            pending_game["crafting_state"]=Snapshot.merge(old_shared,personal.get("crafting_state",{}))
        if not await _restore_latest_host_area():_failure("ONLINE AREA COULD NOT LOAD");return
        if state.records.has("clock"):
            pending_game.crafting_state["world_elapsed_seconds"]=float(state.records.clock.seconds)
    state.commit_writer=store.append
    state.enroll(session.actor,session.profile)
    if not wild.recover() or not population_battles.recover() or not events.recover():_failure("ONLINE ENCOUNTERS COULD NOT BE RECOVERED");return
    active=true;hosting=true;Cache.online_namespace=world_id
    preload("res://scripts/crafting_data.gd").online_enabled=true
    main.coop_menu.close();main.selected_mode=action;main.setup_load_committed=true
    await main._start_game()

func _create_service()->bool:
    if is_instance_valid(service):service.queue_free()
    service=Areas.new();add_child(service)
    service.refresh_area=_flush_area
    service.register_objects=storage.register_objects
    service.area_ready.connect(_area_ready)
    service.generation_requested.connect(_generation_requested)
    service.failed.connect(func(failed_actor,reason):
        if failed_actor==session.actor:
            if not _travel_target.is_empty():_travel_offer={"error":String(reason)}
            else:_failure(reason))
    return service.configure(state,session,Paths.path("online_worlds").path_join(world_id).path_join("snapshots"))==OK

func game_started()->bool:
    if not active:return true
    wild.request_sync()
    population.sync_pending=true
    rest.record=pending_game.get("coop_respawn",{}).duplicate(true)
    storage.pending=pending_game.get("coop_pending_pokemon",[]).duplicate(true)
    rest.apply_on_entry()
    if not hosting:
        visuals.set_area(_area());session.send_host({"kind":"entered","area":_area()});_loading=false;_refresh_drops();building.sync_current()
        var joined:bool=await wild.initialize_ids()
        if joined:
            session.transport.settled=true
            _travelling_box_enter.call_deferred()
        return joined
    shared_records={}
    for key in state.records:
        if _shared_key(String(key),session.actor):shared_records[key]=state.records[key].duplicate(true) if state.records[key] is Dictionary or state.records[key] is Array else state.records[key]
    storage.refresh();_refresh_drops()
    clock_seconds=float(state.records.get("clock",{}).get("seconds",main.world.world_elapsed_seconds))
    if not _create_service():_failure("ONLINE CACHE COULD NOT OPEN");return false
    if not await publish_current():return false
    var checkpoint:Dictionary=main._capture_game_save()
    if not save_checkpoint(checkpoint):_failure("ONLINE SAVE FAILED");return false
    var error:Error=session.host(world_id)
    if error!=OK:_failure("HOST COULD NOT START: "+error_string(error));return false
    # The world name is the lobby name other players see in JOIN GAME.
    lobby_name=String(checkpoint.get("world_name","WORLD")).strip_edges().left(24)
    lobby_salt=_id()
    session.access_proof=Lobby.proof(lobby_salt,lobby_password) if lobby_private else ""
    Network.start();Network.host_open();lobby.advertise(_lobby_record)
    endpoints=preload("res://scripts/coop_join_code.gd").local_endpoints()
    var entry=service.areas.enter(session.actor,_area());area_authority=String(entry.get("authority",""));area_epoch=int(entry.get("epoch",0));visuals.set_area(_area())
    if not await wild.initialize_ids():return false
    await checkpoint_player()
    _travelling_box_enter.call_deferred()
    return true

func _area()->String:
    return "%d,%d"%[main.current_world_grid.x,main.current_world_grid.y]

func publish_current()->bool:
    if not area_authority.is_empty() and area_authority!=session.actor:return true
    # Do not put an optimistic, not-yet-paid placement into an area snapshot.
    # This waits only for this player's action, never for other players to stop.
    while building.busy or population.busy:
        await get_tree().process_frame
        if not session.trusted:return false
    if _publishing:return false
    _publishing=true
    var seed_value=int(main.world.world_seed)
    var size_index=int(main.world.map_size_index)
    var cache=FileAccess.get_file_as_bytes(Cache.cache_path(seed_value,size_index))
    var parts=Snapshot.split(main.world.get_crafting_save_state())
    var registry:Dictionary=state.records if hosting else shared_records
    if not area_authority.is_empty() or (hosting and state.records.has("area/"+_area())):
        parts.shared=Snapshot.committed_population(_area(),parts.shared,registry)
    parts.shared["_coop_build_base"]=building.known(_area(),state.records if hosting else shared_records)
    var bytes=Snapshot.encode(seed_value,size_index,cache,parts.shared)
    if bytes.is_empty():_publishing=false;_failure("ONLINE AREA CACHE IS MISSING");return false
    if not hosting:
        var uploaded:Dictionary=await service.upload(_area(),"",area_epoch,bytes)
        _publishing=false
        return bool(uploaded.get("ok",false))
    var saved:Dictionary=await service.snapshots.save_bytes(bytes)
    if not saved.get("ok",false):_publishing=false;_failure("ONLINE AREA SAVE FAILED");return false
    var metadata={"seed":seed_value,"size":size_index,"snapshot":saved.snapshot,"sha256":saved.sha256}
    var result=state.transact(session.actor,"snapshot/"+preload("res://scripts/coop_random.gd").hex(16),[state.change("area/"+_area(),metadata)])
    _publishing=false
    var registered:bool=bool(result.get("ok",false)) and storage.register_objects(_area(),parts.shared)
    return registered

func save_checkpoint(data:Dictionary)->bool:
    if not active or not hosting:return false
    if store.save(state,{"world_name":String(data.get("world_name","WORLD")),"owner":session.actor})!=OK:return false
    state.loose=0;_world_saved_at=Time.get_ticks_msec()
    var saved:bool=saves.save_host(world_id,session.actor,data)==OK
    return saved

func save_game(data:Dictionary)->bool:
    while building.busy or _request_busy or _checkpoint_running:
        await get_tree().process_frame
        if not session.trusted:return false
    if not await checkpoint_player():return false
    if not hosting:return true # Host's journal has durably acknowledged this player.
    if not await publish_current():return false
    return save_checkpoint(data)

func _ready_session(id:String,_actor:String)->void:
    if hosting:return
    _host_answered=true
    if not Store.valid_id(id):_failure("INVALID HOST WORLD");return
    world_id=id;Cache.online_namespace=id
    if not _create_service():_failure("ONLINE CACHE COULD NOT OPEN")

## Players the host can remove, for OPTIONS > KICK and KICK AND BAN.
## Listed in the order they joined, each marked 1ST, 2ND, 3RD among the
## players here now: two players can share a name and a look.
var _join_sequence:=0
var _joined_at:Dictionary={}

func kick_candidates()->Array:
    var result:Array=[]
    if not hosting:return result
    for peer in _joined_at.keys():
        if not session.players.has(peer):_joined_at.erase(peer)
    for peer in session.players:
        if peer!=1:
            var profile:Dictionary=session.players[peer].profile
            result.append({"peer":peer,"name":String(profile.get("name","PLAYER")).to_upper(),"model":int(profile.get("model",0)),"color":int(profile.get("color",0)),"at":int(_joined_at.get(peer,peer))})
    result.sort_custom(func(a,b):return int(a.at)<int(b.at))
    for index in range(result.size()):result[index]["order"]=["1ST","2ND","3RD"][index] if index<3 else "%dTH"%(index+1)
    return result

## Removes a player from the game. A plain kick lets them join again. A ban is
## saved with the world and follows their identity, so a new look or name does
## not undo it.
func kick(peer:int,ban:bool=false)->bool:
    if not hosting or peer==1 or not session.players.has(peer):return false
    if ban:
        var actor:=String(session.players[peer].actor)
        var device:=String(session.players[peer].get("device",session.NO_DEVICE))
        var banned:={"name":String(session.players[peer].profile.get("name","PLAYER"))}
        var changes:Array=[state.change("blocked/"+actor,banned)]
        # Also the device, so reinstalling the game does not lift the ban.
        if device!=session.NO_DEVICE and not state.records.has("blocked_device/"+device):changes.append(state.change("blocked_device/"+device,banned))
        var result:Dictionary=state.transact(session.actor,"block/"+_id(),changes)
        if not result.get("ok",false):return false
    session.kick(peer,session.BANNED if ban else session.KICKED)
    return true

## "ASH joined the game." / "ASH left the game." for everyone already playing.
## Without it a player can arrive in a public game and nobody would know.
var _notice_names:Dictionary={}
var _notice_label:Label
var _notice_box:PanelContainer
const NOTICE_FONT_SIZE:=12
## The font sits high in its line, so less padding below keeps the text centred.
const NOTICE_PAD_TOP:=8
const NOTICE_PAD_BOTTOM:=5
var _notice_fade:Tween

## "loading" when a player connects, "joined" once their world has loaded and
## they are standing in it, "left" when they go.
const NOTICE_TEXT:={"loading":"%s is loading in...","joined":"%s joined the game.","left":"%s left the game."}
var _notice_loading:Dictionary={}

func _player_notice(peer:int,player:String,event:String)->void:
    if not hosting:return
    if event=="loading":_notice_names[peer]=player;_notice_loading[peer]=true
    elif event=="joined":
        if not _notice_loading.has(peer):return
        _notice_loading.erase(peer);player=String(_notice_names.get(peer,""))
    else:
        player=String(_notice_names.get(peer,""));_notice_names.erase(peer);_notice_loading.erase(peer)
    if player.is_empty():return
    for other in session.players:
        if other!=1 and other!=peer:session.send_to(other,{"kind":"player_notice","name":player,"event":event})
    show_notice(player,event)

func show_notice(player:String,event:String)->void:
    if not NOTICE_TEXT.has(event):return
    if not is_instance_valid(_notice_label):
        # Built like the game's own text boxes and placed in its UI layer, so
        # it wears the player's chosen frame and follows dark mode.
        var row:=CenterContainer.new();row.name="OnlineNotice";main.get_node("UI").add_child(row)
        row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
        row.offset_top=4;row.mouse_filter=Control.MOUSE_FILTER_IGNORE
        _notice_box=PanelContainer.new();row.add_child(_notice_box)
        _notice_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
        var frame:StyleBoxTexture=main._classic_dialogue_style()
        frame.content_margin_left=10;frame.content_margin_right=10;frame.content_margin_top=NOTICE_PAD_TOP;frame.content_margin_bottom=NOTICE_PAD_BOTTOM
        _notice_box.add_theme_stylebox_override("panel",frame)
        _notice_label=main._source_ui_label(_notice_box,"Text",Vector2.ZERO,Vector2.ZERO,NOTICE_FONT_SIZE)
    _notice_label.text=String(NOTICE_TEXT[event])%player.strip_edges().left(24).to_upper()
    _notice_box.modulate.a=1.0;_notice_box.visible=true
    if _notice_fade!=null and _notice_fade.is_valid():_notice_fade.kill()
    _notice_fade=create_tween();_notice_fade.set_speed_scale(1.0/maxf(Engine.time_scale,0.01))
    _notice_fade.tween_interval(4.0)
    _notice_fade.tween_property(_notice_box,"modulate:a",0.0,1.0)

func _admitted(peer:int,actor:String,profile:Dictionary)->void:
    state.enroll(actor,profile)
    _join_sequence+=1;_joined_at[peer]=_join_sequence
    _player_notice(peer,String(profile.get("name","PLAYER")),"loading")
    while _publishing:
        await get_tree().process_frame
        if not session.players.has(peer):return
    if not await publish_current():session.transport._drop(peer);return
    var data:Dictionary=main._capture_game_save()
    # A new guest starts with their own party and inventory, never the host's.
    var personal:Dictionary=state.records.get("player/"+actor,{})
    var saved_personal:Dictionary=personal.get("save",{})
    var destination=_area()
    if not saved_personal.is_empty():
        var saved_area="%d,%d"%[int(saved_personal.get("world_grid_x",0)),int(saved_personal.get("world_grid_y",0))]
        if state.records.has("area/"+saved_area):
            data=saved_personal.duplicate(true);destination=saved_area
    data["caught_pokemon"]=personal.get("party",[main._make_starter_machop()])
    data["inventory"]=personal.get("inventory",main.STARTING_INVENTORY.duplicate(true))
    data["pokemon_storage"]={}
    data["preferred_storage_box"]=String(saved_personal.get("preferred_storage_box",""))
    data["coop_respawn"]=saved_personal.get("coop_respawn",{}).duplicate(true)
    if saved_personal.is_empty():
        data["pokedex"]={};data["pokedex_shiny"]={};data["waypoints"]={}
    data["adjacent_worlds"]={};data["crafting_state"]={}
    data["player_name"]=profile.get("name","PLAYER");data["player_name_custom"]=true
    data["player_model"]=profile.get("model",0);data["player_color"]=profile.get("color",0)
    # Spawn beside the host in the same scene; shared crafting arrives separately.
    data["coop_personal"]=saved_personal.get("crafting_state",Snapshot.split(main.world.get_crafting_save_state()).personal).duplicate(true)
    data.coop_personal.erase("follower_pokemon");data.coop_personal.erase("active_field_move");data.coop_personal.erase("active_field_pokemon")
    if personal.is_empty():
        personal={"party":data.caught_pokemon,"inventory":data.inventory,"save":{}}
        var enrolled=state.transact(actor,"enroll/"+_id(),[state.change("player/"+actor,personal)])
        if not enrolled.get("ok",false):session.transport._drop(peer);return
    await _send_state(peer,actor)
    var error:Error=session.send_to(peer,{"kind":"game_begin","area":destination,"game":data,"profile_base":state.print_of("player/"+actor,{})})
    if error!=OK:session.transport._drop(peer)

func _message(_peer:int,actor:String,packet:Dictionary)->void:
    if hosting:
        if packet.get("kind")=="area_flush_result" and packet.get("id") is String and packet.get("ok") is bool:
            _area_flushes[packet.id]=packet.ok;return
        if packet.get("kind")=="storage_open" and packet.get("id") is String:
            var area=String(state.members.get(actor,{}).get("area",""))
            var success=not area.is_empty() and await _flush_area(area)
            if success:await _send_state(_peer,actor)
            session.send_to(_peer,{"kind":"command_result","id":packet.id,"result":{"ok":success}});return
        if packet.get("kind")=="profile_checkpoint":_checkpoint_request(_peer,actor,packet);return
        if packet.get("kind")=="state_request":_send_state(_peer,actor);return
        if packet.get("kind")=="entered" and packet.get("area") is String:
            _player_notice(_peer,"","joined")
            var entry=service.areas.enter(actor,packet.area)
            if entry.get("ok",false):await _send_state(_peer,actor)
            session.send_to(_peer,{"kind":"entered_reply","entry":entry})
            _broadcast_authority()
        return
    if packet.get("kind")=="area_authorities" and packet.get("owners") is Dictionary and packet.get("epochs") is Dictionary:
        area_authority=String(packet.owners.get(_area(),""));area_epoch=int(packet.epochs.get(_area(),0));return
    if packet.get("kind")=="area_flush" and packet.get("id") is String:
        while _publishing:await get_tree().process_frame
        var saved=packet.get("area")==_area() and await publish_current()
        session.send_host({"kind":"area_flush_result","id":packet.id,"ok":saved});return
    if packet.get("kind")=="entered_reply" and packet.get("entry") is Dictionary:
        _entry_reply=packet.entry
        if _entry_reply.get("ok",false):area_authority=String(_entry_reply.authority);area_epoch=int(_entry_reply.epoch)
        return
    if packet.get("kind")=="area_generate" and packet.get("area")==_travel_target and packet.get("token") is String:
        _travel_token=packet.token;_travel_offer={"new":true};return
    if packet.get("kind") in ["command_result","profile_result"] and packet.get("id") is String and packet.get("result") is Dictionary:
        _replies[packet.id]=packet.result
        return
    if packet.get("kind")=="player_notice":
        if packet.get("name") is String and packet.get("event") is String and main.started:show_notice(packet.name,packet.event)
        return
    if packet.get("kind")=="world_clock":
        var seconds=packet.get("seconds");var speed=packet.get("speed")
        if (seconds is float or seconds is int) and (speed is float or speed is int) and is_finite(float(seconds)) and float(seconds)>=0 and float(speed)>0 and float(speed)<=4:
            clock_seconds=float(seconds);clock_speed=float(speed);_clock_received=Time.get_ticks_msec()
        return
    if packet.get("kind")=="shared_commit" and packet.get("result") is Dictionary:
        _apply_visible(packet.result);return
    if packet.get("kind")=="interaction_update" and packet.get("result") is Dictionary:
        interaction_ui.update(packet.result);return
    if packet.get("kind")=="state_snapshot" and packet.get("records") is Dictionary:
        events.results_dirty=true
        for key in shared_records.keys():
            if _shared_key(String(key),session.actor):shared_records.erase(key)
        for key in packet.records:
            if _shared_key(String(key),session.actor):shared_records[key]=packet.records[key]
        shared_epoch+=1
        _refresh_drops();storage.refresh();return
    if packet.get("kind")!="game_begin" or not packet.get("game") is Dictionary or not packet.get("area") is String:return
    if main.started or not _loading:return
    _guest_game=packet.game
    profile_base=String(packet.get("profile_base",""))
    session.send_host({"kind":"area_request","area":packet.area})

func _broadcast_authority()->void:
    if not hosting or not is_instance_valid(service):return
    area_authority=String(state.authority.get(_area(),""));area_epoch=int(service.areas.epochs.get(_area(),0))
    for peer in session.players:
        if peer!=1:session.send_to(peer,{"kind":"area_authorities","owners":state.authority,"epochs":service.areas.epochs})

func _shared_key(key:String,actor:String)->bool:
    return events.shared_key(key) or key=="settings" or key.begins_with("boss/") or key.begins_with("raid/") or key.begins_with("horde/") or key.begins_with("horde_reward/"+actor+"/") or wild.shared_key(key) or population.shared_key(key) or building.is_build_key(key) or key.begins_with("beacon/") or key.begins_with("drop/") or key.begins_with("box/") or key.begins_with("chest/") or key=="private_box/"+actor

func _send_state(peer:int,actor:String)->void:
    var deadline=Time.get_ticks_msec()+10000
    while session.players.has(peer) and Time.get_ticks_msec()<deadline:
        # Rebuild after backpressure: no await between capture and enqueue, so later
        # commits always follow this complete snapshot in the ordered connection.
        var records:Dictionary={}
        for key in state.records:
            if _shared_key(String(key),actor):records[key]=state.records[key]
        var error:Error=session.send_to(peer,{"kind":"state_snapshot","records":records})
        if error==OK:return
        if error!=ERR_BUSY:session.transport._drop(peer);return
        await get_tree().process_frame
    if session.players.has(peer):session.transport._drop(peer)

func _area_ready(actor:String,_area_name:String,_metadata:Dictionary,bytes:PackedByteArray)->void:
    if actor==session.actor and not _travel_target.is_empty() and _area_name==_travel_target:
        var arrived=Snapshot.decode(bytes)
        if arrived.is_empty() or not _install_cache(arrived):_travel_offer={"error":"ONLINE AREA COULD NOT LOAD"};return
        _travel_offer={"seed":arrived.seed,"size":arrived["size"],"state":Snapshot.merge(wild.overlay(_area_name,population.overlay(_area_name,building.overlay(_area_name,arrived.shared,state.records if hosting else shared_records),state.records if hosting else shared_records),state.records if hosting else shared_records),_arrival_personal(_area_name))}
        return
    if hosting or actor!=session.actor or _guest_game.is_empty():return
    var decoded=Snapshot.decode(bytes)
    if decoded.is_empty():_failure("ONLINE AREA COULD NOT LOAD");return
    var path=Cache.cache_path(decoded.seed,decoded["size"])
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))!=OK:_failure("ONLINE CACHE COULD NOT SAVE");return
    var file=FileAccess.open(path+".pending",FileAccess.WRITE)
    if file==null:_failure("ONLINE CACHE COULD NOT SAVE");return
    file.store_buffer(decoded.cache);file.flush();var error=file.get_error();file.close()
    if error!=OK or DirAccess.rename_absolute(path+".pending",path)!=OK:_failure("ONLINE CACHE COULD NOT SAVE");return
    pending_game=_guest_game;_guest_game={}
    pending_game["crafting_state"]=Snapshot.merge(wild.overlay(_area_name,population.overlay(_area_name,building.overlay(_area_name,decoded.shared,shared_records),shared_records),shared_records),pending_game.get("coop_personal",{}))
    pending_game.erase("coop_personal")
    main.coop_menu.close();main.selected_mode="LOAD";main.setup_load_committed=true
    session.set_loading(true)
    await get_tree().process_frame
    await main._start_game()

func _failure(reason:String)->void:
    main.menu_status.text=reason.to_upper()
    # Refused after being let in, whether still loading or already playing:
    # the host removed this player. Leave the world and say why.
    if active and not hosting and session.trusted:end_session(reason.to_upper());return
    if is_instance_valid(main.coop_menu) and main.coop_menu.visible:
        if main.coop_menu.page=="connecting":main.coop_menu.connecting_failed(reason.to_upper())
        else:main.coop_menu.status.text=reason.to_upper()
    if not main.started:
        preload("res://scripts/crafting_data.gd").online_enabled=false
        session.transport.stop();active=false;hosting=false;_loading=false;Cache.online_namespace=""
        lobby.stop_advertise();Network.host_close();Network.join_close()

func _exit_tree()->void:
    if _area_cleanup!=null:_area_cleanup.wait_to_finish();_area_cleanup=null
    Network.host_close();Network.join_close()
