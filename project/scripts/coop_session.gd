extends Node
## Connection admission and routing; world operations are handled by the adapter.
signal admitted(peer: int, actor: String, profile: Dictionary)
signal departed(peer: int, actor: String)
signal session_ready(world_id: String, actor: String)
signal message(peer: int, actor: String, payload: Dictionary)
signal rejected(reason: String)
signal connection_lost
const Transport = preload("res://scripts/coop_transport.gd")
const PROTOCOL := "pokewilds-godot-coop-5"
var transport: Node
var hosting := false
var world_id := ""
var identity := ""
var actor := ""
var mod_digest := ""
var profile: Dictionary = {}
var players: Dictionary = {}
var trusted := false
var loading := false
## Host: proof guests must present for a PRIVATE lobby. Guest: proof to send.
var access_proof := ""
## Host only: true for a player this world's host has banned. A player is the
## identity their copy of the game made on first run, not a name or appearance.
var blocked := Callable()
const KICKED := "The host removed you from this game."
const BANNED := "The host banned you from this world."

## Tells a connected player why, then closes their connection.
func kick(peer: int, reason: String = KICKED) -> void:
    if hosting and peer != 1 and players.has(peer): _reject(peer, reason)
var _reject_pending: Dictionary = {}
var messages=preload("res://scripts/coop_messages.gd").new()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    transport = Transport.new()
    transport.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(transport)
    messages.send_frame=transport.send
    messages.send_encoded=transport.send_encoded
    messages.delivery_failed.connect(func(peer):transport._drop(peer,"reliable_delivery_failed"))
    transport.connected.connect(_connected)
    transport.disconnected.connect(_disconnected)
    transport.received.connect(_received)
    transport.failed.connect(func(reason):rejected.emit(reason))

func configure(token: String, mods: String, player_profile: Dictionary) -> bool:
    if token.length()!=64 or not token.is_valid_hex_number():return false
    identity=token;actor=token.sha256_text();mod_digest=mods
    profile=player_profile.duplicate(true)
    return true

func host(id: String, port: int = 54555, address: String = "*") -> Error:
    if identity.is_empty() or id.is_empty():return ERR_UNCONFIGURED
    var error: Error=transport.host(port,address)
    if error!=OK:return error
    hosting=true;world_id=id;trusted=true
    players={1:{"actor":actor,"profile":profile.duplicate(true)}}
    session_ready.emit(world_id,actor)
    return OK

func join_code(code: String) -> Error:
    hosting=false;trusted=false;players.clear()
    if identity.is_empty():return ERR_UNCONFIGURED
    return transport.join_code(code)

func join_address(address: String, port: int) -> Error:
    hosting=false;trusted=false;players.clear()
    if identity.is_empty():return ERR_UNCONFIGURED
    return transport.join_address(address,port)

func _connected(peer: int) -> void:
    if hosting:return
    _hello(peer,"")

## A ban has to outlive an uninstall, which makes a new identity. The device
## keeps an id for this game that only a factory reset changes; the host is
## sent a one-way scramble of it mixed with the world's id, so the raw id never
## leaves the device and no two worlds see the same value.
const NO_DEVICE := "0000000000000000000000000000000000000000000000000000000000000000"

static func device_print(world: String) -> String:
    var device := OS.get_unique_id()
    return NO_DEVICE if device.is_empty() or world.is_empty() else (device + "|pokewilds-ban|" + world).sha256_text()

## The host answers the first hello with the world's id; the second carries
## the device print for that world.
func _hello(peer: int, world: String) -> void:
    var hello := {"kind":"hello","protocol":PROTOCOL,"mods":mod_digest,
        "identity":identity,"profile":profile,"access":access_proof}
    if not world.is_empty(): hello["device"] = device_print(world)
    transport.send(peer, hello)

func _reject(peer: int, reason: String) -> void:
    transport.send(peer,{"kind":"rejected","reason":reason})
    _reject_pending[peer]=Time.get_ticks_msec()+1000

func _process(_delta:float)->void:
    messages.pump()
    for peer in _reject_pending.keys():
        if Time.get_ticks_msec()>=int(_reject_pending[peer]):
            transport._drop(peer)
            _reject_pending.erase(peer)

func _received(peer: int, payload: Dictionary) -> void:
    var kind:=String(payload.get("kind",""))
    if kind=="loading" and payload.get("active") is bool:
        if (hosting and players.has(peer)) or (not hosting and trusted):
            transport.set_loading(peer,payload.active,true)
            if payload.active:messages.patient[peer]=true
            elif messages.patient.has(peer):messages.patient[peer]=false
        return
    if kind=="session_blob":
        if (hosting and not players.has(peer)) or (not hosting and not trusted):transport._drop(peer,"fragment_before_handshake");return
        var assembled:Dictionary=messages.receive(peer,payload)
        if assembled.has("error"):transport._drop(peer,"fragment_"+String(assembled.error));return
        if assembled.has("packet"):_received(peer,assembled.packet)
        return
    if hosting:
        if _reject_pending.has(peer):return
        if not players.has(peer):
            if kind!="hello":_reject(peer,"Join handshake required.");return
            if payload.get("protocol")!=PROTOCOL:_reject(peer,"Game versions do not match.");return
            if payload.get("mods")!=mod_digest:_reject(peer,"Mods that change how the game plays must match the host.");return
            if not access_proof.is_empty() and String(payload.get("access",""))!=access_proof:_reject(peer,"Wrong password.");return
            var token:=String(payload.get("identity",""))
            if token.length()!=64 or not token.is_valid_hex_number():_reject(peer,"Invalid player identity.");return
            var id:=token.sha256_text()
            for player in players.values():
                if player.actor==id:_reject(peer,"This player is already connected.");return
            var device:=String(payload.get("device",""))
            if device.length()!=64 or not device.is_valid_hex_number():
                transport.send(peer,{"kind":"challenge","world":world_id});return
            if blocked.is_valid() and blocked.call(id,device):_reject(peer,BANNED);return
            var details=payload.get("profile",{})
            if not details is Dictionary:_reject(peer,"Invalid player profile.");return
            var clean:Dictionary={"name":String(details.get("name","PLAYER")).strip_edges().substr(0,24),
                "model":int(details.get("model",0)),"color":int(details.get("color",0))}
            players[peer]={"actor":id,"profile":clean,"device":device}
            transport.send(peer,{"kind":"welcome","world":world_id,"actor":id,"peer":peer,"protocol":PROTOCOL})
            admitted.emit(peer,id,clean)
            return
        if kind in ["hello","welcome","rejected","challenge"]:return
        # Sender identity always comes from the accepted socket, never a payload field.
        message.emit(peer,String(players[peer].actor),payload)
    else:
        if kind=="rejected":
            rejected.emit(String(payload.get("reason","Join refused.")))
            transport.stop();trusted=false
            return
        if kind=="challenge" and not trusted:
            if payload.get("world") is String and String(payload.world).length()<=64:_hello(peer,String(payload.world))
            return
        if kind=="welcome" and not trusted:
            if payload.get("protocol")!=PROTOCOL or payload.get("actor")!=actor:
                transport.stop();rejected.emit("Invalid host handshake.");return
            world_id=String(payload.get("world",""));trusted=true
            session_ready.emit(world_id,actor)
            return
        if trusted:message.emit(1,"host",payload)

func send_host(payload: Dictionary) -> Error:
    if hosting or not trusted:return ERR_UNAVAILABLE
    return _send_reliable(1,payload)

func set_loading(value:bool)->void:
    if loading==value:return
    loading=value
    for peer in transport.peers:
        transport.set_loading(peer,value)
        # Announce before expensive area work, without waiting behind snapshots.
        transport.send(peer,{"kind":"loading","active":value})

func send_to(peer: int, payload: Dictionary) -> Error:
    if not hosting or not players.has(peer) or peer==1:return ERR_UNAVAILABLE
    return _send_reliable(peer,payload)

func _send_reliable(peer:int,payload:Dictionary)->Error:
    var error:Error=messages.send(peer,payload)
    # Once the bounded reliable queue cannot accept an update, continuing would
    # leave the peer playing a different world. End its connection; its durable
    # profile and world remain available when it rejoins.
    if error!=OK:transport._drop(peer,"message_send_"+error_string(error))
    return error


func _disconnected(peer: int) -> void:
    messages.drop(peer)
    if not hosting:
        trusted=false
        connection_lost.emit()
    if players.has(peer):
        var id:=String(players[peer].actor)
        players.erase(peer)
        departed.emit(peer,id)

func stop() -> void:
    transport.stop();messages.clear();players.clear();_reject_pending.clear();trusted=false;hosting=false;loading=false;access_proof=""
