extends Node
## Host-routed, bounded TCP transport. Gameplay belongs to the session adapter.
signal connected(peer: int)
signal disconnected(peer: int)
signal received(peer: int, message: Dictionary)
signal failed(reason: String)
const JoinCode = preload("res://scripts/coop_join_code.gd")
const MAX_FRAME := 256 * 1024
const MAX_QUEUE := 4 * 1024 * 1024
const FRAME_BUDGET := 64 * 1024
const TIMEOUT_MS := 20000
const LOADING_TIMEOUT_MS := 120000
## How long a joining player waits for the host's first word. Two devices that
## have not spoken since their games were opened need time to find a path to
## each other: it has taken 24 seconds, and the join gave up at 20.
const FIRST_CONTACT_MS := 60000
## How long a joining player puts up with silence after that, until they are
## in the world. A host can stop sending for well over 20 seconds while it
## prepares the next part of a large world, and the join was given up with
## minutes of downloading done.
const JOIN_SILENCE_MS := 90000
## True once a joining player is in the world; from then the usual limit holds.
var settled := false
var server := TCPServer.new()
var peers: Dictionary = {}
var hosting := false
var joining := false
var port := JoinCode.PORT
var _next_peer := 2
var last_disconnect_reason := ""

func host(listen_port: int = JoinCode.PORT, address: String = "*") -> Error:
    stop()
    var error := server.listen(listen_port, address)
    if error != OK: return error
    port = listen_port
    hosting = true
    return OK

func join_code(code: String) -> Error:
    var address := JoinCode.decode(code)
    if address.is_empty(): return ERR_INVALID_PARAMETER
    return join_address(address, JoinCode.PORT)

func join_address(address: String, remote_port: int) -> Error:
    stop()
    var socket := StreamPeerTCP.new()
    var error := socket.connect_to_host(address, remote_port)
    if error != OK: return error
    joining = true
    _add(1, socket)
    return OK

func _add(peer: int, socket: StreamPeerTCP) -> void:
    socket.set_no_delay(true)
    peers[peer] = {"socket": socket, "rx": PackedByteArray(), "tx": [],
        "offset": 0, "queued": 0, "ready": false,
        "seen": Time.get_ticks_msec(), "ping": Time.get_ticks_msec(), "heard": false,
        "local_loading_until": 0, "remote_loading_until": 0}

func set_loading(peer:int, loading:bool, remote:bool=false)->void:
    if not peers.has(peer):return
    peers[peer]["remote_loading_until" if remote else "local_loading_until"] = Time.get_ticks_msec()+LOADING_TIMEOUT_MS if loading else 0

func receive_expired(state:Dictionary, now:int)->bool:
    var limit:=TIMEOUT_MS
    if joining and not state.get("heard",false):limit=FIRST_CONTACT_MS
    elif joining and not settled:limit=JOIN_SILENCE_MS
    return now-int(state.seen)>limit and now>int(state.get("local_loading_until",0)) and now>int(state.get("remote_loading_until",0))

func send(peer: int, message: Dictionary) -> Error:
    return send_encoded(peer,JSON.stringify(message).to_utf8_buffer())

func send_encoded(peer:int, bytes:PackedByteArray)->Error:
    if not peers.has(peer): return ERR_DOES_NOT_EXIST
    if bytes.is_empty() or bytes.size() > MAX_FRAME: return ERR_INVALID_DATA
    var state: Dictionary = peers[peer]
    if int(state.queued) + bytes.size() + 4 > MAX_QUEUE: return ERR_BUSY
    var frame := PackedByteArray()
    frame.resize(4)
    frame.encode_u32(0, bytes.size())
    frame.append_array(bytes)
    state.tx.append(frame)
    state.queued += frame.size()
    return OK

func _process(_delta:float)->void:
    if hosting and server.is_connection_available():
        var socket := server.take_connection()
        if peers.size() >= 3:
            socket.disconnect_from_host()
        else:
            var id := _next_peer
            _next_peer += 1
            _add(id, socket)
    # Real time, independent of gameplay/battle speed and menu pauses.
    var now := Time.get_ticks_msec()
    for peer in peers.keys():
        if not peers.has(peer): continue
        var state: Dictionary = peers[peer]
        var socket: StreamPeerTCP = state.socket
        socket.poll()
        var status := socket.get_status()
        if status in [StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE]:
            _drop(peer,"socket_closed")
            continue
        if status != StreamPeerTCP.STATUS_CONNECTED:
            if now - int(state.seen) > TIMEOUT_MS:_drop(peer,"connect_timeout")
            continue
        if not state.ready:
            state.ready = true
            connected.emit(peer)
            if not peers.has(peer): continue
        if now - int(state.ping) >= 4000:
            send(peer, {"kind":"keepalive"})
            state.ping = now
        var available := mini(socket.get_available_bytes(), FRAME_BUDGET)
        if available > 0:
            var data := socket.get_data(available)
            if data[0] != OK:
                _drop(peer,"socket_read_failed")
                continue
            state.rx.append_array(data[1])
            state.seen = now
            state.heard = true
        # Check the socket before timing out: world loading may have delayed this
        # process call while keepalives were already waiting in the receive buffer.
        if receive_expired(state,now):
            _drop(peer,"receive_timeout")
            continue
        var read_count := 0
        while peers.has(peer) and state.rx.size() >= 4 and read_count < 32:
            var length := int(state.rx.decode_u32(0))
            if length <= 0 or length > MAX_FRAME:
                _drop(peer,"invalid_frame_size_"+str(length))
                break
            if state.rx.size() < length + 4: break
            var decoded = JSON.parse_string(state.rx.slice(4, length + 4).get_string_from_utf8())
            state.rx = state.rx.slice(length + 4)
            read_count += 1
            if not decoded is Dictionary:
                _drop(peer,"invalid_frame_json")
                break
            if decoded.get("kind", "") != "keepalive": received.emit(peer, decoded)
        if not peers.has(peer): continue
        var remaining := FRAME_BUDGET
        while not state.tx.is_empty() and remaining > 0:
            var frame: PackedByteArray = state.tx[0]
            var offset := int(state.offset)
            var sent := socket.put_partial_data(frame.slice(offset, mini(frame.size(), offset + remaining)))
            if sent[0] != OK:
                _drop(peer,"socket_write_failed")
                break
            var count := int(sent[1])
            if count <= 0: break
            remaining -= count
            state.offset += count
            state.queued -= count
            if int(state.offset) == frame.size():
                state.tx.pop_front()
                state.offset = 0

func _drop(peer: int, reason: String = "session_closed") -> void:
    if not peers.has(peer): return
    print("ONLINE transport closed peer=",peer," reason=",reason)
    last_disconnect_reason=reason
    peers[peer].socket.disconnect_from_host()
    peers.erase(peer)
    disconnected.emit(peer)
    if joining:
        joining = false
        failed.emit("Connection to the host closed.")

func stop() -> void:
    server.stop()
    for state in peers.values(): state.socket.disconnect_from_host()
    peers.clear()
    hosting = false
    joining = false
    settled = false
    _next_peer = 2

func _exit_tree() -> void:
    stop()
