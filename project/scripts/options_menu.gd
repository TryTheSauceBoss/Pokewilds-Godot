extends Control

var internet_setup:Panel

@onready var input_router: InputRouter = get_node("/root/InputRouterSingleton")
const Settings = preload("res://scripts/game_options.gd")
const ROWS := [
    ["music","MUSIC VOLUME","Adjust music volume."],
    ["sound","SOUND EFFECTS","Adjust sound effects."],
    ["world_sound","WORLD SOUND EFFECTS","Adjust world movement and field effects."],
    ["cries","POKEMON CRIES","Adjust Pokemon cry volume."],
    ["footsteps","FOOTSTEP VOLUME","Adjust walking and water movement sounds."],
    ["controls","CONTROLS","View controller and touch controls."],
    ["button_layout","BUTTON LAYOUT","TYPE 1: Nintendo. TYPE 2: Xbox."],
    ["radial","RADIAL WHEEL","Enable the field move wheel."],
    ["ball_mechanics","THROWABLE POKEBALLS","RT: throw. Hold RT: balls. LT + RT: party."],
    ["zoom","ZOOM","Enable gameplay and map zoom controls."],
    ["minimap","MINIMAP","Show the minimap while exploring."],
    ["fps_counter","FPS COUNTER","Show frames per second in the top right corner."],
    ["diagonal","DIAGONAL MOVE","Allow diagonal thumbstick movement."],
    ["auto_run","AUTO RUN","Run automatically when walking."],
    ["battle_animations","BATTLE ANIMATIONS","Play battle animations."],
    ["held_emotes","HELD EMOTES","Show when a Pokemon has an item ready."],
    ["shiny_sparkles","SHINY SPARKLES","Show sparkles on shiny overworld Pokemon."],
    ["map_waypoint","MAP WAYPOINT","Enable waypoint creation and map markers."],
    ["weather_events","WEATHER EVENTS","Random wind, rain, lightning, sand and fire."],
    ["dark_mode","DARK MODE","Use dark menus with the selected frame."],
    ["lofi_music","LOFI MUSIC","Use the alternate music pack."],
    ["hd_emotes","HD EMOTES","Use alternate emotes and a green item check."],
    ["gen3_overhaul","GEN3 OVERHAUL","Switch the world artwork without restarting."],
    ["circle_lights","CIRCLE LIGHTS","Use circular light shapes."],
    ["game_speed","GAME SPEED","Speed up gameplay, music and effects together."],
    ["text_speed","TEXT SPEED","Choose how quickly dialogue appears."],
    ["frame","FRAME","Choose a frame."],
    ["swipe_menu","SAVE FILES AND MODS","Open game files, modding and touch controls."]]
var menu_rows: Array = ROWS.duplicate(true)
var main: Node
var selection := 0
var first := 0
var controls_page := false
var control_index := 0
var control_rows: Array[Array] = []
var kick_index := 0
var kick_peer := 0
var kick_choice := 1
var kick_prompt: Panel
var kick_prompt_cursor: TextureRect
var kick_prompt_choices: Array[Label] = []
var kick_ban := false
var players_page := false
var password_view: Panel
var password_text: Label
var action_prompt: Panel
var action_name: Label
var action_cursor: TextureRect
var action_choices: Array[Label] = []
var action_choice := 0
var kick_warning: Label
const KICK_WARNING := "This player will be removed from your world."
const BAN_WARNING := "This player will be removed from your world and will not be able to rejoin this world. Are you sure?"
var title: Label
var description: Label
var body: Panel
var cursor: TextureRect
var row_nodes: Array[Control] = []
var selected_text_material: ShaderMaterial

func configure(owner_main: Node) -> void:
    main=owner_main
    var shader:=Shader.new()
    shader.code="shader_type canvas_item; uniform bool dark=false; void fragment(){ vec4 ink=texture(TEXTURE, UV); COLOR=vec4(dark ? vec3(1.0,0.45,0.45) : vec3(0.75,0.16,0.16),ink.a*COLOR.a); }"
    selected_text_material=ShaderMaterial.new();selected_text_material.shader=shader
    name="OptionsMenu"
    size=Vector2(320,180)
    z_index=260
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var background:=ColorRect.new()
    background.color=Color.WHITE;background.size=size;background.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(background)
    var header:=panel(Vector2(2,2),Vector2(316,25))
    title=label(header,"OPTIONS",Vector2(12,6),Vector2(290,14),10)
    body=panel(Vector2(2,29),Vector2(316,111))
    var footer:=panel(Vector2(2,142),Vector2(316,36))
    description=label(footer,"",Vector2(10,10),Vector2(294,24),7)
    description.add_theme_constant_override("line_spacing",-2)
    description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    cursor=main._source_texture_rect(body,"Cursor",Vector2(8,9),Vector2(5,7),main.source_command_cursor.texture)
    for i in range(6):
        var row:=Control.new();row.position=Vector2(18,9+i*16);row.size=Vector2(288,16)
        row.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.add_child(row);row_nodes.append(row)
    # The same layout as QUIT GAME?: a question with YES and NO beneath it.
    kick_prompt=panel(Vector2(20,44),Vector2(280,92))
    kick_warning=label(kick_prompt,KICK_WARNING,Vector2(16,13),Vector2(250,40),8)
    kick_warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    kick_prompt_choices=[label(kick_prompt,"YES",Vector2(64,64),Vector2(50,14),10),label(kick_prompt,"NO",Vector2(176,64),Vector2(50,14),10)]
    kick_prompt_cursor=main._source_texture_rect(kick_prompt,"Cursor",Vector2(52,67),Vector2(5,7),main.source_command_cursor.texture)
    kick_prompt.hide()
    # PLAYERS > a player: what to do with them.
    action_prompt=panel(Vector2(64,52),Vector2(192,76))
    action_name=label(action_prompt,"",Vector2(38,13),Vector2(140,14),10)
    action_choices=[label(action_prompt,"KICK",Vector2(34,33),Vector2(140,14),10),label(action_prompt,"KICK AND BAN",Vector2(34,49),Vector2(140,14),10)]
    action_cursor=main._source_texture_rect(action_prompt,"Cursor",Vector2(22,34),Vector2(5,7),main.source_command_cursor.texture)
    action_prompt.hide()
    # PLAYERS > SHOW PASSWORD: the whole screen, so any length can be read.
    password_view=panel(Vector2(2,2),Vector2(316,176))
    label(password_view,"PASSWORD",Vector2(14,10),Vector2(288,14),10)
    password_text=label(password_view,"",Vector2(14,34),Vector2(288,112),10)
    password_text.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
    label(password_view,"B: BACK",Vector2(14,154),Vector2(288,12),7)
    password_view.hide()
    hide()

## A snapshot of the player as everyone sees them: their model, facing the
## camera, in their colour. Several players can share a name.
func player_icon(parent: Node, player: Dictionary, at: Vector2) -> void:
    var model:=clampi(int(player.get("model",0)),0,main.PLAYER_MODEL_WALK_TEXTURES.size()-1)
    var color:=clampi(int(player.get("color",0)),0,main.PLAYER_COLOR_VALUES.size()-1)
    var sheet:Texture2D=main._recolor_texture(main.PLAYER_MODEL_WALK_TEXTURES[model],main.PLAYER_MODEL_REPLACE_COLORS[model],main.PLAYER_COLOR_VALUES[color],"coop:%d:%d:false:walk"%[model,color])
    var frame:=Vector2(sheet.get_width()/8.0,sheet.get_height())
    main._source_texture_rect(parent,"PlayerIcon",at,frame,main._source_texture_region(sheet,Rect2(Vector2.ZERO,frame)))

## The box is as tall as its question: three lines for a ban, two for a kick.
func _fit_kick_prompt() -> void:
    kick_warning.text=BAN_WARNING if kick_ban else KICK_WARNING
    var choices_y:=25.0+13.0*(3 if kick_ban else 2)
    for choice in kick_prompt_choices:choice.position.y=choices_y
    kick_prompt.size.y=choices_y+28.0
    kick_prompt.position.y=roundf((180.0-kick_prompt.size.y)/2.0)

## Both arrows use the game's own rule for centring a tick on a line of text.
func _place_kick_cursor() -> void:
    kick_prompt_cursor.position.x=kick_prompt_choices[kick_choice].position.x-12
    main._align_menu_tick(kick_prompt_cursor,kick_prompt_choices[kick_choice])

func _place_action_cursor() -> void:
    main._align_menu_tick(action_cursor,action_choices[action_choice])

func panel(at: Vector2, dimensions: Vector2) -> Panel:
    var node:=Panel.new();node.position=at;node.size=dimensions
    node.mouse_filter=Control.MOUSE_FILTER_IGNORE
    node.add_theme_stylebox_override("panel",Settings.style());add_child(node)
    return node

func label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size: int=8) -> Label:
    return main._source_ui_label(parent,"Text",at,dimensions,font_size,text)

func open() -> void:
    menu_rows=ROWS.duplicate(true)
    # Online the art changes on the next load, not at once, for host and guests alike.
    if is_instance_valid(main.coop_game) and main.coop_game.active:
        for row in menu_rows:
            if row[0]=="gen3_overhaul":row[2]="To see Gen 3 world, please turn on and then restart game."
    if is_instance_valid(main.coop_game) and main.coop_game.active and main.coop_game.hosting:
        menu_rows.append(["horde_mode","HORDE MODE","Rare cooperative night hordes. Host sets this world option."])
        menu_rows.append(["raids_mode","RAIDS","ALL: each fighter catches. LAST: finishing player catches."])
        menu_rows.append(["players","LOBBY","Friends find this world in MULTIPLAYER > JOIN GAME. A: players, and the password of a private game."])
        menu_rows.append(["autosave","AUTOSAVE","OFF: the world is only written when you SAVE. Resets to ON each launch."])
    kick_index=0;players_page=false;kick_prompt.hide();action_prompt.hide();password_view.hide()
    controls_page=false;selection=0;first=0
    main.game_menu_box.hide();show();refresh()

func close() -> void:
    hide();main.game_menu_box.show();main._update_game_menu_cursor()
    if is_instance_valid(main.shared_save_folder): main.shared_save_folder.export_files(main)

func handle(event: InputEvent) -> void:
    if is_instance_valid(internet_setup):internet_setup.handle(event);return
    if event.is_echo():return
    if password_view.visible:
        if event.is_action_pressed("cancel") or event.is_action_pressed("start") or event.is_action_pressed("confirm"):password_view.hide()
        return
    if kick_prompt.visible:
        if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
            kick_choice=1-kick_choice;_place_kick_cursor()
        elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            kick_prompt.hide()
        elif event.is_action_pressed("confirm"):
            kick_prompt.hide()
            if kick_choice==0:main.coop_game.kick(kick_peer,kick_ban)
            refresh()
        return
    if action_prompt.visible:
        if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
            action_choice=1-action_choice;_place_action_cursor()
        elif event.is_action_pressed("cancel") or event.is_action_pressed("start"):
            action_prompt.hide()
        elif event.is_action_pressed("confirm"):
            # NO is selected first, so a stray extra press removes nobody.
            kick_ban=action_choice==1;kick_choice=1
            _fit_kick_prompt()
            action_prompt.hide();kick_prompt.show();kick_prompt.move_to_front();_place_kick_cursor()
        return
    if players_page:
        var players:Array=main.coop_game.kick_candidates()
        # A private game has one more row under the players: SHOW PASSWORD.
        var page_rows:=players.size()+(1 if main.coop_game.lobby_private else 0)
        if event.is_action_pressed("cancel") or event.is_action_pressed("start"):players_page=false
        elif page_rows==0:return
        elif event.is_action_pressed("move_up"):kick_index=wrapi(kick_index-1,0,page_rows)
        elif event.is_action_pressed("move_down"):kick_index=wrapi(kick_index+1,0,page_rows)
        elif event.is_action_pressed("confirm"):
            kick_index=clampi(kick_index,0,page_rows-1)
            if kick_index>=players.size():
                password_text.text=String(main.coop_game.lobby_password)
                password_view.show();password_view.move_to_front()
                return
            kick_peer=int(players[kick_index].peer);action_choice=0
            action_name.text=String(players[kick_index].name)
            var old_icon:=action_prompt.get_node_or_null("PlayerIcon")
            if old_icon!=null:action_prompt.remove_child(old_icon);old_icon.queue_free()
            player_icon(action_prompt,players[kick_index],Vector2(16,8))
            action_prompt.show();action_prompt.move_to_front();_place_action_cursor()
            return
        else:return
        refresh();return
    if event.is_action_pressed("cancel") or event.is_action_pressed("start"):
        if controls_page: controls_page=false;refresh()
        else: close()
        return
    var direction:=0
    if event.is_action_pressed("move_up"):direction=-1
    elif event.is_action_pressed("move_down"):direction=1
    if direction:
        if controls_page:control_index=wrapi(control_index+direction,0,control_rows.size())
        else:selection=wrapi(selection+direction,0,menu_rows.size())
        refresh();return
    if controls_page:return
    var key:String=menu_rows[selection][0]
    if event.is_action_pressed("confirm") and key=="controls":
        build_controls();controls_page=true;control_index=0;refresh();return
    if event.is_action_pressed("confirm") and key=="back":close();return
    if event.is_action_pressed("confirm") and key=="swipe_menu":
        close();main._close_game_menu();main._open_touch_config(true);return
    if event.is_action_pressed("confirm") and key=="players":
        players_page=true;kick_index=0;refresh();return
    direction=-1 if event.is_action_pressed("move_left") else 1 if event.is_action_pressed("move_right") or event.is_action_pressed("confirm") else 0
    if direction and key=="internet_code":
        internet_setup=preload("res://scripts/coop_zerotier_setup.gd").new()
        main.get_node("UI").add_child(internet_setup);internet_setup.configure(main)
        return
    if direction and key=="join_code":
        main.coop_game.cycle_endpoint(direction);refresh();return
    if direction and key=="autosave":
        var Journal=preload("res://scripts/coop_state.gd")
        Journal.journal_enabled=not Journal.journal_enabled
        refresh();return
    if direction and key in ["horde_mode","raids_mode"]:
        if not main.coop_game.hosting:return
        var settings:Dictionary=main.coop_game.hordes.settings()
        var option="horde" if key=="horde_mode" else "raids"
        var value:Variant=not bool(settings.get("horde",true)) if key=="horde_mode" else "LAST" if settings.get("raids","ALL")=="ALL" else "ALL"
        await main.coop_game.command("world_setting",{"key":option,"value":value})
        refresh();return
    if not direction or not Settings.values.has(key):return
    var value=Settings.values[key]
    if key in ["music","sound","world_sound","cries","footsteps"]:value=clampi(int(value)+direction*5,0,100)
    elif key=="game_speed":value=Settings.GAME_SPEEDS[wrapi(Settings.GAME_SPEEDS.find(float(value))+direction,0,Settings.GAME_SPEEDS.size())]
    elif key=="text_speed":value=wrapi(int(value)+direction,0,3)
    elif key=="frame":value=wrapi(int(value)+direction,0,124)
    elif key=="button_layout":value=1-int(value)
    else:value=not bool(value)
    if key == "gen3_overhaul":
        await main.switch_gen3_overhaul(bool(value))
        refresh()
        return
    var saved:=Settings.change(key,value)
    main._apply_game_options()
    refresh()
    if saved!=OK:description.text="Could not save options. Check device storage."

func refresh() -> void:
    selected_text_material.set_shader_parameter("dark",Settings.enabled("dark_mode"))
    if players_page:
        title.text="LOBBY"
        var players:Array=main.coop_game.kick_candidates()
        var page_rows:=players.size()+(1 if main.coop_game.lobby_private else 0)
        kick_index=clampi(kick_index,0,maxi(0,page_rows-1))
        first=clampi(kick_index-2,0,maxi(0,page_rows-6))
        cursor.visible=page_rows>0
        cursor.position.y=9+(kick_index-first)*16
        for i in range(6):
            var row:=row_nodes[i]
            for child in row.get_children():row.remove_child(child);child.queue_free()
            if first+i<players.size():
                player_icon(row,players[first+i],Vector2(0,-4))
                label(row,String(players[first+i].name),Vector2(22,0),Vector2(150,14),8)
                var joined:=label(row,"JOINED %s"%String(players[first+i].order),Vector2(176,0),Vector2(108,14),7)
                joined.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
            elif first+i==players.size() and main.coop_game.lobby_private:label(row,"SHOW PASSWORD",Vector2.ZERO,Vector2(280,14),8)
            elif page_rows==0 and i==0:label(row,"NO OTHER PLAYERS",Vector2.ZERO,Vector2(280,14),8)
        if kick_index>=players.size() and main.coop_game.lobby_private:description.text="A: SHOW THIS WORLD'S PASSWORD\nB: BACK"
        else:description.text="Nobody else is in your world.\nB: BACK" if players.is_empty() else "A: KICK or KICK AND BAN\nB: BACK"
        return
    cursor.visible=true
    title.text="CONTROLS" if controls_page else "OPTIONS"
    title.position.y = 8 if int(Settings.values.frame) + 1 in [118, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 27, 29, 30, 32, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100] else 6
    var index:=control_index if controls_page else selection
    var count:=control_rows.size() if controls_page else menu_rows.size()
    first=clampi(index-2,0,maxi(0,count-6))
    cursor.position.y=9+(index-first)*16
    for i in range(6):
        var row:=row_nodes[i]
        for child in row.get_children():row.remove_child(child);child.queue_free()
        var actual:=first+i
        if actual>=count:continue
        if controls_page:
            label(row,control_rows[actual][0],Vector2.ZERO,Vector2(118,14),8)
            var binding:=label(row,control_rows[actual][1],Vector2(120,0),Vector2(165,14),7)
            var width:=binding.get_theme_font("font").get_string_size(binding.text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
            binding.scale.x=minf(1.0,165.0/maxf(1.0,width))
            continue
        var key:String=menu_rows[actual][0]
        var row_label := label(row,menu_rows[actual][1],Vector2.ZERO,Vector2(128,14),8)
        var text_width := row_label.get_theme_font("font").get_string_size(row_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x
        row_label.scale.x = minf(1.0,118.0/maxf(1.0,text_width))
        if key=="players":
            # One line for the lobby and who is in it: how the world is listed,
            # and how many of the four places are taken.
            var game=main.coop_game
            var count_label := label(row,"%s  %d/4 IN WORLD"%["PRIVATE" if game.lobby_private else "PUBLIC",game.session.players.size()],Vector2(132,0),Vector2(144,14),7)
            var count_width := count_label.get_theme_font("font").get_string_size(count_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
            count_label.scale.x = minf(1.0,140.0/maxf(1.0,count_width))
            continue
        if key=="internet_code":
            label(row,preload("res://scripts/coop_zerotier.gd").code(),Vector2(132,0),Vector2(144,14),8)
            continue
        if key=="join_code":
            label(row,main.coop_game.join_code(),Vector2(132,0),Vector2(144,14),8)
            continue
        if key in ["controls","back","swipe_menu"]:continue
        if key in ["music","sound","world_sound","cries","footsteps"]:
            var bar:=ColorRect.new();bar.position=Vector2(138,6);bar.size=Vector2(98,1);bar.color=Color.BLACK;row.add_child(bar)
            var knob:=ColorRect.new();knob.position=Vector2(138+float(Settings.values[key])*0.98,3);knob.size=Vector2(2,7);knob.color=Color8(192,40,40);row.add_child(knob)
            label(row,str(Settings.values[key]),Vector2(246,0),Vector2(36,14),8)
        elif key=="frame":
            label(row,"TYPE %d" % (int(Settings.values.frame)+1),Vector2(132,0),Vector2(142,14),7)
        elif key=="game_speed":
            for c in range(Settings.GAME_SPEEDS.size()):
                var choice:=label(row,["1x","1.5x","2x","3x","4x"][c],Vector2(132+c*30,0),Vector2(30,14),7)
                choice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
                var selected: bool = is_equal_approx(float(Settings.values.game_speed),Settings.GAME_SPEEDS[c])
                choice.add_theme_color_override("font_color",Color8(192,40,40) if selected else Color.BLACK)
                if selected:choice.material=selected_text_material
        else:
            var choices:Array=["ON","OFF"]
            var selected:=0 if bool(Settings.values.get(key,true)) else 1
            if key=="autosave":selected=0 if preload("res://scripts/coop_state.gd").journal_enabled else 1
            if key=="horde_mode":selected=0 if main.coop_game.hordes.settings().get("horde",true) else 1
            elif key=="raids_mode":choices=["ALL","LAST"];selected=0 if main.coop_game.hordes.settings().get("raids","ALL")=="ALL" else 1
            if key in ["frame","button_layout"]:choices=["TYPE 1","TYPE 2"];selected=int(Settings.values[key])
            elif key=="text_speed":choices=["DEFAULT","FAST","FASTER"];selected=int(Settings.values.text_speed)
            for c in range(choices.size()):
                var x:=132.0+c*(52.0 if choices.size()==3 else 78.0)
                if key=="text_speed" and c==1: x+=4.0
                var choice:=label(row,choices[c],Vector2(x,0),Vector2(76 if choices.size()==2 else 52,14),7)
                choice.add_theme_color_override("font_color",Color8(192,40,40) if c==selected else Color.BLACK)
                if c==selected:choice.material=selected_text_material
    description.text=(control_rows[index][2] if controls_page else menu_rows[index][2])+"\nB: BACK" 

func build_controls() -> void:
    control_rows.clear()
    var touch_map:Dictionary=preload("res://scripts/touch_controls.gd").ACTIONS
    for action in ["move_up","move_down","move_left","move_right","confirm","cancel","run","start","quit_menu","shoulder_left","shoulder_right","zoom_in","zoom_out","field_move_wheel","ball_mechanics","pokedex","map_open","build_menu","battle_catch"]:
        var keys:Array[String]=[];var pads:Array[String]=[];var touches:Array[String]=[]
        for event in InputMap.action_get_events(action):
            if event is InputEventKey:keys.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode))
            elif event is InputEventMouseButton:keys.append("WHEEL UP" if event.button_index==MOUSE_BUTTON_WHEEL_UP else "WHEEL DOWN" if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else event.as_text())
            elif event is InputEventJoypadButton:pads.append(joy_button_name(event.button_index))
            elif event is InputEventJoypadMotion:
                if event.axis==JOY_AXIS_LEFT_X:pads.append("L-STICK LEFT" if event.axis_value<0 else "L-STICK RIGHT")
                elif event.axis==JOY_AXIS_LEFT_Y:pads.append("L-STICK UP" if event.axis_value<0 else "L-STICK DOWN")
                elif event.axis==JOY_AXIS_TRIGGER_LEFT:pads.append("LT / L2")
                elif event.axis==JOY_AXIS_TRIGGER_RIGHT:pads.append("RT / R2")
        for button in touch_map:
            if action in main.touch_controls.button_actions(button):touches.append(main.touch_controls.face_letter(button))
        if action.begins_with("move_"):touches=["D-pad / left stick"]
        var name:String=action.replace("_"," ").to_upper()
        control_rows.append(["CONTROLLER"," / ".join(pads) if not pads.is_empty() else "--",name])
        control_rows.append(["TOUCH"," / ".join(touches) if not touches.is_empty() else "--",name])
        if action == "pokedex":
            control_rows.append(["CONTROLLER"," / ".join(pads),"BATTLE: THROW LAST BALL"])
            control_rows.append(["TOUCH"," / ".join(touches),"BATTLE: THROW LAST BALL"])

    control_rows.append(["CONTROLLER","LT + RT","PARTY WHEEL (THROWABLE POKEBALLS ON)"])
    control_rows.append(["CONTROLLER","TAP RT","THROW / RECALL"])
    control_rows.append(["CONTROLLER","HOLD RT","BALL WHEEL"])
    if is_instance_valid(main.coop_game) and main.coop_game.active:
        control_rows.append(["CONTROLLER","HOLD D-UP","ONLINE: MARK TILE IN FRONT"])
        control_rows.append(["CONTROLLER","A","FACE PLAYER: TRADE / BATTLE"])

func joy_button_name(button: int) -> String:
    var face := input_router.face_button_name(button)
    if not face.is_empty(): return face
    return {JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",JOY_BUTTON_START:"START",JOY_BUTTON_BACK:"SELECT",JOY_BUTTON_LEFT_SHOULDER:"LB / L1",JOY_BUTTON_RIGHT_SHOULDER:"RB / R1",JOY_BUTTON_DPAD_UP:"D-UP",JOY_BUTTON_DPAD_DOWN:"D-DOWN",JOY_BUTTON_DPAD_LEFT:"D-LEFT",JOY_BUTTON_DPAD_RIGHT:"D-RIGHT"}.get(button,"BUTTON %d" % button)
