extends Control
## Original SpecialBattleMewtwo and Attack.Mewtwo_Special1, at 60 source ticks/s.
## Owned by one encounter; no shared battle sprite/material state survives cleanup.
# The two long lines are split so each part fits the message box.
const SPEECH := {100:"Humans...", 280:"They cared nothing for me...",
    560:"From the moment I first opened my eyes,", 760:"they have sought to control me...",
    960:"But no more.", 1160:"Why are you here?",
    1310:"You seek to control me,", 1445:"just like the others.", 1580:"..."}
const RIPPLE := [0,0,0,1,2,2,2,3,4,4,4,3,2,2,2,1]
var host: Node
var timeline: Dictionary
var body: Texture2D
var breath: Texture2D
var breath_sprite: TextureRect
var rock_texture: Texture2D
var backgrounds: Array[Texture2D] = []
var rocks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var accumulator := 0.0
var ticks := 0
var breathe := false
var breath_ticks := 0
var rocks_visible := false
var frozen := false
var front_x := 0
var rear_x := 0
var ripple_y := -16
var effect: ColorRect
var foreground: Control
const RAISED_UI := ["CommandBox", "ExactBattleCommandFrame", "BattleStatus", "DoubleStatus", "MessageArrow",
    "Actions", "MoveTypeBox", "MoveBox", "BattleSubmenu"]
var raised_ui: Dictionary = {}
var level := 0.0

func setup(owner_node: Node, shiny: bool) -> void:
    host = owner_node
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    timeline = JSON.parse_string(FileAccess.get_file_as_string("res://data/source_mewtwo_timeline.json"))
    var suffix := "_shiny" if shiny else ""
    body = load("res://assets/source_mewtwo/mewtwo_special1%s.png" % suffix)
    breath = load("res://assets/source_mewtwo/mewtwo_special2%s.png" % suffix)
    breath_sprite = TextureRect.new()
    breath_sprite.texture = breath
    breath_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    breath_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    breath_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    breath_sprite.use_parent_material = true
    host.enemy_sprite.add_child(breath_sprite)
    breath_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    rock_texture = load("res://assets/source_exact/battle/rock1.png")
    for name in ["battle_bg3", "battle_bg5", "battle_bg4"]:
        backgrounds.append(load("res://assets/source_exact/battle/%s.png" % name))
    rng.randomize()
    for layer in range(2):
        for index in range(10):
            var rock := {"layer":layer, "index":index}
            _reset_rock(rock)
            rocks.append(rock)
    foreground = Control.new()
    foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    foreground.z_index = 2
    foreground.draw.connect(_draw_front)
    add_child(foreground)
    # The foreground draws the source's text-box frame over the front rocks.
    # The battle text and menus must stay above it, or the box shows empty
    # and no attack can be chosen.
    for name in RAISED_UI:
        var node := host.get_node_or_null("UI/BattlePanel/" + name) as CanvasItem
        if node != null and node.z_index <= foreground.z_index:
            raised_ui[node] = node.z_index
            node.z_index = foreground.z_index + 1
    effect = ColorRect.new()
    effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    effect.z_index = 4
    var shader := Shader.new()
    shader.code = """shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float level = 0.0;
uniform float ripple_y = -100.0;
void fragment() {
    vec2 uv = SCREEN_UV;
    float y = (1.0 - uv.y) * 144.0 - ripple_y;
    if (y >= 0.0 && y < 16.0) {
        float offsets[16] = float[16](0.,0.,0.,1.,2.,2.,2.,3.,4.,4.,4.,3.,2.,2.,2.,1.);
        uv.x -= offsets[int(y)] / 160.0;
    }
    vec4 c = texture(screen_texture, uv);
    if (!(c.r >= 0.9 && c.g >= 0.9 && c.b >= 0.9)) c.rgb -= vec3(level);
    COLOR = c;
}"""
    var material_instance := ShaderMaterial.new()
    material_instance.shader = shader
    effect.material = material_instance
    add_child(effect)

func _reset_rock(rock: Dictionary) -> void:
    var rear := int(rock.layer) == 0
    rock["x"] = rng.randi_range(0,127)
    rock["y"] = rng.randi_range(20,65) if rear else rng.randi_range(-144,-1)
    rock["rotation"] = rng.randi_range(0,3)
    rock["period"] = rng.randi_range(4,8)
    rock["counter"] = int(rock.period)
    rock["v1"] = rng.randi_range(1,2)
    rock["v2"] = int(rock.v1) - 1 + rng.randi_range(0,1)

func _process(delta: float) -> void:
    if foreground == null: return
    if not preload("res://scripts/game_options.gd").enabled("battle_animations"): return
    accumulator += delta * 60.0
    while accumulator >= 1.0:
        accumulator -= 1.0
        tick()
    queue_redraw()
    foreground.queue_redraw()

func tick() -> void:
    ticks += 1
    if breathe: breath_ticks = (breath_ticks + 1) % 300
    if breath_sprite != null:
        breath_sprite.position.y = host.enemy_sprite.size.y / 56.0 if breathe and breath_ticks >= 151 else 0.0
    if not rocks_visible: return
    if ripple_y > 576: ripple_y = 0
    ripple_y += 3 if ripple_y % 2 == 0 else 4
    (effect.material as ShaderMaterial).set_shader_parameter("ripple_y", float(ripple_y))
    for rock in rocks:
        var rear := int(rock.layer) == 0
        rock.x = int(rock.x) + (rear_x if rear else front_x)
        if not frozen:
            if rear:
                rock.counter = int(rock.counter) - 1
                if int(rock.counter) <= 0:
                    rock.y = int(rock.y) + 1
                    rock.counter = int(rock.period)
            else:
                rock.y = int(rock.y) + int(rock.v1 if ticks % 2 == 0 else rock.v2)
        if int(rock.y) > 144: _reset_rock(rock)
        if int(rock.x) < 0:
            _reset_rock(rock)
            rock.x = 160
            rock.y = rng.randi_range(0,111) if rear else rng.randi_range(-32,111)

func set_level(value: float) -> void:
    level = value
    (effect.material as ShaderMaterial).set_shader_parameter("level", value)

func special_tick(frame: int) -> void:
    if timeline.special_levels.has(str(frame)):
        set_level(float(timeline.special_levels[str(frame)]))
    if frame == 0: frozen = true
    var velocities := {60:[-8,-2],120:[-12,-3],180:[-16,-4],455:[-14,-3],
        465:[-12,-3],475:[-10,-3],485:[-8,-2],495:[-6,-2],505:[-6,-2],
        515:[-4,-1],525:[-2,-1],535:[0,0]}
    if velocities.has(frame):
        front_x = velocities[frame][0]
        rear_x = velocities[frame][1]
    if frame == 60: host._play_source_battle_sound("Mewtwo_Special1.ogg")
    if frame >= 300 and frame < 550:
        host.player_battle_sprite.modulate.a = 1.0 if frame % 2 == 0 else 0.0
    if frame == 550:
        host.player_battle_sprite.modulate.a = 1.0
        frozen = false

func play_special() -> void:
    if not preload("res://scripts/game_options.gd").enabled("battle_animations"): return
    var elapsed := 0.0
    var frame := 0
    while frame < 600:
        elapsed += await await_frame()
        var target := mini(600, int(elapsed * 60.0))
        while frame < target:
            special_tick(frame)
            frame += 1
    set_level(0.0)

func play_intro() -> void:
    if not preload("res://scripts/game_options.gd").enabled("battle_animations"):
        await host._type_battle_text("An oppressive force surrounds you...")
        await host._type_battle_text("MEWTWO unleashes its full power!")
        rocks_visible = true
        queue_redraw()
        foreground.queue_redraw()
        return
    var elapsed := 0.0
    var frame := 0
    var enemy_end: Vector2 = host.enemy_sprite.position
    var player_end: Vector2 = host.player_battle_sprite.position
    while frame < 640:
        elapsed += await await_frame()
        var target := mini(640, int(elapsed * 60.0))
        while frame < target:
            if timeline.intro_levels.has(str(frame)):
                set_level(float(timeline.intro_levels[str(frame)]))
            if frame <= 144:
                host.enemy_sprite.position = enemy_end + Vector2(float(frame-144),0)
                host.player_battle_sprite.position = player_end + Vector2(float(144-frame),0)
            if frame == 144: host._start_battle_text("An oppressive force surrounds you...")
            if frame == 380: host._start_battle_text("MEWTWO unleashes its full power!")
            if frame == 556: host._start_battle_text("")
            if frame == 609: set_level(0.0)
            if frame == 620: breathe = true
            frame += 1
    rocks_visible = true
    host.enemy_sprite.position = enemy_end
    host.player_battle_sprite.position = player_end

func await_frame() -> float:
    # Async callers must await this helper; elapsed time, not render count,
    # determines source ticks on 30/60/120 Hz displays.
    await get_tree().process_frame
    return get_process_delta_time()

func _draw() -> void:
    if backgrounds.is_empty(): return
    var scale_xy := size / Vector2(160,144)
    draw_set_transform(Vector2.ZERO,0.0,scale_xy)
    var rect := Rect2(-8,-8,176,160)
    draw_texture_rect(backgrounds[0],rect,false)
    draw_texture_rect(backgrounds[1],rect,false)
    if rocks_visible: _draw_rocks(self,0)
    draw_set_transform(Vector2.ZERO)

func _draw_front() -> void:
    if host == null: return
    if not rocks_visible: return
    foreground.draw_set_transform(Vector2.ZERO,0.0,size / Vector2(160,144))
    _draw_rocks(foreground,1)
    foreground.draw_texture_rect(backgrounds[2],Rect2(-8,-8,176,160),false)
    foreground.draw_set_transform(Vector2.ZERO)

func _draw_rocks(canvas: Control, layer: int) -> void:
    var indices := [0,32,64,160,0,32,64,160,0,0] if layer == 0 else [0,32,64,160,192,32,64,160,192,0]
    for rock in rocks:
        if int(rock.layer) != layer: continue
        var position_xy := Vector2(float(rock.x),144.0-float(rock.y)-32.0)
        canvas.draw_set_transform((position_xy+Vector2(16,16)) * size / Vector2(160,144),
            float(rock.rotation)*PI/2.0,size / Vector2(160,144))
        canvas.draw_texture_rect_region(rock_texture,Rect2(-16,-16,32,32),
            Rect2(float(indices[int(rock.index)]),0,32,32),Color.BLACK if layer == 0 else Color.WHITE)
    canvas.draw_set_transform(Vector2.ZERO,0.0,size / Vector2(160,144))

func _exit_tree() -> void:
    for node in raised_ui:
        if is_instance_valid(node): node.z_index = int(raised_ui[node])
    raised_ui.clear()
    if is_instance_valid(breath_sprite): breath_sprite.queue_free()
