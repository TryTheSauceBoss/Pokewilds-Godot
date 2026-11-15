extends RefCounted
## Where ONLINE packets travel. Android builds that include libzt run an embedded
## ZeroTier node on an ad-hoc network: no ZeroTier app, account, network owner or
## member limit. Ad-hoc networks cannot broadcast, so those builds read the lobby
## list from the lobby directory. Everywhere else the same lobby flow runs on the
## local network and finds lobbies by broadcast.
const Paths=preload("res://scripts/game_data_paths.gd")
const GAME_PORT:=54555
const BEACON_PORT:=54556
## Lobby directory (see lobby-directory/ beside the source package). A [lobby] url
## in zerotier.cfg inside the game data folder overrides it without a rebuild;
## [lobby] force=true makes non-Android builds use it too, for testing.
## The lobby list's address and password are not part of the public source.
## Official builds read them from lobby_server.txt in the project folder (the
## address on its first line, the password on its second); that file is never
## published. A build made without it has no online lobby list of its own:
## run your own (see lobby-directory/) and give it your own file.
const LOBBY_FILE:="res://lobby_server.txt"
const BUILD_INFO:="res://scripts/build_info.gd"
static var _lobby_access:Array=[]

static func _lobby_text()->String:
    if ResourceLoader.exists(BUILD_INFO):
        var info:Variant=load(BUILD_INFO)
        if info!=null:return String(info.lobby())
    if FileAccess.file_exists(LOBBY_FILE):
        return FileAccess.get_file_as_string(LOBBY_FILE)
    return ""

## [address, password], both "" when this build was made without the file.
static func lobby_access()->Array:
    if _lobby_access.is_empty():
        _lobby_access=["",""]
        var contents:=_lobby_text()
        if not contents.is_empty():
            var found:Array=[]
            for line in contents.split("\n"):
                var text:=String(line).strip_edges()
                if not text.is_empty() and not text.begins_with("#"):found.append(text)
            if found.size()>=1 and String(found[0]).begins_with("https://"):_lobby_access[0]=String(found[0]).trim_suffix("/")
            if found.size()>=2:_lobby_access[1]=String(found[1])
    return _lobby_access

## The password to send to `url`: only ever to the official address.
static func lobby_key(url:String)->String:
    var access:=lobby_access()
    return String(access[1]) if not String(access[0]).is_empty() and url.begins_with(String(access[0])) else ""
static var bridge:Variant=null
static var _checked:=false
static var _udp:PacketPeerUDP
static var _beacon_open:=false

static func embedded()->bool:
    if _checked:return bridge!=null
    _checked=true
    if OS.get_name()=="Android" and Engine.has_singleton("JavaClassWrapper"):
        var wrapped=Engine.get_singleton("JavaClassWrapper").wrap("com.godot.game.PokeWildsZeroTier")
        if wrapped!=null and wrapped.available():bridge=wrapped
    return bridge!=null

static func _setting(key:String,fallback:Variant)->Variant:
    var config=ConfigFile.new()
    if config.load(Paths.path("zerotier.cfg"))!=OK:return fallback
    return config.get_value("lobby",key,fallback)

static func directory_url()->String:
    return String(_setting("url",String(lobby_access()[0]))).strip_edges().trim_suffix("/")

## True when lobbies are listed by the directory rather than found by broadcast.
static func uses_directory()->bool:
    return embedded() or bool(_setting("force",false))

## Safe to call repeatedly; the node starts once and keeps running.
static func start()->void:
    if embedded():bridge.start(OS.get_user_data_dir().path_join("zerotier"),GAME_PORT)

## {"state":"starting|joining|ready|error","address":String,"message":String,"lan":bool}
static func status()->Dictionary:
    if not embedded():
        var local:=""
        for value in IP.get_local_addresses():
            if "." in value and not value.begins_with("127.") and not value.begins_with("169.254."):local=value;break
        return {"state":"ready","address":local,"message":"","lan":true}
    var parts:PackedStringArray=String(bridge.status()).split("\t")
    while parts.size()<3:parts.append("")
    return {"state":"starting" if parts[0]=="stopped" else parts[0],"address":parts[1],"message":parts[2],"lan":false}

static func status_text()->String:
    var value=status()
    if value.lan:return "LOCAL NETWORK"
    match String(value.state):
        "ready":return "ONLINE" if String(value.message).is_empty() else String(value.message).to_upper()
        "error":return String(value.message).to_upper()
        "joining":return "JOINING NETWORK..."
    return "CONNECTING..."

## The host's game server keeps listening on GAME_PORT; this exposes it online.
static func host_open()->void:
    if embedded():bridge.hostOpen(GAME_PORT,GAME_PORT)

static func host_close()->void:
    if embedded():bridge.hostClose()

## Where the game's TCP socket should connect to reach a lobby's host.
static func join_endpoint(address:String)->Dictionary:
    if not embedded():return {"address":address,"port":GAME_PORT}
    var port:=int(bridge.connectOpen(address,GAME_PORT))
    return {} if port<=0 else {"address":"127.0.0.1","port":port}

static func join_close()->void:
    if embedded():bridge.connectClose()

static func beacon_open()->bool:
    if _beacon_open:return true
    if uses_directory():return false
    _udp=PacketPeerUDP.new()
    _udp.set_broadcast_enabled(true)
    # A second copy on one machine cannot share the port; it can still ask
    # hosts for their lobbies and hear the direct replies.
    if _udp.bind(BEACON_PORT)!=OK and _udp.bind(0)!=OK:_udp=null;return false
    _beacon_open=true
    return true

static func beacon_close()->void:
    if not _beacon_open:return
    _beacon_open=false
    if _udp!=null:_udp.close();_udp=null

## An empty address reaches every player on the network.
static func beacon_send(text:String,address:String="",port:int=BEACON_PORT)->void:
    if not _beacon_open:return
    _udp.set_dest_address("255.255.255.255" if address.is_empty() else address,port)
    _udp.put_packet(text.to_utf8_buffer())

static func beacon_poll()->Array[Dictionary]:
    var result:Array[Dictionary]=[]
    if not _beacon_open:return result
    while _udp.get_available_packet_count()>0 and result.size()<64:
        var bytes:=_udp.get_packet()
        result.append({"from":_udp.get_packet_ip(),"port":_udp.get_packet_port(),"data":bytes.get_string_from_utf8()})
    return result

## Lobby directory requests made outside Godot's own TLS (see PokeWildsZeroTier).
## An empty body is a GET; anything else is a JSON POST.
static func http_start(url:String,body:String="")->int:
    if not embedded():return 0
    bridge.setLobbyKey(lobby_key(url))
    return int(bridge.httpStart(url,body))

## {} while pending, then {"code":int,"body":String} once. Code 0 means failed.
static func http_take(id:int)->Dictionary:
    if not embedded() or id<=0:return {}
    var text:=String(bridge.httpTake(id))
    if text.is_empty():return {}
    var split:=text.find("\n")
    return {"code":int(text.left(split)),"body":text.substr(split+1)}
