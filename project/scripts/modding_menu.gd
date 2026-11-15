extends Control
const Pack = preload("res://scripts/native_mod_pack.gd")
const Settings = preload("res://scripts/game_options.gd")
var main: Node
var selection := 0
var first := 0
var page := "library"
var chosen := -1
var entries := []
var collisions := []
var labels := []
var status: Label
var heading: Label
var cursor: TextureRect
var picker: FileDialog
var busy := false
var stick_held := false
var buttons: Array[Button] = []
var message := ""

func configure(owner_main: Node) -> void:
    main=owner_main;size=Vector2(320,180);z_index=600
    var background:=ColorRect.new();background.color=Color.WHITE;background.size=size;add_child(background)
    var header:=_panel(Vector2(2,2),Vector2(316,25))
    heading=main._source_ui_label(header,"Title",Vector2(12,6),Vector2(226,14),9,"MODDING")
    heading.clip_text=true
    for i in range(2):
        var nav:=Button.new();nav.text="UP" if i==0 else "DN"
        nav.position=Vector2(246+i*32,4);nav.size=Vector2(30,18)
        _button_style(nav);header.add_child(nav)
        for state in ["normal","hover","pressed","focus","disabled"]:nav.add_theme_stylebox_override(state,StyleBoxEmpty.new())
        nav.pressed.connect(func():_navigate(-1 if i==0 else 1))
    var body:=_panel(Vector2(2,29),Vector2(316,103))
    cursor=main._source_texture_rect(body,"Cursor",Vector2(8,10),Vector2(5,7),main.source_command_cursor.texture)
    for i in range(5):
        var button:=Button.new();button.position=Vector2(20,4+i*19);button.size=Vector2(284,19)
        button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.clip_text=true
        _button_style(button);body.add_child(button);buttons.append(button)
        button.pressed.connect(func():selection=first+i;activate())
    var footer:=_panel(Vector2(2,134),Vector2(316,44))
    status=main._source_ui_label(footer,"Status",Vector2(10,5),Vector2(294,35),7,"")
    status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.clip_text=true
    picker=FileDialog.new();picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE
    picker.access=FileDialog.ACCESS_FILESYSTEM;picker.use_native_dialog=true
    picker.filters=PackedStringArray(["*.pwmod,*.zip ; PokeWilds Godot mod"])
    picker.file_selected.connect(_install);add_child(picker);hide()

func _button_style(button: Button) -> void:
    button.flat=true;button.focus_mode=Control.FOCUS_NONE
    button.add_theme_font_override("font",main.JOHTO_FONT);button.add_theme_font_size_override("font_size",8)
    for color in ["font_color","font_hover_color","font_pressed_color"]:button.add_theme_color_override(color,Color.BLACK)

func _panel(at: Vector2, dimensions: Vector2) -> Panel:
    var result:=Panel.new();result.position=at;result.size=dimensions
    result.add_theme_stylebox_override("panel",Settings.style());add_child(result);return result

func open() -> void:
    page="library";selection=0;first=0;stick_held=false;message=""
    entries=Pack.library();collisions=Pack.conflicts();show();_refresh()
    if not Pack.last_error.is_empty():status.text=Pack.last_error

func _close() -> void:
    if busy:return
    if page!="library":
        page="library";selection=maxi(0,chosen+3);first=0;message="";_refresh();return
    hide();main._open_touch_config()

func _refresh() -> void:
    labels=[]
    if page=="library":
        heading.text="MODDING  "+str(entries.size())
        labels=["IMPORT MOD","ALL MODS OFF","CONFLICTS: "+str(collisions.size())]
        for i in range(entries.size()):
            labels.append(str(i+1)+". "+("ON  " if entries[i].get("enabled",false) else "OFF ")+str(entries[i].name))
        labels.append("BACK")
    elif page=="detail":
        heading.text=str(entries[chosen].name)
        labels=["ENABLED: "+("ON" if entries[chosen].get("enabled",false) else "OFF"),"LOAD EARLIER","LOAD LATER","REMOVE MOD","BACK"]
    elif page=="remove":
        heading.text="REMOVE MOD?";labels=["NO - KEEP MOD","YES - REMOVE MOD"]
    else:
        heading.text="CONFLICTS: LATER WINS"
        for conflict in collisions:labels.append(str(conflict.target))
        labels.append("BACK")
    selection=clampi(selection,0,labels.size()-1)
    first=clampi(first,maxi(0,selection-4),selection)
    first=mini(first,maxi(0,labels.size()-5))
    for i in range(buttons.size()):
        buttons[i].visible=first+i<labels.size()
        if buttons[i].visible:buttons[i].text=str(labels[first+i])
    main._align_control_tick(cursor,buttons[selection-first])
    status.text=message
    if message.is_empty():
        if page=="conflicts" and selection<collisions.size():
            var conflict:Dictionary=collisions[selection]
            status.text=str(conflict.earlier)+" -> "+str(conflict.winner)+"\nLater enabled mod wins this entry."
        elif page=="detail":status.text="Version: "+str(entries[chosen].version)+"  Order: "+str(chosen+1)+"\nChanges apply after a full restart. B: BACK"
        elif page=="library":status.text="A: SELECT  B: BACK  UP/DOWN: SCROLL\nLater enabled mods win conflicts. Restart to apply."
        else:status.text="A: SELECT  B: BACK"
    Settings.refresh_frames(self)

func _navigate(direction:int) -> void:
    if busy or picker.visible:return
    message="";selection=wrapi(selection+direction,0,labels.size());_refresh()

func handle(event: InputEvent) -> void:
    if busy or event.is_echo() or picker.visible:return
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):_close()
    elif event.is_action_pressed("move_up"):_navigate(-1)
    elif event.is_action_pressed("move_down"):_navigate(1)
    elif event.is_action_pressed("confirm"):activate()

func _changed(error: Error) -> void:
    message="Saved. Save your game, then fully restart to apply." if error==OK else "Could not save changes."
    entries=Pack.library();collisions=Pack.conflicts();_refresh()

func activate() -> void:
    if busy:return
    if page=="library":
        if selection==0:picker.popup_centered_ratio(0.8)
        elif selection==1:_changed(Pack.disable_all())
        elif selection==2:page="conflicts";selection=0;first=0;message="";_refresh()
        elif selection==labels.size()-1:_close()
        else:chosen=selection-3;page="detail";selection=0;first=0;message="";_refresh()
    elif page=="detail":
        if selection==0:_changed(Pack.set_enabled(chosen,not entries[chosen].get("enabled",false)))
        elif selection in [1,2]:
            var direction:= -1 if selection==1 else 1
            var error:=Pack.move_pack(chosen,direction)
            if error==OK:chosen+=direction
            _changed(error)
        elif selection==3:page="remove";selection=0;first=0;message="";_refresh()
        else:_close()
    elif page=="remove":
        if selection==0:page="detail";selection=0;_refresh()
        else:
            var error:=Pack.remove_pack(chosen)
            page="library";selection=0;first=0;_changed(error)
    elif selection==labels.size()-1:_close()
    else:_refresh()

func _install(path: String) -> void:
    busy=true;status.text="Checking mod package..."
    await get_tree().process_frame
    message=Pack.install(path);busy=false
    entries=Pack.library();collisions=Pack.conflicts();_refresh()
